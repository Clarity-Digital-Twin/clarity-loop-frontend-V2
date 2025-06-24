import Foundation

/// A concrete implementation of the `InsightsRepositoryProtocol` that fetches AI-generated insights
/// from the remote backend API.
class RemoteInsightsRepository: InsightsRepositoryProtocol {
    private let apiClient: APIClientProtocol

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    func getInsightHistory(userId: String, limit: Int, offset: Int) async throws -> InsightHistoryResponseDTO {
        try await apiClient.getInsightHistory(userId: userId, limit: limit, offset: offset)
    }

    func generateInsight(requestDTO: InsightGenerationRequestDTO) async throws -> InsightGenerationResponseDTO {
        try await apiClient.generateInsight(requestDTO: requestDTO)
    }

    // Protocol methods for fetching and generating insights will be implemented here.
}
