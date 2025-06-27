#!/bin/bash
# Unit Tests Script - Runs unit tests with code coverage
# This script runs only unit tests (excluding integration and UI tests)

set -e

echo "🧪 Running Unit Tests with Coverage..."

# Kill any zombie Swift processes before starting
echo "🧹 Cleaning up any stuck processes..."
pkill -f swift-frontend 2>/dev/null || true
pkill -f swift-driver 2>/dev/null || true
pkill -f swift-test 2>/dev/null || true

# Build once strategy - compile dependencies first
echo "🔨 Building project (one-time compilation)..."
swift build --configuration debug

# Run unit tests with coverage enabled using skip-build
echo "📊 Running tests without rebuilding..."
swift test \
    --skip-build \
    --enable-code-coverage \
    --parallel \
    --filter "ClarityDomainTests|ClarityDataTests|ClarityCoreTests" \
    --xunit-output .build/test-results/unit-tests.xml

# Generate coverage report if tests passed
if [ $? -eq 0 ]; then
    echo "📊 Generating Coverage Report..."
    if [ -f .build/debug/codecov/action.xccovreport ]; then
        xcrun xcresulttool get --path .build/debug/codecov/action.xccovreport --format json > coverage-unit.json
    fi
fi

echo "✅ Unit tests completed successfully!"