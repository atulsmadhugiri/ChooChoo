import PostHog
import SwiftUI

struct ContentView: View {
  @StateObject private var locationFetcher = LocationFetcher()
  @State var trainArrivals: [TrainArrivalEntry] = []

  @State var selectionSheetActive: Bool = false

  @State private var selectedDirection: TripDirection = .south
  @State private var selectedStation: MTAStation?

  @State private var loading: Bool = true

  let tapHaptic = UIImpactFeedbackGenerator(style: .medium)

  var body: some View {
    VStack(spacing: 0) {
      let visibleStation = selectedStation ?? locationFetcher.nearestStation
      if let visibleStation {
        StationSign(
          stationName: visibleStation.name,
          trains: visibleStation.daytimeRoutes
        ).onTapGesture {
          tapHaptic.impactOccurred()
          selectionSheetActive = true
          PostHogSDK.shared.capture(
            "user_tapped_station_sign",
            properties: ["currentStation": visibleStation.name])
        }.padding()
          .shadow(radius: 2)
      }

      Divider()

      let visibleArrivals = trainArrivals.filter {
        $0.direction == selectedDirection
      }

      VStack {
        Picker("", selection: $selectedDirection) {
          Text(TripDirection.south.rawValue).tag(TripDirection.south)
          Text(TripDirection.north.rawValue).tag(TripDirection.north)
        }.pickerStyle(.segmented).labelsHidden().padding(.bottom, 8)

        List(visibleArrivals) { arrival in
          ArrivalCard(arrival: arrival)
        }.listStyle(.plain)
          .background(.background)
          .cornerRadius(8)
          .clipped()
          .refreshable {}
          .shadow(radius: 2)
          .overlay {
            if visibleArrivals.isEmpty, !loading {
              ContentUnavailableView {
                Label(
                  "No trains running in this direction.",
                  systemImage: "wrongwaysign.fill")
              }
            }
          }
      }
      .padding()
    }
    .background(.ultraThickMaterial)
    .onChange(of: locationFetcher.nearestStation) {
      if selectedStation != nil {
        return
      }
      Task {
        loading = true
        defer {
          loading = false
        }
        guard let nearestStation = locationFetcher.nearestStation else {
          return
        }
        trainArrivals = await nearestStation.getArrivals()
        let sameDirection = trainArrivals.filter {
          $0.direction == selectedDirection
        }
        if sameDirection.isEmpty {
          selectedDirection = selectedDirection.flipped
        }
      }
    }.onChange(of: selectedStation) {
      Task {
        loading = true
        defer {
          loading = false
        }
        guard let selectedStation else { return }
        trainArrivals = await selectedStation.getArrivals()
        let sameDirection = trainArrivals.filter {
          $0.direction == selectedDirection
        }
        if sameDirection.isEmpty {
          selectedDirection = selectedDirection.flipped
        }
      }
    }.sheet(isPresented: $selectionSheetActive) {
      StationSelectionSheet(
        location: locationFetcher.location,
        isPresented: $selectionSheetActive,
        selectedStation: $selectedStation)
    }.onAppear {
      tapHaptic.prepare()
    }
  }
}

#Preview {
  ContentView()
}
