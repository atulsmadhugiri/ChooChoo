import Foundation

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
