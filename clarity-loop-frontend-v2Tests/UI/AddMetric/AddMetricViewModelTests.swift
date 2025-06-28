//
//  AddMetricViewModelTests.swift
//  clarity-loop-frontend-v2Tests
//
//  TDD tests for Add Metric functionality
//

import XCTest
@testable import ClarityUI
@testable import ClarityDomain
@testable import ClarityData
@testable import ClarityCore

final class AddMetricViewModelTests: XCTestCase {
    
    // MARK: - Properties
    
    private var sut: AddMetricViewModel!
    private var mockRepository: MockHealthMetricRepository!
    private var mockAPIClient: MockAPIClient!
    private var testUserId: UUID!
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        testUserId = UUID()
        mockRepository = MockHealthMetricRepository()
        mockAPIClient = MockAPIClient()
        sut = await AddMetricViewModel(
            repository: mockRepository,
            apiClient: mockAPIClient.asAPIClient(),
            userId: testUserId
        )
    }
    
    override func tearDown() async throws {
        sut = nil
        mockRepository = nil
        mockAPIClient = nil
        testUserId = nil
        try await super.tearDown()
    }
    
    // MARK: - Initial State Tests
    
    @MainActor
    func test_initialState_shouldHaveEmptyForm() {
        // Then
        XCTAssertEqual(sut.selectedMetricType, .heartRate)
        XCTAssertEqual(sut.value, "")
        XCTAssertEqual(sut.notes, "")
        XCTAssertNotNil(sut.recordedAt)
        XCTAssertFalse(sut.isSubmitting)
        XCTAssertNil(sut.errorMessage)
        XCTAssertTrue(sut.validationErrors.isEmpty)
    }
    
    // MARK: - Validation Tests
    
    @MainActor
    func test_validation_withEmptyValue_shouldHaveError() {
        // When
        sut.value = ""
        let errors = sut.validate()
        
        // Then
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains("Value is required"))
    }
    
    @MainActor
    func test_validation_withInvalidValue_shouldHaveError() {
        // When
        sut.value = "abc"
        let errors = sut.validate()
        
        // Then
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains("Value must be a valid number"))
    }
    
    @MainActor
    func test_validation_withValueOutOfRange_shouldHaveError() {
        // Given
        sut.selectedMetricType = .heartRate
        
        // When - heart rate too low
        sut.value = "20"
        var errors = sut.validate()
        
        // Then
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains("Heart Rate must be between 40 and 200 BPM"))
        
        // When - heart rate too high
        sut.value = "300"
        errors = sut.validate()
        
        // Then
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains("Heart Rate must be between 40 and 200 BPM"))
    }
    
    @MainActor
    func test_validation_withValidValue_shouldHaveNoErrors() {
        // Given
        sut.selectedMetricType = .heartRate
        
        // When
        sut.value = "72"
        let errors = sut.validate()
        
        // Then
        XCTAssertTrue(errors.isEmpty)
    }
    
    @MainActor
    func test_validation_withFutureDate_shouldHaveError() {
        // When
        sut.recordedAt = Date().addingTimeInterval(86400) // Tomorrow
        let errors = sut.validate()
        
        // Then
        XCTAssertFalse(errors.isEmpty)
        XCTAssertTrue(errors.contains("Date cannot be in the future"))
    }
    
    // MARK: - Submit Tests
    
    @MainActor
    func test_submitMetric_withValidData_shouldSucceed() async throws {
        // Given
        sut.selectedMetricType = .heartRate
        sut.value = "72"
        sut.notes = "After morning walk"
        
        mockAPIClient.uploadHealthDataResult = .success("12345")
        
        // When
        let success = await sut.submitMetric()
        
        // Then
        XCTAssertTrue(success)
        XCTAssertFalse(sut.isSubmitting)
        XCTAssertNil(sut.errorMessage)
        
        // Verify API was called
        XCTAssertEqual(mockAPIClient.uploadHealthDataCallCount, 1)
        
        // Verify correct data was sent
        if let uploadedData = mockAPIClient.lastUploadedHealthData {
            XCTAssertEqual(uploadedData.data_type, "heart_rate")
            XCTAssertEqual(uploadedData.value, 72.0)
            XCTAssertEqual(uploadedData.unit, "BPM")
        } else {
            XCTFail("No health data was uploaded")
        }
        
        // Verify metric was saved locally
        XCTAssertEqual(mockRepository.savedMetrics.count, 1)
        if let savedMetric = mockRepository.savedMetrics.first {
            XCTAssertEqual(savedMetric.type, .heartRate)
            XCTAssertEqual(savedMetric.value, 72.0)
            XCTAssertEqual(savedMetric.notes, "After morning walk")
        }
    }
    
    @MainActor
    func test_submitMetric_withInvalidData_shouldFail() async {
        // Given
        sut.value = "" // Invalid
        
        // When
        let success = await sut.submitMetric()
        
        // Then
        XCTAssertFalse(success)
        XCTAssertFalse(sut.validationErrors.isEmpty)
        XCTAssertEqual(mockAPIClient.uploadHealthDataCallCount, 0)
        XCTAssertEqual(mockRepository.savedMetrics.count, 0)
    }
    
    @MainActor
    func test_submitMetric_withAPIError_shouldShowError() async {
        // Given
        sut.selectedMetricType = .steps
        sut.value = "10000"
        
        mockAPIClient.uploadHealthDataResult = .failure(NetworkError.offline)
        
        // When
        let success = await sut.submitMetric()
        
        // Then
        XCTAssertFalse(success)
        XCTAssertEqual(sut.errorMessage, "No internet connection")
        XCTAssertFalse(sut.isSubmitting)
        
        // Verify API was called but local save didn't happen
        XCTAssertEqual(mockAPIClient.uploadHealthDataCallCount, 1)
        XCTAssertEqual(mockRepository.savedMetrics.count, 0)
    }
    
    @MainActor
    func test_submitMetric_shouldPreventDoubleSubmission() async {
        // Given
        sut.selectedMetricType = .bloodPressureSystolic
        sut.value = "120"
        
        // Slow API response
        mockAPIClient.uploadHealthDataDelay = 0.5
        mockAPIClient.uploadHealthDataResult = .success("12345")
        
        // When - submit twice quickly
        Task {
            _ = await sut.submitMetric()
        }
        
        // Brief delay to ensure first submission starts
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        let secondSubmitResult = await sut.submitMetric()
        
        // Then
        XCTAssertFalse(secondSubmitResult) // Second submit should fail
        XCTAssertEqual(mockAPIClient.uploadHealthDataCallCount, 1) // Only one API call
    }
    
    // MARK: - Form Reset Tests
    
    @MainActor
    func test_resetForm_shouldClearAllFields() {
        // Given
        sut.selectedMetricType = .steps
        sut.value = "5000"
        sut.notes = "Morning run"
        sut.errorMessage = "Some error"
        sut.validationErrors = ["Error 1", "Error 2"]
        
        // When
        sut.resetForm()
        
        // Then
        XCTAssertEqual(sut.selectedMetricType, .heartRate) // Default
        XCTAssertEqual(sut.value, "")
        XCTAssertEqual(sut.notes, "")
        XCTAssertNil(sut.errorMessage)
        XCTAssertTrue(sut.validationErrors.isEmpty)
    }
}

// MARK: - Mock Types

enum MockRepositoryError: Error {
    case saveFailed
}

private final class MockHealthMetricRepository: HealthMetricRepositoryProtocol, @unchecked Sendable {
    var savedMetrics: [HealthMetric] = []
    var shouldFailSave = false
    
    func create(_ metric: HealthMetric) async throws -> HealthMetric {
        if shouldFailSave {
            throw MockRepositoryError.saveFailed
        }
        savedMetrics.append(metric)
        return metric
    }
    
    func createBatch(_ metrics: [HealthMetric]) async throws -> [HealthMetric] {
        savedMetrics.append(contentsOf: metrics)
        return metrics
    }
    
    func findById(_ id: UUID) async throws -> HealthMetric? {
        savedMetrics.first { $0.id == id }
    }
    
    func findByUserId(_ userId: UUID) async throws -> [HealthMetric] {
        savedMetrics.filter { $0.userId == userId }
    }
    
    func findByUserIdAndDateRange(userId: UUID, startDate: Date, endDate: Date) async throws -> [HealthMetric] {
        savedMetrics.filter { metric in
            metric.userId == userId && metric.recordedAt >= startDate && metric.recordedAt <= endDate
        }
    }
    
    func findByUserIdAndType(userId: UUID, type: HealthMetricType) async throws -> [HealthMetric] {
        savedMetrics.filter { $0.userId == userId && $0.type == type }
    }
    
    func update(_ metric: HealthMetric) async throws -> HealthMetric {
        if let index = savedMetrics.firstIndex(where: { $0.id == metric.id }) {
            savedMetrics[index] = metric
        }
        return metric
    }
    
    func delete(_ id: UUID) async throws {
        savedMetrics.removeAll { $0.id == id }
    }
    
    func deleteAllForUser(_ userId: UUID) async throws {
        savedMetrics.removeAll { $0.userId == userId }
    }
    
    func getLatestByType(userId: UUID, type: HealthMetricType) async throws -> HealthMetric? {
        savedMetrics
            .filter { $0.userId == userId && $0.type == type }
            .sorted { $0.recordedAt > $1.recordedAt }
            .first
    }
}

private final class MockAPIClient {
    var uploadHealthDataResult: Result<String, Error> = .success("12345")
    var uploadHealthDataCallCount = 0
    var uploadHealthDataDelay: TimeInterval = 0
    var lastUploadedHealthData: HealthDataUpload?
    
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
            parent?.uploadHealthDataCallCount += 1
            
            // Extract the upload data
            if let body = endpoint.body,
               let uploadData = try? JSONDecoder().decode(HealthDataUpload.self, from: body) {
                parent?.lastUploadedHealthData = uploadData
            }
            
            if let delay = parent?.uploadHealthDataDelay, delay > 0 {
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
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
        fatalError("Not implemented")
    }
    
    func upload(
        _ endpoint: Endpoint,
        data: Data,
        progressHandler: ((Double) -> Void)?
    ) async throws -> Data {
        fatalError("Not implemented")
    }
    
    func download(
        _ endpoint: Endpoint,
        progressHandler: ((Double) -> Void)?
    ) async throws -> URL {
        fatalError("Not implemented")
    }
}

// Mock response type matching API response
private struct HealthDataResponse: Codable {
    let processing_id: String
    let status: String
    let message: String
}
