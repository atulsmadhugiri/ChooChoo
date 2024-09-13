import Foundation
import SwiftUI

enum MTATrain: String, CaseIterable, Identifiable {
  case one = "1"
  case two = "2"
  case three = "3"
  case four = "4"
  case five = "5"
  case six = "6"
  case seven = "7"
  case a = "A"
  case c = "C"
  case e = "E"
  case b = "B"
  case d = "D"
  case f = "F"
  case m = "M"
  case g = "G"
  case j = "J"
  case z = "Z"
  case l = "L"
  case n = "N"
  case q = "Q"
  case r = "R"
  case w = "W"
  case s = "S"

  var id: String { self.rawValue }
}

extension MTATrain {
  func getLine() -> MTALine {
    switch self {
    case .a, .c, .e:
      return .ace
    case .one, .two, .three:
      return .oneTwoThree
    case .four, .five, .six:
      return .fourFiveSix
    case .seven:
      return MTALine.seven
    case .b, .d, .f, .m:
      return .bdfm
    case .g:
      return MTALine.g
    case .j, .z:
      return .jz
    case .l:
      return MTALine.l
    case .n, .q, .r, .w:
      return .nqrw
    case .s:
      return MTALine.s
    }
  }
}

func getColorForTrain(train: MTATrain) -> Color {
  let line = train.getLine()
  return line.color
}
