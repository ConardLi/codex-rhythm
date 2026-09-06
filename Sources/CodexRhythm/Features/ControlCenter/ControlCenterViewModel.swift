import Foundation
import SwiftUI

final class ControlCenterViewModel: ObservableObject {
    @Published var snapshot: UsageSnapshot?
    @Published var isAssistantEnabled = false
    @Published var selectedMode: TimerAssistantMode = .periodic
    @Published var assistantStatusTitle = "等待首次检查"
    @Published var assistantStatusDetail = "同步额度后会自动判断是否需要开始计时"
    @Published var isRefreshing = false
    @Published var isRunningRequest = false
    @Published var isRedeemingReset = false
    @Published var confirmedFiveHourResetAt: Date?
    @Published var activeStartDate = Date()
    @Published var activeEndDate = Date()
    @Published var fixedTimeOneDate = Date()
    @Published var fixedTimeTwoDate = Date()
    @Published var hasSecondFixedTime = false
    @Published var checkIntervalMinutes = 10
    @Published var notice: String?
    @Published var noticeIsError = false

    var onRefresh: () -> Void = {}
    var onClose: () -> Void = {}
    var onManualRun: () -> Void = {}
    var onRedeemReset: () -> Void = {}
    var onOpenCodex: () -> Void = {}
    var onQuit: () -> Void = {}
    var onSetEnabled: (Bool) -> Void = { _ in }
    var onSelectMode: (TimerAssistantMode) -> Void = { _ in }
    var onSettingsChanged: () -> Void = {}

    func loadSettings(_ settings: TimerAssistantSettings) {
        isAssistantEnabled = settings.isEnabled
        selectedMode = settings.mode
        activeStartDate = Self.date(for: settings.activeStart)
        activeEndDate = Self.date(for: settings.activeEnd)
        fixedTimeOneDate = Self.date(
            for: settings.scheduledTimes.first ?? ScheduledTime(hour: 8, minute: 30)!
        )
        if settings.scheduledTimes.count > 1 {
            hasSecondFixedTime = true
            fixedTimeTwoDate = Self.date(for: settings.scheduledTimes[1])
        } else {
            hasSecondFixedTime = false
            fixedTimeTwoDate = Self.date(for: ScheduledTime(hour: 13, minute: 30)!)
        }
        checkIntervalMinutes = settings.checkIntervalMinutes
    }

    func draftSettings(basedOn base: TimerAssistantSettings) -> TimerAssistantSettings? {
        guard let activeStart = Self.dailyTime(from: activeStartDate),
              let activeEnd = Self.dailyTime(from: activeEndDate),
              let firstTime = Self.dailyTime(from: fixedTimeOneDate) else {
            return nil
        }
        var times = [firstTime]
        if hasSecondFixedTime, let secondTime = Self.dailyTime(from: fixedTimeTwoDate) {
            times.append(secondTime)
        }
        var settings = base
        settings.mode = selectedMode
        settings.activeStart = activeStart
        settings.activeEnd = activeEnd
        settings.scheduledTimes = Array(Set(times)).sorted()
        settings.checkIntervalMinutes = checkIntervalMinutes
        return settings.normalized
    }

    func presentNotice(_ message: String, isError: Bool = false) {
        notice = message
        noticeIsError = isError
    }

    var fiveHourRemaining: Int? { snapshot?.fiveHourRemainingPercent }
    var weeklyRemaining: Int? { snapshot?.weeklyRemainingPercent }
    var bankedCount: Int { snapshot?.resetCredits?.availableCount ?? 0 }

    var resetText: String {
        guard let resetAt = currentFiveHourResetAt else {
            return "尚未开始计时"
        }
        return countdown(to: resetAt)
    }

    var predictedResetDates: [Date] {
        guard let currentFiveHourResetAt else { return [] }
        return predictedFiveHourResetDates(firstResetAt: currentFiveHourResetAt)
    }

    private var currentFiveHourResetAt: Date? {
        guard let snapshot else { return nil }
        return activeFiveHourResetAt(
            snapshot: snapshot,
            confirmedResetAt: confirmedFiveHourResetAt,
            now: Date()
        )
    }

    var weeklyResetText: String {
        guard let resetAt = snapshot?.weeklyResetAt else { return "重置时间未知" }
        return countdown(to: resetAt)
    }

    var syncText: String {
        guard let snapshot else { return "正在连接 Codex" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm:ss"
        return "\(formatter.string(from: snapshot.capturedAt)) 同步"
    }

    private func countdown(to date: Date) -> String {
        let minutes = max(0, Int(date.timeIntervalSinceNow / 60))
        let days = minutes / 1_440
        let hours = (minutes % 1_440) / 60
        let remainder = minutes % 60
        if days > 0 { return "\(days) 天 \(hours) 小时后重置" }
        if hours > 0 { return "\(hours) 小时 \(remainder) 分后重置" }
        if remainder > 0 { return "\(remainder) 分钟后重置" }
        return "即将重置"
    }

    private static func date(for time: ScheduledTime) -> Date {
        Calendar.current.date(
            bySettingHour: time.hour,
            minute: time.minute,
            second: 0,
            of: Date()
        ) ?? Date()
    }

    private static func dailyTime(from date: Date) -> ScheduledTime? {
        let components = Calendar.current.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else { return nil }
        return ScheduledTime(hour: hour, minute: minute)
    }
}
