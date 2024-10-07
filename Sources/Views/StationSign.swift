import SwiftUI

struct StationSign: View {
  var stationName: String
  var trains: [MTATrain]
  var body: some View {
    VStack(spacing: 0) {
      HStack {
        Text(stationName)
          .font(.title)
          .foregroundStyle(.white)
          .bold()
          .padding(
            EdgeInsets(
              top: 12,
              leading: 12,
              bottom: 6,
              trailing: 4
            )
          )
        Spacer()
      }
      ScrollView(.horizontal) {
        HStack {
          ForEach(trains) { route in
            TrainBadge(train: route, badgeSize: .small)
          }
          Spacer()
        }
      }.padding(
        EdgeInsets(
          top: 0,
          leading: 12,
          bottom: 12,
          trailing: 12
        )
      ).scrollIndicators(.hidden)
    }.background(.black)
      .cornerRadius(8)
      .overlay(
        Rectangle()
          .fill(.white)
          .frame(height: 2)
          .padding(.top, 12),
        alignment: .top
      )
  }
}

#Preview {
  StationSign(stationName: "Eighth Avenue Station", trains: [.a, .c, .e])
}
