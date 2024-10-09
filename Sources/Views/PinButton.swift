import SwiftUI

struct PinButton: View {
  @State var liked: Bool = false
  @State var likeCount: Int = 0
  @State var bounceValue: Bool = false

  let likeFeedback = UIImpactFeedbackGenerator(style: .heavy)
  let unlikeFeedback = UIImpactFeedbackGenerator(style: .light)

  var body: some View {
    Button {
      likeCount = liked ? likeCount - 1 : likeCount + 1
      bounceValue = !liked ? !bounceValue : bounceValue
      liked = !liked
      if liked {
        likeFeedback.impactOccurred()
      } else {
        unlikeFeedback.impactOccurred()
      }
    } label: {
      Image(systemName: "heart.fill")
        .frame(height: 20)
        .foregroundColor(liked ? .pink : .gray)
        .symbolEffect(.bounce, value: bounceValue)
      Text("\(likeCount)")
        .foregroundColor(liked ? .pink : .gray)
        .contentTransition(.numericText(countsDown: liked))
        .monospacedDigit()
    }
  }
}

#Preview {
  PinButton()
}
