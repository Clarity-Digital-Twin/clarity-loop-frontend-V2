# Data Layer

The Data layer implements the abstractions defined in the Domain layer and handles all data operations including network requests, local persistence, and external service integrations.

## Structure

```
Data/
├── Repositories/          # Repository implementations
├── DTOs/                  # Data Transfer Objects
├── Services/              # Service protocol definitions
├── Infrastructure/        # Technical implementations
│   ├── Network/           # API client and networking
│   └── Persistence/       # SwiftData local storage
├── Models/                # Persistence models
└── Errors/                # Data layer specific errors
```

## Key Responsibilities

### 1. Repository Implementations
Concrete implementations of Domain repository protocols:
- `UserRepositoryImplementation` - Manages user data with network/cache coordination
- `HealthMetricRepositoryImplementation` - Handles health metric persistence

### 2. Data Transfer Objects (DTOs)
Objects for API communication that map to/from domain entities:
- `UserDTO` - API representation of User
- `HealthMetricDTO` - API representation of HealthMetric
- `AuthTokenDTO` - Authentication token structure

### 3. Infrastructure

#### Network Layer
- `NetworkClient` - Generic HTTP client with async/await
- `APIClientProtocol` - Defines network operations
- Error handling and retry logic
- Request/response transformation

#### Persistence Layer
- `SwiftDataPersistence` - Local database using SwiftData
- `PersistedUser` - SwiftData model for User
- `PersistedHealthMetric` - SwiftData model for HealthMetric
- Offline-first architecture support

### 4. Service Implementations
External service integrations (implemented in AppDependencies):
- AWS Amplify authentication
- HealthKit integration
- Push notification services

## Data Flow

```
Domain UseCase
    ↓ (calls)
Repository Protocol
    ↓ (implemented by)
Repository Implementation
    ↓ (uses)
Network Client / Persistence
    ↓ (transforms)
DTOs / Models
```

## Key Patterns

### Repository Pattern
```swift
class UserRepositoryImplementation: UserRepositoryProtocol {
    private let networkClient: NetworkClientProtocol
    private let persistence: PersistenceServiceProtocol
    
    func findById(_ id: UUID) async throws -> User? {
        // Try cache first
        if let cached = try await persistence.fetch(id) {
            return cached
        }
        
        // Fetch from network
        let dto: UserDTO = try await networkClient.get("/users/\(id)")
        let user = dto.toDomain()
        
        // Cache for offline use
        try await persistence.save(user)
        
        return user
    }
}
```

### DTO Mapping
```swift
struct UserDTO: Codable {
    let id: String
    let email: String
    let firstName: String
    let lastName: String
    
    func toDomain() -> User {
        User(
            id: UUID(uuidString: id)!,
            email: email,
            firstName: firstName,
            lastName: lastName
        )
    }
}
```

## Testing

Data layer components are tested with mocks:

```swift
func test_userRepository_whenNetworkFails_shouldReturnCachedData() async {
    // Given
    let networkClient = MockNetworkClient()
    networkClient.shouldFail = true
    
    let persistence = MockPersistence()
    persistence.cachedUser = testUser
    
    let sut = UserRepositoryImplementation(
        networkClient: networkClient,
        persistence: persistence
    )
    
    // When
    let result = try await sut.findById(testUser.id)
    
    // Then
    XCTAssertEqual(result, testUser)
}
```

## Best Practices

1. **Separation of Concerns**: Keep network, persistence, and mapping logic separate
2. **Error Handling**: Transform infrastructure errors to domain errors
3. **Caching Strategy**: Implement appropriate caching for offline support
4. **DTO Validation**: Validate data from external sources
5. **Dependency Injection**: All dependencies injected via constructor