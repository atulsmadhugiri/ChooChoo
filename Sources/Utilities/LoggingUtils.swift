import Foundation
import PostHog

func logTerminalStationMismatch(for tripID: String) {
  PostHogSDK.shared.capture(
    "terminal_station_mismatch",
    properties: ["tripID": tripID]
  )
  print("tripID without match: \(tripID)")
}

func logTerminalStationPartialMatch(for tripID: String) {
  PostHogSDK.shared.capture(
    "terminal_station_partial_match",
    properties: ["tripID": tripID]
  )
  print("tripID with partial match: \(tripID)")
}

func logStationSignTapped(for station: MTAStation) {
  PostHogSDK.shared.capture(
    "user_tapped_station_sign",
    properties: ["currentStation": station.name])
}
