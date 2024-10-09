import SwiftUI

struct PinButton: View {
  @State var liked: Bool = false
  @State var bounceValue: Bool = false

  let likeFeedback = UIImpactFeedbackGenerator(style: .heavy)
  let unlikeFeedback = UIImpactFeedbackGenerator(style: .light)

  var body: some View {
    Button {
      bounceValue = !liked ? !bounceValue : bounceValue
      liked = !liked
      if liked {
        likeFeedback.impactOccurred()
      } else {
        unlikeFeedback.impactOccurred()
      }
    } label: {
      Image(systemName: "star.fill")
        .frame(height: 40)
        .foregroundColor(liked ? .yellow : .gray)
        .symbolEffect(.bounce, value: bounceValue)
        .imageScale(.large)
    }.buttonStyle(.plain)
  }
}

#Preview {
  PinButton()
}
