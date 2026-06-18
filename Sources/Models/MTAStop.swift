import CryptoKit
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
    MTATrain.routes(in: daytimeRoutesString)
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
    guard let value = MTAStopValue(csvRow: row) else {
      return nil
    }
    self.init(value: value)
  }

  convenience init(value: MTAStopValue) {
    self.init(
      gtfsStopID: value.gtfsStopID,
      complexID: value.complexID,
      division: value.division,
      line: value.line,
      stopName: value.stopName,
      daytimeRoutesString: value.daytimeRoutesString,
      gtfsLatitude: value.gtfsLatitude,
      gtfsLongitude: value.gtfsLongitude,
      northDirectionLabel: value.northDirectionLabel,
      southDirectionLabel: value.southDirectionLabel
    )
  }
}

extension MTAStop {
  static func stationsCSVURL(in bundle: Bundle = .main) -> URL? {
    bundle.url(
      forResource: "Stations",
      withExtension: "csv"
    )
  }

  static func csvSignature(for url: URL) throws -> String {
    let data = try Data(contentsOf: url)
    return SHA256.hash(data: data)
      .map { String(format: "%02x", $0) }
      .joined()
  }

  static func loadStopsFromCSV(at stationsFile: URL) -> [MTAStop] {
    do {
      let df = try DataFrame(contentsOfCSVFile: stationsFile)
      return df.rows.compactMap { MTAStop(from: $0) }
    } catch {
      print("Error reading CSV file: \(error)")
      return []
    }
  }

  static func loadStopsFromCSV() -> [MTAStop] {
    guard let stationsFile = stationsCSVURL() else {
      print("Stations.csv not found.")
      return []
    }
    return loadStopsFromCSV(at: stationsFile)
  }
}

extension MTAStop {
  var value: MTAStopValue {
    MTAStopValue(
      gtfsStopID: gtfsStopID,
      complexID: complexID,
      division: division,
      line: line,
      stopName: stopName,
      daytimeRoutesString: daytimeRoutesString,
      gtfsLatitude: gtfsLatitude,
      gtfsLongitude: gtfsLongitude,
      northDirectionLabel: northDirectionLabel,
      southDirectionLabel: southDirectionLabel
    )
  }

  func getLabelFor(direction: TripDirection) -> String {
    return directionLabel(
      for: direction,
      gtfsStopID: gtfsStopID,
      northDirectionLabel: northDirectionLabel,
      southDirectionLabel: southDirectionLabel,
      stopName: stopName
    )
  }
}
