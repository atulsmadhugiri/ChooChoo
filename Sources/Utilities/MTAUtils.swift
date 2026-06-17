import Foundation

func parseMTARealtimeFeed(
  from data: Data
) throws -> TransitRealtime_FeedMessage {
  try TransitRealtime_FeedMessage(
    serializedBytes: data,
    extensions: Nyct_u45Subway_Extensions
  )
}

public func getTrainArrivalsForStop(
  stop: MTAStopValue,
  feedData: Data,
  stopNamesByGTFSID: [String: String]
) throws -> [TrainArrivalEntry] {
  let feed = try parseMTARealtimeFeed(from: feedData)
  return getTrainArrivalsForStop(
    stop: stop,
    feed: feed.entity,
    stopNamesByGTFSID: stopNamesByGTFSID
  )
}

func getTrainArrivalsForStop(
  stop: MTAStopValue,
  feed: [TransitRealtime_FeedEntity],
  stopNamesByGTFSID: [String: String]
) -> [TrainArrivalEntry] {

  let tripUpdates = extractTripUpdates(from: feed)
  let arrivalsForStop =
    tripUpdates
    .flatMap { tripUpdate in
      let terminalStation = terminalStationName(
        for: tripUpdate,
        stopNamesByGTFSID: stopNamesByGTFSID
      )
      return filterStopTimeUpdates(for: stop, from: tripUpdate).compactMap {
        stopTimeUpdate in
        createTrainArrivalEntry(
          from: stopTimeUpdate,
          trip: tripUpdate.trip,
          stop: stop,
          terminalStation: terminalStation
        )
      }
    }
  return arrivalsForStop.sorted { $0.arrivalTime < $1.arrivalTime }
}

private func extractTripUpdates(
  from feed: [TransitRealtime_FeedEntity]
) -> [TransitRealtime_TripUpdate] {
  return feed.compactMap { $0.hasTripUpdate ? $0.tripUpdate : nil }
}

private func filterStopTimeUpdates(
  for stop: MTAStopValue,
  from tripUpdate: TransitRealtime_TripUpdate
) -> [TransitRealtime_TripUpdate.StopTimeUpdate] {
  return tripUpdate.stopTimeUpdate.filter { stopTimeUpdate in
    guard stopTimeUpdate.isUsableArrival else { return false }
    return GTFSStopID(stopTimeUpdate.stopID).baseID == stop.gtfsStopID
  }
}

private func createTrainArrivalEntry(
  from stopTimeUpdate: TransitRealtime_TripUpdate.StopTimeUpdate,
  trip: TransitRealtime_TripDescriptor,
  stop: MTAStopValue,
  terminalStation: String
) -> TrainArrivalEntry? {

  let tripID = standardizeTripIDForSevenTrain(trip.tripID)

  guard let train = MTATrain(routeID: trip.routeID) else { return nil }

  let direction = tripDirection(for: trip, fallbackTripID: tripID)
  guard let arrivalTimestamp = stopTimeUpdate.bestArrivalTimestamp else {
    return nil
  }

  return TrainArrivalEntry(
    id: "\(tripID)-\(stopTimeUpdate.stopID)-\(arrivalTimestamp)",
    tripID: tripID,
    stopID: stopTimeUpdate.stopID,
    arrivalTimestamp: arrivalTimestamp,
    train: train,
    terminalStation: terminalStation,
    direction: direction,
    directionLabel: stop.getLabelFor(direction: direction)
  )
}

private func terminalStationName(
  for tripUpdate: TransitRealtime_TripUpdate,
  stopNamesByGTFSID: [String: String]
) -> String {
  if tripUpdate.stopTimeUpdate.last?.isUsableArrival == false,
    let fallback = fallbackTerminalStationName(
      for: tripUpdate.trip,
      stopNamesByGTFSID: stopNamesByGTFSID
    )
  {
    return fallback
  }

  if let terminalStopID = tripUpdate.stopTimeUpdate
    .last(where: \.isUsableArrival)?
    .baseStopID,
    let terminal = stopNamesByGTFSID[terminalStopID]
  {
    return terminal
  }

  return fallbackTerminalStationName(
    for: tripUpdate.trip,
    stopNamesByGTFSID: stopNamesByGTFSID
  ) ?? "Unknown Destination."
}

private func fallbackTerminalStationName(
  for trip: TransitRealtime_TripDescriptor,
  stopNamesByGTFSID: [String: String]
) -> String? {
  let tripID = standardizeTripIDForSevenTrain(trip.tripID)
  let direction = tripDirection(for: trip, fallbackTripID: tripID)
  return MTARouteID(rawValue: trip.routeID)?
    .terminalStopID(for: direction)
    .flatMap { stopNamesByGTFSID[$0] }
}

private func tripDirection(
  for trip: TransitRealtime_TripDescriptor,
  fallbackTripID: String
) -> TripDirection {
  if trip.hasNyctTripDescriptor, trip.nyctTripDescriptor.hasDirection {
    switch trip.nyctTripDescriptor.direction {
    case .north:
      return .north
    case .south:
      return .south
    case .east, .west:
      break
    }
  }

  return tripDirection(for: fallbackTripID)
}

extension TransitRealtime_TripUpdate.StopTimeUpdate {
  fileprivate var baseStopID: String {
    GTFSStopID(stopID).baseID
  }

  fileprivate var bestArrivalTimestamp: Int64? {
    if hasArrival, arrival.time > 0 {
      return arrival.time
    }
    if hasDeparture, departure.time > 0 {
      return departure.time
    }
    return nil
  }

  fileprivate var isUsableArrival: Bool {
    guard !stopID.isEmpty else { return false }

    switch scheduleRelationship {
    case .scheduled:
      return bestArrivalTimestamp != nil
    case .skipped, .noData:
      return false
    }
  }
}

let MTAServiceAlertFeedURL =
  "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/camsys%2Fsubway-alerts"

func getServiceAlerts() async -> [TransitRealtime_Alert] {
  do {
    let data = try await NetworkUtils.sendNetworkRequest(
      to: MTAServiceAlertFeedURL)
    let feed = try TransitRealtime_FeedMessage(serializedBytes: data)
    return feed.entity.compactMap { $0.hasAlert ? $0.alert : nil }
  } catch {
    print("Failed to fetch data from MTA Service Alerts feed.")
    return []
  }
}

func timeRangesToServiceAlertPeriods(
  timeRanges: [TransitRealtime_TimeRange]
) -> [MTAServiceAlertTimeRange] {
  guard !timeRanges.isEmpty else {
    return [MTAServiceAlertTimeRange(start: nil, end: nil)]
  }

  return timeRanges.compactMap { timeRange in
    let start = timeRange.hasStart
      ? Date(timeIntervalSince1970: Double(timeRange.start)) : nil
    let end = timeRange.hasEnd
      ? Date(timeIntervalSince1970: Double(timeRange.end)) : nil
    if start == nil, end == nil {
      return MTAServiceAlertTimeRange(start: nil, end: nil)
    }
    guard let start, let end else {
      return MTAServiceAlertTimeRange(start: start, end: end)
    }
    guard start <= end else { return nil }
    return MTAServiceAlertTimeRange(start: start, end: end)
  }
}

func constructServiceAlertsForStop() async -> [String: [MTAServiceAlert]] {
  let serviceAlerts = await getServiceAlerts()
  return constructServiceAlerts(from: serviceAlerts)
}

func constructServiceAlerts(
  from serviceAlerts: [TransitRealtime_Alert]
) -> [String: [MTAServiceAlert]] {
  let mtaServiceAlerts = serviceAlerts.flatMap { alert -> [MTAServiceAlert] in
    guard let headerText = alert.headerText.translation.first(where: \.hasText)?.text,
      !headerText.isEmpty
    else {
      return []
    }
    let descriptionText = alert.descriptionText.translation.first(where: \.hasText)?.text

    let stopIDs = Set(alert.informedEntity.compactMap { entity in
      entity.hasStopID ? GTFSStopID(entity.stopID).baseID : nil
    })

    return stopIDs.sorted().map { stopID in
      return MTAServiceAlert(
        stopID: stopID,
        header: headerText,
        description: descriptionText,
        activePeriod: timeRangesToServiceAlertPeriods(timeRanges: alert.activePeriod)
      )
    }
  }

  return Dictionary(grouping: mtaServiceAlerts, by: { $0.stopID })
}
