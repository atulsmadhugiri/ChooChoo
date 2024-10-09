import CoreLocation
import Foundation
import SwiftData

@Model
class StationEntry {
  @Attribute(.unique)
  var id: Int
  var name: String
  var stops: [StopEntry]

  init(id: Int, name: String, stops: [StopEntry]) {
    self.id = id
    self.name = name
    self.stops = stops
  }

  var location: CLLocation {
    CLLocation(
      latitude: self.stops.first!.gtfsLatitude,
      longitude: self.stops.first!.gtfsLongitude)
  }

  var daytimeRoutes: [MTATrain] {
    let sortedRoutes = self.stops.sorted { (stopA, stopB) -> Bool in
      return stopA.daytimeRoutes.first!.rawValue
        < stopB.daytimeRoutes.first!.rawValue
    }

    return sortedRoutes.flatMap { $0.daytimeRoutes }
  }

  var lines: [MTALine] {
    let routes = self.daytimeRoutes
    let lines = routes.map { $0.line }
    let uniqueLines = Set(lines)
    return Array(uniqueLines)
  }
}

extension StationEntry {
  func mergeStops(_ stops: [StopEntry]) -> [StationEntry] {
    let stationsToStops = Dictionary(grouping: stops, by: { $0.complexID })

    let stations = stationsToStops.map { (complexID, stationStops) in
      let stationName = stationStops.first?.stopName ?? "Unknown"
      return StationEntry(
        id: complexID,
        name: stationName,
        stops: stationStops
      )
    }
    return stations
  }
}
