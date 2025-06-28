//
//  NetworkServiceProtocol.swift
//  clarity-loop-frontend-v2
//
//  Network service protocol for making API requests
//

import Foundation

/// Protocol defining network service capabilities
public protocol NetworkServiceProtocol: Sendable {
    /// Perform a network request and decode the response
    /// - Parameters:
    ///   - endpoint: The endpoint configuration
    ///   - type: The type to decode the response into
    /// - Returns: The decoded response
    func request<T: Decodable>(
        _ endpoint: Endpoint,
        type: T.Type
    ) async throws -> T
    
    /// Perform a network request returning raw data
    /// - Parameter endpoint: The endpoint configuration
    /// - Returns: The raw response data
    func request(
        _ endpoint: Endpoint
    ) async throws -> Data
    
    /// Upload data with optional progress reporting
    /// - Parameters:
    ///   - endpoint: The endpoint configuration
    ///   - data: The data to upload
    ///   - progressHandler: Optional progress callback
    /// - Returns: The response data
    func upload(
        _ endpoint: Endpoint,
        data: Data,
        progressHandler: ((Double) -> Void)?
    ) async throws -> Data
    
    /// Download data with optional progress reporting
    /// - Parameters:
    ///   - endpoint: The endpoint configuration
    ///   - progressHandler: Optional progress callback
    /// - Returns: The local URL of the downloaded file
    func download(
        _ endpoint: Endpoint,
        progressHandler: ((Double) -> Void)?
    ) async throws -> URL
}

/// Request interceptor protocol
public protocol RequestInterceptor: Sendable {
    func intercept(_ request: inout URLRequest) async throws
}