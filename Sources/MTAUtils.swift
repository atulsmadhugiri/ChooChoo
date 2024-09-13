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

func getStationsWith(id: Int) -> [MTAStop] {
  return mtaStops.filter { $0.stationID == id }
}

func getLinesFor(station: MTAStation) -> [MTALine] {
  let routes = station.daytimeRoutes
  let lines = routes.map { $0.line }
  let uniqueLines = Set(lines)
  return Array(uniqueLines)
}

func getFeedDataFor(station: MTAStation)
  async -> [MTALine: TransitRealtime_FeedMessage]
{
  let lines = getLinesFor(station: station)
  var results = [MTALine: TransitRealtime_FeedMessage]()

  await withTaskGroup(of: (MTALine, TransitRealtime_FeedMessage)?.self) {
    group in

    for line in lines {
      group.addTask {
        do {
          let data = try await NetworkUtils.sendNetworkRequest(
            to: line.endpoint
          )
          let feed = try TransitRealtime_FeedMessage(serializedBytes: data)
          return (line, feed)
        } catch {
          print("Failed to fetch feed for line \(line): \(error)")
          return nil
        }
      }
    }

    for await taskResult in group {
      if let (line, feed) = taskResult {
        results[line] = feed
      }
    }

  }
  return results
}

func getArrivalsFor(station: MTAStation) async -> [TrainArrivalEntry] {
  let feedData = await getFeedDataFor(station: station)

  let arrivalEntries = feedData.values.flatMap { feed in
    station.stops.flatMap { stop in
      getTrainArrivalsForStop(stop: stop, feed: feed.entity)
    }
  }

  return
    arrivalEntries
    .filter { $0.arrivalTime.timeIntervalSinceNow > 0 }
    .sorted { $0.arrivalTime < $1.arrivalTime }
}
