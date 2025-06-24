import Foundation
import SwiftData

// MARK: - Repository Factory

final class RepositoryFactory {
    // MARK: - Properties

    private let modelContainer: ModelContainer

    // MARK: - Initialization

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    // MARK: - Factory Methods

    @MainActor
    func makeHealthRepository() -> any HealthRepositoryProtocol {
        HealthRepository(modelContext: modelContainer.mainContext)
    }

    @MainActor
    func makeUserProfileRepository() -> any UserProfileRepositoryProtocol {
        UserProfileRepository(modelContext: modelContainer.mainContext)
    }

    @MainActor
    func makePATAnalysisRepository() -> any PATAnalysisRepositoryProtocol {
        PATAnalysisRepository(modelContext: modelContainer.mainContext)
    }

    @MainActor
    func makeAIInsightRepository() -> any AIInsightRepositoryProtocol {
        AIInsightRepository(modelContext: modelContainer.mainContext)
    }

    // MARK: - Background Context

    func makeBackgroundContext() -> ModelContext {
        ModelContext(modelContainer)
    }

    func makeHealthRepositoryBackground() -> any HealthRepositoryProtocol {
        let context = makeBackgroundContext()
        return HealthRepository(modelContext: context)
    }
}

// MARK: - Repository Protocols (Type Erasure)

protocol HealthRepositoryProtocol: BaseRepository where Model == HealthMetric {
    func fetchMetrics(for type: HealthMetricType, since date: Date) async throws -> [HealthMetric]
    func fetchLatestMetric(for type: HealthMetricType) async throws -> HealthMetric?
    func batchUpload(metrics: [HealthMetric]) async throws
}

protocol UserProfileRepositoryProtocol: BaseRepository where Model == UserProfileModel {
    func fetchCurrentUser() async throws -> UserProfileModel?
    func updatePreferences(_ preferences: UserPreferences) async throws
}

protocol PATAnalysisRepositoryProtocol: BaseRepository where Model == PATAnalysis {
    func fetchAnalyses(between startDate: Date, and endDate: Date) async throws -> [PATAnalysis]
    func fetchLatestAnalysis() async throws -> PATAnalysis?
}

protocol AIInsightRepositoryProtocol: BaseRepository where Model == AIInsight {
    func fetchInsights(for category: InsightCategory?, limit: Int) async throws -> [AIInsight]
    func fetchConversation(id: UUID) async throws -> [AIInsight]
    func searchInsights(query: String) async throws -> [AIInsight]
}

// MARK: - Environment Key for Dependency Injection

import SwiftUI

private struct RepositoryFactoryKey: EnvironmentKey {
    static let defaultValue: RepositoryFactory? = nil
}

extension EnvironmentValues {
    var repositoryFactory: RepositoryFactory? {
        get { self[RepositoryFactoryKey.self] }
        set { self[RepositoryFactoryKey.self] = newValue }
    }
}
