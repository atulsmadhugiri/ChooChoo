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
        let arrivalTime = Date(
          timeIntervalSince1970: Double(stopTimeUpdate.arrival.time))
        let train = MTATrain(rawValue: tripUpdate.trip.routeID) ?? .a
        let tripID = tripUpdate.trip.tripID

        if let terminalStation = determineTerminalStation(for: tripID) {
          if terminalStation == stop.stopName {
            let modifiedTripID = swapTripShapeDirection(
              tripID: tripID)
            if let oppositeTerminal = tripIDToTerminus[modifiedTripID] {
              let direction = tripDirection(for: modifiedTripID)
              return TrainArrivalEntry(
                arrivalTime: arrivalTime,
                train: train,
                terminalStation: oppositeTerminal,
                direction: direction,
                directionLabel: stop.getLabelFor(direction: direction)
              )
            }
            return nil
          }
          return TrainArrivalEntry(
            arrivalTime: arrivalTime, train: train,
            terminalStation: terminalStation,
            direction: tripDirection(for: tripID),
            directionLabel: stop.getLabelFor(
              direction: tripDirection(for: tripID))
          )
        } else {
          logTerminalStationMismatch(for: tripID)
        }

        return nil
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
