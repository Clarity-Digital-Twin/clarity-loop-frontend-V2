# CLARITY Pulse V2 - TDD/BDD Development Guidelines

## Project Context
CLARITY Pulse V2 is a complete rebuild of a HIPAA-compliant iOS health tracking app. This is a **SwiftUI + SwiftData** application that serves as a frontend wrapper for the backend API.

## 🚨 FUNDAMENTAL DEVELOPMENT PHILOSOPHY: TDD + BDD

### Test-Driven Development (TDD)
**NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST. NO EXCEPTIONS.**

Red → Green → Refactor:
1. **Red**: Write a failing test that describes the desired behavior
2. **Green**: Write MINIMUM code to make the test pass
3. **Refactor**: Improve code quality while keeping tests green

### Behavior-Driven Development (BDD)
**DESCRIBE BEHAVIOR, NOT IMPLEMENTATION**

Write tests that describe what the system does, not how:
```swift
// ✅ BDD - Describes behavior
func test_whenUserLogsIn_withValidCredentials_shouldShowDashboard()
func test_whenHealthDataSyncs_withNoNetwork_shouldQueueForLaterSync()

// ❌ Not BDD - Tests implementation
func test_loginMethodCallsAuthService()
func test_repositorySavesDataToDatabase()
```

## Architecture Overview

### Clean Architecture Layers
```
UI Layer       → SwiftUI Views + @Observable ViewModels (MVVM)
Domain Layer   → Use Cases + Domain Models + Repository Protocols  
Data Layer     → Repositories + Services + DTOs
Infrastructure → Network + SwiftData + AWS Amplify
```

### Key Design Patterns & Principles
- **MVVM Architecture** - Clear separation of View and Business Logic
- **@Observable ViewModels** (iOS 17+) - No more ObservableObject
- **SOLID Principles** - Single Responsibility, Open/Closed, Liskov Substitution, Interface Segregation, Dependency Inversion
- **DRY (Don't Repeat Yourself)** - Reusable components and shared logic
- **Repository Pattern** - Abstract data sources (Gang of Four)
- **Factory Pattern** - For object creation in DI container
- **Observer Pattern** - Built into SwiftUI's reactive system
- **Strategy Pattern** - For interchangeable algorithms (e.g., auth providers)
- **Decorator Pattern** - For extending functionality (e.g., middleware)
- **Protocol-First Design** - Everything testable via protocols
- **Dependency Injection** - No singletons, testable architecture
- **ViewState<T>** - Consistent async state handling

## Critical Swift Rules

### Access Control - THIS IS AN APP, NOT A FRAMEWORK!
```swift
// ✅ CORRECT - Private by default
private let apiClient: APIClient
private func syncData() { }
internal protocol RepositoryProtocol { }  // Only when needed cross-module

// ❌ WRONG - Don't make things public
public class DataManager { }  // NO! This isn't a library!
public func configure() { }   // NO! Keep it internal!
```

### Module Visibility Rules - CRITICAL FOR COMPILATION!

**This is a modular Swift Package with separate targets!**

Since we split the code into ClarityDomain, ClarityData, ClarityUI modules:
- Each module is compiled separately (like mini frameworks)
- Cross-module access requires `public` visibility
- `@testable import ModuleName` only exposes internals of that specific module

**What needs to be public:**
```swift
// ✅ MUST BE PUBLIC - Used across modules
public struct HealthMetric { }           // Used by Data layer
public protocol UserRepository { }       // Implemented in Data layer
public enum ValidationError { }          // Thrown across modules
public final class LoginUseCase { }      // Used by UI layer

// ❌ KEEP INTERNAL - Only used within module
internal class MockAPIClient { }         // Test helper
private func parseResponse() { }         // Implementation detail
```

**Module Import Rules:**
```swift
// Domain tests
@testable import ClarityDomain

// Data layer tests (needs both)
@testable import ClarityData
@testable import ClarityDomain  // For domain types

// UI tests
@testable import ClarityUI
import ClarityDomain  // For public types

// ❌ NEVER DO THIS - Module doesn't exist!
@testable import clarity_loop_frontend_v2  // NO SUCH MODULE!
```

### HIPAA Compliance Requirements
- **NO logging of health data** - Ever.
- **Biometric auth** for sensitive operations
- **Encrypted storage** for all PHI
- **Audit trail** for data access
- **Secure transmission** - HTTPS only

## Essential Tool Integration

### Taskmaster CLI (Primary Task Management)
```bash
# View current tasks (200 vertical slice tasks ready!)
task-master list --status pending
task-master next

# Work on tasks
task-master set-status --id=1 --status=in-progress
task-master set-status --id=1 --status=done

# Expand complex tasks with TDD focus
task-master expand --id=<id> --num=10 --prompt="Create TDD subtasks"

# Track progress
task-master list --status done
```

**IMPORTANT**: 200 comprehensive tasks have been created following vertical slices.
See `CLARITY_VERTICAL_SLICE_TASK_SUMMARY.md` for complete details.

### MCP Tools Available
- **mcp__taskmaster-ai__*** - Task management operations
- **mcp__XcodeBuildMCP__*** - Xcode build and test automation
- **mcp__Filesystem__*** - File operations
- **mcp__sequential-thinking__*** - Complex problem solving
- **TodoWrite/TodoRead** - In-session task tracking

### Xcode Build Commands
```bash
# Use MCP tools for building/testing
mcp__XcodeBuildMCP__build_sim_name_ws
mcp__XcodeBuildMCP__test_sim_name_ws
mcp__XcodeBuildMCP__describe_ui  # For UI testing
```

## TDD/BDD Workflow Example

```swift
// 1. BDD Scenario: User views health metrics
describe("Health Dashboard") {
    context("when user has synced data") {
        it("displays current step count") {
            // Given
            let mockHealthKit = MockHealthKitService()
            mockHealthKit.mockSteps = 10_000
            
            // When
            let viewModel = DashboardViewModel(healthKit: mockHealthKit)
            
            // Then
            expect(viewModel.stepCount).toEventually(equal("10,000"))
        }
    }
}

// 2. TDD Implementation
func test_loadHealthMetrics_updatesViewState() async {
    // Red: Test fails - no implementation
    let sut = DashboardViewModel(healthKit: mockService)
    
    await sut.loadHealthMetrics()
    
    XCTAssertEqual(sut.viewState, .success)
}

// 3. Green: Minimal implementation
func loadHealthMetrics() async {
    viewState = .success([])  // Just enough to pass
}

// 4. Refactor: Add real logic with all tests still passing
```

## SwiftUI + SwiftData Patterns

### ViewModels with @Observable
```swift
@Observable
final class DashboardViewModel {
    // State is automatically observable
    private(set) var metrics: [HealthMetric] = []
    private(set) var viewState: ViewState<[HealthMetric]> = .idle
    
    // Dependencies injected
    private let healthService: HealthServiceProtocol
    
    init(healthService: HealthServiceProtocol) {
        self.healthService = healthService
    }
}
```

### SwiftData Models
```swift
@Model
final class HealthMetric {
    private(set) var id: UUID
    private(set) var type: MetricType
    private(set) var value: Double
    private(set) var recordedAt: Date
    
    // Relationships
    private(set) var user: User?
    
    init(type: MetricType, value: Double) {
        self.id = UUID()
        self.type = type
        self.value = value
        self.recordedAt = Date()
    }
}
```

## Backend Integration Requirements

The frontend is a wrapper for 44 backend endpoints. Key considerations:
- **DTOs must match exactly** - See CLARITY_ENDPOINT_MAPPING.md
- **Error responses are standardized** - Handle consistently
- **WebSocket for real-time** - See CLARITY_WEBSOCKET_REALTIME_GUIDE.md
- **Offline-first architecture** - See CLARITY_OFFLINE_SYNC_ARCHITECTURE.md

## Human Intervention Points

**🛑 STOP and request human help for:**
1. Xcode project configuration changes
2. Certificate/provisioning profile setup  
3. Build settings modifications
4. Dependency management (SPM)
5. Archive and distribution

## V2 Specific Guidelines

### What's Different from V1
- **Fresh start with TDD/BDD** - No legacy code
- **SwiftData instead of Core Data**
- **@Observable instead of ObservableObject**
- **Proper dependency injection from day 1**
- **Protocol-first architecture**

### Document References
Essential guides for implementation:
- `CLARITY_VERTICAL_SLICE_TASK_SUMMARY.md` - 200 tasks in vertical slices
- `CLARITY_IMPLEMENTATION_GUIDE.md` - Step-by-step TDD approach
- `CLARITY_ENDPOINT_MAPPING.md` - All 44 endpoints with DTOs
- `CLARITY_SWIFT_BEST_PRACTICES.md` - Avoid AI agent pitfalls
- `CLARITY_PROGRESS_TRACKER.md` - Track implementation progress

## Quick Command Reference

```bash
# Taskmaster
task-master next
task-master set-status --id=<id> --status=done
task-master expand --id=<id>

# Testing
swift test --filter DashboardTests
swift test --parallel

# Building  
swift build -c debug
swift build -c release
```

## Remember

1. **TDD is mandatory** - No exceptions
2. **BDD describes user behavior** - Not technical implementation  
3. **Private by default** - This is an app, not a framework
4. **HIPAA compliance** - Security first, always
5. **Use Taskmaster** - For task management and progress tracking
6. **Request human help** - For Xcode-specific operations

---

This is CLARITY Pulse V2. We're building it right from the start with TDD/BDD.

Every line of production code must be justified by a failing test that describes desired behavior.