import SwiftUI

struct ContentView: View {
  @StateObject private var locationFetcher = LocationFetcher()
  @State var trainArrivals: [TrainArrivalEntry] = []

  @State var selectionSheetActive: Bool = false

  var body: some View {
    VStack {
      if let nearestStation = locationFetcher.nearestStation {
        StationSign(
          stationName: nearestStation.stopName,
          trains: nearestStation.daytimeRoutes
        ).onTapGesture {
          selectionSheetActive = true
        }

        Divider()

        let futureArrivals = trainArrivals.filter {
          $0.arrivalTime.timeIntervalSinceNow > 0
        }

        VStack {
          List(futureArrivals) { arrival in
            HStack {
              TrainBadge(train: arrival.train, badgeSize: .small)
              Spacer()
              Text(arrival.terminalStation).font(.headline).fontDesign(.rounded)
              Spacer()
              Text(
                "\(formatTimeInterval(interval: arrival.arrivalTime.timeIntervalSinceNow))"
              )
              .font(.headline).fontDesign(.rounded)
            }
          }.listStyle(.plain)
            .background(Color.white)
            .cornerRadius(4)
            .clipped()
            .refreshable {}

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
    }.sheet(isPresented: $selectionSheetActive) {
      StationSelectionSheet(
        location:
          locationFetcher.location)
    }
  }
}

#Preview {
  ContentView()
}
