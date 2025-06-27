//
//  NetworkClient.swift
//  clarity-loop-frontend-v2
//
//  Concrete implementation of network client for API communication
//

import Foundation
import ClarityDomain

/// URLSession protocol for dependency injection
public protocol URLSessionProtocol: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionProtocol {}

/// Protocol for network client
protocol NetworkClientProtocol: APIClientProtocol {
    init(session: URLSessionProtocol, baseURL: URL)
}

/// Concrete implementation of network client
public final class NetworkClient: Sendable {
    
    private let session: URLSessionProtocol
    private let baseURL: URL
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    
    public init(
        session: URLSessionProtocol = URLSession.shared,
        baseURL: URL = URL(string: "https://clarity.novamindnyc.com")!
    ) {
        self.session = session
        self.baseURL = baseURL
        
        // Configure decoder for API date format
        self.decoder = JSONDecoder()
        self.decoder.dateDecodingStrategy = .iso8601
        
        // Configure encoder for API date format
        self.encoder = JSONEncoder()
        self.encoder.dateEncodingStrategy = .iso8601
    }
    
    public func get<T: Decodable>(
        _ endpoint: String,
        parameters: [String: String]?
    ) async throws -> T {
        let request = try buildRequest(
            path: endpoint,
            method: "GET",
            parameters: parameters,
            body: nil as Data?
        )
        
        return try await performRequest(request)
    }
    
    public func post<T: Decodable, U: Encodable>(
        _ endpoint: String,
        body: U
    ) async throws -> T {
        let request = try buildRequest(
            path: endpoint,
            method: "POST",
            parameters: nil,
            body: body
        )
        
        return try await performRequest(request)
    }
    
    public func put<T: Decodable, U: Encodable>(
        _ endpoint: String,
        body: U
    ) async throws -> T {
        let request = try buildRequest(
            path: endpoint,
            method: "PUT",
            parameters: nil,
            body: body
        )
        
        return try await performRequest(request)
    }
    
    public func delete<T: Decodable>(
        _ endpoint: String
    ) async throws -> T {
        let request = try buildRequest(
            path: endpoint,
            method: "DELETE",
            parameters: nil,
            body: nil as Data?
        )
        
        return try await performRequest(request)
    }
    
    // MARK: - Private Methods
    
    private func buildRequest<B: Encodable>(
        path: String,
        method: String,
        parameters: [String: String]?,
        body: B?
    ) throws -> URLRequest {
        // Build URL with path
        let url = baseURL.appendingPathComponent(path)
        
        // Add query parameters if provided
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)!
        if let parameters = parameters {
            components.queryItems = parameters.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        
        guard let finalURL = components.url else {
            throw NetworkError.unknown
        }
        
        // Create request
        var request = URLRequest(url: finalURL)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        // Add body if provided
        if let body = body {
            request.httpBody = try encoder.encode(body)
        }
        
        return request
    }
    
    private func performRequest<T: Decodable>(_ request: URLRequest) async throws -> T {
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.unknown
            }
            
            // Check status code
            switch httpResponse.statusCode {
            case 200...299:
                // Success - decode response
                do {
                    return try decoder.decode(T.self, from: data)
                } catch {
                    throw NetworkError.decodingFailed(error.localizedDescription)
                }
                
            case 401:
                throw NetworkError.unauthorized
                
            case 403:
                throw NetworkError.forbidden
                
            case 404:
                throw NetworkError.notFound
                
            case 500...599:
                throw NetworkError.serverError
                
            default:
                throw NetworkError.unknown
            }
            
        } catch let error as URLError {
            if error.code == .notConnectedToInternet {
                throw NetworkError.noConnection
            }
            throw NetworkError.unknown
            
        } catch let error as NetworkError {
            throw error
            
        } catch {
            throw NetworkError.unknown
        }
    }
}

// MARK: - Conformance to APIClientProtocol

extension NetworkClient: APIClientProtocol {
    public func delete<T: Identifiable>(
        type: T.Type,
        id: T.ID
    ) async throws {
        let _: VoidResponse = try await delete("/api/v1/\(String(describing: type).lowercased())s/\(id)")
    }
}

// MARK: - Conformance to NetworkClientProtocol

extension NetworkClient: NetworkClientProtocol {
    // The protocol conformance is satisfied by the initializer and APIClientProtocol methods
}

// MARK: - Helper Types

private struct VoidResponse: Decodable {}