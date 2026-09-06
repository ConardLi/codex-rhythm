import Foundation

func activeFiveHourResetAt(
    snapshot: UsageSnapshot,
    confirmedResetAt: Date?,
    now: Date
) -> Date? {
    guard let usedPercent = snapshot.fiveHourUsedPercent,
          let resetAt = snapshot.fiveHourResetAt,
          resetAt > now.addingTimeInterval(30) else {
        return nil
    }
    if usedPercent > 0 {
        return resetAt
    }

    // The usage endpoint can report 0% together with a moving `now + 5h`
    // placeholder. At 0%, only trust a reset timestamp that this app has
    // previously confirmed as a real, stable window.
    let resetTolerance: TimeInterval = 10 * 60
    guard let confirmedResetAt,
          confirmedResetAt > now.addingTimeInterval(30),
          abs(resetAt.timeIntervalSince(confirmedResetAt)) <= resetTolerance else {
        return nil
    }
    return resetAt
}

func predictedFiveHourResetDates(firstResetAt: Date, count: Int = 3) -> [Date] {
    guard count > 0 else { return [] }
    let fiveHours: TimeInterval = 5 * 60 * 60
    return (0..<count).map { index in
        firstResetAt.addingTimeInterval(TimeInterval(index) * fiveHours)
    }
}

struct TimerAssistantPolicy {
    var calendar: Calendar = .current
    var maximumSnapshotAge: TimeInterval = 3 * 60
    var attemptCooldown: TimeInterval = 5 * 60
    var successfulStartProtection: TimeInterval = 15 * 60
    var maximumAttemptsPerSlot = 3

    func evaluate(
        now: Date,
        snapshot: UsageSnapshot,
        settings: TimerAssistantSettings,
        state: TimerAssistantState
    ) -> TimerAssistantDecision {
        let settings = settings.normalized
        guard settings.isEnabled else { return .disabled }
        guard snapshot.errorMessage == nil,
              snapshot.warningMessage == nil,
              snapshot.source.isOfficial else {
            return .unavailable("当前不是实时官方额度数据")
        }
        let snapshotAge = now.timeIntervalSince(snapshot.capturedAt)
        guard snapshotAge >= -30, snapshotAge <= maximumSnapshotAge else {
            return .unavailable("额度数据已过期")
        }
        guard let weeklyRemaining = snapshot.weeklyRemainingPercent else {
            return .unavailable("无法确认一周剩余额度")
        }
        guard weeklyRemaining >= settings.minimumWeeklyRemainingPercent else {
            return .weeklyProtection(
                remainingPercent: weeklyRemaining,
                minimumPercent: settings.minimumWeeklyRemainingPercent
            )
        }
        guard let fiveHourUsed = snapshot.fiveHourUsedPercent else {
            return .unavailable("无法确认 5 小时计时状态")
        }
        if fiveHourUsed > 0, snapshot.fiveHourResetAt == nil {
            return .unavailable("5 小时计时缺少重置时间")
        }
        if let resetAt = activeFiveHourResetAt(
            snapshot: snapshot,
            confirmedResetAt: state.confirmedFiveHourResetAt,
            now: now
        ) {
            return .activeWindow(resetAt)
        }
        if let lastSuccessfulStartAt = state.lastSuccessfulStartAt,
           now.timeIntervalSince(lastSuccessfulStartAt) < successfulStartProtection {
            return .recentlyStarted(lastSuccessfulStartAt)
        }

        let slot: (key: String, date: Date)?
        switch settings.mode {
        case .periodic:
            slot = periodicEligibleSlot(now: now, settings: settings)
        case .fixedTime:
            slot = latestFixedTimeSlot(now: now, settings: settings)
        }
        guard let slot else { return .outsideSchedule }
        if state.handledSlotKey == slot.key { return .alreadyHandled(slot.key) }
        if state.attemptSlotKey == slot.key,
           state.attemptCount >= maximumAttemptsPerSlot {
            return .attemptLimit
        }
        if state.attemptSlotKey == slot.key,
           let lastAttemptAt = state.lastAttemptAt,
           now.timeIntervalSince(lastAttemptAt) < attemptCooldown {
            return .cooldown
        }
        return .ready(slotKey: slot.key, scheduledAt: slot.date)
    }

    func nextCheckDate(after now: Date, settings: TimerAssistantSettings) -> Date? {
        let settings = settings.normalized
        switch settings.mode {
        case .periodic:
            return nextPeriodicCheck(after: now, settings: settings)
        case .fixedTime:
            return nextFixedTimeCheck(after: now, settings: settings)
        }
    }

    private func periodicEligibleSlot(
        now: Date,
        settings: TimerAssistantSettings
    ) -> (key: String, date: Date)? {
        guard let period = activePeriod(containing: now, settings: settings) else { return nil }
        let elapsedMinutes = max(0, Int(now.timeIntervalSince(period.start) / 60))
        let slotIndex = elapsedMinutes / settings.checkIntervalMinutes
        guard let slotDate = calendar.date(
            byAdding: .minute,
            value: slotIndex * settings.checkIntervalMinutes,
            to: period.start
        ), slotDate < period.end else { return nil }
        return (slotKey(prefix: "periodic", date: slotDate), slotDate)
    }

    private func latestFixedTimeSlot(
        now: Date,
        settings: TimerAssistantSettings
    ) -> (key: String, date: Date)? {
        var candidates: [(key: String, date: Date)] = []
        for dayOffset in [0, -1] {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            for scheduledTime in settings.scheduledTimes {
                guard let scheduledAt = calendar.date(
                    bySettingHour: scheduledTime.hour,
                    minute: scheduledTime.minute,
                    second: 0,
                    of: day
                ) else { continue }
                let graceEnd = scheduledAt.addingTimeInterval(TimeInterval(settings.graceMinutes * 60))
                guard scheduledAt <= now, now <= graceEnd else { continue }
                candidates.append((slotKey(prefix: "fixed", date: scheduledAt), scheduledAt))
            }
        }
        return candidates.max { $0.date < $1.date }
    }

    private func nextPeriodicCheck(after now: Date, settings: TimerAssistantSettings) -> Date? {
        if let period = activePeriod(containing: now, settings: settings) {
            let elapsedMinutes = max(0, Int(now.timeIntervalSince(period.start) / 60))
            let nextIndex = (elapsedMinutes / settings.checkIntervalMinutes) + 1
            let next = calendar.date(
                byAdding: .minute,
                value: nextIndex * settings.checkIntervalMinutes,
                to: period.start
            )
            if let next, next < period.end { return next }
        }
        return nextActivePeriodStart(after: now, settings: settings)
    }

    private func nextFixedTimeCheck(after now: Date, settings: TimerAssistantSettings) -> Date? {
        var candidates: [Date] = []
        for dayOffset in 0...2 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            for scheduledTime in settings.scheduledTimes {
                guard let date = calendar.date(
                    bySettingHour: scheduledTime.hour,
                    minute: scheduledTime.minute,
                    second: 0,
                    of: day
                ), date > now else { continue }
                candidates.append(date)
            }
        }
        return candidates.min()
    }

    private func activePeriod(
        containing now: Date,
        settings: TimerAssistantSettings
    ) -> (start: Date, end: Date)? {
        let startMinutes = settings.activeStart.minutesSinceMidnight
        let endMinutes = settings.activeEnd.minutesSinceMidnight
        guard let startToday = calendar.date(
            bySettingHour: settings.activeStart.hour,
            minute: settings.activeStart.minute,
            second: 0,
            of: now
        ), let endToday = calendar.date(
            bySettingHour: settings.activeEnd.hour,
            minute: settings.activeEnd.minute,
            second: 0,
            of: now
        ) else { return nil }

        if startMinutes == endMinutes {
            guard let end = calendar.date(byAdding: .day, value: 1, to: startToday) else { return nil }
            return (startToday, end)
        }
        if startMinutes < endMinutes {
            return (startToday <= now && now < endToday) ? (startToday, endToday) : nil
        }
        if now >= startToday,
           let endTomorrow = calendar.date(byAdding: .day, value: 1, to: endToday) {
            return (startToday, endTomorrow)
        }
        guard now < endToday,
              let startYesterday = calendar.date(byAdding: .day, value: -1, to: startToday) else {
            return nil
        }
        return (startYesterday, endToday)
    }

    private func nextActivePeriodStart(after now: Date, settings: TimerAssistantSettings) -> Date? {
        guard let todayStart = calendar.date(
            bySettingHour: settings.activeStart.hour,
            minute: settings.activeStart.minute,
            second: 0,
            of: now
        ) else { return nil }
        if todayStart > now { return todayStart }
        return calendar.date(byAdding: .day, value: 1, to: todayStart)
    }

    private func slotKey(prefix: String, date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "yyyy-MM-dd@HH:mm"
        return "\(prefix):\(formatter.string(from: date))"
    }
}

func confirmsTimerStart(requestedAt: Date, observations: [UsageSnapshot]) -> Bool {
    let fiveHours: TimeInterval = 5 * 60 * 60
    let reportingTolerance: TimeInterval = 10 * 60
    let expectedResetAt = requestedAt.addingTimeInterval(fiveHours)
    let reliable = observations.filter { snapshot in
        guard snapshot.errorMessage == nil,
              snapshot.warningMessage == nil,
              snapshot.source.isOfficial,
              snapshot.capturedAt >= requestedAt.addingTimeInterval(-30),
              let resetAt = snapshot.fiveHourResetAt else {
            return false
        }
        return abs(resetAt.timeIntervalSince(expectedResetAt)) <= reportingTolerance
    }
    guard let latest = reliable.last else {
        return false
    }
    if let usedPercent = latest.fiveHourUsedPercent, usedPercent > 0 {
        return true
    }

    // Tiny requests can round down to 0%. In that case, distinguish a real
    // window from the moving placeholder by requiring three observations over
    // at least 12 seconds whose reset timestamps remain stable within 5 seconds.
    let stableSampleCount = 3
    guard reliable.count >= stableSampleCount else { return false }
    let samples = Array(reliable.suffix(stableSampleCount))
    guard samples.allSatisfy({ $0.fiveHourUsedPercent == 0 }),
          let firstDate = samples.first?.capturedAt,
          let lastDate = samples.last?.capturedAt,
          lastDate.timeIntervalSince(firstDate) >= 12 else {
        return false
    }
    let resetTimes = samples.compactMap { $0.fiveHourResetAt?.timeIntervalSince1970 }
    guard resetTimes.count == stableSampleCount,
          let earliest = resetTimes.min(),
          let latestReset = resetTimes.max() else {
        return false
    }
    return latestReset - earliest <= 5
}
