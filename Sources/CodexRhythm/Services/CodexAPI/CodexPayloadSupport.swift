import Foundation

enum CodexPayloadError: LocalizedError {
    case malformedUsage
    case noRecognizedWindows
    case malformedResetCredits

    var errorDescription: String? {
        switch self {
        case .malformedUsage:
            return "Codex 用量格式无法解析"
        case .noRecognizedWindows:
            return "Codex 用量接口没有可识别的窗口数据"
        case .malformedResetCredits:
            return "Codex 返回了无法识别的限额重置数据"
        }
    }
}

struct FlexibleInteger: Decodable {
    let value: Int

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let integer = try? container.decode(Int.self) {
            value = integer
        } else if let number = try? container.decode(Double.self) {
            value = Int(number.rounded())
        } else if let text = try? container.decode(String.self),
                  let number = Double(text) {
            value = Int(number.rounded())
        } else {
            throw DecodingError.typeMismatch(
                Int.self,
                .init(codingPath: decoder.codingPath, debugDescription: "Expected a number")
            )
        }
    }
}

enum ISO8601TimestampParser {
    static func date(from text: String?) -> Date? {
        guard let text else { return nil }
        let parser = ISO8601DateFormatter()
        parser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = parser.date(from: text) { return date }
        parser.formatOptions = [.withInternetDateTime]
        return parser.date(from: text)
    }
}
