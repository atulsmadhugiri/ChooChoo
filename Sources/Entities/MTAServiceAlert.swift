import Foundation

struct MTAServiceAlert: Identifiable {
  let id: UUID = UUID()
  let stopID: String
  let header: String
  let description: String
  let activePeriod: [DateInterval]
}
