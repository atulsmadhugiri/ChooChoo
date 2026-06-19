import Foundation

func parseMTARealtimeFeed(
  from data: Data
) throws -> TransitRealtime_FeedMessage {
  try TransitRealtime_FeedMessage(
    serializedBytes: data,
    extensions: Nyct_u45Subway_Extensions
  )
}

public func getTrainArrivalsForStops(
  stops: [MTAStopValue],
  feedData: Data,
  stopNamesByGTFSID: [String: String]
) throws -> [TrainArrivalEntry] {
  let feed = try parseMTARealtimeFeed(from: feedData)
  return getTrainArrivalsForStops(
    stops: stops,
    feedMessages: [feed],
    stopNamesByGTFSID: stopNamesByGTFSID
  )
}

func getTrainArrivalsForStops(
  stops: [MTAStopValue],
  feedMessages: [TransitRealtime_FeedMessage],
  stopNamesByGTFSID: [String: String]
) -> [TrainArrivalEntry] {
  guard let context = TrainArrivalParseContext(
    stops: stops,
    stopNamesByGTFSID: stopNamesByGTFSID
  ) else {
    return []
  }

  var arrivals: [TrainArrivalEntry] = []
  for feed in feedMessages {
    arrivals.append(contentsOf: trainArrivals(in: feed, context: context))
  }

  return arrivals.sorted { $0.arrivalTime < $1.arrivalTime }
}

func getTrainArrivalsForStops(
  stops: [MTAStopValue],
  feed: [TransitRealtime_FeedEntity],
  stopNamesByGTFSID: [String: String]
) -> [TrainArrivalEntry] {
  guard let context = TrainArrivalParseContext(
    stops: stops,
    stopNamesByGTFSID: stopNamesByGTFSID
  ) else {
    return []
  }

  return trainArrivals(
    in: feed,
    vehicleStatesByTripID: vehicleStatesByTripID(in: feed),
    context: context
  )
    .sorted { $0.arrivalTime < $1.arrivalTime }
}

private struct TrainArrivalParseContext {
  let stopsByGTFSID: [String: MTAStopValue]
  let stopNamesByGTFSID: [String: String]

  init?(stops: [MTAStopValue], stopNamesByGTFSID: [String: String]) {
    guard !stops.isEmpty else { return nil }
    self.stopsByGTFSID = Dictionary(
      stops.map { ($0.gtfsStopID, $0) },
      uniquingKeysWith: { first, _ in first }
    )
    self.stopNamesByGTFSID = stopNamesByGTFSID
  }
}

private func trainArrivals(
  in feed: TransitRealtime_FeedMessage,
  context: TrainArrivalParseContext
) -> [TrainArrivalEntry] {
  trainArrivals(
    in: feed.entity,
    vehicleStatesByTripID: vehicleStatesByTripID(in: feed.entity),
    context: context
  )
}

private func trainArrivals(
  in feed: [TransitRealtime_FeedEntity],
  vehicleStatesByTripID: [String: VehicleStopState],
  context: TrainArrivalParseContext
) -> [TrainArrivalEntry] {
  var arrivals: [TrainArrivalEntry] = []
  for entity in feed where entity.hasTripUpdate {
    let tripUpdate = entity.tripUpdate
    let tripID = standardizeTripIDForSevenTrain(tripUpdate.trip.tripID)
    let terminalStation = terminalStationName(
      for: tripUpdate,
      stopNamesByGTFSID: context.stopNamesByGTFSID
    )

    for stopTimeUpdate in tripUpdate.stopTimeUpdate {
      guard stopTimeUpdate.isUsableArrival,
        let stop = context.stopsByGTFSID[stopTimeUpdate.baseStopID],
        let arrival = createTrainArrivalEntry(
          from: stopTimeUpdate,
          trip: tripUpdate.trip,
          stop: stop,
          terminalStation: terminalStation,
          vehicleState: vehicleStatesByTripID[tripID]
        )
      else {
        continue
      }
      arrivals.append(arrival)
    }
  }

  return arrivals
}

private struct VehicleStopState {
  let stopID: String
  let status: TrainArrivalVehicleStatus
  let timestamp: UInt64?

  func matches(stopID selectedStopID: String) -> Bool {
    if stopID == selectedStopID { return true }

    let currentStop = GTFSStopID(stopID)
    let selectedStop = GTFSStopID(selectedStopID)
    guard currentStop.baseID == selectedStop.baseID else { return false }

    return currentStop.direction == nil
      || selectedStop.direction == nil
      || currentStop.direction == selectedStop.direction
  }
}

private func vehicleStatesByTripID(
  in feed: [TransitRealtime_FeedEntity]
) -> [String: VehicleStopState] {
  var states: [String: VehicleStopState] = [:]

  for entity in feed where entity.hasVehicle {
    let vehicle = entity.vehicle
    guard vehicle.hasTrip,
      !vehicle.trip.tripID.isEmpty,
      vehicle.hasStopID,
      !vehicle.stopID.isEmpty
    else {
      continue
    }

    let tripID = standardizeTripIDForSevenTrain(vehicle.trip.tripID)
    let state = VehicleStopState(
      stopID: vehicle.stopID,
      status: TrainArrivalVehicleStatus(vehicle.currentStatus),
      timestamp: vehicle.hasTimestamp ? vehicle.timestamp : nil
    )

    guard let existingState = states[tripID] else {
      states[tripID] = state
      continue
    }

    if state.timestamp ?? 0 >= existingState.timestamp ?? 0 {
      states[tripID] = state
    }
  }

  return states
}

private func createTrainArrivalEntry(
  from stopTimeUpdate: TransitRealtime_TripUpdate.StopTimeUpdate,
  trip: TransitRealtime_TripDescriptor,
  stop: MTAStopValue,
  terminalStation: String,
  vehicleState: VehicleStopState?
) -> TrainArrivalEntry? {

  let tripID = standardizeTripIDForSevenTrain(trip.tripID)

  guard let train = MTATrain(routeID: trip.routeID) else { return nil }

  let direction = tripDirection(
    for: trip,
    stopID: stopTimeUpdate.stopID,
    fallbackTripID: tripID
  )
  guard let displayTimestamp = stopTimeUpdate.displayTimestamp else {
    return nil
  }
  let vehicleStatus = vehicleState.flatMap { state in
    state.matches(stopID: stopTimeUpdate.stopID) ? state.status : nil
  }

  return TrainArrivalEntry(
    id: "\(tripID)-\(stopTimeUpdate.stopID)-\(displayTimestamp)",
    tripID: tripID,
    stopID: stopTimeUpdate.stopID,
    arrivalTimestamp: stopTimeUpdate.arrivalTimestamp,
    departureTimestamp: stopTimeUpdate.departureTimestamp,
    vehicleStatus: vehicleStatus,
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
      stopID: tripUpdate.stopTimeUpdate.last(where: \.isUsableArrival)?.stopID,
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
    stopID: tripUpdate.stopTimeUpdate.last(where: \.isUsableArrival)?.stopID,
    stopNamesByGTFSID: stopNamesByGTFSID
  ) ?? "Unknown Destination."
}

private func fallbackTerminalStationName(
  for trip: TransitRealtime_TripDescriptor,
  stopID: String?,
  stopNamesByGTFSID: [String: String]
) -> String? {
  let tripID = standardizeTripIDForSevenTrain(trip.tripID)
  let direction = tripDirection(
    for: trip,
    stopID: stopID,
    fallbackTripID: tripID
  )
  return MTATrain.terminalStationName(
    routeID: trip.routeID,
    direction: direction,
    stopNamesByGTFSID: stopNamesByGTFSID
  )
}

private func tripDirection(
  for trip: TransitRealtime_TripDescriptor,
  stopID: String? = nil,
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

  if let stopIDDirection = stopID.map(GTFSStopID.init)?.direction {
    return stopIDDirection
  }

  return tripDirectionFromTripIDSuffix(fallbackTripID) ?? .north
}

extension TransitRealtime_TripUpdate.StopTimeUpdate {
  fileprivate var baseStopID: String {
    GTFSStopID(stopID).baseID
  }

  fileprivate var arrivalTimestamp: Int64? {
    if hasArrival, arrival.time > 0 {
      return arrival.time
    }
    return nil
  }

  fileprivate var departureTimestamp: Int64? {
    if hasDeparture, departure.time > 0 {
      return departure.time
    }
    return nil
  }

  fileprivate var displayTimestamp: Int64? {
    arrivalTimestamp ?? departureTimestamp
  }

  fileprivate var isUsableArrival: Bool {
    guard !stopID.isEmpty else { return false }

    switch scheduleRelationship {
    case .scheduled:
      return displayTimestamp != nil
    case .skipped, .noData:
      return false
    }
  }
}

private extension TrainArrivalVehicleStatus {
  init(_ status: TransitRealtime_VehiclePosition.VehicleStopStatus) {
    switch status {
    case .incomingAt:
      self = .incomingAt
    case .stoppedAt:
      self = .stoppedAt
    case .inTransitTo:
      self = .inTransitTo
    }
  }
}

func getServiceAlerts(
  feedClient: MTAFeedClient = .shared
) async -> [TransitRealtime_Alert] {
  do {
    return try await fetchMTAServiceAlerts(using: feedClient)
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
    if let start, let end, start > end { return nil }
    return MTAServiceAlertTimeRange(start: start, end: end)
  }
}

func constructServiceAlertsForStop(
  feedClient: MTAFeedClient = .shared
) async -> MTAServiceAlerts {
  let serviceAlerts = await getServiceAlerts(feedClient: feedClient)
  return constructServiceAlerts(from: serviceAlerts)
}

func constructServiceAlerts(
  from serviceAlerts: [TransitRealtime_Alert],
  now: Date = Date()
) -> MTAServiceAlerts {
  let mtaServiceAlerts = serviceAlerts.compactMap { alert -> MTAServiceAlert? in
    guard let headerText = alert.headerText.translation.first(where: \.hasText)?.text,
      !headerText.isEmpty
    else {
      return nil
    }
    let descriptionText = alert.descriptionText.translation.first(where: \.hasText)?.text

    let stopIDs = Set(alert.informedEntity.compactMap { entity in
      entity.hasStopID ? GTFSStopID(entity.stopID).baseID : nil
    })
    let routes = Set(alert.informedEntity.compactMap { entity in
      entity.hasRouteID ? MTATrain(routeID: entity.routeID) : nil
    })
    guard !stopIDs.isEmpty || !routes.isEmpty else {
      return nil
    }

    let activePeriod = timeRangesToServiceAlertPeriods(timeRanges: alert.activePeriod)
    guard activePeriod.contains(where: { $0.isRelevant(at: now) }) else {
      return nil
    }

    return MTAServiceAlert(
      stopIDs: stopIDs,
      routes: routes,
      header: headerText,
      description: descriptionText,
      activePeriod: activePeriod
    )
  }

  return MTAServiceAlerts(mtaServiceAlerts)
}
