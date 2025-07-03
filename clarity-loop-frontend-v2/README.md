# ClarityPulse SPM Package

## 🚨 BUILD INSTRUCTIONS 🚨

**This is an SPM package. To build and run the app:**

```bash
cd ../ClarityPulseWrapper
open ClarityPulse.xcworkspace  # ⚠️ WORKSPACE, NOT PROJECT
```

**See:** `../CLARITY_APP_BUILD_PROCESS.md` for complete instructions.

## Package Architecture

This Swift Package contains the core modules for the CLARITY Pulse iOS app:

```
Sources/
├── Core/           # Core services, DI, security
│   ├── Configuration/
│   ├── DI/         # Dependency injection
│   ├── Security/   # Keychain, biometric auth
│   └── Services/   # Core services
├── Domain/         # Business logic
│   ├── Entities/   # Domain models
│   ├── Repositories/ # Repository protocols
│   └── UseCases/   # Business use cases
├── Data/           # Data layer
│   ├── DTOs/       # Data transfer objects
│   ├── Models/     # Persistence models
│   └── Repositories/ # Repository implementations
└── UI/             # User interface
    ├── Common/     # Shared UI components
    ├── Components/ # Reusable components
    ├── ViewModels/ # View models
    └── Views/      # SwiftUI views
```

## Clean Architecture

The package follows clean architecture principles:

- **Domain:** Business logic, entities, use cases (no dependencies)
- **Data:** Repository implementations, DTOs, persistence
- **Core:** Cross-cutting concerns, services, DI
- **UI:** SwiftUI views, view models, presentation logic

## Key Features

- Swift 6 strict concurrency compliance
- @Observable state management (no ViewModels)
- Dependency injection with protocols
- Secure keychain storage
- AWS Amplify authentication
- Health data tracking
- Comprehensive test coverage

## Development

### Adding New Features

1. **Domain First:** Define entities and use cases in `Domain/`
2. **Data Layer:** Implement repositories in `Data/`
3. **UI Layer:** Create views and view models in `UI/`
4. **Tests:** Add comprehensive tests for each layer

### Dependencies

Managed in `Package.swift`:
- AWS Amplify (authentication)
- SwiftData (persistence)
- CryptoKit (security)

### Testing

```bash
# Run tests from package directory
swift test

# Or from Xcode workspace
# Test → Test (⌘U)
```

## Module Dependencies

```
UI → Domain ← Data
 ↓     ↑
Core ←┘
```

- UI depends on Domain and Core
- Data depends on Domain and Core
- Domain has no dependencies (pure business logic)
- Core provides shared services

## Integration

This package is consumed by the Xcode wrapper project in `../ClarityPulseWrapper/`.

**To build the complete app:** Use the workspace, not this package directly.

---

**🚨 TO RUN THE APP: Use `../ClarityPulseWrapper/ClarityPulse.xcworkspace` 🚨**
