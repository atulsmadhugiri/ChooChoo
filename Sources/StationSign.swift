import SwiftUI

struct StationSign: View {
  var stationName: String
  var trains: [MTATrain]
  var body: some View {
    HStack {
      Text(stationName)
        .font(.title)
        .foregroundStyle(.white)
        .bold().padding()
      Spacer()
      HStack {
        ForEach(trains) { route in
          TrainBadge(train: route, badgeSize: .small)
        }
      }.padding()
    }.background(Color.black)
      .cornerRadius(4)
      .overlay(
        Rectangle()
          .foregroundColor(.white)
          .frame(height: 2)
          .padding(.top, 12),
        alignment: .top
      )
  }
}

#Preview {
  StationSign(stationName: "Eighth Avenue Station", trains: [.a, .c, .e])
}
