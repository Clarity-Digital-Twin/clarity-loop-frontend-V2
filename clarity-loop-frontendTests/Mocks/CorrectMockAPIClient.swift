@testable import clarity_loop_frontend
import Foundation

// Correct mock that matches the real APIClientProtocol
class MockAPIClient: APIClientProtocol {
    // MARK: - Control Properties

    var shouldSucceed = true
    var mockError: Error = APIError.unauthorized

    // Mock responses
    var mockInsightHistory = InsightHistoryResponseDTO(
        success: true,
        data: InsightHistoryDataDTO(
            insights: [],
            totalCount: 0,
            hasMore: false,
            pagination: PaginationMetaDTO(
                page: 1,
                limit: 10
            )
        ),
        metadata: nil
    )
    
    var mockInsightGeneration: InsightGenerationResponseDTO?
    var mockServiceStatus: ServiceStatusResponseDTO?
    
    // Tracking
    var generateInsightCalled = false
    var capturedInsightRequest: InsightGenerationRequestDTO?
    
    // Custom handlers
    var uploadHealthKitDataHandler: ((HealthKitUploadRequestDTO) async throws -> HealthKitUploadResponseDTO)?

    // MARK: - Authentication

    func register(requestDTO: UserRegistrationRequestDTO) async throws -> RegistrationResponseDTO {
        guard shouldSucceed else { throw mockError }
        return RegistrationResponseDTO(
            userId: UUID(),
            email: requestDTO.email,
            status: "registered",
            verificationEmailSent: true,
            createdAt: Date()
        )
    }

    func login(requestDTO: UserLoginRequestDTO) async throws -> LoginResponseDTO {
        guard shouldSucceed else { throw mockError }
        return LoginResponseDTO(
            user: UserSessionResponseDTO(
                id: UUID().uuidString,
                email: requestDTO.email,
                displayName: "Test User",
                avatarUrl: nil,
                provider: "email",
                role: "patient",
                isActive: true,
                isEmailVerified: true,
                preferences: UserPreferencesResponseDTO(
                    theme: "light",
                    notifications: true,
                    language: "en"
                ),
                metadata: UserMetadataResponseDTO(
                    lastLogin: Date(),
                    loginCount: 1,
                    createdAt: Date(),
                    updatedAt: Date()
                )
            ),
            tokens: TokenResponseDTO(
                accessToken: "mock_access_token",
                refreshToken: "mock_refresh_token",
                tokenType: "bearer",
                expiresIn: 3600
            )
        )
    }

    func refreshToken(requestDTO: RefreshTokenRequestDTO) async throws -> TokenResponseDTO {
        guard shouldSucceed else { throw mockError }
        return TokenResponseDTO(
            accessToken: "mock_refreshed_token",
            refreshToken: requestDTO.refreshToken,
            tokenType: "bearer",
            expiresIn: 3600
        )
    }

    func logout() async throws -> MessageResponseDTO {
        guard shouldSucceed else { throw mockError }
        return MessageResponseDTO(message: "Successfully logged out")
    }

    func getCurrentUser() async throws -> UserSessionResponseDTO {
        guard shouldSucceed else { throw mockError }
        return UserSessionResponseDTO(
            id: UUID().uuidString,
            email: "test@example.com",
            displayName: "Test User",
            avatarUrl: nil,
            provider: "email",
            role: "patient",
            isActive: true,
            isEmailVerified: true,
            preferences: UserPreferencesResponseDTO(
                theme: "light",
                notifications: true,
                language: "en"
            ),
            metadata: UserMetadataResponseDTO(
                lastLogin: Date(),
                loginCount: 1,
                createdAt: Date(),
                updatedAt: Date()
            )
        )
    }

    func verifyEmail(email: String, code: String) async throws -> LoginResponseDTO {
        guard shouldSucceed else { throw mockError }
        return LoginResponseDTO(
            user: UserSessionResponseDTO(
                id: UUID().uuidString,
                email: email,
                displayName: "Test User",
                avatarUrl: nil,
                provider: "email",
                role: "patient",
                isActive: true,
                isEmailVerified: true,
                preferences: UserPreferencesResponseDTO(
                    theme: "light",
                    notifications: true,
                    language: "en"
                ),
                metadata: UserMetadataResponseDTO(
                    lastLogin: Date(),
                    loginCount: 1,
                    createdAt: Date(),
                    updatedAt: Date()
                )
            ),
            tokens: TokenResponseDTO(
                accessToken: "mock_access_token",
                refreshToken: "mock_refresh_token",
                tokenType: "bearer",
                expiresIn: 3600
            )
        )
    }

    func resendVerificationEmail(email: String) async throws -> MessageResponseDTO {
        guard shouldSucceed else { throw mockError }
        return MessageResponseDTO(message: "Verification email sent")
    }

    // MARK: - Health Data

    func getHealthData(page: Int, limit: Int) async throws -> PaginatedMetricsResponseDTO {
        guard shouldSucceed else { throw mockError }
        
        if let handler = getHealthDataHandler {
            return try await handler(page, limit)
        }
        
        // Default empty response
        return PaginatedMetricsResponseDTO(data: [])
    }

    func uploadHealthKitData(requestDTO: HealthKitUploadRequestDTO) async throws -> HealthKitUploadResponseDTO {
        guard shouldSucceed else { throw mockError }
        
        if let handler = uploadHealthKitDataHandler {
            return try await handler(requestDTO)
        }
        
        // Default response
        return HealthKitUploadResponseDTO(
            uploadId: UUID().uuidString,
            status: "completed",
            processedSamples: requestDTO.samples.count,
            errors: nil,
            timestamp: Date()
        )
    }

    func syncHealthKitData(requestDTO: HealthKitSyncRequestDTO) async throws -> HealthKitSyncResponseDTO {
        guard shouldSucceed else { throw mockError }
        
        if let handler = syncHealthKitDataHandler {
            return try await handler(requestDTO)
        }
        
        // Default response
        return HealthKitSyncResponseDTO(
            success: true,
            syncId: UUID().uuidString,
            status: "initiated",
            estimatedDuration: 60.0,
            message: "Sync initiated successfully"
        )
    }

    func getHealthKitSyncStatus(syncId: String) async throws -> HealthKitSyncStatusDTO {
        guard shouldSucceed else { throw mockError }
        
        if let handler = getHealthKitSyncStatusHandler {
            return try await handler(syncId)
        }
        
        // Default response
        return HealthKitSyncStatusDTO(
            syncId: syncId,
            status: "in_progress",
            progress: 0.5,
            processedSamples: 50,
            totalSamples: 100,
            errors: nil,
            completedAt: nil
        )
    }

    func getHealthKitUploadStatus(uploadId: String) async throws -> HealthKitUploadStatusDTO {
        guard shouldSucceed else { throw mockError }
        
        if let handler = getHealthKitUploadStatusHandler {
            return try await handler(uploadId)
        }
        
        // Default response
        return HealthKitUploadStatusDTO(
            uploadId: uploadId,
            status: "completed",
            progress: 1.0,
            processedSamples: 100,
            totalSamples: 100,
            errors: nil,
            completedAt: Date(),
            message: "Upload completed successfully"
        )
    }

    func getProcessingStatus(id: UUID) async throws -> HealthDataProcessingStatusDTO {
        guard shouldSucceed else { throw mockError }
        
        if let handler = getProcessingStatusHandler {
            return try await handler(id)
        }
        
        // Default response
        return HealthDataProcessingStatusDTO(
            processingId: id,
            status: "completed",
            progress: 1.0,
            processedMetrics: 100,
            totalMetrics: 100,
            estimatedTimeRemaining: nil,
            completedAt: Date(),
            errors: nil,
            message: "Processing completed successfully"
        )
    }

    // MARK: - Insights

    func getInsightHistory(userId: String, limit: Int, offset: Int) async throws -> InsightHistoryResponseDTO {
        guard shouldSucceed else { throw mockError }
        return mockInsightHistory
    }

    func generateInsight(requestDTO: InsightGenerationRequestDTO) async throws -> InsightGenerationResponseDTO {
        generateInsightCalled = true
        capturedInsightRequest = requestDTO
        
        guard shouldSucceed else { throw mockError }
        
        if let mockResponse = mockInsightGeneration {
            return mockResponse
        }
        
        // Default response
        return InsightGenerationResponseDTO(
            success: true,
            data: HealthInsightDTO(
                userId: "test-user",
                narrative: "Generated insight",
                keyInsights: ["Key insight 1", "Key insight 2"],
                recommendations: ["Recommendation 1"],
                confidenceScore: 0.85,
                generatedAt: Date()
            ),
            metadata: nil
        )
    }

    func chatWithAI(requestDTO: ChatRequestDTO) async throws -> ChatResponseDTO {
        guard shouldSucceed else { throw mockError }
        return ChatResponseDTO(
            response: "Mock AI response",
            conversationId: UUID().uuidString,
            followUpQuestions: ["What else would you like to know?"],
            relevantData: nil
        )
    }

    func getInsight(id: String) async throws -> InsightGenerationResponseDTO {
        throw NSError(domain: "MockError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])
    }

    func getInsightsServiceStatus() async throws -> ServiceStatusResponseDTO {
        guard shouldSucceed else { throw mockError }
        
        if let mockStatus = mockServiceStatus {
            return mockStatus
        }
        
        // Default healthy response
        return ServiceStatusResponseDTO(
            service: "insights",
            status: "healthy",
            version: "1.0.0",
            timestamp: Date(),
            dependencies: [
                DependencyStatusDTO(
                    name: "database",
                    status: "healthy",
                    responseTime: 50
                ),
                DependencyStatusDTO(
                    name: "ai-model",
                    status: "healthy",
                    responseTime: 200
                )
            ],
            metrics: ServiceMetricsDTO(
                requestsPerMinute: 100,
                averageResponseTime: 250,
                errorRate: 0.01,
                uptime: 0.999
            )
        )
    }

    // MARK: - PAT Analysis

    func analyzeStepData(requestDTO: StepDataRequestDTO) async throws -> StepAnalysisResponseDTO {
        guard shouldSucceed else { throw mockError }
        
        if let handler = analyzeStepDataHandler {
            return try await handler(requestDTO)
        }
        
        // Default response
        return StepAnalysisResponseDTO(
            success: true,
            analysisId: UUID().uuidString,
            estimatedCompletionTime: Date().addingTimeInterval(300)
        )
    }

    func analyzeActigraphy(requestDTO: DirectActigraphyRequestDTO) async throws -> ActigraphyAnalysisResponseDTO {
        guard shouldSucceed else { throw mockError }
        
        if let handler = analyzeActigraphyHandler {
            return try await handler(requestDTO)
        }
        
        // Default response
        return ActigraphyAnalysisResponseDTO(
            success: true,
            analysisId: UUID().uuidString,
            estimatedCompletionTime: Date().addingTimeInterval(300)
        )
    }

    func getPATAnalysis(id: String) async throws -> PATAnalysisResponseDTO {
        guard shouldSucceed else { throw mockError }
        
        if let handler = getPATAnalysisHandler {
            return try await handler(id)
        }
        
        // Default response
        return PATAnalysisResponseDTO(
            id: id,
            status: "completed",
            patFeatures: nil,
            analysis: nil,
            errorMessage: nil,
            createdAt: Date(),
            completedAt: Date()
        )
    }

    func getPATServiceHealth() async throws -> ServiceStatusResponseDTO {
        throw NSError(domain: "MockError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Not implemented"])
    }
}
