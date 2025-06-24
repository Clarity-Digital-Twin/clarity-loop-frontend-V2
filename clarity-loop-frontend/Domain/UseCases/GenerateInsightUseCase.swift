import Foundation

final class GenerateInsightUseCase {
    private let insightAIService: InsightAIServiceProtocol
    private let healthDataRepository: HealthDataRepositoryProtocol

    init(
        insightAIService: InsightAIServiceProtocol,
        healthDataRepository: HealthDataRepositoryProtocol
    ) {
        self.insightAIService = insightAIService
        self.healthDataRepository = healthDataRepository
    }

    func execute(
        type: InsightType = .dailySummary,
        context: String? = nil
    ) async throws -> HealthInsightDTO {
        // Fetch recent health data
        let healthData = try await healthDataRepository.getHealthData(page: 1, limit: 20)

        switch type {
        case .dailySummary:
            return try await insightAIService.generateInsightFromHealthData(
                metrics: healthData.data,
                patAnalysis: nil,
                customContext: context ?? "Generate a daily health summary with actionable insights."
            )
        case let .chatResponse(userMessage, conversationHistory):
            // Build health context for chat
            let healthContext = buildHealthContext(from: healthData.data)
            return try await insightAIService.generateChatResponse(
                userMessage: userMessage,
                conversationHistory: conversationHistory,
                healthContext: healthContext
            )
        case let .custom(analysisResults):
            return try await insightAIService.generateInsight(
                from: analysisResults,
                context: context,
                insightType: "custom",
                includeRecommendations: true,
                language: "en"
            )
        }
    }

    private func buildHealthContext(from metrics: [HealthMetricDTO]) -> [String: Any] {
        var context: [String: Any] = [:]

        // Group metrics by type for easier analysis
        let groupedMetrics = Dictionary(grouping: metrics) { $0.metricType }

        // Add steps data
        if let stepsMetrics = groupedMetrics["steps"] {
            let totalSteps = stepsMetrics.compactMap { $0.activityData?.steps }.reduce(0, +)
            context["total_steps"] = totalSteps
            context["avg_daily_steps"] = totalSteps / max(1, stepsMetrics.count)
        }

        // Add heart rate data
        if let heartRateMetrics = groupedMetrics["heart_rate"] {
            let heartRates = heartRateMetrics.compactMap { $0.biometricData?.heartRate }
            if !heartRates.isEmpty {
                context["avg_heart_rate"] = heartRates.reduce(0, +) / Double(heartRates.count)
                context["max_heart_rate"] = heartRates.max()
                context["min_heart_rate"] = heartRates.min()
            }
        }

        // Add sleep data
        if let sleepMetrics = groupedMetrics["sleep"] {
            let sleepData = sleepMetrics.compactMap(\.sleepData)
            if !sleepData.isEmpty {
                let totalSleep = sleepData.map(\.totalSleepMinutes).reduce(0, +)
                let avgEfficiency = sleepData.map(\.sleepEfficiency).reduce(0, +) / Double(sleepData.count)
                context["total_sleep_minutes"] = totalSleep
                context["avg_sleep_efficiency"] = avgEfficiency
            }
        }

        context["metrics_count"] = metrics.count
        context["date_range"] =
            "\(metrics.first?.createdAt.formatted() ?? "N/A") - \(metrics.last?.createdAt.formatted() ?? "N/A")"

        return context
    }
}

enum InsightType {
    case dailySummary
    case chatResponse(userMessage: String, conversationHistory: [ChatMessage])
    case custom(analysisResults: [String: Any])
}
