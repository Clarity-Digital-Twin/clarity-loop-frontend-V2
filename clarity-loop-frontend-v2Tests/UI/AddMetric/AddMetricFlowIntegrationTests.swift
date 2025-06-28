//
//  AddMetricFlowIntegrationTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Integration tests for complete Add-Metric flow
//

import XCTest
@testable import ClarityUI
@testable import ClarityDomain
@testable import ClarityData
@testable import ClarityCore

final class AddMetricFlowIntegrationTests: XCTestCase {
    
    // MARK: - Properties
    
    private var dashboardViewModel: DashboardViewModel!
    private var mockRepository: MockHealthMetricRepository!
    private var mockAPIClient: MockAPIClient!
    private var testUser: User!
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Create test user
        testUser = User(
            id: UUID(),
            email: "test@example.com",
            firstName: "Test",
            lastName: "User"
        )
        
        // Create mocks
        mockRepository = MockHealthMetricRepository()
        mockAPIClient = MockAPIClient()
        
        // Create dashboard view model
        dashboardViewModel = await DashboardViewModel(
            user: testUser,
            healthMetricRepository: mockRepository
        )
    }
    
    override func tearDown() async throws {
        dashboardViewModel = nil
        mockRepository = nil
        mockAPIClient = nil
        testUser = nil
        try await super.tearDown()
    }
    
    // MARK: - Full Flow Tests
    
    @MainActor
    func test_addMetricFlow_fromEmptyDashboard_shouldShowNewMetric() async throws {
        // Given - Empty dashboard
        await dashboardViewModel.loadRecentMetrics()
        XCTAssertEqual(dashboardViewModel.metricsState, .empty)
        
        // When - User adds a new metric
        let addMetricViewModel = await AddMetricViewModel(
            repository: mockRepository,
            apiClient: mockAPIClient.asAPIClient(),
            userId: testUser.id
        )
        
        // Configure metric data
        addMetricViewModel.selectedMetricType = .heartRate
        addMetricViewModel.value = "72"
        addMetricViewModel.notes = "Resting heart rate"
        
        // Mock successful API response
        mockAPIClient.uploadHealthDataResult = .success("processing-123")
        
        // Submit metric
        let submitSuccess = await addMetricViewModel.submitMetric()
        XCTAssertTrue(submitSuccess)
        
        // Refresh dashboard
        await dashboardViewModel.refresh()
        
        // Then - Dashboard should show the new metric
        guard case .success(let metrics) = dashboardViewModel.metricsState else {
            XCTFail("Expected success state with metrics")
            return
        }
        
        XCTAssertEqual(metrics.count, 1)
        XCTAssertEqual(metrics.first?.type, .heartRate)
        XCTAssertEqual(metrics.first?.value, 72.0)
        XCTAssertEqual(metrics.first?.notes, "Resting heart rate")
    }
    
    @MainActor
    func test_addMetricFlow_withExistingMetrics_shouldAddToList() async throws {
        // Given - Dashboard with existing metrics
        let existingMetric = HealthMetric(
            userId: testUser.id,
            type: .steps,
            value: 10000,
            unit: "steps",
            recordedAt: Date().addingTimeInterval(-3600), // 1 hour ago
            source: .manual
        )
        mockRepository.metrics = [existingMetric]
        
        await dashboardViewModel.loadRecentMetrics()
        guard case .success(let initialMetrics) = dashboardViewModel.metricsState else {
            XCTFail("Expected success state")
            return
        }
        XCTAssertEqual(initialMetrics.count, 1)
        
        // When - User adds a new metric
        let addMetricViewModel = await AddMetricViewModel(
            repository: mockRepository,
            apiClient: mockAPIClient.asAPIClient(),
            userId: testUser.id
        )
        
        addMetricViewModel.selectedMetricType = .bloodPressureSystolic
        addMetricViewModel.value = "120"
        addMetricViewModel.notes = "After morning coffee"
        
        mockAPIClient.uploadHealthDataResult = .success("processing-456")
        
        let submitSuccess = await addMetricViewModel.submitMetric()
        XCTAssertTrue(submitSuccess)
        
        await dashboardViewModel.refresh()
        
        // Then - Dashboard should show both metrics
        guard case .success(let updatedMetrics) = dashboardViewModel.metricsState else {
            XCTFail("Expected success state with metrics")
            return
        }
        
        XCTAssertEqual(updatedMetrics.count, 2)
        
        // Should be sorted by most recent first
        XCTAssertEqual(updatedMetrics[0].type, .bloodPressureSystolic)
        XCTAssertEqual(updatedMetrics[0].value, 120.0)
        XCTAssertEqual(updatedMetrics[1].type, .steps)
    }
    
    @MainActor
    func test_addMetricFlow_withAPIError_shouldNotAddMetric() async throws {
        // Given - Dashboard loaded
        await dashboardViewModel.loadRecentMetrics()
        
        // When - User tries to add metric but API fails
        let addMetricViewModel = await AddMetricViewModel(
            repository: mockRepository,
            apiClient: mockAPIClient.asAPIClient(),
            userId: testUser.id
        )
        
        addMetricViewModel.selectedMetricType = .weight
        addMetricViewModel.value = "175.5"
        
        // Mock API failure
        mockAPIClient.uploadHealthDataResult = .failure(
            NetworkError.serverError(statusCode: 500, message: "Internal Server Error")
        )
        
        let submitSuccess = await addMetricViewModel.submitMetric()
        XCTAssertFalse(submitSuccess)
        XCTAssertNotNil(addMetricViewModel.errorMessage)
        
        await dashboardViewModel.refresh()
        
        // Then - No metric should be added
        XCTAssertEqual(dashboardViewModel.metricsState, .empty)
        XCTAssertEqual(mockRepository.metrics.count, 0)
    }
    
    @MainActor
    func test_addMetricFlow_withValidation_shouldPreventInvalidSubmission() async {
        // Given
        let addMetricViewModel = await AddMetricViewModel(
            repository: mockRepository,
            apiClient: mockAPIClient.asAPIClient(),
            userId: testUser.id
        )
        
        // When - Invalid heart rate value
        addMetricViewModel.selectedMetricType = .heartRate
        addMetricViewModel.value = "300" // Too high
        
        let errors = addMetricViewModel.validate()
        XCTAssertFalse(errors.isEmpty)
        
        let submitSuccess = await addMetricViewModel.submitMetric()
        
        // Then - Should not submit
        XCTAssertFalse(submitSuccess)
        XCTAssertEqual(mockAPIClient.uploadHealthDataCallCount, 0)
        XCTAssertEqual(mockRepository.metrics.count, 0)
    }
    
    @MainActor
    func test_addMetricFlow_withCompleteData_shouldStoreAllFields() async throws {
        // Given
        let addMetricViewModel = await AddMetricViewModel(
            repository: mockRepository,
            apiClient: mockAPIClient.asAPIClient(),
            userId: testUser.id
        )
        
        let testDate = Date().addingTimeInterval(-1800) // 30 minutes ago
        
        // When - Complete metric data
        addMetricViewModel.selectedMetricType = .bloodGlucose
        addMetricViewModel.value = "95"
        addMetricViewModel.notes = "Before lunch, fasting"
        addMetricViewModel.recordedAt = testDate
        
        mockAPIClient.uploadHealthDataResult = .success("processing-789")
        
        let submitSuccess = await addMetricViewModel.submitMetric()
        XCTAssertTrue(submitSuccess)
        
        // Then - All fields should be stored correctly
        XCTAssertEqual(mockRepository.metrics.count, 1)
        
        let savedMetric = mockRepository.metrics.first!
        XCTAssertEqual(savedMetric.type, .bloodGlucose)
        XCTAssertEqual(savedMetric.value, 95.0)
        XCTAssertEqual(savedMetric.unit, "mg/dL")
        XCTAssertEqual(savedMetric.notes, "Before lunch, fasting")
        XCTAssertEqual(savedMetric.recordedAt.timeIntervalSince1970, testDate.timeIntervalSince1970, accuracy: 1)
        XCTAssertEqual(savedMetric.source, .manual)
        
        // Check metadata is not stored in the domain model
        // (metadata is handled at infrastructure layer)
    }
    
    @MainActor
    func test_addMetricFlow_multipleSubmissions_shouldHandleConcurrency() async throws {
        // Given
        let viewModel1 = await AddMetricViewModel(
            repository: mockRepository,
            apiClient: mockAPIClient.asAPIClient(),
            userId: testUser.id
        )
        let viewModel2 = await AddMetricViewModel(
            repository: mockRepository,
            apiClient: mockAPIClient.asAPIClient(),
            userId: testUser.id
        )
        
        // Configure both submissions
        viewModel1.selectedMetricType = .heartRate
        viewModel1.value = "65"
        
        viewModel2.selectedMetricType = .steps
        viewModel2.value = "5000"
        
        mockAPIClient.uploadHealthDataResult = .success("processing-concurrent")
        
        // When - Submit both concurrently
        async let submit1 = viewModel1.submitMetric()
        async let submit2 = viewModel2.submitMetric()
        
        let results = await (submit1, submit2)
        
        // Then - Both should succeed
        XCTAssertTrue(results.0)
        XCTAssertTrue(results.1)
        
        XCTAssertEqual(mockRepository.metrics.count, 2)
        XCTAssertEqual(mockAPIClient.uploadHealthDataCallCount, 2)
        
        // Verify both metrics were saved
        let heartRateMetric = mockRepository.metrics.first { $0.type == .heartRate }
        let stepsMetric = mockRepository.metrics.first { $0.type == .steps }
        
        XCTAssertNotNil(heartRateMetric)
        XCTAssertEqual(heartRateMetric?.value, 65.0)
        
        XCTAssertNotNil(stepsMetric)
        XCTAssertEqual(stepsMetric?.value, 5000.0)
    }
}

// MARK: - Mock Repository

private final class MockHealthMetricRepository: HealthMetricRepositoryProtocol, @unchecked Sendable {
    var metrics: [HealthMetric] = []
    
    func create(_ metric: HealthMetric) async throws -> HealthMetric {
        metrics.append(metric)
        return metric
    }
    
    func createBatch(_ metrics: [HealthMetric]) async throws -> [HealthMetric] {
        self.metrics.append(contentsOf: metrics)
        return metrics
    }
    
    func findById(_ id: UUID) async throws -> HealthMetric? {
        metrics.first { $0.id == id }
    }
    
    func findByUserId(_ userId: UUID) async throws -> [HealthMetric] {
        metrics.filter { $0.userId == userId }
    }
    
    func findByUserIdAndDateRange(
        userId: UUID,
        startDate: Date,
        endDate: Date
    ) async throws -> [HealthMetric] {
        metrics.filter { metric in
            metric.userId == userId && 
            metric.recordedAt >= startDate && 
            metric.recordedAt <= endDate
        }
    }
    
    func findByUserIdAndType(
        userId: UUID,
        type: HealthMetricType
    ) async throws -> [HealthMetric] {
        metrics.filter { $0.userId == userId && $0.type == type }
    }
    
    func update(_ metric: HealthMetric) async throws -> HealthMetric {
        if let index = metrics.firstIndex(where: { $0.id == metric.id }) {
            metrics[index] = metric
        }
        return metric
    }
    
    func delete(_ id: UUID) async throws {
        metrics.removeAll { $0.id == id }
    }
    
    func deleteAllForUser(_ userId: UUID) async throws {
        metrics.removeAll { $0.userId == userId }
    }
    
    func getLatestByType(
        userId: UUID,
        type: HealthMetricType
    ) async throws -> HealthMetric? {
        metrics
            .filter { $0.userId == userId && $0.type == type }
            .sorted { $0.recordedAt > $1.recordedAt }
            .first
    }
}

// MARK: - Mock API Client

private final class MockAPIClient {
    var uploadHealthDataResult: Result<String, Error> = .success("12345")
    var uploadHealthDataCallCount = 0
    let lock = NSLock()
    private let apiClient: APIClient
    private let mockNetwork: MockNetworkService
    
    init() {
        self.mockNetwork = MockNetworkService()
        self.apiClient = APIClient(networkService: mockNetwork)
        self.mockNetwork.parent = self
    }
    
    func asAPIClient() -> APIClient {
        apiClient
    }
}

private final class MockNetworkService: NetworkServiceProtocol, @unchecked Sendable {
    weak var parent: MockAPIClient?
    
    func request<T>(_ endpoint: Endpoint, type: T.Type) async throws -> T where T: Decodable {
        // Handle health data upload
        if endpoint.path == "/api/v1/health-data/" && endpoint.method == .post {
            parent?.lock.withLock {
                parent?.uploadHealthDataCallCount += 1
            }
            
            switch parent?.uploadHealthDataResult ?? .success("12345") {
            case .success(let id):
                let response = HealthDataResponse(
                    processing_id: id,
                    status: "success",
                    message: "Mock upload successful"
                )
                if let data = try? JSONEncoder().encode(response),
                   let decoded = try? JSONDecoder().decode(T.self, from: data) {
                    return decoded
                }
            case .failure(let error):
                throw error
            }
        }
        fatalError("Not implemented for endpoint: \(endpoint.path)")
    }
    
    func request(_ endpoint: Endpoint) async throws -> Data {
        fatalError("Not implemented for tests")
    }
    
    func upload(
        _ endpoint: Endpoint,
        data: Data,
        progressHandler: ((Double) -> Void)?
    ) async throws -> Data {
        fatalError("Not implemented for tests")
    }
    
    func download(
        _ endpoint: Endpoint,
        progressHandler: ((Double) -> Void)?
    ) async throws -> URL {
        fatalError("Not implemented for tests")
    }
}

// Mock response type matching API response
private struct HealthDataResponse: Codable {
    let processing_id: String
    let status: String
    let message: String
}
