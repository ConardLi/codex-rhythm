import Foundation

enum CodexResetOutcome: String, Equatable {
    case reset
    case nothingToReset
    case noCredit
    case alreadyRedeemed
}

struct CodexResetReceipt: Equatable {
    let outcome: CodexResetOutcome?
    let errorMessage: String?
}

struct CodexResetResult {
    let receipt: CodexResetReceipt
    let message: String
}

func parseCodexResetResponse(_ output: String, requestID: Int = 2) -> CodexResetReceipt? {
    for line in output.split(whereSeparator: \.isNewline) {
        guard let data = String(line).data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              (object["id"] as? NSNumber)?.intValue == requestID else {
            continue
        }

        if let result = object["result"] as? [String: Any],
           let rawOutcome = result["outcome"] as? String,
           let outcome = CodexResetOutcome(rawValue: rawOutcome) {
            return CodexResetReceipt(outcome: outcome, errorMessage: nil)
        }
        if let error = object["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "Codex 未能完成限额重置"
            return CodexResetReceipt(outcome: nil, errorMessage: message)
        }
        return CodexResetReceipt(outcome: nil, errorMessage: "Codex 返回了无法识别的重置结果")
    }
    return nil
}

final class QuotaResetService {
    private let queue = DispatchQueue(label: "app.codexrhythm.quota-reset")
    private let timeoutQueue = DispatchQueue(label: "app.codexrhythm.quota-reset.timeout")

    func redeem(
        customExecutablePath: String,
        idempotencyKey: String,
        completion: @escaping (CodexResetResult) -> Void
    ) {
        queue.async {
            guard let executable = TimerStartService().resolveExecutable(
                customPath: customExecutablePath
            ) else {
                self.complete(
                    CodexResetResult(
                        receipt: CodexResetReceipt(outcome: nil, errorMessage: "找不到 Codex CLI"),
                        message: "找不到可执行的 Codex CLI"
                    ),
                    completion: completion
                )
                return
            }

            let process = Process()
            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = ["app-server", "--stdio"]
            process.currentDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

            let inputPipe = Pipe()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardInput = inputPipe
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
            } catch {
                self.complete(
                    CodexResetResult(
                        receipt: CodexResetReceipt(outcome: nil, errorMessage: error.localizedDescription),
                        message: "启动 Codex 重置服务失败：\(error.localizedDescription)"
                    ),
                    completion: completion
                )
                return
            }

            let initialize: [String: Any] = [
                "id": 1,
                "method": "initialize",
                "params": [
                    "clientInfo": [
                        "name": "codex-rhythm",
                        "title": "Codex Rhythm",
                        "version": "3.5.0"
                    ]
                ]
            ]
            let consume: [String: Any] = [
                "id": 2,
                "method": "account/rateLimitResetCredit/consume",
                "params": ["idempotencyKey": idempotencyKey]
            ]

            do {
                for request in [initialize, consume] {
                    let data = try JSONSerialization.data(withJSONObject: request)
                    inputPipe.fileHandleForWriting.write(data)
                    inputPipe.fileHandleForWriting.write(Data([0x0A]))
                }
                try inputPipe.fileHandleForWriting.close()
            } catch {
                if process.isRunning { process.terminate() }
                self.complete(
                    CodexResetResult(
                        receipt: CodexResetReceipt(outcome: nil, errorMessage: error.localizedDescription),
                        message: "发送重置请求失败：\(error.localizedDescription)"
                    ),
                    completion: completion
                )
                return
            }

            var timedOut = false
            let timeoutItem = DispatchWorkItem {
                if process.isRunning {
                    timedOut = true
                    process.terminate()
                }
            }
            self.timeoutQueue.asyncAfter(deadline: .now() + 45, execute: timeoutItem)
            process.waitUntilExit()
            timeoutItem.cancel()

            let stdout = self.readOutput(outputPipe)
            let stderr = self.readOutput(errorPipe)
            let receipt = parseCodexResetResponse(stdout)
                ?? CodexResetReceipt(
                    outcome: nil,
                    errorMessage: timedOut ? "请求超时" : "没有收到 Codex 重置回执"
                )
            let fallbackDetail = stderr.isEmpty ? receipt.errorMessage : stderr
            let message = receipt.outcome == nil
                ? String((fallbackDetail ?? "限额重置失败").prefix(600))
                : "Codex 已返回限额重置结果"
            self.complete(
                CodexResetResult(receipt: receipt, message: message),
                completion: completion
            )
        }
    }

    private func complete(
        _ result: CodexResetResult,
        completion: @escaping (CodexResetResult) -> Void
    ) {
        DispatchQueue.main.async {
            completion(result)
        }
    }

    private func readOutput(_ pipe: Pipe) -> String {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (String(data: data, encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
