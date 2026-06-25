import MapKit
import SwiftUI

struct MapsButton: View {
  let station: MTAStation

  private let feedback = UIImpactFeedbackGenerator(style: .light)

  var body: some View {
    Button {
      openMaps()
      feedback.impactOccurred()
    } label: {
      Image(systemName: "map")
        .foregroundStyle(.secondary)
        .frame(height: 22)
        .imageScale(.large)
    }
    .buttonStyle(.bordered)
    .tint(.primary)
    .padding(.vertical, 10)
    .accessibilityLabel("Open \(station.name) in Maps")
  }

  private func openMaps() {
#if os(iOS) || targetEnvironment(macCatalyst)
    let placemark = MKPlacemark(coordinate: station.location.coordinate)
    let mapItem = MKMapItem(placemark: placemark)
    mapItem.name = station.name

    let launchOptions = [
      MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving,
    ]

    mapItem.openInMaps(launchOptions: launchOptions, from: nil)
#endif
  }
}
