import Foundation
import SwiftUI

enum MTALine {
  case oneTwoThree
  case fourFiveSix
  case seven
  case ace
  case bdfm
  case g
  case jz
  case l
  case nqrw
  case s
}

func getColorForLine(line: MTALine) -> Color {
  switch line {
  case .oneTwoThree:
    return Color(UIColor(named: "MTAColors/123")!)
  case .fourFiveSix:
    return Color(UIColor(named: "MTAColors/456")!)
  case .seven:
    return Color(UIColor(named: "MTAColors/7")!)
  case .ace:
    return Color(UIColor(named: "MTAColors/ACE")!)
  case .bdfm:
    return Color(UIColor(named: "MTAColors/BDFM")!)
  case .g:
    return Color(UIColor(named: "MTAColors/G")!)
  case .jz:
    return Color(UIColor(named: "MTAColors/JZ")!)
  case .l:
    return Color(UIColor(named: "MTAColors/L")!)
  case .nqrw:
    return Color(UIColor(named: "MTAColors/NQRW")!)
  case .s:
    return Color(UIColor(named: "MTAColors/S")!)
  }
}
