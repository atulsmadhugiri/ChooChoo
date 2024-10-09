import PostHog
import SwiftData
import SwiftUI

@main
struct ChooChooApp: App {
  var modelContainer = {
    do {
      return try ModelContainer(for: StationEntry.self)
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

    let stopEntries = StopEntry.loadStopsFromCSV()
    let stationEntries = StationEntry.mergeStops(stopEntries)
    for stationEntry in stationEntries {
      modelContainer.mainContext.insert(stationEntry)
    }
    try! modelContainer.mainContext.save()
  }

  var body: some Scene {
    WindowGroup {
      ContentView().modelContainer(modelContainer)
    }
  }
}
