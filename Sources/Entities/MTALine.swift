import Foundation

public enum MTAFeedEndpoint: String, Sendable {
  case main = "nyct%2Fgtfs"
  case ace = "nyct%2Fgtfs-ace"
  case bdfm = "nyct%2Fgtfs-bdfm"
  case g = "nyct%2Fgtfs-g"
  case jz = "nyct%2Fgtfs-jz"
  case l = "nyct%2Fgtfs-l"
  case nqrw = "nyct%2Fgtfs-nqrw"
  case serviceAlerts = "camsys%2Fsubway-alerts"

  private static let baseURLString =
    "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds"

  public var url: URL {
    get throws {
      try Self.url(for: rawValue)
    }
  }

  public var jsonURL: URL {
    get throws {
      try Self.url(for: "\(rawValue).json")
    }
  }

  private static func url(for feedID: String) throws -> URL {
    let urlString = "\(baseURLString)/\(feedID)"
    guard let url = URL(string: urlString) else {
      throw MTAFeedEndpointError.invalidURL(urlString)
    }
    return url
  }
}

private enum MTAFeedEndpointError: Error, LocalizedError, Sendable {
  case invalidURL(String)

  var errorDescription: String? {
    switch self {
    case .invalidURL(let endpoint):
      return "Invalid MTA feed URL: \(endpoint)"
    }
  }
}

public enum MTALine: Hashable, Sendable {
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

  public var endpoints: [MTAFeedEndpoint] {
    switch self {
    case .ace:
      return [.ace]
    case .bdfm:
      return [.bdfm]
    case .g:
      return [.g]
    case .jz:
      return [.jz]
    case .nqrw:
      return [.nqrw]
    case .l:
      return [.l]
    case .s:
      return [.main, .bdfm, .ace]
    default:
      return [.main]
    }
  }
}
