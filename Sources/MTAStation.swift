import CoreLocation
import Foundation

struct MTAStation {
  let stationID: Int
  let complexID: Int
  let gtfsStopID: String
  let division: String
  let line: String
  let stopName: String
  let borough: String
  let daytimeRoutes: String
  let structure: String
  let gtfsLatitude: Double
  let gtfsLongitude: Double
  let northDirectionLabel: String
  let southDirectionLabel: String
  let ada: String
  let adaDirectionNotes: String
  let adaNB: String
  let adaSB: String
  let capitalOutageNB: String
  let capitalOutageSB: String

  var location: CLLocation {
    CLLocation(latitude: self.gtfsLatitude, longitude: self.gtfsLongitude)
  }
}
