import Combine
import CoreLocation
import SwiftData
import SwiftUI

struct ContentView: View {
  @Query var stations: [MTAStation]

  @StateObject private var locationFetcher = LocationFetcher()
  @StateObject private var viewModel = ContentViewModel()

  @State var selectionSheetActive: Bool = false

  let tapHaptic = UIImpactFeedbackGenerator(style: .medium)
  let timer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()

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
      viewModel.queueRefresh(stations: stations)
    }.onChange(of: viewModel.selectedStation) { _, newValue in
      if let station = newValue {
        logStationSelected(station)
      }
      viewModel.queueRefresh(stations: stations)
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
      Task {
        await viewModel.loadServiceAlerts()
      }
    }.onReceive(timer) { _ in
      guard viewModel.visibleStation != nil else { return }
      viewModel.queueRefresh(stations: stations)
    }.onDisappear {
      viewModel.cancelRefresh()
      timer.upstream.connect().cancel()
    }
  }

  private func refreshSelectedStation() async {
    await viewModel.refreshSelectedStation(stations: stations)
  }
}

@MainActor
final class ContentViewModel: ObservableObject {
  @Published var trainArrivals: [TrainArrivalEntry] = []
  @Published var selectedDirection: TripDirection = .south
  @Published var selectedStation: MTAStation?
  @Published var nearestStation: MTAStation?
  @Published var loading = true
  @Published var serviceAlerts: [String: [MTAServiceAlert]] = [:]

  private var refreshTask: Task<Void, Never>?
  private var refreshGeneration = 0

  var visibleStation: MTAStation? {
    selectedStation ?? nearestStation
  }

  func loadServiceAlerts() async {
    serviceAlerts = await constructServiceAlertsForStop()
  }

  func queueRefresh(stations: [MTAStation]) {
    refreshGeneration += 1
    let generation = refreshGeneration
    refreshTask?.cancel()
    refreshTask = Task {
      await refreshData(generation: generation, stations: stations)
    }
  }

  func refreshSelectedStation(stations: [MTAStation]) async {
    refreshGeneration += 1
    let generation = refreshGeneration
    refreshTask?.cancel()
    await refreshData(generation: generation, stations: stations)
  }

  func cancelRefresh() {
    refreshTask?.cancel()
    refreshTask = nil
  }

  func setNearestStation(from stations: [MTAStation], location: CLLocation?) {
    guard let location else { return }
    nearestStation = stations.min {
      location.distance(from: $0.location) < location.distance(from: $1.location)
    }
  }

  private func refreshData(
    generation: Int,
    stations: [MTAStation]
  ) async {
    guard let station = visibleStation else { return }

    logRefresh(for: station)

    let lines = station.lines
    let stops = station.stops.map(\.value)
    let stopNamesByGTFSID = Dictionary(
      stations.flatMap(\.stops).map { ($0.gtfsStopID, $0.stopName) },
      uniquingKeysWith: { first, _ in first }
    )

    loading = true
    let arrivals = await getArrivals(
      lines: lines,
      stops: stops,
      stopNamesByGTFSID: stopNamesByGTFSID
    )

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
