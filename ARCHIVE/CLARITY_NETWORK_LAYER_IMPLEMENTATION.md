# CLARITY Network Layer Implementation Guide

## Overview
This document provides the complete network layer implementation for CLARITY Pulse, including retry logic, request queuing, authentication handling, and comprehensive error management.

## Core Network Architecture

### Network Client Protocol

```swift
// NetworkClientProtocol.swift
protocol NetworkClientProtocol {
    func request<T: Decodable>(
        _ endpoint: Endpoint,
        type: T.Type
    ) async throws -> T
    
    func request(
        _ endpoint: Endpoint
    ) async throws -> Data
    
    func upload(
        _ endpoint: Endpoint,
        data: Data,
        progressHandler: ((Double) -> Void)?
    ) async throws -> Data
    
    func download(
        _ endpoint: Endpoint,
        progressHandler: ((Double) -> Void)?
    ) async throws -> URL
}
```

### Endpoint Configuration

```swift
// Endpoint.swift
struct Endpoint {
    let path: String
    let method: HTTPMethod
    let headers: [String: String]?
    let queryItems: [URLQueryItem]?
    let body: Data?
    let requiresAuth: Bool
    let timeout: TimeInterval
    let retryPolicy: RetryPolicy
    
    init(
        path: String,
        method: HTTPMethod = .get,
        headers: [String: String]? = nil,
        queryItems: [URLQueryItem]? = nil,
        body: Data? = nil,
        requiresAuth: Bool = true,
        timeout: TimeInterval = 30,
        retryPolicy: RetryPolicy = .default
    ) {
        self.path = path
        self.method = method
        self.headers = headers
        self.queryItems = queryItems
        self.body = body
        self.requiresAuth = requiresAuth
        self.timeout = timeout
        self.retryPolicy = retryPolicy
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}
```

## Network Client Implementation

### Main Network Client

```swift
// NetworkClient.swift
@Observable
final class NetworkClient: NetworkClientProtocol {
    private let session: URLSession
    private let authService: AuthServiceProtocol
    private let requestQueue: RequestQueue
    private let reachability: NetworkReachability
    
    // Configuration
    private let baseURL: URL
    private let defaultHeaders: [String: String]
    
    init(
        baseURL: URL,
        authService: AuthServiceProtocol,
        configuration: URLSessionConfiguration = .default
    ) {
        self.baseURL = baseURL
        self.authService = authService
        self.session = URLSession(configuration: configuration)
        self.requestQueue = RequestQueue()
        self.reachability = NetworkReachability()
        
        self.defaultHeaders = [
            "Accept": "application/json",
            "Content-Type": "application/json",
            "X-Platform": "iOS",
            "X-App-Version": Bundle.main.appVersion
        ]
    }
    
    func request<T: Decodable>(
        _ endpoint: Endpoint,
        type: T.Type
    ) async throws -> T {
        let data = try await performRequest(endpoint)
        return try JSONDecoder.clarityDecoder.decode(T.self, from: data)
    }
    
    func request(_ endpoint: Endpoint) async throws -> Data {
        return try await performRequest(endpoint)
    }
}
```

### Request Execution with Retry Logic

```swift
extension NetworkClient {
    private func performRequest(_ endpoint: Endpoint) async throws -> Data {
        // Check network availability
        guard reachability.isConnected else {
            // Queue for later if offline
            try await requestQueue.enqueue(endpoint)
            throw NetworkError.offline
        }
        
        // Build request
        var request = try buildRequest(for: endpoint)
        
        // Add authentication if required
        if endpoint.requiresAuth {
            request = try await addAuthentication(to: request)
        }
        
        // Execute with retry logic
        return try await executeWithRetry(
            request: request,
            policy: endpoint.retryPolicy
        )
    }
    
    private func executeWithRetry(
        request: URLRequest,
        policy: RetryPolicy
    ) async throws -> Data {
        var lastError: Error?
        var attemptCount = 0
        
        while attemptCount <= policy.maxAttempts {
            do {
                // Log attempt
                logNetworkRequest(request, attempt: attemptCount)
                
                // Execute request
                let (data, response) = try await session.data(for: request)
                
                // Validate response
                try validateResponse(response, data: data)
                
                // Log success
                logNetworkSuccess(request, data: data)
                
                return data
                
            } catch {
                lastError = error
                attemptCount += 1
                
                // Check if we should retry
                if shouldRetry(
                    error: error,
                    attempt: attemptCount,
                    policy: policy
                ) {
                    // Calculate delay
                    let delay = policy.delayForAttempt(attemptCount)
                    
                    // Log retry
                    logNetworkRetry(request, error: error, delay: delay)
                    
                    // Wait before retry
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    
                    // Refresh auth token if needed
                    if isAuthError(error) {
                        request = try await refreshAuthAndRebuildRequest(request)
                    }
                } else {
                    // No more retries
                    break
                }
            }
        }
        
        // All retries exhausted
        throw lastError ?? NetworkError.unknown
    }
}
```

### Retry Policy

```swift
// RetryPolicy.swift
struct RetryPolicy {
    let maxAttempts: Int
    let backoffStrategy: BackoffStrategy
    let retryableErrors: Set<Int>
    let shouldRetryOnTimeout: Bool
    
    static let `default` = RetryPolicy(
        maxAttempts: 3,
        backoffStrategy: .exponential(baseDelay: 1.0, maxDelay: 30.0),
        retryableErrors: [408, 429, 500, 502, 503, 504],
        shouldRetryOnTimeout: true
    )
    
    static let aggressive = RetryPolicy(
        maxAttempts: 5,
        backoffStrategy: .exponential(baseDelay: 0.5, maxDelay: 60.0),
        retryableErrors: [408, 429, 500, 502, 503, 504],
        shouldRetryOnTimeout: true
    )
    
    static let none = RetryPolicy(
        maxAttempts: 0,
        backoffStrategy: .none,
        retryableErrors: [],
        shouldRetryOnTimeout: false
    )
    
    func delayForAttempt(_ attempt: Int) -> TimeInterval {
        switch backoffStrategy {
        case .none:
            return 0
        case .constant(let delay):
            return delay
        case .linear(let baseDelay):
            return baseDelay * Double(attempt)
        case .exponential(let baseDelay, let maxDelay):
            let delay = baseDelay * pow(2.0, Double(attempt - 1))
            return min(delay, maxDelay)
        }
    }
}

enum BackoffStrategy {
    case none
    case constant(delay: TimeInterval)
    case linear(baseDelay: TimeInterval)
    case exponential(baseDelay: TimeInterval, maxDelay: TimeInterval)
}
```

### Request Queue for Offline Support

```swift
// RequestQueue.swift
@Observable
final class RequestQueue {
    private let modelContext: ModelContext
    private var isProcessing = false
    
    @Model
    final class QueuedRequest {
        let id: UUID
        let endpoint: Data // Encoded Endpoint
        let createdAt: Date
        var retryCount: Int
        var lastAttemptAt: Date?
        
        init(endpoint: Endpoint) throws {
            self.id = UUID()
            self.endpoint = try JSONEncoder().encode(endpoint)
            self.createdAt = Date()
            self.retryCount = 0
        }
    }
    
    func enqueue(_ endpoint: Endpoint) async throws {
        let queuedRequest = try QueuedRequest(endpoint: endpoint)
        modelContext.insert(queuedRequest)
        try modelContext.save()
    }
    
    func processQueue() async {
        guard !isProcessing else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        let descriptor = FetchDescriptor<QueuedRequest>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        
        do {
            let requests = try modelContext.fetch(descriptor)
            
            for request in requests {
                if let endpoint = try? JSONDecoder().decode(
                    Endpoint.self,
                    from: request.endpoint
                ) {
                    // Try to execute queued request
                    do {
                        _ = try await performRequest(endpoint)
                        
                        // Success - remove from queue
                        modelContext.delete(request)
                        try modelContext.save()
                    } catch {
                        // Failed - update retry count
                        request.retryCount += 1
                        request.lastAttemptAt = Date()
                        
                        // Remove if too many retries
                        if request.retryCount > 5 {
                            modelContext.delete(request)
                        }
                        
                        try modelContext.save()
                    }
                }
            }
        } catch {
            // Log queue processing error
        }
    }
}
```

### Authentication Handling

```swift
extension NetworkClient {
    private func addAuthentication(
        to request: URLRequest
    ) async throws -> URLRequest {
        var authenticatedRequest = request
        
        // Get valid token
        let token = try await authService.getValidToken()
        
        // Add auth header
        authenticatedRequest.setValue(
            "Bearer \(token)",
            forHTTPHeaderField: "Authorization"
        )
        
        return authenticatedRequest
    }
    
    private func refreshAuthAndRebuildRequest(
        _ request: URLRequest
    ) async throws -> URLRequest {
        // Force token refresh
        try await authService.refreshToken()
        
        // Rebuild request with new token
        return try await addAuthentication(to: request)
    }
    
    private func isAuthError(_ error: Error) -> Bool {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .unauthorized, .forbidden:
                return true
            default:
                return false
            }
        }
        
        if let urlError = error as? URLError {
            return urlError.code == .userAuthenticationRequired
        }
        
        return false
    }
}
```

### Error Handling

```swift
// NetworkError.swift
enum NetworkError: LocalizedError {
    case offline
    case invalidURL
    case invalidResponse
    case decodingFailed(Error)
    case unauthorized
    case forbidden
    case notFound
    case serverError(statusCode: Int, message: String?)
    case rateLimited(retryAfter: TimeInterval?)
    case timeout
    case cancelled
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .offline:
            return "No internet connection"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .unauthorized:
            return "Authentication required"
        case .forbidden:
            return "Access denied"
        case .notFound:
            return "Resource not found"
        case .serverError(let code, let message):
            return message ?? "Server error (code: \(code))"
        case .rateLimited(let retryAfter):
            if let retryAfter = retryAfter {
                return "Rate limited. Try again in \(Int(retryAfter)) seconds"
            }
            return "Rate limited. Please try again later"
        case .timeout:
            return "Request timed out"
        case .cancelled:
            return "Request cancelled"
        case .unknown:
            return "Unknown error occurred"
        }
    }
}
```

### Response Validation

```swift
extension NetworkClient {
    private func validateResponse(
        _ response: URLResponse,
        data: Data
    ) throws {
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

struct ErrorResponse: Decodable {
    let error: String?
    let message: String?
    let details: [String: Any]?
    
    enum CodingKeys: String, CodingKey {
        case error, message, details
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        error = try container.decodeIfPresent(String.self, forKey: .error)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        
        // Handle dynamic details
        if let detailsData = try? container.decode(Data.self, forKey: .details),
           let json = try? JSONSerialization.jsonObject(with: detailsData) as? [String: Any] {
            details = json
        } else {
            details = nil
        }
    }
}
```

## Upload/Download with Progress

### Upload Implementation

```swift
extension NetworkClient {
    func upload(
        _ endpoint: Endpoint,
        data: Data,
        progressHandler: ((Double) -> Void)?
    ) async throws -> Data {
        var request = try buildRequest(for: endpoint)
        
        // Set up upload task with progress
        let task = session.uploadTask(with: request, from: data)
        
        // Progress observation
        let progressObservation = task.progress.observe(\.fractionCompleted) { progress, _ in
            DispatchQueue.main.async {
                progressHandler?(progress.fractionCompleted)
            }
        }
        
        defer {
            progressObservation.invalidate()
        }
        
        // Execute upload
        return try await withCheckedThrowingContinuation { continuation in
            task.resume()
            
            // Handle completion
            URLSession.shared.dataTask(with: request) { data, response, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else if let data = data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: NetworkError.unknown)
                }
            }.resume()
        }
    }
}
```

### Download Implementation

```swift
extension NetworkClient {
    func download(
        _ endpoint: Endpoint,
        progressHandler: ((Double) -> Void)?
    ) async throws -> URL {
        let request = try buildRequest(for: endpoint)
        
        // Create download task
        let (localURL, response) = try await session.download(for: request)
        
        // Validate response
        try validateResponse(response, data: Data())
        
        // Move to permanent location
        let documentsPath = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        
        let fileName = response.suggestedFilename ?? UUID().uuidString
        let destinationURL = documentsPath.appendingPathComponent(fileName)
        
        try FileManager.default.moveItem(at: localURL, to: destinationURL)
        
        return destinationURL
    }
}
```

## Network Monitoring

```swift
// NetworkReachability.swift
import Network

@Observable
final class NetworkReachability {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "NetworkMonitor")
    
    private(set) var isConnected = true
    private(set) var isExpensive = false
    private(set) var connectionType: ConnectionType = .unknown
    
    init() {
        startMonitoring()
    }
    
    private func startMonitoring() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.isExpensive = path.isExpensive
                self?.connectionType = self?.getConnectionType(path) ?? .unknown
            }
        }
        
        monitor.start(queue: queue)
    }
    
    private func getConnectionType(_ path: NWPath) -> ConnectionType {
        if path.usesInterfaceType(.wifi) {
            return .wifi
        } else if path.usesInterfaceType(.cellular) {
            return .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            return .ethernet
        } else {
            return .unknown
        }
    }
    
    deinit {
        monitor.cancel()
    }
}

enum ConnectionType {
    case wifi
    case cellular
    case ethernet
    case unknown
}
```

## Request Interceptors

### Request Logging

```swift
// NetworkLogger.swift
struct NetworkLogger {
    static func logRequest(_ request: URLRequest, attempt: Int) {
        #if DEBUG
        print("""
        🌐 Network Request (Attempt \(attempt))
        URL: \(request.url?.absoluteString ?? "nil")
        Method: \(request.httpMethod ?? "nil")
        Headers: \(request.allHTTPHeaderFields ?? [:])
        """)
        
        if let body = request.httpBody,
           let json = try? JSONSerialization.jsonObject(with: body) {
            print("Body: \(json)")
        }
        #endif
    }
    
    static func logResponse(_ response: URLResponse?, data: Data?, error: Error?) {
        #if DEBUG
        if let httpResponse = response as? HTTPURLResponse {
            print("""
            ✅ Network Response
            Status: \(httpResponse.statusCode)
            Headers: \(httpResponse.allHeaderFields)
            """)
        }
        
        if let error = error {
            print("❌ Network Error: \(error)")
        }
        
        if let data = data,
           let json = try? JSONSerialization.jsonObject(with: data) {
            print("Response Body: \(json)")
        }
        #endif
    }
}
```

## Testing Network Layer

```swift
// MockNetworkClient.swift
final class MockNetworkClient: NetworkClientProtocol {
    var mockResponses: [String: Result<Data, Error>] = [:]
    var requestDelay: TimeInterval = 0
    var shouldSimulateOffline = false
    
    func request<T: Decodable>(
        _ endpoint: Endpoint,
        type: T.Type
    ) async throws -> T {
        if shouldSimulateOffline {
            throw NetworkError.offline
        }
        
        // Simulate network delay
        if requestDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(requestDelay * 1_000_000_000))
        }
        
        // Return mock response
        let key = "\(endpoint.method.rawValue):\(endpoint.path)"
        
        guard let result = mockResponses[key] else {
            throw NetworkError.notFound
        }
        
        switch result {
        case .success(let data):
            return try JSONDecoder().decode(T.self, from: data)
        case .failure(let error):
            throw error
        }
    }
}

// NetworkClientTests.swift
final class NetworkClientTests: XCTestCase {
    func test_request_withRetryableError_shouldRetry() async throws {
        // Given
        let mockAuth = MockAuthService()
        let client = NetworkClient(
            baseURL: URL(string: "https://api.test.com")!,
            authService: mockAuth
        )
        
        // Simulate server error that should retry
        var attemptCount = 0
        
        // When/Then - verify retry behavior
        do {
            _ = try await client.request(
                Endpoint(
                    path: "/test",
                    retryPolicy: .default
                )
            )
            XCTFail("Should have thrown error")
        } catch {
            XCTAssertEqual(attemptCount, 3) // Should retry 3 times
        }
    }
}
```

## Performance Optimization

### Request Deduplication

```swift
// RequestDeduplicator.swift
actor RequestDeduplicator {
    private var pendingRequests: [String: Task<Data, Error>] = [:]
    
    func deduplicate(
        key: String,
        request: @escaping () async throws -> Data
    ) async throws -> Data {
        // Check if request is already in progress
        if let existingTask = pendingRequests[key] {
            return try await existingTask.value
        }
        
        // Create new task
        let task = Task {
            defer { pendingRequests[key] = nil }
            return try await request()
        }
        
        pendingRequests[key] = task
        
        return try await task.value
    }
}
```

### Response Caching

```swift
// ResponseCache.swift
actor ResponseCache {
    private var cache: [String: CachedResponse] = [:]
    private let maxAge: TimeInterval = 300 // 5 minutes
    
    struct CachedResponse {
        let data: Data
        let timestamp: Date
    }
    
    func get(key: String) -> Data? {
        guard let cached = cache[key] else { return nil }
        
        // Check if expired
        if Date().timeIntervalSince(cached.timestamp) > maxAge {
            cache[key] = nil
            return nil
        }
        
        return cached.data
    }
    
    func set(key: String, data: Data) {
        cache[key] = CachedResponse(data: data, timestamp: Date())
    }
}
```

## ⚠️ Critical Implementation Notes

1. **Always use async/await** - No completion handlers
2. **Respect rate limits** - Parse Retry-After headers
3. **Queue offline requests** - Don't lose user data
4. **Refresh auth tokens** - Handle 401s gracefully
5. **Log sensitively** - No PHI in logs
6. **Test all error paths** - Network issues are common

---

✅ This network layer provides robust, testable networking with comprehensive error handling and offline support.