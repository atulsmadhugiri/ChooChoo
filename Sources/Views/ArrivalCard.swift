import SwiftUI

struct ArrivalCard: View {
  let arrival: TrainArrivalEntry
  var body: some View {
    HStack {
      TrainBadge(train: arrival.train, badgeSize: .small)
        .padding(.trailing, 4)
      Text(arrival.terminalStation)
        .font(.headline)
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
      terminalStation: "Terminal Station"
    )
  )
}
