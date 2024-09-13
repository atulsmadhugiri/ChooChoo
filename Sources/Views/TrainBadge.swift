import SwiftUI

enum BadgeSize {
  case small
  case large
}

struct TrainBadge: View {
  let train: MTATrain
  let badgeSize: BadgeSize

  var body: some View {
    ZStack {
      Circle()
        .frame(width: badgeSize == .small ? 45 : 60)
        .foregroundStyle(train.color)

      Text(train.rawValue)
        .font(badgeSize == .small ? .title : .largeTitle)
        .fontWeight(.semibold)
        .foregroundStyle(.white)
    }
  }
}

#Preview {
  TrainBadge(train: .one, badgeSize: .small)
}
