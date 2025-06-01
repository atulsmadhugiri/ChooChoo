import Algorithms
import CoreLocation
import Foundation
import SwiftData

@Model
class MTAStation {
  @Attribute(.unique)
  var id: Int
  var name: String
  var stops: [MTAStop] = []
  var pinned: Bool

  init(
    id: Int,
    name: String,
    stops: [MTAStop],
    pinned: Bool = false
  ) {
    self.id = id
    self.name = name
    self.pinned = pinned
    self.stops.append(contentsOf: stops)
  }

  var location: CLLocation {
    guard let firstStop = self.stops.first else { return CLLocation() }
    return CLLocation(
      latitude: firstStop.gtfsLatitude,
      longitude: firstStop.gtfsLongitude)
  }

  var daytimeRoutes: [MTATrain] {
    let sortedRoutes = self.stops.sorted { (stopA, stopB) -> Bool in
      return stopA.daytimeRoutes.first!.rawValue
        < stopB.daytimeRoutes.first!.rawValue
    }

    return sortedRoutes.flatMap(\.daytimeRoutes)
  }

  var lines: [MTALine] {
    return Array(self.daytimeRoutes.map(\.line).uniqued())
  }

  func getLabelFor(direction: TripDirection) -> String {
    let labels = Set(self.stops.map { $0.getLabelFor(direction: direction) })
      .filter { !$0.isEmpty }

    if labels.isEmpty {
      return direction.rawValue
    }

    // Combine common borough labels the way the MTA styles them
    if labels.contains("Downtown") && labels.contains("Brooklyn") {
      return "Downtown & Brooklyn"
    }
    if labels.contains("Uptown") && labels.contains("The Bronx") {
      return "Uptown & The Bronx"
    }
    if labels.contains("Uptown") && labels.contains("Queens") {
      return "Uptown & Queens"
    }

    if labels.count == 1, let only = labels.first {
      return only
    }

    return labels.sorted().joined(separator: " & ")
  }
}

extension MTAStation {
  static func mergeStops(_ stops: [MTAStop]) -> [MTAStation] {
    let stationsToStops = Dictionary(grouping: stops, by: { $0.complexID })
    let stations = stationsToStops.compactMap { (complexID, stationStops) -> MTAStation? in
      guard let station = stationStops.first else { return nil }
      return MTAStation(
        id: complexID,
        name: station.stopName,
        stops: stationStops
      )
    }
    return stations
  }
}

func getFeedData(lines: [MTALine]) async -> [MTALine:
  TransitRealtime_FeedMessage]
{
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

func getArrivals(lines: [MTALine], stops: [MTAStopValue]) async
  -> [TrainArrivalEntry]
{
  let feedData = await getFeedData(lines: lines)

  let arrivalEntries = product(feedData.values, stops).flatMap { feed, stop in
    getTrainArrivalsForStop(stop: stop, feed: feed.entity)
  }

  return arrivalEntries.uniqued(on: \.id)
    .filter { $0.arrivalTime.timeIntervalSinceNow > 0 }
    .sorted { $0.arrivalTime < $1.arrivalTime }
}

private func extractTripAlerts(
  from feed: [TransitRealtime_FeedEntity]
) -> [TransitRealtime_Alert] {
  return feed.compactMap { $0.hasAlert ? $0.alert : nil }
}

func getTripDelays(
  lines: [MTALine],
  stops: [MTAStopValue]
) async -> [TransitRealtime_Alert] {
  let feedData = await getFeedData(lines: lines)
  return feedData.values.flatMap { extractTripAlerts(from: $0.entity) }
}
