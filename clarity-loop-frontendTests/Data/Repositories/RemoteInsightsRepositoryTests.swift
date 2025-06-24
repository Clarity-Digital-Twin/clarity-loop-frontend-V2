@testable import clarity_loop_frontend
import XCTest

final class RemoteInsightsRepositoryTests: XCTestCase {
    var insightsRepository: RemoteInsightsRepository!
    var mockAPIClient: MockAPIClient!

    override func setUpWithError() throws {
        try super.setUpWithError()
        mockAPIClient = MockAPIClient()
        insightsRepository = RemoteInsightsRepository(apiClient: mockAPIClient)
    }

    override func tearDownWithError() throws {
        insightsRepository = nil
        mockAPIClient = nil
        try super.tearDownWithError()
    }

    // MARK: - Test Cases

    func testFetchInsights_Success() async throws {
        // Given
        mockAPIClient.shouldSucceed = true

        // When
        let insights = try await insightsRepository.getInsightHistory(userId: "test", limit: 10, offset: 0)

        // Then
        XCTAssertNotNil(insights)
        XCTAssertTrue(insights.success)
    }

    func testFetchInsights_Failure() async throws {
        // Given: API client configured to fail
        mockAPIClient.shouldSucceed = false
        mockAPIClient.mockError = APIError.serverError(statusCode: 500, message: "Internal server error")

        // When / Then: Should throw error
        do {
            _ = try await insightsRepository.getInsightHistory(userId: "test", limit: 10, offset: 0)
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertNotNil(error, "Should have error when API fails")
            
            // Verify it's the expected error type
            if let apiError = error as? APIError {
                switch apiError {
                case .serverError(let statusCode, let message):
                    XCTAssertEqual(statusCode, 500, "Should be server error")
                    XCTAssertEqual(message, "Internal server error", "Should have correct error message")
                default:
                    XCTFail("Wrong error type: \(apiError)")
                }
            } else if error is APIError {
                // The error is an APIError but can't be cast properly
                XCTAssertTrue(true, "Error is an APIError")
            } else {
                XCTFail("Expected APIError but got: \(type(of: error))")
            }
        }
    }

    func testFetchInsights_Empty() async throws {
        // Given
        mockAPIClient.shouldSucceed = true
        // You might need to configure your mock to return an empty array specifically

        // When
        let insights = try await insightsRepository.getInsightHistory(userId: "test", limit: 10, offset: 0)

        // Then
        XCTAssertNotNil(insights)
        XCTAssertTrue(insights.success)
        XCTAssertTrue(insights.data.insights.isEmpty)
    }
    
    // MARK: - Additional Tests
    
    func testGenerateInsight_Success() async throws {
        // Given: Mock API client configured for success
        mockAPIClient.shouldSucceed = true
        let requestDTO = InsightGenerationRequestDTO(
            analysisResults: ["steps": 10000, "heart_rate": 72],
            context: "Daily activity summary",
            insightType: "daily_summary",
            includeRecommendations: true,
            language: "en"
        )
        
        // When: Generate insight
        let response = try await insightsRepository.generateInsight(requestDTO: requestDTO)
        
        // Then: Verify successful response
        XCTAssertNotNil(response, "Should return response")
        XCTAssertTrue(response.success, "Should be successful")
        XCTAssertNotNil(response.data, "Should have insight data")
        XCTAssertEqual(response.data.userId, "test-user", "Should have user ID")
        XCTAssertEqual(response.data.narrative, "Generated insight", "Should have narrative")
        XCTAssertTrue(mockAPIClient.generateInsightCalled, "Should call generateInsight")
        XCTAssertNotNil(mockAPIClient.capturedInsightRequest, "Should capture request")
    }
    
    func testGenerateInsight_Failure() async throws {
        // Given: Mock API client configured to fail
        mockAPIClient.shouldSucceed = false
        mockAPIClient.mockError = APIError.serverError(statusCode: 503, message: "Service unavailable")
        let requestDTO = InsightGenerationRequestDTO(
            analysisResults: ["steps": 1000],
            context: "Low activity",
            insightType: "activity_alert",
            includeRecommendations: false,
            language: "en"
        )
        
        // When/Then: Should throw error
        do {
            _ = try await insightsRepository.generateInsight(requestDTO: requestDTO)
            XCTFail("Should have thrown an error")
        } catch {
            XCTAssertNotNil(error, "Should have error")
            XCTAssertTrue(mockAPIClient.generateInsightCalled, "Should attempt to call generateInsight")
        }
    }
    
    func testCheckServiceStatus_Success() async throws {
        // Given: Mock healthy service status
        mockAPIClient.shouldSucceed = true
        mockAPIClient.mockServiceStatus = ServiceStatusResponseDTO(
            service: "insights",
            status: "healthy",
            version: "2.0.0",
            timestamp: Date(),
            dependencies: [
                DependencyStatusDTO(
                    name: "database",
                    status: "healthy",
                    responseTime: 25
                ),
                DependencyStatusDTO(
                    name: "ai-model",
                    status: "healthy",
                    responseTime: 150
                )
            ],
            metrics: ServiceMetricsDTO(
                requestsPerMinute: 200,
                averageResponseTime: 175,
                errorRate: 0.005,
                uptime: 0.9999
            )
        )
        
        // When: Check service status
        let status = try await insightsRepository.checkServiceStatus()
        
        // Then: Verify healthy status
        XCTAssertNotNil(status, "Should return status")
        XCTAssertEqual(status.status, "healthy", "Should be healthy")
        XCTAssertEqual(status.version, "2.0.0", "Should have correct version")
        XCTAssertEqual(status.dependencies?.count, 2, "Should have 2 dependencies")
        XCTAssertNotNil(status.metrics, "Should have metrics")
        XCTAssertEqual(status.metrics?.requestsPerMinute, 200, "Should have correct RPM")
    }
    
    func testCheckServiceStatus_Degraded() async throws {
        // Given: Mock degraded service status
        mockAPIClient.shouldSucceed = true
        mockAPIClient.mockServiceStatus = ServiceStatusResponseDTO(
            service: "insights",
            status: "degraded",
            version: "2.0.0",
            timestamp: Date(),
            dependencies: [
                DependencyStatusDTO(
                    name: "database",
                    status: "healthy",
                    responseTime: 50
                ),
                DependencyStatusDTO(
                    name: "ai-model",
                    status: "unhealthy",
                    responseTime: 5000
                )
            ],
            metrics: ServiceMetricsDTO(
                requestsPerMinute: 50,
                averageResponseTime: 2500,
                errorRate: 0.15,
                uptime: 0.95
            )
        )
        
        // When: Check service status
        let status = try await insightsRepository.checkServiceStatus()
        
        // Then: Verify degraded status
        XCTAssertEqual(status.status, "degraded", "Should be degraded")
        XCTAssertEqual(status.dependencies?.last?.status, "unhealthy", "AI model should be unhealthy")
        XCTAssertEqual(status.metrics?.errorRate, 0.15, "Should have high error rate")
    }
    
    func testPagination_NextPage() async throws {
        // Given: Mock response with pagination
        mockAPIClient.shouldSucceed = true
        mockAPIClient.mockInsightHistory = InsightHistoryResponseDTO(
            success: true,
            data: InsightHistoryDataDTO(
                insights: [
                    InsightPreviewDTO(
                        id: "1",
                        title: "Daily Summary 1",
                        summary: "Summary 1",
                        keyInsightsCount: 3,
                        confidenceScore: 0.9,
                        generatedAt: Date()
                    ),
                    InsightPreviewDTO(
                        id: "2",
                        title: "Daily Summary 2",
                        summary: "Summary 2",
                        keyInsightsCount: 2,
                        confidenceScore: 0.85,
                        generatedAt: Date()
                    )
                ],
                totalCount: 50,
                hasMore: true,
                pagination: PaginationMetaDTO(
                    page: 2,
                    limit: 10
                )
            ),
            metadata: nil
        )
        
        // When: Fetch second page
        let insights = try await insightsRepository.getInsightHistory(userId: "test", limit: 10, offset: 10)
        
        // Then: Verify pagination
        XCTAssertEqual(insights.data.insights.count, 2, "Should have 2 insights")
        XCTAssertTrue(insights.data.hasMore, "Should have more pages")
        XCTAssertEqual(insights.data.pagination?.page, 2, "Should be on page 2")
        XCTAssertEqual(insights.data.totalCount, 50, "Should have 50 total insights")
    }
}
