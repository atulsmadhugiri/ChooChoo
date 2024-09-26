import PostHog
import SwiftUI

struct ContentView: View {
  @StateObject private var locationFetcher = LocationFetcher()
  @State var trainArrivals: [TrainArrivalEntry] = []

  @State var selectionSheetActive: Bool = false

  @State private var selectedDirection: TripDirection = .south
  @State private var selectedStation: MTAStation?

  @State private var loading: Bool = true

  let tapHaptic = UIImpactFeedbackGenerator(style: .medium)
  let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()

  var body: some View {
    VStack(spacing: 0) {
      let visibleStation = selectedStation ?? locationFetcher.nearestStation
      if let visibleStation {
        StationSign(
          stationName: visibleStation.name,
          trains: visibleStation.daytimeRoutes
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
          ArrivalCard(arrival: arrival)
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
    .onChange(of: locationFetcher.nearestStation) {
      if selectedStation != nil { return }
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
    loading = true
    defer { loading = false }

    guard let station = selectedStation ?? locationFetcher.nearestStation else {
      return
    }

    trainArrivals = await station.getArrivals()
    let sameDirection = trainArrivals.filter {
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
