import Foundation
import PostHog

func logStationSignTapped(for station: MTAStation) {
  PostHogSDK.shared.capture(
    "user_tapped_station_sign",
    properties: ["currentStation": station.name])
}

func logStationSelected(_ station: MTAStation) {
  PostHogSDK.shared.capture(
    "user_selected_station",
    properties: ["station": station.name])
}

func logDirectionChanged(_ direction: TripDirection, station: MTAStation?) {
  var props: [String: String] = ["direction": direction.rawValue]
  if let stationName = station?.name {
    props["station"] = stationName
  }
  PostHogSDK.shared.capture("user_changed_direction", properties: props)
}

func logRefresh(for station: MTAStation?) {
  if let stationName = station?.name {
    PostHogSDK.shared.capture(
      "data_refresh",
      properties: ["station": stationName])
  } else {
    PostHogSDK.shared.capture("data_refresh")
  }
}

func logSearch(term: String) {
  PostHogSDK.shared.capture(
    "station_search",
    properties: ["term": term])
}

func logPinToggled(for station: MTAStation, pinned: Bool) {
  PostHogSDK.shared.capture(
    "station_pin_toggled",
    properties: [
      "station": station.name,
      "pinned": String(pinned)
    ])
}

func logServiceAlertsViewed(for station: MTAStation) {
  PostHogSDK.shared.capture(
    "service_alerts_viewed",
    properties: ["station": station.name])
}
