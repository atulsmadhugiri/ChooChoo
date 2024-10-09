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
  static func mergeStops(_ stops: [StopEntry]) -> [StationEntry] {
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

extension StationEntry {
  func getFeedData() async -> [MTALine: TransitRealtime_FeedMessage] {
    let lines = self.lines
    var results = [MTALine: TransitRealtime_FeedMessage]()

    await withTaskGroup(of: (MTALine, TransitRealtime_FeedMessage)?.self) {
      group in

      for line in lines {
        group.addTask {
          do {
            let data = try await NetworkUtils.sendNetworkRequest(
              to: line.endpoint
            )
            let feed = try TransitRealtime_FeedMessage(serializedBytes: data)
            return (line, feed)
          } catch {
            print("Failed to fetch feed for line \(line): \(error)")
            return nil
          }
        }
      }

      for await taskResult in group {
        if let (line, feed) = taskResult {
          results[line] = feed
        }
      }

    }
    return results

  }
}
