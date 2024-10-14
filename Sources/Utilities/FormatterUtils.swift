import Foundation
import MapKit

func formatTimeInterval(interval: TimeInterval) -> String {
  let formatter = DateComponentsFormatter()
  formatter.allowedUnits = [.hour, .minute]
  formatter.unitsStyle = .short
  let formatted = formatter.string(from: interval) ?? ""
  return formatted
}

func formattedDistanceTraveled(distance: CLLocationDistance) -> String {
  let distanceFormatter = MKDistanceFormatter()
  distanceFormatter.unitStyle = .full
  return distanceFormatter.string(fromDistance: distance)
}
