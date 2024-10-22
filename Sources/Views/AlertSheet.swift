import SwiftUI

struct AlertSheet: View {
  let serviceAlerts: [MTAServiceAlert]

  var body: some View {
    NavigationView {
      List {
        ForEach(serviceAlerts) { serviceAlert in
          AlertBox(alertBody: serviceAlert.header)
            .listRowSeparator(.hidden)
            .backgroundStyle(.thickMaterial)
            .scrollContentBackground(.hidden)
            .listRowBackground(Color.clear)

        }
      }.scrollContentBackground(.hidden)
        .listStyle(.plain)
        .navigationBarTitle(
          "Service Alerts",
          displayMode: .inline
        ).backgroundStyle(.thickMaterial)
    }
  }
}

#Preview {
  AlertSheet(serviceAlerts: [])
}
