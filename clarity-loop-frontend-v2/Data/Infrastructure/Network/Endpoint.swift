//
//  Endpoint.swift
//  clarity-loop-frontend-v2
//
//  Endpoint configuration for network requests
//

import Foundation

/// HTTP methods
public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

/// Endpoint configuration for network requests
public struct Endpoint: Sendable {
    public let path: String
    public let method: HTTPMethod
    public let headers: [String: String]?
    public let queryItems: [URLQueryItem]?
    public let body: Data?
    public let requiresAuth: Bool
    public let timeout: TimeInterval
    
    public init(
        path: String,
        method: HTTPMethod = .get,
        headers: [String: String]? = nil,
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil,
        requiresAuth: Bool = true,
        timeout: TimeInterval = 30
    ) {
        self.path = path
        self.method = method
        self.headers = headers
        self.queryItems = queryItems
        self.body = body
        self.requiresAuth = requiresAuth
        self.timeout = timeout
    }
}