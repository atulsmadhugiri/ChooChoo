import Foundation

struct TrainArrivalEntry: Identifiable {
  let id = UUID()
  let arrivalTime: Date
  let train: MTATrain
  let terminalStation: String
  let direction: TripDirection
}
