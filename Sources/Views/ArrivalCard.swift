import SwiftUI

struct ArrivalCard: View {
  let arrival: TrainArrivalEntry
  var body: some View {
    HStack {
      TrainBadge(train: arrival.train, badgeSize: .small)
        .padding(.trailing, 4)
      VStack(alignment: .leading) {
        Text(arrival.terminalStation).font(.headline)
        Text(arrival.direction.rawValue).font(.subheadline)
      }
      Spacer()
      Text(
        "\(formatTimeInterval(interval: arrival.arrivalTime.timeIntervalSinceNow))"
      )
      .font(.headline)
    }
  }
}

#Preview {
  ArrivalCard(
    arrival: TrainArrivalEntry(
      arrivalTime: Date(),
      train: .a,
      terminalStation: "Terminal Station",
      direction: .south
    )
  )
}
