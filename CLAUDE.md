# CLARITY Pulse iOS Health App - Claude Development Guidelines

## Project Overview
CLARITY Pulse is a HIPAA-compliant iOS health tracking application built with SwiftUI, following MVVM + Clean Architecture principles. The app integrates with HealthKit, AWS Amplify + Cognito, and provides secure biometric authentication for sensitive health data management.

## Core Philosophy

### TEST-DRIVEN DEVELOPMENT IS NON-NEGOTIABLE
Every single line of production code must be written in response to a failing test. No exceptions. This is not a suggestion or a preference - it is the fundamental practice that enables all other principles in this document.

I follow Test-Driven Development (TDD) with a strong emphasis on behavior-driven testing and functional programming principles. All work should be done in small, incremental changes that maintain a working state throughout development.

## Architecture Requirements

### Design Patterns
- **MVVM + Clean Architecture** with Protocol-Oriented Design
- **SwiftUI + iOS 17's @Observable** for reactive UI
- **Environment-based Dependency Injection** for lightweight IoC
- **Repository Pattern** for data abstraction
- **ViewState<T>** pattern for async operation handling

### Layer Structure
```
UI Layer         → SwiftUI Views + ViewModels
Domain Layer     → Use Cases + Domain Models + Repository Protocols  
Data Layer       → Repositories + Services + DTOs
Core Layer       → Networking + Persistence + Utilities
```

## Swift Code Standards

### Access Control (CRITICAL - HIPAA COMPLIANCE)
- **PRIVATE by default**: All implementation details should be `private`
- **INTERNAL**: Module-internal access for shared components
- **PUBLIC**: Only for protocols and essential interfaces
- **NO public classes/structs** unless absolutely necessary for external access

### Security & HIPAA Compliance
- No logging of sensitive health information
- All health data handling must maintain HIPAA compliance
- Secure data transmission only (HTTPS)
- User consent required for all HealthKit access
- Biometric authentication for sensitive operations

### Swift Best Practices
- Use `@Observable` for ViewModels (iOS 17+)
- Environment injection over singletons
- Prefer composition over inheritance
- Keep Views lightweight - logic in ViewModels
- Use `ViewState<T>` for async operations
- Immutable data structures where possible
- Pure functions for business logic

### Naming Conventions
- **ViewModels**: `[Feature]ViewModel` (e.g., `AuthViewModel`)
- **Services**: `[Purpose]Service` (e.g., `HealthKitService`)
- **Repositories**: `[Domain]Repository` (e.g., `RemoteHealthDataRepository`)
- **DTOs**: Descriptive names ending in `DTO`
- **Use Cases**: `[Action][Domain]UseCase` (e.g., `SyncHealthDataUseCase`)

## TDD Process for iOS - THE FUNDAMENTAL PRACTICE

### Red-Green-Refactor Strictly Applied

1. **Red**: Write a failing test for the desired behavior. NO PRODUCTION CODE until you have a failing test.
2. **Green**: Write the MINIMUM Swift code to make the test pass. Resist the urge to write more than needed.
3. **Refactor**: Assess the code for improvement opportunities. If refactoring would add value, clean up the code while keeping tests green.

### Swift TDD Example Workflow

```swift
// Step 1: Red - Start with the simplest behavior
final class HealthDataSyncUseCaseTests: XCTestCase {
    func test_syncHealthData_shouldReturnSuccessForValidData() {
        // Arrange
        let mockRepository = MockHealthDataRepository()
        let useCase = SyncHealthDataUseCase(repository: mockRepository)
        let healthData = HealthData.mock()
        
        // Act & Assert
        let expectation = expectation(description: "Sync completes")
        useCase.execute(data: healthData) { result in
            switch result {
            case .success(let syncResult):
                XCTAssertTrue(syncResult.isSuccessful)
                XCTAssertEqual(syncResult.recordCount, 1)
            case .failure:
                XCTFail("Expected success")
            }
            expectation.fulfill()
        }
        
        waitForExpectations(timeout: 1.0)
    }
}

// Step 2: Green - Minimal implementation
final class SyncHealthDataUseCase {
    private let repository: HealthDataRepositoryProtocol
    
    init(repository: HealthDataRepositoryProtocol) {
        self.repository = repository
    }
    
    func execute(data: HealthData, completion: @escaping (Result<SyncResult, Error>) -> Void) {
        // Minimal implementation to pass the test
        let result = SyncResult(isSuccessful: true, recordCount: 1)
        completion(.success(result))
    }
}

// Step 3: Red - Add test for error case
func test_syncHealthData_shouldReturnFailureForInvalidData() {
    // Arrange
    let mockRepository = MockHealthDataRepository()
    mockRepository.shouldFail = true
    let useCase = SyncHealthDataUseCase(repository: mockRepository)
    let invalidData = HealthData.invalid()
    
    // Act & Assert
    let expectation = expectation(description: "Sync fails")
    useCase.execute(data: invalidData) { result in
        switch result {
        case .success:
            XCTFail("Expected failure")
        case .failure(let error):
            XCTAssertTrue(error is ValidationError)
        }
        expectation.fulfill()
    }
    
    waitForExpectations(timeout: 1.0)
}

// Step 4: Green - NOW we can add the conditional logic
func execute(data: HealthData, completion: @escaping (Result<SyncResult, Error>) -> Void) {
    guard data.isValid else {
        completion(.failure(ValidationError.invalidData))
        return
    }
    
    repository.sync(data: data) { result in
        switch result {
        case .success:
            let syncResult = SyncResult(isSuccessful: true, recordCount: 1)
            completion(.success(syncResult))
        case .failure(let error):
            completion(.failure(error))
        }
    }
}

// Step 5: Refactor - Extract validation and improve structure
private func validateHealthData(_ data: HealthData) throws {
    guard data.isValid else {
        throw ValidationError.invalidData
    }
}

private func createSyncResult(from data: HealthData) -> SyncResult {
    return SyncResult(isSuccessful: true, recordCount: data.recordCount)
}

func execute(data: HealthData, completion: @escaping (Result<SyncResult, Error>) -> Void) {
    do {
        try validateHealthData(data)
    } catch {
        completion(.failure(error))
        return
    }
    
    repository.sync(data: data) { [weak self] result in
        switch result {
        case .success:
            let syncResult = self?.createSyncResult(from: data) ?? SyncResult.empty
            completion(.success(syncResult))
        case .failure(let error):
            completion(.failure(error))
        }
    }
}
```

## Testing Architecture for iOS

### Test Targets
1. **clarity-loop-frontendTests**: Unit tests with comprehensive mocks (✅ Working - 489 tests)
2. **clarity-loop-frontendUITests**: SwiftUI UI automation tests (✅ Working)

### Protocol-Based Mocking Strategy
Create protocols for all major services and use protocol-based mocks:

```swift
// Production protocol
protocol HealthKitServiceProtocol {
    func requestPermissions() async throws
    func fetchStepCount(for date: Date) async throws -> Double
}

// Mock implementation for tests
final class MockHealthKitService: HealthKitServiceProtocol {
    var shouldFailPermissions = false
    var mockStepCount: Double = 10000
    
    func requestPermissions() async throws {
        if shouldFailPermissions {
            throw HealthKitError.permissionDenied
        }
    }
    
    func fetchStepCount(for date: Date) async throws -> Double {
        return mockStepCount
    }
}
```

### Testing Guidelines for HIPAA Compliance
- Mock all external dependencies (AWS Amplify, HealthKit, API)
- Use Environment injection for test doubles
- Test ViewModels in isolation
- Never log actual health data in tests
- Integration tests for critical health data flows
- Test error handling thoroughly (HIPAA requires robust error handling)

### Behavior-Driven Testing in Swift
```swift
// Good - Tests behavior through public API
class AuthViewModelTests: XCTestCase {
    func test_login_withValidCredentials_shouldSucceed() {
        // Arrange
        let mockAuthService = MockAuthService()
        let viewModel = AuthViewModel(authService: mockAuthService)
        
        // Act
        viewModel.login(email: "test@example.com", password: "validPassword")
        
        // Assert
        XCTAssertEqual(viewModel.viewState, .success)
        XCTAssertTrue(mockAuthService.loginCalled)
    }
    
    func test_login_withInvalidCredentials_shouldShowError() {
        // Arrange
        let mockAuthService = MockAuthService()
        mockAuthService.shouldFailLogin = true
        let viewModel = AuthViewModel(authService: mockAuthService)
        
        // Act
        viewModel.login(email: "invalid@example.com", password: "wrongPassword")
        
        // Assert
        switch viewModel.viewState {
        case .error(let message):
            XCTAssertEqual(message, "Invalid credentials")
        default:
            XCTFail("Expected error state")
        }
    }
}

// Avoid - Testing implementation details
func test_login_shouldCallAuthServiceLoginMethod() {
    // This tests implementation, not behavior
}
```

## SwiftUI + MVVM Patterns

### ViewState Pattern for Async Operations
```swift
enum ViewState<T> {
    case idle
    case loading
    case success(T)
    case error(String)
}

@Observable
final class HealthViewModel {
    private(set) var viewState: ViewState<[HealthMetric]> = .idle
    private let healthService: HealthKitServiceProtocol
    
    init(healthService: HealthKitServiceProtocol) {
        self.healthService = healthService
    }
    
    func loadHealthData() {
        viewState = .loading
        
        Task { @MainActor in
            do {
                let metrics = try await healthService.fetchHealthMetrics()
                viewState = .success(metrics)
            } catch {
                viewState = .error(error.localizedDescription)
            }
        }
    }
}
```

### Environment-Based Dependency Injection
```swift
// Environment key
private struct HealthServiceKey: EnvironmentKey {
    static let defaultValue: HealthKitServiceProtocol = HealthKitService()
}

extension EnvironmentValues {
    var healthService: HealthKitServiceProtocol {
        get { self[HealthServiceKey.self] }
        set { self[HealthServiceKey.self] = newValue }
    }
}

// Usage in View
struct HealthView: View {
    @Environment(\.healthService) private var healthService
    @State private var viewModel: HealthViewModel?
    
    var body: some View {
        // View implementation
    }
    
    private func createViewModel() -> HealthViewModel {
        return HealthViewModel(healthService: healthService)
    }
}

// In tests
final class HealthViewTests: XCTestCase {
    func test_healthView_withMockService() {
        let mockService = MockHealthKitService()
        let view = HealthView()
            .environment(\.healthService, mockService)
        
        // Test the view behavior
    }
}
```

## Framework Integration

### AWS Amplify Best Practices
```swift
// Wrapper service for testability
protocol AuthServiceProtocol {
    func signIn(email: String, password: String) async throws -> AuthUser
    func signOut() async throws
}

final class AmplifyAuthService: AuthServiceProtocol {
    func signIn(email: String, password: String) async throws -> AuthUser {
        let result = try await Amplify.Auth.signIn(username: email, password: password)
        // Handle result and return domain model
        return AuthUser(from: result)
    }
    
    func signOut() async throws {
        try await Amplify.Auth.signOut()
    }
}

// Mock for testing
final class MockAuthService: AuthServiceProtocol {
    var shouldFailSignIn = false
    
    func signIn(email: String, password: String) async throws -> AuthUser {
        if shouldFailSignIn {
            throw AuthError.invalidCredentials
        }
        return AuthUser.mock()
    }
    
    func signOut() async throws {
        // Mock implementation
    }
}
```

### HealthKit Integration with Error Handling
```swift
final class HealthKitService: HealthKitServiceProtocol {
    private let healthStore = HKHealthStore()
    
    func requestPermissions() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        let typesToRead: Set<HKObjectType> = [
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .heartRate)!
        ]
        
        try await healthStore.requestAuthorization(toShare: [], read: typesToRead)
    }
    
    func fetchStepCount(for date: Date) async throws -> Double {
        let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount)!
        let predicate = HKQuery.predicateForSamples(withStart: date, end: date, options: .strictStartDate)
        
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                let stepCount = result?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: stepCount)
            }
            
            healthStore.execute(query)
        }
    }
}
```

## Refactoring Guidelines for Swift

### When to Refactor
Always assess after green: Once tests pass, evaluate if refactoring would add value
- Extract common SwiftUI view components
- Create reusable domain models
- Simplify complex async/await chains
- Improve naming for clarity

### Swift-Specific Refactoring Patterns
```swift
// Before: Complex async chain
func syncAllHealthData() async throws {
    let steps = try await healthKit.fetchStepCount(for: Date())
    let heartRate = try await healthKit.fetchHeartRate(for: Date())
    let sleep = try await healthKit.fetchSleep(for: Date())
    
    let healthData = HealthData(steps: steps, heartRate: heartRate, sleep: sleep)
    try await repository.sync(healthData)
}

// After: Extracted and composed
private func fetchAllMetrics(for date: Date) async throws -> HealthMetrics {
    async let steps = healthKit.fetchStepCount(for: date)
    async let heartRate = healthKit.fetchHeartRate(for: date)
    async let sleep = healthKit.fetchSleep(for: date)
    
    return try await HealthMetrics(
        steps: steps,
        heartRate: heartRate,
        sleep: sleep
    )
}

func syncAllHealthData() async throws {
    let metrics = try await fetchAllMetrics(for: Date())
    let healthData = HealthData(from: metrics)
    try await repository.sync(healthData)
}
```

## Build & Test Commands

```bash
# Clean build
xcodebuild clean -project clarity-loop-frontend.xcodeproj -scheme clarity-loop-frontend

# Debug build for simulator
xcodebuild -project clarity-loop-frontend.xcodeproj -scheme clarity-loop-frontend -destination 'platform=iOS Simulator,name=iPhone 16' -configuration Debug build

# Run unit tests
xcodebuild test -project clarity-loop-frontend.xcodeproj -scheme clarity-loop-frontendTests -destination 'platform=iOS Simulator,name=iPhone 16'

# Run UI tests
xcodebuild test -project clarity-loop-frontend.xcodeproj -scheme clarity-loop-frontendUITests -destination 'platform=iOS Simulator,name=iPhone 16'
```

## Common Swift Patterns to Follow

### Error Handling
```swift
// Good - Domain-specific errors
enum HealthKitError: LocalizedError {
    case notAvailable
    case permissionDenied
    case dataNotFound
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .permissionDenied:
            return "Permission to access health data was denied"
        case .dataNotFound:
            return "Requested health data was not found"
        }
    }
}

// Good - Result type for async operations
func fetchHealthData() async -> Result<HealthData, HealthKitError> {
    do {
        let data = try await healthKitService.fetchData()
        return .success(data)
    } catch {
        return .failure(.dataNotFound)
    }
}
```

### Memory Management
```swift
// Good - Weak references in closures
class DataSyncManager {
    func startSync() {
        Timer.scheduledTimer(withTimeInterval: 60) { [weak self] _ in
            self?.performSync()
        }
    }
}

// Good - Unowned for parent-child relationships
class HealthMetric {
    unowned let category: HealthCategory
    
    init(category: HealthCategory) {
        self.category = category
    }
}
```

## Working with Claude - iOS Specific

### Expectations
When working with CLARITY Pulse code:

- **ALWAYS FOLLOW TDD** - No Swift production code without a failing test
- Think deeply about HIPAA compliance implications
- Understand the health data sensitivity context
- Ask clarifying questions about medical/health requirements
- Consider iOS-specific constraints (background processing, permissions, etc.)

### iOS-Specific Considerations
- HealthKit permissions and privacy
- Background app refresh limitations
- Biometric authentication flows
- AWS Amplify iOS SDK patterns
- SwiftData persistence patterns
- Memory management for health data
- Accessibility for health applications

## Current Status
- ✅ Build: Successful
- ✅ Architecture: MVVM + Clean Architecture implemented
- ✅ AWS Integration: Configured and working
- ✅ TDD Ready: All patterns in place for test-driven development

## Security Checklist for Every Change
- [ ] No sensitive health data in logs
- [ ] Proper error handling without exposing internals
- [ ] Biometric authentication for sensitive operations
- [ ] HTTPS-only data transmission
- [ ] Proper HealthKit permission handling
- [ ] Memory cleared after use for sensitive data
- [ ] Tests cover security failure scenarios

Remember: This is a production health application handling sensitive user data. Always prioritize security, privacy, and HIPAA compliance in all development decisions. Every line of code must be driven by a test that describes the expected behavior.

---

## Current Execution Status (2025-06-24)

**Active Plan**: CLARITY_CANONICAL_EXECUTION_PLAN.md
**Current Task**: Fixing all placeholder tests (170+ files with XCTSkip)
**Progress**: ~20 tests fixed out of 489 fake tests

### Key Documents Created
1. **CLARITY_CANONICAL_EXECUTION_PLAN.md** - Master execution plan
2. **EXECUTION_LOG.md** - Detailed progress tracking
3. **TEST_FIXING_PATTERNS.md** - How to fix tests guide
4. **SHOCKING_TRUTHS.md** - Why we're doing this
5. **BACKEND_API_REALITY.md** - API contract mismatches

### If Continuing After Disconnect
1. Read CLARITY_CANONICAL_EXECUTION_PLAN.md first
2. Check EXECUTION_LOG.md for last action
3. Run: `grep -r "XCTSkip" clarity-loop-frontendTests/ | wc -l` to see remaining work
4. Continue fixing tests using TEST_FIXING_PATTERNS.md

### Current Architecture Issues Being Fixed
- All repositories are `final` classes (creating protocol workarounds)
- No dependency injection (building mock infrastructure)
- Frontend doesn't match backend API (documenting mismatches)
- 489 tests are fake (replacing with real implementations)

---

*Last updated: 2025-06-24