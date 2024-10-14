import Foundation

struct MTAStopValue {
  let gtfsStopID: String
  let complexID: Int
  let division: String
  let line: String
  let stopName: String
  let daytimeRoutesString: String
  let gtfsLatitude: Double
  let gtfsLongitude: Double
  let northDirectionLabel: String
  let southDirectionLabel: String

  var daytimeRoutes: [MTATrain] {
    return daytimeRoutesString.split(separator: " ").compactMap {
      MTATrain(rawValue: String($0))
    }
  }
}
