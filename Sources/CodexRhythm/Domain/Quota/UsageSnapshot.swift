import Foundation

enum UsageDataSource: Equatable {
    case officialAPI
    case localTelemetry
    case unavailable

    var displayName: String {
        switch self {
        case .officialAPI: return "Codex 官方用量接口"
        case .localTelemetry: return "本地日志（备用）"
        case .unavailable: return "不可用"
        }
    }

    var isOfficial: Bool { self == .officialAPI }
}

struct UsageSnapshot {
    let capturedAt: Date
    let source: UsageDataSource
    let planType: String?
    let fiveHourWindow: QuotaWindow?
    let weeklyWindow: QuotaWindow?
    let warningMessage: String?
    let errorMessage: String?
    var resetCredits: ResetCreditInventory?
    var resetCreditsError: String?

    init(
        capturedAt: Date,
        source: UsageDataSource,
        planType: String?,
        windows: [QuotaWindow],
        warningMessage: String? = nil,
        errorMessage: String? = nil,
        resetCredits: ResetCreditInventory? = nil,
        resetCreditsError: String? = nil
    ) {
        self.capturedAt = capturedAt
        self.source = source
        self.planType = planType
        fiveHourWindow = windows.first { $0.kind == .fiveHour }
        weeklyWindow = windows.first { $0.kind == .weekly }
        self.warningMessage = warningMessage
        self.errorMessage = errorMessage
        self.resetCredits = resetCredits
        self.resetCreditsError = resetCreditsError
    }

    static func unavailable(_ message: String, capturedAt: Date = Date()) -> UsageSnapshot {
        UsageSnapshot(
            capturedAt: capturedAt,
            source: .unavailable,
            planType: nil,
            windows: [],
            errorMessage: message
        )
    }

    var sourceDate: Date { capturedAt }
    var sourceName: String { source.displayName }
    var fiveHourUsedPercent: Int? { fiveHourWindow?.usedPercent }
    var weeklyUsedPercent: Int? { weeklyWindow?.usedPercent }
    var fiveHourWindowMinutes: Int? { fiveHourWindow?.durationMinutes }
    var weeklyWindowMinutes: Int? { weeklyWindow?.durationMinutes }
    var fiveHourResetAt: Date? { fiveHourWindow?.resetsAt }
    var weeklyResetAt: Date? { weeklyWindow?.resetsAt }
    var fiveHourRemainingPercent: Int? { fiveHourWindow?.remainingPercent }
    var weeklyRemainingPercent: Int? { weeklyWindow?.remainingPercent }
}
