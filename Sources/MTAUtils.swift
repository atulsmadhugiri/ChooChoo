import Foundation

let shapeToTerminus: [String: String] = loadTripsFromCSV()
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

        if let shapeID = tripUpdate.trip.tripID.split(separator: "_").last,
          let terminalStation = shapeToTerminus[String(shapeID)]
        {
          if terminalStation == stop.stopName {
            let modifiedTripID = swapTripShapeDirection(tripID: String(shapeID))
            if let oppositeTerminal = shapeToTerminus[modifiedTripID] {
              let direction = tripDirection(for: modifiedTripID)
              return TrainArrivalEntry(
                arrivalTime: arrivalTime, train: train,
                terminalStation: oppositeTerminal,
                direction: direction)
            }
            return nil
          }
          return TrainArrivalEntry(
            arrivalTime: arrivalTime, train: train,
            terminalStation: terminalStation,
            direction: tripDirection(for: String(shapeID)))
        }
        return nil
      }
    }
  return arrivalsForStop.sorted { $0.arrivalTime < $1.arrivalTime }
}
