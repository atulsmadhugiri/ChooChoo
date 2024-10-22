import PostHog
import SwiftData
import SwiftUI

nonisolated(unsafe) var mtaStopsByGTFSID: [String: MTAStop] = [:]

@main
struct ChooChooApp: App {
  var modelContainer = {
    do {
      return try ModelContainer(for: MTAStation.self, MTAStop.self)
    } catch {
      fatalError("Could not create ModelContainer: \(error)")
    }
  }()

  init() {
    let POSTHOG_API_KEY = "phc_nOyCGfRChLYodikS84yLBNzpacxgWCUrX9IVU1V8THM"
    let POSTHOG_HOST = "https://us.i.posthog.com"
    let configuration = PostHogConfig(
      apiKey: POSTHOG_API_KEY,
      host: POSTHOG_HOST
    )
    PostHogSDK.shared.setup(configuration)

    let stopEntries = MTAStop.loadStopsFromCSV()

    let defaults = UserDefaults.standard
    if !defaults.bool(forKey: "stationsDataLoaded") {
      print("Loading data into SwiftData store.")
      let stationEntries = MTAStation.mergeStops(stopEntries)
      for stationEntry in stationEntries {
        modelContainer.mainContext.insert(stationEntry)
      }
      try! modelContainer.mainContext.save()

      defaults.set(true, forKey: "stationsDataLoaded")
    }

    mtaStopsByGTFSID = Dictionary(
      uniqueKeysWithValues: stopEntries.map { ($0.gtfsStopID, $0) }
    )

  }

  var body: some Scene {
    WindowGroup {
      ContentView().modelContainer(modelContainer)
    }
  }
}
