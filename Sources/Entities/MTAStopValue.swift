import Foundation
import TabularData

public enum StationCSVColumn: String, Sendable {
  case complexID = "Complex ID"
  case gtfsStopID = "GTFS Stop ID"
  case division = "Division"
  case line = "Line"
  case stopName = "Stop Name"
  case daytimeRoutes = "Daytime Routes"
  case gtfsLatitude = "GTFS Latitude"
  case gtfsLongitude = "GTFS Longitude"
  case northDirectionLabel = "North Direction Label"
  case southDirectionLabel = "South Direction Label"
}

public struct MTAStopValue: Sendable {
  public let gtfsStopID: String
  public let complexID: Int
  public let division: String
  public let line: String
  public let stopName: String
  public let daytimeRoutesString: String
  public let gtfsLatitude: Double
  public let gtfsLongitude: Double
  public let northDirectionLabel: String
  public let southDirectionLabel: String

  public init(
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

  public var daytimeRoutes: [MTATrain] {
    MTATrain.routes(in: daytimeRoutesString)
  }

  public var lines: Set<MTALine> {
    MTATrain.lines(in: daytimeRoutesString)
  }
}

extension MTAStopValue {
  public init?(csvRow row: DataFrame.Row) {
    guard row[.division] as? String != "SIR",
      let complexID = row[.complexID] as? Int,
      let gtfsStopID = row[.gtfsStopID] as? String,
      let division = row[.division] as? String,
      let line = row[.line] as? String,
      let stopName = row[.stopName] as? String,
      let daytimeRoutesString = row[.daytimeRoutes] as? String,
      let gtfsLatitude = row[.gtfsLatitude] as? Double,
      let gtfsLongitude = row[.gtfsLongitude] as? Double
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
      northDirectionLabel: row[.northDirectionLabel] as? String ?? "",
      southDirectionLabel: row[.southDirectionLabel] as? String ?? ""
    )
  }

  public func getLabelFor(direction: TripDirection) -> String {
    return directionLabel(
      for: direction,
      gtfsStopID: gtfsStopID,
      northDirectionLabel: northDirectionLabel,
      southDirectionLabel: southDirectionLabel,
      stopName: stopName
    )
  }
}

extension DataFrame.Row {
  fileprivate subscript(_ column: StationCSVColumn) -> Any? {
    self[column.rawValue]
  }
}
