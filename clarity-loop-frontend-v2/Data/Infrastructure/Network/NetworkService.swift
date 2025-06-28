//
//  NetworkService.swift
//  clarity-loop-frontend-v2
//
//  Network service implementation
//

import Foundation
import ClarityDomain

/// Main network service implementation
public final class NetworkService: NetworkServiceProtocol {
    private let baseURL: URL
    private let session: URLSessionProtocol
    private let authService: AuthServiceProtocol
    private let tokenStorage: TokenStorageProtocol
    private let interceptors: [RequestInterceptor]
    
    /// Default headers applied to all requests
    private let defaultHeaders: [String: String]
    
    public init(
        baseURL: URL,
        session: URLSessionProtocol = URLSession.shared,
        authService: AuthServiceProtocol,
        tokenStorage: TokenStorageProtocol,
        interceptors: [RequestInterceptor] = []
    ) {
        self.baseURL = baseURL
        self.session = session
        self.authService = authService
        self.tokenStorage = tokenStorage
        self.interceptors = interceptors
        
        self.defaultHeaders = [
            "Accept": "application/json",
            "Content-Type": "application/json",
            "X-Platform": "iOS",
            "X-App-Version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        ]
    }
    
    public func request<T: Decodable>(
        _ endpoint: Endpoint,
        type: T.Type
    ) async throws -> T {
        let data = try await performRequest(endpoint)
        
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw NetworkError.decodingFailed(error.localizedDescription)
        }
    }
    
    public func request(_ endpoint: Endpoint) async throws -> Data {
        return try await performRequest(endpoint)
    }
    
    public func upload(
        _ endpoint: Endpoint,
        data: Data,
        progressHandler: ((Double) -> Void)?
    ) async throws -> Data {
        // TODO: Implement upload with progress
        fatalError("Upload not yet implemented")
    }
    
    public func download(
        _ endpoint: Endpoint,
        progressHandler: ((Double) -> Void)?
    ) async throws -> URL {
        // TODO: Implement download with progress
        fatalError("Download not yet implemented")
    }
    
    // MARK: - Private Methods
    
    private func performRequest(_ endpoint: Endpoint) async throws -> Data {
        // Build request
        var request = try buildRequest(for: endpoint)
        
        // Add authentication if required
        if endpoint.requiresAuth {
            request = try await addAuthentication(to: request)
        }
        
        // Apply interceptors
        for interceptor in interceptors {
            try await interceptor.intercept(&request)
        }
        
        // Execute request
        let (data, response) = try await session.data(for: request)
        
        // Validate response
        try validateResponse(response, data: data)
        
        return data
    }
    
    private func buildRequest(for endpoint: Endpoint) throws -> URLRequest {
        // Build URL with path
        guard let url = URL(string: endpoint.path, relativeTo: baseURL) else {
            throw NetworkError.invalidURL
        }
        
        // Add query items if present
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        if let queryItems = endpoint.queryItems {
            components?.queryItems = queryItems
        }
        
        guard let finalURL = components?.url else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: finalURL)
        request.httpMethod = endpoint.method.rawValue
        request.timeoutInterval = endpoint.timeout
        
        // Add default headers
        for (key, value) in defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add custom headers
        if let headers = endpoint.headers {
            for (key, value) in headers {
                request.setValue(value, forHTTPHeaderField: key)
            }
        }
        
        // Add body if present
        request.httpBody = endpoint.body
        
        return request
    }
    
    private func addAuthentication(to request: URLRequest) async throws -> URLRequest {
        var authenticatedRequest = request
        
        // Get token from storage
        guard let accessToken = try await tokenStorage.getAccessToken() else {
            throw NetworkError.unauthorized
        }
        
        // Add Authorization header
        authenticatedRequest.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        
        return authenticatedRequest
    }
    
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        switch httpResponse.statusCode {
        case 200...299:
            // Success
            return
            
        case 401:
            throw NetworkError.unauthorized
            
        case 403:
            throw NetworkError.forbidden
            
        case 404:
            throw NetworkError.notFound
            
        case 429:
            // Rate limited - check for Retry-After header
            let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                .flatMap { TimeInterval($0) }
            throw NetworkError.rateLimited(retryAfter: retryAfter)
            
        case 400...499:
            // Client error - try to parse error message
            let errorMessage = try? parseErrorMessage(from: data)
            throw NetworkError.serverError(
                statusCode: httpResponse.statusCode,
                message: errorMessage
            )
            
        case 500...599:
            // Server error
            let errorMessage = try? parseErrorMessage(from: data)
            throw NetworkError.serverError(
                statusCode: httpResponse.statusCode,
                message: errorMessage
            )
            
        default:
            throw NetworkError.unknown
        }
    }
    
    private func parseErrorMessage(from data: Data) throws -> String? {
        let errorResponse = try? JSONDecoder().decode(
            ErrorResponse.self,
            from: data
        )
        return errorResponse?.message ?? errorResponse?.error
    }
}

// MARK: - Error Response

private struct ErrorResponse: Decodable {
    let error: String?
    let message: String?
}