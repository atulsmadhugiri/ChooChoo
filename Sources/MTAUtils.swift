import Foundation
import SwiftUI
import CoreLocation

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

enum MTATrain: String, CaseIterable {
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
}

func getLineForTrain(train: MTATrain) -> MTALine {
  switch train {
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

func getColorForTrain(train: MTATrain) -> Color {
  let line = getLineForTrain(train: train)
  return getColorForLine(line: line)
}

struct MTAStation {
  let stationID: Int
  let complexID: Int
  let gtfsStopID: String
  let division: String
  let line: String
  let stopName: String
  let borough: String
  let daytimeRoutes: String
  let structure: String
  let gtfsLatitude: Double
  let gtfsLongitude: Double
  let northDirectionLabel: String
  let southDirectionLabel: String
  let ada: String
  let adaDirectionNotes: String
  let adaNB: String
  let adaSB: String
  let capitalOutageNB: String
  let capitalOutageSB: String

  var location: CLLocation {
    CLLocation(latitude: self.gtfsLatitude, longitude: self.gtfsLongitude)
  }
}
