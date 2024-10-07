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
