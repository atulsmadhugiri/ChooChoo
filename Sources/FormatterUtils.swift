import Foundation

func formatTimeInterval(interval: TimeInterval) -> String {
  let formatter = DateComponentsFormatter()
  formatter.allowedUnits = [.hour, .minute, .second]
  formatter.unitsStyle = .abbreviated
  let formatted = formatter.string(from: interval) ?? ""
  return formatted
}
