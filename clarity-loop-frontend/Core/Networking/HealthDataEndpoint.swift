import Foundation

enum HealthDataEndpoint {
    case getMetrics(page: Int, limit: Int)
    case uploadHealthKit(dto: HealthKitUploadRequestDTO)
    case syncHealthKit(dto: HealthKitSyncRequestDTO)
    case getSyncStatus(syncId: String)
    case getUploadStatus(uploadId: String)
    case getProcessingStatus(id: UUID)
}

extension HealthDataEndpoint: Endpoint {
    var path: String {
        switch self {
        case .getMetrics:
            "/api/v1/health-data"
        case .uploadHealthKit:
            "/api/v1/healthkit"
        case .syncHealthKit:
            "/api/v1/healthkit/sync"
        case let .getSyncStatus(syncId):
            "/api/v1/healthkit/sync/\(syncId)"
        case let .getUploadStatus(uploadId):
            "/api/v1/healthkit/status/\(uploadId)"
        case let .getProcessingStatus(id):
            "/api/v1/health-data/processing/\(id.uuidString)"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .getMetrics, .getSyncStatus, .getUploadStatus, .getProcessingStatus:
            .get
        case .uploadHealthKit, .syncHealthKit:
            .post
        }
    }

    func body(encoder: JSONEncoder) throws -> Data? {
        switch self {
        case .getMetrics, .getSyncStatus, .getUploadStatus, .getProcessingStatus:
            nil
        case let .uploadHealthKit(dto):
            try encoder.encode(dto)
        case let .syncHealthKit(dto):
            try encoder.encode(dto)
        }
    }

    // We can extend this to handle query parameters.
    func asURLRequest(baseURL: URL, encoder: JSONEncoder) throws -> URLRequest {
        // First, create the basic request.
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try body(encoder: encoder)

        // Then, add query parameters if necessary.
        switch self {
        case let .getMetrics(page, limit):
            guard let url = request.url else {
                throw APIError.invalidURL
            }
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = [
                URLQueryItem(name: "page", value: "\(page)"),
                URLQueryItem(name: "limit", value: "\(limit)"),
            ]
            request.url = components?.url
        case .uploadHealthKit, .syncHealthKit, .getSyncStatus, .getUploadStatus, .getProcessingStatus:
            // These endpoints don't need query parameters
            break
        }

        return request
    }
}
