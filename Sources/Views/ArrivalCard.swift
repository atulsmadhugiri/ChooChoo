import SwiftUI

struct ArrivalCard: View {
  let arrival: TrainArrivalEntry
  var body: some View {
    HStack {
      TrainBadge(train: arrival.train, badgeSize: .small)
      Spacer()
      Text(arrival.terminalStation).font(.headline).fontDesign(.rounded)
      Spacer()
      Text(
        "\(formatTimeInterval(interval: arrival.arrivalTime.timeIntervalSinceNow))"
      )
      .font(.headline).fontDesign(.rounded)
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
