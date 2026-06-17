import ChooChooCore
import Foundation

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
