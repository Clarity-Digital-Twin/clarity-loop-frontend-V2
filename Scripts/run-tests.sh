#!/bin/bash
# Test runner script
# Usage: ./scripts/run-tests.sh [unit|integration|ui|all|fast]

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default to running all tests
TEST_TYPE=${1:-all}

# Kill any zombie Swift processes before starting
echo -e "${YELLOW}🧹 Cleaning up any stuck processes...${NC}"
pkill -f swift-frontend 2>/dev/null || true
pkill -f swift-driver 2>/dev/null || true
pkill -f swift-test 2>/dev/null || true

# Check if Package.swift exists
if [ ! -f "Package.swift" ]; then
    echo -e "${RED}❌ Error: Package.swift not found${NC}"
    echo -e "${YELLOW}Make sure you're running this script from the project root directory${NC}"
    exit 1
fi

# Build once to cache dependencies
build_project() {
    echo -e "${BLUE}🔨 Building project...${NC}"
    swift build --configuration debug
}

# Function to run unit tests
run_unit_tests() {
    echo -e "${BLUE}🧪 Running Unit Tests...${NC}"
    swift test \
        --skip-build \
        --parallel \
        --filter "ClarityDomainTests|ClarityDataTests|ClarityCoreTests"
    
    return $?
}

# Function to run integration tests
run_integration_tests() {
    echo -e "${BLUE}🔗 Running Integration Tests...${NC}"
    swift test \
        --skip-build \
        --parallel \
        --filter "ClarityIntegrationTests"
    
    return $?
}

# Function to run UI tests
run_ui_tests() {
    echo -e "${BLUE}🖱️  Running UI Tests...${NC}"
    swift test \
        --skip-build \
        --parallel \
        --filter "ClarityUITests"
    
    return $?
}

# Function to run fast tests (domain and core only)
run_fast_tests() {
    echo -e "${BLUE}⚡ Running Fast Tests...${NC}"
    swift test \
        --skip-build \
        --parallel \
        --filter "ClarityDomainTests|ClarityCoreTests"
    
    return $?
}

# Clean test results folder
echo -e "${YELLOW}📁 Creating test results directory...${NC}"
mkdir -p .build/test-results

# Build the project first
build_project

# Run tests based on type
case $TEST_TYPE in
    unit)
        run_unit_tests
        RESULT=$?
        ;;
    integration)
        run_integration_tests
        RESULT=$?
        ;;
    ui)
        run_ui_tests
        RESULT=$?
        ;;
    fast)
        run_fast_tests
        RESULT=$?
        ;;
    all)
        echo -e "${GREEN}🏃 Running all tests...${NC}"
        run_unit_tests
        UNIT_RESULT=$?
        
        run_integration_tests
        INT_RESULT=$?
        
        run_ui_tests
        UI_RESULT=$?
        
        if [ $UNIT_RESULT -eq 0 ] && [ $INT_RESULT -eq 0 ] && [ $UI_RESULT -eq 0 ]; then
            RESULT=0
        else
            RESULT=1
        fi
        ;;
    *)
        echo -e "${RED}❌ Invalid test type: $TEST_TYPE${NC}"
        echo -e "${YELLOW}Usage: $0 [unit|integration|ui|all|fast]${NC}"
        echo -e "${YELLOW}  unit        - Run unit tests only${NC}"
        echo -e "${YELLOW}  integration - Run integration tests only${NC}"
        echo -e "${YELLOW}  ui          - Run UI tests only${NC}"
        echo -e "${YELLOW}  all         - Run all test suites${NC}"
        echo -e "${YELLOW}  fast        - Run fast tests only (domain + core)${NC}"
        exit 1
        ;;
esac

# Report results
if [ $RESULT -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    echo -e "${GREEN}📊 Test results saved in: .build/test-results/${NC}"
else
    echo -e "${RED}❌ Some tests failed!${NC}"
    echo -e "${YELLOW}Check the test logs above for details${NC}"
    exit 1
fi