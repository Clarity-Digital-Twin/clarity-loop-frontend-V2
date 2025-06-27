#!/bin/bash
# All Tests Script - Runs all test suites with code coverage
# This script orchestrates running all test types

set -e

echo "🚀 Running All Tests with Coverage..."
echo "=================================="

# Create test results directory
mkdir -p .build/test-results

# Run all available tests with coverage
swift test \
    --enable-code-coverage \
    --parallel

# Export coverage data in different formats
echo "📊 Exporting Coverage Data..."

# Get the coverage data path
COVERAGE_PATH=$(swift test --show-codecov-path)

# Convert to lcov format for CI tools
if command -v xcrun &> /dev/null; then
    xcrun --sdk macosx llvm-cov export \
        -format=lcov \
        -instr-profile=$COVERAGE_PATH \
        .build/debug/ClarityPulsePackageTests.xctest/Contents/MacOS/ClarityPulsePackageTests \
        > coverage.lcov
fi

# Generate human-readable report
swift test --enable-code-coverage --show-codecov-path | xargs -I {} sh -c 'xcrun --sdk macosx llvm-cov report -instr-profile={} .build/debug/*.xctest/Contents/MacOS/*'

echo "✅ All tests completed successfully!"
echo ""
echo "📈 Coverage Summary:"
swift test --enable-code-coverage --show-codecov-path | xargs -I {} sh -c 'xcrun --sdk macosx llvm-cov report -instr-profile={} .build/debug/*.xctest/Contents/MacOS/* | tail -1'