import CoreLocation
import SwiftUI

struct StationSelectionSheet: View {
  var location: CLLocation?

  var body: some View {
    if let location {
      let sorted = mtaStations.sorted(by: {
        location.distance(from: $0.location)
          < location.distance(from: $1.location)
      })
      List(sorted) { station in
        StationSign(
          stationName: station.stopName, trains: station.daytimeRoutes)
      }
    }
  }
}

#Preview {
  StationSelectionSheet()
}
