import CoreLocation
import SwiftUI

struct StationSign: View {
  let station: MTAStation

  let distance: CLLocationDistance?
  let serviceAlerts: [MTAServiceAlert]

  @State private var alertSheetActive = false

  var body: some View {
    VStack(spacing: 0) {
      VStack(spacing: 0) {
        HStack(alignment: .bottom) {
          Text(station.name)
            .font(.title)
            .foregroundStyle(.white)
            .bold()
            .padding(
              EdgeInsets(
                top: 18,
                leading: 12,
                bottom: 8,
                trailing: 4
              )
            )
          Spacer()
        }
        ScrollView(.horizontal, showsIndicators: false) {
          HStack {
            ForEach(station.daytimeRoutes) { route in
              TrainBadge(train: route)
            }
            Spacer()
          }
        }
        .padding(
          EdgeInsets(
            top: 0,
            leading: 12,
            bottom: 12,
            trailing: 12
          )
        )
      }
      .background(.black)
      .overlay(
        Rectangle()
          .fill(.white)
          .frame(height: 2)
          .padding(.top, 14),
        alignment: .top
      )

      HStack {
        Text(distanceText)
          .font(.headline)
          .bold()
          .fontDesign(.rounded)
          .foregroundStyle(.secondary)
          .padding(.horizontal, 12)
          .padding(.vertical, 7)
          .background(
            Capsule()
              .fill(Color.secondary.opacity(0.12))
          )
          .overlay(
            Capsule()
              .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
          )
          .padding(.vertical, 10)
          .accessibilityLabel(distanceText)

        Spacer()

        if !serviceAlerts.isEmpty {
          AlertIndicator(
            alertCount: serviceAlerts.count,
            alertSheetActive: $alertSheetActive
          )
        }

        PinButton(station: station)
      }.padding(
        EdgeInsets(
          top: 0,
          leading: 12,
          bottom: 0,
          trailing: 12
        )
      ).background(
        Color(.secondarySystemGroupedBackground)
      )

    }.clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
      .sheet(isPresented: $alertSheetActive) {
        AlertSheet(serviceAlerts: serviceAlerts)
          .presentationDetents([
            .medium, .large,
          ])
          .presentationDragIndicator(.visible)
          .presentationBackground(.thickMaterial)
      }
  }

  private var distanceText: String {
    distance.map(formattedDistanceTraveled(distance:)) ?? "Station"
  }
}
