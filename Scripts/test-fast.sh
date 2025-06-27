#!/bin/bash
# Fast Test Script - Optimized for development workflow
# This script runs tests as quickly as possible by leveraging build caching

set -e

echo "⚡ Running Fast Tests..."
echo "======================"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Kill any zombie processes
print_status "$YELLOW" "🧹 Cleaning up any stuck processes..."
pkill -f swift-frontend 2>/dev/null || true
pkill -f swift-driver 2>/dev/null || true
pkill -f swift-test 2>/dev/null || true

# Check if we need to build
BUILD_MARKER=".build/last-successful-build"
NEEDS_BUILD=false

if [ ! -f "$BUILD_MARKER" ]; then
    NEEDS_BUILD=true
else
    # Check if any Swift files changed since last build
    LAST_BUILD_TIME=$(stat -f %m "$BUILD_MARKER" 2>/dev/null || echo 0)
    LATEST_SWIFT_FILE=$(find . -name "*.swift" -type f -newer "$BUILD_MARKER" 2>/dev/null | head -1)
    
    if [ -n "$LATEST_SWIFT_FILE" ]; then
        NEEDS_BUILD=true
    fi
fi

if [ "$NEEDS_BUILD" = true ]; then
    print_status "$YELLOW" "🔨 Building project (changes detected)..."
    swift build --configuration debug && touch "$BUILD_MARKER"
else
    print_status "$GREEN" "✓ Using cached build (no changes detected)"
fi

# Run only fast unit tests
print_status "$YELLOW" "🧪 Running fast unit tests..."
swift test \
    --skip-build \
    --parallel \
    --filter "ClarityDomainTests|ClarityCoreTests"

print_status "$GREEN" "✅ Fast tests completed!"