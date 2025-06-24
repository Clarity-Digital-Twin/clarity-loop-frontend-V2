import Combine
import Foundation

/// Modern API Service with async/await, Combine support, and automatic retry/caching
@MainActor
final class APIService: ObservableObject {
    // MARK: - Properties

    static var shared: APIService?

    static func configure(
        apiClient: APIClientProtocol,
        authService: AuthServiceProtocol,
        offlineQueue: OfflineQueueManagerProtocol
    ) {
        shared = APIService(
            apiClient: apiClient,
            authService: authService,
            offlineQueue: offlineQueue
        )
    }

    private let apiClient: APIClientProtocol
    private let authService: AuthServiceProtocol
    private let offlineQueue: OfflineQueueManagerProtocol

    private var cancellables = Set<AnyCancellable>()
    private let responseCache = NSCache<NSString, CachedResponse>()

    // MARK: - Configuration

    private let maxRetries = 3
    private let retryDelay: TimeInterval = 1.0
    private let cacheExpirationInterval: TimeInterval = 300 // 5 minutes

    // MARK: - Initialization

    init(
        apiClient: APIClientProtocol,
        authService: AuthServiceProtocol,
        offlineQueue: OfflineQueueManagerProtocol
    ) {
        self.apiClient = apiClient
        self.authService = authService
        self.offlineQueue = offlineQueue

        setupCachePolicy()
        observeNetworkChanges()
    }

    // MARK: - Public Methods

    /// Execute API request with automatic retry and caching
    func execute<T: Decodable>(
        _ endpoint: APIEndpoint,
        cachePolicy: CachePolicy = .networkFirst,
        retryPolicy: RetryPolicy = .standard
    ) async throws -> T {
        // Check cache first if applicable
        if let cached: T = getCachedResponse(for: endpoint, policy: cachePolicy) {
            return cached
        }

        // Execute with retry
        let response: T = try await executeWithRetry(endpoint, policy: retryPolicy)

        return response
    }

    /// Execute API request with caching support for Codable responses
    func executeWithCaching<T: Codable>(
        _ endpoint: APIEndpoint,
        cachePolicy: CachePolicy = .networkFirst,
        retryPolicy: RetryPolicy = .standard
    ) async throws -> T {
        // Check cache first if applicable
        if let cached: T = getCachedResponse(for: endpoint, policy: cachePolicy) {
            return cached
        }

        // Execute with retry
        let response: T = try await executeWithRetry(endpoint, policy: retryPolicy)

        // Cache successful response
        cacheResponse(response, for: endpoint)

        return response
    }

    /// Execute API request that returns no content
    func executeVoid(
        _ endpoint: APIEndpoint,
        retryPolicy: RetryPolicy = .standard
    ) async throws {
        try await executeWithRetry(endpoint, policy: retryPolicy) as Void
    }

    /// Upload data with progress tracking
    func upload<T: Decodable>(
        _ endpoint: APIEndpoint,
        data: Data,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> T {
        // TODO: Implement multipart upload with progress
        try await execute(endpoint)
    }

    /// Download data with progress tracking
    func download(
        _ endpoint: APIEndpoint,
        progressHandler: ((Double) -> Void)? = nil
    ) async throws -> Data {
        // TODO: Implement download with progress
        throw APIError.notImplemented
    }

    /// Batch execute multiple requests
    func batch<T: Decodable>(
        _ endpoints: [APIEndpoint]
    ) async throws -> [Result<T, Error>] {
        try await withThrowingTaskGroup(of: (Int, Result<T, Error>).self) { group in
            for (index, endpoint) in endpoints.enumerated() {
                group.addTask {
                    do {
                        let result: T = try await self.execute(endpoint)
                        return (index, .success(result))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }

            var results = [Result<T, Error>?](repeating: nil, count: endpoints.count)
            for try await (index, result) in group {
                results[index] = result
            }

            return results.compactMap { $0 }
        }
    }

    // MARK: - Combine Publishers

    /// Create a publisher for an API request
    func publisher<T: Decodable>(
        for endpoint: APIEndpoint,
        cachePolicy: CachePolicy = .networkFirst
    ) -> AnyPublisher<T, Error> {
        Future<T, Error> { promise in
            Task {
                do {
                    let result: T = try await self.execute(endpoint, cachePolicy: cachePolicy)
                    promise(.success(result))
                } catch {
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }

    // MARK: - Private Methods

    private func executeWithRetry<T>(
        _ endpoint: APIEndpoint,
        policy: RetryPolicy
    ) async throws -> T {
        var lastError: Error?
        let maxAttempts = policy == .none ? 1 : maxRetries

        for attempt in 0..<maxAttempts {
            do {
                return try await performRequest(endpoint)
            } catch {
                lastError = error

                // Don't retry certain errors
                if !shouldRetry(error: error, policy: policy) {
                    throw error
                }

                // Wait before retrying
                if attempt < maxAttempts - 1 {
                    let delay = retryDelay * pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                }
            }
        }

        throw lastError ?? APIError.unknown(NSError())
    }

    private func performRequest<T>(_ endpoint: APIEndpoint) async throws -> T {
        // APIService is deprecated - all calls should go through BackendAPIClient directly
        // This routing never worked because endpoints don't conform to APIEndpoint
        throw APIError.notImplemented
    }

    // Removed broken endpoint handlers - use BackendAPIClient directly

    private func shouldRetry(error: Error, policy: RetryPolicy) -> Bool {
        guard policy != .none else { return false }

        if let apiError = error as? APIError {
            switch apiError {
            case .networkError:
                return true
            case let .serverError(code, _) where code >= 500:
                return true
            case .unauthorized where policy == .includeAuth:
                return true
            default:
                return false
            }
        }

        return false
    }

    // MARK: - Caching

    private func setupCachePolicy() {
        responseCache.countLimit = 100
        responseCache.totalCostLimit = 50 * 1024 * 1024 // 50MB
    }

    private func getCachedResponse<T: Decodable>(
        for endpoint: APIEndpoint,
        policy: CachePolicy
    ) -> T? {
        guard policy != .networkOnly else { return nil }

        let key = cacheKey(for: endpoint)
        guard let cached = responseCache.object(forKey: key as NSString) else { return nil }

        // Check expiration
        if cached.expirationDate < Date(), policy != .cacheOnly {
            responseCache.removeObject(forKey: key as NSString)
            return nil
        }

        return try? JSONDecoder().decode(T.self, from: cached.data)
    }

    private func cacheResponse(_ response: some Encodable, for endpoint: APIEndpoint) {
        guard endpoint.method == "GET" else { return } // Only cache GET requests

        do {
            let data = try JSONEncoder().encode(response)
            let cached = CachedResponse(
                data: data,
                expirationDate: Date().addingTimeInterval(cacheExpirationInterval)
            )

            let key = cacheKey(for: endpoint)
            responseCache.setObject(cached, forKey: key as NSString)
        } catch {
            print("Failed to cache response: \(error)")
        }
    }

    private func cacheKey(for endpoint: APIEndpoint) -> String {
        "\(endpoint.method):\(endpoint.path)"
    }

    // MARK: - Network Monitoring

    private func observeNetworkChanges() {
        // TODO: Implement network reachability monitoring
        // When network becomes available, process offline queue
    }
}

// MARK: - Supporting Types

enum CachePolicy {
    case networkFirst // Try network, fallback to cache
    case cacheFirst // Try cache, fallback to network
    case networkOnly // Always use network
    case cacheOnly // Only use cache
}

enum RetryPolicy {
    case none
    case standard // Retry network and 5xx errors
    case includeAuth // Also retry 401 errors
}

private class CachedResponse: NSObject {
    let data: Data
    let expirationDate: Date

    init(data: Data, expirationDate: Date) {
        self.data = data
        self.expirationDate = expirationDate
    }
}

// MARK: - APIEndpoint Protocol

protocol APIEndpoint {
    var path: String { get }
    var method: String { get }
    var headers: [String: String]? { get }
    var body: Data? { get }
}
