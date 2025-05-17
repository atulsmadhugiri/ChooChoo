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

  @Binding var serviceAlerts: [String: [MTAServiceAlert]]

  let tapHaptic = UIImpactFeedbackGenerator(style: .medium)

  var filteredStationEntries: [MTAStation] {
    guard !searchTerm.isEmpty else { return stations }
    return stations.filter {
      $0.name.localizedCaseInsensitiveContains(searchTerm)
    }
  }

  @State private var sortedStationEntries: [StationWithDistance] = []

  func updateSortedStationEntries() {
    guard let location else {
      sortedStationEntries = []
      return
    }

    let stationDistances = filteredStationEntries.map { station in
      StationWithDistance(
        station: station,
        distance: location.distance(from: station.location)
      )
    }

    sortedStationEntries = stationDistances.sorted { a, b in
      if a.station.pinned != b.station.pinned {
        return a.station.pinned && !b.station.pinned
      }
      return a.distance < b.distance
    }
  }

  var body: some View {

    NavigationView {
      List(sortedStationEntries) { entry in
        let alertsForStation: [MTAServiceAlert] = entry.station.stops
          .compactMap { stop in
            serviceAlerts[stop.gtfsStopID]
          }.flatMap { $0 }

        StationSign(
          station: entry.station,
          trains: entry.station.daytimeRoutes,
          distance: entry.distance,
          serviceAlerts: alertsForStation
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
      updateSortedStationEntries()
    }
    .onChange(of: searchTerm) { _ in
      updateSortedStationEntries()
    }
    .onChange(of: stations) { _ in
      updateSortedStationEntries()
    }
  }
}
