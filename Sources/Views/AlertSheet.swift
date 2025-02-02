import SwiftUI

struct AlertSheet: View {
  let serviceAlerts: [MTAServiceAlert]

  var sortedAlerts: [MTAServiceAlert] {
    serviceAlerts.sorted { lhs, rhs in
      if lhs.earliestStart != rhs.earliestStart {
        return lhs.earliestStart < rhs.earliestStart
      } else {
        return lhs.earliestEnd < rhs.earliestEnd
      }
    }
  }

  var body: some View {
    NavigationView {
      List {
        ForEach(sortedAlerts) { alert in
          AlertBox(alertBody: alert.header, activePeriods: alert.activePeriod)
            .listRowSeparator(.hidden)
            .backgroundStyle(.thickMaterial)
            .scrollContentBackground(.hidden)
            .listRowBackground(Color.clear)
        }
      }
      .scrollContentBackground(.hidden)
      .listStyle(.plain)
      .navigationBarTitle("Service Alerts", displayMode: .inline)
      .backgroundStyle(.thickMaterial)
    }
  }
}
