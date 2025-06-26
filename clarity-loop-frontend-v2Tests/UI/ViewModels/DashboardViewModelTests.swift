//
//  DashboardViewModelTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Tests for DashboardViewModel following TDD
//

import XCTest
@testable import ClarityUI
@testable import ClarityDomain
@testable import ClarityData

final class DashboardViewModelTests: XCTestCase {
    
    private var sut: DashboardViewModel!
    private var mockHealthMetricRepository: MockHealthMetricRepository!
    private var mockUser: User!
    
    @MainActor
    override func setUp() async throws {
        try await super.setUp()
        
        mockUser = User(
            id: UUID(),
            email: "test@example.com",
            firstName: "Test",
            lastName: "User"
        )
        
        mockHealthMetricRepository = MockHealthMetricRepository()
        sut = DashboardViewModel(
            user: mockUser,
            healthMetricRepository: mockHealthMetricRepository
        )
    }
    
    override func tearDown() {
        sut = nil
        mockHealthMetricRepository = nil
        mockUser = nil
        super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    @MainActor
    func test_whenInitialized_shouldHaveCorrectInitialState() {
        // Then
        XCTAssertEqual(sut.user.id, mockUser.id)
        XCTAssertEqual(sut.metricsState, .idle)
        XCTAssertTrue(sut.recentMetrics.isEmpty)
        XCTAssertNil(sut.selectedMetricType)
    }
    
    // MARK: - Load Metrics Tests
    
    @MainActor
    func test_whenLoadingMetrics_shouldFetchUserMetrics() async {
        // Given
        let expectedMetrics = [
            HealthMetric(
                id: UUID(),
                userId: mockUser.id,
                type: .heartRate,
                value: 72,
                unit: "BPM",
                recordedAt: Date()
            ),
            HealthMetric(
                id: UUID(),
                userId: mockUser.id,
                type: .steps,
                value: 8500,
                unit: "steps",
                recordedAt: Date()
            )
        ]
        mockHealthMetricRepository.mockMetrics = expectedMetrics
        
        // When
        await sut.loadRecentMetrics()
        
        // Then
        XCTAssertEqual(sut.metricsState, .success(expectedMetrics))
        XCTAssertEqual(sut.recentMetrics.count, 2)
        XCTAssertTrue(mockHealthMetricRepository.findByUserIdWasCalled)
        XCTAssertEqual(mockHealthMetricRepository.lastUserId, mockUser.id)
    }
    
    @MainActor
    func test_whenLoadingMetrics_shouldShowLoadingState() async {
        // Given
        mockHealthMetricRepository.shouldDelay = true
        
        // When
        let loadTask = Task {
            await sut.loadRecentMetrics()
        }
        
        // Allow time for loading state
        try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
        
        // Then
        XCTAssertEqual(sut.metricsState, .loading)
        
        // Cleanup
        loadTask.cancel()
    }
    
    @MainActor
    func test_whenLoadingMetrics_withError_shouldShowError() async {
        // Given
        mockHealthMetricRepository.shouldThrowError = true
        
        // When
        await sut.loadRecentMetrics()
        
        // Then
        XCTAssertEqual(sut.metricsState, .error("Failed to load health metrics"))
        XCTAssertTrue(sut.recentMetrics.isEmpty)
    }
    
    // MARK: - Filter Tests
    
    @MainActor
    func test_whenFilteringByType_shouldShowOnlyMatchingMetrics() async {
        // Given
        let metrics = [
            HealthMetric(
                id: UUID(),
                userId: mockUser.id,
                type: .heartRate,
                value: 72,
                unit: "BPM",
                recordedAt: Date()
            ),
            HealthMetric(
                id: UUID(),
                userId: mockUser.id,
                type: .steps,
                value: 8500,
                unit: "steps",
                recordedAt: Date()
            ),
            HealthMetric(
                id: UUID(),
                userId: mockUser.id,
                type: .heartRate,
                value: 75,
                unit: "BPM",
                recordedAt: Date()
            )
        ]
        mockHealthMetricRepository.mockMetrics = metrics
        await sut.loadRecentMetrics()
        
        // When
        sut.selectedMetricType = .heartRate
        
        // Then
        XCTAssertEqual(sut.filteredMetrics.count, 2)
        XCTAssertTrue(sut.filteredMetrics.allSatisfy { $0.type == .heartRate })
    }
    
    @MainActor
    func test_whenClearingFilter_shouldShowAllMetrics() async {
        // Given
        let metrics = createMixedMetrics()
        mockHealthMetricRepository.mockMetrics = metrics
        await sut.loadRecentMetrics()
        sut.selectedMetricType = .heartRate
        
        // When
        sut.selectedMetricType = nil
        
        // Then
        XCTAssertEqual(sut.filteredMetrics.count, metrics.count)
    }
    
    // MARK: - Summary Statistics Tests
    
    @MainActor
    func test_whenCalculatingSummary_shouldProvideCorrectStats() async {
        // Given
        let metrics = [
            HealthMetric(
                id: UUID(),
                userId: mockUser.id,
                type: .steps,
                value: 8000,
                unit: "steps",
                recordedAt: Date().addingTimeInterval(-86400) // Yesterday
            ),
            HealthMetric(
                id: UUID(),
                userId: mockUser.id,
                type: .steps,
                value: 10000,
                unit: "steps",
                recordedAt: Date() // Today
            )
        ]
        mockHealthMetricRepository.mockMetrics = metrics
        
        // When
        await sut.loadRecentMetrics()
        let summary = sut.summaryForType(.steps)
        
        // Then
        XCTAssertNotNil(summary)
        XCTAssertEqual(summary?.average, 9000)
        XCTAssertEqual(summary?.latest, 10000)
        XCTAssertEqual(summary?.count, 2)
    }
    
    // MARK: - Refresh Tests
    
    @MainActor
    func test_whenRefreshing_shouldReloadData() async {
        // Given
        let initialMetrics = [createMetric(type: .heartRate, value: 72)]
        mockHealthMetricRepository.mockMetrics = initialMetrics
        await sut.loadRecentMetrics()
        
        // Update mock data
        let updatedMetrics = [
            createMetric(type: .heartRate, value: 72),
            createMetric(type: .heartRate, value: 75)
        ]
        mockHealthMetricRepository.mockMetrics = updatedMetrics
        
        // When
        await sut.refresh()
        
        // Then
        XCTAssertEqual(sut.recentMetrics.count, 2)
        XCTAssertEqual(mockHealthMetricRepository.findByUserIdCallCount, 2)
    }
    
    // MARK: - Helper Methods
    
    private func createMetric(
        type: HealthMetricType,
        value: Double,
        date: Date = Date()
    ) -> HealthMetric {
        HealthMetric(
            id: UUID(),
            userId: mockUser.id,
            type: type,
            value: value,
            unit: type.defaultUnit,
            recordedAt: date
        )
    }
    
    private func createMixedMetrics() -> [HealthMetric] {
        [
            createMetric(type: .heartRate, value: 72),
            createMetric(type: .steps, value: 8500),
            createMetric(type: .bloodPressureSystolic, value: 120),
            createMetric(type: .heartRate, value: 75)
        ]
    }
}

// MARK: - Mock Health Metric Repository

@MainActor
private final class MockHealthMetricRepository: HealthMetricRepositoryProtocol, @unchecked Sendable {
    var mockMetrics: [HealthMetric] = []
    var shouldThrowError = false
    var shouldDelay = false
    var findByUserIdWasCalled = false
    var findByUserIdCallCount = 0
    var lastUserId: UUID?
    
    func create(_ metric: HealthMetric) async throws -> HealthMetric {
        mockMetrics.append(metric)
        return metric
    }
    
    func createBatch(_ metrics: [HealthMetric]) async throws -> [HealthMetric] {
        mockMetrics.append(contentsOf: metrics)
        return metrics
    }
    
    func findById(_ id: UUID) async throws -> HealthMetric? {
        mockMetrics.first { $0.id == id }
    }
    
    func findByUserId(_ userId: UUID) async throws -> [HealthMetric] {
        findByUserIdWasCalled = true
        findByUserIdCallCount += 1
        lastUserId = userId
        
        if shouldDelay {
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }
        
        if shouldThrowError {
            throw RepositoryError.fetchFailed
        }
        
        return mockMetrics.filter { $0.userId == userId }
    }
    
    func findByUserIdAndDateRange(
        userId: UUID,
        startDate: Date,
        endDate: Date
    ) async throws -> [HealthMetric] {
        mockMetrics.filter { metric in
            metric.userId == userId &&
            metric.recordedAt >= startDate &&
            metric.recordedAt <= endDate
        }
    }
    
    func findByUserIdAndType(
        userId: UUID,
        type: HealthMetricType
    ) async throws -> [HealthMetric] {
        mockMetrics.filter { $0.userId == userId && $0.type == type }
    }
    
    func update(_ metric: HealthMetric) async throws -> HealthMetric {
        if let index = mockMetrics.firstIndex(where: { $0.id == metric.id }) {
            mockMetrics[index] = metric
        }
        return metric
    }
    
    func delete(_ id: UUID) async throws {
        mockMetrics.removeAll { $0.id == id }
    }
    
    func deleteAllForUser(_ userId: UUID) async throws {
        mockMetrics.removeAll { $0.userId == userId }
    }
    
    func getLatestByType(
        userId: UUID,
        type: HealthMetricType
    ) async throws -> HealthMetric? {
        mockMetrics
            .filter { $0.userId == userId && $0.type == type }
            .max { $0.recordedAt < $1.recordedAt }
    }
    
    func syncPendingMetrics() async throws -> Int {
        0 // No pending metrics in mock
    }
}