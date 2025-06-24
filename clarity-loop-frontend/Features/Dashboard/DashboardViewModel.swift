import Foundation
import Observation
import SwiftUI
import Combine

/// A struct to hold all the necessary data for the dashboard.
/// This will be expanded as more data sources are integrated.
struct DashboardData: Equatable {
    let metrics: DailyHealthMetrics
    let insightOfTheDay: InsightPreviewDTO?
}

@Observable
final class DashboardViewModel {
    // MARK: - Properties

    var viewState: ViewState<DashboardData> = .idle
    var healthSyncManager: HealthDataSyncManager?

    // MARK: - Dependencies

    private let insightsRepo: InsightsRepositoryProtocol
    private let healthKitService: HealthKitServiceProtocol
    private let authService: AuthServiceProtocol
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initializer

    init(
        insightsRepo: InsightsRepositoryProtocol,
        healthKitService: HealthKitServiceProtocol,
        authService: AuthServiceProtocol
    ) {
        self.insightsRepo = insightsRepo
        self.healthKitService = healthKitService
        self.authService = authService
        
        // Listen for health data sync notifications
        NotificationCenter.default.publisher(for: .healthDataSynced)
            .sink { [weak self] _ in
                Task {
                    await self?.loadDashboard()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods

    /// Initializes the health sync manager on the main actor
    @MainActor
    func initializeHealthSyncManager() async {
        if healthSyncManager == nil {
            healthSyncManager = HealthDataSyncManager(
                healthKitService: healthKitService,
                authService: authService
            )
        }
    }
    
    /// Loads all necessary data for the dashboard.
    func loadDashboard() async {
        // Initialize health sync manager if needed
        await initializeHealthSyncManager()
        
        viewState = .loading

        do {
            // Request HealthKit authorization before fetching data.
            try await healthKitService.requestAuthorization()

            // Fetch health metrics and insights in parallel
            async let metrics = healthKitService.fetchAllDailyMetrics(for: Date())
            let userId = await authService.currentUser?.id ?? "unknown"
            async let insightsResponse = insightsRepo.getInsightHistory(userId: userId, limit: 1, offset: 0)

            let (dailyMetrics, insights) = try await (metrics, insightsResponse)

            let data = DashboardData(metrics: dailyMetrics, insightOfTheDay: insights.data.insights.first)

            // The view is considered "empty" only if both metrics and insights are empty.
            let hasMetrics = data.metrics.stepCount > 0 || data.metrics.restingHeartRate != nil || data.metrics
                .sleepData != nil
            if !hasMetrics, data.insightOfTheDay == nil {
                viewState = .empty
            } else {
                viewState = .loaded(data)
            }
        } catch {
            viewState = .error(error)
        }
    }

    #if targetEnvironment(simulator)
        /// Loads sample data for simulator testing ONLY when no real data exists
        func loadSampleData() async {
            viewState = .loading

            // First, try to load real data even in simulator
            do {
                // Request HealthKit authorization
                try await healthKitService.requestAuthorization()

                // Try to fetch real health metrics and insights
                async let metrics = healthKitService.fetchAllDailyMetrics(for: Date())
                let userId = await authService.currentUser?.id ?? "unknown"
                async let insightsResponse = insightsRepo.getInsightHistory(userId: userId, limit: 1, offset: 0)

                let (dailyMetrics, insights) = try await (metrics, insightsResponse)

                let hasRealData = dailyMetrics.stepCount > 0 || 
                                  dailyMetrics.restingHeartRate != nil || 
                                  dailyMetrics.sleepData != nil ||
                                  !insights.data.insights.isEmpty

                if hasRealData {
                    // Use real data
                    let data = DashboardData(metrics: dailyMetrics, insightOfTheDay: insights.data.insights.first)
                    viewState = .loaded(data)
                    return
                }
            } catch {
                // If real data fetch fails, continue with sample data
                print("Failed to load real data in simulator: \(error)")
            }

            // Only show sample data if no real data exists
            let sampleMetrics = DailyHealthMetrics(
                date: Date(),
                stepCount: 0,
                restingHeartRate: nil,
                sleepData: nil
            )

            let data = DashboardData(
                metrics: sampleMetrics,
                insightOfTheDay: nil
            )

            // Small delay to simulate loading
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            viewState = .loaded(data)
        }
    #endif
}
