import SwiftUI

struct AlertBox: View {
  let alertBody: String
  var body: some View {
    GroupBox {
      VStack(alignment: .leading) {
        parseAlertBody(alertBody)
          .fontDesign(.rounded)
      }
    } label: {
      Label("Service Alert", systemImage: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)
        .fontDesign(.rounded)
    }
    .backgroundStyle(.yellow.opacity(0.1))
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

    let pattern = /\[([A-Za-z]+)\]/

    while currentIndex < updatedAlertBody.endIndex {
      if let match = updatedAlertBody[currentIndex...].firstMatch(of: pattern) {
        let range = match.range
        let lineSymbol = match.output.1

        let prefixText = String(
          updatedAlertBody[currentIndex..<range.lowerBound])
        result = result + Text(prefixText)

        let imageName = "\(lineSymbol.lowercased()).circle.fill"
        let lineColor =
          MTATrain(rawValue: String(lineSymbol))?.color ?? MTATrain.a.color
        let lineText = Text(
          Image(systemName: imageName)
            .renderingMode(.original)
        )
        .foregroundStyle(lineColor)

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

#Preview {
  AlertBox(
    alertBody:
      "Delays on the F and G trains due to signal issues at Bergen Street.")
}
