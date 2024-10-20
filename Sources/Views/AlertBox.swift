import SwiftUI

struct AlertBox: View {
  var body: some View {
    GroupBox {
      VStack(alignment: .leading) {
        Text("Delays on the ")
          + Text("\(Image(systemName: "f.circle.fill"))").foregroundStyle(
            MTALine.bdfm.color)
          + Text(" and ")
          + Text("\(Image(systemName: "g.circle.fill"))").foregroundStyle(
            MTALine.g.color)
          + Text(" trains due to signal issues at Bergen Street.")
      }
    } label: {
      Label("Warning", systemImage: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)
    }.padding()
  }
}

#Preview {
  AlertBox()
}
