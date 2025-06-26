# Domain Layer

The Domain layer is the heart of the application, containing all business logic and rules. This layer has **zero dependencies** on external frameworks or other layers.

## Structure

```
Domain/
├── Entities/              # Core business objects
├── UseCases/              # Application business rules
├── Repositories/          # Data access abstractions
├── Services/              # External service abstractions
└── Errors/                # Domain-specific errors
```

## Key Principles

### 1. Framework Independence
- No imports of UIKit, SwiftUI, or any external frameworks
- Pure Swift code only
- All types are `Sendable` for concurrency safety

### 2. Business Logic Encapsulation
- All business rules live in UseCases
- Entities contain only data and simple validations
- Complex operations are delegated to UseCases

### 3. Dependency Inversion
- Depends on abstractions (protocols), never concrete implementations
- Repository and Service protocols define contracts
- Implementations exist in the Data layer

## Components

### Entities
Core business objects that represent the domain model:
- `User` - User account information
- `HealthMetric` - Health measurement data
- `HealthMetricType` - Types of health metrics
- `HealthMetricSource` - Source of health data

### Use Cases
Business operations that orchestrate the flow:
- `LoginUseCase` - Handles user authentication flow
- `RecordHealthMetricUseCase` - Records new health measurements

### Repository Protocols
Abstractions for data persistence:
- `UserRepositoryProtocol` - User data operations
- `HealthMetricRepositoryProtocol` - Health metric operations

### Service Protocols
Abstractions for external services:
- `AuthServiceProtocol` - Authentication service operations

## Testing

All domain components are 100% testable without any framework setup:

```swift
// Example: Testing a use case
func test_login_withValidCredentials_shouldReturnUser() async {
    // Given
    let authService = MockAuthService()
    let userRepo = MockUserRepository()
    let sut = LoginUseCase(authService: authService, userRepository: userRepo)
    
    // When
    let result = try await sut.execute(email: "test@example.com", password: "password")
    
    // Then
    XCTAssertNotNil(result)
}
```

## Best Practices

1. **Keep it Pure**: No side effects in entities
2. **Single Responsibility**: Each use case does one thing
3. **Protocol-First**: Define protocols before implementations
4. **Testability**: Every component must be easily testable
5. **Documentation**: Document complex business rules