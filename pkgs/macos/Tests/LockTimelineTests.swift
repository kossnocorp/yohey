import XCTest
@testable import YoheySchedule

final class LockTimelineTests: XCTestCase {
    func testOneMinuteDisplayAndFiveMinuteGrace() {
        var timeline = LockTimeline(), schedule = WarningSchedule()
        var chimes: [Int] = []
        for t in 0...360 {
            if t == 60 { timeline.begin(.displayOff, now: 60) }
            let limit = timeline.limit(now: Double(t), idle: Double(t), display: 60,
                                       saver: nil, delay: .seconds(300))!
            if schedule.shouldChime(idle: Double(t), limit: limit) { chimes.append(t) }
        }
        XCTAssertEqual(chimes, [300, 330, 350])
    }

    func testFirstObservedTriggerWinsUntilActivity() {
        var timeline = LockTimeline()
        func deadline(_ now: Double, _ idle: Double) -> Double? {
            timeline.limit(now: now, idle: idle, display: 120, saver: 90, delay: .seconds(300))
        }
        XCTAssertEqual(deadline(0, 0), 390)
        timeline.begin(.screenSaver, now: 70)
        timeline.begin(.displayOff, now: 120)
        timeline.end(.screenSaver)
        XCTAssertEqual(deadline(150, 150), 370)
        XCTAssertEqual(deadline(151, 0), 390)
        XCTAssertFalse(timeline.displayIsOff)
    }

    func testSysadminctlStatuses() {
        XCTAssertEqual(PasswordDelay(status: "sysadminctl[123] screenLock delay is 300 seconds\n"), .seconds(300))
        XCTAssertEqual(PasswordDelay(status: "screenLock delay is immediate"), .seconds(0))
        XCTAssertEqual(PasswordDelay(status: "screenLock is off"), .off)
        XCTAssertEqual(PasswordDelay(status: "status unavailable"), .unknown)
    }
}
