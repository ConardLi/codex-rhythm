import Foundation

protocol SQLiteQuerying {
    func execute(databasePath: String, statement: String) throws -> String
}

enum SQLiteQueryError: LocalizedError {
    case commandFailed(status: Int32, message: String)

    var errorDescription: String? {
        switch self {
        case let .commandFailed(_, message):
            return message.isEmpty ? "sqlite3 执行失败" : message
        }
    }
}

struct SQLiteProcessQuery: SQLiteQuerying {
    func execute(databasePath: String, statement: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [databasePath, statement]

        let standardOutput = Pipe()
        let standardError = Pipe()
        process.standardOutput = standardOutput
        process.standardError = standardError
        try process.run()
        process.waitUntilExit()

        let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
        let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
        guard process.terminationStatus == 0 else {
            let message = String(data: errorData, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            throw SQLiteQueryError.commandFailed(
                status: process.terminationStatus,
                message: message
            )
        }
        return String(data: outputData, encoding: .utf8) ?? ""
    }
}
