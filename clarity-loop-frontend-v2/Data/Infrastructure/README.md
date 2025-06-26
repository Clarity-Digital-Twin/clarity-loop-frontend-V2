# Infrastructure Layer

This directory contains the concrete implementations of infrastructure concerns for the Data layer.

## Structure

```
Infrastructure/
├── Network/          # Network client implementations
├── Persistence/      # SwiftData persistence implementations  
└── Services/         # External service integrations
```

## Design Principles

- **Dependency Inversion**: All implementations depend on abstractions from the Domain layer
- **Single Responsibility**: Each component has one clear purpose
- **Testability**: All implementations are testable via protocol abstractions

## Components

### Network
- `NetworkClient.swift`: URLSession-based API client implementation

### Persistence  
- `SwiftDataPersistence.swift`: SwiftData ModelContainer management

### Services
- External service integrations (AWS, HealthKit, etc.)