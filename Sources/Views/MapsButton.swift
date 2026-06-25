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
    }.buttonStyle(.bordered)
      .tint(.primary)
  }
  
  private func openMaps() {
    let placemark = MKPlacemark(
      coordinate: station.location.coordinate,
      name: station.name
    )
    
#if os(iOS) || targetEnvironment(macCatalyst)
    let mapItem = MKMapItem(placemark: placemark)
    mapItem.openInMaps(launchOptions: [.mode: MKLaunchMode.Car]) { success in
      print("Opened Maps for \(station.name): \(success ? \"success\" : \"failure\")")
    }
#endif
  }
}
