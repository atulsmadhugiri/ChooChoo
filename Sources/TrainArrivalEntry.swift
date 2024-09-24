import Foundation

struct TrainArrivalEntry: Identifiable {
  let id = UUID()
  let arrivalTime: Date
  let train: MTATrain
  let terminalStation: String
  let direction: TripDirection
  let directionLabel: String

  init(
    arrivalTimestamp: Int64,
    train: MTATrain,
    terminalStation: String,
    direction: TripDirection,
    directionLabel: String
  ) {
    self.arrivalTime = Date(timeIntervalSince1970: Double(arrivalTimestamp))
    self.train = train
    self.terminalStation = terminalStation
    self.direction = direction
    self.directionLabel = directionLabel
  }
}
