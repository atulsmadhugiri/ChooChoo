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
