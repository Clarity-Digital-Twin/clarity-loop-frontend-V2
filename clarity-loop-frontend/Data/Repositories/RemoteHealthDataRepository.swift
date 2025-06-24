import Foundation

/// A concrete implementation of the `HealthDataRepositoryProtocol` that fetches health data
/// from the remote backend API.
final class RemoteHealthDataRepository: HealthDataRepositoryProtocol {
    // MARK: - Properties

    private let apiClient: APIClientProtocol

    // MARK: - Initializer

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    // MARK: - HealthDataRepositoryProtocol

    func getHealthData(page: Int, limit: Int) async throws -> PaginatedMetricsResponseDTO {
        try await apiClient.getHealthData(page: page, limit: limit)
    }

    func uploadHealthKitData(requestDTO: HealthKitUploadRequestDTO) async throws -> HealthKitUploadResponseDTO {
        try await apiClient.uploadHealthKitData(requestDTO: requestDTO)
    }

    func syncHealthKitData(requestDTO: HealthKitSyncRequestDTO) async throws -> HealthKitSyncResponseDTO {
        try await apiClient.syncHealthKitData(requestDTO: requestDTO)
    }

    func getHealthKitSyncStatus(syncId: String) async throws -> HealthKitSyncStatusDTO {
        try await apiClient.getHealthKitSyncStatus(syncId: syncId)
    }

    func getHealthKitUploadStatus(uploadId: String) async throws -> HealthKitUploadStatusDTO {
        try await apiClient.getHealthKitUploadStatus(uploadId: uploadId)
    }

    func getProcessingStatus(id: UUID) async throws -> HealthDataProcessingStatusDTO {
        try await apiClient.getProcessingStatus(id: id)
    }
}
