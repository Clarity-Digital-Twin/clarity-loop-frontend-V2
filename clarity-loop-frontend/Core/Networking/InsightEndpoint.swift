import Foundation

enum InsightEndpoint {
    case getHistory(userId: String, limit: Int, offset: Int)
    case generate(dto: InsightGenerationRequestDTO)
    case chat(dto: ChatRequestDTO)
    case getInsight(id: String)
    case getServiceStatus
}

extension InsightEndpoint: Endpoint {
    var path: String {
        switch self {
        case let .getHistory(userId, _, _):
            "/api/v1/insights/history/\(userId)"
        case .generate:
            "/api/v1/insights"
        case .chat:
            "/api/v1/insights/chat"
        case let .getInsight(id):
            "/api/v1/insights/\(id)"
        case .getServiceStatus:
            "/api/v1/insights/alerts"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .getHistory, .getInsight, .getServiceStatus:
            .get
        case .generate, .chat:
            .post
        }
    }

    func body(encoder: JSONEncoder) throws -> Data? {
        switch self {
        case .getHistory, .getInsight, .getServiceStatus:
            nil
        case let .generate(dto):
            try encoder.encode(dto)
        case let .chat(dto):
            try encoder.encode(dto)
        }
    }

    func asURLRequest(baseURL: URL, encoder: JSONEncoder) throws -> URLRequest {
        // First, create the basic request.
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try body(encoder: encoder)

        // Then, add query parameters if necessary.
        switch self {
        case let .getHistory(_, limit, offset):
            guard let url = request.url else {
                throw APIError.invalidURL
            }
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = [
                URLQueryItem(name: "limit", value: "\(limit)"),
                URLQueryItem(name: "offset", value: "\(offset)"),
            ]
            request.url = components?.url

        case .generate, .chat, .getInsight, .getServiceStatus:
            // These endpoints don't need query parameters
            break
        }

        return request
    }
}
