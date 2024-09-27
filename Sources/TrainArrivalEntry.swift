import Foundation

struct TrainArrivalEntry: Identifiable {
  let id: String
  let arrivalTime: Date
  let train: MTATrain
  let terminalStation: String
  let direction: TripDirection
  let directionLabel: String

  init(
    id: String,
    arrivalTimestamp: Int64,
    train: MTATrain,
    terminalStation: String,
    direction: TripDirection,
    directionLabel: String
  ) {
    self.id = id
    self.arrivalTime = Date(timeIntervalSince1970: Double(arrivalTimestamp))
    self.train = train
    self.terminalStation = terminalStation
    self.direction = direction
    self.directionLabel = directionLabel
  }
}
