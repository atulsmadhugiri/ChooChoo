import CoreLocation
import SwiftData
import SwiftUI

struct StationSelectionSheet: View {
  @Query var stations: [MTAStation]

  var location: CLLocation?
  @State private var searchTerm = ""
  @Binding var isPresented: Bool
  @Binding var selectedStation: MTAStation?

  let tapHaptic = UIImpactFeedbackGenerator(style: .medium)

  var filteredStationEntries: [MTAStation] {
    guard !searchTerm.isEmpty else { return stations }
    return stations.filter {
      $0.name.localizedCaseInsensitiveContains(searchTerm)
    }
  }

  var body: some View {
    if let location {
      let sortedStationEntries = filteredStationEntries.sorted(by: {

        if $0.pinned != $1.pinned {
          return $0.pinned && !$1.pinned
        }

        return location.distance(from: $0.location)
          < location.distance(from: $1.location)
      })
      NavigationView {
        List(sortedStationEntries) { station in
          StationSign(
            station: station,
            trains: station.daytimeRoutes
          ).onTapGesture {
            tapHaptic.impactOccurred()
            selectedStation = station
            isPresented = false
          }.shadow(radius: 2)
        }.listStyle(.plain)
          .searchable(
            text: $searchTerm,
            placement: .automatic,
            prompt: "Search stations"
          )
          .overlay {
            if sortedStationEntries.isEmpty, !searchTerm.isEmpty {
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
