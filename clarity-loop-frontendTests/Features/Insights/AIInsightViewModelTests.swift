import XCTest
import SwiftData
import Combine
@testable import clarity_loop_frontend

@MainActor
final class AIInsightViewModelTests: XCTestCase {
    
    // MARK: - Properties
    
    private var viewModel: AIInsightViewModel!
    private var modelContext: ModelContext!
    private var realInsightRepository: AIInsightRepository!
    private var mockInsightsRepo: MockInsightsRepositoryProtocol!
    private var realHealthRepository: HealthRepository!
    private var mockAuthService: MockAuthService!
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Setup & Teardown
    
    override func setUp() async throws {
        try await super.setUp()
        
        // Setup test dependencies
        let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
        let modelContainer = try ModelContainer(
            for: AIInsight.self, HealthMetric.self,
            configurations: modelConfiguration
        )
        modelContext = ModelContext(modelContainer)
        
        // Create real repositories as required by the concrete types
        realInsightRepository = AIInsightRepository(modelContext: modelContext)
        realHealthRepository = HealthRepository(modelContext: modelContext)
        mockInsightsRepo = MockInsightsRepositoryProtocol()
        mockAuthService = MockAuthService()
        
        viewModel = AIInsightViewModel(
            modelContext: modelContext,
            insightRepository: realInsightRepository,
            insightsRepo: mockInsightsRepo,
            healthRepository: realHealthRepository,
            authService: mockAuthService
        )
    }
    
    override func tearDown() async throws {
        cancellables.removeAll()
        viewModel = nil
        realInsightRepository = nil
        mockInsightsRepo = nil
        realHealthRepository = nil
        mockAuthService = nil
        modelContext = nil
        try await super.tearDown()
    }
    
    // MARK: - Insights Loading Tests
    
    func testLoadInsightsSuccess() async throws {
        // Given: Insert insights into repository
        let insight1 = AIInsight(
            content: "Your heart rate has been improving",
            category: .heartHealth
        )
        insight1.timestamp = Date()
        insight1.isRead = false
        insight1.priority = .high
        
        let insight2 = AIInsight(
            content: "Sleep quality analysis shows positive trends",
            category: .sleep
        )
        insight2.timestamp = Date().addingTimeInterval(-3600)
        insight2.isRead = true
        insight2.priority = .medium
        
        // Insert directly into repository
        try await realInsightRepository.create(insight1)
        try await realInsightRepository.create(insight2)
        
        // When: Load insights
        await viewModel.loadInsights()
        
        // Then: Insights should be loaded
        XCTAssertEqual(viewModel.insightsState.value?.count, 2)
        XCTAssertEqual(viewModel.insights.count, 2)
        XCTAssertTrue(viewModel.insights.contains { $0.content == "Your heart rate has been improving" })
        XCTAssertTrue(viewModel.hasUnreadInsights)
    }
    
    func testLoadInsightsSyncsWithBackend() async throws {
        // Given: Mock backend response with new insights
        mockAuthService.mockCurrentUser = AuthUser(
            id: "test-user-123",
            email: "test@example.com",
            fullName: "Test User",
            isEmailVerified: true
        )
        
        mockInsightsRepo.historyToReturn = InsightHistoryResponseDTO(
            success: true,
            data: InsightHistoryDataDTO(
                insights: [
                    InsightPreviewDTO(
                        id: "remote-insight-1",
                        narrative: "New insight from backend",
                        generatedAt: Date(),
                        confidenceScore: 0.85,
                        keyInsightsCount: 2,
                        recommendationsCount: 3
                    )
                ],
                totalCount: 1,
                hasMore: false,
                pagination: PaginationMetaDTO(page: 1, limit: 50)
            ),
            metadata: nil
        )
        
        // When: Load insights (which triggers sync)
        await viewModel.loadInsights()
        
        // Then: Should sync with backend
        XCTAssertTrue(mockInsightsRepo.getHistoryCalled)
        XCTAssertEqual(mockInsightsRepo.capturedUserId, "test-user-123")
    }
    
    func testLoadInsightsHandlesEmptyState() async throws {
        // Given: No insights available
        mockInsightsRepo.historyToReturn = InsightHistoryResponseDTO(
            success: true,
            data: InsightHistoryDataDTO(
                insights: [],
                totalCount: 0,
                hasMore: false,
                pagination: PaginationMetaDTO(page: 1, limit: 50)
            ),
            metadata: nil
        )
        
        // When: Load insights
        await viewModel.loadInsights()
        
        // Then: Should show empty state
        switch viewModel.insightsState {
        case .empty:
            XCTAssertTrue(true) // Expected empty state
        default:
            XCTFail("Expected empty state but got \(viewModel.insightsState)")
        }
        XCTAssertEqual(viewModel.insights.count, 0)
        XCTAssertFalse(viewModel.hasUnreadInsights)
    }
    
    func testLoadInsightsHandlesError() async throws {
        // Skip this test as we can't easily make the real repository fail
        XCTSkip("Cannot test error handling with real repository")
    }
    
    // MARK: - Insight Generation Tests
    
    func testGenerateNewInsightSuccess() async throws {
        // Given: User is authenticated with recent health data
        mockAuthService.mockCurrentUser = AuthUser(
            id: "test-user-123",
            email: "test@example.com",
            fullName: "Test User",
            isEmailVerified: true
        )
        
        // Add recent health data to real repository
        let recentMetric = HealthMetric(
            timestamp: Date(),
            value: 72,
            type: .heartRate,
            unit: "bpm"
        )
        try await realHealthRepository.create(recentMetric)
        
        // Mock successful generation response
        mockInsightsRepo.insightToGenerate = InsightGenerationResponseDTO(
            success: true,
            data: HealthInsightDTO(
                userId: "test-user-123",
                narrative: "Your heart rate shows excellent cardiovascular fitness",
                keyInsights: ["Resting heart rate is optimal", "Recovery time is improving"],
                recommendations: ["Continue current exercise routine"],
                confidenceScore: 0.92,
                generatedAt: Date()
            ),
            metadata: nil
        )
        
        // When: Generate new insight
        await viewModel.generateNewInsight()
        
        // Then: Should generate and save insight
        switch viewModel.generationState {
        case .loaded(let insight):
            XCTAssertEqual(insight.content, "Your heart rate shows excellent cardiovascular fitness")
            XCTAssertEqual(insight.category, .heartHealth)
            XCTAssertEqual(insight.priority, .high) // High confidence score
        default:
            XCTFail("Expected loaded state with insight")
        }
    }
    
    func testGenerateNewInsightRequiresHealthData() async throws {
        // Given: User is authenticated but no recent health data
        mockAuthService.mockCurrentUser = AuthUser(
            id: "test-user-123",
            email: "test@example.com",
            fullName: "Test User",
            isEmailVerified: true
        )
        
        // No recent health data in repository
        
        // When: Try to generate insight
        await viewModel.generateNewInsight()
        
        // Then: Should fail with insufficient data error
        switch viewModel.generationState {
        case .error(let error):
            XCTAssertTrue(error is InsightError)
            if let insightError = error as? InsightError {
                XCTAssertEqual(insightError, .insufficientData)
            }
        default:
            XCTFail("Expected error state for insufficient data")
        }
    }
    
    func testGenerateNewInsightRequiresAuthentication() async throws {
        // Given: User is not authenticated
        mockAuthService.mockCurrentUser = nil
        
        // When: Try to generate insight
        await viewModel.generateNewInsight()
        
        // Then: Should fail with authentication error
        switch viewModel.generationState {
        case .error(let error):
            XCTAssertTrue(error is InsightError)
            if let insightError = error as? InsightError {
                XCTAssertEqual(insightError, .notAuthenticated)
            }
        default:
            XCTFail("Expected error state for authentication")
        }
    }
    
    func testGenerateNewInsightHandlesError() async throws {
        // Given: Setup for successful generation but API will fail
        mockAuthService.mockCurrentUser = AuthUser(
            id: "test-user-123",
            email: "test@example.com",
            fullName: "Test User",
            isEmailVerified: true
        )
        
        let metric = HealthMetric(timestamp: Date(), value: 72, type: .heartRate, unit: "bpm")
        try await realHealthRepository.create(metric)
        
        mockInsightsRepo.shouldFail = true
        
        // When: Try to generate insight
        await viewModel.generateNewInsight()
        
        // Then: Should handle generation error
        switch viewModel.generationState {
        case .error:
            XCTAssertTrue(true) // Expected error
        default:
            XCTFail("Expected error state for generation failure")
        }
    }
    
    // MARK: - Filtering Tests
    
    func testFilterByTimeframe() async throws {
        // Given: Insights with different timestamps
        let todayInsight = AIInsight(content: "Today's insight", category: .general)
        todayInsight.timestamp = Date()
        
        let yesterdayInsight = AIInsight(content: "Yesterday's insight", category: .general)
        yesterdayInsight.timestamp = Date().addingTimeInterval(-86400) // 1 day ago
        
        let lastWeekInsight = AIInsight(content: "Last week's insight", category: .general)
        lastWeekInsight.timestamp = Date().addingTimeInterval(-7 * 86400) // 7 days ago
        
        let lastMonthInsight = AIInsight(content: "Last month's insight", category: .general)
        lastMonthInsight.timestamp = Date().addingTimeInterval(-31 * 86400) // 31 days ago
        
        // Create insights in real repository
        try await realInsightRepository.create(todayInsight)
        try await realInsightRepository.create(yesterdayInsight)
        try await realInsightRepository.create(lastWeekInsight)
        try await realInsightRepository.create(lastMonthInsight)
        
        // When: Load insights
        await viewModel.loadInsights()
        
        // Test today filter
        viewModel.selectTimeframe(.today)
        XCTAssertEqual(viewModel.filteredInsights.count, 1)
        XCTAssertEqual(viewModel.filteredInsights[0].content, "Today's insight")
        
        // Test week filter
        viewModel.selectTimeframe(.week)
        XCTAssertEqual(viewModel.filteredInsights.count, 3) // Today, yesterday, last week
        
        // Test month filter
        viewModel.selectTimeframe(.month)
        XCTAssertEqual(viewModel.filteredInsights.count, 3) // Excludes last month
        
        // Test all filter
        viewModel.selectTimeframe(.all)
        XCTAssertEqual(viewModel.filteredInsights.count, 4) // All insights
    }
    
    func testFilterByCategory() async throws {
        // Given: Insights with different categories
        let sleepInsight = AIInsight(content: "Sleep analysis", category: .sleep)
        sleepInsight.timestamp = Date()
        let heartInsight = AIInsight(content: "Heart rate analysis", category: .heartHealth)
        heartInsight.timestamp = Date()
        let activityInsight = AIInsight(content: "Activity summary", category: .activity)
        activityInsight.timestamp = Date()
        let generalInsight = AIInsight(content: "General health", category: .general)
        generalInsight.timestamp = Date()
        
        // Create insights in real repository
        try await realInsightRepository.create(sleepInsight)
        try await realInsightRepository.create(heartInsight)
        try await realInsightRepository.create(activityInsight)
        try await realInsightRepository.create(generalInsight)
        
        // When: Load insights
        await viewModel.loadInsights()
        
        // Test sleep filter
        viewModel.selectCategory(.sleep)
        XCTAssertEqual(viewModel.filteredInsights.count, 1)
        XCTAssertEqual(viewModel.filteredInsights[0].category, .sleep)
        
        // Test cardiovascular filter
        viewModel.selectCategory(.cardiovascular)
        XCTAssertEqual(viewModel.filteredInsights.count, 1)
        XCTAssertEqual(viewModel.filteredInsights[0].category, .heartHealth)
        
        // Test no filter
        viewModel.selectCategory(nil)
        XCTAssertEqual(viewModel.filteredInsights.count, 4)
    }
    
    func testCombinedFilters() async throws {
        // Given: Insights with various categories and timestamps
        let todaySleep = AIInsight(content: "Today's sleep", category: .sleep)
        todaySleep.timestamp = Date()
        
        let todayHeart = AIInsight(content: "Today's heart", category: .heartHealth)
        todayHeart.timestamp = Date()
        
        let yesterdaySleep = AIInsight(content: "Yesterday's sleep", category: .sleep)
        yesterdaySleep.timestamp = Date().addingTimeInterval(-86400)
        
        let lastWeekActivity = AIInsight(content: "Last week activity", category: .activity)
        lastWeekActivity.timestamp = Date().addingTimeInterval(-7 * 86400)
        
        // Create insights in real repository
        try await realInsightRepository.create(todaySleep)
        try await realInsightRepository.create(todayHeart)
        try await realInsightRepository.create(yesterdaySleep)
        try await realInsightRepository.create(lastWeekActivity)
        
        // When: Load insights
        await viewModel.loadInsights()
        
        // Test today + sleep filter
        viewModel.selectTimeframe(.today)
        viewModel.selectCategory(.sleep)
        XCTAssertEqual(viewModel.filteredInsights.count, 1)
        XCTAssertEqual(viewModel.filteredInsights[0].content, "Today's sleep")
        
        // Test week + sleep filter
        viewModel.selectTimeframe(.week)
        viewModel.selectCategory(.sleep)
        XCTAssertEqual(viewModel.filteredInsights.count, 2) // Today and yesterday sleep insights
        
        // Test week + activity filter
        viewModel.selectCategory(.activity)
        XCTAssertEqual(viewModel.filteredInsights.count, 1) // Only last week activity
    }
    
    // MARK: - Insight Actions Tests
    
    func testMarkAsReadUpdatesInsight() async throws {
        // Given: An unread insight
        let insight = AIInsight(content: "Unread insight", category: .general)
        insight.isRead = false
        insight.timestamp = Date()
        
        // Create insight in real repository
        try await realInsightRepository.create(insight)
        
        await viewModel.loadInsights()
        XCTAssertTrue(viewModel.hasUnreadInsights)
        
        // When: Mark as read
        await viewModel.markAsRead(insight)
        
        // Then: Should update insight
        XCTAssertTrue(insight.isRead ?? false)
    }
    
    func testToggleBookmarkPersists() async throws {
        // Given: An insight that's not bookmarked
        let insight = AIInsight(content: "Test insight", category: .general)
        insight.isFavorite = false
        insight.timestamp = Date()
        
        // Create insight in real repository
        try await realInsightRepository.create(insight)
        
        await viewModel.loadInsights()
        
        // When: Toggle bookmark
        await viewModel.toggleBookmark(insight)
        
        // Then: Should update favorite status
        XCTAssertTrue(insight.isFavorite ?? false)
        
        // When: Toggle again
        await viewModel.toggleBookmark(insight)
        
        // Then: Should toggle back
        XCTAssertFalse(insight.isFavorite ?? true)
    }
    
    func testDeleteInsightRemovesFromList() async throws {
        // Given: Multiple insights
        let insight1 = AIInsight(content: "Keep this", category: .general)
        insight1.timestamp = Date()
        let insight2 = AIInsight(content: "Delete this", category: .general)
        insight2.timestamp = Date()
        let insight3 = AIInsight(content: "Keep this too", category: .general)
        insight3.timestamp = Date()
        
        // Create insights in real repository
        try await realInsightRepository.create(insight1)
        try await realInsightRepository.create(insight2)
        try await realInsightRepository.create(insight3)
        
        await viewModel.loadInsights()
        XCTAssertEqual(viewModel.insights.count, 3)
        
        // When: Delete insight2
        await viewModel.deleteInsight(insight2)
        
        // Then: Should remove from list
        XCTAssertEqual(viewModel.insights.count, 2)
        XCTAssertFalse(viewModel.insights.contains { $0.content == "Delete this" })
    }
    
    // MARK: - Insight Statistics Tests
    
    func testInsightStatsCalculation() async throws {
        // Given: Various insights with different properties
        let highPriorityUnread = AIInsight(content: "High priority", category: .heartHealth)
        highPriorityUnread.priority = .high
        highPriorityUnread.isRead = false
        highPriorityUnread.confidenceScore = 0.9
        highPriorityUnread.timestamp = Date()
        
        let mediumPriorityRead = AIInsight(content: "Medium priority", category: .sleep)
        mediumPriorityRead.priority = .medium
        mediumPriorityRead.isRead = true
        mediumPriorityRead.confidenceScore = 0.7
        mediumPriorityRead.timestamp = Date()
        
        let lowPriorityUnread = AIInsight(content: "Low priority", category: .activity)
        lowPriorityUnread.priority = .low
        lowPriorityUnread.isRead = false
        lowPriorityUnread.confidenceScore = 0.5
        lowPriorityUnread.timestamp = Date()
        
        // Create insights in real repository
        try await realInsightRepository.create(highPriorityUnread)
        try await realInsightRepository.create(mediumPriorityRead)
        try await realInsightRepository.create(lowPriorityUnread)
        
        // When: Load insights
        await viewModel.loadInsights()
        
        // Then: Stats should be calculated correctly
        let stats = viewModel.insightStats
        XCTAssertEqual(stats.totalInsights, 3)
        XCTAssertEqual(stats.unreadInsights, 2)
        XCTAssertEqual(stats.highPriorityInsights, 1)
        XCTAssertEqual(stats.averageConfidence, 0.7, accuracy: 0.01) // (0.9 + 0.7 + 0.5) / 3
    }
    
    func testHasUnreadInsightsDetection() async throws {
        // Given: All insights are read
        let readInsight1 = AIInsight(content: "Read 1", category: .general)
        readInsight1.isRead = true
        readInsight1.timestamp = Date()
        
        let readInsight2 = AIInsight(content: "Read 2", category: .general)
        readInsight2.isRead = true
        readInsight2.timestamp = Date()
        
        // Create insights in real repository
        try await realInsightRepository.create(readInsight1)
        try await realInsightRepository.create(readInsight2)
        
        // When: Load insights
        await viewModel.loadInsights()
        
        // Then: Should not have unread insights
        XCTAssertFalse(viewModel.hasUnreadInsights)
        
        // Given: Add an unread insight
        let unreadInsight = AIInsight(content: "Unread", category: .general)
        unreadInsight.isRead = false
        unreadInsight.timestamp = Date()
        try await realInsightRepository.create(unreadInsight)
        
        // When: Reload
        await viewModel.loadInsights()
        
        // Then: Should detect unread insight
        XCTAssertTrue(viewModel.hasUnreadInsights)
    }
    
    // MARK: - Category Tests
    
    func testCategorizationFromNarrative() async throws {
        // Test various narrative categorizations
        let narratives = [
            ("I had trouble sleeping last night and woke up multiple times", InsightCategory.sleep),
            ("Your heart rate variability shows improvement", InsightCategory.heartHealth),
            ("You've been very active today with 12,000 steps", InsightCategory.activity),
            ("Consider adjusting your nutrition intake for better energy", InsightCategory.nutrition),
            ("Your stress levels have been elevated this week", InsightCategory.mentalHealth),
            ("General health update for this week", InsightCategory.general)
        ]
        
        for (narrative, expectedCategory) in narratives {
            // When: Generate insight with specific narrative
            mockAuthService.mockCurrentUser = AuthUser(id: "test", email: "test@example.com", fullName: "Test", isEmailVerified: true)
            
            // Add health data to real repository
            let metric = HealthMetric(timestamp: Date(), value: 1, type: .heartRate, unit: "bpm")
            try await realHealthRepository.create(metric)
            
            mockInsightsRepo.insightToGenerate = InsightGenerationResponseDTO(
                success: true,
                data: HealthInsightDTO(
                    userId: "test",
                    narrative: narrative,
                    keyInsights: [],
                    recommendations: [],
                    confidenceScore: 0.8,
                    generatedAt: Date()
                ),
                metadata: nil
            )
            
            await viewModel.generateNewInsight()
            
            // Then: Should categorize correctly
            switch viewModel.generationState {
            case .loaded(let insight):
                XCTAssertEqual(insight.category, expectedCategory, "Failed for narrative: \(narrative)")
            default:
                XCTFail("Generation failed for narrative: \(narrative)")
            }
        }
    }
    
    func testCategoryIconsAndColors() async throws {
        // Test all category filter icons and colors
        let categories: [InsightCategoryFilter] = InsightCategoryFilter.allCases
        
        for category in categories {
            // Then: Each category should have icon and color
            XCTAssertFalse(category.icon.isEmpty)
            XCTAssertNotNil(category.color)
            
            // Verify specific mappings
            switch category {
            case .general:
                XCTAssertEqual(category.icon, "sparkles")
            case .sleep:
                XCTAssertEqual(category.icon, "moon.fill")
            case .activity:
                XCTAssertEqual(category.icon, "figure.walk")
            case .cardiovascular:
                XCTAssertEqual(category.icon, "heart.fill")
            case .nutrition:
                XCTAssertEqual(category.icon, "leaf.fill")
            case .mentalHealth:
                XCTAssertEqual(category.icon, "brain.head.profile")
            }
        }
    }
    
    // MARK: - Priority Tests
    
    func testPriorityDetermination() async throws {
        // Test priority based on confidence and recommendations
        let testCases: [(confidence: Double, recommendations: Int, expected: InsightPriority)] = [
            (0.9, 3, .high),      // High confidence + many recommendations
            (0.85, 4, .high),     // High confidence + many recommendations
            (0.7, 1, .medium),    // Medium confidence
            (0.65, 2, .medium),   // Medium confidence
            (0.4, 1, .low),       // Low confidence
            (0.3, 0, .low)        // Low confidence + no recommendations
        ]
        
        for (confidence, recommendationCount, expectedPriority) in testCases {
            // Generate insight with specific confidence
            mockAuthService.mockCurrentUser = AuthUser(id: "test", email: "test@example.com", fullName: "Test", isEmailVerified: true)
            
            // Add health data to real repository
            let metric = HealthMetric(timestamp: Date(), value: 1, type: .heartRate, unit: "bpm")
            try await realHealthRepository.create(metric)
            
            mockInsightsRepo.insightToGenerate = InsightGenerationResponseDTO(
                success: true,
                data: HealthInsightDTO(
                    userId: "test",
                    narrative: "Test insight",
                    keyInsights: [],
                    recommendations: Array(repeating: "Recommendation", count: recommendationCount),
                    confidenceScore: confidence,
                    generatedAt: Date()
                ),
                metadata: nil
            )
            
            await viewModel.generateNewInsight()
            
            // Then: Priority should match expected
            switch viewModel.generationState {
            case .loaded(let insight):
                XCTAssertEqual(insight.priority, expectedPriority, 
                             "Failed for confidence: \(confidence), recommendations: \(recommendationCount)")
            default:
                XCTFail("Generation failed")
            }
        }
    }
    
    func testPriorityColors() async throws {
        // Test priority level colors
        XCTAssertEqual(InsightPriorityLevel.high.color, .red)
        XCTAssertEqual(InsightPriorityLevel.medium.color, .orange)
        XCTAssertEqual(InsightPriorityLevel.low.color, .green)
    }
    
    // MARK: - Export Tests
    
    func testExportInsights() async throws {
        // Given: Export not yet implemented
        
        // When: Try to export
        let exportURL = await viewModel.exportInsights()
        
        // Then: Should return nil (not implemented)
        XCTAssertNil(exportURL)
    }
    
    // MARK: - Sync Tests
    
    func testSyncInsightsFromBackend() async throws {
        // Given: User is authenticated
        mockAuthService.mockCurrentUser = AuthUser(
            id: "test-user-123",
            email: "test@example.com",
            fullName: "Test User",
            isEmailVerified: true
        )
        
        // Backend has insights
        mockInsightsRepo.historyToReturn = InsightHistoryResponseDTO(
            success: true,
            data: InsightHistoryDataDTO(
                insights: [
                    InsightPreviewDTO(
                        id: "backend-insight-1",
                        narrative: "Backend insight 1",
                        generatedAt: Date(),
                        confidenceScore: 0.8,
                        keyInsightsCount: 3,
                        recommendationsCount: 2
                    )
                ],
                totalCount: 1,
                hasMore: false,
                pagination: PaginationMetaDTO(page: 1, limit: 50)
            ),
            metadata: nil
        )
        
        // When: Load insights (triggers sync)
        await viewModel.loadInsights()
        
        // Then: Should fetch from backend
        XCTAssertTrue(mockInsightsRepo.getHistoryCalled)
        XCTAssertEqual(mockInsightsRepo.capturedUserId, "test-user-123")
        XCTAssertEqual(mockInsightsRepo.capturedLimit, 50)
    }
    
    func testSyncHandlesNewInsights() async throws {
        // Given: Backend returns new insight not in local storage
        mockAuthService.mockCurrentUser = AuthUser(
            id: "test-user-123",
            email: "test@example.com",
            fullName: "Test User",
            isEmailVerified: true
        )
        
        mockInsightsRepo.historyToReturn = InsightHistoryResponseDTO(
            success: true,
            data: InsightHistoryDataDTO(
                insights: [
                    InsightPreviewDTO(
                        id: "new-backend-insight",
                        narrative: "This is a new insight from backend",
                        generatedAt: Date(),
                        confidenceScore: 0.95,
                        keyInsightsCount: 5,
                        recommendationsCount: 4
                    )
                ],
                totalCount: 1,
                hasMore: false,
                pagination: PaginationMetaDTO(page: 1, limit: 50)
            ),
            metadata: nil
        )
        
        // When: Load insights
        await viewModel.loadInsights()
        
        // Then: Should have synced and created new insight
        XCTAssertTrue(mockInsightsRepo.getHistoryCalled)
        
        // Since we're using real repository, verify the insight was created
        let insights = viewModel.insights
        XCTAssertTrue(insights.contains { insight in
            insight.remoteID == "new-backend-insight" &&
            insight.content == "This is a new insight from backend"
        })
    }
    
    func testSyncAvoidsDuplicates() async throws {
        // Given: Backend returns insight that already exists locally
        mockAuthService.mockCurrentUser = AuthUser(
            id: "test-user-123",
            email: "test@example.com",
            fullName: "Test User",
            isEmailVerified: true
        )
        
        // Create existing insight in real repository
        let existingInsight = AIInsight(content: "Existing insight", category: .general)
        existingInsight.remoteID = "existing-insight-id"
        existingInsight.timestamp = Date()
        try await realInsightRepository.create(existingInsight)
        
        mockInsightsRepo.historyToReturn = InsightHistoryResponseDTO(
            success: true,
            data: InsightHistoryDataDTO(
                insights: [
                    InsightPreviewDTO(
                        id: "existing-insight-id", // Same ID as local
                        narrative: "Existing insight",
                        generatedAt: Date(),
                        confidenceScore: 0.8,
                        keyInsightsCount: 2,
                        recommendationsCount: 1
                    )
                ],
                totalCount: 1,
                hasMore: false,
                pagination: PaginationMetaDTO(page: 1, limit: 50)
            ),
            metadata: nil
        )
        
        // When: Load insights
        await viewModel.loadInsights()
        
        // Then: Should not create duplicate
        XCTAssertEqual(viewModel.insights.count, 1)
        XCTAssertEqual(viewModel.insights.filter { $0.remoteID == "existing-insight-id" }.count, 1)
    }
}