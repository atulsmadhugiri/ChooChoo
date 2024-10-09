import Foundation
import PostHog

func logStationSignTapped(for station: MTAStation) {
  PostHogSDK.shared.capture(
    "user_tapped_station_sign",
    properties: ["currentStation": station.name])
}
