import SwiftData
import TabularData

// Each `MTAStopEntry` corresponds to a GTFS stop in `Stations.csv`

@Model
class StopEntry {
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

extension StopEntry {
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
