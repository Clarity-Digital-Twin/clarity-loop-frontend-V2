//
//  URLSessionProtocol.swift
//  clarity-loop-frontend-v2
//
//  Protocol for URL session abstraction
//

import Foundation

/// Protocol for URL session abstraction
public protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

/// URLSession conformance to URLSessionProtocol
extension URLSession: URLSessionProtocol {}
