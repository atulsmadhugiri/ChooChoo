import Foundation

struct MTAStationSnapshot: Sendable {
  let lines: [MTALine]
  let stops: [MTAStopValue]
  let stopNamesByGTFSID: [String: String]
}
