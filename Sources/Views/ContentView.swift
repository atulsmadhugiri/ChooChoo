import SwiftUI

struct ContentView: View {
  @StateObject private var locationFetcher = LocationFetcher()
  @State var trainArrivals: [TrainArrivalEntry] = []

  @State var selectionSheetActive: Bool = false

  var body: some View {
    VStack(spacing: 0) {
      if let nearestStation = locationFetcher.nearestStation {
        StationSign(
          stationName: nearestStation.stopName,
          trains: nearestStation.daytimeRoutes
        ).onTapGesture {
          selectionSheetActive = true
        }.padding()
          .shadow(radius: 8)

        Divider()

        let futureArrivals = trainArrivals.filter {
          $0.arrivalTime.timeIntervalSinceNow > 0
        }

        VStack {
          List(futureArrivals) { arrival in
            ArrivalCard(arrival: arrival)
          }.listStyle(.plain)
            .background(.background)
            .cornerRadius(8)
            .clipped()
            .refreshable {}
            .shadow(radius: 6)
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
        location:
          locationFetcher.location)
    }
  }
}

#Preview {
  ContentView()
}
