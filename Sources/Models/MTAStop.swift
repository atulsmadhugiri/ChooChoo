import Foundation
import SwiftData
import TabularData

// Each `MTAStop` corresponds to a GTFS stop in `Stations.csv`

@Model
class MTAStop {
  @Attribute(.unique)
  var gtfsStopID: String
  var complexID: Int
  var division: String
  var line: String
  var stopName: String
  var daytimeRoutesString: String
  var gtfsLatitude: Double
  var gtfsLongitude: Double
  var northDirectionLabel: String
  var southDirectionLabel: String

  var station: MTAStation?

  var daytimeRoutes: [MTATrain] {
    return daytimeRoutesString.split(separator: " ").compactMap {
      MTATrain(rawValue: String($0))
    }
  }

  init(
    gtfsStopID: String,
    complexID: Int,
    division: String,
    line: String,
    stopName: String,
    daytimeRoutesString: String,
    gtfsLatitude: Double,
    gtfsLongitude: Double,
    northDirectionLabel: String,
    southDirectionLabel: String
  ) {
    self.gtfsStopID = gtfsStopID
    self.complexID = complexID
    self.division = division
    self.line = line
    self.stopName = stopName
    self.daytimeRoutesString = daytimeRoutesString
    self.gtfsLatitude = gtfsLatitude
    self.gtfsLongitude = gtfsLongitude
    self.northDirectionLabel = northDirectionLabel
    self.southDirectionLabel = southDirectionLabel
  }
}

extension MTAStop {
  convenience init?(from row: DataFrame.Row) {
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

    self.init(
      gtfsStopID: gtfsStopID,
      complexID: complexID,
      division: division,
      line: line,
      stopName: stopName,
      daytimeRoutesString: daytimeRoutesString,
      gtfsLatitude: gtfsLatitude,
      gtfsLongitude: gtfsLongitude,
      northDirectionLabel: row["North Direction Label"] as? String ?? "",
      southDirectionLabel: row["South Direction Label"] as? String ?? ""
    )
  }
}

extension MTAStop {
  static func loadStopsFromCSV() -> [MTAStop] {
    guard
      let stationsFile = Bundle.main.url(
        forResource: "Stations",
        withExtension: "csv"
      )
    else {
      print("Stations.csv not found.")
      return []
    }

    do {
      let df = try DataFrame(contentsOfCSVFile: stationsFile)
      return df.rows.compactMap { MTAStop(from: $0) }
        .filter {
          $0.division != "SIR"
        }
    } catch {
      print("Error reading CSV file: \(error)")
      return []
    }
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
