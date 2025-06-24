import Amplify
import AWSCognitoAuthPlugin
import AWSPluginsCore
import Combine
import Foundation
import Network
import SwiftData

/// Enhanced offline queue manager with comprehensive operation handling
@MainActor
final class EnhancedOfflineQueueManager: ObservableObject {
    // MARK: - Properties

    static let shared = EnhancedOfflineQueueManager()

    @Published private(set) var queueStatus: QueueStatus = .idle
    @Published private(set) var pendingOperations: [OfflineOperation] = []
    @Published private(set) var failedOperations: [OfflineOperation] = []
    @Published private(set) var syncProgress = SyncProgress()
    @Published private(set) var isNetworkAvailable = true

    private let modelContext: ModelContext
    private let apiClient: APIClientProtocol
    private let healthRepository: HealthRepository
    private let insightRepository: AIInsightRepository
    private let profileRepository: UserProfileRepository
    private let patRepository: PATAnalysisRepository

    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.clarity.offlinequeue.monitor")
    private let processingQueue = DispatchQueue(label: "com.clarity.offlinequeue.processing", attributes: .concurrent)

    private var cancellables = Set<AnyCancellable>()
    private var processingTask: Task<Void, Never>?
    private var operationHandlers: [OperationType: OperationHandler] = [:]

    // MARK: - Configuration

    private let batchSize = 20
    private let maxConcurrentOperations = 5
    private let retryStrategy = ExponentialBackoffRetryStrategy()

    // MARK: - Initialization

    private init() {
        // Create a model container for offline operations
        do {
            let container = try SwiftDataConfigurator.shared.createModelContainer()
            self.modelContext = container.mainContext
        } catch {
            fatalError("Failed to create model container: \(error)")
        }

        // Create API client with token provider
        let tokenProvider: () async -> String? = {
            do {
                let session = try await Amplify.Auth.fetchAuthSession()
                if let cognitoSession = session as? AuthCognitoTokensProvider {
                    let tokens = try cognitoSession.getCognitoTokens().get()
                    return tokens.idToken
                }
                return nil
            } catch {
                return nil
            }
        }

        guard let apiClient = BackendAPIClient(tokenProvider: tokenProvider) else {
            fatalError("Failed to create API client")
        }
        self.apiClient = apiClient

        self.healthRepository = HealthRepository(modelContext: modelContext)
        self.insightRepository = AIInsightRepository(modelContext: modelContext)
        self.profileRepository = UserProfileRepository(modelContext: modelContext)
        self.patRepository = PATAnalysisRepository(modelContext: modelContext)

        setupOperationHandlers()
        setupNetworkMonitoring()
        loadPendingOperations()
    }

    // MARK: - Public Methods

    /// Queue a new operation
    func queueOperation(_ operation: OfflineOperation) async {
        pendingOperations.append(operation)
        await persistOperation(operation)

        // Update stats
        syncProgress.totalOperations = pendingOperations.count

        // Try immediate processing if online
        if isNetworkAvailable, queueStatus == .idle {
            await processQueue()
        }
    }

    /// Queue multiple operations with priority ordering
    func queueBatch(_ operations: [OfflineOperation]) async {
        // Sort by priority
        let sorted = operations.sorted { $0.priority > $1.priority }
        pendingOperations.append(contentsOf: sorted)

        // Persist all
        for operation in sorted {
            await persistOperation(operation)
        }

        syncProgress.totalOperations = pendingOperations.count

        if isNetworkAvailable, queueStatus == .idle {
            await processQueue()
        }
    }

    /// Process pending operations
    func processQueue() async {
        guard queueStatus != .processing else { return }
        guard isNetworkAvailable else {
            queueStatus = .waitingForNetwork
            return
        }

        queueStatus = .processing
        syncProgress.reset()
        syncProgress.totalOperations = pendingOperations.count

        defer {
            queueStatus = pendingOperations.isEmpty ? .idle : .partial
        }

        // Group operations by type for efficient processing
        let groupedOperations = Dictionary(grouping: pendingOperations) { $0.type }

        for (type, operations) in groupedOperations {
            guard let handler = operationHandlers[type] else { continue }

            // Process in batches
            for batch in operations.chunked(into: batchSize) {
                await processBatch(batch, handler: handler)
            }
        }

        // Clean up completed operations
        await cleanupCompletedOperations()
    }

    /// Retry all failed operations
    func retryFailedOperations() async {
        let toRetry = failedOperations
        failedOperations.removeAll()

        for operation in toRetry {
            operation.reset()
            await queueOperation(operation)
        }
    }

    /// Cancel specific operation
    func cancelOperation(_ operation: OfflineOperation) async {
        pendingOperations.removeAll { $0.id == operation.id }
        await removePersistedOperation(operation)
        syncProgress.totalOperations = pendingOperations.count
    }

    /// Clear entire queue
    func clearQueue() async {
        processingTask?.cancel()
        pendingOperations.removeAll()
        failedOperations.removeAll()
        await clearPersistedOperations()
        syncProgress.reset()
        queueStatus = .idle
    }

    /// Get queue statistics
    func getQueueStats() -> QueueStatistics {
        QueueStatistics(
            pendingCount: pendingOperations.count,
            failedCount: failedOperations.count,
            byType: Dictionary(grouping: pendingOperations) { $0.type }
                .mapValues { $0.count },
            oldestOperation: pendingOperations.min { $0.timestamp < $1.timestamp },
            estimatedSize: estimateQueueSize()
        )
    }

    // MARK: - Private Methods

    private func setupOperationHandlers() {
        operationHandlers = [
            .healthDataUpload: HealthDataOperationHandler(
                healthRepository: healthRepository,
                apiClient: apiClient
            ),
            .insightRequest: InsightOperationHandler(
                insightRepository: insightRepository,
                apiClient: apiClient
            ),
            .profileUpdate: ProfileOperationHandler(
                profileRepository: profileRepository,
                apiClient: apiClient
            ),
            .patSubmission: PATOperationHandler(
                patRepository: patRepository,
                apiClient: apiClient
            ),
            .syncData: SyncOperationHandler(
                modelContext: modelContext,
                apiClient: apiClient
            ),
            .deleteData: DeleteOperationHandler(
                modelContext: modelContext,
                apiClient: apiClient
            ),
        ]
    }

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor [weak self] in
                let wasOffline = self?.isNetworkAvailable == false
                self?.isNetworkAvailable = path.status == .satisfied

                if wasOffline, self?.isNetworkAvailable == true {
                    // Network recovered, process queue
                    await self?.processQueue()
                } else if self?.isNetworkAvailable == false {
                    self?.queueStatus = .waitingForNetwork
                }
            }
        }
        networkMonitor.start(queue: monitorQueue)

        // Periodic queue processing
        Timer.publish(every: 300, on: .main, in: .common) // Every 5 minutes
            .autoconnect()
            .sink { [weak self] _ in
                Task {
                    await self?.processQueue()
                }
            }
            .store(in: &cancellables)
    }

    private func processBatch(_ batch: [OfflineOperation], handler: OperationHandler) async {
        await withTaskGroup(of: OperationResult.self) { group in
            // Limit concurrent operations
            let semaphore = AsyncSemaphore(value: maxConcurrentOperations)

            for operation in batch {
                group.addTask {
                    await semaphore.wait()
                    defer {
                        Task {
                            await semaphore.signal()
                        }
                    }

                    return await self.processOperation(operation, handler: handler)
                }
            }

            // Collect results
            for await result in group {
                await handleOperationResult(result)
            }
        }
    }

    private func processOperation(_ operation: OfflineOperation, handler: OperationHandler) async -> OperationResult {
        operation.status = .processing
        operation.lastAttemptDate = Date()

        do {
            try await handler.process(operation)
            operation.status = .completed
            syncProgress.completedOperations += 1
            return OperationResult(operation: operation, success: true, error: nil)
        } catch {
            operation.attempts += 1
            operation.lastError = error.localizedDescription

            let shouldRetry = await retryStrategy.shouldRetry(
                operation: operation,
                error: error
            )

            if shouldRetry {
                operation.status = .pending
                let delay = retryStrategy.nextDelay(for: operation)
                operation.nextRetryDate = Date().addingTimeInterval(delay)
            } else {
                operation.status = .failed
                syncProgress.failedOperations += 1
            }

            return OperationResult(operation: operation, success: false, error: error)
        }
    }

    private func handleOperationResult(_ result: OperationResult) async {
        switch result.operation.status {
        case .completed:
            pendingOperations.removeAll { $0.id == result.operation.id }
            await removePersistedOperation(result.operation)

        case .failed:
            if let index = pendingOperations.firstIndex(where: { $0.id == result.operation.id }) {
                pendingOperations.remove(at: index)
                failedOperations.append(result.operation)
            }
            await updatePersistedOperation(result.operation)

        case .pending:
            // Will be retried
            await updatePersistedOperation(result.operation)

        default:
            break
        }
    }

    private func cleanupCompletedOperations() async {
        // Remove old failed operations (older than 7 days)
        let cutoffDate = Date().addingTimeInterval(-7 * 24 * 60 * 60)
        failedOperations.removeAll { $0.timestamp < cutoffDate }

        // Update progress
        syncProgress.totalOperations = pendingOperations.count
    }

    private func estimateQueueSize() -> Int64 {
        // Rough estimate of queue size in bytes
        let operations = pendingOperations + failedOperations
        let estimatedSize = operations.reduce(0) { total, operation in
            total + Int64(operation.estimatedSize)
        }
        return estimatedSize
    }

    // MARK: - Persistence

    private func loadPendingOperations() {
        // Load from SwiftData
        do {
            let descriptor = FetchDescriptor<PersistedOfflineOperation>()
            let persisted = try modelContext.fetch(descriptor)

            pendingOperations = persisted.compactMap { $0.toOfflineOperation() }
                .sorted { $0.priority > $1.priority }
        } catch {
            print("Failed to load offline operations: \(error)")
        }
    }

    private func persistOperation(_ operation: OfflineOperation) async {
        let persisted = PersistedOfflineOperation(from: operation)
        modelContext.insert(persisted)
        try? modelContext.save()
    }

    private func updatePersistedOperation(_ operation: OfflineOperation) async {
        // Update existing persisted operation
        let operationId = operation.id
        let descriptor = FetchDescriptor<PersistedOfflineOperation>(
            predicate: #Predicate { persistedOp in
                persistedOp.id == operationId
            }
        )

        if let persisted = try? modelContext.fetch(descriptor).first {
            persisted.update(from: operation)
            try? modelContext.save()
        }
    }

    private func removePersistedOperation(_ operation: OfflineOperation) async {
        let operationId = operation.id
        let descriptor = FetchDescriptor<PersistedOfflineOperation>(
            predicate: #Predicate { persistedOp in
                persistedOp.id == operationId
            }
        )

        if let persisted = try? modelContext.fetch(descriptor).first {
            modelContext.delete(persisted)
            try? modelContext.save()
        }
    }

    private func clearPersistedOperations() async {
        try? modelContext.delete(model: PersistedOfflineOperation.self)
        try? modelContext.save()
    }
}

// MARK: - Supporting Types

@Observable
class OfflineOperation: Identifiable {
    var id = UUID()
    let type: OperationType
    let payload: [String: Any]
    let timestamp: Date
    let priority: OperationPriority

    var status: OperationStatus = .pending
    var attempts = 0
    var lastError: String?
    var lastAttemptDate: Date?
    var nextRetryDate: Date?

    var estimatedSize: Int {
        // Rough estimate based on payload
        let jsonData = try? JSONSerialization.data(withJSONObject: payload)
        return jsonData?.count ?? 1024
    }

    init(type: OperationType, payload: [String: Any], priority: OperationPriority = .normal) {
        self.type = type
        self.payload = payload
        self.timestamp = Date()
        self.priority = priority
    }

    func reset() {
        status = .pending
        attempts = 0
        lastError = nil
        lastAttemptDate = nil
        nextRetryDate = nil
    }
}

enum OperationType: String, CaseIterable {
    case healthDataUpload = "health_upload"
    case insightRequest = "insight_request"
    case profileUpdate = "profile_update"
    case patSubmission = "pat_submission"
    case syncData = "sync_data"
    case deleteData = "delete_data"
}

enum OperationPriority: Int, Comparable {
    case low = 0
    case normal = 1
    case high = 2
    case critical = 3

    static func < (lhs: OperationPriority, rhs: OperationPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum OperationStatus {
    case pending
    case processing
    case completed
    case failed
}

enum QueueStatus {
    case idle
    case processing
    case waitingForNetwork
    case partial // Some operations completed, some pending
}

struct SyncProgress {
    var totalOperations = 0
    var completedOperations = 0
    var failedOperations = 0

    var progress: Double {
        guard totalOperations > 0 else { return 0 }
        return Double(completedOperations) / Double(totalOperations)
    }

    mutating func reset() {
        totalOperations = 0
        completedOperations = 0
        failedOperations = 0
    }
}

struct QueueStatistics {
    let pendingCount: Int
    let failedCount: Int
    let byType: [OperationType: Int]
    let oldestOperation: OfflineOperation?
    let estimatedSize: Int64
}

struct OperationResult {
    let operation: OfflineOperation
    let success: Bool
    let error: Error?
}

// MARK: - Persistence Model

@Model
final class PersistedOfflineOperation {
    // CloudKit compliant - no @Attribute(.unique) allowed
    var id: UUID?
    var type: String?
    var payloadData: Data?
    var timestamp: Date?
    var priority: Int?
    var status: String?
    var attempts: Int?
    var lastError: String?
    var lastAttemptDate: Date?
    var nextRetryDate: Date?

    init(from operation: OfflineOperation) {
        self.id = operation.id
        self.type = operation.type.rawValue
        self.payloadData = (try? JSONSerialization.data(withJSONObject: operation.payload)) ?? Data()
        self.timestamp = operation.timestamp
        self.priority = operation.priority.rawValue
        self.status = String(describing: operation.status)
        self.attempts = operation.attempts
        self.lastError = operation.lastError
        self.lastAttemptDate = operation.lastAttemptDate
        self.nextRetryDate = operation.nextRetryDate
    }

    func toOfflineOperation() -> OfflineOperation? {
        guard
            let id = id,
            let type = type,
            let payloadData = payloadData,
            let priority = priority,
            let operationType = OperationType(rawValue: type),
            let payload = try? JSONSerialization.jsonObject(with: payloadData) as? [String: Any],
            let operationPriority = OperationPriority(rawValue: priority) else {
            return nil
        }

        let operation = OfflineOperation(type: operationType, payload: payload, priority: operationPriority)
        operation.id = id
        operation.attempts = attempts ?? 0
        operation.lastError = lastError
        operation.lastAttemptDate = lastAttemptDate
        operation.nextRetryDate = nextRetryDate

        return operation
    }

    func update(from operation: OfflineOperation) {
        status = String(describing: operation.status)
        attempts = operation.attempts
        lastError = operation.lastError
        lastAttemptDate = operation.lastAttemptDate
        nextRetryDate = operation.nextRetryDate
    }
}

// MARK: - Operation Handlers

protocol OperationHandler {
    func process(_ operation: OfflineOperation) async throws
}

struct HealthDataOperationHandler: OperationHandler {
    let healthRepository: HealthRepository
    let apiClient: APIClientProtocol

    func process(_ operation: OfflineOperation) async throws {
        guard let metricsData = operation.payload["metrics"] as? [[String: Any]] else {
            throw OfflineQueueError.invalidPayload
        }

        // Convert to HealthMetric objects
        let metrics = metricsData.compactMap { dict -> HealthMetric? in
            guard
                let typeString = dict["type"] as? String,
                let type = HealthMetricType(rawValue: typeString),
                let value = dict["value"] as? Double,
                let unit = dict["unit"] as? String,
                let timestamp = dict["timestamp"] as? Date else {
                return nil
            }

            return HealthMetric(
                timestamp: timestamp,
                value: value,
                type: type,
                unit: unit
            )
        }

        // Upload via repository
        try await healthRepository.batchUpload(metrics: metrics)
    }
}

struct InsightOperationHandler: OperationHandler {
    let insightRepository: AIInsightRepository
    let apiClient: APIClientProtocol

    func process(_ operation: OfflineOperation) async throws {
        guard let userId = operation.payload["userId"] as? String else {
            throw OfflineQueueError.invalidPayload
        }

        // Create insight generation request
        let _ = InsightGenerationRequestDTO(
            analysisResults: [:],
            context: nil,
            insightType: "general",
            includeRecommendations: true,
            language: "en"
        )

        // TODO: When insight API is available, implement the actual API call
        // For now, just mark as complete
        print("Would generate insight for user: \(userId)")
    }
}

struct ProfileOperationHandler: OperationHandler {
    let profileRepository: UserProfileRepository
    let apiClient: APIClientProtocol

    func process(_ operation: OfflineOperation) async throws {
        // Profile update implementation
        guard operation.payload["userId"] != nil else {
            throw OfflineQueueError.invalidPayload
        }

        // TODO: Implement when profile update API is available
    }
}

struct PATOperationHandler: OperationHandler {
    let patRepository: PATAnalysisRepository
    let apiClient: APIClientProtocol

    func process(_ operation: OfflineOperation) async throws {
        guard operation.payload["stepData"] != nil else {
            throw OfflineQueueError.invalidPayload
        }

        // Create PAT submission request
        // TODO: Implement when PAT API is available
    }
}

struct SyncOperationHandler: OperationHandler {
    let modelContext: ModelContext
    let apiClient: APIClientProtocol

    func process(_ operation: OfflineOperation) async throws {
        // Generic sync operation
        guard let entityType = operation.payload["entityType"] as? String else {
            throw OfflineQueueError.invalidPayload
        }

        // Handle different entity types
        switch entityType {
        case "HealthMetric", "AIInsight", "PATAnalysis":
            // Sync logic here
            break
        default:
            throw OfflineQueueError.unsupportedOperation
        }
    }
}

struct DeleteOperationHandler: OperationHandler {
    let modelContext: ModelContext
    let apiClient: APIClientProtocol

    func process(_ operation: OfflineOperation) async throws {
        guard
            operation.payload["entityType"] != nil,
            operation.payload["entityId"] != nil else {
            throw OfflineQueueError.invalidPayload
        }

        // TODO: Implement delete operations
    }
}

// MARK: - Retry Strategy

protocol RetryStrategy {
    func shouldRetry(operation: OfflineOperation, error: Error) async -> Bool
    func nextDelay(for operation: OfflineOperation) -> TimeInterval
}

struct ExponentialBackoffRetryStrategy: RetryStrategy {
    let maxRetries = 5
    let baseDelay: TimeInterval = 2.0
    let maxDelay: TimeInterval = 300.0 // 5 minutes

    func shouldRetry(operation: OfflineOperation, error: Error) async -> Bool {
        // Don't retry if max attempts reached
        guard operation.attempts < maxRetries else { return false }

        // Check error type
        if let apiError = error as? APIError {
            switch apiError {
            case let .httpError(statusCode, _) where statusCode >= 400 && statusCode < 500:
                // Don't retry client errors (except 429)
                return statusCode == 429
            case let .serverError(statusCode, _) where statusCode >= 500:
                // Retry server errors
                return true
            case .networkError:
                // Retry network errors
                return true
            default:
                return false
            }
        }

        return true
    }

    func nextDelay(for operation: OfflineOperation) -> TimeInterval {
        let delay = baseDelay * pow(2.0, Double(operation.attempts - 1))
        return min(delay, maxDelay)
    }
}

// MARK: - Errors

enum OfflineQueueError: LocalizedError {
    case invalidPayload
    case unsupportedOperation
    case persistenceError(Error)
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidPayload:
            return "Invalid operation payload"
        case .unsupportedOperation:
            return "Unsupported operation type"
        case let .persistenceError(error):
            return "Persistence error: \(error.localizedDescription)"
        case .networkUnavailable:
            return "Network is not available"
        }
    }
}

// MARK: - Async Semaphore

actor AsyncSemaphore {
    private var value: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        self.value = value
    }

    func wait() async {
        if value > 0 {
            value -= 1
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func signal() {
        if let waiter = waiters.first {
            waiters.removeFirst()
            waiter.resume()
        } else {
            value += 1
        }
    }
}

// MARK: - Extensions

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
