import SwiftUI

struct ContentView: View {
  @StateObject private var locationFetcher = LocationFetcher()
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

        HStack {
          ForEach(nearestStation.daytimeRoutes) { route in
            TrainBadge(train: route, badgeSize: .small)
          }
        }
      }
    }
    .padding()
  }
}

#Preview {
  ContentView()
}
