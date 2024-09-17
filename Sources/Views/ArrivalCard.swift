import SwiftUI

struct ArrivalCard: View {
  let arrival: TrainArrivalEntry
  var body: some View {
    HStack {
      TrainBadge(train: arrival.train, badgeSize: .small)
        .padding(.trailing, 4)
      VStack(alignment: .leading, spacing: -2) {
        Text(arrival.terminalStation).font(.headline)
        Text(arrival.directionLabel)
          .font(.subheadline)
          .foregroundStyle(.secondary)
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
      direction: .south,
      directionLabel: "Downtown"
    )
  )
}
