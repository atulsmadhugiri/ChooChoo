import CoreLocation
import Foundation
import TabularData

struct MTAStop: Equatable, Identifiable, Sendable {
  static func == (lhs: MTAStop, rhs: MTAStop) -> Bool {
    lhs.gtfsStopID == rhs.gtfsStopID
  }

  var id: Int { gtfsStopID.hashValue }

  let stationID: Int
  let complexID: Int
  let gtfsStopID: String
  let division: String
  let line: String
  let stopName: String
  let borough: String
  let daytimeRoutes: [MTATrain]
  let structure: String
  let gtfsLatitude: Double
  let gtfsLongitude: Double
  let northDirectionLabel: String
  let southDirectionLabel: String
  let ada: String
  let adaDirectionNotes: String
  let adaNB: String
  let adaSB: String
  let capitalOutageNB: String
  let capitalOutageSB: String

  var location: CLLocation {
    CLLocation(latitude: self.gtfsLatitude, longitude: self.gtfsLongitude)
  }
}

extension MTAStop {
  init?(from row: DataFrame.Row) {
    guard
      let stationID = row["Station ID"] as? Int,
      let complexID = row["Complex ID"] as? Int,
      let gtfsStopID = row["GTFS Stop ID"] as? String,
      let division = row["Division"] as? String,
      let line = row["Line"] as? String,
      let stopName = row["Stop Name"] as? String,
      let borough = row["Borough"] as? String,
      let daytimeRoutesString = row["Daytime Routes"] as? String,
      let structure = row["Structure"] as? String,
      let gtfsLatitude = row["GTFS Latitude"] as? Double,
      let gtfsLongitude = row["GTFS Longitude"] as? Double
    else {
      return nil
    }

    self.stationID = stationID
    self.complexID = complexID
    self.gtfsStopID = gtfsStopID
    self.division = division
    self.line = line
    self.stopName = stopName
    self.borough = borough
    self.daytimeRoutes = daytimeRoutesString.split(separator: " ").compactMap {
      MTATrain(rawValue: String($0))
    }
    self.structure = structure
    self.gtfsLatitude = gtfsLatitude
    self.gtfsLongitude = gtfsLongitude

    self.northDirectionLabel = row["North Direction Label"] as? String ?? ""
    self.southDirectionLabel = row["South Direction Label"] as? String ?? ""
    self.ada = row["ADA"] as? String ?? ""
    self.adaDirectionNotes = row["ADA Direction Notes"] as? String ?? ""
    self.adaNB = row["ADA NB"] as? String ?? ""
    self.adaSB = row["ADA SB"] as? String ?? ""
    self.capitalOutageNB = row["Capital Outage NB"] as? String ?? ""
    self.capitalOutageSB = row["Capital Outage SB"] as? String ?? ""
  }
}

extension MTAStop {
  func getLabelFor(direction: TripDirection) -> String {
    if direction == .north {
      return self.northDirectionLabel
    } else {
      return self.southDirectionLabel
    }
  }
}

func loadStopsFromCSV() -> [MTAStop] {
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

func loadTripsFromCSV() -> [String: String] {
  var shapeToHeadSign: [String: String] = [:]
  guard
    let tripsFile = Bundle.main.url(forResource: "Trips", withExtension: "csv")
  else {
    print("Trips.csv not found.")
    return shapeToHeadSign
  }

  do {
    let df = try DataFrame(contentsOfCSVFile: tripsFile)
    let filtered = df.selecting(columnNames: ["trip_id", "trip_headsign"])
    for row in filtered.rows {
      if let shapeID = row["trip_id"] as? String,
        let tripHeadSign = row["trip_headsign"] as? String
      {
        if let underscoreIndex = shapeID.firstIndex(of: "_") {
          let substring = shapeID[shapeID.index(after: underscoreIndex)...]
          shapeToHeadSign[String(substring)] = tripHeadSign
        }
      }
    }
    return shapeToHeadSign
  } catch {
    print("Error reading CSV file: \(error)")
  }
  return shapeToHeadSign
}
