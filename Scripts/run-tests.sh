#!/bin/bash
# Test runner script
# Usage: ./scripts/run-tests.sh [unit|ui|all]

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default to running all tests
TEST_TYPE=${1:-all}

# Configuration
PROJECT="clarity-loop-frontend-v2.xcodeproj"
DESTINATION="platform=iOS Simulator,name=iPhone 16,OS=latest"

# Check if project exists
if [ ! -d "$PROJECT" ]; then
    echo -e "${RED}❌ Error: Project file not found: $PROJECT${NC}"
    echo -e "${YELLOW}Make sure you're running this script from the project root directory${NC}"
    exit 1
fi

# Function to run unit tests
run_unit_tests() {
    echo -e "${BLUE}🧪 Running Unit Tests...${NC}"
    xcodebuild test \
        -project "$PROJECT" \
        -scheme "clarity-loop-frontend-v2Tests" \
        -destination "$DESTINATION" \
        -resultBundlePath "./TestResults/UnitTests.xcresult" \
        | xcpretty --test --color
    
    return ${PIPESTATUS[0]}
}

# Function to run UI tests
run_ui_tests() {
    echo -e "${BLUE}🖱️  Running UI Tests...${NC}"
    xcodebuild test \
        -project "$PROJECT" \
        -scheme "clarity-loop-frontend-v2UITests" \
        -destination "$DESTINATION" \
        -resultBundlePath "./TestResults/UITests.xcresult" \
        | xcpretty --test --color
    
    return ${PIPESTATUS[0]}
}

# Clean test results folder
echo -e "${YELLOW}🧹 Cleaning previous test results...${NC}"
rm -rf TestResults/
mkdir -p TestResults/

# Run tests based on type
case $TEST_TYPE in
    unit)
        run_unit_tests
        RESULT=$?
        ;;
    ui)
        run_ui_tests
        RESULT=$?
        ;;
    all)
        echo -e "${GREEN}🏃 Running all tests...${NC}"
        run_unit_tests
        UNIT_RESULT=$?
        
        run_ui_tests
        UI_RESULT=$?
        
        if [ $UNIT_RESULT -eq 0 ] && [ $UI_RESULT -eq 0 ]; then
            RESULT=0
        else
            RESULT=1
        fi
        ;;
    *)
        echo -e "${RED}❌ Invalid test type: $TEST_TYPE${NC}"
        echo -e "${YELLOW}Usage: $0 [unit|ui|all]${NC}"
        exit 1
        ;;
esac

# Report results
if [ $RESULT -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    echo -e "${GREEN}📊 Test results saved in: ./TestResults/${NC}"
else
    echo -e "${RED}❌ Some tests failed!${NC}"
    echo -e "${YELLOW}Check the test results in: ./TestResults/${NC}"
    exit 1
fi