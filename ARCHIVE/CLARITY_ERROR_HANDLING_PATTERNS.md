# CLARITY Error Handling & Recovery Patterns

## Overview

This document provides comprehensive error handling patterns for every component of the CLARITY app, ensuring graceful degradation and recovery from all failure scenarios.

## Core Error Philosophy

1. **Never crash** - Handle all errors gracefully
2. **Always inform** - Users should understand what went wrong
3. **Provide recovery** - Every error should have a recovery path
4. **Log securely** - Never log PHI in error messages
5. **Fail safely** - Degrade functionality rather than break

## Complete Error Type Architecture

### Base Error Protocol

```swift
protocol ClarityError: LocalizedError {
    var code: String { get }
    var severity: ErrorSeverity { get }
    var isRecoverable: Bool { get }
    var userAction: String? { get }
    var technicalDetails: String { get }
    var shouldNotifyUser: Bool { get }
}

enum ErrorSeverity {
    case info
    case warning
    case error
    case critical
    
    var logLevel: OSLogType {
        switch self {
        case .info: return .info
        case .warning: return .default
        case .error: return .error
        case .critical: return .fault
        }
    }
}
```

### Network Errors

```swift
enum NetworkError: ClarityError {
    case noInternet
    case timeout(TimeInterval)
    case serverError(statusCode: Int, message: String?)
    case invalidResponse
    case decodingFailed(type: String, error: Error)
    case unauthorized
    case rateLimited(retryAfter: TimeInterval?)
    case certificatePinningFailed
    case requestCancelled
    
    var code: String {
        switch self {
        case .noInternet: return "NET001"
        case .timeout: return "NET002"
        case .serverError: return "NET003"
        case .invalidResponse: return "NET004"
        case .decodingFailed: return "NET005"
        case .unauthorized: return "NET006"
        case .rateLimited: return "NET007"
        case .certificatePinningFailed: return "NET008"
        case .requestCancelled: return "NET009"
        }
    }
    
    var severity: ErrorSeverity {
        switch self {
        case .noInternet, .timeout, .requestCancelled: return .warning
        case .serverError(let code, _):
            return code >= 500 ? .error : .warning
        case .unauthorized, .certificatePinningFailed: return .critical
        case .rateLimited: return .info
        default: return .error
        }
    }
    
    var isRecoverable: Bool {
        switch self {
        case .certificatePinningFailed, .unauthorized: return false
        default: return true
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .noInternet:
            return "No internet connection"
        case .timeout(let duration):
            return "Request timed out after \(Int(duration)) seconds"
        case .serverError(let code, let message):
            return message ?? "Server error (\(code))"
        case .invalidResponse:
            return "Invalid response from server"
        case .decodingFailed(let type, _):
            return "Failed to process \(type) data"
        case .unauthorized:
            return "Your session has expired"
        case .rateLimited(let retryAfter):
            if let retry = retryAfter {
                return "Too many requests. Try again in \(Int(retry)) seconds"
            }
            return "Too many requests. Please try again later"
        case .certificatePinningFailed:
            return "Security verification failed"
        case .requestCancelled:
            return "Request was cancelled"
        }
    }
    
    var userAction: String? {
        switch self {
        case .noInternet:
            return "Check your internet connection and try again"
        case .timeout:
            return "Check your connection and try again"
        case .serverError:
            return "Try again later or contact support"
        case .unauthorized:
            return "Please log in again"
        case .rateLimited:
            return "Wait a moment before trying again"
        case .certificatePinningFailed:
            return "Update the app or contact support"
        default:
            return "Try again"
        }
    }
}
```

### Health Data Errors

```swift
enum HealthDataError: ClarityError {
    case authorizationDenied(dataTypes: [String])
    case dataNotAvailable(dataType: String)
    case invalidDateRange(start: Date, end: Date)
    case syncInProgress
    case quotaExceeded(limit: Int)
    case corruptedData(recordId: String)
    case incompatibleFormat(expected: String, received: String)
    
    var code: String {
        switch self {
        case .authorizationDenied: return "HLT001"
        case .dataNotAvailable: return "HLT002"
        case .invalidDateRange: return "HLT003"
        case .syncInProgress: return "HLT004"
        case .quotaExceeded: return "HLT005"
        case .corruptedData: return "HLT006"
        case .incompatibleFormat: return "HLT007"
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .authorizationDenied(let types):
            let typeList = types.joined(separator: ", ")
            return "Permission denied for: \(typeList)"
        case .dataNotAvailable(let type):
            return "\(type) data is not available"
        case .invalidDateRange:
            return "Invalid date range selected"
        case .syncInProgress:
            return "Sync already in progress"
        case .quotaExceeded(let limit):
            return "Upload limit exceeded (\(limit) records)"
        case .corruptedData:
            return "Some health data appears corrupted"
        case .incompatibleFormat(let expected, let received):
            return "Expected \(expected) format, got \(received)"
        }
    }
}
```

### Authentication Errors

```swift
enum AuthError: ClarityError {
    case invalidCredentials
    case emailNotVerified
    case accountLocked(until: Date?)
    case passwordRequirementsNotMet([PasswordRequirement])
    case biometricFailed(BiometricError)
    case sessionExpired
    case mfaRequired
    case networkError(NetworkError)
    
    enum PasswordRequirement {
        case minLength(Int)
        case uppercase
        case lowercase
        case number
        case special
        
        var description: String {
            switch self {
            case .minLength(let length):
                return "At least \(length) characters"
            case .uppercase:
                return "One uppercase letter"
            case .lowercase:
                return "One lowercase letter"
            case .number:
                return "One number"
            case .special:
                return "One special character"
            }
        }
    }
    
    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Invalid email or password"
        case .emailNotVerified:
            return "Please verify your email"
        case .accountLocked(let until):
            if let date = until {
                let formatter = RelativeDateTimeFormatter()
                return "Account locked \(formatter.localizedString(for: date, relativeTo: Date()))"
            }
            return "Account is locked"
        case .passwordRequirementsNotMet(let requirements):
            let list = requirements.map(\.description).joined(separator: "\n• ")
            return "Password must have:\n• \(list)"
        case .biometricFailed(let error):
            return error.errorDescription
        case .sessionExpired:
            return "Your session has expired"
        case .mfaRequired:
            return "Additional verification required"
        case .networkError(let error):
            return error.errorDescription
        }
    }
}
```

### SwiftData Errors

```swift
enum DataError: ClarityError {
    case saveFailed(Error)
    case fetchFailed(entity: String, Error)
    case migrationFailed(from: String, to: String, Error)
    case constraintViolation(entity: String, constraint: String)
    case diskFull
    case databaseCorrupted
    case conflictDetected(local: Any, remote: Any)
    
    var code: String {
        switch self {
        case .saveFailed: return "DAT001"
        case .fetchFailed: return "DAT002"
        case .migrationFailed: return "DAT003"
        case .constraintViolation: return "DAT004"
        case .diskFull: return "DAT005"
        case .databaseCorrupted: return "DAT006"
        case .conflictDetected: return "DAT007"
        }
    }
}
```

## Error Handling Patterns

### 1. View-Level Error Handling

```swift
struct ErrorAwareView<Content: View>: View {
    let content: () -> Content
    @State private var currentError: (any ClarityError)?
    @State private var showingError = false
    
    var body: some View {
        content()
            .environment(\.reportError, ReportErrorAction { error in
                currentError = error
                showingError = true
            })
            .alert(
                "Error",
                isPresented: $showingError,
                presenting: currentError
            ) { error in
                if error.isRecoverable {
                    Button("Retry") {
                        // Retry action
                    }
                    Button("Cancel", role: .cancel) { }
                } else {
                    Button("OK") { }
                }
            } message: { error in
                VStack {
                    Text(error.errorDescription ?? "Unknown error")
                    if let action = error.userAction {
                        Text(action)
                            .font(.caption)
                    }
                }
            }
    }
}

// Environment key for error reporting
private struct ReportErrorKey: EnvironmentKey {
    static let defaultValue = ReportErrorAction { _ in }
}

extension EnvironmentValues {
    var reportError: ReportErrorAction {
        get { self[ReportErrorKey.self] }
        set { self[ReportErrorKey.self] = newValue }
    }
}

struct ReportErrorAction {
    let action: (any ClarityError) -> Void
    
    func callAsFunction(_ error: any ClarityError) {
        action(error)
    }
}
```

### 2. ViewModel Error Handling

```swift
@Observable
final class ResilientViewModel {
    private(set) var viewState: ViewState<Data> = .idle
    private(set) var retryCount = 0
    private let maxRetries = 3
    
    enum ViewState<T> {
        case idle
        case loading
        case success(T)
        case error(any ClarityError)
        
        var error: (any ClarityError)? {
            if case .error(let error) = self { return error }
            return nil
        }
    }
    
    func loadData() async {
        viewState = .loading
        
        do {
            let data = try await fetchDataWithRetry()
            await MainActor.run {
                viewState = .success(data)
                retryCount = 0
            }
        } catch let error as ClarityError {
            await MainActor.run {
                viewState = .error(error)
                logError(error)
            }
        } catch {
            await MainActor.run {
                viewState = .error(UnknownError(error))
            }
        }
    }
    
    private func fetchDataWithRetry() async throws -> Data {
        for attempt in 0..<maxRetries {
            do {
                return try await performFetch()
            } catch let error as NetworkError {
                if case .noInternet = error {
                    // Don't retry for no internet
                    throw error
                }
                
                if attempt < maxRetries - 1 {
                    // Exponential backoff
                    let delay = pow(2.0, Double(attempt))
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                
                throw error
            }
        }
        
        throw NetworkError.timeout(30)
    }
    
    private func logError(_ error: any ClarityError) {
        Logger.shared.log(
            level: error.severity.logLevel,
            "Error [\(error.code)]: \(error.technicalDetails)"
        )
        
        if error.severity == .critical {
            // Send to crash reporting
            CrashReporter.shared.record(error)
        }
    }
}
```

### 3. Network Layer Error Handling

```swift
final class ResilientNetworkClient {
    private let session: URLSession
    private let reachability = NetworkReachability()
    
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T {
        // Check internet connection first
        guard reachability.isConnected else {
            throw NetworkError.noInternet
        }
        
        do {
            let (data, response) = try await session.data(for: endpoint.urlRequest())
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Handle different status codes
            switch httpResponse.statusCode {
            case 200...299:
                return try decode(data, as: T.self)
                
            case 401:
                throw NetworkError.unauthorized
                
            case 429:
                let retryAfter = httpResponse.value(forHTTPHeaderField: "Retry-After")
                    .flatMap(TimeInterval.init)
                throw NetworkError.rateLimited(retryAfter: retryAfter)
                
            case 400...499:
                let errorMessage = try? JSONDecoder().decode(
                    ErrorResponse.self,
                    from: data
                ).message
                throw NetworkError.serverError(
                    statusCode: httpResponse.statusCode,
                    message: errorMessage
                )
                
            case 500...599:
                throw NetworkError.serverError(
                    statusCode: httpResponse.statusCode,
                    message: "Server error"
                )
                
            default:
                throw NetworkError.invalidResponse
            }
            
        } catch let error as URLError {
            switch error.code {
            case .timedOut:
                throw NetworkError.timeout(session.configuration.timeoutIntervalForRequest)
            case .cancelled:
                throw NetworkError.requestCancelled
            case .notConnectedToInternet:
                throw NetworkError.noInternet
            default:
                throw NetworkError.invalidResponse
            }
        }
    }
    
    private func decode<T: Decodable>(_ data: Data, as type: T.Type) throws -> T {
        do {
            return try JSONDecoder.clarityDecoder.decode(type, from: data)
        } catch {
            throw NetworkError.decodingFailed(
                type: String(describing: type),
                error: error
            )
        }
    }
}
```

### 4. Offline Queue Error Recovery

```swift
actor OfflineQueueManager {
    private var queue: [QueuedOperation] = []
    private var isProcessing = false
    
    struct QueuedOperation {
        let id: UUID
        let operation: () async throws -> Void
        let retryCount: Int
        let maxRetries: Int
        let createdAt: Date
    }
    
    func enqueue(_ operation: @escaping () async throws -> Void) {
        let queuedOp = QueuedOperation(
            id: UUID(),
            operation: operation,
            retryCount: 0,
            maxRetries: 3,
            createdAt: Date()
        )
        queue.append(queuedOp)
        
        Task {
            await processQueue()
        }
    }
    
    private func processQueue() async {
        guard !isProcessing, !queue.isEmpty else { return }
        
        isProcessing = true
        defer { isProcessing = false }
        
        while !queue.isEmpty {
            var operation = queue.removeFirst()
            
            do {
                try await operation.operation()
                // Success - operation completed
                
            } catch let error as NetworkError where error.isRecoverable {
                // Retry with backoff
                operation = QueuedOperation(
                    id: operation.id,
                    operation: operation.operation,
                    retryCount: operation.retryCount + 1,
                    maxRetries: operation.maxRetries,
                    createdAt: operation.createdAt
                )
                
                if operation.retryCount < operation.maxRetries {
                    // Re-queue with exponential backoff
                    let delay = pow(2.0, Double(operation.retryCount))
                    
                    Task {
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        queue.append(operation)
                        await processQueue()
                    }
                } else {
                    // Max retries reached
                    await handleFailedOperation(operation, error: error)
                }
                
            } catch {
                // Non-recoverable error
                await handleFailedOperation(operation, error: error)
            }
        }
    }
    
    private func handleFailedOperation(_ operation: QueuedOperation, error: Error) async {
        // Log failure
        Logger.shared.error("Operation \(operation.id) failed after \(operation.retryCount) retries: \(error)")
        
        // Notify user if needed
        if let clarityError = error as? ClarityError, clarityError.shouldNotifyUser {
            await NotificationManager.shared.notify(error: clarityError)
        }
    }
}
```

### 5. UI Error States

```swift
struct ErrorStateView: View {
    let error: any ClarityError
    let retry: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: iconName)
                .font(.system(size: 64))
                .foregroundColor(iconColor)
            
            VStack(spacing: 12) {
                Text(error.errorDescription ?? "Something went wrong")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                
                if let action = error.userAction {
                    Text(action)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            
            if error.isRecoverable, let retry = retry {
                Button(action: retry) {
                    Label("Try Again", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.borderedProminent)
            }
            
            if case .critical = error.severity {
                Button("Contact Support") {
                    openSupport()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private var iconName: String {
        switch error {
        case is NetworkError:
            return "wifi.exclamationmark"
        case is AuthError:
            return "person.crop.circle.badge.exclamationmark"
        case is HealthDataError:
            return "heart.text.square"
        default:
            return "exclamationmark.triangle"
        }
    }
    
    private var iconColor: Color {
        switch error.severity {
        case .info: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        }
    }
}
```

### 6. Global Error Handler

```swift
@MainActor
final class GlobalErrorHandler: ObservableObject {
    static let shared = GlobalErrorHandler()
    
    @Published private(set) var currentError: (any ClarityError)?
    @Published var showingError = false
    
    private var errorQueue: [any ClarityError] = []
    
    func handle(_ error: any ClarityError) {
        // Log error
        Logger.shared.log(
            level: error.severity.logLevel,
            "[\(error.code)] \(error.errorDescription ?? "Unknown error")"
        )
        
        // Handle based on severity
        switch error.severity {
        case .info:
            // Just log, don't show to user
            break
            
        case .warning:
            // Show briefly
            showToast(error)
            
        case .error:
            // Show alert
            queueError(error)
            
        case .critical:
            // Show immediately and report
            currentError = error
            showingError = true
            CrashReporter.shared.record(error)
        }
        
        // Special handling for specific errors
        if error is NetworkError {
            NetworkMonitor.shared.checkConnectivity()
        } else if let authError = error as? AuthError, case .sessionExpired = authError {
            Task {
                await SessionManager.shared.handleExpiredSession()
            }
        }
    }
    
    private func queueError(_ error: any ClarityError) {
        errorQueue.append(error)
        
        if currentError == nil {
            showNextError()
        }
    }
    
    private func showNextError() {
        guard !errorQueue.isEmpty else { return }
        
        currentError = errorQueue.removeFirst()
        showingError = true
    }
    
    func dismissCurrent() {
        showingError = false
        currentError = nil
        
        // Show next error if any
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showNextError()
        }
    }
}
```

## Error Recovery Strategies

### 1. Automatic Retry with Backoff

```swift
func withRetry<T>(
    maxAttempts: Int = 3,
    delay: TimeInterval = 1.0,
    multiplier: Double = 2.0,
    operation: () async throws -> T
) async throws -> T {
    var currentDelay = delay
    
    for attempt in 0..<maxAttempts {
        do {
            return try await operation()
        } catch let error as ClarityError where error.isRecoverable {
            if attempt == maxAttempts - 1 {
                throw error
            }
            
            try await Task.sleep(nanoseconds: UInt64(currentDelay * 1_000_000_000))
            currentDelay *= multiplier
        }
    }
    
    throw NetworkError.timeout(30)
}
```

### 2. Fallback to Cache

```swift
final class CachedDataLoader {
    private let cache = DataCache()
    private let network: NetworkingProtocol
    
    func loadData<T: Codable>(
        endpoint: Endpoint,
        cacheKey: String,
        maxAge: TimeInterval = 3600
    ) async throws -> T {
        do {
            // Try network first
            let data: T = try await network.request(endpoint)
            cache.store(data, for: cacheKey)
            return data
            
        } catch let error as NetworkError {
            // Try cache on network error
            if let cached: T = cache.retrieve(for: cacheKey, maxAge: maxAge) {
                // Log that we're using cached data
                Logger.shared.warning("Using cached data due to: \(error)")
                return cached
            }
            
            // No cache available
            throw error
        }
    }
}
```

### 3. Graceful Degradation

```swift
@Observable
final class DegradableViewModel {
    private(set) var features: Set<Feature> = Feature.allCases
    
    enum Feature: CaseIterable {
        case realTimeSync
        case aiInsights
        case patAnalysis
        case export
        
        var minimumRequirements: Set<Capability> {
            switch self {
            case .realTimeSync: return [.network, .websocket]
            case .aiInsights: return [.network, .premium]
            case .patAnalysis: return [.network, .premium, .computation]
            case .export: return [.storage]
            }
        }
    }
    
    enum Capability {
        case network
        case websocket
        case premium
        case computation
        case storage
    }
    
    func updateAvailableFeatures(capabilities: Set<Capability>) {
        features = Set(Feature.allCases.filter { feature in
            feature.minimumRequirements.isSubset(of: capabilities)
        })
    }
}
```

## Testing Error Scenarios

```swift
final class ErrorHandlingTests: XCTestCase {
    func testNetworkErrorRecovery() async throws {
        let mockNetwork = MockNetworkClient()
        let viewModel = TestViewModel(network: mockNetwork)
        
        // Simulate network error then success
        mockNetwork.responses = [
            .failure(NetworkError.timeout(30)),
            .failure(NetworkError.serverError(statusCode: 500, message: nil)),
            .success(TestData())
        ]
        
        await viewModel.loadData()
        
        // Should succeed after retries
        XCTAssertNotNil(viewModel.data)
        XCTAssertEqual(mockNetwork.requestCount, 3)
    }
    
    func testErrorPropagation() async throws {
        let expectation = XCTestExpectation(description: "Error handled")
        
        let errorHandler = TestErrorHandler { error in
            XCTAssertEqual(error.code, "NET001")
            expectation.fulfill()
        }
        
        let view = TestView()
            .environment(\.errorHandler, errorHandler)
        
        // Trigger error
        await view.triggerError()
        
        await fulfillment(of: [expectation], timeout: 1.0)
    }
}
```

## ⚠️ HUMAN INTERVENTION POINTS

1. **Error Alert Testing**: Requires visual verification in Xcode
2. **Crash Reporting**: Test with real device and crash reporting service
3. **Network Conditions**: Use Network Link Conditioner in Xcode
4. **Recovery Flows**: Manual testing of each recovery path

---

Remember: Every error is an opportunity to improve user experience. Handle them gracefully!