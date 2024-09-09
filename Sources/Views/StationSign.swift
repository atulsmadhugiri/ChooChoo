import SwiftUI

struct StationSign: View {
  var stationName: String
  var trains: [MTATrain]
  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text(stationName)
          .font(.title)
          .foregroundStyle(.background)
          .bold()
          .padding(
            EdgeInsets(
              top: 12,
              leading: 16,
              bottom: 6,
              trailing: 12
            )
          )
        Spacer()
      }
      HStack {
        ForEach(trains) { route in
          TrainBadge(train: route, badgeSize: .small)
        }
        Spacer()
      }.padding(
        EdgeInsets(
          top: 0,
          leading: 16,
          bottom: 12,
          trailing: 12
        )
      )
    }.background(.foreground)
      .cornerRadius(8)
      .overlay(
        Rectangle()
          .fill(.background)
          .frame(height: 2)
          .padding(.top, 12),
        alignment: .top
      )
  }
}

#Preview {
  StationSign(stationName: "Eighth Avenue Station", trains: [.a, .c, .e])
}
