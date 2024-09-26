import SwiftUI

struct ArrivalCard: View {
  let arrival: TrainArrivalEntry

  @State private var arrivingGlow: Bool = false

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
      VStack(alignment: .trailing, spacing: -2) {

        if arrival.arrivalTime.timeIntervalSinceNow < 60 {
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
        } else {
          Text(
            "\(formatTimeInterval(interval: arrival.arrivalTime.timeIntervalSinceNow))"
          )
          .font(.headline)
          .fontDesign(.rounded)
        }

        Text(
          Date(
            timeIntervalSinceNow: arrival.arrivalTime.timeIntervalSinceNow
          ).formatted(date: .omitted, time: .shortened)
        )
        .font(.subheadline)
        .foregroundStyle(.tertiary)
      }
    }
  }
}

#Preview {
  ArrivalCard(
    arrival: TrainArrivalEntry(
      arrivalTimestamp: Int64(),
      train: .a,
      terminalStation: "Terminal Station",
      direction: .south,
      directionLabel: "Downtown"
    )
  )
}
