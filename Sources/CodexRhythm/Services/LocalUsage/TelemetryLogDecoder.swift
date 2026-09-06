import Foundation

struct TelemetryLogDecoder {
    func decode(row: String, apiFailure: Error) -> UsageSnapshot? {
        let trimmed = row.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let separator = trimmed.firstIndex(of: "\t"),
              let timestamp = TimeInterval(trimmed[..<separator]) else {
            return nil
        }

        let payloadStart = trimmed.index(after: separator)
        let fields = TelemetryFieldReader(String(trimmed[payloadStart...]))
        let windows = [
            window(prefix: "x-codex-primary", fields: fields),
            window(prefix: "x-codex-secondary", fields: fields)
        ].compactMap { $0 }
        guard !windows.isEmpty else { return nil }

        return UsageSnapshot(
            capturedAt: Date(timeIntervalSince1970: timestamp),
            source: .localTelemetry,
            planType: fields.string(named: "x-codex-plan-type"),
            windows: windows,
            warningMessage: "官方接口暂不可用：\(apiFailure.localizedDescription)"
        )
    }

    private func window(prefix: String, fields: TelemetryFieldReader) -> QuotaWindow? {
        guard let duration = fields.integer(named: "\(prefix)-window-minutes"),
              let kind = QuotaWindowClassifier.classify(durationMinutes: duration) else {
            return nil
        }
        return QuotaWindow(
            kind: kind,
            usedPercent: fields.integer(named: "\(prefix)-used-percent"),
            durationMinutes: duration,
            resetsAt: fields.epochDate(named: "\(prefix)-reset-at")
        )
    }
}
