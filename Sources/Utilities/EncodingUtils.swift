import Foundation

enum TripDirection: String {
  case north = "Uptown & The Bronx"
  case south = "Downtown & Brooklyn"
}

extension TripDirection {
  var flipped: TripDirection {
    return self == .north ? .south : .north
  }
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

func shapeIDFromTripID(_ tripID: String) -> String {
  guard let underscoreIndex = tripID.firstIndex(of: "_") else { return "" }
  let startIndex = tripID.index(after: underscoreIndex)
  return String(tripID[startIndex...])
}