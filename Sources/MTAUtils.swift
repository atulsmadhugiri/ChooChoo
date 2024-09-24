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
          tripUpdate: tripUpdate,
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

private func createTrainArrivalEntry(
  from stopTimeUpdate: TransitRealtime_TripUpdate.StopTimeUpdate,
  tripUpdate: TransitRealtime_TripUpdate,
  stop: MTAStop
) -> TrainArrivalEntry? {

  let tripID = tripUpdate.trip.tripID
  guard let terminalStation = determineTerminalStation(for: tripID) else {
    logTerminalStationMismatch(for: tripID)
    return nil
  }

  let arrivalTime = Date(
    timeIntervalSince1970: Double(stopTimeUpdate.arrival.time))

  guard let train = MTATrain(rawValue: tripUpdate.trip.routeID) else {
    return nil
  }

  if terminalStation == stop.stopName {
    let modifiedTripID = swapTripShapeDirection(tripID: tripID)
    guard let oppositeTerminal = tripIDToTerminus[modifiedTripID] else {
      return nil
    }
    let direction = tripDirection(for: modifiedTripID)
    let directionLabel = stop.getLabelFor(direction: direction)

    return TrainArrivalEntry(
      arrivalTime: arrivalTime,
      train: train,
      terminalStation: oppositeTerminal,
      direction: direction,
      directionLabel: directionLabel
    )
  } else {
    let direction = tripDirection(for: tripID)
    let directionLabel = stop.getLabelFor(direction: direction)

    return TrainArrivalEntry(
      arrivalTime: arrivalTime,
      train: train,
      terminalStation: terminalStation,
      direction: direction,
      directionLabel: directionLabel
    )
  }
}
