import CoreLocation
import Foundation

class LocationFetcher: NSObject, ObservableObject, CLLocationManagerDelegate {
  let locationManager = CLLocationManager()

  @Published var location: CLLocation?

  private var distanceThreshold: CLLocationDistance {
    ProcessInfo.processInfo.isLowPowerModeEnabled ? 500 : 100
  }

  override init() {
    super.init()
    locationManager.delegate = self
    locationManager.pausesLocationUpdatesAutomatically = true
    configureAccuracy()
    updateAuthorizationState()
  }

  func locationManager(
    _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
  ) {
    guard locations.last != nil else { return }
    location = locations.last
  }

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    updateAuthorizationState()
  }

  func locationManager(
    _ manager: CLLocationManager,
    didFailWithError error: Error
  ) {
    print("Location update failed: \(error)")
  }

  private func updateAuthorizationState() {
    switch locationManager.authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse:
      configureAccuracy()
      locationManager.startUpdatingLocation()
    case .denied, .restricted:
      locationManager.stopUpdatingLocation()
    case .notDetermined:
      locationManager.requestWhenInUseAuthorization()
    @unknown default:
      break
    }
  }

  private func configureAccuracy() {
    locationManager.desiredAccuracy = ProcessInfo.processInfo.isLowPowerModeEnabled
      ? kCLLocationAccuracyKilometer
      : kCLLocationAccuracyHundredMeters
    locationManager.distanceFilter = distanceThreshold
  }
}
