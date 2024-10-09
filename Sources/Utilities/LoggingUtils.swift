import Foundation
import PostHog

func logStationSignTapped(for station: StationEntry) {
  PostHogSDK.shared.capture(
    "user_tapped_station_sign",
    properties: ["currentStation": station.name])
}
