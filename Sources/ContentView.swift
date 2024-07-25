import SwiftUI

struct ContentView: View {
  @StateObject private var locationFetcher = LocationFetcher()
  @State var trainArrivals: [TrainArrivalEntry] = []

  var body: some View {
    VStack {
      if let nearestStation = locationFetcher.nearestStation {
        HStack {
          Image(systemName: "tram.fill")
            .imageScale(.large)
            .foregroundStyle(.black)
          Text(nearestStation.stopName)
            .font(.title2)
        }
        Text("GTFS Stop ID: \(nearestStation.gtfsStopID)")

        HStack {
          ForEach(nearestStation.daytimeRoutes) { route in
            TrainBadge(train: route, badgeSize: .small)
          }
        }

        List(trainArrivals) { arrival in
          if arrival.arrivalTime.timeIntervalSinceNow > 0 {
            HStack {
              TrainBadge(train: arrival.train, badgeSize: .small).padding()
              Text("\(formatTimeInterval(interval: arrival.arrivalTime.timeIntervalSinceNow))")
                .font(.title3)
                .monospaced()
            }
          }
        }.listStyle(.plain)
      }
    }
    .padding()
  }
}

#Preview {
  ContentView()
}
