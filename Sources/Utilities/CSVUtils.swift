import Foundation
import TabularData

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

func tripEntriesFromCSV() -> [TripEntry] {
  var tripEntries: [TripEntry] = []
  guard
    let tripsFile = Bundle.main.url(forResource: "Trips", withExtension: "csv")
  else {
    print("Trips.csv not found.")
    return tripEntries
  }

  do {
    let df = try DataFrame(contentsOfCSVFile: tripsFile)
    for row in df.rows {
      let tripEntry = TripEntry(
        tripID: row["trip_id"] as! String,
        routeID: row["route_id"] as! String,
        tripHeadSign: row["trip_headsign"] as! String,
        directionID: row["direction_id"] as! Int
      )
      tripEntries.append(tripEntry)
    }

  } catch {
    print("Error reading CSV file: \(error)")
  }

  return tripEntries
}
