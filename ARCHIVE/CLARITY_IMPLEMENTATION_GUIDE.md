# CLARITY Frontend Implementation Guide

## Overview

This guide provides concrete, step-by-step instructions for implementing the CLARITY frontend rebuild using Test-Driven Development (TDD). Every feature must be built following the Red-Green-Refactor cycle.

## TDD Workflow for Every Feature

### The Sacred Cycle
```
1. RED - Write a failing test
2. GREEN - Write minimal code to pass
3. REFACTOR - Improve code quality
```

**NEVER write production code without a failing test first!**

## Phase 1: Preparation & Cleanup

### Step 1.1: Backup Current State
```bash
# Create backup branch
git checkout -b v1-backup
git add .
git commit -m "Backup: V1 frontend before rebuild"
git push origin v1-backup

# Return to main branch
git checkout main
```

### Step 1.2: Clean Implementation Files
For each Swift file in the implementation folders:

1. **KEEP the file**
2. **DELETE all contents**
3. **ADD minimal placeholder**

Example transformation:
```swift
// BEFORE: AuthService.swift (500 lines of broken code)
// AFTER: AuthService.swift
import Foundation

// TODO: Implement with TDD
```

### Step 1.3: Files to Completely Remove
```bash
# Remove disabled files
rm clarity-loop-frontend-v2/Core/Services/CognitoAuthService.swift.disabled
rm clarity-loop-frontend-v2/Core/Services/CognitoConfiguration.swift.disabled
rm clarity-loop-frontend-v2Tests/Core/Services/WebSocketManagerTests.swift.disabled
```

## Phase 2: Core Infrastructure

### Step 2.1: Create Base Protocols

#### NetworkingProtocol.swift
```swift
// TEST FIRST!
// NetworkingProtocolTests.swift
import XCTest
@testable import clarity_loop_frontend

final class NetworkingProtocolTests: XCTestCase {
    func test_networkingProtocol_defines_request_method() {
        // This test verifies protocol exists and has correct signature
        // Compile-time test
    }
}

// THEN IMPLEMENT
// NetworkingProtocol.swift
protocol NetworkingProtocol {
    func request<T: Decodable>(_ endpoint: Endpoint) async throws -> T
    func upload(_ endpoint: Endpoint, data: Data) async throws -> UploadResponse
}
```

### Step 2.2: Repository Protocols

For each repository, create protocol FIRST:

#### HealthDataRepositoryProtocol.swift
```swift
// TEST FIRST!
final class HealthDataRepositoryProtocolTests: XCTestCase {
    func test_protocol_defines_upload_method() {
        // Verify protocol contract at compile time
    }
}

// THEN IMPLEMENT
protocol HealthDataRepositoryProtocol {
    func uploadHealthData(_ data: HealthDataDTO) async throws -> ProcessingResponse
    func fetchHealthData(limit: Int, offset: Int) async throws -> PaginatedHealthData
    func getProcessingStatus(id: String) async throws -> ProcessingStatus
}
```

### Step 2.3: Dependency Injection Container

```swift
// TEST FIRST!
final class DependencyContainerTests: XCTestCase {
    func test_container_provides_networking() {
        let container = DependencyContainer()
        let networking = container.networking
        XCTAssertNotNil(networking)
    }
}

// THEN IMPLEMENT
final class DependencyContainer {
    lazy var networking: NetworkingProtocol = {
        APIClient(baseURL: AppConfig.apiBaseURL)
    }()
    
    // Add more dependencies as needed
}
```

## Phase 3: Backend Integration

### Step 3.1: Auth Endpoints (7 endpoints)

#### Pattern for Each Endpoint:

1. **Write DTO Tests**
```swift
final class AuthDTOTests: XCTestCase {
    func test_loginRequest_encodesCorrectly() throws {
        let request = LoginRequestDTO(
            email: "test@example.com",
            password: "password123"
        )
        
        let encoded = try JSONEncoder().encode(request)
        let json = try JSONSerialization.jsonObject(with: encoded)
        let dict = json as? [String: Any]
        
        XCTAssertEqual(dict?["email"] as? String, "test@example.com")
        XCTAssertEqual(dict?["password"] as? String, "password123")
    }
}
```

2. **Implement DTOs**
```swift
struct LoginRequestDTO: Codable {
    let email: String
    let password: String
}

struct LoginResponseDTO: Codable {
    let accessToken: String
    let refreshToken: String
    let expiresIn: Int
    let userId: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
        case userId = "user_id"
    }
}
```

3. **Write Repository Tests**
```swift
final class AuthRepositoryTests: XCTestCase {
    var repository: AuthRepository!
    var mockNetworking: MockNetworking!
    
    override func setUp() {
        mockNetworking = MockNetworking()
        repository = AuthRepository(networking: mockNetworking)
    }
    
    func test_login_success() async throws {
        // Arrange
        let expectedResponse = LoginResponseDTO(
            accessToken: "token",
            refreshToken: "refresh",
            expiresIn: 3600,
            userId: "123"
        )
        mockNetworking.mockResponse = expectedResponse
        
        // Act
        let result = try await repository.login(
            email: "test@example.com",
            password: "password"
        )
        
        // Assert
        XCTAssertEqual(result.accessToken, "token")
        XCTAssertEqual(mockNetworking.lastEndpoint?.path, "/api/v1/auth/login")
    }
}
```

4. **Implement Repository**
```swift
final class AuthRepository: AuthRepositoryProtocol {
    private let networking: NetworkingProtocol
    
    init(networking: NetworkingProtocol) {
        self.networking = networking
    }
    
    func login(email: String, password: String) async throws -> LoginResponseDTO {
        let request = LoginRequestDTO(email: email, password: password)
        let endpoint = AuthEndpoint.login(request)
        return try await networking.request(endpoint)
    }
}
```

### Step 3.2: Health Data Endpoints (5 endpoints)

Follow same pattern for:
- POST /api/v1/health-data
- GET /api/v1/health-data/
- GET /api/v1/health-data/{processing_id}
- DELETE /api/v1/health-data/{processing_id}
- GET /api/v1/health-data/processing/{id}/status

### Step 3.3: Continue for All 44 Endpoints

## Phase 4: UI Implementation

### Step 4.1: ViewModels with TDD

```swift
// TEST FIRST!
@MainActor
final class LoginViewModelTests: XCTestCase {
    func test_login_updatesLoadingState() async {
        let mockAuth = MockAuthRepository()
        let viewModel = LoginViewModel(authRepository: mockAuth)
        
        XCTAssertFalse(viewModel.isLoading)
        
        let task = Task { await viewModel.login() }
        
        // Allow state to update
        try await Task.sleep(nanoseconds: 10_000_000)
        XCTAssertTrue(viewModel.isLoading)
        
        await task.value
        XCTAssertFalse(viewModel.isLoading)
    }
}

// THEN IMPLEMENT
@Observable
final class LoginViewModel {
    private let authRepository: AuthRepositoryProtocol
    
    var email = ""
    var password = ""
    var isLoading = false
    var errorMessage: String?
    
    init(authRepository: AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }
    
    func login() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            _ = try await authRepository.login(
                email: email,
                password: password
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

### Step 4.2: SwiftUI Views

Views should be thin - all logic in ViewModels:

```swift
struct LoginView: View {
    @State private var viewModel: LoginViewModel
    
    init(viewModel: LoginViewModel) {
        self.viewModel = viewModel
    }
    
    var body: some View {
        Form {
            TextField("Email", text: $viewModel.email)
            SecureField("Password", text: $viewModel.password)
            
            if viewModel.isLoading {
                ProgressView()
            } else {
                Button("Login") {
                    Task { await viewModel.login() }
                }
            }
            
            if let error = viewModel.errorMessage {
                Text(error).foregroundColor(.red)
            }
        }
    }
}
```

## Testing Patterns

### Mock Creation Pattern
```swift
final class MockHealthRepository: HealthDataRepositoryProtocol {
    var uploadCalled = false
    var uploadData: HealthDataDTO?
    var mockResponse: ProcessingResponse?
    var shouldThrow = false
    
    func uploadHealthData(_ data: HealthDataDTO) async throws -> ProcessingResponse {
        uploadCalled = true
        uploadData = data
        
        if shouldThrow {
            throw APIError.networkError
        }
        
        return mockResponse ?? ProcessingResponse(
            processingId: "mock-id",
            status: "processing",
            metricsCount: 1,
            estimatedCompletion: Date()
        )
    }
}
```

### Integration Test Pattern
```swift
final class AuthIntegrationTests: XCTestCase {
    func test_fullAuthFlow() async throws {
        // Use real networking with test server
        let container = DependencyContainer.testContainer()
        let authRepo = container.authRepository
        
        // Register
        let user = try await authRepo.register(
            email: "test@example.com",
            password: "password123"
        )
        
        // Login
        let session = try await authRepo.login(
            email: "test@example.com",
            password: "password123"
        )
        
        XCTAssertNotNil(session.accessToken)
    }
}
```

## Checklist for Each Feature

- [ ] Write failing test for DTOs
- [ ] Implement DTOs
- [ ] Write failing test for repository method
- [ ] Implement repository method
- [ ] Write failing test for use case (if needed)
- [ ] Implement use case
- [ ] Write failing test for ViewModel
- [ ] Implement ViewModel
- [ ] Create SwiftUI view
- [ ] Write integration test
- [ ] Refactor if needed

## Common Pitfalls to Avoid

1. **Writing code without tests** - NEVER DO THIS
2. **Testing implementation details** - Test behavior, not internals
3. **Skipping refactor step** - Clean code matters
4. **Not mocking external dependencies** - Always mock
5. **Forgetting error cases** - Test success AND failure

## Next Steps

1. Complete Phase 1 cleanup
2. Start Phase 2 with base protocols
3. Implement one endpoint at a time
4. Build UI only after backend integration works

## Related Documentation

- **CLARITY_SWIFT6_SWIFTDATA_SENDABILITY_GUIDE.md** - Swift 6 concurrency solutions for SwiftData
- **CLARITY_SWIFT_BEST_PRACTICES.md** - Common AI agent pitfalls and Swift patterns
- **CLARITY_VERTICAL_SLICE_TASK_SUMMARY.md** - 200 tasks organized by features
- **CLARITY_ENDPOINT_MAPPING.md** - All 44 backend endpoints with DTOs

---

*Remember: If you're not writing a test first, you're doing it wrong!*