import Foundation

enum TimerAssistantMode: String, CaseIterable, Equatable {
    case periodic
    case fixedTime

    var displayName: String {
        switch self {
        case .periodic:
            return "自动守候"
        case .fixedTime:
            return "固定时间"
        }
    }
}

struct ScheduledTime: Codable, Equatable, Hashable, Comparable, CustomStringConvertible {
    let hour: Int
    let minute: Int

    init?(hour: Int, minute: Int) {
        guard (0...23).contains(hour), (0...59).contains(minute) else { return nil }
        self.hour = hour
        self.minute = minute
    }

    init?(_ text: String) {
        let parts = text.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ":")
        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]) else { return nil }
        self.init(hour: hour, minute: minute)
    }

    var description: String { String(format: "%02d:%02d", hour, minute) }
    var minutesSinceMidnight: Int { hour * 60 + minute }

    static func < (lhs: ScheduledTime, rhs: ScheduledTime) -> Bool {
        (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
    }
}

func parseScheduledTimes(_ text: String) -> [ScheduledTime] {
    let separators = CharacterSet(charactersIn: ",，;； \n\t")
    let values = text.components(separatedBy: separators).compactMap(ScheduledTime.init)
    return Array(Set(values)).sorted()
}

struct TimerAssistantSettings: Equatable {
    var isEnabled = false
    var mode: TimerAssistantMode = .periodic
    var scheduledTimes: [ScheduledTime] = [ScheduledTime(hour: 8, minute: 30)!]
    var activeStart = ScheduledTime(hour: 8, minute: 0)!
    var activeEnd = ScheduledTime(hour: 23, minute: 0)!
    var checkIntervalMinutes = 10
    var graceMinutes = 30
    var minimumWeeklyRemainingPercent = 20
    var codexExecutablePath = ""
    var model = "gpt-5.6-terra"

    var normalized: TimerAssistantSettings {
        var copy = self
        copy.scheduledTimes = Array(Set(scheduledTimes)).sorted()
        if copy.scheduledTimes.isEmpty {
            copy.scheduledTimes = [ScheduledTime(hour: 8, minute: 30)!]
        }
        let allowedIntervals = [5, 10, 15, 30]
        copy.checkIntervalMinutes = allowedIntervals.min {
            abs($0 - checkIntervalMinutes) < abs($1 - checkIntervalMinutes)
        } ?? 10
        copy.graceMinutes = max(2, min(12 * 60, graceMinutes))
        copy.minimumWeeklyRemainingPercent = max(0, min(100, minimumWeeklyRemainingPercent))
        copy.codexExecutablePath = codexExecutablePath.trimmingCharacters(in: .whitespacesAndNewlines)
        copy.model = model.trimmingCharacters(in: .whitespacesAndNewlines)
        return copy
    }
}

struct TimerAssistantState: Equatable {
    var handledSlotKey: String?
    var attemptSlotKey: String?
    var attemptCount = 0
    var lastAttemptAt: Date?
    var lastSuccessfulStartAt: Date?
    var confirmedFiveHourResetAt: Date?
    var lastResult: String?
    var lastResultAt: Date?

    mutating func recordAttempt(slotKey: String, at date: Date) {
        if attemptSlotKey == slotKey {
            attemptCount += 1
        } else {
            attemptSlotKey = slotKey
            attemptCount = 1
        }
        lastAttemptAt = date
    }

    mutating func markHandled(
        slotKey: String,
        result: String,
        at date: Date,
        confirmedResetAt: Date? = nil
    ) {
        handledSlotKey = slotKey
        lastSuccessfulStartAt = date
        confirmedFiveHourResetAt = confirmedResetAt
        lastResult = result
        lastResultAt = date
    }
}

enum TimerAssistantDecision: Equatable {
    case disabled
    case unavailable(String)
    case activeWindow(Date)
    case weeklyProtection(remainingPercent: Int, minimumPercent: Int)
    case outsideSchedule
    case alreadyHandled(String)
    case recentlyStarted(Date)
    case cooldown
    case attemptLimit
    case ready(slotKey: String, scheduledAt: Date)
}
