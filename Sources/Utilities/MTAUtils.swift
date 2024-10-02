import Foundation

let tripIDToTerminus: [String: String] = tripToTerminusFromCSV()
let shapeIDToTerminus: [String: String] = shapeToTerminusFromCSV()

func getTrainArrivalsForStop(
  stop: MTAStop,
  feed: [TransitRealtime_FeedEntity]
) -> [TrainArrivalEntry] {

  let tripUpdates = extractTripUpdates(from: feed)
  let arrivalsForStop =
    tripUpdates
    .flatMap { tripUpdate in
      filterStopTimeUpdates(for: stop, from: tripUpdate).compactMap {
        stopTimeUpdate -> TrainArrivalEntry? in
        createTrainArrivalEntry(
          from: stopTimeUpdate,
          trip: tripUpdate.trip,
          stop: stop
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
  for stop: MTAStop,
  from tripUpdate: TransitRealtime_TripUpdate
) -> [TransitRealtime_TripUpdate.StopTimeUpdate] {
  return tripUpdate.stopTimeUpdate.filter { stopTimeUpdate in
    stopTimeUpdate.stopID.dropLast() == stop.gtfsStopID
  }
}

private func determineTerminalStation(for tripID: String) -> String? {
  // 1. Process `tripID` to account for mismatches.
  let processedTripID = standardizeTripIDForSevenTrain(tripID)

  // 2. See if there is an exact `tripID` match.
  if let exactTripMatch = tripIDToTerminus[processedTripID] {
    return exactTripMatch
  }

  // 3. See if there is an exact `shapeID` match.
  let shapeID = shapeIDFromTripID(processedTripID)
  if let exactShapeMatch = shapeIDToTerminus[shapeID] {
    return exactShapeMatch
  }

  // 4. See if there is a partial `shapeID` match.
  let partialMatch = shapeIDToTerminus.keys.first { $0.hasPrefix(shapeID) }
  if let terminalStation = partialMatch.flatMap({ shapeIDToTerminus[$0] }) {
    logTerminalStationPartialMatch(for: tripID)
    return terminalStation
  }
  return nil
}

private func adjustTerminalAndDirection(
  for tripID: String,
  currentStop: MTAStop
) -> (terminalStation: String, direction: TripDirection)? {
  let modifiedTripID = swapTripShapeDirection(tripID: tripID)
  guard let oppositeTerminal = tripIDToTerminus[modifiedTripID] else {
    return nil
  }
  let direction = tripDirection(for: tripID).flipped
  return (oppositeTerminal, direction)
}

private func createTrainArrivalEntry(
  from stopTimeUpdate: TransitRealtime_TripUpdate.StopTimeUpdate,
  trip: TransitRealtime_TripDescriptor,
  stop: MTAStop
) -> TrainArrivalEntry? {

  let tripID = standardizeTripIDForSevenTrain(trip.tripID)
  guard let terminalStation = determineTerminalStation(for: tripID) else {
    logTerminalStationMismatch(for: trip.tripID)
    return nil
  }

  guard let firstChar = trip.routeID.first,
    let train = MTATrain(rawValue: String(firstChar))
  else { return nil }

  var finalTerminalStation = terminalStation
  var direction = tripDirection(for: tripID)
  if terminalStation == stop.stopName {
    guard
      let adjusted = adjustTerminalAndDirection(for: tripID, currentStop: stop)
    else { return nil }
    finalTerminalStation = adjusted.terminalStation
    direction = adjusted.direction
  }

  return TrainArrivalEntry(
    id: tripID,
    arrivalTimestamp: stopTimeUpdate.arrival.time != 0
      ? stopTimeUpdate.arrival.time : stopTimeUpdate.departure.time,
    train: train,
    terminalStation: finalTerminalStation,
    direction: direction,
    directionLabel: stop.getLabelFor(direction: direction)
  )
}
