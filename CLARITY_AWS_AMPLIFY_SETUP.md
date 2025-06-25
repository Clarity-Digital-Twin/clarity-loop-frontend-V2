# CLARITY AWS Amplify Configuration & Setup Guide

## Overview

This document provides the complete AWS Amplify setup and configuration for CLARITY Pulse, including authentication, API integration, and real-time features.

## ⚠️ CRITICAL: Configuration Files Already Exist!

The project already has `amplifyconfiguration.json` and `awsconfiguration.json`. DO NOT regenerate these files unless absolutely necessary.

## Current AWS Services Architecture

```
┌─────────────────────────────────────────────────────┐
│                   iOS App                           │
├─────────────────────────────────────────────────────┤
│                AWS Amplify SDK                      │
├─────────────────────────────────────────────────────┤
│  Cognito  │  API Gateway  │  S3  │  AppSync  │ IoT │
├───────────┼───────────────┼──────┼──────────┼─────┤
│  Lambda   │   DynamoDB    │  SQS │   SNS    │ SES │
└─────────────────────────────────────────────────────┘
```

## Amplify SDK Integration

### 1. Package Dependencies

```swift
// Package.swift or Xcode Package Manager
dependencies: [
    .package(
        url: "https://github.com/aws-amplify/amplify-swift",
        from: "2.25.0"
    )
]

// Required modules
.product(name: "AWSAPIPlugin", package: "amplify-swift"),
.product(name: "AWSCognitoAuthPlugin", package: "amplify-swift"),
.product(name: "AWSDataStorePlugin", package: "amplify-swift"),
.product(name: "AWSS3StoragePlugin", package: "amplify-swift"),
.product(name: "Amplify", package: "amplify-swift")
```

### 2. Amplify Configuration

```swift
// AmplifyConfiguration.swift
import Amplify
import AWSAPIPlugin
import AWSCognitoAuthPlugin
import AWSDataStorePlugin
import AWSS3StoragePlugin

final class AmplifyConfiguration {
    static let shared = AmplifyConfiguration()
    
    private init() {}
    
    func configure() throws {
        do {
            // Add plugins
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.add(plugin: AWSAPIPlugin())
            try Amplify.add(plugin: AWSDataStorePlugin(modelRegistration: AmplifyModels()))
            try Amplify.add(plugin: AWSS3StoragePlugin())
            
            // Configure
            try Amplify.configure()
            
            Logger.shared.info("Amplify configured successfully")
            
        } catch {
            Logger.shared.error("Failed to configure Amplify: \(error)")
            throw AmplifyError.configuration(error)
        }
    }
}

enum AmplifyError: LocalizedError {
    case configuration(Error)
    case notConfigured
    
    var errorDescription: String? {
        switch self {
        case .configuration(let error):
            return "Amplify configuration failed: \(error.localizedDescription)"
        case .notConfigured:
            return "Amplify is not configured"
        }
    }
}
```

### 3. App Initialization

```swift
// ClarityApp.swift
@main
struct ClarityApp: App {
    init() {
        // Configure Amplify before anything else
        do {
            try AmplifyConfiguration.shared.configure()
        } catch {
            fatalError("Failed to configure Amplify: \(error)")
        }
        
        // ⚠️ HUMAN INTERVENTION: Verify amplifyconfiguration.json exists in project
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## Authentication Service

### Cognito Integration

```swift
// CognitoAuthService.swift
import Amplify
import AWSCognitoAuthPlugin

final class CognitoAuthService: AuthServiceProtocol {
    
    // MARK: - Sign Up
    
    func signUp(email: String, password: String, firstName: String, lastName: String) async throws -> SignUpResult {
        let userAttributes = [
            AuthUserAttribute(.email, value: email),
            AuthUserAttribute(.givenName, value: firstName),
            AuthUserAttribute(.familyName, value: lastName)
        ]
        
        let options = AuthSignUpRequest.Options(userAttributes: userAttributes)
        
        do {
            let result = try await Amplify.Auth.signUp(
                username: email,
                password: password,
                options: options
            )
            
            return SignUpResult(
                userId: result.userID ?? email,
                isConfirmationRequired: result.isSignUpComplete == false
            )
            
        } catch let error as AuthError {
            throw mapAuthError(error)
        }
    }
    
    // MARK: - Sign In
    
    func signIn(email: String, password: String) async throws -> AuthUser {
        do {
            let result = try await Amplify.Auth.signIn(
                username: email,
                password: password
            )
            
            guard result.isSignedIn else {
                throw AuthError.signInFailed("Sign in incomplete")
            }
            
            return try await getCurrentUser()
            
        } catch let error as AuthError {
            throw mapAuthError(error)
        }
    }
    
    // MARK: - Sign Out
    
    func signOut() async throws {
        _ = try await Amplify.Auth.signOut()
    }
    
    // MARK: - Confirm Sign Up
    
    func confirmSignUp(email: String, code: String) async throws {
        do {
            let result = try await Amplify.Auth.confirmSignUp(
                for: email,
                confirmationCode: code
            )
            
            guard result.isSignUpComplete else {
                throw AuthError.confirmationFailed
            }
            
        } catch let error as AuthError {
            throw mapAuthError(error)
        }
    }
    
    // MARK: - Reset Password
    
    func resetPassword(email: String) async throws {
        do {
            let result = try await Amplify.Auth.resetPassword(for: email)
            
            Logger.shared.info("Password reset initiated: \(result.nextStep)")
            
        } catch let error as AuthError {
            throw mapAuthError(error)
        }
    }
    
    func confirmResetPassword(email: String, newPassword: String, code: String) async throws {
        do {
            try await Amplify.Auth.confirmResetPassword(
                for: email,
                with: newPassword,
                confirmationCode: code
            )
        } catch let error as AuthError {
            throw mapAuthError(error)
        }
    }
    
    // MARK: - Session Management
    
    func fetchAuthSession() async throws -> AuthSession {
        try await Amplify.Auth.fetchAuthSession()
    }
    
    func getCurrentUser() async throws -> AuthUser {
        let user = try await Amplify.Auth.getCurrentUser()
        let attributes = try await Amplify.Auth.fetchUserAttributes()
        
        var email: String?
        var firstName: String?
        var lastName: String?
        
        for attribute in attributes {
            switch attribute.key {
            case .email:
                email = attribute.value
            case .givenName:
                firstName = attribute.value
            case .familyName:
                lastName = attribute.value
            default:
                break
            }
        }
        
        return AuthUser(
            id: user.userId,
            email: email ?? user.username,
            firstName: firstName,
            lastName: lastName,
            isEmailVerified: true // Cognito requires verification
        )
    }
    
    // MARK: - Token Management
    
    func getAccessToken() async throws -> String {
        let session = try await Amplify.Auth.fetchAuthSession()
        
        guard let cognitoSession = session as? AuthCognitoTokensProvider,
              let tokens = try? cognitoSession.getCognitoTokens() else {
            throw AuthError.sessionExpired
        }
        
        return tokens.accessToken.rawValue
    }
    
    func refreshToken() async throws {
        _ = try await Amplify.Auth.fetchAuthSession(options: .forceRefresh())
    }
    
    // MARK: - Error Mapping
    
    private func mapAuthError(_ error: AuthError) -> ClarityAuthError {
        switch error {
        case .service(_, _, let underlyingError):
            if let cognitoError = underlyingError as? AWSCognitoAuthError {
                switch cognitoError {
                case .userNotFound:
                    return .userNotFound
                case .userNotConfirmed:
                    return .emailNotVerified
                case .invalidPassword:
                    return .invalidCredentials
                case .limitExceeded:
                    return .tooManyAttempts
                default:
                    break
                }
            }
            
        case .validation:
            return .validationError(error.errorDescription)
            
        case .notAuthorized:
            return .unauthorized
            
        case .sessionExpired:
            return .sessionExpired
            
        default:
            break
        }
        
        return .unknown(error)
    }
}
```

### Biometric Authentication Integration

```swift
// BiometricAuthService.swift
import LocalAuthentication
import Amplify

final class BiometricAuthService {
    private let context = LAContext()
    private let keychainService: KeychainService
    
    init(keychainService: KeychainService = .shared) {
        self.keychainService = keychainService
    }
    
    // MARK: - Biometric Login
    
    func authenticateWithBiometrics() async throws -> AuthUser {
        // First, authenticate with biometrics
        try await performBiometricAuthentication()
        
        // Retrieve stored credentials
        guard let credentials = try? keychainService.retrieveCredentials() else {
            throw BiometricAuthError.noStoredCredentials
        }
        
        // Sign in with stored credentials
        let authService = CognitoAuthService()
        return try await authService.signIn(
            email: credentials.email,
            password: credentials.password
        )
    }
    
    // MARK: - Store Credentials
    
    func enableBiometricLogin(email: String, password: String) async throws {
        // Verify biometrics available
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) else {
            throw BiometricAuthError.notAvailable
        }
        
        // Store credentials securely
        try keychainService.storeCredentials(
            email: email,
            password: password,
            requiresBiometric: true
        )
    }
    
    private func performBiometricAuthentication() async throws {
        let reason = "Authenticate to access your health data"
        
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            
            guard success else {
                throw BiometricAuthError.authenticationFailed
            }
            
        } catch let error as LAError {
            throw mapLAError(error)
        }
    }
}
```

## API Integration

### GraphQL API Client

```swift
// GraphQLAPIClient.swift
import Amplify
import AWSAPIPlugin

final class GraphQLAPIClient {
    
    // MARK: - Queries
    
    func fetchHealthData(userId: String, limit: Int = 50) async throws -> [HealthData] {
        let request = GraphQLRequest(
            document: """
            query GetHealthData($userId: ID!, $limit: Int) {
                listHealthData(
                    filter: { userId: { eq: $userId } },
                    limit: $limit
                ) {
                    items {
                        id
                        userId
                        type
                        value
                        unit
                        timestamp
                        source
                    }
                }
            }
            """,
            variables: [
                "userId": userId,
                "limit": limit
            ],
            responseType: HealthDataList.self
        )
        
        do {
            let result = try await Amplify.API.query(request: request)
            
            switch result {
            case .success(let data):
                return data.listHealthData.items
            case .failure(let error):
                throw APIError.graphQL(error)
            }
        } catch {
            throw APIError.network(error)
        }
    }
    
    // MARK: - Mutations
    
    func createHealthData(_ data: HealthData) async throws -> HealthData {
        let request = GraphQLRequest(
            document: """
            mutation CreateHealthData($input: CreateHealthDataInput!) {
                createHealthData(input: $input) {
                    id
                    userId
                    type
                    value
                    unit
                    timestamp
                    source
                    createdAt
                    updatedAt
                }
            }
            """,
            variables: ["input": data.toInput()],
            responseType: HealthData.self
        )
        
        let result = try await Amplify.API.mutate(request: request)
        
        switch result {
        case .success(let created):
            return created
        case .failure(let error):
            throw APIError.graphQL(error)
        }
    }
    
    // MARK: - Subscriptions
    
    func subscribeToHealthDataUpdates(
        userId: String,
        onUpdate: @escaping (HealthData) -> Void
    ) async throws -> GraphQLSubscriptionTask<HealthData> {
        let request = GraphQLRequest(
            document: """
            subscription OnHealthDataUpdate($userId: ID!) {
                onUpdateHealthData(userId: $userId) {
                    id
                    userId
                    type
                    value
                    unit
                    timestamp
                    source
                }
            }
            """,
            variables: ["userId": userId],
            responseType: HealthData.self
        )
        
        let subscription = Amplify.API.subscribe(request: request)
        
        Task {
            do {
                for try await subscriptionEvent in subscription {
                    switch subscriptionEvent {
                    case .connection(let state):
                        Logger.shared.info("Subscription state: \(state)")
                        
                    case .data(let result):
                        switch result {
                        case .success(let data):
                            onUpdate(data)
                        case .failure(let error):
                            Logger.shared.error("Subscription error: \(error)")
                        }
                    }
                }
            } catch {
                Logger.shared.error("Subscription terminated: \(error)")
            }
        }
        
        return subscription
    }
}
```

### REST API Client

```swift
// RESTAPIClient.swift
import Amplify

final class RESTAPIClient {
    private let apiName = "ClarityAPI"
    
    func uploadHealthData(_ data: HealthDataUploadRequest) async throws -> ProcessingResponse {
        let path = "/health-data"
        let request = RESTRequest(
            path: path,
            body: try JSONEncoder().encode(data)
        )
        
        let data = try await Amplify.API.post(
            request: request,
            apiName: apiName
        )
        
        return try JSONDecoder().decode(ProcessingResponse.self, from: data)
    }
    
    func fetchInsights(userId: String) async throws -> [Insight] {
        let path = "/insights"
        let request = RESTRequest(
            path: path,
            queryParameters: ["userId": userId]
        )
        
        let data = try await Amplify.API.get(
            request: request,
            apiName: apiName
        )
        
        return try JSONDecoder().decode([Insight].self, from: data)
    }
}
```

## Storage Integration

### S3 File Upload

```swift
// S3StorageService.swift
import Amplify
import AWSS3StoragePlugin

final class S3StorageService {
    
    // MARK: - Upload
    
    func uploadHealthExport(_ data: Data, fileName: String) async throws -> String {
        let key = "exports/\(UUID().uuidString)/\(fileName)"
        
        let uploadTask = Amplify.Storage.uploadData(
            key: key,
            data: data,
            options: .init(
                accessLevel: .private,
                metadata: [
                    "content-type": "application/json",
                    "uploaded-by": "ios-app"
                ]
            )
        )
        
        // Monitor progress
        Task {
            for await progress in await uploadTask.progress {
                Logger.shared.info("Upload progress: \(progress.fractionCompleted)")
            }
        }
        
        let result = try await uploadTask.value
        return result.key
    }
    
    // MARK: - Download
    
    func downloadExport(key: String) async throws -> Data {
        let downloadTask = Amplify.Storage.downloadData(
            key: key,
            options: .init(accessLevel: .private)
        )
        
        let data = try await downloadTask.value
        return data
    }
    
    // MARK: - Generate URL
    
    func generateDownloadURL(key: String, expiresIn: TimeInterval = 3600) async throws -> URL {
        let url = try await Amplify.Storage.getURL(
            key: key,
            options: .init(
                accessLevel: .private,
                expires: Date().addingTimeInterval(expiresIn)
            )
        )
        
        return url
    }
    
    // MARK: - Delete
    
    func deleteExport(key: String) async throws {
        try await Amplify.Storage.remove(
            key: key,
            options: .init(accessLevel: .private)
        )
    }
}
```

## Real-Time Features

### WebSocket Connection via AWS IoT

```swift
// IoTWebSocketManager.swift
import Amplify
import AWSIoT

final class IoTWebSocketManager {
    private var iotDataManager: AWSIoTDataManager?
    private let topicPrefix = "clarity/health/"
    
    func connect() async throws {
        let credentials = try await getIoTCredentials()
        
        iotDataManager = AWSIoTDataManager(
            forKey: "ClarityIoT",
            withEndpoint: credentials.endpoint,
            credentials: credentials
        )
        
        try await withCheckedThrowingContinuation { continuation in
            iotDataManager?.connectWebSocket { result in
                if result {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: IoTError.connectionFailed)
                }
            }
        }
    }
    
    func subscribe(to topic: String, onMessage: @escaping (Data) -> Void) {
        let fullTopic = "\(topicPrefix)\(topic)"
        
        iotDataManager?.subscribe(
            toTopic: fullTopic,
            qoS: .messageDeliveryAttemptedAtLeastOnce
        ) { data in
            onMessage(data)
        }
    }
    
    func publish(message: Data, to topic: String) {
        let fullTopic = "\(topicPrefix)\(topic)"
        
        iotDataManager?.publishData(
            message,
            onTopic: fullTopic,
            qoS: .messageDeliveryAttemptedAtMostOnce
        )
    }
}
```

## Push Notifications

### SNS Integration

```swift
// PushNotificationService.swift
import Amplify

final class PushNotificationService {
    
    func registerDevice(token: Data) async throws {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        
        let request = RESTRequest(
            path: "/device/register",
            body: try JSONEncoder().encode([
                "token": tokenString,
                "platform": "ios"
            ])
        )
        
        _ = try await Amplify.API.post(
            request: request,
            apiName: "ClarityAPI"
        )
    }
    
    func updateNotificationPreferences(_ preferences: NotificationPreferences) async throws {
        let request = RESTRequest(
            path: "/notifications/preferences",
            body: try JSONEncoder().encode(preferences)
        )
        
        _ = try await Amplify.API.put(
            request: request,
            apiName: "ClarityAPI"
        )
    }
}
```

## Error Handling

```swift
// AmplifyErrorHandler.swift
enum AmplifyErrorHandler {
    static func handle(_ error: Error) -> ClarityError {
        if let authError = error as? AuthError {
            return mapAuthError(authError)
        }
        
        if let apiError = error as? APIError {
            return mapAPIError(apiError)
        }
        
        if let storageError = error as? StorageError {
            return mapStorageError(storageError)
        }
        
        return .unknown(error)
    }
    
    private static func mapAuthError(_ error: AuthError) -> ClarityError {
        switch error {
        case .sessionExpired:
            return .sessionExpired
        case .notAuthorized:
            return .unauthorized
        case .invalidState:
            return .invalidState
        default:
            return .authentication(error)
        }
    }
}
```

## Testing with Amplify

### Mock Configuration

```swift
// AmplifyMockConfiguration.swift
final class AmplifyMockConfiguration {
    static func configureMocks() throws {
        // Use in-memory configuration for tests
        let config = AmplifyConfiguration(
            auth: .init(
                plugins: [
                    "awsCognitoAuthPlugin": [
                        "IdentityManager": [
                            "Default": [:]
                        ],
                        "CognitoUserPool": [
                            "Default": [
                                "PoolId": "mock-pool-id",
                                "Region": "us-east-1",
                                "AppClientId": "mock-client-id"
                            ]
                        ]
                    ]
                ]
            )
        )
        
        try Amplify.configure(config)
    }
}
```

## ⚠️ HUMAN INTERVENTION REQUIRED

### Amplify CLI Setup
1. **Install Amplify CLI**: `npm install -g @aws-amplify/cli`
2. **Configure Amplify**: `amplify configure`
3. **Pull existing backend**: `amplify pull`
4. **DO NOT run** `amplify init` - project already configured

### Xcode Configuration
1. **Add amplifyconfiguration.json** to Xcode project
2. **Ensure file is in Copy Bundle Resources**
3. **Add AWS SDK packages** via Swift Package Manager
4. **Configure App Transport Security** if needed

### Testing Setup
1. **Create test configuration** in AWS Console
2. **Generate test user pool** for integration tests
3. **Configure test API endpoints**
4. **Set up mock S3 bucket** for storage tests

### Monitoring
1. **Enable CloudWatch logs** for Lambda functions
2. **Set up X-Ray tracing** for API Gateway
3. **Configure Cognito analytics**
4. **Monitor S3 usage** and costs

---

Remember: AWS Amplify simplifies backend integration but requires careful configuration management!