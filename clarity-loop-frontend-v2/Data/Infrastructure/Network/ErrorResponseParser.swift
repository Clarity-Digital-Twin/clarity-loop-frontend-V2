//
//  ErrorResponseParser.swift
//  clarity-loop-frontend-v2
//
//  Parses error responses from API
//

import Foundation

/// Parser for API error responses
public struct ErrorResponseParser: Sendable {
    
    // MARK: - Properties
    
    private let decoder: JSONDecoder
    
    // MARK: - Initialization
    
    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }
    
    // MARK: - Public Methods
    
    /// Parse error from HTTP response
    public func parseError(
        from response: HTTPURLResponse,
        data: Data?
    ) -> NetworkError {
        // First check status code
        switch response.statusCode {
        case 401:
            return .unauthorized
            
        case 403:
            return .forbidden
            
        case 404:
            return .notFound
            
        case 429:
            // Check for Retry-After header
            let retryAfter = response.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) }
            return .rateLimited(retryAfter: retryAfter)
            
        case 400...499:
            // Client error - try to parse error message
            let message = parseErrorMessage(from: data)
            return .serverError(
                statusCode: response.statusCode,
                message: message
            )
            
        case 500...599:
            // Server error
            let message = parseErrorMessage(from: data)
            return .serverError(
                statusCode: response.statusCode,
                message: message
            )
            
        default:
            return .unknown
        }
    }
    
    // MARK: - Private Methods
    
    private func parseErrorMessage(from data: Data?) -> String? {
        guard let data = data, !data.isEmpty else {
            return nil
        }
        
        // Try multiple error response formats
        
        // Format 1: { "error": "message" }
        if let response = try? decoder.decode(SimpleErrorResponse.self, from: data) {
            return response.error
        }
        
        // Format 2: { "message": "message" }
        if let response = try? decoder.decode(MessageErrorResponse.self, from: data) {
            return response.message
        }
        
        // Format 3: { "errors": [{ "message": "message" }] }
        if let response = try? decoder.decode(DetailedErrorResponse.self, from: data),
           let firstError = response.errors.first {
            return firstError.message
        }
        
        // Format 4: { "detail": "message" }
        if let response = try? decoder.decode(DetailErrorResponse.self, from: data) {
            return response.detail
        }
        
        // Format 5: Plain text
        if let message = String(data: data, encoding: .utf8) {
            // Check if it's not JSON
            if !message.trimmingCharacters(in: .whitespaces).hasPrefix("{") {
                return message
            }
        }
        
        return nil
    }
}

// MARK: - Error Response Models

private struct SimpleErrorResponse: Decodable {
    let error: String
}

private struct MessageErrorResponse: Decodable {
    let message: String
}

private struct DetailedErrorResponse: Decodable {
    struct ErrorDetail: Decodable {
        let message: String
        let field: String?
        let code: String?
    }
    
    let errors: [ErrorDetail]
}

private struct DetailErrorResponse: Decodable {
    let detail: String
}