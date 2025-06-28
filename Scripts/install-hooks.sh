#!/bin/bash

# Script to install git hooks for the project

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "🔧 Installing git hooks..."

# Get the root directory of the git repository
GIT_ROOT=$(git rev-parse --show-toplevel)
HOOKS_DIR="$GIT_ROOT/.git/hooks"
SCRIPTS_DIR="$GIT_ROOT/Scripts"

# Create hooks directory if it doesn't exist
mkdir -p "$HOOKS_DIR"

# Install pre-commit hook
if [ -f "$SCRIPTS_DIR/pre-commit-format.sh" ]; then
    ln -sf "$SCRIPTS_DIR/pre-commit-format.sh" "$HOOKS_DIR/pre-commit"
    echo -e "${GREEN}✅ Pre-commit hook installed${NC}"
else
    echo -e "${YELLOW}⚠️  Pre-commit script not found at $SCRIPTS_DIR/pre-commit-format.sh${NC}"
fi

echo ""
echo "Git hooks installation complete!"
echo ""
echo "The pre-commit hook will:"
echo "  - Run SwiftLint on staged Swift files"
echo "  - Prevent commits if there are lint violations"
echo "  - Suggest running 'swiftlint --fix' for auto-fixable issues"