import SwiftUI

struct ContentView: View {
  @StateObject private var locationFetcher = LocationFetcher()
  var body: some View {
    VStack {
      Image(systemName: "globe")
        .imageScale(.large)
        .foregroundStyle(.tint)
      Text(locationFetcher.location.debugDescription)
    }
    .padding()
  }
}

#Preview {
  ContentView()
}
