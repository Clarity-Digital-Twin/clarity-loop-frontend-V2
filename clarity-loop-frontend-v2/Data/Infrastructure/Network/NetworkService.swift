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
    private let session: URLSessionProtocol
    private let authService: AuthServiceProtocol
    private let tokenStorage: TokenStorageProtocol
    private let interceptors: [RequestInterceptor]
    private let requestBuilder: RequestBuilder
    private let retryStrategy: RetryStrategy
    private let errorParser: ErrorResponseParser
    
    public init(
        baseURL: URL,
        session: URLSessionProtocol = URLSession.shared,
        authService: AuthServiceProtocol,
        tokenStorage: TokenStorageProtocol,
        interceptors: [RequestInterceptor] = [],
        retryStrategy: RetryStrategy = ExponentialBackoffRetryStrategy()
    ) {
        self.session = session
        self.authService = authService
        self.tokenStorage = tokenStorage
        self.interceptors = interceptors
        self.retryStrategy = retryStrategy
        self.errorParser = ErrorResponseParser()
        
        let defaultHeaders = [
            "Accept": "application/json",
            "Content-Type": "application/json",
            "X-Platform": "iOS",
            "X-App-Version": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        ]
        
        self.requestBuilder = RequestBuilder(
            baseURL: baseURL,
            defaultHeaders: defaultHeaders
        )
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
        // Create multipart form data request
        var request = try requestBuilder.buildRequest(from: endpoint)
        
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        // Build multipart body
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"upload.dat\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        // Perform upload with progress tracking
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
        // Report completion
        progressHandler?(1.0)
        
        try validateResponse(response, data: responseData)
        return responseData
    }
    
    public func download(
        _ endpoint: Endpoint,
        progressHandler: ((Double) -> Void)?
    ) async throws -> URL {
        let request = try requestBuilder.buildRequest(from: endpoint)
        
        // Create download task
        let (tempURL, response) = try await URLSession.shared.download(for: request)
        
        // Report completion
        progressHandler?(1.0)
        
        // Validate response
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw NetworkError.serverError(statusCode: httpResponse.statusCode, message: "Download failed")
        }
        
        // Move to permanent location
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = endpoint.path.components(separatedBy: "/").last ?? "download"
        let destinationURL = documentsPath.appendingPathComponent(fileName)
        
        try? FileManager.default.removeItem(at: destinationURL)
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)
        
        return destinationURL
    }
    
    // MARK: - Private Methods
    
    private func performRequest(_ endpoint: Endpoint) async throws -> Data {
        var lastError: Error?
        
        let maxAttempts = 3 // Default retry limit
        
        for attempt in 0..<maxAttempts {
            do {
                // Build request
                var request = try requestBuilder.buildRequest(from: endpoint)
                
                // Add authentication if required
                if endpoint.requiresAuth {
                    guard let accessToken = try await tokenStorage.getAccessToken() else {
                        throw NetworkError.unauthorized
                    }
                    request = requestBuilder.addAuthentication(to: request, token: accessToken)
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
            } catch {
                lastError = error
                
                // Check if we should retry
                let decision = retryStrategy.shouldRetry(for: error, attempt: attempt)
                
                switch decision {
                case .retry(let delay):
                    // Wait before retrying
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                    
                case .doNotRetry:
                    throw error
                }
            }
        }
        
        // Should never reach here, but throw last error if we do
        throw lastError ?? NetworkError.unknown
    }
    
    private func validateResponse(_ response: URLResponse, data: Data) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.invalidResponse
        }
        
        // Success responses don't need error parsing
        guard httpResponse.statusCode < 200 || httpResponse.statusCode >= 300 else {
            return
        }
        
        // Parse error using ErrorResponseParser
        throw errorParser.parseError(from: httpResponse, data: data)
    }
}
