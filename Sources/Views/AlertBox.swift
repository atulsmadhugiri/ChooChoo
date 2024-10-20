import SwiftUI

struct AlertBox: View {
  var body: some View {
    GroupBox {
      VStack(alignment: .leading) {
        Text("Delays on the ")
          + Text(
            Image(systemName: "f.circle.fill")
              .renderingMode(.original)
          ).foregroundStyle(
            MTALine.bdfm.color)
          + Text(" and ")
          + Text(
            Image(systemName: "g.circle.fill")
              .renderingMode(.original)
          ).foregroundStyle(MTALine.g.color)

          + Text(" trains due to signal issues at Bergen Street.")
      }
    } label: {
      Label("Alert", systemImage: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)
    }
    .backgroundStyle(.yellow.opacity(0.1))
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color.yellow, lineWidth: 1)
    ).padding(12)
  }
}

#Preview {
  AlertBox()
}
