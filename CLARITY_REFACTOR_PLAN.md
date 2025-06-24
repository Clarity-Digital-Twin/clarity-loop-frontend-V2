# CLARITY Frontend Refactoring Plan

## Executive Summary

After deep analysis, the CLARITY frontend has fundamental architectural issues that make it nearly impossible to maintain or extend. The codebase shows:

- **0% real test coverage** (489 fake tests)
- **Fundamental misalignment** with backend APIs
- **Broken architecture** (untestable `final` classes everywhere)
- **Incorrect assumptions** about authentication, data models, and APIs

## Current State Analysis

### What's Broken
1. **Authentication**: Expects custom JWT, backend uses AWS Cognito
2. **WebSocket**: Completely broken implementation
3. **Data Models**: Don't match backend DTOs
4. **Testing**: All tests are placeholders with `XCTSkip`
5. **Dependency Injection**: Non-existent, everything tightly coupled
6. **HIPAA Compliance**: Missing critical security features

### What Works
1. Basic UI layout (SwiftUI views)
2. HealthKit integration skeleton
3. Build configuration
4. AWS Amplify setup (but misconfigured)

## Recommendation: Test-Driven Rewrite

### Why Not Refactor?
- Would take 4-6 weeks to untangle dependencies
- No tests means no safety net for changes
- Fundamental misalignments require rewriting 80% anyway
- Current architecture prevents proper testing

### Why TDD Rewrite?
- 2-3 weeks to production-ready
- Proper architecture from day one
- 100% real test coverage
- Correct API integration
- HIPAA compliance built-in

## Implementation Plan

### Week 1: Foundation (Days 1-7)
**Day 1-2: Project Setup**
- New project with TDD structure
- Proper dependency injection (Resolver/Swinject)
- CI/CD with mandatory test coverage
- OpenAPI code generation setup

**Day 3-4: Authentication Layer**
- AWS Cognito integration (TDD)
- Biometric authentication
- Session management
- Token refresh handling

**Day 5-7: Core Architecture**
- Repository pattern with protocols
- ViewModels with proper DI
- Error handling framework
- Network layer with Combine

### Week 2: Features (Days 8-14)
**Day 8-9: Health Data**
- HealthKit integration (TDD)
- Data sync with backend
- Offline storage with SwiftData
- Background sync

**Day 10-11: Real-time Features**
- WebSocket manager (TDD)
- Health monitoring
- AI chat integration
- Push notifications

**Day 12-14: UI Implementation**
- Dashboard with real data
- Health insights views
- Settings and profile
- Accessibility compliance

### Week 3: Production Ready (Days 15-21)
**Day 15-16: HIPAA Compliance**
- Audit logging
- Data encryption
- Access controls
- Privacy features

**Day 17-18: Integration Testing**
- E2E test suite
- Performance testing
- Security testing
- Backend integration tests

**Day 19-21: Polish & Deploy**
- Error tracking (Sentry)
- Analytics
- App Store preparation
- Documentation

## Architecture Blueprint

```
clarity-pulse-ios/
├── App/
│   ├── CLARITYApp.swift
│   └── Configuration/
├── Core/
│   ├── DI/                  # Dependency Injection
│   ├── Network/            # API Client, WebSocket
│   ├── Security/           # HIPAA, Encryption
│   └── Extensions/
├── Data/
│   ├── Repositories/       # Protocol implementations
│   ├── Services/          # External service wrappers
│   ├── DTOs/              # Generated from OpenAPI
│   └── Persistence/       # SwiftData models
├── Domain/
│   ├── Models/            # Business models
│   ├── UseCases/          # Business logic
│   └── Repositories/      # Protocol definitions
├── Presentation/
│   ├── ViewModels/        # @Observable, DI
│   ├── Views/             # SwiftUI
│   └── Components/        # Reusable UI
└── Tests/
    ├── Unit/              # TDD tests
    ├── Integration/       # API tests
    └── UI/                # UI automation
```

## Key Principles

### 1. Test-Driven Development
- Write test first, always
- No code without failing test
- Minimum code to pass
- Refactor with green tests

### 2. Dependency Injection
```swift
protocol HealthRepositoryProtocol {
    func fetchMetrics() async throws -> [HealthMetric]
}

@Observable
final class HealthViewModel {
    private let repository: HealthRepositoryProtocol
    
    init(repository: HealthRepositoryProtocol) {
        self.repository = repository
    }
}
```

### 3. Protocol-Oriented Design
- All dependencies as protocols
- Easy mocking for tests
- Flexible implementations
- Clean boundaries

### 4. Async/Await + Combine
- Modern concurrency
- Reactive streams where needed
- Proper error propagation
- Testable async code

## Success Metrics

### Code Quality
- **100% critical path coverage** (not bullshit tests)
- **0 force unwraps** in production code
- **All async code tested**
- **No singleton abuse**

### Performance
- **Cold start < 1s**
- **API calls < 200ms** (p95)
- **60 FPS** UI always
- **Background sync** without battery drain

### Security
- **HIPAA compliant** audit logs
- **Biometric** + PIN fallback
- **End-to-end encryption** for health data
- **Zero sensitive data** in logs

## Migration Strategy

### Phase 1: New Foundation (Week 1)
- Build new app alongside old
- Share only Assets.xcassets
- Independent test suite
- No legacy dependencies

### Phase 2: Feature Parity (Week 2)
- Implement core features TDD
- Validate against backend
- User acceptance testing
- Performance benchmarks

### Phase 3: Transition (Week 3)
- Data migration tools
- User transition plan
- Deprecate old app
- Monitor and iterate

## Tools & Technologies

### Development
- **Xcode 16** + Swift 6
- **SwiftUI** + iOS 17 minimum
- **Swift Concurrency** (async/await)
- **Combine** for reactive streams

### Testing
- **XCTest** + Swift Testing
- **Quick/Nimble** for BDD
- **Mockingbird** for mocks
- **Proxyman** for API testing

### Backend Integration
- **OpenAPI Generator** for DTOs
- **URLSession** + async/await
- **Starscream** for WebSocket
- **AWS SDK** for Cognito

### Quality
- **SwiftLint** + custom rules
- **Danger** for PR checks
- **Fastlane** for CI/CD
- **Codecov** for coverage

## Next Steps

1. **Get buy-in** on TDD rewrite vs refactor
2. **Set up new project** with proper structure
3. **Start with auth** - most critical path
4. **Daily progress** with working features
5. **Deploy weekly** to TestFlight

## The Bottom Line

The current codebase is beyond salvage. A clean TDD rewrite will:
- Take **less time** than refactoring (3 weeks vs 6 weeks)
- Produce **maintainable** code with real tests
- Actually **work** with the backend APIs
- Be **HIPAA compliant** from day one
- Enable **rapid iteration** going forward

The choice is clear: **Start fresh with TDD**.

---

*"The best time to plant a tree was 20 years ago. The second best time is now."*