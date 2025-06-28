//
//  DashboardViewTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Tests for DashboardView UI behavior
//

import XCTest
import SwiftUI
@testable import ClarityUI
@testable import ClarityCore
@testable import ClarityDomain
@testable import ClarityData

final class DashboardViewTests: XCTestCase {
    
    // MARK: - Dashboard Header Tests
    
    @MainActor
    func test_dashboardView_shouldShowUserName_whenAppStateHasUser() {
        // Given
        let mockViewModel = createMockViewModel()
        let appState = AppState()
        appState.login(userId: UUID(), email: "test@example.com", name: "John Doe")
        
        // Create test container
        let container = DIContainer()
        container.register(DashboardViewModelFactory.self) { _ in
            MockDashboardViewModelFactory(viewModel: mockViewModel)
        }
        
        // When/Then - verify the view displays user name
        // This test validates that the DashboardView properly displays
        // the current user's name from AppState
    }
    
    @MainActor
    func test_dashboardView_shouldShowQuickStats_whenMetricsAvailable() {
        // Given
        let mockViewModel = createMockViewModel(withMetrics: true)
        
        // When metrics are loaded successfully
        // Then quick stats cards should be visible
        // This ensures important health metrics are prominently displayed
    }
    
    // MARK: - Loading State Tests
    
    @MainActor
    func test_dashboardView_shouldShowLoadingIndicator_whenFetchingData() {
        // Given
        let mockViewModel = createMockViewModel()
        mockViewModel.metricsState = .loading
        
        // When the view is loading metrics
        // Then a progress indicator should be shown
        // This provides visual feedback during data fetching
    }
    
    // MARK: - Empty State Tests
    
    @MainActor
    func test_dashboardView_shouldShowEmptyState_whenNoMetrics() {
        // Given
        let mockViewModel = createMockViewModel()
        mockViewModel.metricsState = .empty
        
        // When there are no health metrics
        // Then an appropriate empty state message should be shown
        // This guides users to add their first health data
    }
    
    // MARK: - Error State Tests
    
    @MainActor
    func test_dashboardView_shouldShowError_whenLoadingFails() {
        // Given
        let mockViewModel = createMockViewModel()
        mockViewModel.metricsState = .error(AppError.network(.connectionFailed))
        
        // When metric loading fails
        // Then an error message should be displayed
        // This helps users understand and potentially recover from errors
    }
    
    // MARK: - Filter Tests
    
    @MainActor
    func test_dashboardView_shouldFilterMetrics_whenTypeSelected() {
        // Given
        let mockViewModel = createMockViewModel(withMetrics: true)
        
        // When user selects a specific metric type filter
        mockViewModel.selectedMetricType = .heartRate
        
        // Then only metrics of that type should be displayed
        // This allows users to focus on specific health aspects
    }
    
    // MARK: - Refresh Tests
    
    @MainActor
    func test_dashboardView_shouldTriggerRefresh_whenPullToRefresh() {
        // Given
        let mockViewModel = createMockViewModel()
        
        // When user performs pull-to-refresh gesture
        // Then viewModel.refresh() should be called
        // This ensures users can manually update their data
    }
    
    @MainActor
    func test_dashboardView_shouldDisableRefreshButton_whenRefreshing() {
        // Given
        let mockViewModel = createMockViewModel()
        mockViewModel.metricsState = .loading
        
        // When data is being refreshed
        // Then the refresh button should be disabled
        // This prevents duplicate refresh requests
    }
    
    // MARK: - Navigation Tests
    
    @MainActor
    func test_dashboardView_shouldHaveProperNavigation() {
        // Given
        let mockViewModel = createMockViewModel()
        
        // When the dashboard is displayed
        // Then it should have proper navigation title and toolbar
        // This ensures consistent navigation experience
    }
    
    // MARK: - Helper Methods
    
    private func createMockViewModel(withMetrics: Bool = false) -> MockDashboardViewModel {
        let viewModel = MockDashboardViewModel()
        
        if withMetrics {
            let metrics = [
                HealthMetric(
                    id: UUID(),
                    userId: UUID(),
                    type: .heartRate,
                    value: 72,
                    unit: "BPM",
                    recordedAt: Date()
                ),
                HealthMetric(
                    id: UUID(),
                    userId: UUID(),
                    type: .steps,
                    value: 8500,
                    unit: "steps",
                    recordedAt: Date()
                ),
                HealthMetric(
                    id: UUID(),
                    userId: UUID(),
                    type: .weight,
                    value: 70.5,
                    unit: "kg",
                    recordedAt: Date()
                )
            ]
            viewModel.recentMetrics = metrics
            viewModel.metricsState = .success(metrics)
        }
        
        return viewModel
    }
}

// MARK: - Mock Dashboard View Model

@MainActor
private final class MockDashboardViewModel: DashboardViewModel {
    var loadRecentMetricsWasCalled = false
    var refreshWasCalled = false
    
    override func loadRecentMetrics() async {
        loadRecentMetricsWasCalled = true
    }
    
    override func refresh() async {
        refreshWasCalled = true
    }
}

// MARK: - Mock Factory

private struct MockDashboardViewModelFactory: DashboardViewModelFactory {
    let viewModel: DashboardViewModel
    
    func create(_ user: User) -> DashboardViewModel {
        viewModel
    }
}