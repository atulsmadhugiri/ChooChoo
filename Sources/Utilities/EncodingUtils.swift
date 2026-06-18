import Foundation

public enum TripDirection: String, Sendable {
  case north = "Uptown & The Bronx"
  case south = "Downtown & Brooklyn"
}

public struct GTFSStopID: Hashable, Sendable {
  public let rawValue: String

  public init(_ rawValue: String) {
    self.rawValue = rawValue
  }

  public var direction: TripDirection? {
    switch rawValue.last {
    case "N":
      return .north
    case "S":
      return .south
    default:
      return nil
    }
  }

  public var baseID: String {
    guard direction != nil else { return rawValue }
    return String(rawValue.dropLast())
  }
}

extension TripDirection {
  public init?(storageValue: String) {
    switch storageValue {
    case "north":
      self = .north
    case "south":
      self = .south
    default:
      return nil
    }
  }

  public var storageValue: String {
    switch self {
    case .north:
      return "north"
    case .south:
      return "south"
    }
  }

  public var flipped: TripDirection {
    return self == .north ? .south : .north
  }
}

public func tripDirectionFromTripIDSuffix(_ tripID: String) -> TripDirection? {
  let components = tripID.components(separatedBy: "..")
  guard components.count == 2 else {
    return nil
  }

  let suffix = components[1]

  switch suffix.prefix(1) {
  case "N":
    return .north
  case "S":
    return .south
  default:
    return nil
  }
}

public func tripDirection(for tripID: String) -> TripDirection {
  tripDirectionFromTripIDSuffix(tripID) ?? .north
}

public func standardizeTripIDForSevenTrain(_ tripID: String) -> String {
  return tripID.replacingOccurrences(of: "_7X..", with: "_7..")
}

public func directionLabel(
  for direction: TripDirection,
  gtfsStopID: String,
  northDirectionLabel: String,
  southDirectionLabel: String,
  stopName: String? = nil
) -> String {
  let adjustedDirection =
    stopsWithInvertedDirectionLabels.contains(gtfsStopID)
    ? direction.flipped : direction

  let label: String
  switch adjustedDirection {
  case .north:
    label = northDirectionLabel
  case .south:
    label = southDirectionLabel
  }

  if label.caseInsensitiveCompare("Last Stop") == .orderedSame,
    let stopName,
    !stopName.isEmpty
  {
    return stopName
  }

  return label
}

private let stopsWithInvertedDirectionLabels: Set<String> = [
  "726",  // 34 St-Hudson Yards
]
