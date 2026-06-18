import SwiftUI

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
    Color("MTAColors/\(colorSuffix)")
  }
}

extension MTATrain {
  var color: Color {
    return self.line.color
  }
}

struct TrainBadge: View {
  let train: MTATrain

  var body: some View {
    ZStack {
      Circle()
        .frame(width: 45)
        .foregroundStyle(train.color)

      Text(train.rawValue)
        .font(.title)
        .fontWeight(.semibold)
        .foregroundStyle(.white)
    }
  }
}

#Preview {
  TrainBadge(train: .one)
}
