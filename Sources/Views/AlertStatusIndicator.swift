import SwiftUI

struct AlertStatusIndicator: View {
  let activePeriods: [MTAServiceAlertTimeRange]

  private static let customFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d 'at' h a"
    return formatter
  }()

  var body: some View {
    let now = Date()
    let periods = sortedPeriods

    if let activeInterval = periods.first(where: { $0.contains(now) }) {
      HStack(spacing: 6) {
        Text(activeText(for: activeInterval))
        .font(.footnote)
        .foregroundColor(.green)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(Color.green.opacity(0.1))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color.green, lineWidth: 1)
      )
    } else if let scheduledInterval = periods.first(where: {
      $0.start.map { $0 > now } ?? false
    }) {
      HStack(spacing: 6) {
        Text(scheduledText(for: scheduledInterval))
          .font(.footnote)
          .foregroundColor(.gray)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(Color.gray.opacity(0.1))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color.gray, lineWidth: 1)
      )
    } else {
      EmptyView()
    }
  }

  private var sortedPeriods: [MTAServiceAlertTimeRange] {
    activePeriods.sorted { lhs, rhs in
      if lhs.sortStart != rhs.sortStart {
        return lhs.sortStart < rhs.sortStart
      }
      return lhs.sortEnd < rhs.sortEnd
    }
  }

  private func activeText(for period: MTAServiceAlertTimeRange) -> String {
    guard let end = period.end else { return "Active now" }
    return "Active until \(Self.customFormatter.string(from: end))"
  }

  private func scheduledText(for period: MTAServiceAlertTimeRange) -> String {
    guard let start = period.start else { return "" }
    let startString = Self.customFormatter.string(from: start)
    guard let end = period.end else { return "Starts \(startString)" }
    return "\(startString) -> \(Self.customFormatter.string(from: end))"
  }
}
