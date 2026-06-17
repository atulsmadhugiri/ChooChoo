import Foundation

public struct MTAStopValue: Sendable {
  public let gtfsStopID: String
  public let complexID: Int
  public let division: String
  public let line: String
  public let stopName: String
  public let daytimeRoutesString: String
  public let gtfsLatitude: Double
  public let gtfsLongitude: Double
  public let northDirectionLabel: String
  public let southDirectionLabel: String

  public init(
    gtfsStopID: String,
    complexID: Int,
    division: String,
    line: String,
    stopName: String,
    daytimeRoutesString: String,
    gtfsLatitude: Double,
    gtfsLongitude: Double,
    northDirectionLabel: String,
    southDirectionLabel: String
  ) {
    self.gtfsStopID = gtfsStopID
    self.complexID = complexID
    self.division = division
    self.line = line
    self.stopName = stopName
    self.daytimeRoutesString = daytimeRoutesString
    self.gtfsLatitude = gtfsLatitude
    self.gtfsLongitude = gtfsLongitude
    self.northDirectionLabel = northDirectionLabel
    self.southDirectionLabel = southDirectionLabel
  }

  public var daytimeRoutes: [MTATrain] {
    MTATrain.routes(in: daytimeRoutesString)
  }

  public var lines: Set<MTALine> {
    MTATrain.lines(in: daytimeRoutesString)
  }
}

extension MTAStopValue {
  public func getLabelFor(direction: TripDirection) -> String {
    return directionLabel(
      for: direction,
      gtfsStopID: gtfsStopID,
      northDirectionLabel: northDirectionLabel,
      southDirectionLabel: southDirectionLabel,
      stopName: stopName
    )
  }
}
