//
//  RequestBuilder.swift
//  clarity-loop-frontend-v2
//
//  Builds URLRequests from Endpoint configurations
//

import Foundation

/// Builder for constructing URLRequests
public struct RequestBuilder: Sendable {
    
    // MARK: - Properties
    
    private let baseURL: URL
    private let defaultHeaders: [String: String]
    
    // MARK: - Initialization
    
    public init(baseURL: URL, defaultHeaders: [String: String] = [:]) {
        self.baseURL = baseURL
        self.defaultHeaders = defaultHeaders
    }
    
    // MARK: - Public Methods
    
    /// Build URLRequest from Endpoint configuration
    public func buildRequest(from endpoint: Endpoint) throws -> URLRequest {
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
    
    /// Add authentication to request
    public func addAuthentication(
        to request: URLRequest,
        token: String
    ) -> URLRequest {
        var authenticatedRequest = request
        authenticatedRequest.setValue(
            "Bearer \(token)",
            forHTTPHeaderField: "Authorization"
        )
        return authenticatedRequest
    }
}