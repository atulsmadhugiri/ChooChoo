import SwiftUI

struct AlertBox: View {
  let alertBody: String
  var body: some View {
    GroupBox {
      VStack(alignment: .leading) {
        Text(alertBody).lineLimit(2)
      }
    } label: {
      Label("Alert", systemImage: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)
    }
    .backgroundStyle(.yellow.opacity(0.1))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.yellow, lineWidth: 1)
    ).padding(
      EdgeInsets(
        top: 0,
        leading: 12,
        bottom: 12,
        trailing: 12
      ))
  }
}

#Preview {
  AlertBox(
    alertBody:
      "Delays on the F and G trains due to signal issues at Bergen Street.")
}
