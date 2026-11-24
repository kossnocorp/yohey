import XCTest
@testable import YoheySchedule

final class DisplayLimitsTests: XCTestCase {
    func testReadsDisplayTimerForEachProfileIncludingNever() {
        let limits = DisplayLimits("""
        Battery Power:
         sleep          1
         displaysleep   2
        AC Power:
         displaysleep   0
        UPS Power:
         displaysleep   15
        """)
        XCTAssertEqual(limits.battery, 2)
        XCTAssertEqual(limits.adapter, 0)
    }

    func testDesktopDoesNotInventBatteryTimeout() {
        let limits = DisplayLimits("AC Power:\n displaysleep   180")
        XCTAssertNil(limits.battery)
        XCTAssertEqual(limits.adapter, 180)
    }
}
