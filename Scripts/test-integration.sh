#!/bin/bash
# Integration Tests Script - Runs integration tests with code coverage
# This script runs only integration tests

set -e

echo "🔗 Running Integration Tests with Coverage..."

# Note: Integration tests are currently disabled in Package.swift
# Uncomment when tests are re-enabled
echo "⚠️  Integration tests are currently disabled in Package.swift"
echo "   Uncomment the ClarityIntegrationTests target to enable"

# When enabled, use:
# swift test \
#     --enable-code-coverage \
#     --parallel \
#     --filter "ClarityIntegrationTests" \
#     --xunit-output .build/test-results/integration-tests.xml

# Generate coverage report when tests are enabled
# xcrun xcresulttool get --path .build/debug/codecov/action.xccovreport --format json > coverage-integration.json

echo "⏭️  Skipping integration tests (disabled)"