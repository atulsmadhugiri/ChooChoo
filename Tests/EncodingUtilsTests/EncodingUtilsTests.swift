import Foundation
import TabularData
import Testing
@testable import ChooChooCore

struct EncodingUtilsTests {
    @Test func tripDirectionNorth() {
        #expect(tripDirection(for: "ABC..N12") == .north)
    }

    @Test func tripDirectionSouth() {
        #expect(tripDirection(for: "ABC..S12") == .south)
    }

    @Test func tripDirectionStorageValuesAreStable() {
        #expect(TripDirection(storageValue: "north") == .north)
        #expect(TripDirection(storageValue: "south") == .south)
        #expect(TripDirection.north.storageValue == "north")
        #expect(TripDirection.south.storageValue == "south")
        #expect(TripDirection(storageValue: "Uptown & The Bronx") == nil)
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
        #expect(MTALine.s.endpoints == [.main, .bdfm, .ace])
    }

    @Test func feedEndpointsBuildEncodedMTAURLs() throws {
        #expect(
            try MTAFeedEndpoint.main.url.absoluteString
                == "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs")
        #expect(
            try MTAFeedEndpoint.main.jsonURL.absoluteString
                == "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/nyct%2Fgtfs.json")
        #expect(
            try MTAFeedEndpoint.serviceAlerts.url.absoluteString
                == "https://api-endpoint.mta.info/Dataservice/mtagtfsfeeds/camsys%2Fsubway-alerts")
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

    @Test func gtfsStopIDOnlyStripsDirectionalSuffixes() {
        #expect(GTFSStopID("120N").baseID == "120")
        #expect(GTFSStopID("120N").direction == .north)
        #expect(GTFSStopID("H15S").baseID == "H15")
        #expect(GTFSStopID("H15S").direction == .south)
        #expect(GTFSStopID("R01").baseID == "R01")
        #expect(GTFSStopID("R01").direction == nil)
    }

    @Test func serviceAlertsKeepHeaderOnlyAlertsAndNormalizeStopIDs() {
        var alert = TransitRealtime_Alert()
        alert.headerText = translatedString("Service change")
        var northEntity = TransitRealtime_EntitySelector()
        northEntity.stopID = "120N"
        var southEntity = TransitRealtime_EntitySelector()
        southEntity.stopID = "120S"
        alert.informedEntity = [northEntity, southEntity]

        let alertsByStopID = constructServiceAlerts(from: [alert])

        #expect(alertsByStopID.keys.contains("120"))
        #expect(alertsByStopID["120"]?.count == 1)
        #expect(alertsByStopID["120"]?.first?.header == "Service change")
        #expect(alertsByStopID["120"]?.first?.description == nil)
    }

    @Test func serviceAlertPeriodsPreserveOpenEndedRanges() {
        var startOnly = TransitRealtime_TimeRange()
        startOnly.start = 1_800_000_000
        var endOnly = TransitRealtime_TimeRange()
        endOnly.end = 1_800_000_100

        let periods = timeRangesToServiceAlertPeriods(timeRanges: [startOnly, endOnly])

        #expect(periods.count == 2)
        #expect(periods[0].start == Date(timeIntervalSince1970: 1_800_000_000))
        #expect(periods[0].end == nil)
        #expect(periods[0].contains(Date(timeIntervalSince1970: 1_800_000_050)))
        #expect(periods[1].start == nil)
        #expect(periods[1].end == Date(timeIntervalSince1970: 1_800_000_100))
        #expect(periods[1].contains(Date(timeIntervalSince1970: 1_800_000_050)))
    }

    @Test func missingServiceAlertPeriodIsActiveWhileInFeed() {
        let periods = timeRangesToServiceAlertPeriods(timeRanges: [])

        #expect(periods.count == 1)
        #expect(periods[0].start == nil)
        #expect(periods[0].end == nil)
        #expect(periods[0].contains(Date(timeIntervalSince1970: 1_800_000_000)))
    }

    @Test func mtaFeedClientUsesFreshCacheWithoutRefetching() async throws {
        let url = try #require(URL(string: "https://example.com/feed"))
        let firstPayload = Data("first".utf8)
        let secondPayload = Data("second".utf8)
        let recorder = FeedFetchRecorder(responses: [firstPayload, secondPayload])
        let client = MTAFeedClient(fetch: { url in
            try await recorder.fetch(url)
        })
        let cachePolicy = MTAFeedCachePolicy(
            freshness: .seconds(60),
            staleFallback: nil
        )

        let first = try await client.data(from: url, cachePolicy: cachePolicy)
        let second = try await client.data(from: url, cachePolicy: cachePolicy)

        #expect(first == firstPayload)
        #expect(second == firstPayload)
        #expect(await recorder.requestCount() == 1)
    }

    @Test func mtaFeedClientCoalescesInFlightRequests() async throws {
        let url = try #require(URL(string: "https://example.com/feed"))
        let payload = Data("shared".utf8)
        let recorder = FeedFetchRecorder(
            responses: [payload],
            delay: .milliseconds(50)
        )
        let client = MTAFeedClient(fetch: { url in
            try await recorder.fetch(url)
        })
        let cachePolicy = MTAFeedCachePolicy(
            freshness: .seconds(0),
            staleFallback: nil
        )

        async let first = client.data(from: url, cachePolicy: cachePolicy)
        async let second = client.data(from: url, cachePolicy: cachePolicy)
        let values = try await [first, second]

        #expect(values == [payload, payload])
        #expect(await recorder.requestCount() == 1)
    }

    @Test func mtaFeedClientFallsBackToStaleCacheOnFailure() async throws {
        let url = try #require(URL(string: "https://example.com/feed"))
        let payload = Data("stale but useful".utf8)
        let recorder = FeedFetchRecorder(responses: [payload])
        let client = MTAFeedClient(fetch: { url in
            try await recorder.fetch(url)
        })

        let initial = try await client.data(
            from: url,
            cachePolicy: MTAFeedCachePolicy(
                freshness: .seconds(60),
                staleFallback: .seconds(60)
            )
        )

        try await Task.sleep(for: .milliseconds(5))
        await recorder.setFailing(true)

        let fallback = try await client.data(
            from: url,
            cachePolicy: MTAFeedCachePolicy(
                freshness: .seconds(0),
                staleFallback: .seconds(60)
            )
        )

        #expect(initial == payload)
        #expect(fallback == payload)
        #expect(await recorder.requestCount() == 2)
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

    @Test func multiStopArrivalsMatchSingleStopUnion() {
        var entity = TransitRealtime_FeedEntity()
        entity.id = "trip"
        entity.tripUpdate = makeTripUpdate(
            tripID: "ABC..N",
            routeID: "1",
            nyctDirection: .north,
            stopUpdates: [
                makeStopTimeUpdate(stopID: "120N", arrival: 1_800_000_000),
                makeStopTimeUpdate(stopID: "121N", arrival: 1_800_000_100),
                makeStopTimeUpdate(stopID: "122N", arrival: 1_800_000_200),
            ]
        )

        let stops = [
            stopValue(gtfsStopID: "120"),
            stopValue(gtfsStopID: "121"),
        ]
        let stopNamesByGTFSID = ["122": "Terminal"]

        let multiStopArrivals = getTrainArrivalsForStops(
            stops: stops,
            feed: [entity],
            stopNamesByGTFSID: stopNamesByGTFSID
        )
        let singleStopArrivals = stops.flatMap {
            getTrainArrivalsForStop(
                stop: $0,
                feed: [entity],
                stopNamesByGTFSID: stopNamesByGTFSID
            )
        }

        #expect(multiStopArrivals.map(\.id) == singleStopArrivals.map(\.id))
        #expect(multiStopArrivals.map(\.stopID) == ["120N", "121N"])
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

    @Test func nyctDescriptorWithoutDirectionFallsBackToTripIDSuffix() {
        var entity = TransitRealtime_FeedEntity()
        entity.id = "trip"
        entity.tripUpdate = makeTripUpdateWithoutNYCTDirection(
            tripID: "ABC..S",
            routeID: "1",
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

    @Test func bundledStationCSVHasKnownSubwayRoutes() throws {
        let stops = try stationCSVStops()
        #expect(stops.count > 400)

        let stopsWithoutRoutes = stops.filter {
            MTATrain.routeTokens(in: $0.daytimeRoutesString).isEmpty
        }
        #expect(stopsWithoutRoutes.isEmpty)

        let unknownRoutes = stops.flatMap { stop in
            MTATrain.routeTokens(in: stop.daytimeRoutesString)
                .filter { MTATrain(rawValue: $0) == nil }
                .map { "\(stop.gtfsStopID):\($0)" }
        }
        #expect(unknownRoutes.isEmpty)
    }
}

private actor FeedFetchRecorder {
    private var responses: [Data]
    private var requests: [URL] = []
    private let delay: Duration
    private var failing = false

    init(
        responses: [Data],
        delay: Duration = .seconds(0)
    ) {
        self.responses = responses
        self.delay = delay
    }

    func fetch(_ url: URL) async throws -> Data {
        requests.append(url)
        try await Task.sleep(for: delay)

        if failing {
            throw URLError(.notConnectedToInternet)
        }

        let responseIndex = min(requests.count - 1, responses.count - 1)
        return responses[responseIndex]
    }

    func setFailing(_ failing: Bool) {
        self.failing = failing
    }

    func requestCount() -> Int {
        requests.count
    }
}

private func translatedString(_ text: String) -> TransitRealtime_TranslatedString {
    var translation = TransitRealtime_TranslatedString.Translation()
    translation.text = text
    var translatedString = TransitRealtime_TranslatedString()
    translatedString.translation = [translation]
    return translatedString
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

private func makeTripUpdateWithoutNYCTDirection(
    tripID: String,
    routeID: String,
    stopUpdates: [TransitRealtime_TripUpdate.StopTimeUpdate]
) -> TransitRealtime_TripUpdate {
    var tripDescriptor = TransitRealtime_TripDescriptor()
    tripDescriptor.tripID = tripID
    tripDescriptor.routeID = routeID
    // Attach a NYCT descriptor that carries metadata but leaves `direction`
    // unset, as the feed often does, so `hasDirection` is false.
    var nyctTripDescriptor = NyctTripDescriptor()
    nyctTripDescriptor.isAssigned = true
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

private func stationCSVStops() throws -> [MTAStopValue] {
    let testFileURL = URL(fileURLWithPath: #filePath)
    let packageRoot = testFileURL
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
    let csvURL = packageRoot.appending(path: "Resources/Stations.csv")
    let dataFrame = try DataFrame(contentsOfCSVFile: csvURL)
    return dataFrame.rows.compactMap(MTAStopValue.init(csvRow:))
}
