import Foundation

struct ResetCreditsPayloadDecoder {
    private struct Envelope: Decodable {
        struct Credit: Decodable {
            let identifier: String
            let label: String?
            let kind: String?
            let state: String
            let expiration: String?

            enum CodingKeys: String, CodingKey {
                case identifier = "id"
                case label = "title"
                case kind = "reset_type"
                case state = "status"
                case expiration = "expires_at"
            }
        }

        let availableCount: FlexibleInteger
        let credits: [Credit]

        enum CodingKeys: String, CodingKey {
            case availableCount = "available_count"
            case credits
        }
    }

    func decode(_ data: Data) throws -> ResetCreditInventory {
        let payload: Envelope
        do {
            payload = try JSONDecoder().decode(Envelope.self, from: data)
        } catch {
            throw CodexPayloadError.malformedResetCredits
        }
        guard payload.credits.allSatisfy({ !$0.identifier.isEmpty && !$0.state.isEmpty }) else {
            throw CodexPayloadError.malformedResetCredits
        }

        return ResetCreditInventory(
            reportedAvailableCount: payload.availableCount.value,
            credits: payload.credits.map {
                ResetCredit(
                    identifier: $0.identifier,
                    label: $0.label,
                    kind: $0.kind,
                    state: $0.state,
                    expiration: ISO8601TimestampParser.date(from: $0.expiration)
                )
            }
        )
    }
}
