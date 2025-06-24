import Foundation
#if canImport(UIKit) && DEBUG
    import UIKit
#endif

/// Defines the contract for an API client that communicates with the CLARITY backend.
/// This protocol allows for dependency injection and mocking for testing purposes.
protocol APIClientProtocol {
    // Endpoints for Authentication
    func register(requestDTO: UserRegistrationRequestDTO) async throws -> RegistrationResponseDTO
    func login(requestDTO: UserLoginRequestDTO) async throws -> LoginResponseDTO
    func refreshToken(requestDTO: RefreshTokenRequestDTO) async throws -> TokenResponseDTO
    func logout() async throws -> MessageResponseDTO
    func getCurrentUser() async throws -> UserSessionResponseDTO
    func verifyEmail(email: String, code: String) async throws -> LoginResponseDTO
    func resendVerificationEmail(email: String) async throws -> MessageResponseDTO

    // Endpoints for Health Data
    func getHealthData(page: Int, limit: Int) async throws -> PaginatedMetricsResponseDTO
    func uploadHealthKitData(requestDTO: HealthKitUploadRequestDTO) async throws -> HealthKitUploadResponseDTO
    func syncHealthKitData(requestDTO: HealthKitSyncRequestDTO) async throws -> HealthKitSyncResponseDTO
    func getHealthKitSyncStatus(syncId: String) async throws -> HealthKitSyncStatusDTO
    func getHealthKitUploadStatus(uploadId: String) async throws -> HealthKitUploadStatusDTO
    func getProcessingStatus(id: UUID) async throws -> HealthDataProcessingStatusDTO

    // Endpoints for Insights
    func getInsightHistory(userId: String, limit: Int, offset: Int) async throws -> InsightHistoryResponseDTO
    func generateInsight(requestDTO: InsightGenerationRequestDTO) async throws -> InsightGenerationResponseDTO
    func chatWithAI(requestDTO: ChatRequestDTO) async throws -> ChatResponseDTO
    func getInsight(id: String) async throws -> InsightGenerationResponseDTO
    func getInsightsServiceStatus() async throws -> ServiceStatusResponseDTO

    // Endpoints for PAT Analysis
    func analyzeStepData(requestDTO: StepDataRequestDTO) async throws -> StepAnalysisResponseDTO
    func analyzeActigraphy(requestDTO: DirectActigraphyRequestDTO) async throws -> ActigraphyAnalysisResponseDTO
    func getPATAnalysis(id: String) async throws -> PATAnalysisResponseDTO
    func getPATServiceHealth() async throws -> ServiceStatusResponseDTO
}

/// The concrete implementation of the API client.
final class APIClient: APIClientProtocol {
    // MARK: - Properties

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let tokenProvider: () async -> String?

    // MARK: - Initializer

    init?(
        baseURLString: String = AppConfig.apiBaseURL,
        session: URLSession = .shared,
        tokenProvider: @escaping () async -> String?
    ) {
        guard let baseURL = URL(string: baseURLString) else {
            return nil // Return nil if the URL is invalid
        }
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    // MARK: - Public API Methods

    func register(requestDTO: UserRegistrationRequestDTO) async throws -> RegistrationResponseDTO {
        let endpoint = AuthEndpoint.register(dto: requestDTO)
        return try await performRequest(for: endpoint, requiresAuth: false)
    }

    func login(requestDTO: UserLoginRequestDTO) async throws -> LoginResponseDTO {
        let endpoint = AuthEndpoint.login(dto: requestDTO)
        return try await performRequest(for: endpoint, requiresAuth: false)
    }

    // MARK: - Health Data Methods

    func getHealthData(page: Int, limit: Int) async throws -> PaginatedMetricsResponseDTO {
        let endpoint = HealthDataEndpoint.getMetrics(page: page, limit: limit)
        return try await performRequest(for: endpoint)
    }

    func uploadHealthKitData(requestDTO: HealthKitUploadRequestDTO) async throws -> HealthKitUploadResponseDTO {
        // Convert to backend-compatible format
        guard let backendRequest = requestDTO.toBackendUploadRequest() else {
            throw APIError.validationError("Invalid user ID format")
        }

        // Create a custom endpoint for the backend format
        let endpoint = BackendHealthDataEndpoint.upload(dto: backendRequest)

        // Perform the request and get backend response
        let backendResponse: HealthDataResponseDTO = try await performRequest(for: endpoint)

        // Convert backend response to frontend format
        return HealthKitUploadResponseDTO(
            success: backendResponse.status == "received" || backendResponse.status == "processing",
            uploadId: backendResponse.processingId.uuidString,
            processedSamples: backendResponse.acceptedMetrics,
            skippedSamples: backendResponse.rejectedMetrics,
            errors: backendResponse.validationErrors.isEmpty ? nil : backendResponse.validationErrors,
            message: backendResponse.message
        )
    }

    func syncHealthKitData(requestDTO: HealthKitSyncRequestDTO) async throws -> HealthKitSyncResponseDTO {
        let endpoint = HealthDataEndpoint.syncHealthKit(dto: requestDTO)
        return try await performRequest(for: endpoint)
    }

    func getHealthKitSyncStatus(syncId: String) async throws -> HealthKitSyncStatusDTO {
        let endpoint = HealthDataEndpoint.getSyncStatus(syncId: syncId)
        return try await performRequest(for: endpoint)
    }

    // MARK: - Insights Methods

    func getInsightHistory(userId: String, limit: Int, offset: Int) async throws -> InsightHistoryResponseDTO {
        let endpoint = InsightEndpoint.getHistory(userId: userId, limit: limit, offset: offset)
        return try await performRequest(for: endpoint)
    }

    func generateInsight(requestDTO: InsightGenerationRequestDTO) async throws -> InsightGenerationResponseDTO {
        let endpoint = InsightEndpoint.generate(dto: requestDTO)
        return try await performRequest(for: endpoint)
    }
    
    func chatWithAI(requestDTO: ChatRequestDTO) async throws -> ChatResponseDTO {
        let endpoint = InsightEndpoint.chat(dto: requestDTO)
        return try await performRequest(for: endpoint)
    }

    // MARK: - Additional Auth Methods

    func refreshToken(requestDTO: RefreshTokenRequestDTO) async throws -> TokenResponseDTO {
        let endpoint = AuthEndpoint.refreshToken(dto: requestDTO)
        return try await performRequest(for: endpoint, requiresAuth: false)
    }

    func logout() async throws -> MessageResponseDTO {
        let endpoint = AuthEndpoint.logout
        return try await performRequest(for: endpoint)
    }

    func getCurrentUser() async throws -> UserSessionResponseDTO {
        let endpoint = AuthEndpoint.getCurrentUser
        return try await performRequest(for: endpoint)
    }

    func verifyEmail(email: String, code: String) async throws -> LoginResponseDTO {
        let endpoint = AuthEndpoint.verifyEmail(email: email, code: code)
        return try await performRequest(for: endpoint, requiresAuth: false)
    }

    func resendVerificationEmail(email: String) async throws -> MessageResponseDTO {
        let endpoint = AuthEndpoint.resendVerificationEmail(email: email)
        return try await performRequest(for: endpoint, requiresAuth: false)
    }

    // MARK: - Additional Health Data Methods

    func getHealthKitUploadStatus(uploadId: String) async throws -> HealthKitUploadStatusDTO {
        let endpoint = HealthDataEndpoint.getUploadStatus(uploadId: uploadId)
        return try await performRequest(for: endpoint)
    }

    func getProcessingStatus(id: UUID) async throws -> HealthDataProcessingStatusDTO {
        let endpoint = HealthDataEndpoint.getProcessingStatus(id: id)
        return try await performRequest(for: endpoint)
    }

    // MARK: - Additional Insights Methods

    func getInsight(id: String) async throws -> InsightGenerationResponseDTO {
        let endpoint = InsightEndpoint.getInsight(id: id)
        return try await performRequest(for: endpoint)
    }

    func getInsightsServiceStatus() async throws -> ServiceStatusResponseDTO {
        let endpoint = InsightEndpoint.getServiceStatus
        return try await performRequest(for: endpoint)
    }

    // MARK: - PAT Analysis Methods

    func analyzeStepData(requestDTO: StepDataRequestDTO) async throws -> StepAnalysisResponseDTO {
        let endpoint = PATEndpoint.analyzeStepData(dto: requestDTO)
        return try await performRequest(for: endpoint)
    }

    func analyzeActigraphy(requestDTO: DirectActigraphyRequestDTO) async throws -> ActigraphyAnalysisResponseDTO {
        let endpoint = PATEndpoint.analyzeActigraphy(dto: requestDTO)
        return try await performRequest(for: endpoint)
    }

    func getPATAnalysis(id: String) async throws -> PATAnalysisResponseDTO {
        let endpoint = PATEndpoint.getAnalysis(id: id)
        return try await performRequest(for: endpoint)
    }

    func getPATServiceHealth() async throws -> ServiceStatusResponseDTO {
        let endpoint = PATEndpoint.getServiceHealth
        return try await performRequest(for: endpoint)
    }

    // MARK: - Private Request Helper

    /// A generic helper to perform network requests, handle authentication, and decode responses.
    /// This method centralizes error handling and token attachment.
    private func performRequest<T: Decodable>(
        for endpoint: Endpoint,
        requiresAuth: Bool = true
    ) async throws -> T {
        print("🚀 APIClient: Starting request to \(endpoint.path)")

        guard let request = try? endpoint.asURLRequest(baseURL: baseURL, encoder: encoder) else {
            print("❌ APIClient: Invalid URL for endpoint \(endpoint.path)")
            throw APIError.invalidURL
        }

        var authorizedRequest = request
        if requiresAuth {
            guard let token = await tokenProvider() else {
                throw APIError.unauthorized
            }

            authorizedRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        do {
            let (data, response) = try await session.data(for: authorizedRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.unknown(URLError(.badServerResponse))
            }

            switch httpResponse.statusCode {
            case 202:
                // Special handling for 202 Accepted (email verification required)

                // Check if we can decode the email verification required response
                if
                    let verificationRequired = try? decoder.decode(EmailVerificationRequiredDTO.self, from: data),
                    verificationRequired.requiresEmailVerification {
                    throw APIError.emailVerificationRequired
                }

                // If we can't decode the expected response, fall through to normal handling
                throw APIError.serverError(statusCode: 202, message: "Email verification required")

            case 200...299:
                do {
                    // Handle empty response body for 204 No Content
                    if data.isEmpty, let empty = EmptyResponse() as? T {
                        print("✅ APIClient: Empty response success")
                        return empty
                    }
                    let result = try decoder.decode(T.self, from: data)
                    print("✅ APIClient: Successfully decoded response")
                    return result
                } catch {
                    print("❌ APIClient: Decoding error: \(error)")
                    // Log the raw response for debugging
                    if let jsonString = String(data: data, encoding: .utf8) {
                        print("📄 APIClient: Raw response: \(jsonString)")
                    }
                    throw APIError.decodingError(error)
                }
            case 401:
                print("❌ APIClient: Unauthorized (401)")
                if requiresAuth {
                    if let result: T = await retryWithRefreshedToken(authorizedRequest) {
                        return result
                    }
                }
                throw APIError.unauthorized
            default:
                let serverMessage = try? decoder.decode(MessageResponseDTO.self, from: data).message
                print("❌ APIClient: Server error \(httpResponse.statusCode): \(serverMessage ?? "No message")")
                // Log the raw error response
                if let jsonString = String(data: data, encoding: .utf8) {
                    print("📄 APIClient: Raw error response: \(jsonString)")
                }
                throw APIError.serverError(statusCode: httpResponse.statusCode, message: serverMessage)
            }
        } catch let error as APIError {
            throw error
        } catch let error as URLError {
            throw APIError.networkError(error)
        } catch {
            throw APIError.unknown(error)
        }
    }

    private func retryWithRefreshedToken<T: Decodable>(_ request: URLRequest) async -> T? {
        guard let refreshedToken = await tokenProvider() else {
            return nil
        }

        var authorizedRequest = request
        authorizedRequest.setValue("Bearer \(refreshedToken)", forHTTPHeaderField: "Authorization")

        // Retry the request once with fresh token
        guard
            let retryData = try? await session.data(for: authorizedRequest),
            let retryResponse = retryData.1 as? HTTPURLResponse,
            retryResponse.statusCode >= 200, retryResponse.statusCode < 300 else {
            return nil
        }
        do {
            if retryData.0.isEmpty, let empty = EmptyResponse() as? T {
                return empty
            }
            return try decoder.decode(T.self, from: retryData.0)
        } catch {
            print("❌ APIClient: Retry decoding error: \(error)")
            return nil
        }
    }
}

// MARK: - Endpoint Definition

protocol Endpoint {
    var path: String { get }
    var method: HTTPMethod { get }

    // The body is now a function that takes an encoder.
    func body(encoder: JSONEncoder) throws -> Data?
}

extension Endpoint {
    func asURLRequest(baseURL: URL, encoder: JSONEncoder) throws -> URLRequest {
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try body(encoder: encoder)
        return request
    }
}

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case patch = "PATCH"
}

/// A helper struct for empty JSON responses.
struct EmptyResponse: Codable {}
