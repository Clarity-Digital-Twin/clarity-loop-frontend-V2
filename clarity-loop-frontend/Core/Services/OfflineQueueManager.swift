import Foundation
import Network
import OSLog
import SwiftData

/// Represents a queued upload operation
@Model
final class QueuedUpload {
    var id: UUID
    var typeString: String
    var payload: Data
    var retryCount: Int
    var createdAt: Date
    var lastAttemptAt: Date?
    var error: String?

    var type: UploadType {
        get { UploadType(rawValue: typeString) ?? .healthKitData }
        set { typeString = newValue.rawValue }
    }

    enum UploadType: String, Codable {
        case healthKitData = "healthKit"
        case insightGeneration = "insight"
        case patAnalysis = "pat"
    }

    init(type: UploadType, payload: Data) {
        self.id = UUID()
        self.typeString = type.rawValue
        self.payload = payload
        self.retryCount = 0
        self.createdAt = Date()
    }
}

/// Protocol defining offline queue management operations
protocol OfflineQueueManagerProtocol: AnyObject {
    func enqueue(_ upload: QueuedUpload) async throws
    func processQueue() async
    func clearQueue() async throws
    func getQueuedItemsCount() async -> Int
    func startMonitoring()
    func stopMonitoring()
}

/// Manages offline queue for pending uploads when network is unavailable
final class OfflineQueueManager: OfflineQueueManagerProtocol {
    // MARK: - Constants

    private enum Constants {
        static let maxRetries = 3
        static let retryDelay: TimeInterval = 30 // seconds
        static let queueProcessingInterval: TimeInterval = 60 // seconds
    }

    // MARK: - Properties

    private let modelContext: ModelContext
    private let healthDataRepository: HealthDataRepositoryProtocol
    private let insightsRepository: InsightsRepositoryProtocol
    private let networkMonitor = NWPathMonitor()
    private let monitorQueue = DispatchQueue(label: "com.novamindnyc.clarity-loop-frontend.networkMonitor")
    private let logger = Logger(subsystem: "com.novamindnyc.clarity-loop-frontend", category: "OfflineQueueManager")

    private var isProcessing = false
    private var processingTask: Task<Void, Never>?
    private var isNetworkAvailable = true

    // MARK: - Initializer

    init(
        modelContext: ModelContext,
        healthDataRepository: HealthDataRepositoryProtocol,
        insightsRepository: InsightsRepositoryProtocol
    ) {
        self.modelContext = modelContext
        self.healthDataRepository = healthDataRepository
        self.insightsRepository = insightsRepository

        setupNetworkMonitoring()
    }

    // MARK: - Public Methods

    /// Adds an upload to the offline queue
    func enqueue(_ upload: QueuedUpload) async throws {
        modelContext.insert(upload)
        try modelContext.save()
        logger.info("Enqueued upload of type \(upload.type.rawValue)")

        // Try to process immediately if network is available
        if isNetworkAvailable, !isProcessing {
            await processQueue()
        }
    }

    /// Processes all queued uploads
    func processQueue() async {
        guard !isProcessing else { return }
        guard isNetworkAvailable else {
            logger.info("Network unavailable, skipping queue processing")
            return
        }

        isProcessing = true
        defer { isProcessing = false }

        logger.info("Starting queue processing")

        do {
            let maxRetries = Constants.maxRetries
            let descriptor = FetchDescriptor<QueuedUpload>(
                predicate: #Predicate { upload in
                    upload.retryCount < maxRetries
                },
                sortBy: [SortDescriptor(\.createdAt)]
            )

            let queuedUploads = try modelContext.fetch(descriptor)

            for upload in queuedUploads {
                await processUpload(upload)
            }

            logger.info("Queue processing completed")

        } catch {
            logger.error("Failed to fetch queued uploads: \(error.localizedDescription)")
        }
    }

    /// Clears all items from the queue
    func clearQueue() async throws {
        try modelContext.delete(model: QueuedUpload.self)
        try modelContext.save()
        logger.info("Queue cleared")
    }

    /// Gets the count of queued items
    func getQueuedItemsCount() async -> Int {
        do {
            let descriptor = FetchDescriptor<QueuedUpload>()
            let count = try modelContext.fetchCount(descriptor)
            return count
        } catch {
            logger.error("Failed to get queue count: \(error.localizedDescription)")
            return 0
        }
    }

    /// Starts monitoring network status and processing queue
    func startMonitoring() {
        networkMonitor.start(queue: monitorQueue)

        // Start periodic queue processing
        processingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.processQueue()
                try? await Task.sleep(nanoseconds: UInt64(Constants.queueProcessingInterval * 1_000_000_000))
            }
        }

        logger.info("Started offline queue monitoring")
    }

    /// Stops monitoring
    func stopMonitoring() {
        networkMonitor.cancel()
        processingTask?.cancel()
        processingTask = nil
        logger.info("Stopped offline queue monitoring")
    }

    // MARK: - Private Methods

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task { [weak self] in
                let wasOffline = self?.isNetworkAvailable == false
                self?.isNetworkAvailable = path.status == .satisfied

                if wasOffline, self?.isNetworkAvailable == true {
                    self?.logger.info("Network became available, processing queue")
                    await self?.processQueue()
                }
            }
        }
    }

    private func processUpload(_ upload: QueuedUpload) async {
        upload.lastAttemptAt = Date()
        upload.retryCount += 1

        do {
            switch upload.type {
            case .healthKitData:
                try await processHealthKitUpload(upload)
            case .insightGeneration:
                try await processInsightGeneration(upload)
            case .patAnalysis:
                try await processPATAnalysis(upload)
            }

            // Success - remove from queue
            modelContext.delete(upload)
            try modelContext.save()
            logger.info("Successfully processed upload \(upload.id)")

        } catch {
            upload.error = error.localizedDescription

            if upload.retryCount >= Constants.maxRetries {
                logger
                    .error(
                        "Upload \(upload.id) failed after \(Constants.maxRetries) retries: \(error.localizedDescription)"
                    )
                // Keep in queue but won't be retried automatically
            } else {
                logger.warning("Upload \(upload.id) failed, will retry: \(error.localizedDescription)")
            }

            try? modelContext.save()
        }
    }

    private func processHealthKitUpload(_ upload: QueuedUpload) async throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let request = try decoder.decode(HealthKitUploadRequestDTO.self, from: upload.payload)
        _ = try await healthDataRepository.uploadHealthKitData(requestDTO: request)
    }

    private func processInsightGeneration(_ upload: QueuedUpload) async throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let request = try decoder.decode(InsightGenerationRequestDTO.self, from: upload.payload)
        _ = try await insightsRepository.generateInsight(requestDTO: request)
    }

    private func processPATAnalysis(_ upload: QueuedUpload) async throws {
        // PAT analysis processing would be implemented here
        // For now, this is a placeholder
        throw APIError.notImplemented
    }
}

// MARK: - Convenience Extensions

extension HealthKitUploadRequestDTO {
    func toQueuedUpload() throws -> QueuedUpload {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(self)
        return QueuedUpload(type: .healthKitData, payload: data)
    }
}

extension InsightGenerationRequestDTO {
    func toQueuedUpload() throws -> QueuedUpload {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let data = try encoder.encode(self)
        return QueuedUpload(type: .insightGeneration, payload: data)
    }
}
