import SwiftUI

struct AlertBox: View {
  let alertBody: String
  let activePeriods: [DateInterval]

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

    while currentIndex < updatedAlertBody.endIndex {
      if let match = updatedAlertBody[currentIndex...].firstMatch(of: pattern) {
        let range = match.range
        let lineSymbol = match.output.1

        let prefixText = String(
          updatedAlertBody[currentIndex..<range.lowerBound])
        result = result + Text(prefixText)

        let imageName = "\(lineSymbol.first?.lowercased() ?? "a").circle.fill"
        let lineColor =
          MTATrain(rawValue: String(lineSymbol.first ?? "A"))?.color
          ?? MTATrain.a.color
        let lineText = Text(
          Image(systemName: imageName)
            .renderingMode(.original)
        )
        .foregroundStyle(lineColor)
        .font(.title3).baselineOffset(-1)

        result = result + lineText

        currentIndex = range.upperBound
      } else {
        let suffixText = String("\(updatedAlertBody[currentIndex...]).")
        result = result + Text(suffixText)
        break
      }
    }

    return result
  }
}
