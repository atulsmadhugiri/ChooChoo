import ChooChooCore
import Foundation

struct MTAWebStopResponse: Decodable {
  let groups: [MTAWebGroup]
}

struct MTAWebGroup: Decodable {
  let route: MTAWebRoute
  let headsign: String
  let times: [MTAWebTime]
}

struct MTAWebRoute: Decodable {
  let id: String
}

struct MTAWebTime: Decodable {
  let stopID: String
  let departureFmt: String?
  let tripHeadsign: String?
  let tripID: String?

  enum CodingKeys: String, CodingKey {
    case stopID = "stopId"
    case departureFmt
    case tripHeadsign
    case tripID = "tripId"
  }
}

enum MTAWebArrivalDecoder {
  static func arrivals(
    for stop: MTAStopValue,
    feedData: Data
  ) throws -> [ComparableArrival] {
    let responses = try JSONDecoder().decode([MTAWebStopResponse].self, from: feedData)
    var arrivals: [ComparableArrival] = []
    let dateFormatter = ISO8601DateFormatter()

    for response in responses {
      for group in response.groups {
        let routeID = agencylessID(group.route.id)
        guard let train = MTATrain(routeID: routeID) else { continue }

        for time in group.times {
          let stopID = agencylessID(time.stopID)
          let parsedStopID = GTFSStopID(stopID)
          guard parsedStopID.baseID == stop.gtfsStopID,
            let direction = parsedStopID.direction,
            let departureFmt = time.departureFmt,
            let departure = dateFormatter.date(from: departureFmt)
          else {
            continue
          }

          arrivals.append(ComparableArrival(
            tripID: agencylessID(time.tripID ?? ""),
            stopID: stopID,
            train: train.rawValue,
            arrivalTimestamp: Int64(departure.timeIntervalSince1970),
            terminalStation: time.tripHeadsign ?? group.headsign,
            direction: direction,
            directionLabel: stop.getLabelFor(direction: direction)
          ))
        }
      }
    }

    return arrivals
  }
}

struct MTAJSONFeed: Decodable {
  let entity: [MTAJSONEntity]
}

struct MTAJSONEntity: Decodable {
  let tripUpdate: MTAJSONTripUpdate?

  enum CodingKeys: String, CodingKey {
    case tripUpdate = "trip_update"
  }
}

struct MTAJSONTripUpdate: Decodable {
  let trip: MTAJSONTrip
  let stopTimeUpdate: [MTAJSONStopTimeUpdate]

  enum CodingKeys: String, CodingKey {
    case trip
    case stopTimeUpdate = "stop_time_update"
  }
}

struct MTAJSONTrip: Decodable {
  let tripID: String
  let routeID: String
  let nyctTripDescriptor: MTAJSONNYCTTripDescriptor?

  enum CodingKeys: String, CodingKey {
    case tripID = "trip_id"
    case routeID = "route_id"
    case nyctTripDescriptor = "nyct_trip_descriptor"
  }
}

struct MTAJSONNYCTTripDescriptor: Decodable {
  let direction: Int?
}

struct MTAJSONStopTimeUpdate: Decodable {
  let stopID: String
  let arrival: MTAJSONStopTimeEvent?
  let departure: MTAJSONStopTimeEvent?
  let scheduleRelationship: Int?

  enum CodingKeys: String, CodingKey {
    case stopID = "stop_id"
    case arrival
    case departure
    case scheduleRelationship = "schedule_relationship"
  }

  var baseStopID: String {
    GTFSStopID(stopID).baseID
  }

  var bestArrivalTimestamp: Int64? {
    if let time = arrival?.time, time > 0 {
      return time
    }
    if let time = departure?.time, time > 0 {
      return time
    }
    return nil
  }

  var isUsableArrival: Bool {
    (scheduleRelationship ?? 0) == 0 && bestArrivalTimestamp != nil
  }
}

struct MTAJSONStopTimeEvent: Decodable {
  let time: Int64?
}

enum JSONArrivalDecoder {
  static func arrivals(
    for stop: MTAStopValue,
    feedData: Data,
    stopNameByGTFSID: [String: String]
  ) throws -> [ComparableArrival] {
    let feed = try JSONDecoder().decode(MTAJSONFeed.self, from: feedData)
    let tripUpdates: [MTAJSONTripUpdate] = feed.entity.compactMap { entity in
      entity.tripUpdate
    }

    return tripUpdates.flatMap { tripUpdate in
      let terminalStopID = tripUpdate.stopTimeUpdate
        .last(where: \.isUsableArrival)?
        .baseStopID
      let terminal = terminalStopID.flatMap { stopNameByGTFSID[$0] }
        ?? "Unknown Destination."

      var arrivals: [ComparableArrival] = []
      for stopTimeUpdate in tripUpdate.stopTimeUpdate {
        guard stopTimeUpdate.isUsableArrival,
          stopTimeUpdate.baseStopID == stop.gtfsStopID,
          let timestamp = stopTimeUpdate.bestArrivalTimestamp,
          let train = MTATrain(routeID: tripUpdate.trip.routeID)
        else {
          continue
        }

        let tripID = standardizeTripIDForSevenTrain(tripUpdate.trip.tripID)
        let direction = tripDirection(
          nyctDirection: tripUpdate.trip.nyctTripDescriptor?.direction,
          fallbackTripID: tripID
        )

        arrivals.append(ComparableArrival(
          tripID: tripID,
          stopID: stopTimeUpdate.stopID,
          train: train.rawValue,
          arrivalTimestamp: timestamp,
          terminalStation: terminal,
          direction: direction,
          directionLabel: stop.getLabelFor(direction: direction)
        ))
      }

      return arrivals
    }
  }

  private static func tripDirection(
    nyctDirection: Int?,
    fallbackTripID: String
  ) -> TripDirection {
    switch nyctDirection {
    case 1:
      return .north
    case 3:
      return .south
    default:
      return ChooChooCore.tripDirection(for: fallbackTripID)
    }
  }
}
