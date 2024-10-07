import CoreLocation
import Foundation
import TabularData

struct MTAStop: Equatable, Identifiable, Sendable {
  static func == (lhs: MTAStop, rhs: MTAStop) -> Bool {
    lhs.gtfsStopID == rhs.gtfsStopID
  }

  var id: Int { gtfsStopID.hashValue }

  let complexID: Int
  let gtfsStopID: String
  let division: String
  let line: String
  let stopName: String
  let daytimeRoutes: [MTATrain]
  let gtfsLatitude: Double
  let gtfsLongitude: Double
  let northDirectionLabel: String
  let southDirectionLabel: String

  var location: CLLocation {
    CLLocation(latitude: self.gtfsLatitude, longitude: self.gtfsLongitude)
  }
}

extension MTAStop {
  init?(from row: DataFrame.Row) {
    guard

      let complexID = row["Complex ID"] as? Int,
      let gtfsStopID = row["GTFS Stop ID"] as? String,
      let division = row["Division"] as? String,
      let line = row["Line"] as? String,
      let stopName = row["Stop Name"] as? String,
      let daytimeRoutesString = row["Daytime Routes"] as? String,
      let gtfsLatitude = row["GTFS Latitude"] as? Double,
      let gtfsLongitude = row["GTFS Longitude"] as? Double
    else {
      return nil
    }

    self.complexID = complexID
    self.gtfsStopID = gtfsStopID
    self.division = division
    self.line = line
    self.stopName = stopName
    self.daytimeRoutes = daytimeRoutesString.split(separator: " ").compactMap {
      MTATrain(rawValue: String($0))
    }
    self.gtfsLatitude = gtfsLatitude
    self.gtfsLongitude = gtfsLongitude

    self.northDirectionLabel = row["North Direction Label"] as? String ?? ""
    self.southDirectionLabel = row["South Direction Label"] as? String ?? ""
  }
}

extension MTAStop {
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
