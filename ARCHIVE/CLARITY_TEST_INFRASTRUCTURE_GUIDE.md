# CLARITY Test Infrastructure Guide

## Overview

This guide documents the comprehensive test infrastructure for CLARITY Pulse V2, following TDD/BDD principles. Every feature must have failing tests first, then implementation, then refactoring.

## Test Architecture

### Module Structure
```
clarity-loop-frontend-v2Tests/
├── Infrastructure/           # Base test classes and utilities
│   ├── BaseUnitTestCase.swift
│   ├── AsyncTestCase.swift
│   ├── BaseIntegrationTestCase.swift
│   └── MockGenerator.swift
├── Domain/                   # Domain layer tests
│   ├── UseCases/
│   └── Entities/
├── Data/                     # Data layer tests
│   └── Repositories/
├── Integration/              # Integration tests
│   ├── LoginFlowIntegrationTests.swift
│   └── HealthMetricFlowIntegrationTests.swift
└── UI/                       # UI and ViewModel tests
    ├── ViewModels/
    └── Helpers/
```

## Base Test Classes

### BaseUnitTestCase
Foundation for all unit tests with common setup/teardown and utilities.

```swift
open class BaseUnitTestCase: XCTestCase {
    // Automatic cleanup of subscriptions
    var cancellables = Set<AnyCancellable>()
    
    // Common test data
    func makeTestUser() -> User
    func makeTestHealthMetric() -> HealthMetric
    
    // Assertion helpers
    func assertThrowsError<T>(_ expression: @autoclosure () throws -> T)
}
```

**Usage**:
```swift
class LoginUseCaseTests: BaseUnitTestCase {
    func test_login_withValidCredentials_shouldReturnUser() async throws {
        // Given
        let user = makeTestUser()
        
        // When
        let result = try await sut.execute(email: "test@example.com", password: "password")
        
        // Then
        XCTAssertEqual(result.id, user.id)
    }
}
```

### AsyncTestCase
Specialized for testing async/await code with Swift concurrency.

```swift
open class AsyncTestCase: BaseUnitTestCase {
    // Async assertions with timeout
    func assertAsync<T>(
        timeout: TimeInterval = 10,
        _ operation: () async throws -> T
    ) async
    
    // Wait for @Observable property changes
    func waitForObservableChange<Root, Value>(
        on object: Root,
        keyPath: KeyPath<Root, Value>,
        expectedValue: Value
    ) async
}
```

**Usage**:
```swift
class DashboardViewModelTests: AsyncTestCase {
    func test_loadData_updatesViewState() async {
        // Given
        let viewModel = DashboardViewModel()
        
        // When & Then
        await assertAsync {
            await viewModel.loadData()
            XCTAssertEqual(viewModel.viewState, .success)
        }
    }
}
```

### BaseIntegrationTestCase
For testing multiple components working together with real implementations.

```swift
open class BaseIntegrationTestCase: BaseUnitTestCase {
    // Test-specific DI container
    private(set) var testContainer: DIContainer!
    
    // Mock services
    private(set) var testNetworkClient: MockNetworkClient!
    private(set) var testPersistence: MockPersistenceService!
    
    // Helper methods
    func givenNetworkResponse<T>(for path: String, response: T)
    func verifyNetworkRequest(to path: String, times: Int = 1)
}
```

**Usage**:
```swift
class LoginFlowIntegrationTests: BaseIntegrationTestCase {
    func test_loginFlow_fromAPIToPersistence() async throws {
        // Given
        await givenNetworkResponse(
            for: "/api/v1/auth/login",
            response: LoginResponseDTO(...)
        )
        
        // When
        let loginUseCase = testContainer.require(LoginUseCaseProtocol.self)
        let user = try await loginUseCase.execute(...)
        
        // Then
        await verifyNetworkRequest(to: "/api/v1/auth/login")
        let savedUser = try await testPersistence.fetch(user.id)
        XCTAssertNotNil(savedUser)
    }
}
```

## Mock Infrastructure

### MockGenerator
Utility for creating consistent test data across all tests.

```swift
final class MockGenerator {
    static func user(
        id: UUID = UUID(),
        email: String = "test@example.com"
    ) -> User
    
    static func healthMetric(
        type: HealthMetricType = .heartRate,
        value: Double = 72
    ) -> HealthMetric
    
    static func authToken() -> AuthToken
}
```

### Mock Services
All external dependencies have mock implementations:

- **MockNetworkClient**: Simulates API responses
- **MockPersistenceService**: In-memory storage
- **MockAuthService**: Authentication simulation
- **MockHealthKitService**: HealthKit data simulation

## BDD Test Patterns

### Naming Convention
```swift
func test_whenCondition_shouldExpectedBehavior()
func test_givenContext_whenAction_thenResult()
```

### BDD Structure
```swift
func test_whenUserLogsIn_withValidCredentials_shouldShowDashboard() async throws {
    // Given - Setup initial state
    let credentials = makeValidCredentials()
    let mockUser = makeTestUser()
    await givenAuthServiceReturns(mockUser)
    
    // When - Perform action
    await viewModel.login(with: credentials)
    
    // Then - Verify outcome
    XCTAssertEqual(viewModel.navigationDestination, .dashboard)
    XCTAssertEqual(viewModel.currentUser, mockUser)
}
```

## TDD Workflow

### 1. Red Phase - Write Failing Test
```swift
func test_healthMetric_withNegativeValue_shouldThrowValidationError() {
    // This test will fail because validation isn't implemented yet
    XCTAssertThrowsError(
        try HealthMetric(type: .heartRate, value: -10)
    ) { error in
        XCTAssertEqual(error as? ValidationError, .invalidValue)
    }
}
```

### 2. Green Phase - Minimal Implementation
```swift
struct HealthMetric {
    init(type: HealthMetricType, value: Double) throws {
        guard value >= 0 else {
            throw ValidationError.invalidValue
        }
        // Minimal implementation to pass test
    }
}
```

### 3. Refactor Phase - Improve Code
```swift
struct HealthMetric {
    private let validRanges: [HealthMetricType: ClosedRange<Double>] = [
        .heartRate: 30...250,
        .bloodPressureSystolic: 70...200
    ]
    
    init(type: HealthMetricType, value: Double) throws {
        guard let range = validRanges[type],
              range.contains(value) else {
            throw ValidationError.invalidValue(
                "Value \(value) outside valid range for \(type)"
            )
        }
        // Refined implementation
    }
}
```

## Test Configuration

### Coverage Requirements (.test-config.json)
```json
{
  "coverage": {
    "minimum": 80,
    "targets": {
      "ClarityCore": 85,
      "ClarityDomain": 90,
      "ClarityData": 80,
      "ClarityUI": 75
    }
  }
}
```

### Running Tests

#### Quick Commands
```bash
# Fast unit tests (TDD cycle)
./Scripts/test-fast.sh

# All unit tests with coverage
./Scripts/test-unit.sh

# Integration tests
./Scripts/test-integration.sh

# Full test suite
./Scripts/test-all.sh

# CI mode with strict coverage
./Scripts/test-ci.sh
```

#### Swift Commands
```bash
# Run specific test
swift test --filter LoginViewModelTests/test_login_success

# Run with coverage
swift test --enable-code-coverage

# Parallel execution
swift test --parallel
```

## Performance Considerations

### Test Speed Guidelines
- Unit tests: < 0.1s per test
- Integration tests: < 1s per test
- UI tests: < 5s per test

### Optimization Strategies
1. **Build Once**: All scripts use `swift build` then `swift test --skip-build`
2. **Parallel Execution**: Tests run in parallel by default
3. **Focused Testing**: Use filters to run only relevant tests during TDD
4. **Mock Heavy Operations**: Never hit real network/disk in unit tests

## Swift 6 Concurrency

### Proper Actor Usage
```swift
// ✅ Correct - Use @MainActor for UI components
@MainActor
@Observable
final class DashboardViewModel {
    private(set) var metrics: [HealthMetric] = []
}

// ❌ Incorrect - Don't use @unchecked Sendable
final class BadViewModel: @unchecked Sendable { }
```

### Async Test Patterns
```swift
// Test @MainActor methods
func test_viewModel_updatesOnMainActor() async {
    let viewModel = DashboardViewModel()
    
    await MainActor.run {
        viewModel.updateMetrics([])
        XCTAssertTrue(viewModel.metrics.isEmpty)
    }
}
```

## Integration Test Patterns

### Data Flow Verification
```swift
func test_healthMetricFlow_fromAPIToUI() async throws {
    // API → Repository → Use Case → ViewModel → UI State
    
    // Given - API will return metrics
    let metrics = [MockGenerator.healthMetric()]
    await givenNetworkResponse(for: "/api/v1/health-metrics", response: metrics)
    
    // When - User refreshes dashboard
    let viewModel = testContainer.require(DashboardViewModel.self)
    await viewModel.refresh()
    
    // Then - Verify entire flow
    await verifyNetworkRequest(to: "/api/v1/health-metrics")
    XCTAssertEqual(viewModel.metrics.count, 1)
    XCTAssertEqual(viewModel.viewState, .success)
}
```

## UI Testing Helpers

### SwiftUI Preview Testing
```swift
struct PreviewHelpers {
    static var previewContainer: DIContainer {
        let container = DIContainer()
        // Configure with mock services
        return container
    }
    
    static func makeViewModel<T>(_ type: T.Type) -> T {
        previewContainer.require(type)
    }
}

// Usage in previews
#Preview {
    DashboardView()
        .environmentObject(PreviewHelpers.makeViewModel(DashboardViewModel.self))
}
```

## Troubleshooting

### Common Issues

1. **Test Timeouts**
   - Solution: Scripts now kill zombie processes and use build caching
   - Use `test-fast.sh` for rapid TDD cycles

2. **Flaky Async Tests**
   - Use `AsyncTestCase` with proper timeouts
   - Always await async operations
   - Use `@MainActor` for UI state

3. **Module Import Errors**
   - Use `@testable import` for internal access
   - Remember module names: `ClarityCore`, `ClarityDomain`, etc.

## Best Practices

### DO:
- ✅ Write test first (Red → Green → Refactor)
- ✅ Test behavior, not implementation
- ✅ Use descriptive test names
- ✅ Keep tests fast and isolated
- ✅ Mock external dependencies
- ✅ Test edge cases and error paths

### DON'T:
- ❌ Test private methods directly
- ❌ Share state between tests
- ❌ Use real network/database in unit tests
- ❌ Write tests after implementation
- ❌ Skip the refactor phase

## Continuous Integration

### GitHub Actions Integration
```yaml
- name: Run Tests
  run: |
    ./Scripts/test-ci.sh
    
- name: Upload Coverage
  uses: codecov/codecov-action@v3
  with:
    file: .build/test-results/coverage.lcov
```

### Pre-commit Hook
```bash
#!/bin/bash
# .git/hooks/pre-commit
./Scripts/test-fast.sh || exit 1
```

## Next Steps

1. Complete domain model tests (Task 6)
2. Implement repository protocol tests (Task 7)
3. Create DTO model tests (Task 8)
4. Begin authentication slice with TDD (Tasks 31-55)

Remember: **No production code without a failing test first!**