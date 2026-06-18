import SwiftUI

struct ArrivalCard: View {
  let arrival: TrainArrivalEntry

  @State private var arrivingGlow: Bool = false

  var body: some View {
    let now = Date()
    let status = arrival.displayStatus(at: now)
    let remainingTime = arrival.displayTime.timeIntervalSince(now)

    HStack {
      TrainBadge(train: arrival.train)
      VStack(alignment: .leading, spacing: -2) {
        Text(arrival.terminalStation)
          .font(.headline)
          .lineLimit(1)
        Text(arrival.directionLabel)
          .font(.subheadline)
          .foregroundStyle(.secondary)
      }
      Spacer()
      VStack(alignment: .trailing, spacing: -2) {

        switch status {
        case .arriving:
          Text("Arriving")
            .font(.headline)
            .fontDesign(.rounded)
            .foregroundStyle(.green)
            .shadow(
              color: .green.opacity(arrivingGlow ? 1.0 : 0.25),
              radius: 10,
              x: 0,
              y: 0
            )
            .onAppear {
              withAnimation(
                Animation.easeInOut(duration: 1)
                  .repeatForever(autoreverses: true)
              ) {
                arrivingGlow.toggle()
              }
            }
        case .boarding:
          Text("Arriving")
            .font(.headline)
            .fontDesign(.rounded)
            .foregroundStyle(.green)
        case .upcoming:
          Text(
            countdownText(remainingTime: remainingTime)
          )
          .font(.headline)
          .fontDesign(.rounded)
        case .departed:
          Text("Departed")
            .font(.headline)
            .fontDesign(.rounded)
            .foregroundStyle(.secondary)
        }

        Text(
          secondaryTime(for: status).formatted(date: .omitted, time: .shortened)
        )
        .font(.subheadline)
        .foregroundStyle(.tertiary)
      }
    }
  }

  private func secondaryTime(for status: TrainArrivalDisplayStatus) -> Date {
    if status == .boarding,
      let departureTime = arrival.estimatedDepartureTime
    {
      return departureTime
    }

    return arrival.estimatedArrivalTime
      ?? arrival.estimatedDepartureTime
      ?? arrival.displayTime
  }

  private func countdownText(remainingTime: TimeInterval) -> String {
    if remainingTime < 60 {
      return "<1m"
    }
    return formatTimeInterval(interval: remainingTime)
  }
}

#Preview {
  ArrivalCard(
    arrival: TrainArrivalEntry(
      id: "123",
      arrivalTimestamp: Int64(),
      train: .a,
      terminalStation: "Terminal Station",
      direction: .south,
      directionLabel: "Downtown"
    )
  )
}
