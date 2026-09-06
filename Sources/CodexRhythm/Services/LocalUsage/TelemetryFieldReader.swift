import Foundation

struct TelemetryFieldReader {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    func string(named name: String) -> String? {
        let marker = "\"\(name)\""
        guard let keyRange = text.range(of: marker) else { return nil }

        var cursor = keyRange.upperBound
        while cursor < text.endIndex, text[cursor].isWhitespace {
            cursor = text.index(after: cursor)
        }
        guard cursor < text.endIndex, text[cursor] == ":" else { return nil }
        cursor = text.index(after: cursor)
        while cursor < text.endIndex, text[cursor].isWhitespace {
            cursor = text.index(after: cursor)
        }
        guard cursor < text.endIndex, text[cursor] == "\"" else { return nil }

        let valueStart = text.index(after: cursor)
        cursor = valueStart
        var isEscaped = false
        while cursor < text.endIndex {
            let character = text[cursor]
            if character == "\"", !isEscaped {
                return String(text[valueStart..<cursor])
            }
            if character == "\\" {
                isEscaped.toggle()
            } else {
                isEscaped = false
            }
            cursor = text.index(after: cursor)
        }
        return nil
    }

    func integer(named name: String) -> Int? {
        string(named: name).flatMap(Int.init)
    }

    func epochDate(named name: String) -> Date? {
        integer(named: name).map { Date(timeIntervalSince1970: TimeInterval($0)) }
    }
}
