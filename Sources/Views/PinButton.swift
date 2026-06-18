import SwiftData
import SwiftUI

struct PinButton: View {
  @Environment(\.modelContext) private var modelContext
  var station: MTAStation

  let likeFeedback = UIImpactFeedbackGenerator(style: .heavy)
  let unlikeFeedback = UIImpactFeedbackGenerator(style: .light)
  @State private var bounceValue: Bool = false

  var body: some View {
    Button {
      let nextPinnedValue = !station.pinned
      station.pinned = nextPinnedValue
      do {
        try modelContext.save()
        if nextPinnedValue {
          bounceValue.toggle()
          likeFeedback.impactOccurred()
        } else {
          unlikeFeedback.impactOccurred()
        }
      } catch {
        modelContext.rollback()
        print("Failed to save pinned station: \(error)")
      }
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
