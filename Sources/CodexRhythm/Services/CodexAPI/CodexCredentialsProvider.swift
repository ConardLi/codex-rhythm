import Foundation

struct CodexCredentials: Equatable {
    let accessToken: String
    let accountIdentifier: String
}

protocol CodexCredentialsProviding {
    func load() throws -> CodexCredentials
}

enum CodexCredentialsError: LocalizedError {
    case incompleteAuthenticationFile

    var errorDescription: String? {
        "找不到 Codex 登录信息"
    }
}

struct FileCodexCredentialsProvider: CodexCredentialsProviding {
    private let authenticationFile: URL

    init(homeDirectory: String = NSHomeDirectory()) {
        authenticationFile = URL(fileURLWithPath: homeDirectory)
            .appendingPathComponent(".codex/auth.json")
    }

    func load() throws -> CodexCredentials {
        struct AuthenticationDocument: Decodable {
            struct TokenSet: Decodable {
                let accessToken: String
                let accountIdentifier: String

                enum CodingKeys: String, CodingKey {
                    case accessToken = "access_token"
                    case accountIdentifier = "account_id"
                }
            }

            let tokens: TokenSet
        }

        let data = try Data(contentsOf: authenticationFile)
        let document = try JSONDecoder().decode(AuthenticationDocument.self, from: data)
        guard !document.tokens.accessToken.isEmpty,
              !document.tokens.accountIdentifier.isEmpty else {
            throw CodexCredentialsError.incompleteAuthenticationFile
        }
        return CodexCredentials(
            accessToken: document.tokens.accessToken,
            accountIdentifier: document.tokens.accountIdentifier
        )
    }
}
