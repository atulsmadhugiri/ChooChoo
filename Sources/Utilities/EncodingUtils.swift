import Foundation

public enum TripDirection: String, Sendable {
  case north = "Uptown & The Bronx"
  case south = "Downtown & Brooklyn"
}

extension TripDirection {
  public var flipped: TripDirection {
    return self == .north ? .south : .north
  }
}

public func tripDirection(for tripID: String) -> TripDirection {
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
