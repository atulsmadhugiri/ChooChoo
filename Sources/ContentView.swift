import SwiftUI

struct ContentView: View {
  @StateObject private var locationFetcher = LocationFetcher()
  var body: some View {
    VStack {
      Image(systemName: "globe")
        .imageScale(.large)
        .foregroundStyle(.tint)
      Text(locationFetcher.location.debugDescription)
      if let nearestStation = locationFetcher.nearestStation {
        Text(nearestStation.stopName)
      }
    }
    .padding()
  }
}

#Preview {
  ContentView()
}
