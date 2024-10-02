import PostHog
import SwiftUI

@main
struct ChooChooApp: App {
  init() {
    let POSTHOG_API_KEY = "phc_nOyCGfRChLYodikS84yLBNzpacxgWCUrX9IVU1V8THM"
    let POSTHOG_HOST = "https://us.i.posthog.com"
    let configuration = PostHogConfig(
      apiKey: POSTHOG_API_KEY,
      host: POSTHOG_HOST
    )
    PostHogSDK.shared.setup(configuration)
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
    }
  }
}
