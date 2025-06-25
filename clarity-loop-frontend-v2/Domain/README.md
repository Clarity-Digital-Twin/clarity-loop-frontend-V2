# Domain Layer

The Domain layer contains the core business logic and entities of the CLARITY Pulse application. This layer is independent of any external frameworks or dependencies.

## Structure

```
Domain/
├── Entities/              # Core domain models
│   ├── User.swift
│   ├── HealthMetric.swift
│   ├── HealthMetricType.swift
│   └── HealthMetricSource.swift
├── Repositories/          # Repository protocols
│   ├── UserRepositoryProtocol.swift
│   ├── HealthMetricRepositoryProtocol.swift
│   └── RepositoryError.swift
├── Services/              # Service protocols
│   └── AuthServiceProtocol.swift
├── UseCases/              # Business logic
│   ├── LoginUseCase.swift
│   └── RecordHealthMetricUseCase.swift
└── Errors/                # Domain-specific errors
    └── ValidationError.swift
```

## Key Principles

1. **Protocol-Oriented**: All external dependencies are defined as protocols
2. **Testable**: Every component has comprehensive unit tests
3. **Independent**: No dependencies on UI, Data, or Infrastructure layers
4. **Type-Safe**: Strong typing with Swift 6.1 features

## Entities

### User
- Represents a user in the system
- Includes profile information and authentication state
- Supports profile completion checks

### HealthMetric
- Represents a single health measurement
- Includes validation for acceptable value ranges
- Supports multiple metric types and sources

## Use Cases

### LoginUseCase
- Handles user authentication flow
- Updates last login timestamp
- Validates input before processing

### RecordHealthMetricUseCase
- Records individual or batch health metrics
- Validates metric values against acceptable ranges
- Checks for duplicate entries

## Testing

All domain components follow TDD principles:
1. Tests written first
2. Implementation to make tests pass
3. Refactoring while keeping tests green

Run domain tests:
```bash
swift test --filter Domain
```