import SwiftUI

struct DashboardView: View {
    @Environment(\.healthKitService) private var healthKitService
    @Environment(\.insightsRepository) private var insightsRepository
    @Environment(\.authService) private var authService

    @State private var viewModel: DashboardViewModel?

    var body: some View {
        NavigationStack {
            ZStack {
                if let viewModel {
                    switch viewModel.viewState {
                    case .idle:
                        Color.clear // Nothing shown
                    case .loading:
                        LoadingView(
                            message: "Loading your health data...",
                            style: .fullScreen
                        )
                    case let .loaded(data):
                        ScrollView {
                            LazyVStack(spacing: 16) {
                                // Health sync status card
                                if let syncManager = viewModel.healthSyncManager {
                                    SyncStatusView(syncManager: syncManager)
                                }
                                
                                if let insight = data.insightOfTheDay {
                                    InsightCardView(insight: insight)
                                }

                                HealthMetricCardView(
                                    title: "Steps",
                                    value: String(format: "%.0f", data.metrics.stepCount),
                                    systemImageName: "figure.walk"
                                )

                                if let rhr = data.metrics.restingHeartRate {
                                    HealthMetricCardView(
                                        title: "Resting Heart Rate",
                                        value: String(format: "%.0f", rhr) + " BPM",
                                        systemImageName: "heart.fill"
                                    )
                                }

                                if let sleep = data.metrics.sleepData {
                                    HealthMetricCardView(
                                        title: "Time Asleep",
                                        value: String(format: "%.1f", sleep.totalTimeAsleep / 3600) + " hr",
                                        systemImageName: "bed.double.fill"
                                    )
                                }
                            }
                            .padding()
                        }
                        .refreshable {
                            await viewModel.loadDashboard()
                        }
                    case .empty:
                        #if targetEnvironment(simulator)
                            EmptyStateView(
                                title: "Welcome to CLARITY Pulse",
                                message: "You're running in the simulator. To see real health data, run the app on a physical device with HealthKit data.",
                                systemImage: "iphone.and.arrow.forward",
                                actionTitle: "Load Sample Data",
                                action: {
                                    Task {
                                        await viewModel.loadSampleData()
                                    }
                                }
                            )
                        #else
                            NoHealthDataView(
                                onSetupHealthKit: {
                                    Task {
                                        await viewModel.loadDashboard()
                                    }
                                }
                            )
                        #endif
                    case .error(let error):
                        ErrorView(
                            apiError: error as? APIError ?? APIError.unknown(error),
                            onRetry: {
                                Task {
                                    await viewModel.loadDashboard()
                                }
                            }
                        )
                    }
                } else {
                    ProgressView("Loading...")
                }
            }
            .navigationTitle("Your Pulse")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: ChatView()) {
                        Image(systemName: "bubble.left.and.bubble.right")
                    }
                }
            }
            .task {
                if viewModel == nil {
                    viewModel = DashboardViewModel(
                        insightsRepo: insightsRepository,
                        healthKitService: healthKitService,
                        authService: authService
                    )
                }

                if let vm = viewModel, case .idle = vm.viewState {
                    await vm.loadDashboard()
                }
            }
        }
    }
}

#Preview {
    guard
        let previewAPIClient = APIClient(
            baseURLString: AppConfig.previewAPIBaseURL,
            tokenProvider: { nil }
        ) else {
        return Text("Failed to create preview client")
    }

    return DashboardView()
        .environment(\.authService, AuthService(apiClient: previewAPIClient))
        .environment(\.healthKitService, HealthKitService(apiClient: previewAPIClient))
        .environment(\.insightsRepository, RemoteInsightsRepository(apiClient: previewAPIClient))
}
