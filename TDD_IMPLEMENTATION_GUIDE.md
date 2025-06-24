# TDD Implementation Guide for CLARITY

## The TDD Mindset Shift

### From Current Approach:
```swift
// 1. Write feature code
// 2. Maybe write tests later
// 3. Tests don't work, skip them
// 4. Ship broken code
```

### To TDD Approach:
```swift
// 1. Write failing test for behavior
// 2. Write minimum code to pass
// 3. Refactor with safety net
// 4. Ship working code with confidence
```

## Week 1: Foundation Sprint

### Day 1: Project Setup (4 hours)

#### Hour 1: Create New Project
```bash
# Create new Xcode project
- Name: ClarityPulse
- Team: Your Team
- Organization Identifier: com.clarity
- Interface: SwiftUI
- Language: Swift
- Use Core Data: NO (we'll use SwiftData)
- Include Tests: YES
```

#### Hour 2: Setup Dependencies
```ruby
# Podfile
platform :ios, '17.0'
use_frameworks!

target 'ClarityPulse' do
  # Dependency Injection
  pod 'Swinject'
  
  # Networking
  pod 'OpenAPIGenerator'
  
  # WebSocket
  pod 'Starscream'
  
  # AWS
  pod 'AWSCore'
  pod 'AWSCognito'
  pod 'AWSS3'
end

target 'ClarityPulseTests' do
  inherit! :search_paths
  
  pod 'Quick'
  pod 'Nimble'
  pod 'Mockingbird'
end
```

#### Hour 3: TDD Structure
```
ClarityPulse/
├── Application/
│   └── ClarityPulseApp.swift
├── Core/
│   ├── DI/
│   │   └── Container+Setup.swift
│   └── Network/
│       └── APIClient.swift
├── Features/
│   └── Authentication/
│       ├── Domain/
│       ├── Data/
│       └── Presentation/
└── Resources/
```

#### Hour 4: First TDD Cycle
```swift
// Test: AuthenticationServiceTests.swift
import XCTest
@testable import ClarityPulse

final class AuthenticationServiceTests: XCTestCase {
    func test_signIn_withValidCredentials_shouldReturnUser() async throws {
        // Arrange
        let mockCognito = MockCognitoService()
        mockCognito.mockUser = User(id: "123", email: "test@example.com")
        let sut = AuthenticationService(cognito: mockCognito)
        
        // Act
        let user = try await sut.signIn(email: "test@example.com", password: "password")
        
        // Assert
        XCTAssertEqual(user.id, "123")
        XCTAssertEqual(user.email, "test@example.com")
    }
}

// RED: Test fails - no code exists

// GREEN: Minimum implementation
struct User {
    let id: String
    let email: String
}

protocol CognitoServiceProtocol {
    func signIn(email: String, password: String) async throws -> User
}

final class AuthenticationService {
    private let cognito: CognitoServiceProtocol
    
    init(cognito: CognitoServiceProtocol) {
        self.cognito = cognito
    }
    
    func signIn(email: String, password: String) async throws -> User {
        return try await cognito.signIn(email: email, password: password)
    }
}

// REFACTOR: Add validation
final class AuthenticationService {
    // ... previous code ...
    
    func signIn(email: String, password: String) async throws -> User {
        guard email.isValidEmail else {
            throw AuthError.invalidEmail
        }
        guard password.count >= 8 else {
            throw AuthError.weakPassword
        }
        return try await cognito.signIn(email: email, password: password)
    }
}
```

### Day 2: Authentication Layer

#### Morning: AWS Cognito Integration
```swift
// Test: CognitoServiceTests.swift
func test_signIn_callsAWSCognito() async throws {
    // Arrange
    let mockAWS = MockAWSCognito()
    let sut = CognitoService(aws: mockAWS)
    
    // Act
    _ = try await sut.signIn(email: "test@example.com", password: "password")
    
    // Assert
    XCTAssertTrue(mockAWS.signInCalled)
    XCTAssertEqual(mockAWS.capturedEmail, "test@example.com")
}

// Implementation driven by test
final class CognitoService: CognitoServiceProtocol {
    private let aws: AWSCognitoIdentityProvider
    
    init(aws: AWSCognitoIdentityProvider = .default()) {
        self.aws = aws
    }
    
    func signIn(email: String, password: String) async throws -> User {
        let request = AWSCognitoIdentityProviderInitiateAuthRequest()!
        request.authFlow = .userPasswordAuth
        request.authParameters = [
            "USERNAME": email,
            "PASSWORD": password
        ]
        
        let response = try await aws.initiateAuth(request)
        guard let idToken = response.authenticationResult?.idToken else {
            throw AuthError.authenticationFailed
        }
        
        let user = try decodeUser(from: idToken)
        return user
    }
}
```

#### Afternoon: Biometric Authentication
```swift
// Test first
func test_biometricAuth_whenAvailable_shouldAuthenticate() async throws {
    // Arrange
    let mockBiometric = MockBiometricService()
    mockBiometric.isAvailable = true
    mockBiometric.mockSuccess = true
    let sut = AuthenticationService(biometric: mockBiometric)
    
    // Act
    let success = try await sut.authenticateWithBiometric()
    
    // Assert
    XCTAssertTrue(success)
    XCTAssertTrue(mockBiometric.authenticateCalled)
}

// Implementation
protocol BiometricServiceProtocol {
    var isAvailable: Bool { get }
    func authenticate() async throws -> Bool
}

extension AuthenticationService {
    func authenticateWithBiometric() async throws -> Bool {
        guard biometric.isAvailable else {
            throw AuthError.biometricNotAvailable
        }
        return try await biometric.authenticate()
    }
}
```

### Day 3-4: Core Architecture

#### Repository Pattern with TDD
```swift
// Test the contract first
protocol HealthRepositoryProtocol {
    func save(_ metric: HealthMetric) async throws
    func fetch(type: MetricType, range: DateRange) async throws -> [HealthMetric]
    func sync() async throws
}

// Test implementation
func test_save_shouldPersistMetric() async throws {
    // Arrange
    let mockStore = MockDataStore()
    let mockAPI = MockAPIClient()
    let sut = HealthRepository(store: mockStore, api: mockAPI)
    let metric = HealthMetric(type: .heartRate, value: 72, date: Date())
    
    // Act
    try await sut.save(metric)
    
    // Assert
    XCTAssertTrue(mockStore.saveCalled)
    XCTAssertEqual(mockStore.savedMetrics.count, 1)
    XCTAssertEqual(mockStore.savedMetrics.first?.value, 72)
}

// Implementation
final class HealthRepository: HealthRepositoryProtocol {
    private let store: DataStoreProtocol
    private let api: APIClientProtocol
    
    init(store: DataStoreProtocol, api: APIClientProtocol) {
        self.store = store
        self.api = api
    }
    
    func save(_ metric: HealthMetric) async throws {
        try await store.save(metric)
        // Queue for sync
        await SyncQueue.shared.enqueue(metric)
    }
}
```

#### ViewModel Pattern with TDD
```swift
// Test behavior, not implementation
func test_loadHealthData_shouldUpdateState() async {
    // Arrange
    let mockRepo = MockHealthRepository()
    mockRepo.mockMetrics = [
        HealthMetric(type: .steps, value: 5000, date: Date())
    ]
    let sut = HealthViewModel(repository: mockRepo)
    
    // Act
    await sut.loadData()
    
    // Assert
    switch sut.state {
    case .loaded(let metrics):
        XCTAssertEqual(metrics.count, 1)
        XCTAssertEqual(metrics.first?.value, 5000)
    default:
        XCTFail("Expected loaded state")
    }
}

// Clean implementation
@Observable
final class HealthViewModel {
    private(set) var state: ViewState<[HealthMetric]> = .idle
    private let repository: HealthRepositoryProtocol
    
    init(repository: HealthRepositoryProtocol) {
        self.repository = repository
    }
    
    func loadData() async {
        state = .loading
        do {
            let metrics = try await repository.fetch(
                type: .all,
                range: .today
            )
            state = .loaded(metrics)
        } catch {
            state = .error(error)
        }
    }
}
```

### Day 5-7: Network Layer

#### OpenAPI Integration
```bash
# Generate DTOs from backend OpenAPI spec
openapi-generator generate \
  -i backend-api.yaml \
  -g swift5 \
  -o ./Generated
```

#### API Client with TDD
```swift
// Test contract
func test_fetchHealthMetrics_shouldReturnDTOs() async throws {
    // Arrange
    let mockSession = MockURLSession()
    mockSession.mockData = """
    {
        "metrics": [{
            "metric_type": "heart_rate",
            "value": 72.5,
            "timestamp": "2024-01-15T10:00:00Z"
        }]
    }
    """.data(using: .utf8)!
    
    let sut = APIClient(session: mockSession)
    
    // Act
    let response = try await sut.fetchHealthMetrics()
    
    // Assert
    XCTAssertEqual(response.metrics.count, 1)
    XCTAssertEqual(response.metrics.first?.metricType, "heart_rate")
}
```

## Week 2: Feature Implementation

### Day 8-9: HealthKit Integration

#### TDD for HealthKit
```swift
// Test the wrapper
func test_requestAuthorization_shouldRequestCorrectTypes() async throws {
    // Arrange
    let mockHealthStore = MockHKHealthStore()
    let sut = HealthKitService(store: mockHealthStore)
    
    // Act
    try await sut.requestAuthorization()
    
    // Assert
    XCTAssertTrue(mockHealthStore.requestAuthorizationCalled)
    XCTAssertTrue(mockHealthStore.typesToRead.contains(.heartRate))
    XCTAssertTrue(mockHealthStore.typesToRead.contains(.stepCount))
}

// Clean implementation
final class HealthKitService: HealthKitServiceProtocol {
    private let store: HKHealthStore
    
    func requestAuthorization() async throws {
        let types: Set<HKSampleType> = [
            .quantityType(forIdentifier: .heartRate)!,
            .quantityType(forIdentifier: .stepCount)!,
            .categoryType(forIdentifier: .sleepAnalysis)!
        ]
        
        try await store.requestAuthorization(
            toShare: [],
            read: types
        )
    }
}
```

### Day 10-11: WebSocket

#### TDD WebSocket Manager
```swift
// Test connection behavior
func test_connect_shouldEstablishWebSocket() async throws {
    // Arrange
    let mockWebSocket = MockWebSocket()
    let sut = WebSocketManager(socket: mockWebSocket)
    
    // Act
    try await sut.connect()
    
    // Assert
    XCTAssertTrue(mockWebSocket.connectCalled)
    XCTAssertEqual(sut.connectionState, .connected)
}

// Test message handling
func test_receiveMessage_shouldParseHealthUpdate() async throws {
    // Arrange
    let mockDelegate = MockWebSocketDelegate()
    let sut = WebSocketManager()
    sut.delegate = mockDelegate
    
    // Act
    sut.handleMessage("""
    {
        "type": "health_metric_update",
        "data": {
            "metric_type": "heart_rate",
            "value": 75
        }
    }
    """)
    
    // Assert
    XCTAssertTrue(mockDelegate.didReceiveHealthUpdateCalled)
    XCTAssertEqual(mockDelegate.lastHealthUpdate?.value, 75)
}
```

### Day 12-14: UI Implementation

#### SwiftUI with ViewModel Testing
```swift
// Test ViewModel behavior
func test_dashboardViewModel_loadData() async {
    // Arrange
    let mockHealthRepo = MockHealthRepository()
    let mockInsightRepo = MockInsightRepository()
    let sut = DashboardViewModel(
        healthRepo: mockHealthRepo,
        insightRepo: mockInsightRepo
    )
    
    // Act
    await sut.onAppear()
    
    // Assert
    XCTAssertTrue(mockHealthRepo.fetchCalled)
    XCTAssertTrue(mockInsightRepo.fetchLatestCalled)
    XCTAssertNotNil(sut.todaysSummary)
}

// Clean SwiftUI View
struct DashboardView: View {
    @StateObject private var viewModel: DashboardViewModel
    
    init(viewModel: DashboardViewModel = .init()) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    var body: some View {
        Group {
            switch viewModel.state {
            case .loading:
                ProgressView()
            case .loaded:
                ScrollView {
                    MetricsSummaryView(metrics: viewModel.metrics)
                    InsightsView(insights: viewModel.insights)
                }
            case .error(let error):
                ErrorView(error: error) {
                    Task { await viewModel.retry() }
                }
            case .idle, .empty:
                EmptyView()
            }
        }
        .task {
            await viewModel.onAppear()
        }
    }
}
```

## Week 3: Production Ready

### Day 15-16: HIPAA Compliance

#### Audit Logging with TDD
```swift
// Test audit requirements
func test_sensitiveDataAccess_shouldLog() async {
    // Arrange
    let mockLogger = MockAuditLogger()
    let sut = HealthRepository(logger: mockLogger)
    
    // Act
    _ = try await sut.fetchSensitiveData(userId: "123")
    
    // Assert
    XCTAssertTrue(mockLogger.logCalled)
    XCTAssertEqual(mockLogger.lastEvent?.action, .dataAccess)
    XCTAssertEqual(mockLogger.lastEvent?.resourceType, .healthData)
    XCTAssertNotNil(mockLogger.lastEvent?.timestamp)
}
```

### Day 17-18: Integration Testing

#### Real API Tests
```swift
// Test against staging API
func test_realAPI_healthMetricsFlow() async throws {
    // Only run in CI
    try XCTSkipUnless(ProcessInfo.processInfo.environment["CI"] != nil)
    
    // Arrange
    let api = APIClient(baseURL: Config.stagingURL)
    let testUser = try await createTestUser()
    
    // Act
    let metric = HealthMetric(type: .steps, value: 1000, date: Date())
    try await api.uploadMetric(metric, token: testUser.token)
    
    let fetched = try await api.fetchMetrics(token: testUser.token)
    
    // Assert
    XCTAssertTrue(fetched.contains { $0.value == 1000 })
    
    // Cleanup
    try await deleteTestUser(testUser)
}
```

### Day 19-21: Polish

#### Performance Testing
```swift
func test_largeDataset_performance() {
    // Arrange
    let repository = HealthRepository()
    let metrics = (0..<10000).map { i in
        HealthMetric(type: .steps, value: Double(i), date: Date())
    }
    
    // Act & Assert
    measure {
        let saved = try await repository.batchSave(metrics)
        XCTAssertEqual(saved.count, 10000)
    }
}
```

## The TDD Workflow

### Every Feature:
1. **Write failing test** for the behavior
2. **Write minimum code** to make it pass
3. **Refactor** while tests stay green
4. **Commit** with confidence

### Every Bug:
1. **Write test** that reproduces the bug
2. **Fix** until test passes
3. **Add edge cases** to prevent regression

### Every Day:
1. **Run all tests** before starting
2. **TDD new features** throughout the day
3. **Run all tests** before pushing
4. **Fix any broken tests** immediately

## Measuring Success

### Coverage Goals
- **Unit Tests**: 90%+ coverage
- **Integration**: All API endpoints
- **UI Tests**: Critical user flows
- **Performance**: No regressions

### Quality Metrics
- **0 production crashes**
- **< 1% error rate**
- **< 200ms API response time**
- **60 FPS UI always**

## The Payoff

After 3 weeks of TDD:
- **Confidence** to refactor anything
- **Documentation** through tests
- **Regression protection** forever
- **Fast feature development** 
- **Happy users** with working app

## Remember

> "TDD is not about testing. It's about design and confidence."

Every test you write is:
- A specification of behavior
- Documentation of intent
- Protection against regression
- Confidence to change

Start with the test. Always.