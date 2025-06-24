import Foundation
import Observation

@Observable
@MainActor
final class InsightsListViewModel {
    // MARK: - Properties

    private(set) var viewState: ViewState<[InsightPreviewDTO]> = .idle
    private(set) var isLoadingMore = false
    private(set) var hasMorePages = true

    // MARK: - Private Properties

    private let insightsRepository: InsightsRepositoryProtocol
    private let userId: String
    private var currentPage = 0
    private let pageSize = 20
    private var allInsights: [InsightPreviewDTO] = []

    // MARK: - Initializer

    init(insightsRepository: InsightsRepositoryProtocol, userId: String) {
        self.insightsRepository = insightsRepository
        self.userId = userId
    }

    // MARK: - Public Methods

    /// Loads the initial set of insights
    func loadInsights() async {
        guard case .idle = viewState else { return }

        viewState = .loading
        currentPage = 0
        allInsights = []

        do {
            let response = try await insightsRepository.getInsightHistory(
                userId: userId,
                limit: pageSize,
                offset: 0
            )

            allInsights = response.data.insights
            hasMorePages = response.data.hasMore

            if allInsights.isEmpty {
                viewState = .empty
            } else {
                viewState = .loaded(allInsights)
            }

        } catch {
            viewState = .error(error)
        }
    }

    /// Loads more insights for pagination
    func loadMoreInsights() async {
        guard !isLoadingMore, hasMorePages else { return }

        isLoadingMore = true

        do {
            let nextPage = currentPage + 1
            let response = try await insightsRepository.getInsightHistory(
                userId: userId,
                limit: pageSize,
                offset: nextPage * pageSize
            )

            allInsights.append(contentsOf: response.data.insights)
            hasMorePages = response.data.hasMore
            currentPage = nextPage

            viewState = .loaded(allInsights)

        } catch {
            // Don't change the view state for pagination errors
            print("Error loading more insights: \(error)")
        }

        isLoadingMore = false
    }

    /// Refreshes the insights list
    func refresh() async {
        currentPage = 0
        allInsights = []
        hasMorePages = true

        do {
            let response = try await insightsRepository.getInsightHistory(
                userId: userId,
                limit: pageSize,
                offset: 0
            )

            allInsights = response.data.insights
            hasMorePages = response.data.hasMore

            if allInsights.isEmpty {
                viewState = .empty
            } else {
                viewState = .loaded(allInsights)
            }

        } catch {
            // Keep showing existing data on refresh error
            if allInsights.isEmpty {
                viewState = .error(error)
            }
        }
    }

    /// Generates a new insight based on recent health data
    func generateNewInsight() async {
        // This would typically gather recent health data and call the insights generation endpoint
        // For now, this is a placeholder
        print("Generating new insight...")
    }
}
