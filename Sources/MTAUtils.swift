import Foundation
import PostHog

let tripIDToTerminus: [String: String] = tripToTerminusFromCSV()
func getTrainArrivalsForStop(
  stop: MTAStop,
  feed: [TransitRealtime_FeedEntity]
) -> [TrainArrivalEntry] {

  let arrivalsForStop =
    feed
    .compactMap { $0.hasTripUpdate ? $0.tripUpdate : nil }
    .flatMap { tripUpdate in
      tripUpdate.stopTimeUpdate.compactMap {
        stopTimeUpdate -> TrainArrivalEntry? in
        guard
          stopTimeUpdate.stopID.dropLast() == stop.gtfsStopID
        else {
          return nil
        }
        let arrivalTime = Date(
          timeIntervalSince1970: Double(stopTimeUpdate.arrival.time))
        let train = MTATrain(rawValue: tripUpdate.trip.routeID) ?? .a
        let tripID = tripUpdate.trip.tripID

        let partialMatch = tripIDToTerminus.keys.first(where: {
          $0.hasPrefix(tripID)
        })
        if let terminalStation = tripIDToTerminus[tripID]
          ?? tripIDToTerminus[partialMatch ?? ""]
        {
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
          print("tripID without match: \(tripID)")
          PostHogSDK.shared.capture(
            "terminal_station_mismatch",
            properties: ["tripID": tripID])
        }

        return nil
      }
    }
  return arrivalsForStop.sorted { $0.arrivalTime < $1.arrivalTime }
}
