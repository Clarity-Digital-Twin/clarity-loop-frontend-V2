import Foundation
import Observation
import SwiftData
import SwiftUI

@Observable
@MainActor
final class AIInsightViewModel: BaseViewModel {
    // MARK: - Properties

    private(set) var insightsState: ViewState<[AIInsight]> = .idle
    private(set) var generationState: ViewState<AIInsight> = .idle
    private(set) var selectedTimeframe: InsightTimeframe = .week
    private(set) var selectedCategory: InsightCategoryFilter?

    // MARK: - Dependencies

    private let insightRepository: AIInsightRepository
    private let insightsRepo: InsightsRepositoryProtocol
    private let healthRepository: HealthRepository
    private let authService: AuthServiceProtocol

    // MARK: - Computed Properties

    var insights: [AIInsight] {
        insightsState.value ?? []
    }

    var filteredInsights: [AIInsight] {
        var filtered = insights

        // Filter by category
        if let categoryFilter = selectedCategory {
            // Map filter to actual category
            let category = mapFilterToCategory(categoryFilter)
            filtered = filtered.filter { $0.category == category }
        }

        // Filter by timeframe
        let cutoffDate = selectedTimeframe.cutoffDate
        filtered = filtered.filter { ($0.timestamp ?? Date.distantPast) >= cutoffDate }

        return filtered
    }

    var hasUnreadInsights: Bool {
        insights.contains { !($0.isRead ?? false) }
    }

    var insightStats: InsightStats {
        let total = insights.count
        let unread = insights.filter { !($0.isRead ?? false) }.count
        let highPriority = insights.filter { $0.priority == .high }.count
        let averageConfidence = insights.isEmpty ? 0 : insights.compactMap(\.confidenceScore)
            .reduce(0, +) / Double(insights.count)

        return InsightStats(
            totalInsights: total,
            unreadInsights: unread,
            highPriorityInsights: highPriority,
            averageConfidence: averageConfidence
        )
    }

    // MARK: - Initialization

    init(
        modelContext: ModelContext,
        insightRepository: AIInsightRepository,
        insightsRepo: InsightsRepositoryProtocol,
        healthRepository: HealthRepository,
        authService: AuthServiceProtocol
    ) {
        self.insightRepository = insightRepository
        self.insightsRepo = insightsRepo
        self.healthRepository = healthRepository
        self.authService = authService
        super.init(modelContext: modelContext)
    }

    // MARK: - Public Methods

    func loadInsights() async {
        insightsState = .loading

        do {
            // Load local insights
            let localInsights = try await insightRepository.fetchAll()

            if !localInsights.isEmpty {
                insightsState = .loaded(localInsights)
            }

            // Sync with backend
            await syncInsights()

            // Reload after sync
            let updatedInsights = try await insightRepository.fetchAll()
            insightsState = updatedInsights.isEmpty ? .empty : .loaded(updatedInsights)
        } catch {
            insightsState = .error(error)
            handle(error: error)
        }
    }

    func generateNewInsight() async {
        generationState = .loading

        do {
            // Check if we have recent health data
            let hasData = await checkRecentHealthData()
            guard hasData else {
                throw InsightError.insufficientData
            }

            // Get user ID
            guard await authService.currentUser?.id != nil else {
                throw InsightError.notAuthenticated
            }

            // Request insight generation
            let requestDTO = InsightGenerationRequestDTO(
                analysisResults: [:],
                context: nil,
                insightType: "general",
                includeRecommendations: true,
                language: "en"
            )
            let response = try await insightsRepo.generateInsight(requestDTO: requestDTO)

            // Create local AIInsight model
            let insight = AIInsight(
                content: response.data.narrative,
                category: categorizeInsight(response.data.narrative)
            )
            insight.remoteID = response.data.id
            insight.summary = response.data.narrative
            insight.priority = determinePriority(response.data)
            insight.timestamp = response.data.generatedAt
            insight.confidenceScore = response.data.confidenceScore

            // Save locally
            try await insightRepository.create(insight)

            generationState = .loaded(insight)

            // Reload insights list
            await loadInsights()
        } catch {
            generationState = .error(error)
            handle(error: error)
        }
    }

    func markAsRead(_ insight: AIInsight) async {
        insight.isRead = true

        do {
            try await insightRepository.update(insight)
        } catch {
            handle(error: error)
        }
    }

    func toggleBookmark(_ insight: AIInsight) async {
        insight.isFavorite = !(insight.isFavorite ?? false)

        do {
            try await insightRepository.update(insight)
        } catch {
            handle(error: error)
        }
    }

    func deleteInsight(_ insight: AIInsight) async {
        do {
            try await insightRepository.delete(insight)
            await loadInsights()
        } catch {
            handle(error: error)
        }
    }

    func selectTimeframe(_ timeframe: InsightTimeframe) {
        selectedTimeframe = timeframe
    }

    func selectCategory(_ category: InsightCategoryFilter?) {
        selectedCategory = category
    }

    func exportInsights() async -> URL? {
        // TODO: Implement export when AIInsight conforms to Codable
        nil
    }

    // MARK: - Private Methods

    private func syncInsights() async {
        do {
            guard let userId = await authService.currentUser?.id else { return }

            // Fetch latest insights from backend
            let response = try await insightsRepo.getInsightHistory(
                userId: userId,
                limit: 50,
                offset: 0
            )

            // Convert and save new insights
            for insightDTO in response.data.insights {
                // Check if we already have this insight
                let remoteId = insightDTO.id
                let descriptor = FetchDescriptor<AIInsight>(
                    predicate: #Predicate { insight in
                        insight.remoteID == remoteId
                    }
                )
                let existingInsights = try await insightRepository.fetch(descriptor: descriptor)

                if existingInsights.isEmpty {
                    // Create new insight from DTO
                    let insight = AIInsight(
                        content: insightDTO.narrative,
                        category: categorizeInsight(insightDTO.narrative)
                    )
                    insight.remoteID = insightDTO.id
                    insight.summary = insightDTO.narrative
                    insight.priority = determinePriority(insightDTO)
                    insight.timestamp = insightDTO.generatedAt
                    insight.confidenceScore = insightDTO.confidenceScore

                    try await insightRepository.create(insight)
                }
            }

            // Mark repository as synced
            try await insightRepository.sync()
        } catch {
            print("Insight sync error: \(error)")
        }
    }

    private func checkRecentHealthData() async -> Bool {
        do {
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -3, to: endDate)!

            // Check for any recent metrics
            var hasMetrics = false
            for type in HealthMetricType.allCases {
                let metrics = try await healthRepository.fetchMetrics(for: type, since: startDate)
                if !metrics.isEmpty {
                    hasMetrics = true
                    break
                }
            }

            return hasMetrics
        } catch {
            return false
        }
    }

    private func mapFilterToCategory(_ filter: InsightCategoryFilter) -> InsightCategory {
        switch filter {
        case .general: .general
        case .sleep: .sleep
        case .activity: .activity
        case .cardiovascular: .heartHealth
        case .nutrition: .nutrition
        case .mentalHealth: .mentalHealth
        }
    }

    private func categorizeInsight(_ narrative: String) -> InsightCategory {
        let lowercased = narrative.lowercased()

        if lowercased.contains("sleep") || lowercased.contains("rest") {
            return .sleep
        } else if lowercased.contains("heart") || lowercased.contains("cardiovascular") {
            return .heartHealth
        } else if lowercased.contains("activity") || lowercased.contains("exercise") || lowercased.contains("step") {
            return .activity
        } else if lowercased.contains("nutrition") || lowercased.contains("diet") || lowercased.contains("calor") {
            return .nutrition
        } else if lowercased.contains("stress") || lowercased.contains("mental") || lowercased.contains("mood") {
            return .mentalHealth
        } else {
            return .general
        }
    }

    private func determinePriority(_ insight: HealthInsightDTO) -> InsightPriority {
        // High priority if confidence is high and has many recommendations
        if insight.confidenceScore > 0.8, insight.recommendations.count > 2 {
            .high
        } else if insight.confidenceScore > 0.6 {
            .medium
        } else {
            .low
        }
    }

    private func determinePriority(_ insight: InsightPreviewDTO) -> InsightPriority {
        // High priority if confidence is high and has many recommendations
        if insight.confidenceScore > 0.8, insight.recommendationsCount > 2 {
            .high
        } else if insight.confidenceScore > 0.6 {
            .medium
        } else {
            .low
        }
    }
}

// MARK: - Supporting Types

enum InsightTimeframe: String, CaseIterable {
    case today = "Today"
    case week = "This Week"
    case month = "This Month"
    case all = "All Time"

    var cutoffDate: Date {
        let calendar = Calendar.current
        switch self {
        case .today:
            return calendar.startOfDay(for: Date())
        case .week:
            return calendar.date(byAdding: .day, value: -7, to: Date())!
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: Date())!
        case .all:
            return Date.distantPast
        }
    }
}

enum InsightCategoryFilter: String, CaseIterable {
    case general = "General"
    case sleep = "Sleep"
    case activity = "Activity"
    case cardiovascular = "Heart Health"
    case nutrition = "Nutrition"
    case mentalHealth = "Mental Health"

    var icon: String {
        switch self {
        case .general: "sparkles"
        case .sleep: "moon.fill"
        case .activity: "figure.walk"
        case .cardiovascular: "heart.fill"
        case .nutrition: "leaf.fill"
        case .mentalHealth: "brain.head.profile"
        }
    }

    var color: Color {
        switch self {
        case .general: .purple
        case .sleep: .indigo
        case .activity: .orange
        case .cardiovascular: .red
        case .nutrition: .green
        case .mentalHealth: .blue
        }
    }
}

enum InsightPriorityLevel: String, CaseIterable {
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    var color: Color {
        switch self {
        case .high: .red
        case .medium: .orange
        case .low: .green
        }
    }
}

struct InsightStats {
    let totalInsights: Int
    let unreadInsights: Int
    let highPriorityInsights: Int
    let averageConfidence: Double
}

enum InsightError: LocalizedError {
    case insufficientData
    case notAuthenticated
    case generationFailed

    var errorDescription: String? {
        switch self {
        case .insufficientData:
            "Not enough health data to generate insights. Please sync more data."
        case .notAuthenticated:
            "You must be signed in to generate insights"
        case .generationFailed:
            "Failed to generate insight. Please try again."
        }
    }
}
