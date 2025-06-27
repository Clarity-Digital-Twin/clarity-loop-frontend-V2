#!/bin/bash
# UI Tests Script - Runs UI tests
# This script runs SwiftUI component tests

set -e

echo "🎨 Running UI Tests..."

# Kill any zombie Swift processes before starting
echo "🧹 Cleaning up any stuck processes..."
pkill -f swift-frontend 2>/dev/null || true
pkill -f swift-driver 2>/dev/null || true
pkill -f swift-test 2>/dev/null || true

# Build once strategy
echo "🔨 Building project (one-time compilation)..."
swift build --configuration debug

# Run UI tests without rebuilding
echo "🧪 Running UI tests without rebuilding..."
swift test \
    --skip-build \
    --enable-code-coverage \
    --filter "ClarityUITests" \
    --xunit-output .build/test-results/ui-tests.xml

# Generate coverage report
echo "📊 Generating UI Coverage Report..."
xcrun xcresulttool get --path .build/debug/codecov/action.xccovreport --format json > coverage-ui.json

echo "✅ UI tests completed successfully!"