// 🚨 CRITICAL DOCUMENTATION - READ BEFORE MODIFYING! 🚨
//
// This file implements the OFFICIAL APPLE DTS ENGINEER SOLUTION for the
// SwiftUI Background Launch Environment Injection Bug.
//
// PROBLEM: SwiftUI accesses @Environment values BEFORE environment injection
// when the app is launched directly into background (not user-initiated).
//
// SOLUTION: All EnvironmentKey must have SAFE defaultValue implementations
// instead of optional values or fatalError fallbacks.
//
// REFERENCE: Apple Developer Forums Thread #744194
// URL: https://developer.apple.com/forums/thread/744194
//
// ⚠️ NEVER use optional environment values with fatalError!
// ⚠️ ALWAYS provide safe fallback implementations!
//
// For detailed documentation, see: SWIFTUI_BACKGROUND_LAUNCH_BUG.md

import Foundation
import SwiftUI

// MARK: - Dummy/Fallback Implementations for Background Launch Safety

/// Safe fallback AuthService for background app launches
/// Implements all AuthServiceProtocol methods with safe no-op behavior
@MainActor
private final class DummyAuthService: AuthServiceProtocol {
    /// Safe fallback auth state that emits nil user
    lazy var authState: AsyncStream<AuthUser?> = AsyncStream { continuation in
        print("⚠️ DummyAuthService: authState accessed during background launch")
        continuation.yield(nil)
        continuation.finish()
    }

    /// No current user in background launch fallback
    var currentUser: AuthUser? {
        get async {
            print("⚠️ DummyAuthService: currentUser accessed during background launch")
            return nil
        }
    }

    /// Safe no-op sign in for background launch
    func signIn(withEmail email: String, password: String) async throws -> UserSessionResponseDTO {
        print("⚠️ DummyAuthService: signIn called during background launch")
        throw AuthenticationError.configurationError
    }

    /// Safe no-op register for background launch
    func register(
        withEmail email: String,
        password: String,
        details: UserRegistrationRequestDTO
    ) async throws -> RegistrationResponseDTO {
        print("⚠️ DummyAuthService: register called during background launch")
        throw AuthenticationError.configurationError
    }

    /// Safe no-op sign out for background launch
    func signOut() async throws {
        print("⚠️ DummyAuthService: signOut called during background launch")
        // No-op - safe to ignore
    }

    /// Safe no-op password reset for background launch
    func sendPasswordReset(to email: String) async throws {
        print("⚠️ DummyAuthService: sendPasswordReset called during background launch")
        throw AuthenticationError.configurationError
    }

    /// Safe no-op token retrieval for background launch
    func getCurrentUserToken() async throws -> String {
        print("⚠️ DummyAuthService: getCurrentUserToken called during background launch")
        throw AuthenticationError.configurationError
    }

    /// Safe no-op email verification for background launch
    func verifyEmail(email: String, code: String) async throws -> LoginResponseDTO {
        print("⚠️ DummyAuthService: verifyEmail called during background launch")
        throw AuthenticationError.configurationError
    }

    /// Safe no-op resend verification for background launch
    func resendVerificationEmail(to email: String) async throws {
        print("⚠️ DummyAuthService: resendVerificationEmail called during background launch")
        throw AuthenticationError.configurationError
    }
}

/// Safe fallback implementation for background app launches
private final class DummyHealthDataRepository: HealthDataRepositoryProtocol {
    func getHealthData(page: Int, limit: Int) async throws -> PaginatedMetricsResponseDTO {
        print("⚠️ DummyHealthDataRepository: getHealthData called during background launch")
        return PaginatedMetricsResponseDTO(data: [])
    }

    func uploadHealthKitData(requestDTO: HealthKitUploadRequestDTO) async throws -> HealthKitUploadResponseDTO {
        print("⚠️ DummyHealthDataRepository: uploadHealthKitData called during background launch")
        return HealthKitUploadResponseDTO(
            success: false,
            uploadId: "dummy-upload-id",
            processedSamples: 0,
            skippedSamples: 0,
            errors: ["Background launch fallback"],
            message: "Background launch fallback"
        )
    }

    func syncHealthKitData(requestDTO: HealthKitSyncRequestDTO) async throws -> HealthKitSyncResponseDTO {
        print("⚠️ DummyHealthDataRepository: syncHealthKitData called during background launch")
        return HealthKitSyncResponseDTO(
            success: false,
            syncId: "dummy-sync-id",
            status: "failed",
            estimatedDuration: nil,
            message: "Background launch fallback"
        )
    }

    func getHealthKitSyncStatus(syncId: String) async throws -> HealthKitSyncStatusDTO {
        print("⚠️ DummyHealthDataRepository: getHealthKitSyncStatus called during background launch")
        return HealthKitSyncStatusDTO(
            syncId: syncId,
            status: "failed",
            progress: 0.0,
            processedSamples: 0,
            totalSamples: 0,
            errors: ["Background launch fallback"],
            completedAt: nil
        )
    }

    func getHealthKitUploadStatus(uploadId: String) async throws -> HealthKitUploadStatusDTO {
        print("⚠️ DummyHealthDataRepository: getHealthKitUploadStatus called during background launch")
        return HealthKitUploadStatusDTO(
            uploadId: uploadId,
            status: "failed",
            progress: 0.0,
            processedSamples: 0,
            totalSamples: 0,
            errors: ["Background launch fallback"],
            completedAt: nil,
            message: "Background launch fallback"
        )
    }

    func getProcessingStatus(id: UUID) async throws -> HealthDataProcessingStatusDTO {
        print("⚠️ DummyHealthDataRepository: getProcessingStatus called during background launch")
        return HealthDataProcessingStatusDTO(
            processingId: id,
            status: "failed",
            progress: 0.0,
            processedMetrics: 0,
            totalMetrics: 0,
            estimatedTimeRemaining: nil,
            completedAt: nil,
            errors: ["Background launch fallback"],
            message: "Background launch fallback"
        )
    }
}

/// Safe fallback implementation for background app launches
private final class DummyInsightsRepository: InsightsRepositoryProtocol {
    func generateInsight(requestDTO: InsightGenerationRequestDTO) async throws -> InsightGenerationResponseDTO {
        print("⚠️ DummyInsightsRepository: generateInsight called during background launch")
        let dummyInsight = HealthInsightDTO(
            userId: "dummy-user",
            narrative: "Background launch fallback - no insights available",
            keyInsights: [],
            recommendations: [],
            confidenceScore: 0.0,
            generatedAt: Date()
        )
        return InsightGenerationResponseDTO(
            success: false,
            data: dummyInsight,
            metadata: ["error": AnyCodable("Background launch fallback")]
        )
    }

    func getInsightHistory(userId: String, limit: Int, offset: Int) async throws -> InsightHistoryResponseDTO {
        print("⚠️ DummyInsightsRepository: getInsightHistory called during background launch")
        let historyData = InsightHistoryDataDTO(
            insights: [],
            totalCount: 0,
            hasMore: false,
            pagination: PaginationMetaDTO(page: 1, limit: limit)
        )
        return InsightHistoryResponseDTO(
            success: false,
            data: historyData,
            metadata: ["error": AnyCodable("Background launch fallback")]
        )
    }
}

/// Safe fallback UserRepository for background app launches
private final class DummyUserRepository: UserRepositoryProtocol {
    func getCurrentUserProfile() async throws -> UserProfile {
        print("⚠️ DummyUserRepository: getCurrentUserProfile called during background launch")
        // Return dummy profile to avoid crash
        return UserProfile(
            id: UUID(),
            email: "dummy@example.com",
            firstName: "Dummy",
            lastName: "User",
            role: "user",
            permissions: [],
            status: "dummy",
            emailVerified: false,
            mfaEnabled: false,
            createdAt: Date(),
            lastLogin: nil
        )
    }

    func updateUserProfile(_ profile: UserProfile) async throws -> UserProfile {
        print("⚠️ DummyUserRepository: updateUserProfile called during background launch")
        return profile // Return same profile unchanged
    }

    func deleteUserAccount() async throws {
        print("⚠️ DummyUserRepository: deleteUserAccount called during background launch")
        // No-op - safe to ignore
    }

    func getPrivacyPreferences() async throws -> UserPrivacyPreferencesDTO {
        print("⚠️ DummyUserRepository: getPrivacyPreferences called during background launch")
        return UserPrivacyPreferencesDTO(
            shareDataForResearch: false,
            enableAnalytics: false,
            marketingEmails: false,
            pushNotifications: false,
            dataRetentionPeriod: 30,
            allowThirdPartyIntegrations: false
        )
    }

    func updatePrivacyPreferences(_ preferences: UserPrivacyPreferencesDTO) async throws {
        print("⚠️ DummyUserRepository: updatePrivacyPreferences called during background launch")
        // No-op - safe to ignore
    }
}

/// Safe fallback HealthKitService for background app launches
private final class DummyHealthKitService: HealthKitServiceProtocol {
    func isHealthDataAvailable() -> Bool {
        print("⚠️ DummyHealthKitService: isHealthDataAvailable called during background launch")
        return false // Safe default
    }

    func requestAuthorization() async throws {
        print("⚠️ DummyHealthKitService: requestAuthorization called during background launch")
        // No-op - safe to ignore
    }

    func fetchDailySteps(for date: Date) async throws -> Double {
        print("⚠️ DummyHealthKitService: fetchDailySteps called during background launch")
        return 0.0 // Safe default
    }

    func fetchRestingHeartRate(for date: Date) async throws -> Double? {
        print("⚠️ DummyHealthKitService: fetchRestingHeartRate called during background launch")
        return nil // Safe default
    }

    func fetchSleepAnalysis(for date: Date) async throws -> SleepData? {
        print("⚠️ DummyHealthKitService: fetchSleepAnalysis called during background launch")
        return nil // Safe default
    }

    func fetchAllDailyMetrics(for date: Date) async throws -> DailyHealthMetrics {
        print("⚠️ DummyHealthKitService: fetchAllDailyMetrics called during background launch")
        return DailyHealthMetrics(date: date, stepCount: 0, restingHeartRate: nil, sleepData: nil)
    }

    func uploadHealthKitData(_ uploadRequest: HealthKitUploadRequestDTO) async throws -> HealthKitUploadResponseDTO {
        print("⚠️ DummyHealthKitService: uploadHealthKitData called during background launch")
        return HealthKitUploadResponseDTO(
            success: false,
            uploadId: "dummy-upload-id",
            processedSamples: 0,
            skippedSamples: 0,
            errors: ["Background launch fallback"],
            message: "Background launch fallback"
        )
    }

    func enableBackgroundDelivery() async throws {
        print("⚠️ DummyHealthKitService: enableBackgroundDelivery called during background launch")
        // No-op - safe to ignore
    }

    func disableBackgroundDelivery() async throws {
        print("⚠️ DummyHealthKitService: disableBackgroundDelivery called during background launch")
        // No-op - safe to ignore
    }

    func setupObserverQueries() {
        print("⚠️ DummyHealthKitService: setupObserverQueries called during background launch")
        // No-op - safe to ignore
    }

    func setOfflineQueueManager(_ manager: OfflineQueueManagerProtocol) {
        print("⚠️ DummyHealthKitService: setOfflineQueueManager called during background launch")
        // No-op - safe to ignore
    }
    
    func fetchHealthDataForUpload(from startDate: Date, to endDate: Date, userId: String) async throws -> HealthKitUploadRequestDTO {
        print("⚠️ DummyHealthKitService: fetchHealthDataForUpload called during background launch")
        return HealthKitUploadRequestDTO(
            userId: userId,
            samples: [],
            deviceInfo: nil,
            timestamp: Date()
        )
    }
}

/// Safe fallback APIClient for background app launches
/// Made internal for use in app initialization fallback
final class DummyAPIClient: APIClientProtocol {
    // Auth endpoints
    func register(requestDTO: UserRegistrationRequestDTO) async throws -> RegistrationResponseDTO {
        print("⚠️ DummyAPIClient: register called during background launch")
        throw URLError(.notConnectedToInternet)
    }

    func login(requestDTO: UserLoginRequestDTO) async throws -> LoginResponseDTO {
        print("⚠️ DummyAPIClient: login called during background launch")
        throw URLError(.notConnectedToInternet)
    }

    func refreshToken(requestDTO: RefreshTokenRequestDTO) async throws -> TokenResponseDTO {
        print("⚠️ DummyAPIClient: refreshToken called during background launch")
        throw URLError(.notConnectedToInternet)
    }

    func logout() async throws -> MessageResponseDTO {
        print("⚠️ DummyAPIClient: logout called during background launch")
        return MessageResponseDTO(message: "Background launch - no operation")
    }

    func getCurrentUser() async throws -> UserSessionResponseDTO {
        print("⚠️ DummyAPIClient: getCurrentUser called during background launch")
        throw URLError(.notConnectedToInternet)
    }

    func verifyEmail(email: String, code: String) async throws -> LoginResponseDTO {
        print("⚠️ DummyAPIClient: verifyEmail called during background launch")
        throw URLError(.notConnectedToInternet)
    }

    func resendVerificationEmail(email: String) async throws -> MessageResponseDTO {
        print("⚠️ DummyAPIClient: resendVerificationEmail called during background launch")
        throw URLError(.notConnectedToInternet)
    }

    // Health Data endpoints
    func getHealthData(page: Int, limit: Int) async throws -> PaginatedMetricsResponseDTO {
        print("⚠️ DummyAPIClient: getHealthData called during background launch")
        return PaginatedMetricsResponseDTO(data: [])
    }

    func uploadHealthKitData(requestDTO: HealthKitUploadRequestDTO) async throws -> HealthKitUploadResponseDTO {
        print("⚠️ DummyAPIClient: uploadHealthKitData called during background launch")
        return HealthKitUploadResponseDTO(
            success: false,
            uploadId: "dummy-upload-id",
            processedSamples: 0,
            skippedSamples: 0,
            errors: ["Background launch fallback"],
            message: "Background launch fallback"
        )
    }

    func syncHealthKitData(requestDTO: HealthKitSyncRequestDTO) async throws -> HealthKitSyncResponseDTO {
        print("⚠️ DummyAPIClient: syncHealthKitData called during background launch")
        return HealthKitSyncResponseDTO(
            success: false,
            syncId: "dummy-sync-id",
            status: "failed",
            estimatedDuration: nil,
            message: "Background launch fallback"
        )
    }

    func getHealthKitSyncStatus(syncId: String) async throws -> HealthKitSyncStatusDTO {
        print("⚠️ DummyAPIClient: getHealthKitSyncStatus called during background launch")
        return HealthKitSyncStatusDTO(
            syncId: syncId,
            status: "failed",
            progress: 0.0,
            processedSamples: 0,
            totalSamples: 0,
            errors: ["Background launch fallback"],
            completedAt: nil
        )
    }

    func getHealthKitUploadStatus(uploadId: String) async throws -> HealthKitUploadStatusDTO {
        print("⚠️ DummyAPIClient: getHealthKitUploadStatus called during background launch")
        return HealthKitUploadStatusDTO(
            uploadId: uploadId,
            status: "failed",
            progress: 0.0,
            processedSamples: 0,
            totalSamples: 0,
            errors: ["Background launch fallback"],
            completedAt: nil,
            message: "Background launch fallback"
        )
    }

    func getProcessingStatus(id: UUID) async throws -> HealthDataProcessingStatusDTO {
        print("⚠️ DummyAPIClient: getProcessingStatus called during background launch")
        return HealthDataProcessingStatusDTO(
            processingId: id,
            status: "failed",
            progress: 0.0,
            processedMetrics: 0,
            totalMetrics: 0,
            estimatedTimeRemaining: nil,
            completedAt: nil,
            errors: ["Background launch fallback"],
            message: "Background launch fallback"
        )
    }

    // Insights endpoints
    func getInsightHistory(userId: String, limit: Int, offset: Int) async throws -> InsightHistoryResponseDTO {
        print("⚠️ DummyAPIClient: getInsightHistory called during background launch")
        let historyData = InsightHistoryDataDTO(
            insights: [],
            totalCount: 0,
            hasMore: false,
            pagination: PaginationMetaDTO(page: 1, limit: limit)
        )
        return InsightHistoryResponseDTO(
            success: false,
            data: historyData,
            metadata: ["error": AnyCodable("Background launch fallback")]
        )
    }

    func generateInsight(requestDTO: InsightGenerationRequestDTO) async throws -> InsightGenerationResponseDTO {
        print("⚠️ DummyAPIClient: generateInsight called during background launch")
        let dummyInsight = HealthInsightDTO(
            userId: "dummy-user",
            narrative: "Background launch fallback - no insights available",
            keyInsights: [],
            recommendations: [],
            confidenceScore: 0.0,
            generatedAt: Date()
        )
        return InsightGenerationResponseDTO(
            success: false,
            data: dummyInsight,
            metadata: ["error": AnyCodable("Background launch fallback")]
        )
    }
    
    func chatWithAI(requestDTO: ChatRequestDTO) async throws -> ChatResponseDTO {
        print("⚠️ DummyAPIClient: chatWithAI called during background launch")
        return ChatResponseDTO(
            response: "Background launch fallback - chat not available",
            conversationId: requestDTO.context?.conversationId ?? UUID().uuidString,
            followUpQuestions: [],
            relevantData: nil
        )
    }

    func getInsight(id: String) async throws -> InsightGenerationResponseDTO {
        print("⚠️ DummyAPIClient: getInsight called during background launch")
        let dummyInsight = HealthInsightDTO(
            userId: "dummy-user",
            narrative: "Background launch fallback - no insights available",
            keyInsights: [],
            recommendations: [],
            confidenceScore: 0.0,
            generatedAt: Date()
        )
        return InsightGenerationResponseDTO(
            success: false,
            data: dummyInsight,
            metadata: ["error": AnyCodable("Background launch fallback")]
        )
    }

    func getInsightsServiceStatus() async throws -> ServiceStatusResponseDTO {
        print("⚠️ DummyAPIClient: getInsightsServiceStatus called during background launch")
        throw URLError(.notConnectedToInternet)
    }

    // PAT Analysis endpoints
    func analyzeStepData(requestDTO: StepDataRequestDTO) async throws -> StepAnalysisResponseDTO {
        print("⚠️ DummyAPIClient: analyzeStepData called during background launch")
        throw URLError(.notConnectedToInternet)
    }

    func analyzeActigraphy(requestDTO: DirectActigraphyRequestDTO) async throws -> ActigraphyAnalysisResponseDTO {
        print("⚠️ DummyAPIClient: analyzeActigraphy called during background launch")
        throw URLError(.notConnectedToInternet)
    }

    func getPATAnalysis(id: String) async throws -> PATAnalysisResponseDTO {
        print("⚠️ DummyAPIClient: getPATAnalysis called during background launch")
        throw URLError(.notConnectedToInternet)
    }

    func getPATServiceHealth() async throws -> ServiceStatusResponseDTO {
        print("⚠️ DummyAPIClient: getPATServiceHealth called during background launch")
        throw URLError(.notConnectedToInternet)
    }
}

// MARK: - Shared Token Provider

/// Shared token provider for default environment values
/// Returns nil to avoid early TokenManager access during environment setup
private let defaultTokenProvider: () async -> String? = {
    print("⚠️ Default environment: Using fallback tokenProvider (no authentication)")
    return nil // Don't access TokenManager.shared during environment setup!
}

// MARK: - Environment Keys with Safe Defaults (Apple DTS Engineer Solution)

/// The key for accessing the `AuthServiceProtocol` in the SwiftUI Environment.
/// Uses safe default implementation to prevent background launch crashes.
private struct AuthServiceKey: EnvironmentKey {
    typealias Value = AuthServiceProtocol
    static var defaultValue: AuthServiceProtocol {
        // Use MainActor.assumeIsolated to create dummy service for background launches
        // This works around Swift 6 concurrency warnings while preventing crashes
        MainActor.assumeIsolated {
            DummyAuthService()
        }
    }
}

/// The key for accessing the `AuthViewModel` in the SwiftUI Environment.
/// Note: This is kept for backwards compatibility, but the app uses the new iOS 17+ @Environment(Type.self) pattern
struct AuthViewModelKey: EnvironmentKey {
    typealias Value = AuthViewModel?
    static var defaultValue: AuthViewModel? = nil
}

private struct APIClientKey: EnvironmentKey {
    typealias Value = APIClientProtocol
    static let defaultValue: APIClientProtocol = {
        guard
            let client = BackendAPIClient(
                baseURLString: AppConfig.apiBaseURL,
                tokenProvider: defaultTokenProvider
            ) else {
            // Fallback to dummy client if BackendAPIClient fails
            return DummyAPIClient()
        }
        return client
    }()
}

// MARK: - Repository Environment Keys with Safe Defaults

private struct HealthDataRepositoryKey: EnvironmentKey {
    typealias Value = HealthDataRepositoryProtocol
    static let defaultValue: HealthDataRepositoryProtocol = DummyHealthDataRepository()
}

private struct InsightsRepositoryKey: EnvironmentKey {
    typealias Value = InsightsRepositoryProtocol
    static let defaultValue: InsightsRepositoryProtocol = DummyInsightsRepository()
}

private struct UserRepositoryKey: EnvironmentKey {
    typealias Value = UserRepositoryProtocol
    static let defaultValue: UserRepositoryProtocol = DummyUserRepository()
}

private struct HealthKitServiceKey: EnvironmentKey {
    typealias Value = HealthKitServiceProtocol
    static let defaultValue: HealthKitServiceProtocol = DummyHealthKitService()
}

// Security services will be added later when protocols are defined

extension EnvironmentValues {
    /// Provides access to the `AuthService` throughout the SwiftUI environment.
    /// Uses safe default implementation - NO MORE FATAL ERRORS!
    var authService: AuthServiceProtocol {
        get { self[AuthServiceKey.self] }
        set { self[AuthServiceKey.self] = newValue }
    }

    /// Provides access to the `AuthViewModel` throughout the SwiftUI environment.
    var authViewModel: AuthViewModel? {
        get { self[AuthViewModelKey.self] }
        set { self[AuthViewModelKey.self] = newValue }
    }

    /// Safe access to HealthDataRepository - no fatal errors
    var healthDataRepository: HealthDataRepositoryProtocol {
        get { self[HealthDataRepositoryKey.self] }
        set { self[HealthDataRepositoryKey.self] = newValue }
    }

    /// Safe access to InsightsRepository - no fatal errors
    var insightsRepository: InsightsRepositoryProtocol {
        get { self[InsightsRepositoryKey.self] }
        set { self[InsightsRepositoryKey.self] = newValue }
    }

    /// Safe access to UserRepository - no fatal errors
    var userRepository: UserRepositoryProtocol {
        get { self[UserRepositoryKey.self] }
        set { self[UserRepositoryKey.self] = newValue }
    }

    /// Safe access to HealthKitService - no fatal errors
    var healthKitService: HealthKitServiceProtocol {
        get { self[HealthKitServiceKey.self] }
        set { self[HealthKitServiceKey.self] = newValue }
    }

    /// Safe access to APIClient - no fatal errors
    var apiClient: APIClientProtocol {
        get { self[APIClientKey.self] }
        set { self[APIClientKey.self] = newValue }
    }
}

// Default values are provided above for each environment key
// These will be used in previews and when services aren't explicitly injected

// NOTE: Add other service keys here as needed (e.g., for HealthKit, Networking, etc.)
