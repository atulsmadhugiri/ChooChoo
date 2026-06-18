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
            departureTimestamp: Int64(departure.timeIntervalSince1970),
            vehicleStatus: nil,
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
  let vehicle: MTAJSONVehicle?

  enum CodingKeys: String, CodingKey {
    case tripUpdate = "trip_update"
    case vehicle
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

  var arrivalTimestamp: Int64? {
    if let time = arrival?.time, time > 0 {
      return time
    }
    return nil
  }

  var departureTimestamp: Int64? {
    if let time = departure?.time, time > 0 {
      return time
    }
    return nil
  }

  var displayTimestamp: Int64? {
    arrivalTimestamp ?? departureTimestamp
  }

  var isUsableArrival: Bool {
    (scheduleRelationship ?? 0) == 0 && displayTimestamp != nil
  }
}

struct MTAJSONStopTimeEvent: Decodable {
  let time: Int64?
}

struct MTAJSONVehicle: Decodable {
  let trip: MTAJSONTrip
  let currentStatus: Int?
  let stopID: String?
  let timestamp: UInt64?

  enum CodingKeys: String, CodingKey {
    case trip
    case currentStatus = "current_status"
    case stopID = "stop_id"
    case timestamp
  }
}

enum JSONArrivalDecoder {
  static func arrivals(
    for stops: [MTAStopValue],
    feedData: Data,
    stopNameByGTFSID: [String: String]
  ) throws -> [ComparableArrival] {
    let feed = try JSONDecoder().decode(MTAJSONFeed.self, from: feedData)
    let stopsByGTFSID = Dictionary(
      stops.map { ($0.gtfsStopID, $0) },
      uniquingKeysWith: { first, _ in first }
    )
    let tripUpdates: [MTAJSONTripUpdate] = feed.entity.compactMap { entity in
      entity.tripUpdate
    }
    let vehicleStatesByTripID = vehicleStatesByTripID(in: feed.entity)

    return tripUpdates.flatMap { tripUpdate in
      let terminal = terminalStationName(
        for: tripUpdate,
        stopNameByGTFSID: stopNameByGTFSID
      )

      var arrivals: [ComparableArrival] = []
      for stopTimeUpdate in tripUpdate.stopTimeUpdate {
        guard stopTimeUpdate.isUsableArrival,
          let stop = stopsByGTFSID[stopTimeUpdate.baseStopID],
          let timestamp = stopTimeUpdate.displayTimestamp,
          let train = MTATrain(routeID: tripUpdate.trip.routeID)
        else {
          continue
        }

        let tripID = standardizeTripIDForSevenTrain(tripUpdate.trip.tripID)
        let vehicleStatus = vehicleStatesByTripID[tripID].flatMap { state in
          state.matches(stopID: stopTimeUpdate.stopID) ? state.status : nil
        }
        let direction = tripDirection(
          nyctDirection: tripUpdate.trip.nyctTripDescriptor?.direction,
          stopID: stopTimeUpdate.stopID,
          fallbackTripID: tripID
        )

        arrivals.append(ComparableArrival(
          tripID: tripID,
          stopID: stopTimeUpdate.stopID,
          train: train.rawValue,
          arrivalTimestamp: timestamp,
          departureTimestamp: stopTimeUpdate.departureTimestamp,
          vehicleStatus: vehicleStatus,
          terminalStation: terminal,
          direction: direction,
          directionLabel: stop.getLabelFor(direction: direction)
        ))
      }

      return arrivals
    }
  }

  private static func terminalStationName(
    for tripUpdate: MTAJSONTripUpdate,
    stopNameByGTFSID: [String: String]
  ) -> String {
    let tripID = standardizeTripIDForSevenTrain(tripUpdate.trip.tripID)
    let lastUsableStopUpdate = tripUpdate.stopTimeUpdate.last(where: \.isUsableArrival)
    let direction = tripDirection(
      nyctDirection: tripUpdate.trip.nyctTripDescriptor?.direction,
      stopID: lastUsableStopUpdate?.stopID,
      fallbackTripID: tripID
    )

    if tripUpdate.stopTimeUpdate.last?.isUsableArrival == false,
      let fallback = MTATrain.terminalStationName(
        routeID: tripUpdate.trip.routeID,
        direction: direction,
        stopNamesByGTFSID: stopNameByGTFSID
      )
    {
      return fallback
    }

    if let terminalStopID = lastUsableStopUpdate?.baseStopID,
      let terminal = stopNameByGTFSID[terminalStopID]
    {
      return terminal
    }

    return MTATrain.terminalStationName(
      routeID: tripUpdate.trip.routeID,
      direction: direction,
      stopNamesByGTFSID: stopNameByGTFSID
    ) ?? "Unknown Destination."
  }

  private struct VehicleStopState {
    let stopID: String
    let status: TrainArrivalVehicleStatus
    let timestamp: UInt64?

    func matches(stopID selectedStopID: String) -> Bool {
      if stopID == selectedStopID { return true }

      let currentStop = GTFSStopID(stopID)
      let selectedStop = GTFSStopID(selectedStopID)
      guard currentStop.baseID == selectedStop.baseID else { return false }

      return currentStop.direction == nil
        || selectedStop.direction == nil
        || currentStop.direction == selectedStop.direction
    }
  }

  private static func vehicleStatesByTripID(
    in entities: [MTAJSONEntity]
  ) -> [String: VehicleStopState] {
    var states: [String: VehicleStopState] = [:]

    for entity in entities {
      guard let vehicle = entity.vehicle,
        !vehicle.trip.tripID.isEmpty,
        let stopID = vehicle.stopID,
        !stopID.isEmpty
      else {
        continue
      }

      let tripID = standardizeTripIDForSevenTrain(vehicle.trip.tripID)
      let state = VehicleStopState(
        stopID: stopID,
        status: vehicleStatus(from: vehicle.currentStatus),
        timestamp: vehicle.timestamp
      )

      guard let existingState = states[tripID] else {
        states[tripID] = state
        continue
      }

      if state.timestamp ?? 0 >= existingState.timestamp ?? 0 {
        states[tripID] = state
      }
    }

    return states
  }

  private static func vehicleStatus(from rawValue: Int?) -> TrainArrivalVehicleStatus {
    switch rawValue {
    case 0:
      return .incomingAt
    case 1:
      return .stoppedAt
    default:
      return .inTransitTo
    }
  }

  private static func tripDirection(
    nyctDirection: Int?,
    stopID: String?,
    fallbackTripID: String
  ) -> TripDirection {
    switch nyctDirection {
    case 1:
      return .north
    case 3:
      return .south
    default:
      if let stopIDDirection = stopID.map(GTFSStopID.init)?.direction {
        return stopIDDirection
      }
      return tripDirectionFromTripIDSuffix(fallbackTripID) ?? .north
    }
  }
}
