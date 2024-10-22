import SwiftUI

struct AlertBox: View {
  let alertBody: String
  var body: some View {
    GroupBox {
      VStack(alignment: .leading) {
        Text(alertBody)
      }
    } label: {
      Label("Alert", systemImage: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)
    }
    .backgroundStyle(.yellow.opacity(0.1))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.yellow, lineWidth: 1)
    )
  }
}

#Preview {
  AlertBox(
    alertBody:
      "Delays on the F and G trains due to signal issues at Bergen Street.")
}
