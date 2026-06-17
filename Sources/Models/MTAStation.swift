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
    let sortedStops = self.stops.sorted { stopA, stopB -> Bool in
      let firstRouteA = stopA.daytimeRoutes.first?.rawValue ?? stopA.daytimeRoutesString
      let firstRouteB = stopB.daytimeRoutes.first?.rawValue ?? stopB.daytimeRoutesString
      if firstRouteA != firstRouteB {
        return firstRouteA < firstRouteB
      }
      return stopA.gtfsStopID < stopB.gtfsStopID
    }

    return Array(sortedStops.flatMap(\.daytimeRoutes).uniqued())
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

  func serviceAlerts(in alertsByStopID: [String: [MTAServiceAlert]]) -> [MTAServiceAlert] {
    stops.flatMap { stop in
      alertsByStopID[GTFSStopID(stop.gtfsStopID).baseID] ?? []
    }
  }

  func snapshot(stopNamesByGTFSID: [String: String]) -> MTAStationSnapshot {
    MTAStationSnapshot(
      lines: lines,
      stops: stops.map(\.value),
      stopNamesByGTFSID: stopNamesByGTFSID
    )
  }
}

extension MTAStation {
  static func mergeStops(
    _ stops: [MTAStop],
    pinnedStationIDs: Set<Int> = []
  ) -> [MTAStation] {
    let stationsToStops = Dictionary(grouping: stops, by: { $0.complexID })
    let stations = stationsToStops.compactMap { (complexID, stationStops) -> MTAStation? in
      guard let station = stationStops.first else { return nil }
      return MTAStation(
        id: complexID,
        name: station.stopName,
        stops: stationStops,
        pinned: pinnedStationIDs.contains(complexID)
      )
    }
    return stations
  }

  static func stopNamesByGTFSID(from stations: [MTAStation]) -> [String: String] {
    Dictionary(
      stations.flatMap(\.stops).map { ($0.gtfsStopID, $0.stopName) },
      uniquingKeysWith: { first, _ in first }
    )
  }
}

func getFeedData(
  lines: [MTALine],
  feedClient: MTAFeedClient = .shared
) async -> [MTALine:
  TransitRealtime_FeedMessage]
{
  guard !lines.isEmpty else { return [:] }
  var results = [MTALine: TransitRealtime_FeedMessage]()

  await withTaskGroup(of: (MTALine, [Data])?.self) {
    group in

    for line in lines {
      group.addTask {
        do {
          let payloads = try await fetchMTARealtimePayloads(
            from: line.endpoints,
            using: feedClient
          )
          return (line, payloads)
        } catch {
          print("Failed to fetch feed for line \(line): \(error)")
          return nil
        }
      }
    }

    for await taskResult in group {
      if let (line, payloads) = taskResult {
        do {
          results[line] = try decodeMTARealtimeFeeds(from: payloads)
        } catch {
          print("Failed to decode feed for line \(line): \(error)")
        }
      }
    }

  }
  return results
}

func getArrivals(
  lines: [MTALine],
  stops: [MTAStopValue],
  stopNamesByGTFSID: [String: String],
  feedClient: MTAFeedClient = .shared
) async
  -> [TrainArrivalEntry]
{
  await getArrivals(
    for: MTAStationSnapshot(
      lines: lines,
      stops: stops,
      stopNamesByGTFSID: stopNamesByGTFSID
    ),
    feedClient: feedClient
  )
}

func getArrivals(
  for station: MTAStationSnapshot,
  feedClient: MTAFeedClient = .shared
) async -> [TrainArrivalEntry] {
  let lines = station.lines
  let stops = station.stops
  guard !lines.isEmpty, !stops.isEmpty else { return [] }

  let feedData = await getFeedData(lines: lines, feedClient: feedClient)
  let now = Date()

  let arrivalEntries = product(feedData.values, stops).flatMap { feed, stop in
    getTrainArrivalsForStop(
      stop: stop,
      feed: feed.entity,
      stopNamesByGTFSID: station.stopNamesByGTFSID
    )
  }

  return arrivalEntries.uniqued(on: \.id)
    .filter { $0.arrivalTime > now }
    .sorted { $0.arrivalTime < $1.arrivalTime }
}

private func extractTripAlerts(
  from feed: [TransitRealtime_FeedEntity]
) -> [TransitRealtime_Alert] {
  return feed.compactMap { $0.hasAlert ? $0.alert : nil }
}

func getTripDelays(
  lines: [MTALine],
  stops: [MTAStopValue],
  feedClient: MTAFeedClient = .shared
) async -> [TransitRealtime_Alert] {
  let feedData = await getFeedData(lines: lines, feedClient: feedClient)
  return feedData.values.flatMap { extractTripAlerts(from: $0.entity) }
}
