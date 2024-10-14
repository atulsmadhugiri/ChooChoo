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

extension MTAStopValue {
  init(mtaStop: MTAStop) {
    self.init(
      gtfsStopID: mtaStop.gtfsStopID,
      complexID: mtaStop.complexID,
      division: mtaStop.division,
      line: mtaStop.line,
      stopName: mtaStop.stopName,
      daytimeRoutesString: mtaStop.daytimeRoutesString,
      gtfsLatitude: mtaStop.gtfsLatitude,
      gtfsLongitude: mtaStop.gtfsLongitude,
      northDirectionLabel: mtaStop.northDirectionLabel,
      southDirectionLabel: mtaStop.southDirectionLabel
    )
  }
}

extension MTAStopValue {
  func getLabelFor(direction: TripDirection) -> String {
    // HACK: Accounting for weird direction labels for 34 St-Hudson Yards.
    //       As with all the other hacks, there's definitely a better way.
    let adjustedDirection =
      self.gtfsStopID == "726" ? direction.flipped : direction
    if adjustedDirection == .north {
      return self.northDirectionLabel
    } else {
      return self.southDirectionLabel
    }
  }
}
