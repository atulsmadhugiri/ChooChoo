import CoreLocation

let mtaStops: [MTAStop] = loadStopsFromCSV()
let mtaStopsByGTFSID: [String: MTAStop] = Dictionary(
  uniqueKeysWithValues: mtaStops.map { ($0.gtfsStopID, $0) }
)
let mtaStations = mergeStops(mtaStops)

class LocationFetcher: NSObject, ObservableObject, CLLocationManagerDelegate {
  let locationManager = CLLocationManager()

  @Published var location: CLLocation?
  @Published var nearestStation: MTAStation?

  private let distanceThreshold: CLLocationDistance = 15

  override init() {
    super.init()
    locationManager.delegate = self
    locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
    locationManager.distanceFilter = distanceThreshold
    locationManager.pausesLocationUpdatesAutomatically = true
    locationManager.requestWhenInUseAuthorization()
    locationManager.startUpdatingLocation()
  }

  func locationManager(
    _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
  ) {
    guard locations.last != nil else { return }
    location = locations.last
    nearestStation = getNearestStation(from: locations.last)
  }

  func getNearestStation(from currentLocation: CLLocation?) -> MTAStation? {
    guard let currentLocation = currentLocation else { return nil }
    return mtaStations.min(by: {
      currentLocation.distance(from: $0.location)
        < currentLocation.distance(from: $1.location)
    })
  }
}
