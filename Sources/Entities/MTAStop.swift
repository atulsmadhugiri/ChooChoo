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
  let adaNotes: String
  let adaNB: String
  let adaSB: String

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
    self.adaNotes = row["ADA Notes"] as? String ?? ""
    self.adaNB = row["ADA Northbound"] as? String ?? ""
    self.adaSB = row["ADA Northbound"] as? String ?? ""
  }
}

extension MTAStop {
  func getLabelFor(direction: TripDirection) -> String {
    // HACK: Accounting for weird direction labels for 34 St-Hudson Yards.
    //       As with all the other hacks, there's definitely a better way.
    let adjustedDirection = self.gtfsStopID == "726" ? direction.flipped : direction
    if adjustedDirection == .north {
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

func tripToTerminusFromCSV() -> [String: String] {
  var tripToTerminus: [String: String] = [:]
  guard
    let tripsFile = Bundle.main.url(forResource: "Trips", withExtension: "csv")
  else {
    print("Trips.csv not found.")
    return tripToTerminus
  }

  do {
    let df = try DataFrame(contentsOfCSVFile: tripsFile)
    let filtered = df.selecting(columnNames: ["trip_id", "trip_headsign"])
    for row in filtered.rows {
      if let tripID = row["trip_id"] as? String,
        let tripHeadSign = row["trip_headsign"] as? String
      {
        // TODO: We'll create some higher level function if we end up
        //       needing to do further processing for specific lines.
        let processedTripID = standardizeTripIDForSevenTrain(tripID)
        tripToTerminus[processedTripID] = tripHeadSign
      }
    }
    return tripToTerminus
  } catch {
    print("Error reading CSV file: \(error)")
  }
  return tripToTerminus
}

func shapeToTerminusFromCSV() -> [String: String] {
  var shapeToTerminus: [String: String] = [:]
  guard
    let tripsFile = Bundle.main.url(forResource: "Trips", withExtension: "csv")
  else {
    print("Trips.csv not found.")
    return shapeToTerminus
  }

  do {
    let df = try DataFrame(contentsOfCSVFile: tripsFile)
    let filtered = df.selecting(columnNames: ["trip_id", "trip_headsign"])
    for row in filtered.rows {
      if let tripID = row["trip_id"] as? String,
        let tripHeadSign = row["trip_headsign"] as? String
      {
        let processedTripID = standardizeTripIDForSevenTrain(tripID)
        let shapeID = shapeIDFromTripID(processedTripID)
        // HACK: We had a mismatch between `shape_id` in static GTFS data and `shape_id`
        // in realtime GTFS data for the L train. The static data had eg `L..N02R` whereas
        // the realtime data had just `L..N`.
        if shapeID.hasPrefix("L..") {
          shapeToTerminus[String(shapeID.prefix(4))] = tripHeadSign
          continue
        }
        shapeToTerminus[shapeID] = tripHeadSign
      }
    }
    return shapeToTerminus
  } catch {
    print("Error reading CSV file: \(error)")
  }
  return shapeToTerminus
}
