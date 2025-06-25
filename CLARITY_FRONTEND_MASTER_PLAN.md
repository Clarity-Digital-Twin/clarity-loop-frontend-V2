# CLARITY Frontend V2 Master Rebuild Plan

## Executive Summary

This document serves as the canonical blueprint for rebuilding the CLARITY Pulse iOS frontend as a proper wrapper for the backend API. The V1 frontend was fundamentally broken because it was built without a proper backend contract. This plan ensures V2 is built correctly using Test-Driven Development (TDD) and proper architectural patterns.

## Current State Analysis

### What's Broken (V1)
- Frontend doesn't match backend API contract (44 endpoints)
- Business logic doesn't work
- Tests are incomplete/fake (only 5 files with XCTSkip, not 170+ as previously thought)
- No proper dependency injection
- Repositories are final classes instead of protocols
- Mock infrastructure is incomplete

### What's Working
- Project structure and file organization
- Xcode configurations (Info.plist, build settings, targets)
- AWS Amplify configuration
- HealthKit entitlements
- Basic UI components
- Test targets are properly configured

### Backend Contract Summary
- **Total Endpoints**: 44
- **Auth**: 7 endpoints (register, login, logout, refresh, verify, reset-password, profile)
- **Health Data**: 5 endpoints (upload, list, get, delete, status)
- **HealthKit**: 4 endpoints (upload, status, sync, categories)
- **AI Insights**: 6 endpoints (generate, chat, summary, recommendations, trends, alerts)
- **PAT Analysis**: 5 endpoints (analysis, status, results, batch, models)
- **Metrics**: 4 endpoints (health, user, export, prometheus)
- **WebSocket**: 3 endpoints (main, health, rooms)
- **System**: 4 endpoints (health, docs, redoc, openapi)

## Rebuild Strategy

### Phase 1: Preparation & Cleanup
**Goal**: Clean repository with stable configurations preserved

### Phase 2: Core Infrastructure
**Goal**: Build foundation with proper TDD

### Phase 3: Backend Integration
**Goal**: Implement all 44 API endpoints with tests

### Phase 4: UI Implementation
**Goal**: Build UI components that properly use the backend

### Phase 5: Integration & Polish
**Goal**: Complete app with all features working

## What to Keep vs Delete

### KEEP (Stable Configurations)
1. **Project Structure**
   - clarity-loop-frontend-v2.xcodeproj
   - All Info.plist files
   - clarity-loop-frontend-v2.entitlements
   - Assets.xcassets

2. **Build Configurations**
   - All target settings
   - Build phases
   - Linked frameworks
   - Capabilities configuration

3. **Resources**
   - amplifyconfiguration.json
   - Any image assets
   - Launch screen configurations

4. **Test Infrastructure**
   - Test target configurations
   - XCTest framework links
   - UI test target setup

### DELETE (Broken Implementation)
1. **All Swift Implementation Files**
   - Keep file structure but delete contents
   - Maintain folder hierarchy for organization

2. **Specific Files to Completely Remove**
   - CognitoAuthService.swift.disabled
   - CognitoConfiguration.swift.disabled
   - WebSocketManagerTests.swift.disabled
   - Any .disabled files

## Architecture Blueprint

### Clean Architecture Layers

```
┌─────────────────────────────────────────┐
│            Presentation Layer            │
│         (SwiftUI Views + VMs)           │
├─────────────────────────────────────────┤
│             Domain Layer                 │
│    (Use Cases + Domain Models)          │
├─────────────────────────────────────────┤
│              Data Layer                  │
│  (Repositories + DTOs + Services)       │
├─────────────────────────────────────────┤
│         Infrastructure Layer             │
│    (Networking + Persistence)           │
└─────────────────────────────────────────┘
```

### Dependency Flow
- Views depend on ViewModels
- ViewModels depend on Use Cases
- Use Cases depend on Repository Protocols
- Repository Implementations depend on Services
- All dependencies injected via protocols

## Human Intervention Points

### Required Human Actions in Xcode

1. **Initial Setup**
   - Open project in Xcode
   - Verify all targets compile
   - Check signing & capabilities
   - Verify HealthKit entitlements

2. **After Core Infrastructure Phase**
   - Run tests in Xcode
   - Verify simulator builds
   - Check for any missing framework links

3. **After Backend Integration**
   - Test on real device
   - Verify HealthKit permissions
   - Check push notification setup

4. **Before Release**
   - Archive and validate
   - Check all build configurations
   - Verify release entitlements

## Implementation Order

### Week 1: Foundation
1. Clean codebase (preserve configs)
2. Create protocol infrastructure
3. Build networking layer with tests
4. Implement basic auth flow

### Week 2: Core Features
1. Health data upload/sync
2. HealthKit integration
3. Basic UI screens
4. Offline queue management

### Week 3: AI Features
1. PAT analysis integration
2. Insights generation
3. Chat functionality
4. WebSocket real-time updates

### Week 4: Polish & Testing
1. Complete UI implementation
2. Integration testing
3. Performance optimization
4. Security audit

## Success Criteria

### Technical Requirements
- [ ] All 44 backend endpoints properly wrapped
- [ ] 100% test coverage for business logic
- [ ] Proper error handling for all API calls
- [ ] Offline support with sync queue
- [ ] HIPAA-compliant data handling

### Functional Requirements
- [ ] User can register and login
- [ ] HealthKit data syncs to backend
- [ ] AI insights are generated and displayed
- [ ] Real-time updates via WebSocket
- [ ] All UI matches backend capabilities

## Next Steps

1. Review this plan with human
2. Get approval to proceed
3. Start with `CLARITY_IMPLEMENTATION_GUIDE.md`
4. Begin Phase 1: Preparation & Cleanup

---

*This is a living document. Update as the project progresses.*