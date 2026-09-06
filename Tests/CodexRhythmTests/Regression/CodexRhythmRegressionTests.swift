import Foundation

@main
enum CodexRhythmRegressionTests {
    static func main() {
        precondition(QuotaWindowClassifier.classify(durationMinutes: 300) == .fiveHour)
        precondition(QuotaWindowClassifier.classify(durationMinutes: 10_080) == .weekly)
        precondition(QuotaWindowClassifier.classify(durationMinutes: 0) == nil)
        precondition(QuotaWindowClassifier.classify(durationMinutes: nil) == nil)

        let weeklyOnly = snapshot(fiveHourUsed: nil, weeklyUsed: 0)
        precondition(weeklyOnly.fiveHourRemainingPercent == nil)
        precondition(weeklyOnly.weeklyRemainingPercent == 100)

        let exhaustedFiveHour = snapshot(fiveHourUsed: 100, weeklyUsed: 25)
        precondition(exhaustedFiveHour.fiveHourRemainingPercent == 0)
        precondition(exhaustedFiveHour.weeklyRemainingPercent == 75)

        let malformedValues = snapshot(fiveHourUsed: -5, weeklyUsed: 105)
        precondition(malformedValues.fiveHourRemainingPercent == 100)
        precondition(malformedValues.weeklyRemainingPercent == 0)

        let bankedData = """
        {
          "available_count": 3,
          "credits": [
            {
              "id": "later",
              "title": "Full reset",
              "reset_type": "full",
              "status": "available",
              "expires_at": "2026-08-13T12:34:56Z"
            },
            {
              "id": "redeemed",
              "title": "Full reset",
              "status": "redeemed",
              "expires_at": "2026-07-20T00:00:00Z"
            },
            {
              "id": "earlier",
              "title": "Full reset",
              "status": "available",
              "expires_at": "2026-07-27T00:00:00.000Z"
            },
            {
              "id": "middle",
              "title": "Full reset",
              "status": "available",
              "expires_at": "2026-08-01T08:15:30Z"
            }
          ]
        }
        """.data(using: .utf8)!
        let banked = try! ResetCreditsPayloadDecoder().decode(bankedData)
        precondition(banked.availableCount == 3)
        precondition(banked.available.map(\.identifier) == ["earlier", "middle", "later"])

        let utc = TimeZone(secondsFromGMT: 0)!
        let earliestExpiry = banked.available[0].expiration!
        precondition(
            ResetCreditDateFormatter.displayString(for: earliestExpiry, timeZone: utc) ==
            "2026-07-27 周一 00:00:00"
        )

        testUsagePayloadDecoding()
        testTelemetryFallbackDecoding()
        testTimerAssistantPolicy()
        testTimerStartConfirmation()
        testResetPredictions()
        testResetResponseParsing()

        print("Codex Rhythm regression tests passed")
    }

    private static func testUsagePayloadDecoding() {
        let data = """
        {
          "plan_type": "plus",
          "rate_limit": {
            "primary_window": {
              "used_percent": 34,
              "limit_window_seconds": "604800",
              "reset_at": "1789288200"
            },
            "secondary_window": {
              "used_percent": "12.4",
              "limit_window_seconds": 18000,
              "reset_at": 1788687000
            }
          }
        }
        """.data(using: .utf8)!
        let capturedAt = date("2026-09-06T01:00:00Z")
        let result = try! UsagePayloadDecoder().decode(data, capturedAt: capturedAt)
        precondition(result.source == .officialAPI)
        precondition(result.capturedAt == capturedAt)
        precondition(result.planType == "plus")
        precondition(result.fiveHourUsedPercent == 12)
        precondition(result.fiveHourWindowMinutes == 300)
        precondition(result.weeklyUsedPercent == 34)
        precondition(result.weeklyWindowMinutes == 10_080)
    }

    private static func testTelemetryFallbackDecoding() {
        let row = "1788685200\t{\"x-codex-plan-type\":\"plus\",\"x-codex-primary-used-percent\":\"7\",\"x-codex-primary-window-minutes\":\"300\",\"x-codex-primary-reset-at\":\"1788703200\",\"x-codex-secondary-used-percent\":\"21\",\"x-codex-secondary-window-minutes\":\"10080\"}"
        let failure = NSError(domain: "tests", code: 1)
        let result = TelemetryLogDecoder().decode(row: row, apiFailure: failure)
        precondition(result?.source == .localTelemetry)
        precondition(result?.fiveHourUsedPercent == 7)
        precondition(result?.weeklyUsedPercent == 21)
        precondition(result?.warningMessage != nil)
    }

    private static func testResetPredictions() {
        let firstReset = date("2026-09-06T01:30:00Z")
        precondition(
            predictedFiveHourResetDates(firstResetAt: firstReset) == [
                date("2026-09-06T01:30:00Z"),
                date("2026-09-06T06:30:00Z"),
                date("2026-09-06T11:30:00Z")
            ]
        )
        precondition(predictedFiveHourResetDates(firstResetAt: firstReset, count: 0).isEmpty)
    }

    private static func testTimerStartConfirmation() {
        let requestedAt = date("2026-08-28T08:00:00Z")
        let confirmed = assistantSnapshot(
            now: requestedAt.addingTimeInterval(5),
            fiveHourUsed: 1,
            weeklyUsed: 50,
            resetAt: requestedAt.addingTimeInterval(5 * 60 * 60)
        )
        precondition(confirmsTimerStart(requestedAt: requestedAt, observations: [confirmed]))

        let withinTolerance = assistantSnapshot(
            now: requestedAt.addingTimeInterval(5),
            fiveHourUsed: 1,
            weeklyUsed: 50,
            resetAt: requestedAt.addingTimeInterval((4 * 60 + 50) * 60)
        )
        precondition(confirmsTimerStart(requestedAt: requestedAt, observations: [withinTolerance]))

        let outsideTolerance = assistantSnapshot(
            now: requestedAt.addingTimeInterval(5),
            fiveHourUsed: 1,
            weeklyUsed: 50,
            resetAt: requestedAt.addingTimeInterval((4 * 60 + 49) * 60)
        )
        precondition(!confirmsTimerStart(requestedAt: requestedAt, observations: [outsideTolerance]))

        let missingReset = assistantSnapshot(
            now: requestedAt.addingTimeInterval(5),
            fiveHourUsed: 0,
            weeklyUsed: 50
        )
        precondition(!confirmsTimerStart(requestedAt: requestedAt, observations: [missingReset]))

        let staleReset = assistantSnapshot(
            now: requestedAt.addingTimeInterval(5),
            fiveHourUsed: 1,
            weeklyUsed: 50,
            resetAt: requestedAt.addingTimeInterval(3 * 60 * 60)
        )
        precondition(!confirmsTimerStart(requestedAt: requestedAt, observations: [staleReset]))

        let stableResetAt = requestedAt.addingTimeInterval(5 * 60 * 60)
        let stableZeroUsage = [3, 10, 20].map { seconds in
            assistantSnapshot(
                now: requestedAt.addingTimeInterval(TimeInterval(seconds)),
                fiveHourUsed: 0,
                weeklyUsed: 50,
                resetAt: stableResetAt
            )
        }
        precondition(
            confirmsTimerStart(requestedAt: requestedAt, observations: stableZeroUsage),
            "a stable reset timestamp must confirm a tiny request that rounds to 0%"
        )

        let movingPlaceholder = [3, 10, 20].map { seconds in
            assistantSnapshot(
                now: requestedAt.addingTimeInterval(TimeInterval(seconds)),
                fiveHourUsed: 0,
                weeklyUsed: 50,
                resetAt: requestedAt.addingTimeInterval(5 * 60 * 60 + TimeInterval(seconds))
            )
        }
        precondition(
            !confirmsTimerStart(requestedAt: requestedAt, observations: movingPlaceholder),
            "a moving now + 5h placeholder must not confirm a real window"
        )
    }

    private static func testResetResponseParsing() {
        let reset = parseCodexResetResponse("""
        {"id":1,"result":{"userAgent":"test"}}
        {"id":2,"result":{"outcome":"reset"}}
        """)
        precondition(reset == CodexResetReceipt(outcome: .reset, errorMessage: nil))

        let noCredit = parseCodexResetResponse("""
        {"id":2,"result":{"outcome":"noCredit"}}
        """)
        precondition(noCredit == CodexResetReceipt(outcome: .noCredit, errorMessage: nil))

        let failure = parseCodexResetResponse("""
        {"id":2,"error":{"code":-32603,"message":"request failed"}}
        """)
        precondition(failure == CodexResetReceipt(outcome: nil, errorMessage: "request failed"))
    }

    private static func testTimerAssistantPolicy() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let evaluator = TimerAssistantPolicy(calendar: calendar)
        let now = date("2026-08-28T08:45:00Z")
        let settings = TimerAssistantSettings(
            isEnabled: true,
            mode: .fixedTime,
            scheduledTimes: [ScheduledTime("08:30")!],
            graceMinutes: 90,
            minimumWeeklyRemainingPercent: 20,
            codexExecutablePath: "",
            model: ""
        )
        let eligible = assistantSnapshot(
            now: now,
            fiveHourUsed: 0,
            weeklyUsed: 50,
            resetAt: now.addingTimeInterval(5 * 60 * 60)
        )

        let ready = evaluator.evaluate(
            now: now,
            snapshot: eligible,
            settings: settings,
            state: TimerAssistantState()
        )
        guard case let .ready(slotKey, scheduledAt) = ready else {
            preconditionFailure("expected ready decision")
        }
        precondition(slotKey == "fixed:2026-08-28@08:30")
        precondition(scheduledAt == date("2026-08-28T08:30:00Z"))

        var confirmedZeroUsageState = TimerAssistantState()
        confirmedZeroUsageState.confirmedFiveHourResetAt = eligible.fiveHourResetAt
        guard case .activeWindow = evaluator.evaluate(
            now: now,
            snapshot: eligible,
            settings: settings,
            state: confirmedZeroUsageState
        ) else {
            preconditionFailure("a persisted, confirmed 0% window must remain active")
        }

        let active = assistantSnapshot(
            now: now,
            fiveHourUsed: 1,
            weeklyUsed: 50,
            resetAt: now.addingTimeInterval(3600)
        )
        guard case .activeWindow = evaluator.evaluate(
            now: now,
            snapshot: active,
            settings: settings,
            state: TimerAssistantState()
        ) else {
            preconditionFailure("active window must not start the timer")
        }

        let protected = assistantSnapshot(now: now, fiveHourUsed: 0, weeklyUsed: 90)
        precondition(
            evaluator.evaluate(
                now: now,
                snapshot: protected,
                settings: settings,
                state: TimerAssistantState()
            ) == .weeklyProtection(remainingPercent: 10, minimumPercent: 20)
        )

        var handled = TimerAssistantState()
        handled.markHandled(slotKey: slotKey, result: "done", at: now.addingTimeInterval(-1800))
        precondition(
            evaluator.evaluate(now: now, snapshot: eligible, settings: settings, state: handled) ==
            .alreadyHandled(slotKey)
        )

        var coolingDown = TimerAssistantState()
        coolingDown.recordAttempt(slotKey: slotKey, at: now.addingTimeInterval(-60))
        precondition(
            evaluator.evaluate(now: now, snapshot: eligible, settings: settings, state: coolingDown) ==
            .cooldown
        )

        var atLimit = TimerAssistantState()
        atLimit.recordAttempt(slotKey: slotKey, at: now.addingTimeInterval(-1800))
        atLimit.recordAttempt(slotKey: slotKey, at: now.addingTimeInterval(-1200))
        atLimit.recordAttempt(slotKey: slotKey, at: now.addingTimeInterval(-600))
        precondition(
            evaluator.evaluate(now: now, snapshot: eligible, settings: settings, state: atLimit) ==
            .attemptLimit
        )

        let stale = assistantSnapshot(
            now: now.addingTimeInterval(-600),
            fiveHourUsed: 0,
            weeklyUsed: 50
        )
        guard case .unavailable = evaluator.evaluate(
            now: now,
            snapshot: stale,
            settings: settings,
            state: TimerAssistantState()
        ) else {
            preconditionFailure("stale usage data must not start the timer")
        }

        let midnightSettings = TimerAssistantSettings(
            isEnabled: true,
            mode: .fixedTime,
            scheduledTimes: [ScheduledTime("23:30")!],
            graceMinutes: 120,
            minimumWeeklyRemainingPercent: 20,
            codexExecutablePath: "",
            model: ""
        )
        let afterMidnight = date("2026-08-29T00:15:00Z")
        let afterMidnightSnapshot = assistantSnapshot(
            now: afterMidnight,
            fiveHourUsed: 0,
            weeklyUsed: 50
        )
        guard case let .ready(midnightSlot, _) = evaluator.evaluate(
            now: afterMidnight,
            snapshot: afterMidnightSnapshot,
            settings: midnightSettings,
            state: TimerAssistantState()
        ) else {
            preconditionFailure("previous-day grace window should remain eligible")
        }
        precondition(midnightSlot == "fixed:2026-08-28@23:30")

        let periodicSettings = TimerAssistantSettings(
            isEnabled: true,
            mode: .periodic,
            activeStart: ScheduledTime("08:00")!,
            activeEnd: ScheduledTime("23:00")!,
            checkIntervalMinutes: 10,
            minimumWeeklyRemainingPercent: 20,
            model: ""
        )
        guard case let .ready(periodicSlot, periodicAt) = evaluator.evaluate(
            now: now,
            snapshot: eligible,
            settings: periodicSettings,
            state: TimerAssistantState()
        ) else {
            preconditionFailure("periodic mode should use the current check slot")
        }
        precondition(periodicSlot == "periodic:2026-08-28@08:40")
        precondition(periodicAt == date("2026-08-28T08:40:00Z"))
        precondition(
            evaluator.nextCheckDate(after: now, settings: periodicSettings) ==
            date("2026-08-28T08:50:00Z")
        )

        let outsideTime = date("2026-08-28T23:15:00Z")
        let outsideSnapshot = assistantSnapshot(now: outsideTime, fiveHourUsed: 0, weeklyUsed: 50)
        precondition(
            evaluator.evaluate(
                now: outsideTime,
                snapshot: outsideSnapshot,
                settings: periodicSettings,
                state: TimerAssistantState()
            ) == .outsideSchedule
        )

        var recentlyStarted = TimerAssistantState()
        recentlyStarted.markHandled(
            slotKey: periodicSlot,
            result: "done",
            at: now.addingTimeInterval(-60)
        )
        precondition(
            evaluator.evaluate(
                now: now,
                snapshot: eligible,
                settings: periodicSettings,
                state: recentlyStarted
            ) == .recentlyStarted(now.addingTimeInterval(-60))
        )

        precondition(parseScheduledTimes("08:30，08:30; 13:05").map(\.description) == ["08:30", "13:05"])
    }

    private static func snapshot(fiveHourUsed: Int?, weeklyUsed: Int?) -> UsageSnapshot {
        UsageSnapshot(
            capturedAt: Date(),
            source: .officialAPI,
            planType: "test",
            windows: makeWindows(fiveHourUsed: fiveHourUsed, weeklyUsed: weeklyUsed)
        )
    }

    private static func assistantSnapshot(
        now: Date,
        fiveHourUsed: Int?,
        weeklyUsed: Int?,
        resetAt: Date? = nil
    ) -> UsageSnapshot {
        UsageSnapshot(
            capturedAt: now,
            source: .officialAPI,
            planType: "plus",
            windows: makeWindows(
                fiveHourUsed: fiveHourUsed,
                weeklyUsed: weeklyUsed,
                fiveHourResetAt: resetAt
            )
        )
    }

    private static func makeWindows(
        fiveHourUsed: Int?,
        weeklyUsed: Int?,
        fiveHourResetAt: Date? = nil
    ) -> [QuotaWindow] {
        var windows: [QuotaWindow] = []
        if let fiveHourUsed {
            windows.append(QuotaWindow(
                kind: .fiveHour,
                usedPercent: fiveHourUsed,
                durationMinutes: 300,
                resetsAt: fiveHourResetAt
            ))
        }
        if let weeklyUsed {
            windows.append(QuotaWindow(
                kind: .weekly,
                usedPercent: weeklyUsed,
                durationMinutes: 10_080,
                resetsAt: nil
            ))
        }
        return windows
    }

    private static func date(_ value: String) -> Date {
        ISO8601DateFormatter().date(from: value)!
    }
}
