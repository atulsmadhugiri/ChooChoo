import SwiftUI

struct AlertIndicator: View {
  let alertCount: Int
  @Binding var alertSheetActive: Bool
  var body: some View {
    Button {
      alertSheetActive = true
    } label: {
      Image(systemName: "exclamationmark.triangle.fill")
        .frame(height: 12)
        .foregroundColor(.orange)
        .imageScale(.large)
      Text(String(alertCount))
        .foregroundColor(.orange)
        .fontWeight(.bold)
        .fontDesign(.rounded)
        .imageScale(.large)

    }.buttonStyle(.bordered).tint(.orange).padding(.vertical, 6)
  }
}

#Preview {
  AlertIndicator(alertCount: 10, alertSheetActive: .constant(false))
}
