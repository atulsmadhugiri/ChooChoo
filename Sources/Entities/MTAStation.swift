import Algorithms
import CoreLocation
import Foundation

struct MTAStation: Identifiable, Equatable {
  let id: Int
  let name: String
  let stops: [MTAStop]

  init(id: Int, name: String, stops: [MTAStop]) {
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
