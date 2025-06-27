#!/bin/bash
# Integration Tests Script - Runs integration tests with code coverage
# This script runs only integration tests

set -e

echo "🔗 Running Integration Tests with Coverage..."

# Kill any zombie Swift processes before starting
echo "🧹 Cleaning up any stuck processes..."
pkill -f swift-frontend 2>/dev/null || true
pkill -f swift-driver 2>/dev/null || true
pkill -f swift-test 2>/dev/null || true

# Build once strategy - compile dependencies first
echo "🔨 Building project (one-time compilation)..."
swift build --configuration debug

# Run integration tests with coverage
echo "🧪 Running integration tests without rebuilding..."
swift test \
    --skip-build \
    --enable-code-coverage \
    --parallel \
    --filter "ClarityIntegrationTests" \
    --xunit-output .build/test-results/integration-tests.xml

# Generate coverage report if tests passed
if [ $? -eq 0 ]; then
    echo "📊 Generating Coverage Report..."
    if [ -f .build/debug/codecov/action.xccovreport ]; then
        xcrun xcresulttool get --path .build/debug/codecov/action.xccovreport --format json > coverage-integration.json
    fi
fi

echo "✅ Integration tests completed successfully!"