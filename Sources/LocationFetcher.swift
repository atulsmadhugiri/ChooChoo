import CoreLocation
import Foundation

@MainActor
final class LocationFetcher: NSObject, ObservableObject, @preconcurrency CLLocationManagerDelegate {
  private let locationManager = CLLocationManager()

  @Published private(set) var location: CLLocation?

  private var isUpdatingLocation = false

  private var distanceThreshold: CLLocationDistance {
    ProcessInfo.processInfo.isLowPowerModeEnabled ? 500 : 100
  }

  private var maximumAcceptedAccuracy: CLLocationDistance {
    ProcessInfo.processInfo.isLowPowerModeEnabled ? 1_000 : 250
  }

  override init() {
    super.init()
    locationManager.delegate = self
    locationManager.pausesLocationUpdatesAutomatically = true
    updateAuthorizationState()
  }

  func locationManager(
    _ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]
  ) {
    guard let latestLocation = locations.reversed().first(where: isUsableLocation) else {
      return
    }

    location = latestLocation
    if latestLocation.horizontalAccuracy <= distanceThreshold {
      stopUpdatingLocation()
    }
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

  func refreshAuthorizationState() {
    updateAuthorizationState()
  }

  func stopUpdatingLocation() {
    locationManager.stopUpdatingLocation()
    isUpdatingLocation = false
  }

  private func updateAuthorizationState() {
    switch locationManager.authorizationStatus {
    case .authorizedAlways, .authorizedWhenInUse:
      configureAccuracy()
      startUpdatingLocation()
    case .denied, .restricted:
      location = nil
      stopUpdatingLocation()
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

  private func startUpdatingLocation() {
    guard !isUpdatingLocation else { return }
    locationManager.startUpdatingLocation()
    isUpdatingLocation = true
  }

  private func isUsableLocation(_ location: CLLocation) -> Bool {
    location.horizontalAccuracy >= 0
      && location.horizontalAccuracy <= maximumAcceptedAccuracy
      && abs(location.timestamp.timeIntervalSinceNow) <= 5 * 60
  }
}
