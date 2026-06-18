import Foundation

struct MTAFeedCachePolicy: Sendable {
  let freshness: Duration
  let staleFallback: Duration?

  static let realtime = MTAFeedCachePolicy(
    freshness: .seconds(8),
    staleFallback: .seconds(90)
  )

  static let serviceAlerts = MTAFeedCachePolicy(
    freshness: .seconds(60),
    staleFallback: .seconds(600)
  )
}

actor MTAFeedClient {
  typealias Fetch = @Sendable (URL) async throws -> Data

  static let shared = MTAFeedClient()

  private struct CacheEntry {
    let data: Data
    let fetchedAt: ContinuousClock.Instant
  }

  private let clock = ContinuousClock()
  private let fetch: Fetch
  private var cache: [URL: CacheEntry] = [:]
  private var inFlight: [URL: Task<Data, Error>] = [:]

  init(
    fetch: @escaping Fetch = { url in
      try await NetworkUtils.sendNetworkRequest(to: url)
    }
  ) {
    self.fetch = fetch
  }

  func data(
    from endpoint: MTAFeedEndpoint,
    cachePolicy: MTAFeedCachePolicy = .realtime
  ) async throws -> Data {
    try await data(from: endpoint.url, cachePolicy: cachePolicy)
  }

  func data(
    from url: URL,
    cachePolicy: MTAFeedCachePolicy = .realtime
  ) async throws -> Data {
    let now = clock.now
    if let cachedData = cachedData(for: url, now: now, maxAge: cachePolicy.freshness) {
      return cachedData
    }

    if let task = inFlight[url] {
      return try await value(
        from: task,
        url: url,
        cachePolicy: cachePolicy
      )
    }

    let fetch = fetch
    let task = Task<Data, Error> {
      try await fetch(url)
    }
    inFlight[url] = task
    defer { inFlight[url] = nil }

    do {
      let data = try await task.value
      cache[url] = CacheEntry(data: data, fetchedAt: clock.now)
      return data
    } catch {
      if let staleData = staleData(for: url, cachePolicy: cachePolicy) {
        return staleData
      }
      throw error
    }
  }

  private func value(
    from task: Task<Data, Error>,
    url: URL,
    cachePolicy: MTAFeedCachePolicy
  ) async throws -> Data {
    do {
      return try await task.value
    } catch {
      if let staleData = staleData(for: url, cachePolicy: cachePolicy) {
        return staleData
      }
      throw error
    }
  }

  private func cachedData(
    for url: URL,
    now: ContinuousClock.Instant,
    maxAge: Duration
  ) -> Data? {
    guard let entry = cache[url],
      entry.fetchedAt.duration(to: now) <= maxAge
    else {
      return nil
    }
    return entry.data
  }

  private func staleData(
    for url: URL,
    cachePolicy: MTAFeedCachePolicy
  ) -> Data? {
    guard let staleFallback = cachePolicy.staleFallback else { return nil }
    return cachedData(for: url, now: clock.now, maxAge: staleFallback)
  }
}

func fetchMTARealtimePayloads(
  from endpoints: [MTAFeedEndpoint],
  using feedClient: MTAFeedClient = .shared
) async throws -> [Data] {
  try await withThrowingTaskGroup(of: Data.self) { group in
    for endpoint in endpoints {
      group.addTask {
        try await feedClient.data(from: endpoint, cachePolicy: .realtime)
      }
    }

    var payloads: [Data] = []
    payloads.reserveCapacity(endpoints.count)
    for try await data in group {
      payloads.append(data)
    }
    return payloads
  }
}

func decodeMTARealtimeFeeds(
  from payloads: [Data]
) throws -> TransitRealtime_FeedMessage {
  var mergedFeed = TransitRealtime_FeedMessage()
  for payload in payloads {
    let feed = try parseMTARealtimeFeed(from: payload)
    mergedFeed.entity.append(contentsOf: feed.entity)
  }
  return mergedFeed
}

func fetchMTAServiceAlerts(
  using feedClient: MTAFeedClient = .shared
) async throws -> [TransitRealtime_Alert] {
  let data = try await feedClient.data(
    from: .serviceAlerts,
    cachePolicy: .serviceAlerts
  )
  let feed = try TransitRealtime_FeedMessage(serializedBytes: data)
  return feed.entity.compactMap { $0.hasAlert ? $0.alert : nil }
}
