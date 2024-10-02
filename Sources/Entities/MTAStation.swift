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

extension MTAStation {
  func getArrivals() async -> [TrainArrivalEntry] {
    let feedData = await self.getFeedData()

    let arrivalEntries = feedData.values.flatMap { feed in
      self.stops.flatMap { stop in
        getTrainArrivalsForStop(stop: stop, feed: feed.entity)
      }
    }

    return arrivalEntries.uniqued(on: \.id)
      .filter { $0.arrivalTime.timeIntervalSinceNow > 0 }
      .sorted { $0.arrivalTime < $1.arrivalTime }
  }
}

extension MTAStation {
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

func mergeStops(_ stops: [MTAStop]) -> [MTAStation] {
  let stationToStops = Dictionary(grouping: stops, by: { $0.complexID })

  let stations = stationToStops.map { (complexID, stationStops) in
    let stationName = stationStops.first?.stopName ?? "Unknown"
    return MTAStation(id: complexID, name: stationName, stops: stationStops)
  }

  return stations
}
