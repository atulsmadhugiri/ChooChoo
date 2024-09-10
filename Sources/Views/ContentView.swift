import SwiftUI

struct ContentView: View {
  @StateObject private var locationFetcher = LocationFetcher()
  @State var trainArrivals: [TrainArrivalEntry] = []

  @State var selectionSheetActive: Bool = false

  @State private var selectedDirection: TripDirection = .south
  @State private var selectedStation: MTAStation?

  let tapHaptic = UIImpactFeedbackGenerator(style: .medium)

  var body: some View {
    VStack(spacing: 0) {
      let visibleStation = selectedStation ?? locationFetcher.nearestStation
      if let visibleStation {
        StationSign(
          stationName: visibleStation.stopName,
          trains: visibleStation.daytimeRoutes
        ).onTapGesture {
          tapHaptic.impactOccurred()
          selectionSheetActive = true
        }.padding()
          .shadow(radius: 2)
      }

      if let nearestStation = locationFetcher.nearestStation {
        Divider()

        let futureArrivals = trainArrivals.filter {
          $0.arrivalTime.timeIntervalSinceNow > 0
            && $0.direction == selectedDirection
        }

        VStack {
          Picker("", selection: $selectedDirection) {
            Text(TripDirection.south.rawValue).tag(TripDirection.south)
            Text(TripDirection.north.rawValue).tag(TripDirection.north)
          }.pickerStyle(.segmented).labelsHidden().padding(.bottom, 8)

          List(futureArrivals) { arrival in
            ArrivalCard(arrival: arrival)
          }.listStyle(.plain)
            .background(.background)
            .cornerRadius(8)
            .clipped()
            .refreshable {}
            .shadow(radius: 2)
        }
        .padding().background(.ultraThickMaterial)

      }
    }
    .onChange(of: locationFetcher.nearestStation) {
      Task {
        guard let nearestStation = locationFetcher.nearestStation,
          let train = nearestStation.daytimeRoutes.first
        else {
          return
        }

        let data = try await NetworkUtils.sendNetworkRequest(
          to: getLineForTrain(train: train).endpoint)
        let feed = try TransitRealtime_FeedMessage(serializedBytes: data)

        trainArrivals = getTrainArrivalsForStop(
          stop: nearestStation,
          feed: feed.entity
        )
      }
    }.sheet(isPresented: $selectionSheetActive) {
      StationSelectionSheet(
        location: locationFetcher.location,
        isPresented: $selectionSheetActive,
        selectedStation: $selectedStation)
    }.onAppear {
      tapHaptic.prepare()
    }
  }
}

#Preview {
  ContentView()
}
