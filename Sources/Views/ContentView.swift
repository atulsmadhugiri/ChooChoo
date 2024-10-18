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

  let tapHaptic = UIImpactFeedbackGenerator(style: .medium)
  let timer = Timer.publish(every: 20, on: .main, in: .common).autoconnect()

  var body: some View {
    VStack(spacing: 0) {
      let visibleStation = selectedStation ?? nearestStation
      if let visibleStation, let location = locationFetcher.location {
        StationSign(
          station: visibleStation,
          trains: visibleStation.daytimeRoutes,
          distance: location.distance(from: visibleStation.location)
        ).onTapGesture {
          tapHaptic.impactOccurred()
          selectionSheetActive = true
          logStationSignTapped(for: visibleStation)
        }.padding(12).shadow(radius: 2)
      }

      Divider()

      let visibleArrivals = trainArrivals.filter {
        $0.direction == selectedDirection
      }

      VStack {
        Picker("", selection: $selectedDirection) {
          Text(TripDirection.south.rawValue).tag(TripDirection.south)
          Text(TripDirection.north.rawValue).tag(TripDirection.north)
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
          .refreshable { await refreshData() }
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
      Task { await refreshData() }
    }.onChange(of: selectedStation) {
      Task { await refreshData() }
    }.sheet(isPresented: $selectionSheetActive) {
      StationSelectionSheet(
        location: locationFetcher.location,
        isPresented: $selectionSheetActive,
        selectedStation: $selectedStation)
    }.onAppear {
      tapHaptic.prepare()
    }.onReceive(timer) { _ in
      Task { await refreshData() }
    }.onDisappear {
      timer.upstream.connect().cancel()
    }
  }

  func refreshData() async {
    guard let station = selectedStation ?? nearestStation else {
      return
    }

    let lines = station.lines
    let stops = station.stops.map { MTAStopValue(mtaStop: $0) }

    Task {
      loading = true
      defer { loading = false }
      trainArrivals = await getArrivals(lines: lines, stops: stops)
      let sameDirection = trainArrivals.filter {
        $0.direction == selectedDirection
      }
      if sameDirection.isEmpty {
        selectedDirection = selectedDirection.flipped
      }
    }
  }

  func setNearestStation() {
    guard let currentLocation = locationFetcher.location else { return }
    let nearestStations = stations.sorted(by: {
      currentLocation.distance(from: $0.location)
        < currentLocation.distance(from: $1.location)
    })
    nearestStation = nearestStations.first
  }
}

#Preview {
  ContentView()
}
