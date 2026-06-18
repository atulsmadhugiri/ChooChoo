import ChooChooCore
import Foundation
import TabularData

struct StationGroup {
  let complexID: Int
  let name: String
  let stops: [MTAStopValue]

  var lines: Set<MTALine> {
    stops.reduce(into: Set<MTALine>()) { result, stop in
      result.formUnion(stop.lines)
    }
  }
}

enum StationCSV {
  static func loadStops(from path: String) throws -> [MTAStopValue] {
    let url = URL(fileURLWithPath: path)
    guard FileManager.default.fileExists(atPath: url.path) else {
      throw AuditError.missingStationsCSV(path)
    }

    let dataFrame = try DataFrame(contentsOfCSVFile: url)
    return dataFrame.rows.compactMap(MTAStopValue.init(csvRow:))
  }
}

enum StationSelector {
  static func selectStations(
    from stops: [MTAStopValue],
    options: AuditOptions
  ) throws -> [StationGroup] {
    let grouped = Dictionary(grouping: stops, by: \.complexID)
      .map { complexID, stops in
        StationGroup(
          complexID: complexID,
          name: stops.first?.stopName ?? "\(complexID)",
          stops: stops.sorted { $0.gtfsStopID < $1.gtfsStopID }
        )
      }
      .sorted { $0.complexID < $1.complexID }

    if options.allStations {
      return grouped
    }

    var seenComplexIDs: Set<Int> = []
    let selected = options.stationSelectors.flatMap { selector in
      matches(selector: selector, in: grouped)
    }
    .filter { station in
      seenComplexIDs.insert(station.complexID).inserted
    }
    guard !selected.isEmpty else { throw AuditError.noStationsSelected }
    return selected
  }

  private static func matches(
    selector: String,
    in stations: [StationGroup]
  ) -> [StationGroup] {
    let complexMatches = stations.filter { String($0.complexID) == selector }
    if !complexMatches.isEmpty {
      return complexMatches
    }

    let stopMatches = stations.filter { station in
      station.stops.contains {
        $0.gtfsStopID.caseInsensitiveCompare(selector) == .orderedSame
      }
    }
    if !stopMatches.isEmpty {
      return stopMatches
    }

    return stations.filter {
      $0.name.range(of: selector, options: [.caseInsensitive, .diacriticInsensitive]) != nil
    }
  }
}
