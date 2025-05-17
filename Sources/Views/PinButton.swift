import SwiftUI

struct PinButton: View {
  @Environment(\.modelContext) private var modelContext
  var station: MTAStation

  let likeFeedback = UIImpactFeedbackGenerator(style: .heavy)
  let unlikeFeedback = UIImpactFeedbackGenerator(style: .light)
  @State private var bounceValue: Bool = false

  var body: some View {
    Button {
      bounceValue = !station.pinned ? !bounceValue : bounceValue
      station.pinned = !station.pinned
      if station.pinned {
        likeFeedback.impactOccurred()
        modelContext.insert(station)
        try! modelContext.save()
      } else {
        unlikeFeedback.impactOccurred()
        modelContext.insert(station)
        try! modelContext.save()
      }
      logPinToggled(for: station, pinned: station.pinned)
    } label: {
      Image(systemName: "heart.fill")
        .frame(height: 22)
        .foregroundColor(station.pinned ? .pink : .gray.opacity(0.5))
        .symbolEffect(.bounce, value: bounceValue)
        .imageScale(.large)
    }.buttonStyle(.bordered)
      .tint(station.pinned ? .pink : .secondary)
      .padding(.vertical, 10)
  }
}
