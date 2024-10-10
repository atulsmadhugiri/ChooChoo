import SwiftUI

struct StationSign: View {
  var station: MTAStation
  var trains: [MTATrain]
  var body: some View {
    BaseStationSign(station: station, trains: trains)
  }
}
