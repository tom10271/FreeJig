import Foundation
import FreeJigCore

private var checkCount = 0

private func fail(_ message: String, file: StaticString = #filePath, line: UInt = #line) -> Never {
    FileHandle.standardError.write(Data("FAIL \(file):\(line) \(message)\n".utf8))
    exit(1)
}

private func expectTrue(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) {
    checkCount += 1
    if !value { fail("Expected true", file: file, line: line) }
}

private func expectFalse(_ value: Bool, file: StaticString = #filePath, line: UInt = #line) {
    expectTrue(!value, file: file, line: line)
}

private func expectEqual<T: Equatable>(_ actual: T, _ expected: T, file: StaticString = #filePath, line: UInt = #line) {
    checkCount += 1
    if actual != expected { fail("\(actual) != \(expected)", file: file, line: line) }
}

private func expectNil<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) {
    expectTrue(value == nil, file: file, line: line)
}

private func unwrap<T>(_ value: T?, file: StaticString = #filePath, line: UInt = #line) -> T {
    guard let value else { fail("Expected value", file: file, line: line) }
    return value
}

private func expectThrowsError<T>(_ body: @autoclosure () throws -> T, file: StaticString = #filePath, line: UInt = #line) {
    checkCount += 1
    do { _ = try body() } catch { return }
    fail("Expected error", file: file, line: line)
}

final class PolicyChecks {
    private var calendar: Calendar {
        var value = Calendar(identifier: .gregorian)
        value.timeZone = TimeZone(secondsFromGMT: 0)!
        return value
    }

    private func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }

    func testDefaultsRequireNoGeneratedClicksScrollOrKeys() {
        let settings = Settings()
        expectEqual(settings.mode, .natural)
        expectEqual(settings.range, .small)
        expectEqual(settings.startAfter, 60)
        expectEqual(settings.interval, 60)
        expectFalse(settings.schedule.enabled)
        expectEqual(settings.autoStop.mode, .never)
        expectEqual(settings.appRule.condition, .any)
        expectEqual(settings.click, .none)
        expectEqual(settings.scroll, .none)
        expectFalse(settings.pressShift)
    }

    func testDisabledScheduleAllowsAnyDateEvenWithoutSelectedDays() {
        let schedule = WeeklySchedule(enabled: false, weekdays: [])
        expectTrue(schedule.contains(date("2026-10-18T03:00:00Z"), calendar: calendar))
    }

    func testDaytimeScheduleHasInclusiveStartAndExclusiveEnd() {
        let schedule = WeeklySchedule(enabled: true, startMinute: 540, endMinute: 1080, weekdays: [2])
        expectFalse(schedule.contains(date("2026-10-19T08:59:59Z"), calendar: calendar))
        expectTrue(schedule.contains(date("2026-10-19T09:00:00Z"), calendar: calendar))
        expectTrue(schedule.contains(date("2026-10-19T17:59:59Z"), calendar: calendar))
        expectFalse(schedule.contains(date("2026-10-19T18:00:00Z"), calendar: calendar))
        expectFalse(schedule.contains(date("2026-10-20T10:00:00Z"), calendar: calendar))
    }

    func testOvernightWindowBelongsToStartingWeekdayIncludingWeekRollover() {
        let schedule = WeeklySchedule(enabled: true, startMinute: 22 * 60, endMinute: 2 * 60, weekdays: [7])
        expectFalse(schedule.contains(date("2026-10-24T01:00:00Z"), calendar: calendar))
        expectTrue(schedule.contains(date("2026-10-24T22:00:00Z"), calendar: calendar))
        expectTrue(schedule.contains(date("2026-10-25T01:59:59Z"), calendar: calendar))
        expectFalse(schedule.contains(date("2026-10-25T02:00:00Z"), calendar: calendar))
        expectFalse(schedule.contains(date("2026-10-25T22:00:00Z"), calendar: calendar))
    }

    func testEqualTimesMeanSelectedCalendarDay() {
        let schedule = WeeklySchedule(enabled: true, startMinute: 540, endMinute: 540, weekdays: [2])
        expectTrue(schedule.contains(date("2026-10-19T00:00:00Z"), calendar: calendar))
        expectTrue(schedule.contains(date("2026-10-19T23:59:59Z"), calendar: calendar))
        expectFalse(schedule.contains(date("2026-10-20T00:00:00Z"), calendar: calendar))
    }

    func testEnabledScheduleWithNoDaysMatchesNothing() {
        for (start, end) in [(540, 1080), (1320, 120), (540, 540)] {
            let schedule = WeeklySchedule(enabled: true, startMinute: start, endMinute: end, weekdays: [])
            expectFalse(schedule.contains(date("2026-10-19T10:00:00Z"), calendar: calendar))
            expectFalse(schedule.contains(date("2026-10-19T23:00:00Z"), calendar: calendar))
        }
    }

    func testScheduleUsesProvidedLocalCalendar() {
        var localCalendar = calendar
        localCalendar.timeZone = TimeZone(identifier: "Asia/Hong_Kong")!
        let schedule = WeeklySchedule(enabled: true, startMinute: 540, endMinute: 1080, weekdays: [2])
        expectTrue(schedule.contains(date("2026-10-19T01:00:00Z"), calendar: localCalendar))
        expectFalse(schedule.contains(date("2026-10-19T01:00:00Z"), calendar: calendar))
    }

    func testAppConditionsMatchAnySelectedApp() {
        let ids = ["com.example.one", "com.example.two"]
        expectTrue(AppRule().allows(running: [], frontmost: nil))
        expectTrue(AppRule(condition: .running, bundleIDs: ids)
            .allows(running: ["com.example.two"], frontmost: nil))
        expectFalse(AppRule(condition: .running, bundleIDs: ids)
            .allows(running: ["com.example.other"], frontmost: "com.example.one"))
        expectTrue(AppRule(condition: .frontmost, bundleIDs: ids)
            .allows(running: [], frontmost: "com.example.two"))
        expectFalse(AppRule(condition: .frontmost, bundleIDs: ids)
            .allows(running: Set(ids), frontmost: nil))
        expectFalse(AppRule(condition: .notFrontmost, bundleIDs: ids)
            .allows(running: Set(ids), frontmost: "com.example.one"))
        expectTrue(AppRule(condition: .notFrontmost, bundleIDs: ids)
            .allows(running: [], frontmost: "com.example.other"))
        expectTrue(AppRule(condition: .notFrontmost, bundleIDs: ids)
            .allows(running: [], frontmost: nil))
    }

    func testEmptyConstrainedAppListsMatchNothing() {
        for condition in [AppCondition.running, .frontmost, .notFrontmost] {
            expectFalse(AppRule(condition: condition)
                .allows(running: ["com.example.one"], frontmost: "com.example.one"))
            expectFalse(AppRule(condition: condition).allows(running: [], frontmost: nil))
        }
    }

    func testNeverAndDurationStopDeadlines() {
        let start = date("2026-03-08T01:30:00-08:00")
        expectNil(AutoStop().deadline(startedAt: start, calendar: calendar))
        expectEqual(AutoStop(mode: .after, afterMinutes: 60).deadline(startedAt: start, calendar: calendar),
                       date("2026-03-08T03:30:00-07:00"))
    }

    func testWallClockStopChoosesNextOccurrence() {
        let stop = AutoStop(mode: .at, atMinute: 18 * 60)
        expectEqual(stop.deadline(startedAt: date("2026-10-19T17:00:00Z"), calendar: calendar),
                       date("2026-10-19T18:00:00Z"))
        expectEqual(stop.deadline(startedAt: date("2026-10-19T18:00:00Z"), calendar: calendar),
                       date("2026-10-20T18:00:00Z"))
        expectEqual(stop.deadline(startedAt: date("2026-10-19T18:00:01Z"), calendar: calendar),
                       date("2026-10-20T18:00:00Z"))
    }

    func testWallClockStopUsesCalendarAcrossDST() {
        var localCalendar = calendar
        localCalendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        expectEqual(AutoStop(mode: .at, atMinute: 2 * 60 + 30)
            .deadline(startedAt: date("2026-03-08T01:00:00-08:00"), calendar: localCalendar),
                       date("2026-03-08T03:00:00-07:00"))
        expectEqual(AutoStop(mode: .at, atMinute: 1 * 60 + 30)
            .deadline(startedAt: date("2026-11-01T00:00:00-07:00"), calendar: localCalendar),
                       date("2026-11-01T01:30:00-07:00"))
        expectEqual(AutoStop(mode: .at, atMinute: 1 * 60 + 30)
            .deadline(startedAt: date("2026-11-01T01:45:00-07:00"), calendar: localCalendar),
                       date("2026-11-01T01:30:00-08:00"))
        expectEqual(AutoStop(mode: .at, atMinute: 9 * 60)
            .deadline(startedAt: date("2026-03-07T10:00:00-08:00"), calendar: localCalendar),
                       date("2026-03-08T09:00:00-07:00"))
    }

    func testValidationClampsPersistedNumbersAndFiltersWeekdays() {
        let settings = Settings(
            startAfter: -10,
            interval: 99999,
            schedule: WeeklySchedule(startMinute: Int.min, endMinute: Int.max, weekdays: [0, 1, 2, 7, 8]),
            autoStop: AutoStop(afterMinutes: -1, atMinute: Int.max)
        ).validated()
        expectEqual(settings.startAfter, 1)
        expectEqual(settings.interval, 3600)
        expectEqual(settings.schedule.startMinute, 0)
        expectEqual(settings.schedule.endMinute, 1439)
        expectEqual(settings.schedule.weekdays, [1, 2, 7])
        expectEqual(settings.autoStop.afterMinutes, 1)
        expectEqual(settings.autoStop.atMinute, 1439)
        let otherBounds = Settings(startAfter: 99999, interval: -1,
                                   autoStop: AutoStop(afterMinutes: 99999, atMinute: -1)).validated()
        expectEqual(otherBounds.startAfter, 3600)
        expectEqual(otherBounds.interval, 1)
        expectEqual(otherBounds.autoStop.afterMinutes, 1440)
        expectEqual(otherBounds.autoStop.atMinute, 0)
    }

    func testValidationReplacesNonfiniteValuesAndPreservesValidSettings() {
        for value in [Double.nan, .infinity, -.infinity] {
            let settings = Settings(startAfter: value, interval: value,
                                    autoStop: AutoStop(afterMinutes: value)).validated()
            expectEqual(settings.startAfter, 60)
            expectEqual(settings.interval, 60)
            expectEqual(settings.autoStop.afterMinutes, 60)
        }
        let valid = Settings(mode: .silent, range: .full, startAfter: 1.5, interval: 3600,
                             schedule: WeeklySchedule(enabled: true, weekdays: [1, 7]),
                             autoStop: AutoStop(mode: .after, afterMinutes: 1440, atMinute: 0),
                             appRule: AppRule(condition: .notFrontmost, bundleIDs: ["com.example.one"]),
                             click: .double, scroll: .alternating, pressShift: true)
        expectEqual(valid.validated(), valid)
        expectEqual(valid.validated().validated(), valid)
    }

    func testSettingsRoundTripAndInvalidEnumRejection() throws {
        let original = Settings(mode: .subtle, range: .medium, startAfter: 120, interval: 30,
                                schedule: WeeklySchedule(enabled: true, weekdays: [2, 4, 6]),
                                autoStop: AutoStop(mode: .at, atMinute: 1234),
                                appRule: AppRule(condition: .running, bundleIDs: ["com.example.one"]),
                                click: .right, scroll: .down, pressShift: true)
        let encoded = try JSONEncoder().encode(original)
        expectEqual(try JSONDecoder().decode(Settings.self, from: encoded), original)
        var json = unwrap(try JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        json["mode"] = "unknown-mode"
        let invalid = try JSONSerialization.data(withJSONObject: json)
        expectThrowsError(try JSONDecoder().decode(Settings.self, from: invalid))
        expectThrowsError(try JSONDecoder().decode(Settings.self, from: Data("broken".utf8)))
    }
}

let checks = PolicyChecks()
do {
    checks.testDefaultsRequireNoGeneratedClicksScrollOrKeys()
    checks.testDisabledScheduleAllowsAnyDateEvenWithoutSelectedDays()
    checks.testDaytimeScheduleHasInclusiveStartAndExclusiveEnd()
    checks.testOvernightWindowBelongsToStartingWeekdayIncludingWeekRollover()
    checks.testEqualTimesMeanSelectedCalendarDay()
    checks.testEnabledScheduleWithNoDaysMatchesNothing()
    checks.testScheduleUsesProvidedLocalCalendar()
    checks.testAppConditionsMatchAnySelectedApp()
    checks.testEmptyConstrainedAppListsMatchNothing()
    checks.testNeverAndDurationStopDeadlines()
    checks.testWallClockStopChoosesNextOccurrence()
    checks.testWallClockStopUsesCalendarAcrossDST()
    checks.testValidationClampsPersistedNumbersAndFiltersWeekdays()
    checks.testValidationReplacesNonfiniteValuesAndPreservesValidSettings()
    try checks.testSettingsRoundTripAndInvalidEnumRejection()
    print("15 policy groups passed (\(checkCount) checks).")
} catch {
    fail("Unexpected error \(error)")
}
