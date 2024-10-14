import CoreLocation
import SwiftUI

struct StationSign: View {
  var station: MTAStation
  var trains: [MTATrain]

  var location: CLLocation?

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
                top: 12,
                leading: 12,
                bottom: 6,
                trailing: 4
              )
            )
          Spacer()
        }
        HStack {
          ScrollView(.horizontal) {
            HStack {
              ForEach(trains) { route in
                TrainBadge(train: route, badgeSize: .small)
              }
              Spacer()
            }
          }
        }.padding(
          EdgeInsets(
            top: 0,
            leading: 12,
            bottom: 12,
            trailing: 12
          )
        )
        .scrollIndicators(.hidden)
      }
      .background(.black)
      .overlay(
        Rectangle()
          .fill(.white)
          .frame(height: 2)
          .padding(.top, 12),
        alignment: .top
      )

      HStack {
        if let location {
          Text(
            formattedDistanceTraveled(
              distance: location.distance(from: station.location))
          ).font(.headline)
            .bold()
            .fontDesign(.rounded)
            .foregroundStyle(.secondary)
        }
        Spacer()
        PinButton(station: station)
      }.padding(
        EdgeInsets(
          top: 0,
          leading: 12,
          bottom: 0,
          trailing: 12
        )
      ).background(
        .ultraThickMaterial
      )

    }.cornerRadius(8)
  }
}
