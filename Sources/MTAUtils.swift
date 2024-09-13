import Foundation
import SwiftUI

enum MTALine {
  case oneTwoThree
  case fourFiveSix
  case seven
  case ace
  case bdfm
  case g
  case jz
  case l
  case nqrw
  case s

  var endpoint: String {
    switch self {
    case .ace:
      return
        "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-ace"
    case .bdfm:
      return
        "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-bdfm"
    case .g:
      return
        "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-g"
    case .jz:
      return
        "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-jz"
    case .nqrw:
      return
        "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-nqrw"
    case .l:
      return
        "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-l"
    default:
      return
        "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs"
    }
  }
}

func getColorForLine(line: MTALine) -> Color {
  switch line {
  case .oneTwoThree:
    return Color(UIColor(named: "MTAColors/123")!)
  case .fourFiveSix:
    return Color(UIColor(named: "MTAColors/456")!)
  case .seven:
    return Color(UIColor(named: "MTAColors/7")!)
  case .ace:
    return Color(UIColor(named: "MTAColors/ACE")!)
  case .bdfm:
    return Color(UIColor(named: "MTAColors/BDFM")!)
  case .g:
    return Color(UIColor(named: "MTAColors/G")!)
  case .jz:
    return Color(UIColor(named: "MTAColors/JZ")!)
  case .l:
    return Color(UIColor(named: "MTAColors/L")!)
  case .nqrw:
    return Color(UIColor(named: "MTAColors/NQRW")!)
  case .s:
    return Color(UIColor(named: "MTAColors/S")!)
  }
}

enum MTATrain: String, CaseIterable, Identifiable {
  case one = "1"
  case two = "2"
  case three = "3"
  case four = "4"
  case five = "5"
  case six = "6"
  case seven = "7"
  case a = "A"
  case c = "C"
  case e = "E"
  case b = "B"
  case d = "D"
  case f = "F"
  case m = "M"
  case g = "G"
  case j = "J"
  case z = "Z"
  case l = "L"
  case n = "N"
  case q = "Q"
  case r = "R"
  case w = "W"
  case s = "S"

  var id: String { self.rawValue }
}

func getLineForTrain(train: MTATrain) -> MTALine {
  switch train {
  case .a, .c, .e:
    return .ace
  case .one, .two, .three:
    return .oneTwoThree
  case .four, .five, .six:
    return .fourFiveSix
  case .seven:
    return MTALine.seven
  case .b, .d, .f, .m:
    return .bdfm
  case .g:
    return MTALine.g
  case .j, .z:
    return .jz
  case .l:
    return MTALine.l
  case .n, .q, .r, .w:
    return .nqrw
  case .s:
    return MTALine.s
  }
}

func getColorForTrain(train: MTATrain) -> Color {
  let line = getLineForTrain(train: train)
  return getColorForLine(line: line)
}

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

func swapTripShapeDirection(tripID: String) -> String {
  let components = tripID.components(separatedBy: "..")

  guard components.count == 2 else {
    return tripID
  }

  let prefix = components[0]
  let suffix = components[1]

  let modifiedSuffix: String
  if suffix.hasPrefix("N") {
    modifiedSuffix = "S" + suffix.dropFirst()
  } else if suffix.hasPrefix("S") {
    modifiedSuffix = "N" + suffix.dropFirst()
  } else {
    modifiedSuffix = suffix
  }
  return "\(prefix)..\(modifiedSuffix)"
}

enum TripDirection: String {
  case north = "Uptown & The Bronx"
  case south = "Downtown & Brooklyn"
}

func tripDirection(for tripID: String) -> TripDirection {
  let components = tripID.components(separatedBy: "..")
  guard components.count == 2 else {
    return .north
  }

  let suffix = components[1]

  switch suffix.prefix(1) {
  case "N":
    return .north
  default:
    return .south
  }
}

func flip(direction: TripDirection) -> TripDirection {
  if direction == .north {
    return .south
  } else {
    return .north
  }
}

func getStationsWith(id: Int) -> [MTAStop] {
  return mtaStops.filter { $0.stationID == id }
}

func getArrivalsFor(station: MTAStop) async -> [TrainArrivalEntry] {
  guard let train = station.daytimeRoutes.first else { return [] }
  do {
    let data = try await NetworkUtils.sendNetworkRequest(
      to: getLineForTrain(train: train).endpoint)
    let feed = try TransitRealtime_FeedMessage(serializedBytes: data)
    let trainArrivals = getTrainArrivalsForStop(
      stop: station,
      feed: feed.entity
    ).filter { $0.arrivalTime.timeIntervalSinceNow > 0 }
    return trainArrivals
  } catch {
    print("Error fetching realtime data.")
    return []
  }
}

func getLinesFor(station: MTAStation) -> [MTALine] {
  let routes = station.daytimeRoutes
  let lines = routes.map(getLineForTrain)
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
