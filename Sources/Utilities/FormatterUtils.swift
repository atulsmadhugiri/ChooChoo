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
  return distanceFormatter.string(fromDistance: distance)
}

private let distanceFormatter: MKDistanceFormatter = {
  let formatter = MKDistanceFormatter()
  formatter.unitStyle = .full
  return formatter
}()
