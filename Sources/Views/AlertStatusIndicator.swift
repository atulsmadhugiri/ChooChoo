import SwiftUI

struct AlertStatusIndicator: View {
  let activePeriods: [DateInterval]
  private var now: Date { Date() }

  private static let customFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "MMM d 'at' h a"
    return formatter
  }()

  var body: some View {
    if let activeInterval = activePeriods.first(where: { $0.contains(now) }) {
      HStack(spacing: 6) {
        Text(
          "Active until \(activeInterval.end, formatter: Self.customFormatter)"
        )
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
    } else if let scheduledInterval = activePeriods.first(where: {
      $0.start > now
    }) {
      let startString = Self.customFormatter.string(
        from: scheduledInterval.start)
      let endString = Self.customFormatter.string(from: scheduledInterval.end)
      HStack(spacing: 6) {
        Text("\(startString) → \(endString)")
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
}
