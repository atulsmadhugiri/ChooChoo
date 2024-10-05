import SwiftData

// Each `TripEntry` corresponds to a scheduled trip in `Trips.csv`.

@Model
class TripEntry {
  var tripID: String
  var routeID: String
  var tripHeadSign: String
  var directionID: Int

  init(
    tripID: String,
    routeID: String,
    tripHeadSign: String,
    directionID: Int
  ) {
    self.tripID = tripID
    self.routeID = routeID
    self.tripHeadSign = tripHeadSign
    self.directionID = directionID
  }
}
