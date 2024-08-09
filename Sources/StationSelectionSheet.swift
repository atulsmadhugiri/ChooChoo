import SwiftUI

struct StationSelectionSheet: View {
  var body: some View {
    List(mtaStations) { station in
      StationSign(stationName: station.stopName, trains: station.daytimeRoutes)
    }
  }
}

#Preview {
  StationSelectionSheet()
}
