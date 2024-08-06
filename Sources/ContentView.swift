import SwiftUI

struct ContentView: View {
  @StateObject private var locationFetcher = LocationFetcher()
  @State var trainArrivals: [TrainArrivalEntry] = []

  var body: some View {
    VStack {
      if let nearestStation = locationFetcher.nearestStation {
        StationSign(
          stationName: nearestStation.stopName,
          trains: nearestStation.daytimeRoutes

        )
        Divider()

        let nextTwoArrivals = trainArrivals.filter {
          $0.arrivalTime.timeIntervalSinceNow > 0
        }.prefix(2)

        VStack {
          ForEach(nextTwoArrivals) { arrival in
            HStack {
              TrainBadge(train: arrival.train, badgeSize: .small)
              Spacer()
              Text("Destination Station").font(.title3).fontDesign(.rounded)
              Spacer()
              Text(
                "\(formatTimeInterval(interval: arrival.arrivalTime.timeIntervalSinceNow))"
              )
              .font(.title3).fontDesign(.rounded)
            }
          }.listStyle(.plain)
            .padding()
            .background(Color.white)
            .cornerRadius(4)
            .clipped()

        }
        .padding().background(Color.black).cornerRadius(4)

        Spacer()

      }
    }
    .padding()
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
    }
  }
}

#Preview {
  ContentView()
}
