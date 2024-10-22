import SwiftUI

struct AlertSheet: View {
  let serviceAlerts: [MTAServiceAlert]

  var body: some View {
    NavigationView {
      List {
        ForEach(serviceAlerts) { serviceAlert in
          AlertBox(alertBody: serviceAlert.header).listRowSeparator(.hidden)
        }
      }.listStyle(.plain)
        .navigationBarTitle(
          "Service Alerts",
          displayMode: .inline
        )
    }
  }
}

#Preview {
  AlertSheet(serviceAlerts: [])
}
