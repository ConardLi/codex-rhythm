import Foundation

struct LocalUsageSnapshotReader {
    private static let latestUsageStatement = """
    SELECT ts || char(9) || feedback_log_body
    FROM logs
    WHERE feedback_log_body LIKE '%x-codex-primary-used-percent%'
    ORDER BY ts DESC, ts_nanos DESC
    LIMIT 1;
    """

    private let databasePaths: [String]
    private let query: SQLiteQuerying
    private let decoder = TelemetryLogDecoder()

    init(
        homeDirectory: String = NSHomeDirectory(),
        query: SQLiteQuerying = SQLiteProcessQuery()
    ) {
        databasePaths = [
            "\(homeDirectory)/.codex/logs_2.sqlite",
            "\(homeDirectory)/.codex/sqlite/logs_2.sqlite"
        ]
        self.query = query
    }

    func latestSnapshot(after apiFailure: Error) -> UsageSnapshot {
        let candidates = databasePaths.filter(FileManager.default.fileExists(atPath:))
        guard !candidates.isEmpty else {
            return .unavailable("官方接口不可用，且找不到 Codex 本地日志。")
        }

        var snapshots: [UsageSnapshot] = []
        var mostRecentError: Error?
        for path in candidates {
            do {
                let row = try query.execute(
                    databasePath: path,
                    statement: Self.latestUsageStatement
                )
                if let snapshot = decoder.decode(row: row, apiFailure: apiFailure) {
                    snapshots.append(snapshot)
                }
            } catch {
                mostRecentError = error
            }
        }

        if let latest = snapshots.max(by: { $0.capturedAt < $1.capturedAt }) {
            return latest
        }
        let detail = mostRecentError?.localizedDescription ?? apiFailure.localizedDescription
        return .unavailable("读取 Codex 用量失败：\(detail)")
    }
}
