import CoreLocation
import SwiftUI

struct StationSelectionSheet: View {
  var location: CLLocation?
  @State private var searchTerm = ""
  @Binding var isPresented: Bool
  @Binding var selectedStation: MTAStation?

  let tapHaptic = UIImpactFeedbackGenerator(style: .medium)

  let mergedStations = mergeStops(mtaStops)
  var filteredStations: [MTAStation] {
    guard !searchTerm.isEmpty else { return mergedStations }
    return mergedStations.filter {
      $0.name.localizedCaseInsensitiveContains(searchTerm)
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
            stationName: station.name,
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
          .overlay {
            if sorted.isEmpty, !searchTerm.isEmpty {
              ContentUnavailableView.search(text: searchTerm)
            }
          }
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
