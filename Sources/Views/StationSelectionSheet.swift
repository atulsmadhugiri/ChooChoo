import CoreLocation
import SwiftData
import SwiftUI

struct StationWithDistance: Identifiable {
  let station: MTAStation
  let distance: CLLocationDistance?
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

  var sortedStationEntries: [StationWithDistance] {
    let stationDistances = filteredStationEntries.map { station in
      StationWithDistance(
        station: station,
        distance: location.map { $0.distance(from: station.location) }
      )
    }

    return stationDistances.sorted { a, b in
      if a.station.pinned != b.station.pinned {
        return a.station.pinned && !b.station.pinned
      }
      guard let distanceA = a.distance, let distanceB = b.distance else {
        return a.station.name.localizedStandardCompare(b.station.name) == .orderedAscending
      }
      return distanceA < distanceB
    }
  }

  var body: some View {

    NavigationView {
      List(sortedStationEntries) { entry in
        StationSign(
          station: entry.station,
          trains: entry.station.daytimeRoutes,
          distance: entry.distance,
          serviceAlerts: entry.station.serviceAlerts(in: serviceAlerts)
        ).id(entry.id)
          .onTapGesture {
            tapHaptic.impactOccurred()
            selectedStation = entry.station
            isPresented = false
            logStationSelected(entry.station)
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
        location == nil ? "Stations" : "Nearby Stations",
        displayMode: .inline
      )
    }
    .onAppear {
      tapHaptic.prepare()
    }
    .onChange(of: searchTerm) { _, newTerm in
      if !newTerm.isEmpty {
        logSearch(term: newTerm)
      }
    }
  }
}
