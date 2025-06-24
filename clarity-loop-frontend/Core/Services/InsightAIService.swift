import Foundation
import Observation

@Observable
final class InsightAIService {
    // MARK: - Properties

    private let apiClient: APIClientProtocol

    // MARK: - Initialization

    init(apiClient: APIClientProtocol) {
        self.apiClient = apiClient
    }

    // MARK: - Public Methods

    func generateInsight(
        from analysisResults: [String: Any],
        context: String? = nil,
        insightType: String = "daily_summary",
        includeRecommendations: Bool = true,
        language: String = "en"
    ) async throws -> HealthInsightDTO {
        let request = InsightGenerationRequestDTO(
            analysisResults: analysisResults.mapValues { AnyCodable($0) },
            context: context,
            insightType: insightType,
            includeRecommendations: includeRecommendations,
            language: language
        )

        let response = try await apiClient.generateInsight(requestDTO: request)
        return response.data
    }

    func generateInsightFromHealthData(
        metrics: [HealthMetricDTO],
        patAnalysis: [String: Any]? = nil,
        customContext: String? = nil
    ) async throws -> HealthInsightDTO {
        // Convert health metrics to analysis format
        var analysisResults: [String: Any] = [:]

        // Group metrics by type
        let groupedMetrics = Dictionary(grouping: metrics) { $0.metricType }

        for (metricType, metricList) in groupedMetrics {
            switch metricType {
            case "steps":
                analysisResults["daily_steps"] = metricList.compactMap { $0.activityData?.steps }.reduce(0, +)
            case "heart_rate":
                let heartRates = metricList.compactMap { $0.biometricData?.heartRate }
                if !heartRates.isEmpty {
                    analysisResults["avg_heart_rate"] = heartRates.reduce(0, +) / Double(heartRates.count)
                    analysisResults["max_heart_rate"] = heartRates.max()
                    analysisResults["min_heart_rate"] = heartRates.min()
                }
            case "sleep":
                let sleepData = metricList.compactMap(\.sleepData)
                if !sleepData.isEmpty {
                    analysisResults["total_sleep_minutes"] = sleepData.map(\.totalSleepMinutes).reduce(0, +)
                    analysisResults["avg_sleep_efficiency"] = sleepData.map(\.sleepEfficiency)
                        .reduce(0, +) / Double(sleepData.count)
                }
            default:
                break
            }
        }

        // Include PAT analysis if available
        if let patAnalysis {
            analysisResults["pat_analysis"] = patAnalysis
        }

        let context = customContext ?? "Generate insights based on the user's recent health data patterns."

        return try await generateInsight(
            from: analysisResults,
            context: context,
            insightType: "health_summary"
        )
    }

    func generateChatResponse(
        userMessage: String,
        conversationHistory: [ChatMessage] = [],
        healthContext: [String: Any]? = nil
    ) async throws -> HealthInsightDTO {
        // Since the chat endpoint doesn't exist, use the insights generation endpoint
        // Format the conversation history as context
        var context = userMessage
        if !conversationHistory.isEmpty {
            context = "Previous conversation:\n"
            for msg in conversationHistory.suffix(5) { // Keep last 5 messages for context
                context += "\(msg.sender.rawValue.capitalized): \(msg.text)\n"
            }
            context += "\nUser: \(userMessage)\n\nPlease provide a helpful response based on the conversation."
        }
        
        // Create analysis results with conversation context
        var analysisResults: [String: AnyCodable] = [
            "conversation_type": AnyCodable("chat"),
            "message": AnyCodable(userMessage)
        ]
        
        // Add health context if provided
        if let healthContext {
            for (key, value) in healthContext {
                analysisResults[key] = AnyCodable(value)
            }
        }
        
        // Use the insights endpoint instead of non-existent chat endpoint
        let response = try await generateInsight(
            from: analysisResults,
            context: context,
            insightType: "chat_response",
            includeRecommendations: false,
            language: "en"
        )
        
        return response
    }

    func getInsightHistory(userId: String, limit: Int = 20, offset: Int = 0) async throws -> InsightHistoryResponseDTO {
        try await apiClient.getInsightHistory(userId: userId, limit: limit, offset: offset)
    }

    func checkServiceStatus() async throws -> ServiceStatusResponseDTO {
        try await apiClient.getInsightsServiceStatus()
    }
}

// MARK: - Protocol

protocol InsightAIServiceProtocol {
    func generateInsight(
        from analysisResults: [String: Any],
        context: String?,
        insightType: String,
        includeRecommendations: Bool,
        language: String
    ) async throws -> HealthInsightDTO

    func generateInsightFromHealthData(
        metrics: [HealthMetricDTO],
        patAnalysis: [String: Any]?,
        customContext: String?
    ) async throws -> HealthInsightDTO

    func generateChatResponse(
        userMessage: String,
        conversationHistory: [ChatMessage],
        healthContext: [String: Any]?
    ) async throws -> HealthInsightDTO

    func getInsightHistory(userId: String, limit: Int, offset: Int) async throws -> InsightHistoryResponseDTO

    func checkServiceStatus() async throws -> ServiceStatusResponseDTO
}

extension InsightAIService: InsightAIServiceProtocol {}

// MARK: - Supporting Types

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let sender: Sender
    var text: String
    var timestamp: Date = .init()
    var isError = false

    enum Sender: String, CaseIterable {
        case user
        case assistant
    }
}
