import SwiftUI

struct AlertIndicator: View {
  let alertCount: Int
  @Binding var alertSheetActive: Bool

  let tapHaptic = UIImpactFeedbackGenerator(style: .heavy)

  var body: some View {
    Button {
      tapHaptic.impactOccurred()
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

    }.buttonStyle(.bordered)
      .tint(.yellow)
      .padding(.vertical, 6)
      .onAppear {
        tapHaptic.prepare()
      }
  }
}

#Preview {
  AlertIndicator(alertCount: 10, alertSheetActive: .constant(false))
}
