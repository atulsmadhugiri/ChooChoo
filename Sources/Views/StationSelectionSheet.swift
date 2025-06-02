import CoreLocation
import SwiftData
import SwiftUI

struct StationWithDistance: Identifiable {
  let station: MTAStation
  let distance: CLLocationDistance
  var id: MTAStation.ID { station.id }
}

enum StationFilter: String, CaseIterable, Identifiable {
  case nearby = "Nearby"
  case favorites = "Favorites"

  var id: Self { self }
}

struct StationSelectionSheet: View {
  @Query var stations: [MTAStation]

  var location: CLLocation?
  @State private var searchTerm = ""
  @State private var selectedFilter: StationFilter = .nearby
  @Binding var isPresented: Bool
  @Binding var selectedStation: MTAStation?

  @Binding var serviceAlerts: [String: [MTAServiceAlert]]

  let tapHaptic = UIImpactFeedbackGenerator(style: .medium)

  var filteredStationEntries: [MTAStation] {
    var filtered = stations
    if selectedFilter == .favorites {
      filtered = filtered.filter(\.pinned)
    }
    if !searchTerm.isEmpty {
      filtered = filtered.filter {
        $0.name.localizedCaseInsensitiveContains(searchTerm)
      }
    }
    return filtered
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

    NavigationView {
      VStack {
        Picker("Filter", selection: $selectedFilter) {
          ForEach(StationFilter.allCases) { filter in
            Text(filter.rawValue).tag(filter)
          }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .padding([.horizontal, .top])

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
      }
      .navigationBarTitle(
        selectedFilter == .favorites ? "Favorite Stations" : "Nearby Stations",
        displayMode: .inline
      )
    }
    .onAppear {
      tapHaptic.prepare()
    }
    .onChange(of: searchTerm) { newTerm in
      if !newTerm.isEmpty {
        logSearch(term: newTerm)
      }
    }
  }
}
