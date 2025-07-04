# CLARITY Comprehensive Testing Strategy

## Overview

This document defines the complete testing strategy for CLARITY Pulse, ensuring 100% confidence in code quality through systematic testing at every level.

## Testing Philosophy

1. **Test-First Development** - Write tests before implementation
2. **Behavior Over Implementation** - Test what it does, not how
3. **Fast Feedback** - Tests must run quickly
4. **Isolated Tests** - No test depends on another
5. **Readable Tests** - Tests document the system

## Testing Pyramid

```
         /\
        /  \  UI Tests (10%)
       /----\
      /      \  Integration Tests (20%)
     /--------\
    /          \  Unit Tests (70%)
   /____________\
```

## Complete Testing Architecture

### 1. Unit Tests (70% of tests)

#### Model Tests

```swift
// HealthMetricTests.swift
import XCTest
@testable import ClarityPulse

final class HealthMetricTests: XCTestCase {
    func test_init_setsAllProperties() {
        // Arrange
        let type = HealthMetricType.heartRate
        let value = 72.0
        let unit = "bpm"
        let timestamp = Date()
        let source = "Apple Watch"
        
        // Act
        let metric = HealthMetric(
            type: type,
            value: value,
            unit: unit,
            timestamp: timestamp,
            source: source
        )
        
        // Assert
        XCTAssertNotNil(metric.id)
        XCTAssertEqual(metric.type, type)
        XCTAssertEqual(metric.value, value)
        XCTAssertEqual(metric.unit, unit)
        XCTAssertEqual(metric.timestamp, timestamp)
        XCTAssertEqual(metric.source, source)
        XCTAssertFalse(metric.isSynced)
        XCTAssertNil(metric.syncedAt)
    }
    
    func test_validRange_returnsCorrectRangeForType() {
        // Arrange
        let testCases: [(HealthMetricType, min: Double, max: Double)] = [
            (.heartRate, 30, 220),
            (.steps, 0, 100000),
            (.bloodOxygen, 70, 100)
        ]
        
        // Act & Assert
        for (type, expectedMin, expectedMax) in testCases {
            let range = type.validRange
            XCTAssertEqual(range.min, expectedMin, "Min for \(type)")
            XCTAssertEqual(range.max, expectedMax, "Max for \(type)")
        }
    }
}
```

#### ViewModel Tests

```swift
// DashboardViewModelTests.swift
@MainActor
final class DashboardViewModelTests: XCTestCase {
    private var viewModel: DashboardViewModel!
    private var mockRepository: MockHealthRepository!
    private var mockContext: ModelContext!
    
    override func setUp() async throws {
        try await super.setUp()
        mockRepository = MockHealthRepository()
        mockContext = try ModelContext(for: [HealthMetric.self], isStoredInMemoryOnly: true)
        viewModel = DashboardViewModel(
            healthRepository: mockRepository,
            modelContext: mockContext
        )
    }
    
    func test_loadDashboard_success_updatesViewState() async {
        // Arrange
        let expectedMetrics = HealthMetric.mockArray(count: 5)
        mockRepository.mockMetrics = expectedMetrics
        
        // Act
        await viewModel.loadDashboard()
        
        // Assert
        switch viewModel.viewState {
        case .success(let data):
            XCTAssertEqual(data.metrics.count, 5)
            XCTAssertNotNil(data.summary)
        default:
            XCTFail("Expected success state")
        }
    }
    
    func test_loadDashboard_failure_showsError() async {
        // Arrange
        mockRepository.shouldFail = true
        mockRepository.mockError = NetworkError.noInternet
        
        // Act
        await viewModel.loadDashboard()
        
        // Assert
        switch viewModel.viewState {
        case .error(let message):
            XCTAssertEqual(message, "No internet connection")
        default:
            XCTFail("Expected error state")
        }
    }
    
    func test_refresh_triggersNewLoad() async {
        // Arrange
        let initialTrigger = viewModel.refreshTrigger
        
        // Act
        await viewModel.refresh()
        
        // Assert
        XCTAssertNotEqual(viewModel.refreshTrigger, initialTrigger)
        XCTAssertTrue(mockRepository.fetchCalled)
    }
}
```

#### Service Tests

```swift
// NetworkClientTests.swift
final class NetworkClientTests: XCTestCase {
    private var client: NetworkClient!
    private var mockSession: MockURLSession!
    
    override func setUp() {
        super.setUp()
        mockSession = MockURLSession()
        client = NetworkClient(session: mockSession)
    }
    
    func test_request_successfulResponse_decodesData() async throws {
        // Arrange
        let expectedUser = User(id: "123", email: "test@example.com")
        let responseData = try JSONEncoder().encode(expectedUser)
        
        mockSession.mockData = responseData
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.clarity.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )
        
        // Act
        let endpoint = UserEndpoint.profile
        let user: User = try await client.request(endpoint)
        
        // Assert
        XCTAssertEqual(user.id, expectedUser.id)
        XCTAssertEqual(user.email, expectedUser.email)
    }
    
    func test_request_401Response_throwsUnauthorized() async {
        // Arrange
        mockSession.mockResponse = HTTPURLResponse(
            url: URL(string: "https://api.clarity.com")!,
            statusCode: 401,
            httpVersion: nil,
            headerFields: nil
        )
        
        // Act & Assert
        do {
            let _: User = try await client.request(UserEndpoint.profile)
            XCTFail("Expected unauthorized error")
        } catch let error as NetworkError {
            XCTAssertEqual(error, .unauthorized)
        }
    }
}
```

### 2. Integration Tests (20% of tests)

#### Repository Integration Tests

```swift
// HealthRepositoryIntegrationTests.swift
final class HealthRepositoryIntegrationTests: XCTestCase {
    private var repository: HealthRepository!
    private var mockServer: MockServer!
    
    override func setUp() async throws {
        try await super.setUp()
        mockServer = try MockServer(port: 8080)
        try await mockServer.start()
        
        let client = NetworkClient(baseURL: URL(string: "http://localhost:8080")!)
        repository = HealthRepository(networkClient: client)
    }
    
    override func tearDown() async throws {
        try await mockServer.stop()
        try await super.tearDown()
    }
    
    func test_uploadHealthData_integrationFlow() async throws {
        // Arrange
        let metrics = HealthMetric.mockArray(count: 10)
        
        mockServer.stub(
            path: "/api/v1/health-data",
            method: .post,
            response: MockResponse(
                status: 200,
                json: [
                    "processing_id": "test-123",
                    "status": "processing",
                    "metrics_count": 10
                ]
            )
        )
        
        // Act
        let response = try await repository.uploadHealthData(metrics)
        
        // Assert
        XCTAssertEqual(response.processingId, "test-123")
        XCTAssertEqual(response.metricsCount, 10)
        
        // Verify request
        let request = try XCTUnwrap(mockServer.lastRequest)
        XCTAssertEqual(request.path, "/api/v1/health-data")
        XCTAssertEqual(request.method, "POST")
    }
}
```

#### SwiftData Integration Tests

```swift
// SwiftDataIntegrationTests.swift
final class SwiftDataIntegrationTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    
    override func setUp() async throws {
        try await super.setUp()
        
        let schema = Schema([
            User.self,
            HealthMetric.self,
            SyncQueueItem.self
        ])
        
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        
        container = try ModelContainer(
            for: schema,
            configurations: [configuration]
        )
        
        context = container.mainContext
    }
    
    func test_userHealthMetricRelationship() throws {
        // Arrange
        let user = User(
            id: "test-user",
            email: "test@example.com",
            firstName: "Test",
            lastName: "User"
        )
        
        let metric = HealthMetric(
            type: .heartRate,
            value: 75,
            unit: "bpm",
            timestamp: Date(),
            source: "Test"
        )
        
        // Act
        context.insert(user)
        context.insert(metric)
        metric.user = user
        
        try context.save()
        
        // Fetch and verify
        let fetchedUsers = try context.fetch(FetchDescriptor<User>())
        let fetchedUser = try XCTUnwrap(fetchedUsers.first)
        
        // Assert
        XCTAssertEqual(fetchedUser.healthMetrics?.count, 1)
        XCTAssertEqual(fetchedUser.healthMetrics?.first?.value, 75)
    }
    
    func test_cascadeDelete() throws {
        // Arrange
        let user = User(id: "test", email: "test@example.com", firstName: "Test", lastName: "User")
        let metrics = (0..<5).map { _ in
            HealthMetric(type: .steps, value: 1000, unit: "steps", timestamp: Date(), source: "Test")
        }
        
        context.insert(user)
        metrics.forEach { 
            context.insert($0)
            $0.user = user
        }
        
        try context.save()
        
        // Act - Delete user
        context.delete(user)
        try context.save()
        
        // Assert - Metrics should be deleted
        let remainingMetrics = try context.fetch(FetchDescriptor<HealthMetric>())
        XCTAssertEqual(remainingMetrics.count, 0)
    }
}
```

### 3. UI Tests (10% of tests)

#### Authentication Flow UI Tests

```swift
// AuthenticationUITests.swift
final class AuthenticationUITests: XCTestCase {
    private var app: XCUIApplication!
    
    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        
        app = XCUIApplication()
        app.launchArguments = ["--uitesting"]
        app.launchEnvironment = ["MOCK_API": "true"]
    }
    
    func test_loginFlow_validCredentials_navigatesToDashboard() {
        // Arrange
        app.launch()
        
        // Act
        let emailField = app.textFields["Email"]
        emailField.tap()
        emailField.typeText("test@example.com")
        
        let passwordField = app.secureTextFields["Password"]
        passwordField.tap()
        passwordField.typeText("password123")
        
        app.buttons["Login"].tap()
        
        // Assert
        let dashboardTitle = app.navigationBars["Dashboard"].waitForExistence(timeout: 5)
        XCTAssertTrue(dashboardTitle)
    }
    
    func test_loginFlow_invalidCredentials_showsError() {
        // Arrange
        app.launch()
        
        // Act
        app.textFields["Email"].tap()
        app.typeText("invalid@example.com")
        
        app.secureTextFields["Password"].tap()
        app.typeText("wrongpassword")
        
        app.buttons["Login"].tap()
        
        // Assert
        let alert = app.alerts["Error"].waitForExistence(timeout: 2)
        XCTAssertTrue(alert)
        XCTAssertTrue(app.alerts.staticTexts["Invalid email or password"].exists)
    }
}
```

#### Health Data UI Tests

```swift
// HealthDataUITests.swift
final class HealthDataUITests: XCTestCase {
    func test_addHealthMetric_manual_appearsInList() {
        // Arrange
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--authenticated"]
        app.launch()
        
        // Navigate to health tab
        app.tabBars.buttons["Health"].tap()
        
        // Act - Add metric
        app.navigationBars["Health Data"].buttons["Add"].tap()
        
        let picker = app.pickers["metric-type-picker"]
        picker.pickerWheels.element.adjust(toPickerWheelValue: "Heart Rate")
        
        let valueField = app.textFields["metric-value"]
        valueField.tap()
        valueField.typeText("72")
        
        app.buttons["Save"].tap()
        
        // Assert
        let newMetric = app.cells.containing(.staticText, identifier: "Heart Rate").element
        XCTAssertTrue(newMetric.waitForExistence(timeout: 2))
        XCTAssertTrue(app.cells.staticTexts["72 bpm"].exists)
    }
}
```

## Mock Strategy

### Protocol-Based Mocking

```swift
// MockHealthRepository.swift
final class MockHealthRepository: HealthRepositoryProtocol {
    // Control properties
    var shouldFail = false
    var mockError: Error = NetworkError.unknown
    var networkDelay: TimeInterval = 0
    
    // Verification properties
    private(set) var uploadCalled = false
    private(set) var uploadedMetrics: [HealthMetric]?
    private(set) var fetchCalled = false
    
    // Mock data
    var mockMetrics: [HealthMetric] = []
    var mockResponse = ProcessingResponse(
        processingId: "mock-123",
        status: "completed",
        metricsCount: 0,
        estimatedCompletion: Date()
    )
    
    func uploadHealthData(_ metrics: [HealthMetric]) async throws -> ProcessingResponse {
        uploadCalled = true
        uploadedMetrics = metrics
        
        if networkDelay > 0 {
            try await Task.sleep(nanoseconds: UInt64(networkDelay * 1_000_000_000))
        }
        
        if shouldFail {
            throw mockError
        }
        
        return mockResponse
    }
    
    func fetchHealthData(limit: Int, offset: Int) async throws -> PaginatedHealthData {
        fetchCalled = true
        
        if shouldFail {
            throw mockError
        }
        
        let page = Array(mockMetrics.dropFirst(offset).prefix(limit))
        
        return PaginatedHealthData(
            total: mockMetrics.count,
            limit: limit,
            offset: offset,
            data: page
        )
    }
}
```

### Mock Factories

```swift
// MockFactory.swift
enum MockFactory {
    static func makeHealthMetric(
        type: HealthMetricType = .heartRate,
        value: Double = 72,
        timestamp: Date = Date()
    ) -> HealthMetric {
        HealthMetric(
            type: type,
            value: value,
            unit: type.unit,
            timestamp: timestamp,
            source: "Mock"
        )
    }
    
    static func makeUser(
        id: String = UUID().uuidString,
        email: String = "test@example.com"
    ) -> User {
        User(
            id: id,
            email: email,
            firstName: "Test",
            lastName: "User"
        )
    }
}

// Extension for arrays
extension HealthMetric {
    static func mockArray(count: Int) -> [HealthMetric] {
        (0..<count).map { i in
            MockFactory.makeHealthMetric(
                value: Double.random(in: 60...100),
                timestamp: Date().addingTimeInterval(TimeInterval(-i * 3600))
            )
        }
    }
}
```

## Test Helpers

### Async Test Helpers

```swift
// XCTestCase+Async.swift
extension XCTestCase {
    func asyncTest(
        timeout: TimeInterval = 10,
        block: @escaping () async throws -> Void
    ) {
        let expectation = expectation(description: "Async test")
        
        Task {
            do {
                try await block()
            } catch {
                XCTFail("Async test failed: \(error)")
            }
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: timeout)
    }
    
    func waitForCondition(
        timeout: TimeInterval = 5,
        condition: @escaping () async -> Bool
    ) async throws {
        let start = Date()
        
        while Date().timeIntervalSince(start) < timeout {
            if await condition() {
                return
            }
            try await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        }
        
        XCTFail("Condition not met within timeout")
    }
}
```

### SwiftUI Test Helpers

```swift
// ViewInspector+Helpers.swift
extension View {
    func testable() -> some View {
        self.environment(\.isTestEnvironment, true)
    }
}

private struct IsTestEnvironmentKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var isTestEnvironment: Bool {
        get { self[IsTestEnvironmentKey.self] }
        set { self[IsTestEnvironmentKey.self] = newValue }
    }
}
```

## Test Organization

### Directory Structure
```
clarity-loop-frontend-v2Tests/
├── Unit/
│   ├── Models/
│   ├── ViewModels/
│   ├── Services/
│   ├── Repositories/
│   └── Utilities/
├── Integration/
│   ├── API/
│   ├── Database/
│   └── EndToEnd/
├── Mocks/
│   ├── Services/
│   ├── Repositories/
│   └── Utilities/
├── Helpers/
│   ├── Extensions/
│   └── Factories/
└── Resources/
    ├── JSON/
    └── TestData/
```

### Test Naming Convention

```swift
func test_methodName_condition_expectedResult() {
    // Test implementation
}

// Examples:
func test_login_validCredentials_returnsSuccess()
func test_fetchData_noInternet_throwsNetworkError()
func test_saveMetric_duplicateId_throwsConstraintError()
```

## Continuous Integration Tests

### Pre-commit Tests
```bash
#!/bin/bash
# .git/hooks/pre-commit

echo "Running unit tests..."
xcodebuild test \
    -project clarity-loop-frontend-v2.xcodeproj \
    -scheme clarity-loop-frontend-v2 \
    -destination 'platform=iOS Simulator,name=iPhone 15' \
    -only-testing:clarity-loop-frontend-v2Tests/Unit \
    -quiet

if [ $? -ne 0 ]; then
    echo "Unit tests failed. Commit aborted."
    exit 1
fi
```

### CI Pipeline Tests
```yaml
# .github/workflows/test.yml
name: Test Suite

on: [push, pull_request]

jobs:
  unit-tests:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Unit Tests
        run: |
          xcodebuild test \
            -project clarity-loop-frontend-v2.xcodeproj \
            -scheme clarity-loop-frontend-v2 \
            -destination 'platform=iOS Simulator,name=iPhone 15' \
            -resultBundlePath TestResults
      
      - name: Upload Results
        uses: actions/upload-artifact@v3
        with:
          name: test-results
          path: TestResults.xcresult
```

## Test Coverage Requirements

### Minimum Coverage Targets
- Overall: 80%
- Critical Paths: 95%
- ViewModels: 90%
- Services: 85%
- Models: 70%

### Coverage Exceptions
```swift
// Use @testable wisely
@testable import ClarityPulse

// Mark untestable code
// swiftlint:disable:next test_coverage
private func untestableLegacyCode() {
    // Code that can't be tested
}
```

## Performance Testing

```swift
final class PerformanceTests: XCTestCase {
    func test_largeDataSetQuery_performance() {
        self.measure {
            // Performance critical code
            let metrics = try! context.fetch(
                FetchDescriptor<HealthMetric>(
                    sortBy: [SortDescriptor(\.timestamp)]
                )
            )
            _ = metrics.count
        }
    }
    
    func test_encryption_performance() {
        let data = Data(repeating: 0, count: 1_000_000) // 1MB
        
        self.measure(metrics: [XCTClockMetric(), XCTMemoryMetric()]) {
            _ = try! encryptionService.encrypt(data)
        }
    }
}
```

## ⚠️ HUMAN INTERVENTION REQUIRED

### Test Execution
1. **All tests must be run in Xcode** - AI cannot execute tests
2. **Use Cmd+U** for all tests or Cmd+Ctrl+U for current test
3. **UI tests require** simulator or device configuration
4. **Performance tests need** baseline configuration

### Test Debugging
1. **Breakpoints** must be set in Xcode
2. **View hierarchy debugging** for UI test failures
3. **Memory graph** for leak detection
4. **Console logs** for test output

### Coverage Reports
1. **Enable coverage** in scheme settings
2. **View coverage** in Xcode report navigator
3. **Export coverage** for CI integration

---

Remember: Untested code is broken code. Test everything!