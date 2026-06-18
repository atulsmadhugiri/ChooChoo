import SwiftData
import SwiftUI

@main
struct ChooChooApp: App {
  private static let stationsSeedSignatureKey = "stationsSeedSignature"

  private let modelContainer = Self.makeModelContainer()

  private static func makeModelContainer() -> ModelContainer {
    do {
      return try ModelContainer(for: MTAStation.self, MTAStop.self)
    } catch {
      print("Could not create persistent ModelContainer: \(error)")
      do {
        let schema = Schema([MTAStation.self, MTAStop.self])
        let configuration = ModelConfiguration(
          schema: schema,
          isStoredInMemoryOnly: true
        )
        return try ModelContainer(
          for: schema,
          configurations: [configuration]
        )
      } catch {
        fatalError("Could not create fallback ModelContainer: \(error)")
      }
    }
  }

  init() {
    seedStationsIfNeeded()
  }

  private func seedStationsIfNeeded() {
    guard let stationsFile = MTAStop.stationsCSVURL() else {
      print("Stations.csv not found.")
      return
    }

    let context = modelContainer.mainContext
    do {
      let signature = try MTAStop.csvSignature(for: stationsFile)
      let defaults = UserDefaults.standard
      let storedSignature = defaults.string(forKey: Self.stationsSeedSignatureKey)
      let currentStationCount = try context.fetchCount(FetchDescriptor<MTAStation>())
      guard storedSignature != signature || currentStationCount == 0 else {
        return
      }

      let stopEntries = MTAStop.loadStopsFromCSV(at: stationsFile)
      guard !stopEntries.isEmpty else {
        print("Skipping station seed because Stations.csv produced no stops.")
        return
      }

      print("Loading station data into SwiftData store.")
      let existingStations = try context.fetch(FetchDescriptor<MTAStation>())
      let pinnedStationIDs = Set(existingStations.filter(\.pinned).map(\.id))
      for station in existingStations {
        context.delete(station)
      }

      let existingStops = try context.fetch(FetchDescriptor<MTAStop>())
      for stop in existingStops {
        context.delete(stop)
      }

      let stationEntries = MTAStation.mergeStops(
        stopEntries,
        pinnedStationIDs: pinnedStationIDs
      )
      for stationEntry in stationEntries {
        context.insert(stationEntry)
      }

      try context.save()
      defaults.set(signature, forKey: Self.stationsSeedSignatureKey)
    } catch {
      context.rollback()
      print("Failed to seed station data: \(error)")
    }
  }

  var body: some Scene {
    WindowGroup {
      ContentView().modelContainer(modelContainer)
    }
  }
}
