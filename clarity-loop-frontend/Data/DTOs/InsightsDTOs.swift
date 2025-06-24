import Foundation

// Note: The `AnyCodable` type from the `AnyCodable.swift` file is used here
// to handle dynamic JSON values in metadata fields.

// MARK: - Insight Generation DTOs

struct InsightGenerationRequestDTO: Codable {
    let analysisResults: [String: AnyCodable]
    let context: String?
    let insightType: String
    let includeRecommendations: Bool
    let language: String
}

struct InsightGenerationResponseDTO: Codable {
    let success: Bool
    let data: HealthInsightDTO
    let metadata: [String: AnyCodable]?
}

// MARK: - Main Insight DTO

struct HealthInsightDTO: Codable, Identifiable {
    var id: String { userId } // This might need a more stable ID from the backend.

    let userId: String
    let narrative: String
    let keyInsights: [String]
    let recommendations: [String]
    let confidenceScore: Double
    let generatedAt: Date
}

// MARK: - Insight History DTOs

struct InsightHistoryResponseDTO: Codable {
    let success: Bool
    let data: InsightHistoryDataDTO
    let metadata: [String: AnyCodable]?
}

struct InsightHistoryDataDTO: Codable {
    let insights: [InsightPreviewDTO]
    let totalCount: Int
    let hasMore: Bool
    let pagination: PaginationMetaDTO?
}

struct InsightPreviewDTO: Codable, Identifiable, Equatable {
    let id: String
    let narrative: String
    let generatedAt: Date
    let confidenceScore: Double
    let keyInsightsCount: Int
    let recommendationsCount: Int
}

struct PaginationMetaDTO: Codable {
    let page: Int
    let limit: Int
    // Add other pagination fields as needed from the API spec
}

// MARK: - Service Status DTOs

/// DTO for service status response.
struct ServiceStatusResponseDTO: Codable {
    let success: Bool
    let data: ServiceStatusDataDTO
    let metadata: [String: AnyCodable]?
}

/// DTO for service status data.
struct ServiceStatusDataDTO: Codable {
    let service: String
    let status: String // "healthy", "degraded", "unhealthy"
    let modelInfo: ModelInfoDTO
    let timestamp: Date
    let uptime: Double? // in seconds
    let version: String?
}

struct ModelInfoDTO: Codable {
    let modelName: String
    let projectId: String
    let initialized: Bool
    let capabilities: [String]
}

struct InsightProcessingStatusDTO: Codable {
    let processingId: UUID
    let status: String // "pending", "processing", "completed", "failed"
    let progress: Double? // 0.0 to 1.0
    let estimatedCompletion: Date?
    let message: String?
    let error: String?
    let createdAt: Date
    let updatedAt: Date
}
