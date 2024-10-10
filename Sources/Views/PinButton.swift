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
      } else {
        unlikeFeedback.impactOccurred()
        modelContext.insert(station)
      }
    } label: {
      Image(systemName: "star.fill")
        .frame(height: 40)
        .foregroundColor(station.pinned ? .yellow : .gray)
        .symbolEffect(.bounce, value: bounceValue)
        .imageScale(.large)
    }.buttonStyle(.plain)
  }
}
