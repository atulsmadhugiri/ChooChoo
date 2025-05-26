import Foundation
import MapKit

private let timeIntervalFormatter: DateComponentsFormatter = {
  let formatter = DateComponentsFormatter()
  formatter.allowedUnits = [.hour, .minute]
  formatter.unitsStyle = .short
  return formatter
}()

func formatTimeInterval(interval: TimeInterval) -> String {
  timeIntervalFormatter.string(from: interval) ?? ""
}

private let distanceFormatter: MKDistanceFormatter = {
  let formatter = MKDistanceFormatter()
  formatter.unitStyle = .full
  return formatter
}()

func formattedDistanceTraveled(distance: CLLocationDistance) -> String {
  distanceFormatter.string(fromDistance: distance)
}
