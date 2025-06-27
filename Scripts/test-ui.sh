#!/bin/bash
# UI Tests Script - Runs UI tests
# This script runs SwiftUI component tests

set -e

echo "🎨 Running UI Tests..."

# Run UI tests
swift test \
    --enable-code-coverage \
    --filter "ClarityUITests" \
    --xunit-output .build/test-results/ui-tests.xml

# Generate coverage report
echo "📊 Generating UI Coverage Report..."
xcrun xcresulttool get --path .build/debug/codecov/action.xccovreport --format json > coverage-ui.json

echo "✅ UI tests completed successfully!"