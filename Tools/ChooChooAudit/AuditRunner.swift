import ChooChooCore
import Foundation

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
  ) async throws -> [MTAFeedEndpoint: FeedPayload] {
    let endpoints = stations
      .flatMap(\.lines)
      .flatMap(\.endpoints)
      .uniqued()
    let shouldFetchJSON = comparisonMode.includesGTFSJSON
    return try await withThrowingTaskGroup(of: (MTAFeedEndpoint, FeedPayload).self) { group in
      for endpoint in endpoints {
        group.addTask {
          let payload = try await Self.fetchPayload(
            endpoint: endpoint,
            includingJSON: shouldFetchJSON
          )
          return (endpoint, payload)
        }
      }

      var result: [MTAFeedEndpoint: FeedPayload] = [:]
      for try await (endpoint, payload) in group {
        result[endpoint] = payload
      }
      return result
    }
  }

  private static func fetchPayload(
    endpoint: MTAFeedEndpoint,
    includingJSON shouldFetchJSON: Bool
  ) async throws -> FeedPayload {
    let protobufURL = try endpoint.url
    let protobuf = try await HTTPClient.fetch(protobufURL)
    let json = shouldFetchJSON ? await Self.freshJSONFeed(for: endpoint) : nil
    return FeedPayload(protobuf: protobuf, json: json)
  }

  private static func freshJSONFeed(for endpoint: MTAFeedEndpoint) async -> Data? {
    let jsonURL: URL
    do {
      jsonURL = try endpoint.jsonURL
    } catch {
      print("Skipping invalid JSON feed URL \(endpoint.rawValue).json")
      return nil
    }

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
    feedData: [MTAFeedEndpoint: FeedPayload],
    now: Date
  ) async throws -> StationAuditResult {
    var appArrivals: [ComparableArrival] = []
    var jsonComparableAppArrivals: [ComparableArrival] = []
    var jsonArrivals: [ComparableArrival] = []

    let endpoints = station.lines.flatMap(\.endpoints).uniqued()
    for endpoint in endpoints {
      guard let payload = feedData[endpoint] else { continue }
      let payloadAppArrivals = try getTrainArrivalsForStops(
        stops: station.stops,
        feedData: payload.protobuf,
        stopNamesByGTFSID: stopNameByGTFSID
      )
      .filter { $0.isActive(at: now) }
      .map { ComparableArrival(appArrival: $0) }

      if comparisonMode.includesMTAWeb {
        appArrivals.append(contentsOf: payloadAppArrivals)
      }

      guard comparisonMode.includesGTFSJSON,
        let json = payload.json
      else {
        continue
      }

      jsonComparableAppArrivals.append(contentsOf: payloadAppArrivals)
      jsonArrivals.append(
        contentsOf: try JSONArrivalDecoder.arrivals(
          for: station.stops,
          feedData: json,
          stopNameByGTFSID: stopNameByGTFSID
        )
        .filter { $0.isActive(at: now) }
      )
    }

    var comparisons: [ArrivalComparisonResult] = []
    if comparisonMode.includesGTFSJSON {
      let uniqueJSONComparableAppArrivals = Array(Set(jsonComparableAppArrivals))
      let uniqueJSONArrivals = Array(Set(jsonArrivals))
      if uniqueJSONComparableAppArrivals.isEmpty, uniqueJSONArrivals.isEmpty {
        comparisons.append(
          ArrivalComparisonResult(
            referenceName: "gtfs-json",
            appCount: 0,
            referenceCount: 0,
            mismatches: [],
            skippedReason: "no fresh JSON reference feed",
            sampledAt: now
          )
        )
      } else {
        comparisons.append(
          ArrivalComparator.exact(
            appArrivals: uniqueJSONComparableAppArrivals,
            referenceArrivals: uniqueJSONArrivals,
            referenceName: "gtfs-json",
            sampledAt: now
          )
        )
      }
    }

    if comparisonMode.includesMTAWeb {
      let uniqueAppArrivals = Array(Set(appArrivals))
      var webArrivals: [ComparableArrival] = []
      for stop in station.stops {
        let data = try await HTTPClient.fetch(
          try MTAWebEndpoint.nearbyURL(for: stop.gtfsStopID)
        )
        webArrivals.append(
          contentsOf: try MTAWebArrivalDecoder.arrivals(
            for: stop,
            feedData: data
          )
          .filter { $0.isActive(at: now) }
        )
      }

      comparisons.append(
        ArrivalComparator.visibleFields(
          appArrivals: uniqueAppArrivals,
          referenceArrivals: webArrivals,
          referenceName: "mta-web",
          sampledAt: now
        )
      )
    }

    return StationAuditResult(
      station: station,
      comparisons: comparisons
    )
  }
}

struct FeedPayload {
  let protobuf: Data
  let json: Data?
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

private extension Sequence where Element: Hashable {
  func uniqued() -> [Element] {
    var seen = Set<Element>()
    return filter { seen.insert($0).inserted }
  }
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

  static func nearbyURL(for stopID: String) throws -> URL {
    guard var components = URLComponents(
      string: "https://otp-mta-prod.camsys-apps.com/otp/routers/default/nearby"
    ) else {
      throw AuditError.network("invalid MTA web endpoint")
    }
    components.queryItems = [
      URLQueryItem(name: "stops", value: "MTASBWY:\(stopID)"),
      URLQueryItem(name: "timeRange", value: "84600"),
      URLQueryItem(name: "apikey", value: apiKey),
    ]
    guard let url = components.url else {
      throw AuditError.network("could not build MTA web URL for stop \(stopID)")
    }
    return url
  }
}
