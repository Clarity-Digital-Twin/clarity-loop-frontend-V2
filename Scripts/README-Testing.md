# CLARITY Pulse V2 - Test Configuration Guide

## Overview

This document describes the test infrastructure and configuration for the CLARITY Pulse V2 Swift Package Manager project.

## Test Structure

The project uses Swift Package Manager's built-in test support with the following test targets:

- **ClarityDomainTests** - Unit tests for business logic and domain models
- **ClarityDataTests** - Unit tests for data layer (repositories, DTOs)
- **ClarityUITests** - Tests for SwiftUI views and view models
- **ClarityCoreTests** - Tests for DI container and architecture

## Running Tests

### Using Make Commands

```bash
# Run all tests with coverage
make test

# Run specific test suites
make test-unit        # Unit tests only
make test-integration # Integration tests (currently disabled)
make test-ui         # UI component tests
make test-performance # Performance baseline tests
make test-ci         # CI mode with strict coverage (80% minimum)

# Generate coverage reports
make coverage         # Text report
make coverage-html    # HTML report (opens in browser)

# TDD watch mode
make test-tdd        # Watches for changes and reruns tests
```

### Using Swift Commands Directly

```bash
# Run all tests
swift test

# Run with coverage
swift test --enable-code-coverage

# Run specific test target
swift test --filter ClarityDomainTests

# Run specific test class
swift test --filter LoginViewModelTests

# Run tests in parallel
swift test --parallel
```

### Using Test Scripts

The `Scripts/` directory contains specialized test scripts:

- `test-all.sh` - Runs all tests with coverage reporting
- `test-unit.sh` - Runs only unit tests
- `test-integration.sh` - Runs integration tests (when enabled)
- `test-ui.sh` - Runs UI tests
- `test-performance.sh` - Sets up performance baselines
- `test-ci.sh` - CI-optimized test runner with coverage threshold

## Coverage Configuration

### Coverage Requirements

Minimum coverage threshold: **80%**

Target-specific thresholds (defined in `.test-config.json`):
- ClarityCore: 85%
- ClarityDomain: 90%
- ClarityData: 80%
- ClarityUI: 75%

### Viewing Coverage

1. **Text Report**: 
   ```bash
   make coverage
   # Output: build/coverage/coverage.txt
   ```

2. **HTML Report**:
   ```bash
   make coverage-html
   # Opens: build/coverage/html/index.html
   ```

3. **CI Coverage**:
   ```bash
   make test-ci
   # Outputs: .build/test-results/coverage.lcov
   ```

## Test Configuration File

The `.test-config.json` file defines:
- Coverage thresholds per module
- Test suite configurations
- CI settings
- Performance baselines

## TDD/BDD Workflow

1. **Start TDD Session**:
   ```bash
   make tdd-start FEATURE=login
   ```

2. **Create New Test**:
   ```bash
   make tdd-new-test NAME=LoginViewModel
   ```

3. **Watch Mode**:
   ```bash
   make test-tdd
   ```

## Performance Testing

Performance baselines are defined in `.build/performance-results/performance-baseline.json`:

- Login flow: 500ms target
- Health data sync: 1000ms target
- Dashboard load: 200ms target
- Database queries: 10-50ms targets

## CI Integration

For GitHub Actions or other CI systems:

```bash
# Run CI tests with JUnit XML and LCOV coverage
./Scripts/test-ci.sh

# Outputs:
# - .build/test-results/tests.xml (JUnit format)
# - .build/test-results/coverage.lcov (LCOV format)
# - .build/test-results/coverage-html/ (HTML report)
```

## Troubleshooting

### Tests Timing Out

If `swift test` times out:
1. Check for infinite loops in tests
2. Verify async test expectations have timeouts
3. Run specific test targets to isolate issues

### Coverage Not Generated

If coverage reports are empty:
1. Ensure tests are actually running
2. Check that code is being exercised by tests
3. Verify `.build/debug/codecov` directory exists

### Module Import Errors

Remember that test targets need explicit imports:
```swift
@testable import ClarityDomain
@testable import ClarityData
// etc.
```

## Best Practices

1. **Follow TDD**: Write failing tests first
2. **Use BDD naming**: `test_whenCondition_shouldExpectedBehavior()`
3. **Keep tests fast**: Mock external dependencies
4. **Test behavior, not implementation**: Focus on public APIs
5. **Maintain coverage**: Don't merge code that drops coverage below 80%

## Future Enhancements

- [ ] Re-enable integration tests (currently disabled)
- [ ] Add UI test recordings
- [ ] Implement performance test measurements
- [ ] Add mutation testing
- [ ] Set up test result trending