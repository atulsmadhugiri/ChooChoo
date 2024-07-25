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

        let nextTwoArrivals = trainArrivals.filter { $0.arrivalTime.timeIntervalSinceNow > 0 }.prefix(2)
        List(nextTwoArrivals) { arrival in
          HStack {
            TrainBadge(train: arrival.train, badgeSize: .small).padding()
            Text("\(formatTimeInterval(interval: arrival.arrivalTime.timeIntervalSinceNow))")
              .font(.title3)
              .monospaced()
          }
        }.listStyle(.plain)
      }
    }
    .padding()
    .onAppear {
      Task {
        let data = try await NetworkUtils.sendNetworkRequest(to: .l)
        let feed = try TransitRealtime_FeedMessage(serializedBytes: data)
        guard let nearestStation = locationFetcher.nearestStation else {
          return
        }

        let trainArrivalsForCurrentStop: [TrainArrivalEntry] = feed.entity
          .compactMap { $0.hasTripUpdate ? $0.tripUpdate : nil }
          .flatMap { tripUpdate in
            tripUpdate.stopTimeUpdate.compactMap { stopTimeUpdate -> TrainArrivalEntry? in
              guard stopTimeUpdate.stopID.dropLast() == nearestStation.gtfsStopID else {
                return nil
              }
              let arrivalTime = Date(timeIntervalSince1970: Double(stopTimeUpdate.arrival.time))
              let train = MTATrain(rawValue: tripUpdate.trip.routeID) ?? .a
              return TrainArrivalEntry(arrivalTime: arrivalTime, train: train)
            }
          }
        trainArrivals = trainArrivalsForCurrentStop.sorted { $0.arrivalTime < $1.arrivalTime }
      }
    }
  }
}

#Preview {
  ContentView()
}
