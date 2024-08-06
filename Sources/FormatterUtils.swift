import Foundation

func formatTimeInterval(interval: TimeInterval) -> String {
  let formatter = DateComponentsFormatter()
  formatter.allowedUnits = [.hour, .minute]
  formatter.unitsStyle = .short
  let formatted = formatter.string(from: interval) ?? ""
  return formatted
}
