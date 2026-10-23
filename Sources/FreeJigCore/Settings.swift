import Foundation

public enum MovementMode: String, Codable, CaseIterable, Identifiable {
    case natural, subtle, silent

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public enum MovementRange: String, Codable, CaseIterable, Identifiable {
    case small, medium, full

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public enum StopMode: String, Codable, CaseIterable, Identifiable {
    case never, after, at

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public enum AppCondition: String, Codable, CaseIterable, Identifiable {
    case any, running, frontmost, notFrontmost

    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .any: return "Any app"
        case .running: return "Is running"
        case .frontmost: return "Is in front"
        case .notFrontmost: return "Isn't in front"
        }
    }
}

public enum ClickMode: String, Codable, CaseIterable, Identifiable {
    case none, left, right, double

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public enum ScrollMode: String, Codable, CaseIterable, Identifiable {
    case none, up, down, alternating

    public var id: String { rawValue }
    public var title: String { rawValue.capitalized }
}

public struct WeeklySchedule: Codable, Equatable {
    public var enabled: Bool
    public var startMinute: Int
    public var endMinute: Int
    public var weekdays: Set<Int>

    public init(
        enabled: Bool = false,
        startMinute: Int = 9 * 60,
        endMinute: Int = 18 * 60,
        weekdays: Set<Int> = [2, 3, 4, 5, 6]
    ) {
        self.enabled = enabled
        self.startMinute = startMinute
        self.endMinute = endMinute
        self.weekdays = weekdays
    }

    public func contains(_ date: Date, calendar: Calendar) -> Bool {
        guard enabled else { return true }
        let weekday = calendar.component(.weekday, from: date)
        let minute = calendar.component(.hour, from: date) * 60
            + calendar.component(.minute, from: date)
        if startMinute == endMinute {
            return weekdays.contains(weekday)
        }
        if startMinute < endMinute {
            return weekdays.contains(weekday) && minute >= startMinute && minute < endMinute
        }
        if minute >= startMinute {
            return weekdays.contains(weekday)
        }
        guard minute < endMinute,
              let previousDay = calendar.date(byAdding: .day, value: -1, to: date) else {
            return false
        }
        return weekdays.contains(calendar.component(.weekday, from: previousDay))
    }
}

public struct AutoStop: Codable, Equatable {
    public var mode: StopMode
    public var afterMinutes: Double
    public var atMinute: Int

    public init(mode: StopMode = .never, afterMinutes: Double = 60, atMinute: Int = 18 * 60) {
        self.mode = mode
        self.afterMinutes = afterMinutes
        self.atMinute = atMinute
    }

    public func deadline(startedAt: Date, calendar: Calendar) -> Date? {
        switch mode {
        case .never:
            return nil
        case .after:
            return startedAt.addingTimeInterval(afterMinutes * 60)
        case .at:
            return calendar.nextDate(
                after: startedAt,
                matching: DateComponents(hour: atMinute / 60, minute: atMinute % 60, second: 0),
                matchingPolicy: .nextTime,
                repeatedTimePolicy: .first,
                direction: .forward
            )
        }
    }
}

public struct AppRule: Codable, Equatable {
    public var condition: AppCondition
    public var bundleIDs: [String]

    public init(condition: AppCondition = .any, bundleIDs: [String] = []) {
        self.condition = condition
        self.bundleIDs = bundleIDs
    }

    public func allows(running: Set<String>, frontmost: String?) -> Bool {
        guard condition == .any || !bundleIDs.isEmpty else { return false }
        switch condition {
        case .any:
            return true
        case .running:
            return bundleIDs.contains(where: running.contains)
        case .frontmost:
            return frontmost.map(bundleIDs.contains) ?? false
        case .notFrontmost:
            return frontmost.map { !bundleIDs.contains($0) } ?? true
        }
    }
}

public struct Settings: Codable, Equatable {
    public var mode: MovementMode
    public var range: MovementRange
    public var startAfter: Double
    public var interval: Double
    public var schedule: WeeklySchedule
    public var autoStop: AutoStop
    public var appRule: AppRule
    public var click: ClickMode
    public var scroll: ScrollMode
    public var pressShift: Bool

    public init(
        mode: MovementMode = .natural,
        range: MovementRange = .small,
        startAfter: Double = 60,
        interval: Double = 60,
        schedule: WeeklySchedule = WeeklySchedule(),
        autoStop: AutoStop = AutoStop(),
        appRule: AppRule = AppRule(),
        click: ClickMode = .none,
        scroll: ScrollMode = .none,
        pressShift: Bool = false
    ) {
        self.mode = mode
        self.range = range
        self.startAfter = startAfter
        self.interval = interval
        self.schedule = schedule
        self.autoStop = autoStop
        self.appRule = appRule
        self.click = click
        self.scroll = scroll
        self.pressShift = pressShift
    }

    public func validated() -> Settings {
        var result = self
        result.startAfter = bounded(startAfter, to: 1...3600, fallback: 60)
        result.interval = bounded(interval, to: 1...3600, fallback: 60)
        result.autoStop.afterMinutes = bounded(autoStop.afterMinutes, to: 1...1440, fallback: 60)
        result.autoStop.atMinute = min(1439, max(0, autoStop.atMinute))
        result.schedule.startMinute = min(1439, max(0, schedule.startMinute))
        result.schedule.endMinute = min(1439, max(0, schedule.endMinute))
        result.schedule.weekdays = schedule.weekdays.filter { (1...7).contains($0) }
        return result
    }
}

private func bounded(_ value: Double, to range: ClosedRange<Double>, fallback: Double) -> Double {
    value.isFinite ? min(range.upperBound, max(range.lowerBound, value)) : fallback
}
