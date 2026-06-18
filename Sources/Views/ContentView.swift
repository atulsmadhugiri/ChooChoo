import CoreLocation
import Observation
import SwiftData
import SwiftUI

struct ContentView: View {
  @Query var stations: [MTAStation]

  @AppStorage("lastVisibleStationID") private var lastVisibleStationID = 0
  @AppStorage("lastSelectedDirection") private var persistedSelectedDirection =
    TripDirection.south.storageValue

  @StateObject private var locationFetcher = LocationFetcher()
  @State private var viewModel = ContentViewModel()

  @State var selectionSheetActive: Bool = false

  let tapHaptic = UIImpactFeedbackGenerator(style: .medium)

  var body: some View {
    let visibleStation = viewModel.visibleStation ?? launchStation

    VStack(spacing: 0) {
      if let visibleStation {
        StationSign(
          station: visibleStation,
          trains: visibleStation.daytimeRoutes,
          distance: locationFetcher.location?.distance(from: visibleStation.location),
          serviceAlerts: visibleStation.serviceAlerts(in: viewModel.serviceAlerts)
        ).onTapGesture {
          tapHaptic.impactOccurred()
          selectionSheetActive = true
          logStationSignTapped(for: visibleStation)
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
    }.onChange(of: viewModel.selectedStation) { _, newValue in
      if let station = newValue {
        lastVisibleStationID = station.id
        logStationSelected(station)
      }
    }.onChange(of: viewModel.selectedDirection) { _, newDirection in
      persistedSelectedDirection = newDirection.storageValue
      logDirectionChanged(newDirection, station: viewModel.visibleStation)
    }.onChange(of: viewModel.visibleStation?.id) { _, stationID in
      if let stationID {
        lastVisibleStationID = stationID
      }
    }.sheet(isPresented: $selectionSheetActive) {
      StationSelectionSheet(
        location: locationFetcher.location,
        isPresented: $selectionSheetActive,
        selectedStation: $viewModel.selectedStation,
        serviceAlerts: $viewModel.serviceAlerts)
    }.onAppear {
      tapHaptic.prepare()
    }.task {
      await viewModel.loadServiceAlerts()
    }.task(id: visibleStation?.id) {
      viewModel.restoreLaunchState(
        stations: stations,
        preferredStation: launchStation,
        directionStorageValue: persistedSelectedDirection
      )
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
      .min { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
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

  func refreshLoop(stations: [MTAStation]) async {
    guard visibleStation != nil else {
      loading = false
      return
    }

    await refreshSelectedStation(stations: stations)

    while !Task.isCancelled {
      do {
        try await Task.sleep(for: .seconds(20))
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

    logRefresh(for: station)

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
    if !sameDirectionExists {
      selectedDirection = selectedDirection.flipped
    }
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

#Preview {
  ContentView()
}
