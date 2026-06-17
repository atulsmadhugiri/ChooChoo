import Foundation

public struct TrainArrivalEntry: Identifiable, Equatable, Sendable {
  public let id: String
  public let tripID: String
  public let stopID: String
  public let arrivalTime: Date
  public let train: MTATrain
  public let terminalStation: String
  public let direction: TripDirection
  public let directionLabel: String

  public init(
    id: String,
    tripID: String? = nil,
    stopID: String = "",
    arrivalTimestamp: Int64,
    train: MTATrain,
    terminalStation: String,
    direction: TripDirection,
    directionLabel: String
  ) {
    self.id = id
    self.tripID = tripID ?? id
    self.stopID = stopID
    self.arrivalTime = Date(timeIntervalSince1970: Double(arrivalTimestamp))
    self.train = train
    self.terminalStation = terminalStation
    self.direction = direction
    self.directionLabel = directionLabel
  }
}
