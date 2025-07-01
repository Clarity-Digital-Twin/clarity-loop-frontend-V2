# DI Migration Checklist: DIContainer → Dependencies

## Phase 1: Audit Results ✅

### Files Using DIContainer.shared
- [x] LoginView.swift - `LoginViewModelFactory`
- [x] DashboardView.swift - `DashboardViewModelFactory`, `HealthMetricRepositoryProtocol`, `APIClient`
- [x] ProfileView.swift - `AuthServiceProtocol`
- [x] HealthMetricsView.swift - `HealthMetricRepositoryProtocol`
- [x] ClarityPulseApp.swift - `ModelContainer`

### Bridge/Configuration Files (TO DELETE)
- [ ] DIContainer.swift
- [ ] DIContainerBridge.swift
- [ ] LegacyDIConfiguration.swift
- [ ] AppDependencies.swift (legacy registrations)
- [ ] AppDependencies+SwiftUI.swift (bridge code only)

### Test Files to Update
- [ ] DIContainerTests.swift
- [ ] LoginViewTests.swift
- [ ] DashboardViewTests.swift

## Phase 2: Migration Tasks

### Step 1: Create Environment Keys
- [ ] Create `EnvironmentKeys+ViewModels.swift`
  - [ ] LoginViewModelFactoryKey
  - [ ] DashboardViewModelFactoryKey
  - [ ] AuthServiceKey (already exists)
  - [ ] HealthMetricRepositoryKey (already exists)
  - [ ] APIClientKey (already exists)
  - [ ] ModelContainerKey (already exists)

### Step 2: Update App Entry Point
- [ ] ClarityPulseWrapperApp.swift
  - [ ] Remove DIContainerBridge call
  - [ ] Configure Dependencies properly
  - [ ] Add `.withDependencies()` modifier to root view

### Step 3: Migrate Views (NO WORK IN INIT!)

#### LoginView.swift
- [ ] Remove DIContainer access from init()
- [ ] Add `@Environment(\.loginViewModelFactory) var factory`
- [ ] Move viewModel creation to `.task { }`
- [ ] Handle loading state

#### DashboardView.swift
- [ ] Remove DIContainer access from init()
- [ ] Add `@Environment(\.dashboardViewModelFactory) var factory`
- [ ] Add `@Environment(\.healthMetricRepository) var repository`
- [ ] Add `@Environment(\.apiClient) var apiClient`
- [ ] Move viewModel creation to `.task { }`
- [ ] Update sheet to use environment values

#### ProfileView.swift
- [ ] Add `@Environment(\.authService) var authService`
- [ ] Remove DIContainer access from performLogout()
- [ ] Use environment authService directly

#### HealthMetricsView.swift
- [ ] Add `@Environment(\.healthMetricRepository) var repository`
- [ ] Remove DIContainer access from submitMetric()
- [ ] Use environment repository directly

#### ClarityPulseApp.swift
- [ ] Add `@Environment(\.modelContainer) var modelContainer`
- [ ] Remove DIContainer access from init()
- [ ] Pass modelContainer via environment

### Step 4: Update Tests
- [ ] LoginViewTests.swift - use withDependencies
- [ ] DashboardViewTests.swift - use withDependencies
- [ ] Create new tests that verify no DIContainer usage

### Step 5: Delete Legacy Code
- [ ] Delete DIContainer.swift
- [ ] Delete DIContainerBridge.swift
- [ ] Delete LegacyDIConfiguration.swift
- [ ] Remove legacy registrations from AppDependencies.swift
- [ ] Remove bridge code from AppDependencies+SwiftUI.swift
- [ ] Delete DIContainerTests.swift

### Step 6: Update Documentation
- [ ] Update DI_SYSTEMS_AUDIT.md
- [ ] Update DI_MIGRATION_PLAN.md
- [ ] Create new DI usage guide

## Success Criteria

### Build Gates
- [ ] `swift build` succeeds
- [ ] `swift test` succeeds
- [ ] `xcodebuild -scheme ClarityPulseWrapper -destination "generic/platform=iOS"` succeeds

### Runtime Gates
- [ ] App launches on simulator
- [ ] LoginView appears (not black screen)
- [ ] No fatalError in console
- [ ] Can navigate through app

### Code Quality Gates
- [ ] Zero references to DIContainer.shared
- [ ] All dependencies injected via Environment
- [ ] No work in View init()
- [ ] All tests pass

## Implementation Order

1. **Commit 1**: Create EnvironmentKeys+ViewModels.swift
2. **Commit 2**: Update ClarityPulseWrapperApp with Dependencies
3. **Commit 3**: Migrate LoginView
4. **Commit 4**: Migrate DashboardView
5. **Commit 5**: Migrate ProfileView
6. **Commit 6**: Migrate HealthMetricsView
7. **Commit 7**: Migrate ClarityPulseApp
8. **Commit 8**: Update all tests
9. **Commit 9**: Delete all legacy DI code
10. **Commit 10**: Update documentation