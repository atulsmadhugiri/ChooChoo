import Foundation

struct MTAServiceAlertTimeRange: Hashable, Sendable {
  let start: Date?
  let end: Date?

  func contains(_ date: Date) -> Bool {
    let startsBeforeDate = start.map { $0 <= date } ?? true
    let endsAfterDate = end.map { date < $0 } ?? true
    return startsBeforeDate && endsAfterDate
  }

  func isRelevant(at date: Date) -> Bool {
    end.map { date < $0 } ?? true
  }

  var sortStart: Date {
    start ?? Date.distantPast
  }

  var sortEnd: Date {
    end ?? Date.distantFuture
  }

  var idComponent: String {
    let startComponent = start.map { String(Int64($0.timeIntervalSince1970)) } ?? "*"
    let endComponent = end.map { String(Int64($0.timeIntervalSince1970)) } ?? "*"
    return "\(startComponent)-\(endComponent)"
  }
}

struct MTAServiceAlert: Identifiable, Sendable {
  let id: String
  let stopIDs: Set<String>
  let routes: Set<MTATrain>
  let header: String
  let description: String?
  let activePeriod: [MTAServiceAlertTimeRange]

  init(
    stopIDs: Set<String>,
    routes: Set<MTATrain>,
    header: String,
    description: String?,
    activePeriod: [MTAServiceAlertTimeRange]
  ) {
    self.stopIDs = stopIDs
    self.routes = routes
    self.header = header
    self.description = description
    self.activePeriod = activePeriod
    self.id = [
      stopIDs.sorted().joined(separator: ","),
      routes.map(\.rawValue).sorted().joined(separator: ","),
      header,
      description ?? "",
      activePeriod.map(\.idComponent).joined(separator: ","),
    ].joined(separator: "|")
  }
}

extension MTAServiceAlert {
  func isRelevant(at date: Date) -> Bool {
    activePeriod.contains { $0.isRelevant(at: date) }
  }

  var earliestStart: Date {
    activePeriod.map(\.sortStart).min() ?? Date.distantFuture
  }

  var earliestEnd: Date {
    activePeriod.map(\.sortEnd).min() ?? Date.distantFuture
  }
}

struct MTAServiceAlerts: Sendable {
  static let empty = MTAServiceAlerts([])

  private let byStopID: [String: [MTAServiceAlert]]
  private let byRoute: [MTATrain: [MTAServiceAlert]]

  init(_ alerts: [MTAServiceAlert]) {
    var byStopID: [String: [MTAServiceAlert]] = [:]
    var byRoute: [MTATrain: [MTAServiceAlert]] = [:]

    for alert in alerts {
      for stopID in alert.stopIDs {
        byStopID[stopID, default: []].append(alert)
      }
      for route in alert.routes {
        byRoute[route, default: []].append(alert)
      }
    }

    self.byStopID = byStopID
    self.byRoute = byRoute
  }

  var isEmpty: Bool {
    byStopID.isEmpty && byRoute.isEmpty
  }

  var stopIDs: Set<String> {
    Set(byStopID.keys)
  }

  func alerts(forStopID stopID: String) -> [MTAServiceAlert] {
    byStopID[stopID] ?? []
  }

  func alerts(for route: MTATrain) -> [MTAServiceAlert] {
    byRoute[route] ?? []
  }
}
