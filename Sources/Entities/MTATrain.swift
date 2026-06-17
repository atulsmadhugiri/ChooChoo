import Foundation

public enum MTATrain: String, CaseIterable, Identifiable, Sendable {
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

  public var id: String { self.rawValue }
}

public enum MTARouteID: String, Sendable {
  case one = "1"
  case two = "2"
  case three = "3"
  case four = "4"
  case five = "5"
  case six = "6"
  case sixExpress = "6X"
  case seven = "7"
  case sevenExpress = "7X"
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
  case shuttle = "S"
  case franklinShuttle = "FS"
  case grandCentralShuttle = "GS"
  case rockawayShuttle = "H"

  var train: MTATrain {
    switch self {
    case .one:
      return .one
    case .two:
      return .two
    case .three:
      return .three
    case .four:
      return .four
    case .five:
      return .five
    case .six, .sixExpress:
      return .six
    case .seven, .sevenExpress:
      return .seven
    case .a:
      return .a
    case .c:
      return .c
    case .e:
      return .e
    case .b:
      return .b
    case .d:
      return .d
    case .f:
      return .f
    case .m:
      return .m
    case .g:
      return .g
    case .j:
      return .j
    case .z:
      return .z
    case .l:
      return .l
    case .n:
      return .n
    case .q:
      return .q
    case .r:
      return .r
    case .w:
      return .w
    case .shuttle, .franklinShuttle, .grandCentralShuttle, .rockawayShuttle:
      return .s
    }
  }

  func terminalStopID(for direction: TripDirection) -> String? {
    switch self {
    case .grandCentralShuttle:
      return direction == .north ? "902" : "901"
    case .rockawayShuttle:
      return direction == .north ? "H04" : "H15"
    case .franklinShuttle:
      return direction == .north ? "S01" : "D26"
    default:
      return nil
    }
  }
}

extension MTATrain {
  public init?(routeID: String) {
    guard let routeID = MTARouteID(rawValue: routeID) else {
      return nil
    }
    self = routeID.train
  }

  public static func routes(in routeString: String) -> [MTATrain] {
    routeTokens(in: routeString).compactMap(MTATrain.init(rawValue:))
  }

  public static func lines(in routeString: String) -> Set<MTALine> {
    Set(routes(in: routeString).map(\.line))
  }

  public static func routeTokens(in routeString: String) -> [String] {
    routeString.split(separator: " ").map(String.init)
  }
}

extension MTATrain {
  public var line: MTALine {
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
