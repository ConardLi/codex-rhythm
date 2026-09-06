import AppKit
import SwiftUI
import UserNotifications

final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    private let usageService = CodexUsageService()
    private let timerAssistantStore = TimerAssistantStore()
    private let timerAssistantPolicy = TimerAssistantPolicy()
    private let timerStartService = TimerStartService()
    private let quotaResetService = QuotaResetService()
    private let controlCenterViewModel = ControlCenterViewModel()
    private let popover = NSPopover()

    private var statusItem: NSStatusItem?
    private var controlWindow: NSWindow?
    private var snapshot: UsageSnapshot?
    private var refreshTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var isRefreshing = false
    private var isTimerStartRunning = false
    private var isVerifyingTimerStart = false
    private var timerAssistantSettings = TimerAssistantSettings()
    private var timerAssistantState = TimerAssistantState()
    private var timerAssistantDecision: TimerAssistantDecision = .disabled

    // MARK: - Application lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        timerAssistantSettings = timerAssistantStore.loadSettings()
        timerAssistantState = timerAssistantStore.loadState()

        configureControlCenter()
        configureStatusItem()
        refresh()

        refreshTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            self?.refresh()
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.refresh()
        }
        if !ProcessInfo.processInfo.arguments.contains("--background") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                self?.showControlWindow()
            }
        }
        AppLogger.log("control center launched")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showControlWindow()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        refreshTimer?.invalidate()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }

    // MARK: - Menu bar and control center

    private func configureStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem?.button else { return }
        button.image = NSImage(
            systemSymbolName: "clock.arrow.circlepath",
            accessibilityDescription: "Codex Rhythm"
        )
        button.imagePosition = .imageLeading
        button.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
        button.title = " …"
        button.toolTip = "Codex Rhythm"
        button.target = self
        button.action = #selector(toggleControlCenter)
    }

    private func configureControlCenter() {
        controlCenterViewModel.loadSettings(timerAssistantSettings)
        controlCenterViewModel.onRefresh = { [weak self] in self?.refresh() }
        controlCenterViewModel.onClose = { [weak self] in self?.closeControlCenter() }
        controlCenterViewModel.onManualRun = { [weak self] in self?.startTimerManually() }
        controlCenterViewModel.onRedeemReset = { [weak self] in self?.redeemUsageReset() }
        controlCenterViewModel.onOpenCodex = { [weak self] in self?.openCodex() }
        controlCenterViewModel.onQuit = { NSApplication.shared.terminate(nil) }
        controlCenterViewModel.onSetEnabled = { [weak self] enabled in self?.setAssistantEnabled(enabled) }
        controlCenterViewModel.onSelectMode = { [weak self] mode in self?.selectMode(mode) }
        controlCenterViewModel.onSettingsChanged = { [weak self] in self?.saveSettingsDraft() }

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 420, height: 700)
        let hostingController = NSHostingController(rootView: ControlCenterView(model: controlCenterViewModel))
        hostingController.view.appearance = NSAppearance(named: .aqua)
        hostingController.view.wantsLayer = true
        hostingController.view.layer?.backgroundColor = NSColor.clear.cgColor
        popover.contentViewController = hostingController
    }

    @objc private func toggleControlCenter() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }

    private func showControlWindow() {
        popover.performClose(nil)
        if controlWindow == nil {
            let hostingController = NSHostingController(rootView: ControlCenterView(model: controlCenterViewModel))
            let window = GlassControlWindow(
                contentRect: NSRect(origin: .zero, size: NSSize(width: 420, height: 700)),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.contentViewController = hostingController
            window.isMovableByWindowBackground = true
            window.isReleasedWhenClosed = false
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = true
            window.appearance = NSAppearance(named: .aqua)
            window.setContentSize(NSSize(width: 420, height: 700))
            window.minSize = NSSize(width: 420, height: 580)
            window.center()
            controlWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        controlWindow?.makeKeyAndOrderFront(nil)
    }

    private func closeControlCenter() {
        if popover.isShown { popover.performClose(nil) }
        controlWindow?.orderOut(nil)
    }

    // MARK: - Usage refresh

    private func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        controlCenterViewModel.isRefreshing = true
        usageService.fetchUsage { [weak self] snapshot in
            DispatchQueue.main.async {
                guard let self else { return }
                self.isRefreshing = false
                self.controlCenterViewModel.isRefreshing = false
                self.snapshot = snapshot
                self.controlCenterViewModel.snapshot = snapshot
                self.rememberActiveWindow(from: snapshot)
                self.updateStatusItem()
                self.evaluateTimerAssistant(snapshot: snapshot)
                self.syncRuntimeState()
                AppLogger.log(
                    "control center refreshed source=\(snapshot.sourceName) " +
                    "fiveHour=\(snapshot.fiveHourUsedPercent.map(String.init) ?? "--") " +
                    "weekly=\(snapshot.weeklyUsedPercent.map(String.init) ?? "--") " +
                    "fiveHourResetAt=\(snapshot.fiveHourResetAt.map(String.init(describing:)) ?? "--")"
                )
            }
        }
    }

    private func updateStatusItem() {
        guard let snapshot, snapshot.errorMessage == nil else {
            statusItem?.button?.title = " —"
            return
        }
        statusItem?.button?.title = " \(snapshot.fiveHourRemainingPercent.map(String.init) ?? "—")%"
    }

    // MARK: - Timer assistant policy

    private func evaluateTimerAssistant(snapshot: UsageSnapshot) {
        timerAssistantDecision = timerAssistantPolicy.evaluate(
            now: Date(),
            snapshot: snapshot,
            settings: timerAssistantSettings,
            state: timerAssistantState
        )
        guard case let .ready(slotKey, _) = timerAssistantDecision else { return }
        startTimerAutomatically(slotKey: slotKey)
    }

    private func setAssistantEnabled(_ enabled: Bool) {
        if enabled, !timerAssistantSettings.isEnabled {
            let alert = NSAlert()
            alert.alertStyle = .informational
            alert.messageText = "开启计时助手？"
            alert.informativeText = "当检测到 5 小时计时尚未开始时，程序会发送一次真实的 Codex 最小请求，并消耗少量额度。"
            alert.addButton(withTitle: "开启")
            alert.addButton(withTitle: "取消")
            NSApp.activate(ignoringOtherApps: true)
            guard alert.runModal() == .alertFirstButtonReturn else {
                controlCenterViewModel.isAssistantEnabled = timerAssistantSettings.isEnabled
                return
            }
        }

        timerAssistantSettings.isEnabled = enabled
        timerAssistantStore.save(settings: timerAssistantSettings)
        controlCenterViewModel.loadSettings(timerAssistantSettings)
        if enabled { requestNotificationPermission() }
        reevaluatePolicy()
        syncRuntimeState()
        controlCenterViewModel.presentNotice(enabled ? "计时助手已开启" : "计时助手已关闭")
        if enabled { refresh() }
    }

    private func selectMode(_ mode: TimerAssistantMode) {
        guard timerAssistantSettings.mode != mode else { return }
        timerAssistantSettings.mode = mode
        timerAssistantSettings = timerAssistantSettings.normalized
        timerAssistantStore.save(settings: timerAssistantSettings)
        controlCenterViewModel.loadSettings(timerAssistantSettings)
        reevaluatePolicy()
        syncRuntimeState()
        controlCenterViewModel.presentNotice("已切换为\(mode.displayName)")
    }

    private func saveSettingsDraft() {
        guard var settings = controlCenterViewModel.draftSettings(basedOn: timerAssistantSettings) else {
            controlCenterViewModel.presentNotice("时间设置无效", isError: true)
            return
        }
        settings.isEnabled = timerAssistantSettings.isEnabled
        timerAssistantSettings = settings.normalized
        timerAssistantStore.save(settings: timerAssistantSettings)
        reevaluatePolicy()
        syncRuntimeState()
    }

    private func reevaluatePolicy() {
        guard let snapshot else {
            timerAssistantDecision = timerAssistantSettings.isEnabled ? .unavailable("等待额度同步") : .disabled
            return
        }
        timerAssistantDecision = timerAssistantPolicy.evaluate(
            now: Date(),
            snapshot: snapshot,
            settings: timerAssistantSettings,
            state: timerAssistantState
        )
    }

    private func syncRuntimeState() {
        controlCenterViewModel.isAssistantEnabled = timerAssistantSettings.isEnabled
        controlCenterViewModel.selectedMode = timerAssistantSettings.mode
        controlCenterViewModel.isRunningRequest = isTimerStartRunning
        controlCenterViewModel.confirmedFiveHourResetAt = timerAssistantState.confirmedFiveHourResetAt
        let status = assistantStatus(for: timerAssistantDecision)
        controlCenterViewModel.assistantStatusTitle = status.title
        controlCenterViewModel.assistantStatusDetail = status.detail
    }

    private func assistantStatus(for decision: TimerAssistantDecision) -> (title: String, detail: String) {
        if isTimerStartRunning {
            return isVerifyingTimerStart
                ? ("正在确认计时", "正在读取官方额度状态")
                : ("正在启动计时", "正在向 Codex 发送一次轻量请求")
        }
        let nextCheck = nextCheckDescription()
        switch decision {
        case .disabled:
            return ("计时助手已关闭", "不会自动检查或发送请求")
        case let .unavailable(reason):
            return ("暂时无法检查", reason)
        case .activeWindow:
            return (
                timerAssistantSettings.mode == .periodic ? "自动守候中" : "固定时间模式",
                "当前无需操作 · \(nextCheck)"
            )
        case let .weeklyProtection(remaining, minimum):
            return ("已暂停自动触发", "周额度剩余 \(remaining)%，低于 \(minimum)% 保护线")
        case .outsideSchedule:
            return (
                timerAssistantSettings.mode == .periodic ? "等待使用时段" : "等待固定时间",
                nextCheck
            )
        case .alreadyHandled, .recentlyStarted:
            return ("本轮已处理", "后续只检查状态，不会重复发送请求")
        case .cooldown:
            return ("稍后自动重试", nextCheck)
        case .attemptLimit:
            return ("本轮已停止重试", "下一检查时段会重新判断")
        case .ready:
            return ("准备开始计时", "已确认当前尚未计时")
        }
    }

    private func nextCheckDescription() -> String {
        guard let date = timerAssistantPolicy.nextCheckDate(after: Date(), settings: timerAssistantSettings) else {
            return "下一次检查时间待定"
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        let prefix = Calendar.current.isDateInToday(date) ? "今天" : "明天"
        return "下一次检查：\(prefix) \(formatter.string(from: date))"
    }

    // MARK: - Timer start workflow

    private func startTimerAutomatically(slotKey: String) {
        startTimer(slotKey: slotKey, isAutomatic: true)
    }

    private func startTimerManually() {
        guard !isTimerStartRunning else { return }
        guard let snapshot else {
            controlCenterViewModel.presentNotice("额度尚未同步完成", isError: true)
            return
        }
        if let issue = manualTimerStartIssue(snapshot: snapshot) {
            controlCenterViewModel.presentNotice(issue.message, isError: issue.isError)
            return
        }

        startTimer(slotKey: "manual:\(Int(Date().timeIntervalSince1970))", isAutomatic: false)
    }

    private func startTimer(slotKey: String, isAutomatic: Bool) {
        guard !isTimerStartRunning else { return }
        let requestedAt = Date()
        isTimerStartRunning = true
        isVerifyingTimerStart = false
        timerAssistantState.recordAttempt(slotKey: slotKey, at: requestedAt)
        timerAssistantStore.save(state: timerAssistantState)
        syncRuntimeState()

        timerStartService.start(settings: timerAssistantSettings) { [weak self] result in
            guard let self else { return }
            AppLogger.log(
                "timer start command succeeded=\(result.succeeded) " +
                "inputTokens=\(result.inputTokens.map(String.init) ?? "--") " +
                "outputTokens=\(result.outputTokens.map(String.init) ?? "--") " +
                "executable=\(result.executablePath ?? "--")"
            )
            guard result.succeeded else {
                let prefix = isAutomatic ? "自动启动失败" : "启动失败"
                self.finishTimerStart(
                    slotKey: slotKey,
                    succeeded: false,
                    summary: "\(prefix)：\(result.message)",
                    isAutomatic: isAutomatic
                )
                return
            }
            self.isVerifyingTimerStart = true
            self.syncRuntimeState()
            self.verifyTimerStart(
                slotKey: slotKey,
                requestedAt: requestedAt,
                isAutomatic: isAutomatic,
                delayIndex: 0,
                observations: []
            )
        }
    }

    private func verifyTimerStart(
        slotKey: String,
        requestedAt: Date,
        isAutomatic: Bool,
        delayIndex: Int,
        observations: [UsageSnapshot]
    ) {
        let delays: [TimeInterval] = [3, 7, 10, 15, 25]
        guard delayIndex < delays.count else {
            finishTimerStart(
                slotKey: slotKey,
                succeeded: false,
                summary: "请求已完成，但官方额度中未检测到新的 5 小时计时",
                isAutomatic: isAutomatic
            )
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + delays[delayIndex]) { [weak self] in
            guard let self, self.isTimerStartRunning else { return }
            self.usageService.fetchUsage { [weak self] freshSnapshot in
                DispatchQueue.main.async {
                    guard let self, self.isTimerStartRunning else { return }
                    self.snapshot = freshSnapshot
                    self.controlCenterViewModel.snapshot = freshSnapshot
                    self.updateStatusItem()
                    let updatedObservations = observations + [freshSnapshot]
                    AppLogger.log(
                        "timer start verification attempt=\(delayIndex + 1) " +
                        "source=\(freshSnapshot.sourceName) " +
                        "fiveHour=\(freshSnapshot.fiveHourUsedPercent.map(String.init) ?? "--") " +
                        "resetAt=\(freshSnapshot.fiveHourResetAt.map(String.init(describing:)) ?? "--")"
                    )
                    if confirmsTimerStart(
                        requestedAt: requestedAt,
                        observations: updatedObservations
                    ) {
                        self.finishTimerStart(
                            slotKey: slotKey,
                            succeeded: true,
                            summary: "5 小时计时已确认启动",
                            isAutomatic: isAutomatic,
                            confirmedResetAt: freshSnapshot.fiveHourResetAt
                        )
                    } else {
                        self.verifyTimerStart(
                            slotKey: slotKey,
                            requestedAt: requestedAt,
                            isAutomatic: isAutomatic,
                            delayIndex: delayIndex + 1,
                            observations: updatedObservations
                        )
                    }
                }
            }
        }
    }

    private func finishTimerStart(
        slotKey: String,
        succeeded: Bool,
        summary: String,
        isAutomatic: Bool,
        confirmedResetAt: Date? = nil
    ) {
        isTimerStartRunning = false
        isVerifyingTimerStart = false
        let now = Date()
        timerAssistantState.lastResult = summary
        timerAssistantState.lastResultAt = now
        if succeeded {
            timerAssistantState.markHandled(
                slotKey: slotKey,
                result: summary,
                at: now,
                confirmedResetAt: confirmedResetAt
            )
        }
        timerAssistantStore.save(state: timerAssistantState)
        reevaluatePolicy()
        syncRuntimeState()
        controlCenterViewModel.presentNotice(summary, isError: !succeeded)
        if isAutomatic {
            sendNotification(title: "Codex Rhythm", body: summary)
        }
    }

    private func manualTimerStartIssue(snapshot: UsageSnapshot) -> (message: String, isError: Bool)? {
        let now = Date()
        guard snapshot.errorMessage == nil,
              snapshot.warningMessage == nil,
              snapshot.source.isOfficial,
              now.timeIntervalSince(snapshot.capturedAt) <= 3 * 60 else {
            return ("当前没有可靠的实时额度数据，请先同步", true)
        }
        if activeFiveHourResetAt(
            snapshot: snapshot,
            confirmedResetAt: timerAssistantState.confirmedFiveHourResetAt,
            now: now
        ) != nil {
            return ("当前计时已经开始，无需重复操作", false)
        }
        guard snapshot.fiveHourUsedPercent != nil else {
            return ("无法确认当前计时状态", true)
        }
        guard let weeklyRemaining = snapshot.weeklyRemainingPercent else {
            return ("无法确认一周剩余额度", true)
        }
        if weeklyRemaining < timerAssistantSettings.minimumWeeklyRemainingPercent {
            return ("周额度低于安全保护线，未发送请求", true)
        }
        if let lastSuccessfulStartAt = timerAssistantState.lastSuccessfulStartAt,
           now.timeIntervalSince(lastSuccessfulStartAt) < 15 * 60 {
            return ("刚刚已经处理过，本轮不会重复发送", false)
        }
        return nil
    }

    private func rememberActiveWindow(from snapshot: UsageSnapshot) {
        let now = Date()
        guard let usedPercent = snapshot.fiveHourUsedPercent,
              usedPercent > 0,
              let resetAt = snapshot.fiveHourResetAt,
              resetAt > now.addingTimeInterval(30) else {
            return
        }
        if let savedResetAt = timerAssistantState.confirmedFiveHourResetAt,
           abs(savedResetAt.timeIntervalSince(resetAt)) < 1 {
            return
        }
        timerAssistantState.confirmedFiveHourResetAt = resetAt
        timerAssistantStore.save(state: timerAssistantState)
    }

    // MARK: - Quota reset

    private func redeemUsageReset() {
        guard !controlCenterViewModel.isRedeemingReset else { return }
        guard let availableCount = snapshot?.resetCredits?.availableCount,
              availableCount > 0 else {
            controlCenterViewModel.presentNotice("当前没有可用的限额重置次数", isError: true)
            return
        }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "使用一次限额重置？"
        alert.informativeText = "这会立即消耗 1 次可用重置，并重置当前符合条件的 Codex 使用窗口。此操作无法撤销。"
        alert.addButton(withTitle: "确认重置")
        alert.addButton(withTitle: "取消")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        let defaults = UserDefaults.standard
        let keyName = "BankedReset.pendingIdempotencyKey"
        let idempotencyKey = defaults.string(forKey: keyName) ?? UUID().uuidString
        defaults.set(idempotencyKey, forKey: keyName)
        controlCenterViewModel.isRedeemingReset = true
        controlCenterViewModel.presentNotice("正在使用限额重置…")

        quotaResetService.redeem(
            customExecutablePath: timerAssistantSettings.codexExecutablePath,
            idempotencyKey: idempotencyKey
        ) { [weak self] result in
            guard let self else { return }
            self.controlCenterViewModel.isRedeemingReset = false
            if result.receipt.outcome != nil {
                defaults.removeObject(forKey: keyName)
            }

            let message: String
            let isError: Bool
            switch result.receipt.outcome {
            case .reset:
                message = "限额已重置，正在同步最新状态"
                isError = false
            case .alreadyRedeemed:
                message = "本次限额重置此前已经成功，正在同步"
                isError = false
            case .nothingToReset:
                message = "当前额度无需重置，未消耗重置次数"
                isError = false
            case .noCredit:
                message = "当前没有可用的限额重置次数"
                isError = true
            case nil:
                message = "限额重置失败：\(result.message)"
                isError = true
            }
            self.controlCenterViewModel.presentNotice(message, isError: isError)
            AppLogger.log("usage reset outcome=\(result.receipt.outcome?.rawValue ?? "unknown") message=\(result.message)")

            if result.receipt.outcome != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in self?.refresh() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in self?.refresh() }
            }
        }
    }

    // MARK: - System integration

    private func openCodex() {
        let candidates = [
            "/Applications/Codex.app",
            "/Applications/ChatGPT.app",
            "\(NSHomeDirectory())/Applications/Codex.app"
        ]
        guard let path = candidates.first(where: FileManager.default.fileExists) else {
            controlCenterViewModel.presentNotice("找不到 Codex 客户端", isError: true)
            return
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error { AppLogger.log("notification permission error=\(error.localizedDescription)") }
        }
    }

    private func sendNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            guard granted, error == nil else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            center.add(UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil))
        }
    }
}

private final class GlassControlWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
