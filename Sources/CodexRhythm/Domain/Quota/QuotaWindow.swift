import Foundation

enum QuotaWindowKind: Hashable {
    case fiveHour
    case weekly
}

struct QuotaWindow: Equatable {
    let kind: QuotaWindowKind
    let usedPercent: Int?
    let durationMinutes: Int
    let resetsAt: Date?

    var remainingPercent: Int? {
        usedPercent.map { min(100, max(0, 100 - $0)) }
    }
}

enum QuotaWindowClassifier {
    private static let fiveHourRange = 240...360
    private static let weeklyRange = (6 * 24 * 60)...(8 * 24 * 60)

    static func classify(durationMinutes: Int?) -> QuotaWindowKind? {
        guard let durationMinutes else { return nil }
        if fiveHourRange.contains(durationMinutes) { return .fiveHour }
        if weeklyRange.contains(durationMinutes) { return .weekly }
        return nil
    }
}
