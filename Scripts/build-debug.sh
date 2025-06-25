#!/bin/bash
# Build script for debug configuration
# Usage: ./scripts/build-debug.sh

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🔨 Building CLARITY Pulse (Debug)...${NC}"

# Configuration
PROJECT="clarity-loop-frontend-v2.xcodeproj"
SCHEME="clarity-loop-frontend-v2"
CONFIGURATION="Debug"
DESTINATION="platform=iOS Simulator,name=iPhone 16,OS=latest"

# Check if project exists
if [ ! -d "$PROJECT" ]; then
    echo -e "${RED}❌ Error: Project file not found: $PROJECT${NC}"
    echo -e "${YELLOW}Make sure you're running this script from the project root directory${NC}"
    exit 1
fi

# Clean build folder
echo -e "${YELLOW}🧹 Cleaning build folder...${NC}"
rm -rf build/

# Build
echo -e "${GREEN}🏗️  Starting build...${NC}"
xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    -derivedDataPath ./build \
    -skipMacroValidation \
    build | xcpretty

# Check if build succeeded
if [ ${PIPESTATUS[0]} -eq 0 ]; then
    echo -e "${GREEN}✅ Build succeeded!${NC}"
    echo -e "${GREEN}📱 App location: ./build/Build/Products/Debug-iphonesimulator/${SCHEME}.app${NC}"
else
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi