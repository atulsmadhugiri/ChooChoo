import Testing
@testable import ChooChooCore

struct EncodingUtilsTests {
    @Test func tripDirectionNorth() {
        #expect(tripDirection(for: "ABC..N12") == .north)
    }

    @Test func tripDirectionSouth() {
        #expect(tripDirection(for: "ABC..S12") == .south)
    }

    @Test func standardizeTripID() {
        #expect(standardizeTripIDForSevenTrain("XYZ_7X..NB") == "XYZ_7..NB")
    }

    @Test func routeIDMapsKnownShuttlesToShuttleTrain() {
        #expect(MTATrain(routeID: "S") == .s)
        #expect(MTATrain(routeID: "FS") == .s)
        #expect(MTATrain(routeID: "GS") == .s)
        #expect(MTATrain(routeID: "H") == .s)
    }

    @Test func routeIDMapsExpressSixAndSevenToLocalBadges() {
        #expect(MTATrain(routeID: "6X") == .six)
        #expect(MTATrain(routeID: "7X") == .seven)
    }

    @Test func shuttleLineReadsAllShuttleFeeds() {
        #expect(MTALine.s.endpoints.contains { $0.hasSuffix("nyct%2Fgtfs") })
        #expect(MTALine.s.endpoints.contains { $0.hasSuffix("nyct%2Fgtfs-bdfm") })
        #expect(MTALine.s.endpoints.contains { $0.hasSuffix("nyct%2Fgtfs-ace") })
    }

    @Test func stopValueDirectionLabelsUseSharedInversionRules() {
        let hudsonYards = MTAStopValue(
            gtfsStopID: "726",
            complexID: 471,
            division: "IRT",
            line: "Flushing",
            stopName: "34 St-Hudson Yards",
            daytimeRoutesString: "7",
            gtfsLatitude: 0,
            gtfsLongitude: 0,
            northDirectionLabel: "Hudson Yards",
            southDirectionLabel: "Queens"
        )

        #expect(hudsonYards.getLabelFor(direction: .north) == "Queens")
        #expect(hudsonYards.getLabelFor(direction: .south) == "Hudson Yards")
    }

    @Test func lastStopDirectionLabelUsesStopName() {
        let hudsonYards = MTAStopValue(
            gtfsStopID: "726",
            complexID: 471,
            division: "IRT",
            line: "Flushing",
            stopName: "34 St-Hudson Yards",
            daytimeRoutesString: "7",
            gtfsLatitude: 0,
            gtfsLongitude: 0,
            northDirectionLabel: "Last Stop",
            southDirectionLabel: "Queens"
        )

        #expect(hudsonYards.getLabelFor(direction: .south) == "34 St-Hudson Yards")
    }

    @Test func nyctTripDescriptorDirectionBeatsTripIDSuffix() {
        var entity = TransitRealtime_FeedEntity()
        entity.id = "trip"
        entity.tripUpdate = makeTripUpdate(
            tripID: "ABC..N",
            routeID: "1",
            nyctDirection: .south,
            stopUpdates: [
                makeStopTimeUpdate(stopID: "120S", arrival: 1_800_000_000),
                makeStopTimeUpdate(stopID: "121S", arrival: 1_800_000_100),
            ]
        )

        let arrivals = getTrainArrivalsForStop(
            stop: stopValue(gtfsStopID: "120"),
            feed: [entity],
            stopNamesByGTFSID: ["121": "Next Stop"]
        )

        #expect(arrivals.count == 1)
        #expect(arrivals.first?.direction == .south)
    }

    @Test func terminalStationIgnoresNoDataMarker() {
        var entity = TransitRealtime_FeedEntity()
        entity.id = "trip"
        entity.tripUpdate = makeTripUpdate(
            tripID: "ABC..S",
            routeID: "1",
            nyctDirection: .south,
            stopUpdates: [
                makeStopTimeUpdate(stopID: "120S", arrival: 1_800_000_000),
                makeStopTimeUpdate(stopID: "121S", arrival: 1_800_000_100),
                makeStopTimeUpdate(
                    stopID: "999S",
                    arrival: nil,
                    relationship: .noData
                ),
            ]
        )

        let arrivals = getTrainArrivalsForStop(
            stop: stopValue(gtfsStopID: "120"),
            feed: [entity],
            stopNamesByGTFSID: ["121": "Usable Terminal", "999": "No Data Marker"]
        )

        #expect(arrivals.first?.terminalStation == "Usable Terminal")
    }

    @Test func rockawayShuttleUsesTerminalFallbackForNoDataTerminal() {
        var entity = TransitRealtime_FeedEntity()
        entity.id = "trip"
        entity.tripUpdate = makeTripUpdate(
            tripID: "ABC_H..N",
            routeID: "H",
            nyctDirection: .north,
            stopUpdates: [
                makeStopTimeUpdate(stopID: "H15N", arrival: 1_800_000_000),
                makeStopTimeUpdate(
                    stopID: "H04N",
                    arrival: nil,
                    relationship: .noData
                ),
            ]
        )

        let arrivals = getTrainArrivalsForStop(
            stop: stopValue(gtfsStopID: "H15"),
            feed: [entity],
            stopNamesByGTFSID: [
                "H04": "Broad Channel",
                "H15": "Rockaway Park-Beach 116 St",
            ]
        )

        #expect(arrivals.first?.terminalStation == "Broad Channel")
    }

    @Test func franklinShuttleUsesTerminalFallbackForNoDataTerminal() {
        var entity = TransitRealtime_FeedEntity()
        entity.id = "trip"
        entity.tripUpdate = makeTripUpdate(
            tripID: "ABC_FS..S",
            routeID: "FS",
            nyctDirection: .south,
            stopUpdates: [
                makeStopTimeUpdate(stopID: "S01S", arrival: 1_800_000_000),
                makeStopTimeUpdate(
                    stopID: "D26S",
                    arrival: nil,
                    relationship: .noData
                ),
            ]
        )

        let arrivals = getTrainArrivalsForStop(
            stop: stopValue(gtfsStopID: "S01"),
            feed: [entity],
            stopNamesByGTFSID: [
                "D26": "Prospect Park",
                "S01": "Franklin Av",
            ]
        )

        #expect(arrivals.first?.terminalStation == "Prospect Park")
    }

    @Test func grandCentralShuttleUsesTerminalFallbackForNoDataTerminal() {
        var entity = TransitRealtime_FeedEntity()
        entity.id = "trip"
        entity.tripUpdate = makeTripUpdate(
            tripID: "ABC_GS..N",
            routeID: "GS",
            nyctDirection: .north,
            stopUpdates: [
                makeStopTimeUpdate(stopID: "901N", arrival: 1_800_000_000),
                makeStopTimeUpdate(
                    stopID: "902N",
                    arrival: nil,
                    relationship: .noData
                ),
            ]
        )

        let arrivals = getTrainArrivalsForStop(
            stop: stopValue(gtfsStopID: "901"),
            feed: [entity],
            stopNamesByGTFSID: [
                "901": "Grand Central-42 St",
                "902": "Times Sq-42 St",
            ]
        )

        #expect(arrivals.first?.terminalStation == "Times Sq-42 St")
    }

    @Test func grandCentralShuttleSouthboundFallbackUsesGrandCentral() {
        var entity = TransitRealtime_FeedEntity()
        entity.id = "trip"
        entity.tripUpdate = makeTripUpdate(
            tripID: "ABC_GS..S",
            routeID: "GS",
            nyctDirection: .south,
            stopUpdates: [
                makeStopTimeUpdate(stopID: "902S", arrival: 1_800_000_000),
                makeStopTimeUpdate(
                    stopID: "901S",
                    arrival: nil,
                    relationship: .noData
                ),
            ]
        )

        let arrivals = getTrainArrivalsForStop(
            stop: stopValue(gtfsStopID: "902"),
            feed: [entity],
            stopNamesByGTFSID: [
                "901": "Grand Central-42 St",
                "902": "Times Sq-42 St",
            ]
        )

        #expect(arrivals.first?.terminalStation == "Grand Central-42 St")
    }

    @Test func departureTimestampIsUsedWhenArrivalIsMissing() {
        var entity = TransitRealtime_FeedEntity()
        entity.id = "trip"
        entity.tripUpdate = makeTripUpdate(
            tripID: "ABC..N",
            routeID: "1",
            nyctDirection: .north,
            stopUpdates: [
                makeStopTimeUpdate(
                    stopID: "120N",
                    arrival: nil,
                    departure: 1_800_000_100
                ),
                makeStopTimeUpdate(stopID: "121N", arrival: 1_800_000_200),
            ]
        )

        let arrivals = getTrainArrivalsForStop(
            stop: stopValue(gtfsStopID: "120"),
            feed: [entity],
            stopNamesByGTFSID: ["121": "Terminal"]
        )

        #expect(arrivals.first?.arrivalTime.timeIntervalSince1970 == 1_800_000_100)
    }

    @Test func arrivalTimestampBeatsDepartureTimestamp() {
        var entity = TransitRealtime_FeedEntity()
        entity.id = "trip"
        entity.tripUpdate = makeTripUpdate(
            tripID: "ABC..N",
            routeID: "1",
            nyctDirection: .north,
            stopUpdates: [
                makeStopTimeUpdate(
                    stopID: "120N",
                    arrival: 1_800_000_100,
                    departure: 1_800_000_200
                ),
                makeStopTimeUpdate(stopID: "121N", arrival: 1_800_000_300),
            ]
        )

        let arrivals = getTrainArrivalsForStop(
            stop: stopValue(gtfsStopID: "120"),
            feed: [entity],
            stopNamesByGTFSID: ["121": "Terminal"]
        )

        #expect(arrivals.first?.arrivalTime.timeIntervalSince1970 == 1_800_000_100)
    }

    @Test func skippedSelectedStopIsIgnoredEvenWhenItHasATime() {
        var entity = TransitRealtime_FeedEntity()
        entity.id = "trip"
        entity.tripUpdate = makeTripUpdate(
            tripID: "ABC..N",
            routeID: "1",
            nyctDirection: .north,
            stopUpdates: [
                makeStopTimeUpdate(
                    stopID: "120N",
                    arrival: 1_800_000_100,
                    relationship: .skipped
                ),
                makeStopTimeUpdate(stopID: "121N", arrival: 1_800_000_200),
            ]
        )

        let arrivals = getTrainArrivalsForStop(
            stop: stopValue(gtfsStopID: "120"),
            feed: [entity],
            stopNamesByGTFSID: ["121": "Terminal"]
        )

        #expect(arrivals.isEmpty)
    }

    @Test func eastWestNYCTDirectionFallsBackToTripIDSuffix() {
        var entity = TransitRealtime_FeedEntity()
        entity.id = "trip"
        entity.tripUpdate = makeTripUpdate(
            tripID: "ABC..S",
            routeID: "1",
            nyctDirection: .east,
            stopUpdates: [
                makeStopTimeUpdate(stopID: "120S", arrival: 1_800_000_000),
                makeStopTimeUpdate(stopID: "121S", arrival: 1_800_000_100),
            ]
        )

        let arrivals = getTrainArrivalsForStop(
            stop: stopValue(gtfsStopID: "120"),
            feed: [entity],
            stopNamesByGTFSID: ["121": "Terminal"]
        )

        #expect(arrivals.first?.direction == .south)
    }

    @Test func unknownRouteIDDoesNotCreateArrival() {
        var entity = TransitRealtime_FeedEntity()
        entity.id = "trip"
        entity.tripUpdate = makeTripUpdate(
            tripID: "ABC..N",
            routeID: "UNKNOWN",
            nyctDirection: .north,
            stopUpdates: [
                makeStopTimeUpdate(stopID: "120N", arrival: 1_800_000_000),
                makeStopTimeUpdate(stopID: "121N", arrival: 1_800_000_100),
            ]
        )

        let arrivals = getTrainArrivalsForStop(
            stop: stopValue(gtfsStopID: "120"),
            feed: [entity],
            stopNamesByGTFSID: ["121": "Terminal"]
        )

        #expect(arrivals.isEmpty)
    }

    @Test func arrivalsAreSortedAndIDsIncludeTimestamp() {
        var later = TransitRealtime_FeedEntity()
        later.id = "later"
        later.tripUpdate = makeTripUpdate(
            tripID: "ABC..N",
            routeID: "1",
            nyctDirection: .north,
            stopUpdates: [
                makeStopTimeUpdate(stopID: "120N", arrival: 1_800_000_200),
                makeStopTimeUpdate(stopID: "121N", arrival: 1_800_000_300),
            ]
        )

        var earlier = TransitRealtime_FeedEntity()
        earlier.id = "earlier"
        earlier.tripUpdate = makeTripUpdate(
            tripID: "ABC..N",
            routeID: "1",
            nyctDirection: .north,
            stopUpdates: [
                makeStopTimeUpdate(stopID: "120N", arrival: 1_800_000_100),
                makeStopTimeUpdate(stopID: "121N", arrival: 1_800_000_300),
            ]
        )

        let arrivals = getTrainArrivalsForStop(
            stop: stopValue(gtfsStopID: "120"),
            feed: [later, earlier],
            stopNamesByGTFSID: ["121": "Terminal"]
        )

        #expect(arrivals.map(\.arrivalTime.timeIntervalSince1970) == [
            1_800_000_100,
            1_800_000_200,
        ])
        #expect(Set(arrivals.map(\.id)).count == 2)
    }
}

private func stopValue(gtfsStopID: String) -> MTAStopValue {
    MTAStopValue(
        gtfsStopID: gtfsStopID,
        complexID: 1,
        division: "IRT",
        line: "Broadway - 7Av",
        stopName: "Test Stop",
        daytimeRoutesString: "1",
        gtfsLatitude: 0,
        gtfsLongitude: 0,
        northDirectionLabel: "North",
        southDirectionLabel: "South"
    )
}

private func makeTripUpdate(
    tripID: String,
    routeID: String,
    nyctDirection: NyctTripDescriptor.Direction,
    stopUpdates: [TransitRealtime_TripUpdate.StopTimeUpdate]
) -> TransitRealtime_TripUpdate {
    var tripDescriptor = TransitRealtime_TripDescriptor()
    tripDescriptor.tripID = tripID
    tripDescriptor.routeID = routeID
    var nyctTripDescriptor = NyctTripDescriptor()
    nyctTripDescriptor.direction = nyctDirection
    tripDescriptor.nyctTripDescriptor = nyctTripDescriptor

    var tripUpdate = TransitRealtime_TripUpdate()
    tripUpdate.trip = tripDescriptor
    tripUpdate.stopTimeUpdate = stopUpdates
    return tripUpdate
}

private func makeStopTimeUpdate(
    stopID: String,
    arrival: Int64? = nil,
    departure: Int64? = nil,
    relationship: TransitRealtime_TripUpdate.StopTimeUpdate.ScheduleRelationship = .scheduled
) -> TransitRealtime_TripUpdate.StopTimeUpdate {
    var stopTimeUpdate = TransitRealtime_TripUpdate.StopTimeUpdate()
    stopTimeUpdate.stopID = stopID
    stopTimeUpdate.scheduleRelationship = relationship

    if let arrival {
        var event = TransitRealtime_TripUpdate.StopTimeEvent()
        event.time = arrival
        stopTimeUpdate.arrival = event
    }

    if let departure {
        var event = TransitRealtime_TripUpdate.StopTimeEvent()
        event.time = departure
        stopTimeUpdate.departure = event
    }

    return stopTimeUpdate
}
