import CoreLocation
import Foundation
import Observation
import SwiftData
import SwiftUI

struct ContentView: View {
  @Environment(\.scenePhase) private var scenePhase
  @Query(sort: \MTAStation.name) var stations: [MTAStation]

  @AppStorage("lastVisibleStationID") private var lastVisibleStationID = 0
  @AppStorage("lastSelectedDirection") private var persistedSelectedDirection =
    TripDirection.south.storageValue

  @StateObject private var locationFetcher = LocationFetcher()
  @State private var viewModel = ContentViewModel()

  @State private var selectionSheetActive = false

  let tapHaptic = UIImpactFeedbackGenerator(style: .medium)

  var body: some View {
    let visibleStation = viewModel.visibleStation ?? launchStation

    VStack(spacing: 0) {
      if let visibleStation {
        StationSign(
          station: visibleStation,
          distance: locationFetcher.location?.distance(from: visibleStation.location),
          serviceAlerts: visibleStation.serviceAlerts(in: viewModel.serviceAlerts)
        ).onTapGesture {
          tapHaptic.impactOccurred()
          selectionSheetActive = true
        }.padding(12).shadow(radius: 2)
      } else {
        Button {
          tapHaptic.impactOccurred()
          selectionSheetActive = true
        } label: {
          Label("Choose Station", systemImage: "tram.fill")
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .padding(12)
      }

      Divider()

      let visibleArrivals = viewModel.trainArrivals.filter {
        $0.direction == viewModel.selectedDirection
      }

      VStack {
        Picker("", selection: $viewModel.selectedDirection) {
          let southLabel = visibleStation?.getLabelFor(direction: .south)
            ?? TripDirection.south.rawValue
          let northLabel = visibleStation?.getLabelFor(direction: .north)
            ?? TripDirection.north.rawValue
          Text(southLabel).tag(TripDirection.south)
          Text(northLabel).tag(TripDirection.north)
        }.pickerStyle(.segmented).labelsHidden().padding(.bottom, 8)

        List(visibleArrivals) { arrival in
          ArrivalCard(arrival: arrival).listRowInsets(
            EdgeInsets(
              top: 12,
              leading: 12,
              bottom: 12,
              trailing: 12
            )
          )
        }.listStyle(.plain)
          .background(.background)
          .cornerRadius(8)
          .clipped()
          .refreshable { await refreshSelectedStation() }
          .shadow(radius: 2)
          .overlay {
            if visibleArrivals.isEmpty, !viewModel.loading {
              ContentUnavailableView {
                Label(
                  "No trains running in this direction.",
                  systemImage: "wrongwaysign.fill")
              }
            }
          }
      }
      .padding(12)
    }
    .background(.ultraThickMaterial)
    .onChange(of: locationFetcher.location) {
      if viewModel.selectedStation != nil { return }
      viewModel.setNearestStation(from: stations, location: locationFetcher.location)
    }.onChange(of: viewModel.selectedDirection) { _, newDirection in
      persistedSelectedDirection = newDirection.storageValue
    }.onChange(of: viewModel.visibleStation?.id) { _, stationID in
      if let stationID {
        lastVisibleStationID = stationID
        viewModel.prepareForStationChange()
      }
    }.sheet(isPresented: $selectionSheetActive) {
      StationSelectionSheet(
        location: locationFetcher.location,
        isPresented: $selectionSheetActive,
        selectedStation: $viewModel.selectedStation,
        serviceAlerts: viewModel.serviceAlerts)
    }.task(id: scenePhase) {
      switch scenePhase {
      case .active:
        locationFetcher.refreshAuthorizationState()
        do {
          try await Task.sleep(for: .milliseconds(250))
        } catch {
          return
        }
        guard !Task.isCancelled else { return }
        await recordAnalyticsAppOpenIfNeeded()
      case .inactive:
        locationFetcher.stopUpdatingLocation()
      case .background:
        locationFetcher.stopUpdatingLocation()
        await recordAnalyticsAppBackgrounded()
      default:
        break
      }
    }.task {
      await viewModel.loadServiceAlerts()
    }.task(id: RefreshLoopID(stationID: visibleStation?.id, scenePhase: scenePhase)) {
      viewModel.restoreLaunchState(
        stations: stations,
        preferredStation: launchStation,
        directionStorageValue: persistedSelectedDirection
      )
      guard scenePhase == .active else { return }
      await viewModel.refreshLoop(stations: stations)
    }
  }

  private func refreshSelectedStation() async {
    await viewModel.refreshSelectedStation(stations: stations)
  }

  private var launchStation: MTAStation? {
    if lastVisibleStationID != 0,
      let station = stations.first(where: { $0.id == lastVisibleStationID })
    {
      return station
    }

    return stations
      .lazy
      .filter(\.pinned)
      .first
  }
}

@MainActor
@Observable
final class ContentViewModel {
  var trainArrivals: [TrainArrivalEntry] = []
  var selectedDirection: TripDirection = .south
  var selectedStation: MTAStation?
  var nearestStation: MTAStation?
  var loading = true
  var serviceAlerts: [String: [MTAServiceAlert]] = [:]

  @ObservationIgnored
  private var refreshGeneration = 0

  @ObservationIgnored
  private var cachedStopNameStationIDs: [Int] = []

  @ObservationIgnored
  private var cachedStopNamesByGTFSID: [String: String] = [:]

  var visibleStation: MTAStation? {
    selectedStation ?? nearestStation
  }

  func restoreLaunchState(
    stations: [MTAStation],
    preferredStation: MTAStation?,
    directionStorageValue: String
  ) {
    if let direction = TripDirection(storageValue: directionStorageValue) {
      selectedDirection = direction
    }

    if let selectedStation {
      if let replacement = stations.first(where: { $0.id == selectedStation.id }) {
        self.selectedStation = replacement
        return
      }
      self.selectedStation = nil
    }

    if nearestStation != nil { return }

    selectedStation = preferredStation
  }

  func loadServiceAlerts() async {
    let alerts = await constructServiceAlertsForStop()
    guard !Task.isCancelled else { return }
    serviceAlerts = alerts
  }

  func prepareForStationChange() {
    trainArrivals = []
    loading = true
  }

  func refreshLoop(stations: [MTAStation]) async {
    guard visibleStation != nil else {
      loading = false
      return
    }

    await refreshSelectedStation(stations: stations)

    while !Task.isCancelled {
      do {
        try await Task.sleep(for: refreshInterval)
      } catch {
        return
      }
      await refreshSelectedStation(stations: stations)
    }
  }

  func setNearestStation(from stations: [MTAStation], location: CLLocation?) {
    guard let location else { return }
    var closestStation: MTAStation?
    var closestDistance = CLLocationDistance.greatestFiniteMagnitude

    for station in stations {
      let distance = location.distance(from: station.location)
      guard distance < closestDistance else { continue }
      closestStation = station
      closestDistance = distance
    }

    nearestStation = closestStation
  }

  func refreshSelectedStation(stations: [MTAStation]) async {
    refreshGeneration += 1
    let generation = refreshGeneration
    await refreshData(generation: generation, stations: stations)
  }

  private func refreshData(
    generation: Int,
    stations: [MTAStation]
  ) async {
    guard let station = visibleStation else {
      loading = false
      return
    }

    let snapshot = station.snapshot(
      stopNamesByGTFSID: stopNamesByGTFSID(from: stations)
    )

    loading = true
    let arrivals = await getArrivals(for: snapshot)

    guard !Task.isCancelled, generation == refreshGeneration else { return }

    trainArrivals = arrivals
    loading = false
    let sameDirectionExists = arrivals.contains {
      $0.direction == selectedDirection
    }
    let flippedDirectionExists = arrivals.contains {
      $0.direction == selectedDirection.flipped
    }
    if !sameDirectionExists, flippedDirectionExists {
      selectedDirection = selectedDirection.flipped
    }
  }

  private var refreshInterval: Duration {
    ProcessInfo.processInfo.isLowPowerModeEnabled ? .seconds(45) : .seconds(20)
  }

  private func stopNamesByGTFSID(from stations: [MTAStation]) -> [String: String] {
    let stationIDs = stations.map(\.id).sorted()
    guard stationIDs != cachedStopNameStationIDs else {
      return cachedStopNamesByGTFSID
    }

    cachedStopNameStationIDs = stationIDs
    cachedStopNamesByGTFSID = MTAStation.stopNamesByGTFSID(from: stations)
    return cachedStopNamesByGTFSID
  }
}

private struct RefreshLoopID: Equatable {
  let stationID: MTAStation.ID?
  let scenePhase: ScenePhase
}

#Preview {
  ContentView()
}
