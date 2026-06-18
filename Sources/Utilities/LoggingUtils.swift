import PostHog

private actor Analytics {
  static let shared = Analytics()

  private static let apiKey = "phc_nOyCGfRChLYodikS84yLBNzpacxgWCUrX9IVU1V8THM"
  private static let host = "https://us.i.posthog.com"

  private var configured = false
  private var activeSessionRecorded = false

  func recordAppOpenIfNeeded() {
    configureIfNeeded()
    guard !activeSessionRecorded else { return }
    activeSessionRecorded = true
    PostHogSDK.shared.capture("app_opened")
  }

  func recordAppBackgrounded() {
    activeSessionRecorded = false
  }

  private func configureIfNeeded() {
    guard !configured else { return }

    let configuration = PostHogConfig(apiKey: Self.apiKey, host: Self.host)
    configuration.personProfiles = .always
    configuration.captureApplicationLifecycleEvents = false
    configuration.captureScreenViews = false
    configuration.preloadFeatureFlags = false
    configuration.sendFeatureFlagEvent = false
    #if os(iOS) || targetEnvironment(macCatalyst)
    configuration.captureElementInteractions = false
    #endif
    #if os(iOS)
    configuration.sessionReplay = false
    #endif
    PostHogSDK.shared.setup(configuration)
    configured = true
  }
}

func recordAnalyticsAppOpenIfNeeded() async {
  await Analytics.shared.recordAppOpenIfNeeded()
}

func recordAnalyticsAppBackgrounded() async {
  await Analytics.shared.recordAppBackgrounded()
}
