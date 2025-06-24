import Foundation

/// A protocol defining the contract for a repository that handles fetching health data.
/// This abstraction allows for interchangeable concrete implementations (e.g., a remote repository
/// that fetches from an API, or a local one that fetches from a cache).
protocol HealthDataRepositoryProtocol {
    /// Fetches a paginated list of health metrics.
    /// - Parameters:
    ///   - page: The page number to retrieve.
    ///   - limit: The number of items per page.
    /// - Returns: A `PaginatedMetricsResponseDTO` containing the health data.
    func getHealthData(page: Int, limit: Int) async throws -> PaginatedMetricsResponseDTO

    /// Uploads HealthKit data to the backend.
    /// - Parameter requestDTO: The upload request containing HealthKit samples.
    /// - Returns: A response indicating the upload status.
    func uploadHealthKitData(requestDTO: HealthKitUploadRequestDTO) async throws -> HealthKitUploadResponseDTO

    /// Initiates a sync of HealthKit data for a specific date range.
    /// - Parameter requestDTO: The sync request parameters.
    /// - Returns: A response with sync status information.
    func syncHealthKitData(requestDTO: HealthKitSyncRequestDTO) async throws -> HealthKitSyncResponseDTO

    /// Gets the status of a HealthKit sync operation.
    /// - Parameter syncId: The ID of the sync operation.
    /// - Returns: The current sync status.
    func getHealthKitSyncStatus(syncId: String) async throws -> HealthKitSyncStatusDTO

    /// Gets the status of a HealthKit upload operation.
    /// - Parameter uploadId: The ID of the upload operation.
    /// - Returns: The current upload status.
    func getHealthKitUploadStatus(uploadId: String) async throws -> HealthKitUploadStatusDTO

    /// Gets the processing status of health data.
    /// - Parameter id: The ID of the processing operation.
    /// - Returns: The current processing status.
    func getProcessingStatus(id: UUID) async throws -> HealthDataProcessingStatusDTO
}
