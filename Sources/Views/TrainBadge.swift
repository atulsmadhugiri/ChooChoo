import SwiftUI
import UIKit

extension MTALine {
  private var colorSuffix: String {
    switch self {
    case .oneTwoThree:
      return "123"
    case .fourFiveSix:
      return "456"
    case .seven:
      return "7"
    case .ace:
      return "ACE"
    case .bdfm:
      return "BDFM"
    case .g:
      return "G"
    case .jz:
      return "JZ"
    case .l:
      return "L"
    case .nqrw:
      return "NQRW"
    case .s:
      return "S"
    }
  }

  var color: Color {
    let colorName = "MTAColors/\(self.colorSuffix)"
    guard let color = UIColor(named: colorName) else {
      return .gray
    }
    return Color(color)
  }
}

extension MTATrain {
  var color: Color {
    return self.line.color
  }
}

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
