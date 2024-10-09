import CoreLocation

class LocationFetcher: NSObject, ObservableObject, CLLocationManagerDelegate {
  let locationManager = CLLocationManager()

  @Published var location: CLLocation?

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
  }

}
