import Foundation

struct MTAStation {
  let id: Int
  let name: String
  let stops: [MTAStop]

  init(id: Int, name: String, stops: [MTAStop]) {
    self.id = id
    self.name = name
    self.stops = stops
  }
}

func mergeStops(_ stops: [MTAStop]) -> [MTAStation] {
  let stationToStops = Dictionary(grouping: stops, by: { $0.stationID })

  let stations = stationToStops.map { (stationID, stationStops) in
    let stationName = stationStops.first?.stopName ?? "Unknown"
    return MTAStation(id: stationID, name: stationName, stops: stationStops)
  }

  return stations
}
