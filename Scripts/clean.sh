#!/bin/bash
# Clean script to remove all build artifacts
# Usage: ./scripts/clean.sh

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}🧹 Cleaning CLARITY Pulse project...${NC}"

# Configuration
PROJECT="clarity-loop-frontend-v2.xcodeproj"
SCHEME="clarity-loop-frontend-v2"

# Clean Xcode build
if [ -d "$PROJECT" ]; then
    echo -e "${GREEN}🏗️  Cleaning Xcode build...${NC}"
    xcodebuild clean \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -quiet || true
fi

# Remove build directories
echo -e "${GREEN}📁 Removing build directories...${NC}"
rm -rf build/
rm -rf DerivedData/
rm -rf TestResults/
rm -rf *.xcresult

# Remove user-specific Xcode files
echo -e "${GREEN}🗑️  Removing user-specific files...${NC}"
rm -rf "$PROJECT/xcuserdata"
rm -rf "$PROJECT/project.xcworkspace/xcuserdata"

# Clean SPM cache (optional - uncomment if needed)
# echo -e "${GREEN}📦 Cleaning Swift Package Manager cache...${NC}"
# rm -rf ~/Library/Caches/org.swift.swiftpm
# rm -rf .build/

# Clean derived data for this project
echo -e "${GREEN}🗄️  Cleaning derived data...${NC}"
DERIVED_DATA_PATH=~/Library/Developer/Xcode/DerivedData
if [ -d "$DERIVED_DATA_PATH" ]; then
    find "$DERIVED_DATA_PATH" -name "clarity-loop-frontend-v2-*" -type d -exec rm -rf {} + 2>/dev/null || true
fi

# Remove old build logs
echo -e "${GREEN}📝 Removing old build logs...${NC}"
rm -f *.log
rm -f "xcodemake -project"*

echo -e "${GREEN}✅ Clean complete!${NC}"