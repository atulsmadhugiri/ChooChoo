import CoreLocation
import Observation
import SwiftData
import SwiftUI

struct ContentView: View {
  @Query var stations: [MTAStation]

  @StateObject private var locationFetcher = LocationFetcher()
  @State private var viewModel = ContentViewModel()

  @State var selectionSheetActive: Bool = false

  let tapHaptic = UIImpactFeedbackGenerator(style: .medium)

  var body: some View {
    VStack(spacing: 0) {
      let visibleStation = viewModel.visibleStation
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
        logStationSelected(station)
      }
    }.onChange(of: viewModel.selectedDirection) { _, newDirection in
      logDirectionChanged(newDirection, station: viewModel.visibleStation)
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
    }.task(id: viewModel.visibleStation?.id) {
      await viewModel.refreshLoop(stations: stations)
    }
  }

  private func refreshSelectedStation() async {
    await viewModel.refreshSelectedStation(stations: stations)
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

  var visibleStation: MTAStation? {
    selectedStation ?? nearestStation
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
    nearestStation = stations.min {
      location.distance(from: $0.location) < location.distance(from: $1.location)
    }
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
      stopNamesByGTFSID: MTAStation.stopNamesByGTFSID(from: stations)
    )

    loading = true
    let arrivals = await getArrivals(for: snapshot)

    guard !Task.isCancelled, generation == refreshGeneration else { return }

    trainArrivals = arrivals
    loading = false
    let sameDirection = arrivals.filter {
      $0.direction == selectedDirection
    }
    if sameDirection.isEmpty {
      selectedDirection = selectedDirection.flipped
    }
  }
}

#Preview {
  ContentView()
}
