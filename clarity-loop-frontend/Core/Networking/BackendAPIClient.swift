import Amplify
import Foundation

// MARK: - Backend API Client

/// Enhanced API client that uses the backend contract adapter for all requests
/// This ensures perfect compatibility with the backend API
final class BackendAPIClient: APIClientProtocol {
    // MARK: - Properties

    private let baseURL: URL
    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder
    private let tokenProvider: () async -> String?
    private let contractAdapter: BackendContractAdapterProtocol

    // MARK: - Initializer

    init?(
        baseURLString: String = AppConfig.apiBaseURL,
        session: URLSession = .shared,
        tokenProvider: @escaping () async -> String?,
        contractAdapter: BackendContractAdapterProtocol = BackendContractAdapter()
    ) {
        guard let baseURL = URL(string: baseURLString) else {
            return nil
        }
        self.baseURL = baseURL
        self.session = session
        self.tokenProvider = tokenProvider
        self.contractAdapter = contractAdapter

        self.decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        self.encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.keyEncodingStrategy = .convertToSnakeCase
    }

    // MARK: - Authentication Methods

    func register(requestDTO: UserRegistrationRequestDTO) async throws -> RegistrationResponseDTO {
        // Adapt frontend DTO to backend format
        let backendRequest = contractAdapter.adaptRegistrationRequest(requestDTO)

        // Make the request
        let endpoint = AuthEndpoint.register(dto: requestDTO) // We'll override the body
        let backendResponse: BackendTokenResponse = try await performBackendRequest(
            for: endpoint,
            body: backendRequest,
            requiresAuth: false
        )

        // Adapt response back to frontend format
        return try contractAdapter.adaptRegistrationResponse(backendResponse)
    }

    func login(requestDTO: UserLoginRequestDTO) async throws -> LoginResponseDTO {
        // Adapt frontend DTO to backend format
        let backendRequest = contractAdapter.adaptLoginRequest(requestDTO)

        // Make the login request
        let endpoint = AuthEndpoint.login(dto: requestDTO) // We'll override the body
        let tokenResponse: BackendTokenResponse = try await performBackendRequest(
            for: endpoint,
            body: backendRequest,
            requiresAuth: false
        )

        // Now fetch user info to complete the login response
        let userInfoEndpoint = AuthEndpoint.getCurrentUser
        let userInfo: BackendUserInfoResponse = try await performBackendRequest(
            for: userInfoEndpoint,
            requiresAuth: true,
            accessToken: tokenResponse.accessToken
        )

        // Combine responses
        let userSession = contractAdapter.adaptUserInfoResponse(userInfo)
        let tokens = contractAdapter.adaptTokenResponse(tokenResponse)

        return LoginResponseDTO(user: userSession, tokens: tokens)
    }

    func refreshToken(requestDTO: RefreshTokenRequestDTO) async throws -> TokenResponseDTO {
        let backendRequest = contractAdapter.adaptRefreshTokenRequest(requestDTO.refreshToken)

        let backendResponse: BackendTokenResponse = try await performBackendRequest(
            for: AuthEndpoint.refreshToken(dto: requestDTO),
            body: backendRequest,
            requiresAuth: false
        )

        return contractAdapter.adaptTokenResponse(backendResponse)
    }

    func logout() async throws -> MessageResponseDTO {
        let backendResponse: BackendLogoutResponse = try await performBackendRequest(
            for: AuthEndpoint.logout,
            requiresAuth: true
        )

        return contractAdapter.adaptLogoutResponse(backendResponse)
    }

    func getCurrentUser() async throws -> UserSessionResponseDTO {
        let backendResponse: BackendUserInfoResponse = try await performBackendRequest(
            for: AuthEndpoint.getCurrentUser,
            requiresAuth: true
        )

        return contractAdapter.adaptUserInfoResponse(backendResponse)
    }

    // MARK: - Private Request Methods

    private func performBackendRequest<Response: Decodable>(
        for endpoint: Endpoint,
        requiresAuth: Bool = true,
        accessToken: String? = nil
    ) async throws -> Response {
        try await performBackendRequest(
            for: endpoint,
            body: EmptyBody(),
            requiresAuth: requiresAuth,
            accessToken: accessToken
        )
    }

    private func performBackendRequest<Response: Decodable>(
        for endpoint: Endpoint,
        body: some Encodable,
        requiresAuth: Bool = true,
        accessToken: String? = nil
    ) async throws -> Response {
        // Build URL
        guard let url = URL(string: endpoint.path, relativeTo: baseURL) else {
            throw APIError.invalidURL
        }

        // Create request
        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add body if provided
        if !(body is EmptyBody) {
            request.httpBody = try encoder.encode(body)
        } else if endpoint.method.requiresBody {
            // Use endpoint's body method if no override provided
            request.httpBody = try endpoint.body(encoder: encoder)
        }

        // Add authentication
        if requiresAuth {
            let token: String? = if let providedToken = accessToken {
                providedToken
            } else {
                await tokenProvider()
            }

            if let token {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            } else {
                throw APIError.missingAuthToken
            }
        }

        // Perform request
        do {
            let (data, response) = try await session.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse else {
                throw APIError.invalidResponse
            }

            // Handle errors
            if httpResponse.statusCode >= 400 {
                // Handle 401 Unauthorized with token refresh
                if httpResponse.statusCode == 401, requiresAuth {
                    // Try to refresh token once
                    if let refreshedResponse: Response = await retryWithRefreshedToken(request) {
                        return refreshedResponse
                    }
                }

                // Try to adapt backend error
                if let adaptedError = contractAdapter.adaptErrorResponse(data) {
                    throw adaptedError
                }

                // Fallback to generic API error
                throw APIError.httpError(statusCode: httpResponse.statusCode, data: data)
            }

            // Decode response
            return try decoder.decode(Response.self, from: data)

        } catch {
            throw error
        }
    }

    // MARK: - Token Refresh Helper

    private func retryWithRefreshedToken<Response: Decodable>(_ originalRequest: URLRequest) async -> Response? {
        // Amplify automatically refreshes tokens when needed
        // Just get a fresh token and retry
        guard let freshToken = await tokenProvider() else {
            return nil
        }

        var retryRequest = originalRequest
        retryRequest.setValue("Bearer \(freshToken)", forHTTPHeaderField: "Authorization")

        do {
            let (data, response) = try await session.data(for: retryRequest)

            guard let httpResponse = response as? HTTPURLResponse else {
                return nil
            }

            if (200...299).contains(httpResponse.statusCode) {
                return try decoder.decode(Response.self, from: data)
            }
        } catch {
            return nil
        }

        return nil
    }

    // MARK: - Other Protocol Methods (Not Implemented Yet)

    func verifyEmail(email: String, code: String) async throws -> LoginResponseDTO {
        let endpoint = AuthEndpoint.verifyEmail(email: email, code: code)
        return try await performBackendRequest(for: endpoint, requiresAuth: false)
    }

    func resendVerificationEmail(email: String) async throws -> MessageResponseDTO {
        let endpoint = AuthEndpoint.resendVerificationEmail(email: email)
        return try await performBackendRequest(for: endpoint, requiresAuth: false)
    }

    func getHealthData(page: Int, limit: Int) async throws -> PaginatedMetricsResponseDTO {
        let endpoint = HealthDataEndpoint.getMetrics(page: page, limit: limit)
        return try await performBackendRequest(for: endpoint, requiresAuth: true)
    }

    func uploadHealthKitData(requestDTO: HealthKitUploadRequestDTO) async throws -> HealthKitUploadResponseDTO {
        let endpoint = HealthDataEndpoint.uploadHealthKit(dto: requestDTO)
        return try await performBackendRequest(for: endpoint, requiresAuth: true)
    }

    func syncHealthKitData(requestDTO: HealthKitSyncRequestDTO) async throws -> HealthKitSyncResponseDTO {
        let endpoint = HealthDataEndpoint.syncHealthKit(dto: requestDTO)
        return try await performBackendRequest(for: endpoint, requiresAuth: true)
    }

    func getHealthKitSyncStatus(syncId: String) async throws -> HealthKitSyncStatusDTO {
        let endpoint = HealthDataEndpoint.getSyncStatus(syncId: syncId)
        return try await performBackendRequest(for: endpoint, requiresAuth: true)
    }

    func getHealthKitUploadStatus(uploadId: String) async throws -> HealthKitUploadStatusDTO {
        let endpoint = HealthDataEndpoint.getUploadStatus(uploadId: uploadId)
        return try await performBackendRequest(for: endpoint, requiresAuth: true)
    }

    func getProcessingStatus(id: UUID) async throws -> HealthDataProcessingStatusDTO {
        let endpoint = HealthDataEndpoint.getProcessingStatus(id: id)
        return try await performBackendRequest(for: endpoint, requiresAuth: true)
    }

    func getInsightHistory(userId: String, limit: Int, offset: Int) async throws -> InsightHistoryResponseDTO {
        let endpoint = InsightEndpoint.getHistory(userId: userId, limit: limit, offset: offset)
        return try await performBackendRequest(for: endpoint, requiresAuth: true)
    }

    func generateInsight(requestDTO: InsightGenerationRequestDTO) async throws -> InsightGenerationResponseDTO {
        let endpoint = InsightEndpoint.generate(dto: requestDTO)
        return try await performBackendRequest(for: endpoint, requiresAuth: true)
    }
    
    func chatWithAI(requestDTO: ChatRequestDTO) async throws -> ChatResponseDTO {
        let endpoint = InsightEndpoint.chat(dto: requestDTO)
        return try await performBackendRequest(for: endpoint, requiresAuth: true)
    }

    func getInsight(id: String) async throws -> InsightGenerationResponseDTO {
        let endpoint = InsightEndpoint.getInsight(id: id)
        return try await performBackendRequest(for: endpoint, requiresAuth: true)
    }

    func getInsightsServiceStatus() async throws -> ServiceStatusResponseDTO {
        let endpoint = InsightEndpoint.getServiceStatus
        return try await performBackendRequest(for: endpoint, requiresAuth: true)
    }

    func analyzeStepData(requestDTO: StepDataRequestDTO) async throws -> StepAnalysisResponseDTO {
        let endpoint = PATEndpoint.analyzeStepData(dto: requestDTO)
        return try await performBackendRequest(for: endpoint, requiresAuth: true)
    }

    func analyzeActigraphy(requestDTO: DirectActigraphyRequestDTO) async throws -> ActigraphyAnalysisResponseDTO {
        let endpoint = PATEndpoint.analyzeActigraphy(dto: requestDTO)
        return try await performBackendRequest(for: endpoint, requiresAuth: true)
    }

    func getPATAnalysis(id: String) async throws -> PATAnalysisResponseDTO {
        let endpoint = PATEndpoint.getAnalysis(id: id)
        return try await performBackendRequest(for: endpoint, requiresAuth: true)
    }

    func getPATServiceHealth() async throws -> ServiceStatusResponseDTO {
        let endpoint = PATEndpoint.getServiceHealth
        return try await performBackendRequest(for: endpoint, requiresAuth: true)
    }
}

// MARK: - HTTP Method Extension

extension HTTPMethod {
    fileprivate var requiresBody: Bool {
        switch self {
        case .post, .put, .patch:
            true
        default:
            false
        }
    }
}

// MARK: - Empty Body Type

private struct EmptyBody: Encodable {}
