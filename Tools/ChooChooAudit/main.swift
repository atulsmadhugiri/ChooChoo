import Foundation

@main
struct ChooChooAudit {
  static func main() async {
    do {
      let options = try AuditOptions(arguments: CommandLine.arguments.dropFirst())
      let stops = try StationCSV.loadStops(from: options.stationsCSVPath)
      let stopNames = Dictionary(uniqueKeysWithValues: stops.map {
        ($0.gtfsStopID, $0.stopName)
      })

      let stations = try StationSelector.selectStations(
        from: stops,
        options: options
      )
      let runner = AuditRunner(
        stations: stations,
        stopNameByGTFSID: stopNames,
        comparisonMode: options.comparisonMode
      )
      try await runner.run(samples: options.samples, interval: options.interval)
    } catch {
      FileHandle.standardError.write(Data("error: \(error)\n".utf8))
      exit(1)
    }
  }
}
