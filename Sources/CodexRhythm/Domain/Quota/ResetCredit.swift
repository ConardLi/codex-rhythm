import Foundation

struct ResetCredit: Equatable {
    let identifier: String
    let label: String?
    let kind: String?
    let state: String
    let expiration: Date?

    var isAvailable: Bool { state == "available" }
}

struct ResetCreditInventory: Equatable {
    let reportedAvailableCount: Int
    let credits: [ResetCredit]

    var availableCount: Int { max(0, reportedAvailableCount) }

    var available: [ResetCredit] {
        credits
            .filter(\.isAvailable)
            .sorted {
                switch ($0.expiration, $1.expiration) {
                case let (.some(left), .some(right)) where left != right:
                    return left < right
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                default:
                    return $0.identifier < $1.identifier
                }
            }
    }
}

enum ResetCreditDateFormatter {
    static func displayString(for date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd EEE HH:mm:ss"
        return formatter.string(from: date)
    }
}
