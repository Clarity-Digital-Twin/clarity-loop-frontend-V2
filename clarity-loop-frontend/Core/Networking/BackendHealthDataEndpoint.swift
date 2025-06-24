import Foundation

enum BackendHealthDataEndpoint {
    case upload(dto: BackendHealthDataUpload)
}

extension BackendHealthDataEndpoint: Endpoint {
    var path: String {
        switch self {
        case .upload:
            "/api/v1/health-data/upload"
        }
    }

    var method: HTTPMethod {
        switch self {
        case .upload:
            .post
        }
    }

    func body(encoder: JSONEncoder) throws -> Data? {
        switch self {
        case let .upload(dto):
            try encoder.encode(dto)
        }
    }
}
