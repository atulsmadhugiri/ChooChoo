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
  let stopID: String
  let header: String
  let description: String?
  let activePeriod: [MTAServiceAlertTimeRange]

  init(
    stopID: String,
    header: String,
    description: String?,
    activePeriod: [MTAServiceAlertTimeRange]
  ) {
    self.stopID = stopID
    self.header = header
    self.description = description
    self.activePeriod = activePeriod
    self.id = [
      stopID,
      header,
      description ?? "",
      activePeriod.map(\.idComponent).joined(separator: ","),
    ].joined(separator: "|")
  }
}

extension MTAServiceAlert {
  var earliestStart: Date {
    activePeriod.map(\.sortStart).min() ?? Date.distantFuture
  }

  var earliestEnd: Date {
    activePeriod.map(\.sortEnd).min() ?? Date.distantFuture
  }
}
