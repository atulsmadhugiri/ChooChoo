import Foundation

struct MTAServiceAlertTimeRange {
  let start: Date?
  let end: Date?

  func contains(_ date: Date) -> Bool {
    let startsBeforeDate = start.map { $0 <= date } ?? true
    let endsAfterDate = end.map { date < $0 } ?? true
    return startsBeforeDate && endsAfterDate
  }

  var sortStart: Date {
    start ?? Date.distantPast
  }

  var sortEnd: Date {
    end ?? Date.distantFuture
  }
}

struct MTAServiceAlert: Identifiable {
  let id: UUID = UUID()
  let stopID: String
  let header: String
  let description: String?
  let activePeriod: [MTAServiceAlertTimeRange]
}

extension MTAServiceAlert {
  var earliestStart: Date {
    activePeriod.map(\.sortStart).min() ?? Date.distantFuture
  }

  var earliestEnd: Date {
    activePeriod.map(\.sortEnd).min() ?? Date.distantFuture
  }
}
