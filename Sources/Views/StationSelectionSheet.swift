import CoreLocation
import SwiftUI

struct StationSelectionSheet: View {
  var location: CLLocation?
  @State private var searchTerm = ""
  @Binding var isPresented: Bool
  @Binding var selectedStation: MTAStop?

  let tapHaptic = UIImpactFeedbackGenerator(style: .medium)

  var filteredStations: [MTAStop] {
    guard !searchTerm.isEmpty else { return mtaStations }
    return mtaStations.filter {
      $0.stopName.localizedCaseInsensitiveContains(searchTerm)
    }
  }

  var body: some View {
    if let location {
      let sorted = filteredStations.sorted(by: {
        location.distance(from: $0.location)
          < location.distance(from: $1.location)
      })
      NavigationView {
        List(sorted) { station in
          StationSign(
            stationName: station.stopName,
            trains: station.daytimeRoutes
          ).onTapGesture {
            tapHaptic.impactOccurred()
            selectedStation = station
            isPresented = false
          }
        }.listStyle(.plain)
          .searchable(
            text: $searchTerm,
            placement: .automatic,
            prompt: "Search stations"
          )
          .navigationBarTitle(
            "Nearby Stations",
            displayMode: .inline
          )
      }.onAppear {
        tapHaptic.prepare()
      }

    }
  }
}
