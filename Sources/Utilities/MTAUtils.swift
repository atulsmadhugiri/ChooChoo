import Foundation

func getTrainArrivalsForStop(
  stop: MTAStopValue,
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
    stopTimeUpdate.stopID.dropLast() == stop.gtfsStopID
  }
}

private func createTrainArrivalEntry(
  from stopTimeUpdate: TransitRealtime_TripUpdate.StopTimeUpdate,
  trip: TransitRealtime_TripDescriptor,
  stop: MTAStopValue,
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

func constructServiceAlertsForStop() async -> [String: [MTAServiceAlert]] {
  let serviceAlerts = await getServiceAlerts()

  let mtaServiceAlerts = serviceAlerts.flatMap { alert -> [MTAServiceAlert] in
    guard let headerText = alert.headerText.translation.first?.text,
      let descriptionText = alert.descriptionText.translation.first?.text
    else { return [] }

    return alert.informedEntity.compactMap { entity in
      guard entity.hasStopID else { return nil }
      let stopID = entity.stopID
      return MTAServiceAlert(
        stopID: stopID,
        header: headerText,
        description: descriptionText,
        activePeriod: []
      )
    }
  }

  return Dictionary(grouping: mtaServiceAlerts, by: { $0.stopID })
}
