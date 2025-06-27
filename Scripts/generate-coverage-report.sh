#!/bin/bash

# CLARITY Coverage Report Script
# Generates and displays test coverage for all modules

set -e

echo "📊 CLARITY Coverage Report"
echo "=========================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Build once for efficiency
echo "🔨 Building project..."
swift build --configuration debug

# Run tests with coverage
echo "🧪 Running tests with coverage..."
swift test --skip-build --enable-code-coverage --parallel

# Find the coverage data
COVERAGE_DIR=".build/debug/codecov"
PROFDATA=$(find .build -name 'default.profdata' | head -n 1)

if [ -z "$PROFDATA" ]; then
    echo "❌ No coverage data found"
    exit 1
fi

echo ""
echo "📈 Coverage by Module:"
echo "-------------------"

# Get executable path
EXECUTABLE=$(swift build --show-bin-path)/ClarityPulsePackageTests.xctest/Contents/MacOS/ClarityPulsePackageTests

# Extract coverage for each module
for MODULE in ClarityCore ClarityDomain ClarityData ClarityUI; do
    if xcrun llvm-cov report "$EXECUTABLE" -instr-profile="$PROFDATA" -ignore-filename-regex=".*Tests.*|.*Mocks.*" 2>/dev/null | grep -q "$MODULE"; then
        COVERAGE=$(xcrun llvm-cov report "$EXECUTABLE" -instr-profile="$PROFDATA" -ignore-filename-regex=".*Tests.*|.*Mocks.*" 2>/dev/null | grep "$MODULE" | awk '{print $(NF-2)}')
        
        # Extract percentage
        PERCENT=$(echo "$COVERAGE" | sed 's/%//')
        
        # Color based on target from .test-config.json
        case $MODULE in
            ClarityCore)
                TARGET=85
                ;;
            ClarityDomain)
                TARGET=90
                ;;
            ClarityData)
                TARGET=80
                ;;
            ClarityUI)
                TARGET=75
                ;;
        esac
        
        if (( $(echo "$PERCENT >= $TARGET" | bc -l) )); then
            echo -e "$MODULE: ${GREEN}${COVERAGE}${NC} (target: ${TARGET}%)"
        else
            echo -e "$MODULE: ${RED}${COVERAGE}${NC} (target: ${TARGET}%)"
        fi
    else
        echo -e "$MODULE: ${RED}No coverage data${NC}"
    fi
done

echo ""

# Overall summary
echo "📊 Overall Coverage:"
echo "-----------------"
xcrun llvm-cov report "$EXECUTABLE" -instr-profile="$PROFDATA" -ignore-filename-regex=".*Tests.*|.*Mocks.*" 2>/dev/null | tail -n 3

# Generate HTML report
echo ""
echo "📄 Generating HTML report..."
xcrun llvm-cov show "$EXECUTABLE" -instr-profile="$PROFDATA" -format=html -output-dir=.build/coverage-report -ignore-filename-regex=".*Tests.*|.*Mocks.*"

echo ""
echo "✅ Coverage report generated at: .build/coverage-report/index.html"
echo ""

# Check if we meet minimum coverage
TOTAL_COVERAGE=$(xcrun llvm-cov report "$EXECUTABLE" -instr-profile="$PROFDATA" -ignore-filename-regex=".*Tests.*|.*Mocks.*" 2>/dev/null | tail -n 1 | awk '{print $(NF-2)}' | sed 's/%//')

if (( $(echo "$TOTAL_COVERAGE >= 80" | bc -l) )); then
    echo -e "✅ ${GREEN}Coverage meets minimum requirement of 80%${NC}"
    exit 0
else
    echo -e "❌ ${RED}Coverage ($TOTAL_COVERAGE%) is below minimum requirement of 80%${NC}"
    exit 1
fi