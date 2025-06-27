#!/bin/bash
# CI Test Script - Optimized for continuous integration environments
# This script runs tests with CI-friendly output and strict error handling

set -euo pipefail

# CI Environment Variables
export CI=true
export TERM=dumb
export NSUnbufferedIO=YES

echo "🤖 Running Tests in CI Mode..."
echo "=============================="

# Function to check minimum coverage
check_coverage() {
    local min_coverage=80
    local actual_coverage=$(swift test --enable-code-coverage --show-codecov-path | xargs -I {} sh -c 'xcrun --sdk macosx llvm-cov report -instr-profile={} .build/debug/*.xctest/Contents/MacOS/* | tail -1' | awk '{print $10}' | sed 's/%//')
    
    if (( $(echo "$actual_coverage < $min_coverage" | bc -l) )); then
        echo "❌ Coverage ($actual_coverage%) is below minimum threshold ($min_coverage%)"
        exit 1
    else
        echo "✅ Coverage ($actual_coverage%) meets minimum threshold ($min_coverage%)"
    fi
}

# Kill any zombie Swift processes before starting
echo "🧹 Cleaning up any stuck processes..."
pkill -f swift-frontend 2>/dev/null || true
pkill -f swift-driver 2>/dev/null || true
pkill -f swift-test 2>/dev/null || true

# Clean previous test results only (keep build cache)
echo "🧹 Cleaning test results..."
rm -rf .build/test-results
mkdir -p .build/test-results

# Build the project once
echo "🔨 Building project (one-time compilation)..."
swift build --configuration debug

# Run tests with coverage and JUnit output using skip-build
echo "🧪 Running tests without rebuilding..."
swift test \
    --skip-build \
    --enable-code-coverage \
    --parallel \
    --xunit-output .build/test-results/tests.xml \
    --enable-test-discovery

# Generate coverage reports
echo "📊 Generating coverage reports..."
COVERAGE_PATH=$(swift test --show-codecov-path)

# Export LCOV for codecov.io or similar services
xcrun --sdk macosx llvm-cov export \
    -format=lcov \
    -instr-profile=$COVERAGE_PATH \
    .build/debug/ClarityPulsePackageTests.xctest/Contents/MacOS/ClarityPulsePackageTests \
    > .build/test-results/coverage.lcov

# Export JSON for detailed analysis
xcrun --sdk macosx llvm-cov export \
    -format=text \
    -instr-profile=$COVERAGE_PATH \
    .build/debug/ClarityPulsePackageTests.xctest/Contents/MacOS/ClarityPulsePackageTests \
    > .build/test-results/coverage.json

# Generate HTML report for human review
xcrun --sdk macosx llvm-cov show \
    -format=html \
    -instr-profile=$COVERAGE_PATH \
    -output-dir=.build/test-results/coverage-html \
    .build/debug/ClarityPulsePackageTests.xctest/Contents/MacOS/ClarityPulsePackageTests

# Check coverage threshold
echo "📈 Checking coverage threshold..."
check_coverage

echo "✅ CI tests completed successfully!"
echo ""
echo "📁 Test artifacts available in:"
echo "   - JUnit XML: .build/test-results/tests.xml"
echo "   - LCOV: .build/test-results/coverage.lcov"
echo "   - HTML Report: .build/test-results/coverage-html/index.html"