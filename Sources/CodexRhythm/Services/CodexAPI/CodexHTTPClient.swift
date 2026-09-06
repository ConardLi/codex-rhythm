import Foundation

enum CodexHTTPError: LocalizedError {
    case rejected(endpoint: String, statusCode: Int)
    case missingBody(endpoint: String)

    var errorDescription: String? {
        switch self {
        case let .rejected(endpoint, statusCode):
            return "\(endpoint)返回 HTTP \(statusCode)"
        case let .missingBody(endpoint):
            return "\(endpoint)没有返回数据"
        }
    }
}

final class CodexHTTPClient {
    private let session: URLSession
    private let userAgent: String

    init(
        userAgent: String,
        session: URLSession = CodexHTTPClient.makeSession()
    ) {
        self.userAgent = userAgent
        self.session = session
    }

    func get(
        _ url: URL,
        credentials: CodexCredentials,
        endpointName: String,
        additionalHeaders: [String: String] = [:],
        completion: @escaping (Result<Data, Error>) -> Void
    ) {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(credentials.accountIdentifier, forHTTPHeaderField: "ChatGPT-Account-ID")
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        additionalHeaders.forEach { request.setValue($1, forHTTPHeaderField: $0) }

        session.dataTask(with: request) { data, response, transportError in
            if let transportError {
                completion(.failure(transportError))
                return
            }
            guard let response = response as? HTTPURLResponse,
                  (200..<300).contains(response.statusCode) else {
                completion(.failure(CodexHTTPError.rejected(
                    endpoint: endpointName,
                    statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1
                )))
                return
            }
            guard let data else {
                completion(.failure(CodexHTTPError.missingBody(endpoint: endpointName)))
                return
            }
            completion(.success(data))
        }.resume()
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 15
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }
}
