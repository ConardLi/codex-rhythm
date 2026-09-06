import Foundation

final class CodexUsageService {
    private final class FetchBatch {
        private let lock = NSLock()
        private var usage: UsageSnapshot?
        private var credits: Result<ResetCreditInventory, Error>?
        private var pendingResponses = 2
        private let completion: (UsageSnapshot) -> Void

        init(completion: @escaping (UsageSnapshot) -> Void) {
            self.completion = completion
        }

        func receiveUsage(_ snapshot: UsageSnapshot) {
            finish { usage = snapshot }
        }

        func receiveCredits(_ result: Result<ResetCreditInventory, Error>) {
            finish { credits = result }
        }

        private func finish(_ mutation: () -> Void) {
            lock.lock()
            mutation()
            pendingResponses -= 1
            guard pendingResponses == 0 else {
                lock.unlock()
                return
            }
            var finalSnapshot = usage ?? .unavailable("Codex 用量读取未完成")
            switch credits {
            case let .success(inventory):
                finalSnapshot.resetCredits = inventory
            case let .failure(error):
                finalSnapshot.resetCreditsError = "限额重置次数读取失败：\(error.localizedDescription)"
            case nil:
                finalSnapshot.resetCreditsError = "限额重置次数读取未完成"
            }
            lock.unlock()
            completion(finalSnapshot)
        }
    }

    private let configuration: CodexAPIConfiguration
    private let credentialsProvider: CodexCredentialsProviding
    private let httpClient: CodexHTTPClient
    private let usageDecoder = UsagePayloadDecoder()
    private let resetCreditsDecoder = ResetCreditsPayloadDecoder()
    private let localFallback: LocalUsageSnapshotReader

    init(
        configuration: CodexAPIConfiguration = .production,
        credentialsProvider: CodexCredentialsProviding = FileCodexCredentialsProvider(),
        httpClient: CodexHTTPClient? = nil,
        localFallback: LocalUsageSnapshotReader = LocalUsageSnapshotReader()
    ) {
        self.configuration = configuration
        self.credentialsProvider = credentialsProvider
        self.httpClient = httpClient ?? CodexHTTPClient(userAgent: configuration.userAgent)
        self.localFallback = localFallback
    }

    func fetchUsage(completion: @escaping (UsageSnapshot) -> Void) {
        let credentials: CodexCredentials
        do {
            credentials = try credentialsProvider.load()
        } catch {
            var snapshot = localFallback.latestSnapshot(after: error)
            snapshot.resetCreditsError = "限额重置次数读取失败：\(error.localizedDescription)"
            completion(snapshot)
            return
        }

        let batch = FetchBatch(completion: completion)
        fetchQuota(credentials: credentials, batch: batch)
        fetchResetCredits(credentials: credentials, batch: batch)
    }

    private func fetchQuota(credentials: CodexCredentials, batch: FetchBatch) {
        httpClient.get(
            configuration.usageEndpoint,
            credentials: credentials,
            endpointName: "Codex 用量接口"
        ) { [usageDecoder, localFallback] result in
            switch result {
            case let .success(data):
                do {
                    batch.receiveUsage(try usageDecoder.decode(data))
                } catch {
                    batch.receiveUsage(localFallback.latestSnapshot(after: error))
                }
            case let .failure(error):
                batch.receiveUsage(localFallback.latestSnapshot(after: error))
            }
        }
    }

    private func fetchResetCredits(credentials: CodexCredentials, batch: FetchBatch) {
        httpClient.get(
            configuration.resetCreditsEndpoint,
            credentials: credentials,
            endpointName: "限额重置接口",
            additionalHeaders: ["originator": "Codex Desktop"]
        ) { [resetCreditsDecoder] result in
            batch.receiveCredits(result.flatMap { data in
                Result { try resetCreditsDecoder.decode(data) }
            })
        }
    }
}
