import Foundation

struct UsagePayloadDecoder {
    private struct Envelope: Decodable {
        struct RateLimit: Decodable {
            let primary: Window?
            let secondary: Window?

            enum CodingKeys: String, CodingKey {
                case primary = "primary_window"
                case secondary = "secondary_window"
            }

            init(from decoder: Decoder) throws {
                let container = try decoder.container(keyedBy: CodingKeys.self)
                primary = try? container.decodeIfPresent(Window.self, forKey: .primary)
                secondary = try? container.decodeIfPresent(Window.self, forKey: .secondary)
            }
        }

        struct Window: Decodable {
            let usedPercent: FlexibleInteger?
            let durationSeconds: FlexibleInteger
            let resetEpoch: FlexibleInteger?

            enum CodingKeys: String, CodingKey {
                case usedPercent = "used_percent"
                case durationSeconds = "limit_window_seconds"
                case resetEpoch = "reset_at"
            }

            func domainValue() -> QuotaWindow? {
                let minutes = durationSeconds.value / 60
                guard let kind = QuotaWindowClassifier.classify(durationMinutes: minutes) else {
                    return nil
                }
                return QuotaWindow(
                    kind: kind,
                    usedPercent: usedPercent?.value,
                    durationMinutes: minutes,
                    resetsAt: resetEpoch.map { Date(timeIntervalSince1970: TimeInterval($0.value)) }
                )
            }
        }

        let planType: String?
        let rateLimit: RateLimit

        enum CodingKeys: String, CodingKey {
            case planType = "plan_type"
            case rateLimit = "rate_limit"
        }
    }

    func decode(_ data: Data, capturedAt: Date = Date()) throws -> UsageSnapshot {
        let envelope: Envelope
        do {
            envelope = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw CodexPayloadError.malformedUsage
        }

        let windows = [envelope.rateLimit.primary, envelope.rateLimit.secondary]
            .compactMap { $0?.domainValue() }
        guard !windows.isEmpty else { throw CodexPayloadError.noRecognizedWindows }

        return UsageSnapshot(
            capturedAt: capturedAt,
            source: .officialAPI,
            planType: envelope.planType,
            windows: windows
        )
    }
}
