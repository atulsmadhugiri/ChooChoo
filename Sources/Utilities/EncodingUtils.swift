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

func standardizeTripIDForSevenTrain(_ tripID: String) -> String {
  return tripID.replacingOccurrences(of: "_7X..", with: "_7..")
}
