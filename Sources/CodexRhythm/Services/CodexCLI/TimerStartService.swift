import Foundation

struct TimerStartResult {
    let succeeded: Bool
    let message: String
    let executablePath: String?
    let inputTokens: Int?
    let outputTokens: Int?
}

final class TimerStartService {
    private let queue = DispatchQueue(label: "app.codexrhythm.timer-start")
    private let timeoutQueue = DispatchQueue(label: "app.codexrhythm.timer-start.timeout")

    func start(
        settings: TimerAssistantSettings,
        completion: @escaping (TimerStartResult) -> Void
    ) {
        queue.async {
            let settings = settings.normalized
            guard let executable = self.resolveExecutable(customPath: settings.codexExecutablePath) else {
                DispatchQueue.main.async {
                    completion(
                        TimerStartResult(
                            succeeded: false,
                            message: "找不到可执行的 codex CLI，请在设置中填写完整路径",
                            executablePath: nil,
                            inputTokens: nil,
                            outputTokens: nil
                        )
                    )
                }
                return
            }

            let login = self.runProcess(
                executable: executable,
                arguments: ["login", "status"],
                timeout: 15
            )
            let loginDetail = [login.stdout, login.stderr]
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
            guard login.status == 0, loginDetail.contains("Logged in using ChatGPT") else {
                DispatchQueue.main.async {
                    completion(
                        TimerStartResult(
                            succeeded: false,
                            message: "Codex CLI 必须使用 ChatGPT 账号登录；API Key 请求不会启动订阅的 5 小时计时",
                            executablePath: executable,
                            inputTokens: nil,
                            outputTokens: nil
                        )
                    )
                }
                return
            }

            var arguments = [
                "exec",
                "--ephemeral",
                "--json",
                "--skip-git-repo-check",
                "--sandbox", "read-only",
                "--ignore-user-config",
                "--ignore-rules"
            ]
            if !settings.model.isEmpty {
                arguments += ["--model", settings.model]
            }
            arguments.append("Reply exactly: TIMER_STARTED. Do not inspect files, call tools, or perform any other work.")

            let execution = self.runProcess(
                executable: executable,
                arguments: arguments,
                timeout: 90
            )
            let receipt = self.parseReceipt(execution.stdout)
            let succeeded = execution.status == 0 && receipt.turnCompleted && receipt.totalTokens > 0
            let failureDetail = execution.stderr.isEmpty ? execution.stdout : execution.stderr
            let message: String
            if succeeded {
                message = "Codex 请求已完成（输入 \(receipt.inputTokens ?? 0)，输出 \(receipt.outputTokens ?? 0) Token）"
            } else if execution.timedOut {
                message = "Codex 请求超时"
            } else if execution.status != 0 {
                message = failureDetail.isEmpty
                    ? "Codex 返回退出码 \(execution.status)"
                    : String(failureDetail.prefix(600))
            } else {
                message = "Codex 请求结束，但没有收到有效的模型用量回执"
            }

            DispatchQueue.main.async {
                completion(
                    TimerStartResult(
                        succeeded: succeeded,
                        message: message,
                        executablePath: executable,
                        inputTokens: receipt.inputTokens,
                        outputTokens: receipt.outputTokens
                    )
                )
            }
        }
    }

    func resolveExecutable(customPath: String) -> String? {
        let fileManager = FileManager.default
        let customPath = NSString(string: customPath).expandingTildeInPath
        if !customPath.isEmpty, fileManager.isExecutableFile(atPath: customPath) {
            return customPath
        }

        var candidates = [
            "/Applications/ChatGPT.app/Contents/Resources/codex",
            "/Applications/Codex.app/Contents/Resources/codex",
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "\(NSHomeDirectory())/.local/bin/codex"
        ]
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            candidates += path.split(separator: ":").map { "\($0)/codex" }
        }
        candidates += nvmCandidates()

        var seen = Set<String>()
        return candidates.first { path in
            guard seen.insert(path).inserted else {
                return false
            }
            return fileManager.isExecutableFile(atPath: path)
        }
    }

    private func nvmCandidates() -> [String] {
        let versionsPath = "\(NSHomeDirectory())/.nvm/versions/node"
        guard let versions = try? FileManager.default.contentsOfDirectory(atPath: versionsPath) else {
            return []
        }
        return versions.sorted(by: >).map { "\(versionsPath)/\($0)/bin/codex" }
    }

    private func runProcess(
        executable: String,
        arguments: [String],
        timeout: TimeInterval
    ) -> ProcessExecution {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
        } catch {
            return ProcessExecution(
                status: -1,
                stdout: "",
                stderr: "启动 codex 失败：\(error.localizedDescription)",
                timedOut: false
            )
        }

        var timedOut = false
        let timeoutItem = DispatchWorkItem {
            if process.isRunning {
                timedOut = true
                process.terminate()
            }
        }
        timeoutQueue.asyncAfter(deadline: .now() + timeout, execute: timeoutItem)
        process.waitUntilExit()
        timeoutItem.cancel()

        return ProcessExecution(
            status: process.terminationStatus,
            stdout: readOutput(outputPipe),
            stderr: readOutput(errorPipe),
            timedOut: timedOut
        )
    }

    private func parseReceipt(_ output: String) -> CodexExecutionReceipt {
        var receipt = CodexExecutionReceipt()
        for line in output.split(whereSeparator: \.isNewline) {
            guard let data = String(line).data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  object["type"] as? String == "turn.completed" else {
                continue
            }
            receipt.turnCompleted = true
            guard let usage = object["usage"] as? [String: Any] else { continue }
            receipt.inputTokens = (usage["input_tokens"] as? NSNumber)?.intValue
            receipt.outputTokens = (usage["output_tokens"] as? NSNumber)?.intValue
        }
        return receipt
    }

    private func readOutput(_ pipe: Pipe) -> String {
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (String(data: data, encoding: .utf8) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

private struct ProcessExecution {
    let status: Int32
    let stdout: String
    let stderr: String
    let timedOut: Bool
}

private struct CodexExecutionReceipt {
    var turnCompleted = false
    var inputTokens: Int?
    var outputTokens: Int?

    var totalTokens: Int {
        (inputTokens ?? 0) + (outputTokens ?? 0)
    }
}
