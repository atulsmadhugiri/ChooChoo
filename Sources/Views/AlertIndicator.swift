import SwiftUI

struct AlertIndicator: View {
  let alertCount: Int
  var body: some View {
    Button {
    } label: {
      Image(systemName: "exclamationmark.triangle.fill")
        .frame(height: 20)
        .foregroundColor(.orange)
      Text(String(alertCount))
        .foregroundColor(.orange)
        .monospacedDigit()
    }.buttonStyle(.bordered).tint(.orange)
  }
}

#Preview {
  AlertIndicator(alertCount: 10)
}
