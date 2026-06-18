import Foundation
import PostHog

private actor Analytics {
  private struct PendingEvent {
    let name: String
    let properties: [String: String]?
  }

  static let shared = Analytics()

  private static let apiKey = "phc_nOyCGfRChLYodikS84yLBNzpacxgWCUrX9IVU1V8THM"
  private static let host = "https://us.i.posthog.com"

  private var configured = false
  private var pendingEvents: [PendingEvent] = []

  func configureIfNeeded() {
    guard !configured else { return }

    let configuration = PostHogConfig(apiKey: Self.apiKey, host: Self.host)
    configuration.personProfiles = .always
    PostHogSDK.shared.setup(configuration)
    configured = true

    for event in pendingEvents {
      PostHogSDK.shared.capture(event.name, properties: event.properties)
    }
    pendingEvents.removeAll()
  }

  func capture(_ name: String, properties: [String: String]? = nil) {
    guard configured else {
      pendingEvents.append(PendingEvent(name: name, properties: properties))
      return
    }

    PostHogSDK.shared.capture(name, properties: properties)
  }
}

func configureAnalyticsIfNeeded() async {
  await Analytics.shared.configureIfNeeded()
}

private func captureAnalyticsEvent(
  _ name: String,
  properties: [String: String]? = nil
) {
  Task.detached(priority: .utility) {
    await Analytics.shared.capture(name, properties: properties)
  }
}

func logStationSignTapped(for station: MTAStation) {
  captureAnalyticsEvent(
    "user_tapped_station_sign",
    properties: ["currentStation": station.name])
}

func logStationSelected(_ station: MTAStation) {
  captureAnalyticsEvent(
    "user_selected_station",
    properties: ["station": station.name])
}

func logDirectionChanged(_ direction: TripDirection, station: MTAStation?) {
  var props: [String: String] = ["direction": direction.rawValue]
  if let stationName = station?.name {
    props["station"] = stationName
  }
  captureAnalyticsEvent("user_changed_direction", properties: props)
}

func logRefresh(for station: MTAStation?) {
  if let stationName = station?.name {
    captureAnalyticsEvent(
      "data_refresh",
      properties: ["station": stationName])
  } else {
    captureAnalyticsEvent("data_refresh")
  }
}

func logSearch(term: String) {
  captureAnalyticsEvent(
    "station_search",
    properties: ["term": term])
}

func logPinToggled(for station: MTAStation, pinned: Bool) {
  captureAnalyticsEvent(
    "station_pin_toggled",
    properties: [
      "station": station.name,
      "pinned": String(pinned)
    ])
}

func logServiceAlertsViewed(for station: MTAStation) {
  captureAnalyticsEvent(
    "service_alerts_viewed",
    properties: ["station": station.name])
}
