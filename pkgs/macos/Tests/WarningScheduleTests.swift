import XCTest
@testable import YoheySchedule

extension WarningSchedule {
    mutating func shouldChime(idle: Double, limit: Double) -> Bool {
        chimeVolume(idle: idle, limit: limit, from: 1, to: 1) != nil
    }
}

final class WarningScheduleTests: XCTestCase {
    func testVolumeFollowsSpacingBetweenEndpoints() {
        func volumes(_ spacing: ReminderSpacing, _ start: Double, _ end: Double, count: Int = 3) -> [Double] {
            var schedule = WarningSchedule(count: count, spacing: spacing)
            return (0...1000).compactMap {
                schedule.chimeVolume(idle: Double($0) / 10, limit: 100, from: start, to: end)
            }
        }
        for spacing in ReminderSpacing.allCases {
            XCTAssertEqual(volumes(spacing, 1, 1), [1, 1, 1])
            XCTAssertEqual(volumes(spacing, 0, 1, count: 1), [1])
        }
        XCTAssertEqual(volumes(.steady, 1, 0), [1, 0.5, 0])
        XCTAssertEqual(volumes(.gentle, 0, 1), [0, 0.6, 1])
        let urgent = volumes(.urgent, 0, 1)
        XCTAssertGreaterThan(urgent[1], 0.6)
        XCTAssertEqual(urgent.last, 1)
    }
    func testDenseSchedulesDeliverAll25BeforeLock() {
        for spacing in ReminderSpacing.allCases {
            var schedule = WarningSchedule(start: 15, count: 25, spacing: spacing)
            var chimes: [Double] = []
            for tick in 0...3000 {
                let idle = Double(tick) / 100
                if schedule.shouldChime(idle: idle, limit: 30) { chimes.append(idle) }
            }
            XCTAssertEqual(chimes.count, 25)
            XCTAssertEqual(chimes.first, 15)
            let gaps = zip(chimes, chimes.dropFirst() + [30]).map { $1 - $0 }
            if spacing == .steady {
                for gap in gaps { XCTAssertEqual(gap, 0.6, accuracy: 0.011) }
            } else {
                XCTAssertGreaterThan(gaps.first!, gaps.last!)
                XCTAssertGreaterThanOrEqual(gaps.min()!, 0.34)
            }
        }
    }
    func testUrgentBuildsLaterThanGentle() {
        let gentle = WarningSchedule(spacing: .gentle)
        let urgent = WarningSchedule(spacing: .urgent)
        XCTAssertGreaterThan(urgent.nextBoundary(idle: 0, limit: 60)!,
                             gentle.nextBoundary(idle: 0, limit: 60)!)
    }
    func testHundredRemindersFitShortestWindow() {
        for spacing in ReminderSpacing.allCases {
            var schedule = WarningSchedule(start: 15, count: 100, spacing: spacing)
            let chimes = (0...3000).filter { schedule.shouldChime(idle: Double($0) / 100, limit: 30) }
            XCTAssertEqual(chimes.count, 100)
        }
    }
    func testConfigurableScheduleMatchesCountdown() {
        for (start, count, expected) in [(120, 1, [180]), (15, 5, [285, 290, 294, 297, 299])] {
            var schedule = WarningSchedule(start: start, count: count)
            XCTAssertEqual(schedule.nextBoundary(idle: 0, limit: 300), expected.first.map(Double.init))
            let actual = (0...300).filter { schedule.shouldChime(idle: Double($0), limit: 300) }
            XCTAssertEqual(actual, expected)
        }
    }
    func testIdleCycleAndInputReset() {
        var schedule = WarningSchedule()
        for _ in 0..<2 {
            let chimes = (0...310).filter { schedule.shouldChime(idle: Double($0), limit: 300) }
            XCTAssertEqual(chimes, [240, 270, 290])
        }
    }

    func testResumeDoesNotReplaySkippedWarnings() {
        var schedule = WarningSchedule()
        XCTAssertFalse(schedule.shouldChime(idle: 1, limit: 300))
        XCTAssertFalse(schedule.shouldChime(idle: 289, limit: 300))
        XCTAssertTrue(schedule.shouldChime(idle: 290, limit: 300))
        XCTAssertFalse(schedule.shouldChime(idle: 290.5, limit: 300))
    }
}
