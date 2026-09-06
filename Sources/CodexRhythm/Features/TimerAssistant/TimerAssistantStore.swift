import Foundation

final class TimerAssistantStore {
    private static let legacyBundleIdentifier = "io.github.zhanglaojiu.codexquotamenu"

    // These keys are a persisted compatibility contract. Their historical
    // prefix intentionally remains unchanged so upgrades keep user settings.
    private enum Key {
        static let enabled = "WindowStarter.enabled"
        static let mode = "WindowStarter.mode"
        static let scheduledTimes = "WindowStarter.triggerTimes"
        static let activeStart = "WindowStarter.activeStart"
        static let activeEnd = "WindowStarter.activeEnd"
        static let checkInterval = "WindowStarter.checkInterval"
        static let graceMinutes = "WindowStarter.graceMinutes"
        static let weeklyMinimum = "WindowStarter.weeklyMinimum"
        static let executablePath = "WindowStarter.executablePath"
        static let model = "WindowStarter.model"
        static let handledSlotKey = "WindowStarter.handledSlotKey"
        static let attemptSlotKey = "WindowStarter.attemptSlotKey"
        static let attemptCount = "WindowStarter.attemptCount"
        static let lastAttemptAt = "WindowStarter.lastAttemptAt"
        static let lastSuccessfulStartAt = "WindowStarter.lastSuccessfulTriggerAt"
        static let confirmedFiveHourResetAt = "WindowStarter.confirmedFiveHourResetAt"
        static let lastResult = "WindowStarter.lastResult"
        static let lastResultAt = "WindowStarter.lastResultAt"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        migrateLegacyPreferencesIfNeeded()
    }

    private func migrateLegacyPreferencesIfNeeded() {
        guard defaults.object(forKey: Key.enabled) == nil,
              let legacyValues = defaults.persistentDomain(
                  forName: Self.legacyBundleIdentifier
              ) else {
            return
        }
        for (key, value) in legacyValues where key.hasPrefix("WindowStarter.") {
            defaults.set(value, forKey: key)
        }
    }

    func loadSettings() -> TimerAssistantSettings {
        var settings = TimerAssistantSettings()
        let rawMode = defaults.string(forKey: Key.mode)
        if let rawMode, let mode = TimerAssistantMode(rawValue: rawMode) {
            settings.mode = mode
        } else if rawMode == "automatic" {
            settings.mode = .fixedTime
        }
        if defaults.object(forKey: Key.enabled) != nil {
            settings.isEnabled = defaults.bool(forKey: Key.enabled)
        } else {
            settings.isEnabled = rawMode == "automatic"
        }
        if let rawTimes = defaults.stringArray(forKey: Key.scheduledTimes) {
            let times = rawTimes.compactMap(ScheduledTime.init)
            if !times.isEmpty { settings.scheduledTimes = times }
        }
        if let rawStart = defaults.string(forKey: Key.activeStart),
           let start = ScheduledTime(rawStart) {
            settings.activeStart = start
        }
        if let rawEnd = defaults.string(forKey: Key.activeEnd),
           let end = ScheduledTime(rawEnd) {
            settings.activeEnd = end
        }
        if defaults.object(forKey: Key.checkInterval) != nil {
            settings.checkIntervalMinutes = defaults.integer(forKey: Key.checkInterval)
        }
        if defaults.object(forKey: Key.graceMinutes) != nil {
            settings.graceMinutes = defaults.integer(forKey: Key.graceMinutes)
        }
        if defaults.object(forKey: Key.weeklyMinimum) != nil {
            settings.minimumWeeklyRemainingPercent = defaults.integer(forKey: Key.weeklyMinimum)
        }
        settings.codexExecutablePath = defaults.string(forKey: Key.executablePath) ?? ""
        if let savedModel = defaults.string(forKey: Key.model),
           !savedModel.isEmpty,
           savedModel != "gpt-5.6-luna" {
            settings.model = savedModel
        }
        return settings.normalized
    }

    func save(settings: TimerAssistantSettings) {
        let settings = settings.normalized
        defaults.set(settings.isEnabled, forKey: Key.enabled)
        defaults.set(settings.mode.rawValue, forKey: Key.mode)
        defaults.set(settings.scheduledTimes.map(\.description), forKey: Key.scheduledTimes)
        defaults.set(settings.activeStart.description, forKey: Key.activeStart)
        defaults.set(settings.activeEnd.description, forKey: Key.activeEnd)
        defaults.set(settings.checkIntervalMinutes, forKey: Key.checkInterval)
        defaults.set(settings.graceMinutes, forKey: Key.graceMinutes)
        defaults.set(settings.minimumWeeklyRemainingPercent, forKey: Key.weeklyMinimum)
        defaults.set(settings.codexExecutablePath, forKey: Key.executablePath)
        defaults.set(settings.model, forKey: Key.model)
    }

    func loadState() -> TimerAssistantState {
        TimerAssistantState(
            handledSlotKey: defaults.string(forKey: Key.handledSlotKey),
            attemptSlotKey: defaults.string(forKey: Key.attemptSlotKey),
            attemptCount: defaults.integer(forKey: Key.attemptCount),
            lastAttemptAt: date(forKey: Key.lastAttemptAt),
            lastSuccessfulStartAt: date(forKey: Key.lastSuccessfulStartAt),
            confirmedFiveHourResetAt: date(forKey: Key.confirmedFiveHourResetAt),
            lastResult: defaults.string(forKey: Key.lastResult),
            lastResultAt: date(forKey: Key.lastResultAt)
        )
    }

    func save(state: TimerAssistantState) {
        defaults.set(state.handledSlotKey, forKey: Key.handledSlotKey)
        defaults.set(state.attemptSlotKey, forKey: Key.attemptSlotKey)
        defaults.set(state.attemptCount, forKey: Key.attemptCount)
        defaults.set(state.lastAttemptAt?.timeIntervalSince1970, forKey: Key.lastAttemptAt)
        defaults.set(state.lastSuccessfulStartAt?.timeIntervalSince1970, forKey: Key.lastSuccessfulStartAt)
        defaults.set(state.confirmedFiveHourResetAt?.timeIntervalSince1970, forKey: Key.confirmedFiveHourResetAt)
        defaults.set(state.lastResult, forKey: Key.lastResult)
        defaults.set(state.lastResultAt?.timeIntervalSince1970, forKey: Key.lastResultAt)
    }

    private func date(forKey key: String) -> Date? {
        guard defaults.object(forKey: key) != nil else { return nil }
        return Date(timeIntervalSince1970: defaults.double(forKey: key))
    }
}
