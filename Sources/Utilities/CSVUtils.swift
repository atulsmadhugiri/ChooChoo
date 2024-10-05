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
