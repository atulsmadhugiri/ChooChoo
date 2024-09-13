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

  var endpoint: String {
    switch self {
    case .ace:
      return
        "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-ace"
    case .bdfm:
      return
        "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-bdfm"
    case .g:
      return
        "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-g"
    case .jz:
      return
        "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-jz"
    case .nqrw:
      return
        "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-nqrw"
    case .l:
      return
        "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-l"
    default:
      return
        "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs"
    }
  }
}

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
    return Color(UIColor(named: colorName)!)
  }
}
