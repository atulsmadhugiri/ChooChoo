import Foundation

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
        let lastStation = tripUpdate.stopTimeUpdate.last
        if let lastStation {
          let terminalStation = String(lastStation.stopID.dropLast())
          return createTrainArrivalEntry(
            from: stopTimeUpdate,
            trip: tripUpdate.trip,
            stop: stop,
            terminalStation: mtaStopsByGTFSID[terminalStation]?.stopName
              ?? "Unknown Destination."
          )
        }
        return nil
      }
    }
  return arrivalsForStop.sorted { $0.arrivalTime < $1.arrivalTime }
}

func getTrainArrivalsForStopEntry(
  stop: StopEntry,
  feed: [TransitRealtime_FeedEntity]
) -> [TrainArrivalEntry] {

  let tripUpdates = extractTripUpdates(from: feed)
  let arrivalsForStop =
    tripUpdates
    .flatMap { tripUpdate in
      filterStopEntryTimeUpdates(for: stop, from: tripUpdate).compactMap {
        stopTimeUpdate -> TrainArrivalEntry? in
        let lastStation = tripUpdate.stopTimeUpdate.last
        if let lastStation {
          let terminalStation = String(lastStation.stopID.dropLast())
          return createTrainArrivalEntryWithStopEntry(
            from: stopTimeUpdate,
            trip: tripUpdate.trip,
            stop: stop,
            terminalStation: mtaStopsByGTFSID[terminalStation]?.stopName
              ?? "Unknown Destination."
          )
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

private func filterStopEntryTimeUpdates(
  for stop: StopEntry,
  from tripUpdate: TransitRealtime_TripUpdate
) -> [TransitRealtime_TripUpdate.StopTimeUpdate] {
  return tripUpdate.stopTimeUpdate.filter { stopTimeUpdate in
    stopTimeUpdate.stopID.dropLast() == stop.gtfsStopID
  }
}

private func createTrainArrivalEntry(
  from stopTimeUpdate: TransitRealtime_TripUpdate.StopTimeUpdate,
  trip: TransitRealtime_TripDescriptor,
  stop: MTAStop,
  terminalStation: String
) -> TrainArrivalEntry? {

  let tripID = standardizeTripIDForSevenTrain(trip.tripID)

  guard let firstChar = trip.routeID.first,
    let train = MTATrain(rawValue: String(firstChar))
  else { return nil }

  let direction = tripDirection(for: tripID)
  return TrainArrivalEntry(
    id: tripID,
    arrivalTimestamp: stopTimeUpdate.arrival.time != 0
      ? stopTimeUpdate.arrival.time : stopTimeUpdate.departure.time,
    train: train,
    terminalStation: terminalStation,
    direction: direction,
    directionLabel: stop.getLabelFor(direction: direction)
  )
}

private func createTrainArrivalEntryWithStopEntry(
  from stopTimeUpdate: TransitRealtime_TripUpdate.StopTimeUpdate,
  trip: TransitRealtime_TripDescriptor,
  stop: StopEntry,
  terminalStation: String
) -> TrainArrivalEntry? {

  let tripID = standardizeTripIDForSevenTrain(trip.tripID)

  guard let firstChar = trip.routeID.first,
    let train = MTATrain(rawValue: String(firstChar))
  else { return nil }

  let direction = tripDirection(for: tripID)
  return TrainArrivalEntry(
    id: tripID,
    arrivalTimestamp: stopTimeUpdate.arrival.time != 0
      ? stopTimeUpdate.arrival.time : stopTimeUpdate.departure.time,
    train: train,
    terminalStation: terminalStation,
    direction: direction,
    directionLabel: stop.getLabelFor(direction: direction)
  )
}
