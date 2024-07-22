import CoreLocation
import Foundation
import TabularData

struct MTAStation {
  let stationID: Int
  let complexID: Int
  let gtfsStopID: String
  let division: String
  let line: String
  let stopName: String
  let borough: String
  let daytimeRoutes: String
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

  init?(from row: DataFrame.Row) {
    guard
      let stationID = row["Station ID"] as? Int,
      let complexID = row["Complex ID"] as? Int,
      let gtfsStopID = row["GTFS Stop ID"] as? String,
      let division = row["Division"] as? String,
      let line = row["Line"] as? String,
      let stopName = row["Stop Name"] as? String,
      let borough = row["Borough"] as? String,
      let daytimeRoutes = row["Daytime Routes"] as? String,
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
    self.daytimeRoutes = daytimeRoutes
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

func loadStationsFromCSV() -> [MTAStation] {
  guard let stationsFile = Bundle.main.url(forResource: "Stations", withExtension: "csv") else {
    print("Stations.csv not found.")
    return []
  }

  do {
    let df = try DataFrame(contentsOfCSVFile: stationsFile)
    return df.rows.compactMap { MTAStation(from: $0)}
  } catch {
    print("Error reading CSV file: \(error)")
    return []
  }
}
