import SwiftUI

struct AlertBox: View {
  let alertBody: String
  let activePeriods: [MTAServiceAlertTimeRange]

  var body: some View {
    GroupBox {
      VStack(alignment: .leading) {
        parseAlertBody(alertBody)
          .fontDesign(.rounded)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    } label: {
      VStack(alignment: .leading, spacing: 6) {
        Label("Service Alert", systemImage: "exclamationmark.triangle.fill")
          .foregroundStyle(.orange)
        AlertStatusIndicator(activePeriods: activePeriods)
      }
    }
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(Color.yellow.opacity(0.6))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.yellow, lineWidth: 1)
    )
  }

  func parseAlertBody(_ alertBody: String) -> Text {
    let updatedAlertBody = alertBody.replacingOccurrences(
      of: "\n", with: ".\n\n")
    var result = Text("")
    var currentIndex = updatedAlertBody.startIndex
    let pattern = /\[([A-Za-z1-7]+)\]/

    for match in updatedAlertBody.matches(of: pattern) {
      result = result + Text(updatedAlertBody[currentIndex..<match.range.lowerBound])
      result = result + routeIcon(for: match.output.1)
      currentIndex = match.range.upperBound
    }

    if currentIndex < updatedAlertBody.endIndex {
      result = result + Text("\(updatedAlertBody[currentIndex...]).")
    }
    return result
  }

  private func routeIcon(for symbol: Substring) -> Text {
    let routeSymbol = String(symbol.prefix(1))
    let train = MTATrain(rawValue: routeSymbol.uppercased()) ?? .a

    return Text(
      Image(systemName: "\(routeSymbol.lowercased()).circle.fill")
        .renderingMode(.original)
    )
    .foregroundStyle(train.color)
    .font(.title3)
    .baselineOffset(-1)
  }
}
