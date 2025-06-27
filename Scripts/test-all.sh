#!/bin/bash
# All Tests Script - Runs all test suites with code coverage
# This script orchestrates running all test types

set -e

echo "🚀 Running All Tests with Coverage..."
echo "=================================="

# Kill any zombie Swift processes before starting
echo "🧹 Cleaning up any stuck processes..."
pkill -f swift-frontend 2>/dev/null || true
pkill -f swift-driver 2>/dev/null || true
pkill -f swift-test 2>/dev/null || true

# Create test results directory
mkdir -p .build/test-results

# Build once strategy - compile all dependencies first
echo "🔨 Building project (one-time compilation)..."
swift build --configuration debug

# Run all available tests with coverage using skip-build
echo "🧪 Running tests without rebuilding..."
swift test \
    --skip-build \
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