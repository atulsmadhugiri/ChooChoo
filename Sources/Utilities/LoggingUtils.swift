import Foundation
import PostHog

func logTerminalStationMismatch(for tripID: String) {
  PostHogSDK.shared.capture(
    "terminal_station_mismatch",
    properties: ["tripID": tripID]
  )
  print("tripID without match: \(tripID)")
}
