# CLARITY Code Coverage Requirements

## Overview

Code coverage is configured and enforced across all CLARITY modules to ensure high code quality and comprehensive testing.

## Coverage Targets

Per `.test-config.json`, the following minimum coverage targets are enforced:

| Module | Minimum Coverage | Rationale |
|--------|-----------------|-----------|
| **ClarityCore** | 85% | Core infrastructure requires high coverage |
| **ClarityDomain** | 90% | Business logic must be thoroughly tested |
| **ClarityData** | 80% | Data layer with external dependencies |
| **ClarityUI** | 75% | UI layer with SwiftUI complexity |
| **Overall** | 80% | Project-wide minimum |

## Running Coverage Reports

### Quick Coverage Check
```bash
# Generate coverage report
./Scripts/generate-coverage-report.sh

# View HTML report
open .build/coverage-report/index.html
```

### Coverage with Different Test Suites
```bash
# Unit tests with coverage
./Scripts/test-unit.sh

# All tests with coverage
./Scripts/test-all.sh

# CI mode with strict coverage enforcement
./Scripts/test-ci.sh
```

## Pre-commit Hook

Install the pre-commit hook to ensure tests pass before commits:
```bash
./Scripts/setup-pre-commit.sh
```

This will:
- Run fast unit tests before each commit
- Block commits if tests fail
- Help maintain code quality

## Coverage Configuration

### `.test-config.json`
```json
{
  "coverage": {
    "minimum": 80,
    "targets": {
      "ClarityCore": 85,
      "ClarityDomain": 90,
      "ClarityData": 80,
      "ClarityUI": 75
    },
    "exclude": [
      "*/Mocks/*",
      "*/Tests/*",
      "*/Preview Content/*",
      "*.generated.swift"
    ]
  }
}
```

### Excluded from Coverage
- Mock implementations
- Test files themselves
- SwiftUI preview providers
- Generated code

## Swift Package Manager Coverage

Coverage is enabled via SPM flags:
```bash
swift test --enable-code-coverage
```

Coverage data is generated in:
- `.build/debug/codecov/`
- `.build/*/default.profdata`

## Viewing Coverage

### Command Line
```bash
# Summary by file
xcrun llvm-cov report <executable> -instr-profile=<profdata>

# Detailed line-by-line
xcrun llvm-cov show <executable> -instr-profile=<profdata>
```

### HTML Report
```bash
# Generate HTML report
xcrun llvm-cov show <executable> \
  -instr-profile=<profdata> \
  -format=html \
  -output-dir=.build/coverage-report

# Open in browser
open .build/coverage-report/index.html
```

## CI Integration

GitHub Actions automatically:
1. Runs all tests with coverage
2. Generates coverage reports
3. Uploads to Codecov
4. Comments on PRs with coverage changes
5. Blocks merge if coverage drops below minimum

## Best Practices

### DO:
- ✅ Write tests first (TDD)
- ✅ Aim for >90% coverage on critical paths
- ✅ Test edge cases and error conditions
- ✅ Keep coverage consistent across modules

### DON'T:
- ❌ Write tests just to increase coverage
- ❌ Test implementation details
- ❌ Include generated code in coverage
- ❌ Ignore coverage warnings

## Troubleshooting

### Coverage Not Generated
```bash
# Clean and rebuild
swift package clean
swift build
swift test --enable-code-coverage
```

### Coverage Report Errors
```bash
# Find the correct profdata
find .build -name "*.profdata"

# Find the test executable
find .build -name "*PackageTests.xctest"
```

### Low Coverage Areas

Common causes:
1. Missing error path tests
2. Untested edge cases
3. Dead code (remove it!)
4. Complex UI logic (refactor to testable ViewModels)

## Module-Specific Guidelines

### ClarityDomain (90% target)
- Test all business logic paths
- Cover all validation cases
- Test error conditions

### ClarityCore (85% target)
- Test DI container thoroughly
- Cover all utility functions
- Test error handling

### ClarityData (80% target)
- Mock external dependencies
- Test data transformations
- Cover error responses

### ClarityUI (75% target)
- Focus on ViewModel logic
- Test state management
- UI previews don't count

## Summary

Code coverage is not just a metric—it's a tool to ensure:
- Business logic is thoroughly tested
- Edge cases are handled
- Refactoring is safe
- Code quality remains high

Maintain coverage discipline throughout development!