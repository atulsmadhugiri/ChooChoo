import Combine
import PostHog
import SwiftData
import SwiftUI

struct ContentView: View {
  @Query var stations: [MTAStation]

  @StateObject private var locationFetcher = LocationFetcher()
  @State var trainArrivals: [TrainArrivalEntry] = []

  @State var selectionSheetActive: Bool = false

  @State private var selectedDirection: TripDirection = .south
  @State private var selectedStation: MTAStation?

  @State private var nearestStation: MTAStation?

  @State private var loading: Bool = true

  @State private var serviceAlerts: [String: [MTAServiceAlert]] = [:]
  @State private var refreshTask: Task<Void, Never>?
  @State private var refreshGeneration = 0

  let tapHaptic = UIImpactFeedbackGenerator(style: .medium)
  let timer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()

  var body: some View {
    VStack(spacing: 0) {
      let visibleStation = selectedStation ?? nearestStation
      if let visibleStation {
        StationSign(
          station: visibleStation,
          trains: visibleStation.daytimeRoutes,
          distance: locationFetcher.location?.distance(from: visibleStation.location),
          serviceAlerts: visibleStation.serviceAlerts(in: serviceAlerts)
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

      let visibleArrivals = trainArrivals.filter {
        $0.direction == selectedDirection
      }

      VStack {
        Picker("", selection: $selectedDirection) {
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
            if visibleArrivals.isEmpty, !loading {
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
      if selectedStation != nil { return }
      setNearestStation()
      queueRefresh()
    }.onChange(of: selectedStation) { _, newValue in
      if let station = newValue {
        logStationSelected(station)
      }
      queueRefresh()
    }.onChange(of: selectedDirection) { _, newDirection in
      logDirectionChanged(newDirection, station: selectedStation ?? nearestStation)
    }.sheet(isPresented: $selectionSheetActive) {
      StationSelectionSheet(
        location: locationFetcher.location,
        isPresented: $selectionSheetActive,
        selectedStation: $selectedStation,
        serviceAlerts: $serviceAlerts)
    }.onAppear {
      tapHaptic.prepare()
      Task {
        serviceAlerts = await constructServiceAlertsForStop()
      }
    }.onReceive(timer) { _ in
      guard selectedStation ?? nearestStation != nil else { return }
      queueRefresh()
    }.onDisappear {
      refreshTask?.cancel()
      timer.upstream.connect().cancel()
    }
  }

  private func queueRefresh() {
    refreshGeneration += 1
    let generation = refreshGeneration
    refreshTask?.cancel()
    refreshTask = Task {
      await refreshData(generation: generation)
    }
  }

  private func refreshSelectedStation() async {
    refreshGeneration += 1
    let generation = refreshGeneration
    refreshTask?.cancel()
    await refreshData(generation: generation)
  }

  private func refreshData(generation: Int) async {
    guard let station = selectedStation ?? nearestStation else {
      return
    }

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

  func setNearestStation() {
    guard let currentLocation = locationFetcher.location else { return }
    nearestStation = stations.min {
      currentLocation.distance(from: $0.location)
        < currentLocation.distance(from: $1.location)
    }
  }
}

#Preview {
  ContentView()
}
