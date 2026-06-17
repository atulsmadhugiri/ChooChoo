import Foundation

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

  public var endpoint: String {
    endpoints[0]
  }

  public var endpoints: [String] {
    switch self {
    case .ace:
      return [
        "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-ace"
      ]
    case .bdfm:
      return [
        "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-bdfm"
      ]
    case .g:
      return [
        "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-g"
      ]
    case .jz:
      return [
        "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-jz"
      ]
    case .nqrw:
      return [
        "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-nqrw"
      ]
    case .l:
      return [
        "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-l"
      ]
    case .s:
      return [
        "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs",
        "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-bdfm",
        "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs-ace",
      ]
    default:
      return [
        "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs"
      ]
    }
  }
}
