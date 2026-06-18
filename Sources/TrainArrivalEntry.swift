import Foundation

public enum TrainArrivalVehicleStatus: Equatable, Sendable {
  case incomingAt
  case stoppedAt
  case inTransitTo
}

public enum TrainArrivalDisplayStatus: Equatable, Sendable {
  case upcoming
  case arriving
  case boarding
  case departed
}

public struct TrainArrivalEntry: Identifiable, Equatable, Sendable {
  public let id: String
  public let tripID: String
  public let stopID: String
  public let arrivalTimestamp: Int64?
  public let departureTimestamp: Int64?
  public let vehicleStatus: TrainArrivalVehicleStatus?
  public let train: MTATrain
  public let terminalStation: String
  public let direction: TripDirection
  public let directionLabel: String

  public init(
    id: String,
    tripID: String? = nil,
    stopID: String = "",
    arrivalTimestamp: Int64? = nil,
    departureTimestamp: Int64? = nil,
    vehicleStatus: TrainArrivalVehicleStatus? = nil,
    train: MTATrain,
    terminalStation: String,
    direction: TripDirection,
    directionLabel: String
  ) {
    self.id = id
    self.tripID = tripID ?? id
    self.stopID = stopID
    self.arrivalTimestamp = arrivalTimestamp
    self.departureTimestamp = departureTimestamp
    self.vehicleStatus = vehicleStatus
    self.train = train
    self.terminalStation = terminalStation
    self.direction = direction
    self.directionLabel = directionLabel
  }

  public var displayTimestamp: Int64 {
    arrivalTimestamp ?? departureTimestamp ?? 0
  }

  public var displayTime: Date {
    Date(timeIntervalSince1970: Double(displayTimestamp))
  }

  public var arrivalTime: Date {
    displayTime
  }

  public var estimatedArrivalTime: Date? {
    arrivalTimestamp.map { Date(timeIntervalSince1970: Double($0)) }
  }

  public var estimatedDepartureTime: Date? {
    departureTimestamp.map { Date(timeIntervalSince1970: Double($0)) }
  }

  public func isActive(at now: Date = Date()) -> Bool {
    switch vehicleStatus {
    case .incomingAt, .stoppedAt:
      return true
    case .inTransitTo, nil:
      break
    }

    if let estimatedDepartureTime {
      return estimatedDepartureTime > now
    }
    guard let estimatedArrivalTime else {
      return false
    }
    return estimatedArrivalTime > now
  }

  public func displayStatus(at now: Date = Date()) -> TrainArrivalDisplayStatus {
    switch vehicleStatus {
    case .incomingAt:
      return .arriving
    case .stoppedAt:
      return .boarding
    case .inTransitTo, nil:
      break
    }

    guard isActive(at: now) else {
      return .departed
    }

    if let estimatedArrivalTime,
      estimatedArrivalTime <= now
    {
      return .boarding
    }

    return .upcoming
  }
}
