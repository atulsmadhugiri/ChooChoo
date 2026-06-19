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
    let stopsWithRoutes = stops.map { stop in
      (stop: stop, routes: stop.daytimeRoutes)
    }
    let sortedStops = stopsWithRoutes.sorted { stopA, stopB -> Bool in
      let firstRouteA = stopA.routes.first?.rawValue ?? stopA.stop.daytimeRoutesString
      let firstRouteB = stopB.routes.first?.rawValue ?? stopB.stop.daytimeRoutesString
      if firstRouteA != firstRouteB {
        return firstRouteA < firstRouteB
      }
      return stopA.stop.gtfsStopID < stopB.stop.gtfsStopID
    }

    return sortedStops.flatMap(\.routes).uniqued()
  }

  var lines: [MTALine] {
    return daytimeRoutes.map(\.line).uniqued()
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
    var seen = Set<MTAServiceAlertDisplayKey>()
    return stops.flatMap { stop in
      alertsByStopID[GTFSStopID(stop.gtfsStopID).baseID] ?? []
    }.filter { alert in
      seen.insert(MTAServiceAlertDisplayKey(alert)).inserted
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

private struct MTAServiceAlertDisplayKey: Hashable {
  let header: String
  let description: String?
  let activePeriod: [MTAServiceAlertTimeRange]

  init(_ alert: MTAServiceAlert) {
    self.header = alert.header
    self.description = alert.description
    self.activePeriod = alert.activePeriod
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
) async -> [TransitRealtime_FeedMessage]
{
  await fetchMTARealtimeFeeds(
    from: lines.flatMap(\.endpoints),
    using: feedClient
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

  let arrivalEntries = getTrainArrivalsForStops(
    stops: stops,
    feedMessages: feedData,
    stopNamesByGTFSID: station.stopNamesByGTFSID
  )

  return arrivalEntries.uniqued(by: \.id)
    .filter { $0.isActive(at: now) }
}

private extension Sequence where Element: Hashable {
  func uniqued() -> [Element] {
    var seen = Set<Element>()
    return filter { seen.insert($0).inserted }
  }
}

private extension Sequence {
  func uniqued<ID: Hashable>(by keyPath: KeyPath<Element, ID>) -> [Element] {
    var seen = Set<ID>()
    return filter { seen.insert($0[keyPath: keyPath]).inserted }
  }
}
