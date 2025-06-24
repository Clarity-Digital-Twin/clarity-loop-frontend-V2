# CLARITY iOS App - Canonical Execution Plan
## The Definitive Guide to Our Test-Driven Resurrection

Created: 2025-06-24
Status: ACTIVE - IN PROGRESS
Current Step: 2.3 (Fixing UserProfileViewModelTests)

---

## Executive Summary

We discovered that 489 "passing" tests are all fake (using XCTSkip). Instead of burning everything down, we're performing a **controlled refactoring through test-driven fixes**. Each fixed test becomes documentation for the eventual rewrite.

## The Master Plan

### Phase 1: Test Infrastructure Revolution (Current Phase)
**Timeline**: 1 week
**Status**: 40% Complete

#### Completed ✅
1. Created MockHealthRepository from scratch
2. Fixed HealthViewModelTests (19/20 passing)
3. Created MockUserProfileRepository
4. Fixed ViewStateTests
5. Fixed BackendIntegrationTests
6. Created TestableHealthViewModel pattern for `final` class workarounds
7. Fixed compilation errors in UserProfileViewModelTests

#### In Progress 🔄
- Task 2.3: Complete UserProfileViewModelTests execution
- Task 2.4: Run test suite and verify all fixes

#### Remaining Tasks 📋
1. **Fix Authentication Tests**
   - LoginViewModelTests
   - RegistrationViewModelTests
   - AuthServiceTests
   - Create MockAuthService improvements

2. **Fix Repository Tests**
   - HealthRepositoryTests
   - UserProfileRepositoryTests
   - AIInsightRepositoryTests
   - PATAnalysisRepositoryTests

3. **Fix Service Tests**
   - HealthKitServiceTests
   - WebSocketManagerTests (currently disabled)
   - APIServiceTests
   - BiometricAuthServiceTests

4. **Fix Integration Tests**
   - AuthenticationIntegrationTests
   - HealthDataContractValidationTests
   - PATContractValidationTests

### Phase 2: Parallel TDD Branch
**Timeline**: 1 week
**Status**: Not Started

1. Create branch: `feature/tdd-architecture`
2. Implement proper dependency injection
3. Create protocol-based architecture
4. Build repositories with TDD
5. Migrate working UI components

### Phase 3: Architecture Migration
**Timeline**: 1 week
**Status**: Not Started

1. Replace concrete dependencies with protocols
2. Implement proper Repository pattern
3. Add dependency injection container
4. Create comprehensive mock system

## Current Working Directory Structure

```
clarity-loop-frontend/
├── CLARITY_CANONICAL_EXECUTION_PLAN.md (THIS FILE)
├── SHOCKING_TRUTHS.md (Why we're doing this)
├── CLARITY_REFACTOR_PLAN.md (Original 3-week plan)
├── BACKEND_API_REALITY.md (API mismatches)
├── TDD_IMPLEMENTATION_GUIDE.md (Day-by-day guide)
└── clarity-loop-frontendTests/
    ├── Mocks/ (Our new mock infrastructure)
    │   ├── MockHealthRepository.swift ✅
    │   ├── MockUserProfileRepository.swift ✅
    │   ├── MockHealthKitService.swift ✅
    │   └── MockAuthService.swift (needs updates)
    └── Features/
        ├── Health/
        │   └── HealthViewModelTests.swift ✅ (19/20 passing)
        └── Profile/
            └── UserProfileViewModelTests.swift 🔄 (in progress)
```

## Git Strategy

### Current Branch
- Working on: `experimental`
- All fixes committed with pattern: "test: Fix [Component] tests - implement real assertions"

### Planned Branches
1. `feature/test-infrastructure` - Current test fixes
2. `feature/tdd-architecture` - Parallel TDD implementation
3. `feature/architecture-migration` - Final migration

## Key Decisions Made

1. **Don't Burn It Down** - We're learning too much from fixing tests
2. **Every Test Tells a Story** - Fixed tests become our specification
3. **Parallel Development** - Fix tests while building TDD version
4. **Document Everything** - This file is our source of truth

## How to Continue If Disconnected

### If you're picking this up fresh:

1. **Check Current Status**
   ```bash
   git status
   grep -r "XCTSkip" clarity-loop-frontendTests/ | wc -l
   ```

2. **Find Next Test File**
   ```bash
   grep -r "XCTSkip" clarity-loop-frontendTests/ | head -10
   ```

3. **Fix Pattern**
   - Replace `XCTSkip("Placeholder...")` with real assertions
   - Create mocks if needed (see Mocks/ directory for patterns)
   - Ensure tests actually test behavior, not just compile

4. **Run Tests**
   ```bash
   xcodebuild test -project clarity-loop-frontend.xcodeproj \
     -scheme clarity-loop-frontendTests \
     -destination 'platform=iOS Simulator,name=iPad (A16),OS=18.5'
   ```

### Current Test Counts
- Total test files: ~50
- Files with XCTSkip: ~45 (at start)
- Files fixed: 5
- Files remaining: ~40

## Success Metrics

1. **Phase 1 Success**: All tests have real implementations (0 XCTSkip)
2. **Phase 2 Success**: TDD branch has 80%+ coverage
3. **Phase 3 Success**: Main app uses new architecture

## Emergency Procedures

### If Tests Won't Compile
1. Check for missing mock methods
2. Verify protocol conformance
3. Use `TestableViewModel` pattern for `final` classes

### If Overwhelmed
1. Pick ONE test file
2. Fix ONE test method
3. Commit immediately
4. Repeat

## The Philosophy

We're not just fixing tests. We're:
1. **Documenting** the intended behavior
2. **Learning** the actual architecture
3. **Building** the foundation for a proper rewrite
4. **Creating** a safety net for refactoring

Every test we fix is a step toward a maintainable codebase.

## Next Immediate Actions

1. ✅ Create this document
2. 🔄 Finish UserProfileViewModelTests
3. ⏳ Run full test suite
4. ⏳ Commit all changes
5. ⏳ Move to next test file (LoginViewModelTests)

---

**Remember**: This is a marathon, not a sprint. Each test fixed is progress. Each mock created is infrastructure. Each workaround discovered is knowledge gained.

*"The best time to plant a tree was 20 years ago. The second best time is now."*

END OF CANONICAL PLAN - EXECUTE WITH CONFIDENCE