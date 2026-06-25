import CoreLocation
import MapKit
import SwiftUI

struct MapsButton: View {
  var station: MTAStation

  let feedback = UIImpactFeedbackGenerator(style: .light)

  var body: some View {
    Button {
      openMaps()
      feedback.impactOccurred()
    } label: {
      Label("Open in Maps", systemImage: "map")
        .font(.headline)
        .foregroundStyle(.secondary)
        .frame(height: 28)
        .padding(.vertical, 10)
    }
    .buttonStyle(.bordered)
    .tint(.primary)
  }

  private func openMaps() {
    let placemark = MKPlacemark(
      coordinate: station.location.coordinate
    )

#if os(iOS) || targetEnvironment(macCatalyst)
    let stationName = station.name
    let mapItem = MKMapItem(placemark: placemark)
    mapItem.name = stationName

    let launchOptions = [
      MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving,
    ]

    mapItem.openInMaps(launchOptions: launchOptions, from: nil) { success in
      let result = success ? "success" : "failure"
      print("Opened Maps for \(stationName): \(result)")
    }
#endif
  }
}
