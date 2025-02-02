import Foundation

struct MTAServiceAlert: Identifiable {
  let id: UUID = UUID()
  let stopID: String
  let header: String
  let description: String
  let activePeriod: [DateInterval]
}

extension MTAServiceAlert {
  var earliestStart: Date {
    activePeriod.map { $0.start }.min() ?? Date.distantFuture
  }

  var earliestEnd: Date {
    activePeriod.map { $0.end }.min() ?? Date.distantFuture
  }
}
