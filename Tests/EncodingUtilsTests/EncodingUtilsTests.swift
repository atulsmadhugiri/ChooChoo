import Testing
@testable import EncodingUtils

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
}
