import Foundation

struct CodexAPIConfiguration {
    let usageEndpoint: URL
    let resetCreditsEndpoint: URL
    let userAgent: String

    static let production = CodexAPIConfiguration(
        usageEndpoint: URL(string: "https://chatgpt.com/backend-api/wham/usage")!,
        resetCreditsEndpoint: URL(
            string: "https://chatgpt.com/backend-api/wham/rate-limit-reset-credits"
        )!,
        userAgent: "CodexRhythm/3.5"
    )
}
