import Foundation
import XCTest

// Temporarily disabled - references types that don't exist yet
/*
 /// Mock server that exactly mirrors the backend behavior for E2E testing
 /// This allows us to test without hitting the real backend
 final class BackendMockServer {

     // MARK: - Properties

     private var registeredUsers: [String: BackendUserRegister] = [:]
     private var userTokens: [String: BackendTokenResponse] = [:]
     private var refreshTokens: [String: String] = [:] // refresh token -> email

     // MARK: - Response Builders

     func handleRequest(endpoint: String, method: String, body: Data?, headers: [String: String]) throws -> (statusCode: Int, data: Data) {
         switch (endpoint, method) {
         case ("/api/v1/auth/register", "POST"):
             return try handleRegistration(body: body)

         case ("/api/v1/auth/login", "POST"):
             return try handleLogin(body: body)

         case ("/api/v1/auth/me", "GET"):
             return try handleGetCurrentUser(headers: headers)

         case ("/api/v1/auth/refresh", "POST"):
             return try handleRefreshToken(body: body)

         case ("/api/v1/auth/logout", "POST"):
             return try handleLogout(headers: headers)

         case ("/api/v1/auth/health", "GET"):
             return try handleHealthCheck()

         default:
             throw MockServerError.endpointNotFound
         }
     }

     // MARK: - Registration Handler

     private func handleRegistration(body: Data?) throws -> (statusCode: Int, data: Data) {
         guard let body = body else {
             throw MockServerError.missingBody
         }

         let decoder = JSONDecoder()
         let request = try decoder.decode(BackendUserRegister.self, from: body)

         // Validate request
         guard request.email.contains("@") else {
             return createValidationError(field: "email", message: "Invalid email format")
         }

         guard request.password.count >= 8 else {
             return createValidationError(field: "password", message: "Password must be at least 8 characters")
         }

         // Check if user exists
         if registeredUsers[request.email] != nil {
             return createProblemDetail(
                 type: "user_already_exists",
                 title: "User Already Exists",
                 detail: "A user with this email already exists",
                 status: 409
             )
         }

         // Register user
         registeredUsers[request.email] = request

         // Generate tokens
         let tokenResponse = generateTokenResponse(email: request.email)
         userTokens[request.email] = tokenResponse
         refreshTokens[tokenResponse.refreshToken] = request.email

         let encoder = JSONEncoder()
         encoder.keyEncodingStrategy = .convertToSnakeCase
         let responseData = try encoder.encode(tokenResponse)

         return (statusCode: 200, data: responseData)
     }

     // MARK: - Login Handler

     private func handleLogin(body: Data?) throws -> (statusCode: Int, data: Data) {
         guard let body = body else {
             throw MockServerError.missingBody
         }

         let decoder = JSONDecoder()
         let request = try decoder.decode(BackendUserLogin.self, from: body)

         // Check if user exists
         guard let registeredUser = registeredUsers[request.email] else {
             return createProblemDetail(
                 type: "invalid_credentials",
                 title: "Invalid Credentials",
                 detail: "Invalid email or password",
                 status: 401
             )
         }

         // Check password (simplified - just check if it matches)
         guard registeredUser.password == request.password else {
             return createProblemDetail(
                 type: "invalid_credentials",
                 title: "Invalid Credentials",
                 detail: "Invalid email or password",
                 status: 401
             )
         }

         // Generate new tokens
         let tokenResponse = generateTokenResponse(email: request.email)
         userTokens[request.email] = tokenResponse
         refreshTokens[tokenResponse.refreshToken] = request.email

         let encoder = JSONEncoder()
         encoder.keyEncodingStrategy = .convertToSnakeCase
         let responseData = try encoder.encode(tokenResponse)

         return (statusCode: 200, data: responseData)
     }

     // MARK: - Get Current User Handler

     private func handleGetCurrentUser(headers: [String: String]) throws -> (statusCode: Int, data: Data) {
         guard let authHeader = headers["Authorization"],
               authHeader.hasPrefix("Bearer ") else {
             return createProblemDetail(
                 type: "authentication_required",
                 title: "Authentication Required",
                 detail: "Missing or invalid authorization header",
                 status: 401
             )
         }

         let token = String(authHeader.dropFirst(7))

         // Find user by token
         guard let email = userTokens.first(where: { $0.value.accessToken == token })?.key,
               let user = registeredUsers[email] else {
             return createProblemDetail(
                 type: "invalid_token",
                 title: "Invalid Token",
                 detail: "The provided token is invalid or expired",
                 status: 401
             )
         }

         let userInfo = BackendUserInfoResponse(
             userId: UUID().uuidString,
             email: email,
             emailVerified: true,
             displayName: user.displayName,
             authProvider: "cognito"
         )

         let encoder = JSONEncoder()
         encoder.keyEncodingStrategy = .convertToSnakeCase
         let responseData = try encoder.encode(userInfo)

         return (statusCode: 200, data: responseData)
     }

     // MARK: - Refresh Token Handler

     private func handleRefreshToken(body: Data?) throws -> (statusCode: Int, data: Data) {
         let decoder = JSONDecoder()

         // Try to get refresh token from body
         var refreshToken: String?
         if let body = body {
             let request = try? decoder.decode(BackendRefreshTokenRequest.self, from: body)
             refreshToken = request?.refreshToken
         }

         guard let token = refreshToken,
               let email = refreshTokens[token] else {
             return createProblemDetail(
                 type: "invalid_refresh_token",
                 title: "Invalid Refresh Token",
                 detail: "The refresh token is invalid or expired",
                 status: 401
             )
         }

         // Generate new access token (keep same refresh token like Cognito)
         let tokenResponse = generateTokenResponse(email: email, keepRefreshToken: token)
         userTokens[email] = tokenResponse

         let encoder = JSONEncoder()
         encoder.keyEncodingStrategy = .convertToSnakeCase
         let responseData = try encoder.encode(tokenResponse)

         return (statusCode: 200, data: responseData)
     }

     // MARK: - Logout Handler

     private func handleLogout(headers: [String: String]) throws -> (statusCode: Int, data: Data) {
         // Backend doesn't require auth for logout, just returns success
         let response = BackendLogoutResponse(message: "Successfully logged out")

         let encoder = JSONEncoder()
         let responseData = try encoder.encode(response)

         return (statusCode: 200, data: responseData)
     }

     // MARK: - Health Check Handler

     private func handleHealthCheck() throws -> (statusCode: Int, data: Data) {
         let response = BackendHealthResponse(
             status: "healthy",
             service: "authentication",
             version: "1.0.0"
         )

         let encoder = JSONEncoder()
         let responseData = try encoder.encode(response)

         return (statusCode: 200, data: responseData)
     }

     // MARK: - Helper Methods

     private func generateTokenResponse(email: String, keepRefreshToken: String? = nil) -> BackendTokenResponse {
         let accessToken = "mock_access_token_\(UUID().uuidString)"
         let refreshToken = keepRefreshToken ?? "mock_refresh_token_\(UUID().uuidString)"

         return BackendTokenResponse(
             accessToken: accessToken,
             refreshToken: refreshToken,
             tokenType: "Bearer",
             expiresIn: 3600,
             scope: "full_access"
         )
     }

     private func createValidationError(field: String, message: String) -> (statusCode: Int, data: Data) {
         let error = BackendValidationError(
             detail: [
                 ValidationErrorDetail(
                     loc: ["body", field],
                     msg: message,
                     type: "value_error"
                 )
             ]
         )

         let encoder = JSONEncoder()
         let data = try! encoder.encode(error)

         return (statusCode: 422, data: data)
     }

     private func createProblemDetail(type: String, title: String, detail: String, status: Int) -> (statusCode: Int, data: Data) {
         let problem = BackendProblemDetail(
             type: type,
             title: title,
             detail: detail,
             status: status,
             instance: "https://api.clarity.health/requests/\(UUID().uuidString)"
         )

         let encoder = JSONEncoder()
         let data = try! encoder.encode(problem)

         return (statusCode: status, data: data)
     }
 }

 // MARK: - Mock Server Error

 enum MockServerError: Error {
     case endpointNotFound
     case missingBody
     case invalidRequest
 }

 // MARK: - URLSession Mock Extension

 extension URLSession {
     static func mockSession(server: BackendMockServer) -> URLSession {
         let config = URLSessionConfiguration.ephemeral
         config.protocolClasses = [MockURLProtocol.self]
         MockURLProtocol.mockServer = server
         return URLSession(configuration: config)
     }
 }

 // MARK: - Mock URL Protocol

 class MockURLProtocol: URLProtocol {
     static var mockServer: BackendMockServer?

     override class func canInit(with request: URLRequest) -> Bool {
         return true
     }

     override class func canonicalRequest(for request: URLRequest) -> URLRequest {
         return request
     }

     override func startLoading() {
         guard let server = MockURLProtocol.mockServer,
               let url = request.url else {
             client?.urlProtocol(self, didFailWithError: MockServerError.endpointNotFound)
             return
         }

         let path = url.path
         let method = request.httpMethod ?? "GET"
         let headers = request.allHTTPHeaderFields ?? [:]

         do {
             let (statusCode, data) = try server.handleRequest(
                 endpoint: path,
                 method: method,
                 body: request.httpBody,
                 headers: headers
             )

             let response = HTTPURLResponse(
                 url: url,
                 statusCode: statusCode,
                 httpVersion: "HTTP/1.1",
                 headerFields: ["Content-Type": "application/json"]
             )!

             client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
             client?.urlProtocol(self, didLoad: data)
             client?.urlProtocolDidFinishLoading(self)

         } catch {
             client?.urlProtocol(self, didFailWithError: error)
         }
     }

     override func stopLoading() {
         // Nothing to do
     }
 }*/
