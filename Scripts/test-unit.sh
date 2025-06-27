#!/bin/bash
# Unit Tests Script - Runs unit tests with code coverage
# This script runs only unit tests (excluding integration and UI tests)

set -e

echo "🧪 Running Unit Tests with Coverage..."

# Run unit tests with coverage enabled
swift test \
    --enable-code-coverage \
    --parallel \
    --filter "ClarityDomainTests|ClarityDataTests|ClarityCoreTests" \
    --xunit-output .build/test-results/unit-tests.xml

# Generate coverage report
echo "📊 Generating Coverage Report..."
xcrun xcresulttool get --path .build/debug/codecov/action.xccovreport --format json > coverage-unit.json

echo "✅ Unit tests completed successfully!"