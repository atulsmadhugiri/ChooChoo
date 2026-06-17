import Foundation

struct AuditOptions {
  var stationSelectors: [String] = ["635", "610", "471", "627", "607"]
  var allStations = false
  var samples = 1
  var interval: TimeInterval = 20
  var stationsCSVPath = "Resources/Stations.csv"
  var comparisonMode: ComparisonMode = .mtaWeb

  init(arguments: ArraySlice<String>) throws {
    var index = arguments.startIndex
    while index < arguments.endIndex {
      let argument = arguments[index]
      switch argument {
      case "--all-stations":
        allStations = true
      case "--stations":
        let value = try Self.value(after: argument, in: arguments, index: &index)
        stationSelectors = value.split(separator: ",").map {
          String($0).trimmingCharacters(in: .whitespacesAndNewlines)
        }
      case "--samples":
        let value = try Self.value(after: argument, in: arguments, index: &index)
        guard let parsed = Int(value), parsed > 0 else {
          throw AuditError.invalidArgument("--samples must be a positive integer")
        }
        samples = parsed
      case "--duration":
        let value = try Self.value(after: argument, in: arguments, index: &index)
        guard let duration = TimeInterval(value), duration >= 0 else {
          throw AuditError.invalidArgument("--duration must be a non-negative number")
        }
        samples = max(1, Int(ceil(duration / interval)))
      case "--interval":
        let value = try Self.value(after: argument, in: arguments, index: &index)
        guard let parsed = TimeInterval(value), parsed > 0 else {
          throw AuditError.invalidArgument("--interval must be a positive number")
        }
        interval = parsed
      case "--stations-csv":
        stationsCSVPath = try Self.value(after: argument, in: arguments, index: &index)
      case "--compare":
        let value = try Self.value(after: argument, in: arguments, index: &index)
        guard let mode = ComparisonMode(rawValue: value) else {
          throw AuditError.invalidArgument(
            "--compare must be one of: mta-web, gtfs-json, both"
          )
        }
        comparisonMode = mode
      case "--help", "-h":
        print(Self.help)
        exit(0)
      default:
        throw AuditError.invalidArgument("unknown argument \(argument)")
      }
      arguments.formIndex(after: &index)
    }
  }

  private static func value(
    after argument: String,
    in arguments: ArraySlice<String>,
    index: inout ArraySlice<String>.Index
  ) throws -> String {
    let valueIndex = arguments.index(after: index)
    guard valueIndex < arguments.endIndex else {
      throw AuditError.invalidArgument("\(argument) requires a value")
    }
    index = valueIndex
    return arguments[valueIndex]
  }

  private static let help = """
  Usage:
    swift run ChooChooAudit [--stations 635,610] [--samples 3] [--interval 20]
    swift run ChooChooAudit --compare both --stations "34 St-Hudson Yards"
    swift run ChooChooAudit --all-stations --duration 300 --interval 20

  Station selectors may be complex IDs, GTFS stop IDs, or case-insensitive station-name fragments.
  Comparison modes: mta-web compares against the MTA website countdown endpoint;
  gtfs-json compares against fresh JSON renderings of the same GTFS-RT feeds;
  stale or missing JSON feeds are reported as SKIP. both runs both modes.
  """
}

enum ComparisonMode: String {
  case mtaWeb = "mta-web"
  case gtfsJSON = "gtfs-json"
  case both

  var includesMTAWeb: Bool {
    self == .mtaWeb || self == .both
  }

  var includesGTFSJSON: Bool {
    self == .gtfsJSON || self == .both
  }
}

enum AuditError: Error, CustomStringConvertible {
  case invalidArgument(String)
  case missingStationsCSV(String)
  case noStationsSelected
  case network(String)

  var description: String {
    switch self {
    case .invalidArgument(let message), .network(let message):
      return message
    case .missingStationsCSV(let path):
      return "could not read stations CSV at \(path)"
    case .noStationsSelected:
      return "no stations matched the requested selectors"
    }
  }
}
