import CoreLocation
import SwiftData
import SwiftUI

struct StationWithDistance: Identifiable {
  let station: MTAStation
  let distance: CLLocationDistance
  var id: MTAStation.ID { station.id }
}

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

  var sortedStationEntries: [StationWithDistance] {
    guard let location else { return [] }
    let stationDistances = filteredStationEntries.map { station in
      StationWithDistance(
        station: station,
        distance: location.distance(from: station.location)
      )
    }

    return stationDistances.sorted { a, b in
      if a.station.pinned != b.station.pinned {
        return a.station.pinned && !b.station.pinned
      }
      return a.distance < b.distance
    }
  }

  var body: some View {
    if location != nil {
      NavigationView {
        List(sortedStationEntries) { entry in
          StationSign(
            station: entry.station,
            trains: entry.station.daytimeRoutes,
            distance: entry.distance
          ).id(entry.id)
            .onTapGesture {
              tapHaptic.impactOccurred()
              selectedStation = entry.station
              isPresented = false
            }
            .shadow(radius: 2)
        }
        .listStyle(.plain)
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
      }
      .onAppear {
        tapHaptic.prepare()
      }
    }
  }
}
