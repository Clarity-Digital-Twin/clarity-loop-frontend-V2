#!/bin/bash

# Pre-commit hook script for SwiftLint
# This script runs SwiftLint and fails if there are any violations

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🧹 Running SwiftLint pre-commit checks..."

# Check if SwiftLint is installed
if ! which swiftlint >/dev/null; then
    echo -e "${RED}❌ Error: SwiftLint is not installed${NC}"
    echo "Install it using: brew install swiftlint"
    exit 1
fi

# Get the root directory of the git repository
GIT_ROOT=$(git rev-parse --show-toplevel)
cd "$GIT_ROOT"

# Run SwiftLint on staged Swift files only
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM | grep "\.swift$")

if [ -z "$STAGED_FILES" ]; then
    echo -e "${GREEN}✅ No Swift files to lint${NC}"
    exit 0
fi

# Create a temporary file to store results
RESULT_FILE=$(mktemp)

# Run SwiftLint on staged files
echo "$STAGED_FILES" | while read file; do
    if [ -f "$file" ]; then
        swiftlint lint --quiet "$file" >> "$RESULT_FILE" 2>&1
    fi
done

# Check if there were any violations
if [ -s "$RESULT_FILE" ]; then
    echo -e "${RED}❌ SwiftLint found violations:${NC}"
    cat "$RESULT_FILE"
    rm "$RESULT_FILE"
    
    echo ""
    echo -e "${YELLOW}💡 Tip: Run 'swiftlint --fix' to automatically fix some violations${NC}"
    echo -e "${YELLOW}   Then stage the fixed files and try committing again${NC}"
    
    exit 1
else
    echo -e "${GREEN}✅ SwiftLint checks passed!${NC}"
    rm "$RESULT_FILE"
    exit 0
fi