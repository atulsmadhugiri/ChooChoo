import ChooChooCore
import Foundation

@main
struct ChooChooAudit {
  static func main() async {
    do {
      let options = try AuditOptions(arguments: CommandLine.arguments.dropFirst())
      let stops = try StationCSV.loadStops(from: options.stationsCSVPath)
      let stopNames = Dictionary(uniqueKeysWithValues: stops.map {
        ($0.gtfsStopID, $0.stopName)
      })

      let stations = try StationSelector.selectStations(
        from: stops,
        options: options
      )
      let runner = AuditRunner(
        stations: stations,
        stopNameByGTFSID: stopNames,
        comparisonMode: options.comparisonMode
      )
      try await runner.run(samples: options.samples, interval: options.interval)
    } catch {
      FileHandle.standardError.write(Data("error: \(error)\n".utf8))
      exit(1)
    }
  }
}

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

struct StationStop {
  let gtfsStopID: String
  let complexID: Int
  let division: String
  let line: String
  let stopName: String
  let daytimeRoutesString: String
  let gtfsLatitude: Double
  let gtfsLongitude: Double
  let northDirectionLabel: String
  let southDirectionLabel: String

  var value: MTAStopValue {
    MTAStopValue(
      gtfsStopID: gtfsStopID,
      complexID: complexID,
      division: division,
      line: line,
      stopName: stopName,
      daytimeRoutesString: daytimeRoutesString,
      gtfsLatitude: gtfsLatitude,
      gtfsLongitude: gtfsLongitude,
      northDirectionLabel: northDirectionLabel,
      southDirectionLabel: southDirectionLabel
    )
  }

  var lines: Set<MTALine> {
    Set(daytimeRoutesString.split(separator: " ").compactMap {
      MTATrain(rawValue: String($0))?.line
    })
  }
}

struct StationGroup {
  let complexID: Int
  let name: String
  let stops: [StationStop]

  var lines: Set<MTALine> {
    stops.reduce(into: Set<MTALine>()) { result, stop in
      result.formUnion(stop.lines)
    }
  }
}

enum StationCSV {
  static func loadStops(from path: String) throws -> [StationStop] {
    guard let data = FileManager.default.contents(atPath: path),
      let contents = String(data: data, encoding: .utf8)
    else {
      throw AuditError.missingStationsCSV(path)
    }

    var rows = CSVParser.parse(contents)
    guard !rows.isEmpty else { return [] }
    let header = rows.removeFirst()
    let indexes = Dictionary(uniqueKeysWithValues: header.enumerated().map {
      ($0.element, $0.offset)
    })

    return rows.compactMap { row in
      guard field("Division", row, indexes) != "SIR",
        let complexID = Int(field("Complex ID", row, indexes)),
        let latitude = Double(field("GTFS Latitude", row, indexes)),
        let longitude = Double(field("GTFS Longitude", row, indexes))
      else {
        return nil
      }

      return StationStop(
        gtfsStopID: field("GTFS Stop ID", row, indexes),
        complexID: complexID,
        division: field("Division", row, indexes),
        line: field("Line", row, indexes),
        stopName: field("Stop Name", row, indexes),
        daytimeRoutesString: field("Daytime Routes", row, indexes),
        gtfsLatitude: latitude,
        gtfsLongitude: longitude,
        northDirectionLabel: field("North Direction Label", row, indexes),
        southDirectionLabel: field("South Direction Label", row, indexes)
      )
    }
  }

  private static func field(
    _ name: String,
    _ row: [String],
    _ indexes: [String: Int]
  ) -> String {
    guard let index = indexes[name], index < row.count else { return "" }
    return row[index]
  }
}

enum CSVParser {
  static func parse(_ contents: String) -> [[String]] {
    var rows: [[String]] = []
    var row: [String] = []
    var field = ""
    var inQuotes = false
    var iterator = contents.makeIterator()

    while let character = iterator.next() {
      switch character {
      case "\"":
        if inQuotes, let next = iterator.next() {
          if next == "\"" {
            field.append("\"")
          } else {
            inQuotes = false
            consume(next, field: &field, row: &row, rows: &rows, inQuotes: &inQuotes)
          }
        } else {
          inQuotes.toggle()
        }
      default:
        consume(character, field: &field, row: &row, rows: &rows, inQuotes: &inQuotes)
      }
    }

    if !field.isEmpty || !row.isEmpty {
      row.append(field)
      rows.append(row)
    }

    return rows
  }

  private static func consume(
    _ character: Character,
    field: inout String,
    row: inout [String],
    rows: inout [[String]],
    inQuotes: inout Bool
  ) {
    if inQuotes {
      field.append(character)
      return
    }

    switch character {
    case ",":
      row.append(field)
      field = ""
    case "\n":
      row.append(field)
      rows.append(row)
      row = []
      field = ""
    case "\r":
      break
    default:
      field.append(character)
    }
  }
}

enum StationSelector {
  static func selectStations(
    from stops: [StationStop],
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

struct AuditRunner {
  let stations: [StationGroup]
  let stopNameByGTFSID: [String: String]
  let comparisonMode: ComparisonMode

  func run(samples: Int, interval: TimeInterval) async throws {
    print("Auditing \(stations.count) station(s), \(samples) sample(s), interval \(Int(interval))s")

    var totalMismatches = 0
    var auditSummary = AuditRunSummary()
    for sample in 1...samples {
      if sample > 1 {
        try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
      }

      let sampledAt = Date()
      print("\nSample \(sample) at \(ISO8601DateFormatter().string(from: sampledAt))")

      let feedData = try await fetchFeeds(for: stations)
      for station in stations {
        let result = try await compare(station: station, feedData: feedData, now: sampledAt)
        totalMismatches += result.mismatchCount
        auditSummary.record(result)
        result.printSummary()
      }
    }

    print("\nTotal mismatches: \(totalMismatches)")
    auditSummary.printSummary()
  }

  private func fetchFeeds(
    for stations: [StationGroup]
  ) async throws -> [MTALine: LineFeeds] {
    let lines = Set(stations.flatMap(\.lines))
    let shouldFetchJSON = comparisonMode.includesGTFSJSON
    return try await withThrowingTaskGroup(of: (MTALine, LineFeeds).self) { group in
      for line in lines {
        group.addTask {
          let payloads = try await Self.fetchPayloads(
            for: line,
            includingJSON: shouldFetchJSON
          )
          return (line, LineFeeds(payloads: payloads))
        }
      }

      var result: [MTALine: LineFeeds] = [:]
      for try await (line, feeds) in group {
        result[line] = feeds
      }
      return result
    }
  }

  private static func fetchPayloads(
    for line: MTALine,
    includingJSON shouldFetchJSON: Bool
  ) async throws -> [FeedPayload] {
    try await withThrowingTaskGroup(of: FeedPayload.self) { group in
      for endpoint in line.endpoints {
        group.addTask {
          try await Self.fetchPayload(endpoint: endpoint, includingJSON: shouldFetchJSON)
        }
      }

      var payloads: [FeedPayload] = []
      for try await payload in group {
        payloads.append(payload)
      }
      return payloads
    }
  }

  private static func fetchPayload(
    endpoint: String,
    includingJSON shouldFetchJSON: Bool
  ) async throws -> FeedPayload {
    let protobufURL = URL(string: endpoint)!
    let protobuf = try await HTTPClient.fetch(protobufURL)
    let json = shouldFetchJSON ? await Self.freshJSONFeed(for: endpoint) : nil
    return FeedPayload(protobuf: protobuf, json: json)
  }

  private static func freshJSONFeed(for endpoint: String) async -> Data? {
    let jsonURL = URL(string: "\(endpoint).json")!
    do {
      let json = try await HTTPClient.fetch(jsonURL)
      if !isLikelyJSON(json) {
        print("Skipping non-JSON feed \(jsonURL.absoluteString)")
        return nil
      }
      if !isFreshMTAJSONFeed(json) {
        print("Skipping stale JSON feed \(jsonURL.absoluteString)")
        return nil
      }
      return json
    } catch {
      print("Skipping JSON feed \(jsonURL.absoluteString): \(error)")
      return nil
    }
  }

  private func compare(
    station: StationGroup,
    feedData: [MTALine: LineFeeds],
    now: Date
  ) async throws -> StationAuditResult {
    var appArrivals: [ComparableArrival] = []
    var jsonComparableAppArrivals: [ComparableArrival] = []
    var jsonArrivals: [ComparableArrival] = []

    for line in station.lines {
      guard let feeds = feedData[line] else { continue }
      for stop in station.stops {
        let stopValue = stop.value
        for payload in feeds.payloads {
          let payloadAppArrivals = try getTrainArrivalsForStop(
            stop: stopValue,
            feedData: payload.protobuf,
            stopNamesByGTFSID: stopNameByGTFSID
          )
          .filter { $0.arrivalTime > now }
          .map { ComparableArrival(appArrival: $0) }

          appArrivals.append(contentsOf: payloadAppArrivals)

          guard comparisonMode.includesGTFSJSON,
            let json = payload.json
          else {
            continue
          }

          jsonComparableAppArrivals.append(contentsOf: payloadAppArrivals)
          jsonArrivals.append(
            contentsOf: try JSONArrivalDecoder.arrivals(
              for: stopValue,
              feedData: json,
              stopNameByGTFSID: stopNameByGTFSID
            )
            .filter { $0.arrivalTime > now }
          )
        }
      }
    }

    let appSet = Set(appArrivals)
    let uniqueAppArrivals = Array(appSet)
    let uniqueJSONComparableAppArrivals = Array(Set(jsonComparableAppArrivals))
    let uniqueJSONArrivals = Array(Set(jsonArrivals))
    var comparisons: [ArrivalComparisonResult] = []
    if comparisonMode.includesGTFSJSON {
      if uniqueJSONComparableAppArrivals.isEmpty, uniqueJSONArrivals.isEmpty {
        comparisons.append(
          ArrivalComparisonResult(
            referenceName: "gtfs-json",
            appCount: 0,
            referenceCount: 0,
            mismatches: [],
            skippedReason: "no fresh JSON reference feed"
          )
        )
      } else {
        comparisons.append(
          ArrivalComparator.exact(
            appArrivals: uniqueJSONComparableAppArrivals,
            referenceArrivals: uniqueJSONArrivals,
            referenceName: "gtfs-json"
          )
        )
      }
    }

    if comparisonMode.includesMTAWeb {
      var webArrivals: [ComparableArrival] = []
      for stop in station.stops {
        let data = try await HTTPClient.fetch(MTAWebEndpoint.nearbyURL(for: stop.gtfsStopID))
        webArrivals.append(
          contentsOf: try MTAWebArrivalDecoder.arrivals(
            for: stop.value,
            feedData: data
          )
          .filter { $0.arrivalTime > now }
        )
      }

      comparisons.append(
        ArrivalComparator.visibleFields(
          appArrivals: uniqueAppArrivals,
          referenceArrivals: webArrivals,
          referenceName: "mta-web"
        )
      )
    }

    return StationAuditResult(
      station: station,
      appCount: appSet.count,
      comparisons: comparisons
    )
  }
}

struct FeedPayload {
  let protobuf: Data
  let json: Data?
}

struct LineFeeds {
  let payloads: [FeedPayload]
}

func isLikelyJSON(_ data: Data) -> Bool {
  data
    .drop { byte in
      byte == 0x09 || byte == 0x0A || byte == 0x0D || byte == 0x20
    }
    .first
    .map { $0 == 0x5B || $0 == 0x7B }
    ?? false
}

func isFreshMTAJSONFeed(
  _ data: Data,
  now: Date = Date(),
  staleAfter seconds: TimeInterval = 6 * 60 * 60
) -> Bool {
  guard let freshness = try? JSONDecoder().decode(MTAJSONFeedFreshness.self, from: data),
    let timestamp = freshness.header.timestamp
  else {
    return false
  }

  return abs(now.timeIntervalSince1970 - Double(timestamp)) <= seconds
}

struct MTAJSONFeedFreshness: Decodable {
  let header: Header

  struct Header: Decodable {
    let timestamp: Int64?
  }
}

enum HTTPClient {
  static func fetch(_ url: URL) async throws -> Data {
    var request = URLRequest(url: url)
    request.httpMethod = "GET"
    request.setValue("ChooChooAudit/1.0", forHTTPHeaderField: "User-Agent")

    let (data, response) = try await URLSession.shared.data(for: request)
    guard let httpResponse = response as? HTTPURLResponse else {
      throw AuditError.network("no HTTP response for \(url.absoluteString)")
    }
    guard (200...299).contains(httpResponse.statusCode) else {
      throw AuditError.network("\(url.absoluteString) returned \(httpResponse.statusCode)")
    }
    return data
  }
}

enum MTAWebEndpoint {
  private static let apiKey = "Z276E3rCeTzOQEoBPPN4JCEc6GfvdnYE"

  static func nearbyURL(for stopID: String) -> URL {
    var components = URLComponents(
      string: "https://otp-mta-prod.camsys-apps.com/otp/routers/default/nearby"
    )!
    components.queryItems = [
      URLQueryItem(name: "stops", value: "MTASBWY:\(stopID)"),
      URLQueryItem(name: "timeRange", value: "84600"),
      URLQueryItem(name: "apikey", value: apiKey),
    ]
    return components.url!
  }
}

struct MTAWebStopResponse: Decodable {
  let groups: [MTAWebGroup]
}

struct MTAWebGroup: Decodable {
  let route: MTAWebRoute
  let headsign: String
  let times: [MTAWebTime]
}

struct MTAWebRoute: Decodable {
  let id: String
}

struct MTAWebTime: Decodable {
  let stopID: String
  let departureFmt: String?
  let tripHeadsign: String?
  let tripID: String?

  enum CodingKeys: String, CodingKey {
    case stopID = "stopId"
    case departureFmt
    case tripHeadsign
    case tripID = "tripId"
  }
}

enum MTAWebArrivalDecoder {
  static func arrivals(
    for stop: MTAStopValue,
    feedData: Data
  ) throws -> [ComparableArrival] {
    let responses = try JSONDecoder().decode([MTAWebStopResponse].self, from: feedData)
    var arrivals: [ComparableArrival] = []
    let dateFormatter = ISO8601DateFormatter()

    for response in responses {
      for group in response.groups {
        let routeID = agencylessID(group.route.id)
        guard let train = MTATrain(routeID: routeID) else { continue }

        for time in group.times {
          let stopID = agencylessID(time.stopID)
          guard String(stopID.dropLast()) == stop.gtfsStopID,
            let departureFmt = time.departureFmt,
            let departure = dateFormatter.date(from: departureFmt)
          else {
            continue
          }

          let direction: TripDirection = stopID.hasSuffix("S") ? .south : .north
          arrivals.append(ComparableArrival(
            tripID: agencylessID(time.tripID ?? ""),
            stopID: stopID,
            train: train.rawValue,
            arrivalTimestamp: Int64(departure.timeIntervalSince1970),
            terminalStation: time.tripHeadsign ?? group.headsign,
            direction: direction,
            directionLabel: stop.getLabelFor(direction: direction)
          ))
        }
      }
    }

    return arrivals
  }
}

struct MTAJSONFeed: Decodable {
  let entity: [MTAJSONEntity]
}

struct MTAJSONEntity: Decodable {
  let tripUpdate: MTAJSONTripUpdate?

  enum CodingKeys: String, CodingKey {
    case tripUpdate = "trip_update"
  }
}

struct MTAJSONTripUpdate: Decodable {
  let trip: MTAJSONTrip
  let stopTimeUpdate: [MTAJSONStopTimeUpdate]

  enum CodingKeys: String, CodingKey {
    case trip
    case stopTimeUpdate = "stop_time_update"
  }
}

struct MTAJSONTrip: Decodable {
  let tripID: String
  let routeID: String
  let nyctTripDescriptor: MTAJSONNYCTTripDescriptor?

  enum CodingKeys: String, CodingKey {
    case tripID = "trip_id"
    case routeID = "route_id"
    case nyctTripDescriptor = "nyct_trip_descriptor"
  }
}

struct MTAJSONNYCTTripDescriptor: Decodable {
  let direction: Int?
}

struct MTAJSONStopTimeUpdate: Decodable {
  let stopID: String
  let arrival: MTAJSONStopTimeEvent?
  let departure: MTAJSONStopTimeEvent?
  let scheduleRelationship: Int?

  enum CodingKeys: String, CodingKey {
    case stopID = "stop_id"
    case arrival
    case departure
    case scheduleRelationship = "schedule_relationship"
  }

  var baseStopID: String {
    String(stopID.dropLast())
  }

  var bestArrivalTimestamp: Int64? {
    if let time = arrival?.time, time > 0 {
      return time
    }
    if let time = departure?.time, time > 0 {
      return time
    }
    return nil
  }

  var isUsableArrival: Bool {
    (scheduleRelationship ?? 0) == 0 && bestArrivalTimestamp != nil
  }
}

struct MTAJSONStopTimeEvent: Decodable {
  let time: Int64?
}

enum JSONArrivalDecoder {
  static func arrivals(
    for stop: MTAStopValue,
    feedData: Data,
    stopNameByGTFSID: [String: String]
  ) throws -> [ComparableArrival] {
    let feed = try JSONDecoder().decode(MTAJSONFeed.self, from: feedData)
    let tripUpdates: [MTAJSONTripUpdate] = feed.entity.compactMap { entity in
      entity.tripUpdate
    }

    return tripUpdates.flatMap { tripUpdate in
      let terminalStopID = tripUpdate.stopTimeUpdate
        .last(where: \.isUsableArrival)?
        .baseStopID
      let terminal = terminalStopID.flatMap { stopNameByGTFSID[$0] }
        ?? "Unknown Destination."

      var arrivals: [ComparableArrival] = []
      for stopTimeUpdate in tripUpdate.stopTimeUpdate {
        guard stopTimeUpdate.isUsableArrival,
          stopTimeUpdate.baseStopID == stop.gtfsStopID,
          let timestamp = stopTimeUpdate.bestArrivalTimestamp,
          let train = MTATrain(routeID: tripUpdate.trip.routeID)
        else {
          continue
        }

        let tripID = standardizeTripIDForSevenTrain(tripUpdate.trip.tripID)
        let direction = tripDirection(
          nyctDirection: tripUpdate.trip.nyctTripDescriptor?.direction,
          fallbackTripID: tripID
        )

        arrivals.append(ComparableArrival(
          tripID: tripID,
          stopID: stopTimeUpdate.stopID,
          train: train.rawValue,
          arrivalTimestamp: timestamp,
          terminalStation: terminal,
          direction: direction,
          directionLabel: stop.getLabelFor(direction: direction)
        ))
      }

      return arrivals
    }
  }

  private static func tripDirection(
    nyctDirection: Int?,
    fallbackTripID: String
  ) -> TripDirection {
    switch nyctDirection {
    case 1:
      return .north
    case 3:
      return .south
    default:
      return ChooChooCore.tripDirection(for: fallbackTripID)
    }
  }
}

struct ComparableArrival: Hashable, Comparable {
  let tripID: String
  let stopID: String
  let train: String
  let arrivalTimestamp: Int64
  let terminalStation: String
  let direction: TripDirection
  let directionLabel: String

  init(
    tripID: String,
    stopID: String,
    train: String,
    arrivalTimestamp: Int64,
    terminalStation: String,
    direction: TripDirection,
    directionLabel: String
  ) {
    self.tripID = tripID
    self.stopID = stopID
    self.train = train
    self.arrivalTimestamp = arrivalTimestamp
    self.terminalStation = terminalStation
    self.direction = direction
    self.directionLabel = directionLabel
  }

  init(appArrival: TrainArrivalEntry) {
    self.init(
      tripID: appArrival.tripID,
      stopID: appArrival.stopID,
      train: appArrival.train.rawValue,
      arrivalTimestamp: Int64(appArrival.arrivalTime.timeIntervalSince1970),
      terminalStation: appArrival.terminalStation,
      direction: appArrival.direction,
      directionLabel: appArrival.directionLabel
    )
  }

  var arrivalTime: Date {
    Date(timeIntervalSince1970: Double(arrivalTimestamp))
  }

  static func < (lhs: ComparableArrival, rhs: ComparableArrival) -> Bool {
    if lhs.arrivalTimestamp != rhs.arrivalTimestamp {
      return lhs.arrivalTimestamp < rhs.arrivalTimestamp
    }
    if lhs.train != rhs.train { return lhs.train < rhs.train }
    if lhs.stopID != rhs.stopID { return lhs.stopID < rhs.stopID }
    return lhs.tripID < rhs.tripID
  }

  var summary: String {
    let minutes = max(0, Int((arrivalTime.timeIntervalSinceNow / 60).rounded()))
    return "\(train) \(stopID) \(minutes)m to \(terminalStation) \(directionLabel) [\(tripID)]"
  }
}

enum ArrivalMismatch {
  case onlyInApp(ComparableArrival)
  case onlyInReference(ComparableArrival)
  case differentDetails(
    app: ComparableArrival,
    reference: ComparableArrival,
    differences: [String]
  )

  var sortArrival: ComparableArrival {
    switch self {
    case .onlyInApp(let arrival), .onlyInReference(let arrival):
      return arrival
    case .differentDetails(let app, _, _):
      return app
    }
  }

  func summary(referenceName: String) -> String {
    switch self {
    case .onlyInApp(let arrival):
      return "only app:  \(arrival.summary)"
    case .onlyInReference(let arrival):
      return "only \(referenceName): \(arrival.summary)"
    case .differentDetails(let app, let reference, let differences):
      return
        "details:   \(app.train) \(app.stopID) \(app.minutesAway)m "
        + "app(\(app.visibleDetails)) \(referenceName)(\(reference.visibleDetails)) "
        + differences.joined(separator: "; ")
    }
  }

  func bucketKind(referenceName: String) -> String {
    switch self {
    case .onlyInApp:
      return "only app"
    case .onlyInReference:
      return "only \(referenceName)"
    case .differentDetails(_, _, let differences):
      return differences
        .map { difference in
          difference.hasPrefix("time ") ? "time" : difference
        }
        .joined(separator: "+")
    }
  }
}

struct ArrivalComparisonResult {
  let referenceName: String
  let appCount: Int
  let referenceCount: Int
  let mismatches: [ArrivalMismatch]
  let skippedReason: String?

  init(
    referenceName: String,
    appCount: Int,
    referenceCount: Int,
    mismatches: [ArrivalMismatch],
    skippedReason: String? = nil
  ) {
    self.referenceName = referenceName
    self.appCount = appCount
    self.referenceCount = referenceCount
    self.mismatches = mismatches
    self.skippedReason = skippedReason
  }
}

enum ArrivalComparator {
  static func exact(
    appArrivals: [ComparableArrival],
    referenceArrivals: [ComparableArrival],
    referenceName: String
  ) -> ArrivalComparisonResult {
    let appArrivals = appArrivals.sorted()
    let referenceArrivals = referenceArrivals.sorted()
    let difference = referenceArrivals.difference(from: appArrivals)

    let mismatches = difference.compactMap { change -> ArrivalMismatch? in
      switch change {
      case .remove(_, let arrival, _):
        return .onlyInApp(arrival)
      case .insert(_, let arrival, _):
        return .onlyInReference(arrival)
      }
    }

    return ArrivalComparisonResult(
      referenceName: referenceName,
      appCount: appArrivals.count,
      referenceCount: referenceArrivals.count,
      mismatches: mismatches.sorted { $0.sortArrival < $1.sortArrival }
    )
  }

  static func visibleFields(
    appArrivals: [ComparableArrival],
    referenceArrivals: [ComparableArrival],
    referenceName: String
  ) -> ArrivalComparisonResult {
    let pairingTolerance: Int64 = 90
    let timingMismatchThreshold = pairingTolerance
    let appHorizon = appArrivals.reduce(into: [ArrivalSeriesKey: Int64]()) {
      result, arrival in
      result[arrival.seriesKey] = max(
        result[arrival.seriesKey] ?? arrival.arrivalTimestamp,
        arrival.arrivalTimestamp
      )
    }
    let referenceHorizon = referenceArrivals.reduce(into: [ArrivalSeriesKey: Int64]()) {
      result, arrival in
      result[arrival.seriesKey] = max(
        result[arrival.seriesKey] ?? arrival.arrivalTimestamp,
        arrival.arrivalTimestamp
      )
    }
    let boundedAppArrivals = appArrivals.filter { arrival in
      guard let maxReferenceTimestamp = referenceHorizon[arrival.seriesKey] else {
        return true
      }
      return arrival.arrivalTimestamp <= maxReferenceTimestamp
    }
    let boundedReferenceArrivals = referenceArrivals.filter { arrival in
      guard let maxAppTimestamp = appHorizon[arrival.seriesKey] else {
        return true
      }
      return arrival.arrivalTimestamp <= maxAppTimestamp
    }

    let appBySeries = Dictionary(grouping: boundedAppArrivals, by: \.seriesKey)
    let referenceBySeries = Dictionary(grouping: boundedReferenceArrivals, by: \.seriesKey)
    let allSeries = Set(appBySeries.keys).union(referenceBySeries.keys)
    var mismatches: [ArrivalMismatch] = []

    for series in allSeries {
      var appMatches = appBySeries[series, default: []].sorted()
      let referenceMatches = referenceBySeries[series, default: []].sorted()

      for reference in referenceMatches {
        guard let matchIndex = nearestArrivalIndex(
          to: reference,
          in: appMatches,
          tolerance: pairingTolerance
        ) else {
          mismatches.append(.onlyInReference(reference))
          continue
        }

        let app = appMatches.remove(at: matchIndex)
        let differences = detailDifferences(
          app: app,
          reference: reference,
          timingMismatchThreshold: timingMismatchThreshold
        )
        if !differences.isEmpty {
          mismatches.append(
            .differentDetails(
              app: app,
              reference: reference,
              differences: differences
            )
          )
        }
      }

      mismatches.append(contentsOf: appMatches.map(ArrivalMismatch.onlyInApp))
    }

    return ArrivalComparisonResult(
      referenceName: referenceName,
      appCount: boundedAppArrivals.count,
      referenceCount: boundedReferenceArrivals.count,
      mismatches: mismatches.sorted { $0.sortArrival < $1.sortArrival }
    )
  }

  private static func nearestArrivalIndex(
    to reference: ComparableArrival,
    in appArrivals: [ComparableArrival],
    tolerance: Int64
  ) -> Int? {
    appArrivals.indices
      .map { index in
        (index: index, delta: abs(appArrivals[index].arrivalTimestamp - reference.arrivalTimestamp))
      }
      .filter { $0.delta <= tolerance }
      .min { $0.delta < $1.delta }?
      .index
  }

  private static func detailDifferences(
    app: ComparableArrival,
    reference: ComparableArrival,
    timingMismatchThreshold: Int64
  ) -> [String] {
    var differences: [String] = []
    let timingDelta = app.arrivalTimestamp - reference.arrivalTimestamp
    if abs(timingDelta) > timingMismatchThreshold {
      differences.append("time \(timingDelta)s")
    }
    if normalizedText(app.terminalStation) != normalizedText(reference.terminalStation) {
      differences.append("terminal")
    }
    if normalizedText(app.directionLabel) != normalizedText(reference.directionLabel) {
      differences.append("direction")
    }
    return differences
  }
}

struct ArrivalSeriesKey: Hashable {
  let stopID: String
  let train: String
}

extension ComparableArrival {
  var seriesKey: ArrivalSeriesKey {
    ArrivalSeriesKey(stopID: stopID, train: train)
  }

  var minutesAway: Int {
    max(0, Int((arrivalTime.timeIntervalSinceNow / 60).rounded()))
  }

  var visibleDetails: String {
    "to \(terminalStation), \(directionLabel)"
  }
}

func agencylessID(_ id: String) -> String {
  id.split(separator: ":").last.map(String.init) ?? id
}

func normalizedText(_ text: String) -> String {
  text
    .replacingOccurrences(of: "-", with: " ")
    .replacingOccurrences(of: "&", with: "and")
    .lowercased()
    .split(whereSeparator: \.isWhitespace)
    .joined(separator: " ")
}

struct StationAuditResult {
  let station: StationGroup
  let appCount: Int
  let comparisons: [ArrivalComparisonResult]

  var mismatchCount: Int {
    comparisons.reduce(0) { $0 + $1.mismatches.count }
  }

  func printSummary() {
    for comparison in comparisons {
      if let skippedReason = comparison.skippedReason {
        print(
          "SKIP \(comparison.referenceName) \(station.complexID) \(station.name): "
            + skippedReason
        )
        continue
      }

      if comparison.mismatches.isEmpty {
        print(
          "OK \(comparison.referenceName) \(station.complexID) \(station.name): "
            + "\(comparison.appCount) arrivals"
        )
        continue
      }

      print(
        "DIFF \(comparison.referenceName) \(station.complexID) \(station.name): "
          + "app \(comparison.appCount), \(comparison.referenceName) "
          + "\(comparison.referenceCount), mismatches \(comparison.mismatches.count)"
      )
      for mismatch in comparison.mismatches.prefix(20) {
        print("  \(mismatch.summary(referenceName: comparison.referenceName))")
      }
      if comparison.mismatches.count > 20 {
        print("  ... \(comparison.mismatches.count - 20) more")
      }
    }
  }
}

struct AuditRunSummary {
  private var buckets: [MismatchBucket: MismatchBucketSummary] = [:]

  mutating func record(_ result: StationAuditResult) {
    for comparison in result.comparisons {
      for mismatch in comparison.mismatches {
        let bucket = MismatchBucket(
          referenceName: comparison.referenceName,
          stationID: result.station.complexID,
          stationName: result.station.name,
          kind: mismatch.bucketKind(referenceName: comparison.referenceName)
        )
        buckets[bucket, default: MismatchBucketSummary()].record(
          mismatch.summary(referenceName: comparison.referenceName)
        )
      }
    }
  }

  func printSummary() {
    guard !buckets.isEmpty else {
      print("No mismatch buckets.")
      return
    }

    print("\nMismatch buckets:")
    for (bucket, summary) in buckets.sorted(by: sortBuckets).prefix(20) {
      print(
        "  \(summary.count)x \(bucket.referenceName) "
          + "\(bucket.stationID) \(bucket.stationName) \(bucket.kind)"
      )
      print("    e.g. \(summary.example)")
    }
  }

  private func sortBuckets(
    lhs: (key: MismatchBucket, value: MismatchBucketSummary),
    rhs: (key: MismatchBucket, value: MismatchBucketSummary)
  ) -> Bool {
    if lhs.value.count != rhs.value.count {
      return lhs.value.count > rhs.value.count
    }
    if lhs.key.stationID != rhs.key.stationID {
      return lhs.key.stationID < rhs.key.stationID
    }
    return lhs.key.kind < rhs.key.kind
  }
}

struct MismatchBucket: Hashable {
  let referenceName: String
  let stationID: Int
  let stationName: String
  let kind: String
}

struct MismatchBucketSummary {
  private(set) var count = 0
  private(set) var example = ""

  mutating func record(_ example: String) {
    count += 1
    if self.example.isEmpty {
      self.example = example
    }
  }
}
