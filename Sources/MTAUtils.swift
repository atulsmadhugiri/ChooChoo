import Foundation
import PostHog

let tripIDToTerminus: [String: String] = tripToTerminusFromCSV()
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

private func logTerminalStationMismatch(for tripID: String) {
  PostHogSDK.shared.capture(
    "terminal_station_mismatch",
    properties: ["tripID": tripID]
  )
  print("tripID without match: \(tripID)")
}

private func determineTerminalStation(for tripID: String) -> String? {
  if let exactMatch = tripIDToTerminus[tripID] {
    return exactMatch
  }
  let partialMatch = tripIDToTerminus.keys.first { $0.hasPrefix(tripID) }
  return partialMatch.flatMap { tripIDToTerminus[$0] }
}

private func adjustTerminalAndDirection(
  for tripID: String,
  currentStop: MTAStop
) -> (terminalStation: String, direction: TripDirection)? {
  let modifiedTripID = swapTripShapeDirection(tripID: tripID)
  guard let oppositeTerminal = tripIDToTerminus[modifiedTripID] else {
    return nil
  }
  let direction = tripDirection(for: modifiedTripID)
  return (oppositeTerminal, direction)
}

private func createTrainArrivalEntry(
  from stopTimeUpdate: TransitRealtime_TripUpdate.StopTimeUpdate,
  trip: TransitRealtime_TripDescriptor,
  stop: MTAStop
) -> TrainArrivalEntry? {

  let tripID = trip.tripID
  guard let terminalStation = determineTerminalStation(for: tripID) else {
    logTerminalStationMismatch(for: tripID)
    return nil
  }
  guard let train = MTATrain(rawValue: trip.routeID) else { return nil }

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
    arrivalTimestamp: stopTimeUpdate.arrival.time,
    train: train,
    terminalStation: finalTerminalStation,
    direction: direction,
    directionLabel: stop.getLabelFor(direction: direction)
  )
}
