import CoreLocation
import SwiftData
import SwiftUI

struct StationWithDistance: Identifiable {
  let station: MTAStation
  let distance: CLLocationDistance?
  var id: MTAStation.ID { station.id }
}

struct StationSelectionSheet: View {
  @Query(sort: \MTAStation.name) var stations: [MTAStation]

  var location: CLLocation?
  @State private var searchTerm = ""
  @State private var sheetLocation: CLLocation?
  @Binding var isPresented: Bool
  @Binding var selectedStation: MTAStation?

  let serviceAlerts: [String: [MTAServiceAlert]]

  let tapHaptic = UIImpactFeedbackGenerator(style: .medium)

  var filteredStationEntries: [MTAStation] {
    guard !searchTerm.isEmpty else { return stations }
    return stations.filter {
      $0.name.localizedCaseInsensitiveContains(searchTerm)
    }
  }

  var sortedStationEntries: [StationWithDistance] {
    let distanceLocation = sheetLocation ?? location
    guard let distanceLocation else {
      let entries = filteredStationEntries.map { station in
        StationWithDistance(station: station, distance: nil)
      }
      return entries.filter { $0.station.pinned } + entries.filter { !$0.station.pinned }
    }

    let stationDistances = filteredStationEntries.map { station in
      StationWithDistance(
        station: station,
        distance: distanceLocation.distance(from: station.location)
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
    let stationEntries = sortedStationEntries

    NavigationView {
      List(stationEntries) { entry in
        StationSign(
          station: entry.station,
          distance: entry.distance,
          serviceAlerts: entry.station.serviceAlerts(in: serviceAlerts)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
          .onTapGesture {
            tapHaptic.impactOccurred()
            selectedStation = entry.station
            isPresented = false
          }
          .compositingGroup()
          .shadow(color: .black.opacity(0.14), radius: 2, x: 0, y: 1)
          .listRowInsets(
            EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)
          )
          .listRowSeparator(.hidden)
          .listRowBackground(Color.clear)
      }
      .listStyle(.plain)
      .scrollContentBackground(.hidden)
      .background(Color(.systemGroupedBackground))
      .searchable(
        text: $searchTerm,
        placement: .automatic,
        prompt: "Search stations"
      )
      .overlay {
        if stationEntries.isEmpty, !searchTerm.isEmpty {
          ContentUnavailableView.search(text: searchTerm)
        }
      }
      .navigationBarTitle(
        (sheetLocation ?? location) == nil ? "Stations" : "Nearby Stations",
        displayMode: .inline
      )
    }
    .onAppear {
      sheetLocation = location
    }
    .onChange(of: location) { _, newLocation in
      if sheetLocation == nil {
        sheetLocation = newLocation
      }
    }
  }
}
