#!/bin/bash

# CLARITY Pre-commit Hook Setup Script
# Sets up git pre-commit hook to check test coverage

set -e

echo "📋 Setting up pre-commit hook for coverage checking..."

# Check if .git exists
if [ ! -d ".git" ]; then
    echo "❌ Error: Not a git repository. Run this from the project root."
    exit 1
fi

# Create hooks directory if it doesn't exist
mkdir -p .git/hooks

# Create pre-commit hook
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash

# CLARITY Pre-commit Hook
# Runs fast unit tests before allowing commit

echo "🧪 Running pre-commit tests..."

# Run fast tests
./Scripts/test-fast.sh

if [ $? -ne 0 ]; then
    echo "❌ Tests failed! Please fix tests before committing."
    exit 1
fi

echo "✅ All tests passed! Proceeding with commit..."
exit 0
EOF

# Make hook executable
chmod +x .git/hooks/pre-commit

echo "✅ Pre-commit hook installed successfully!"
echo ""
echo "The hook will:"
echo "  - Run fast unit tests before each commit"
echo "  - Block commits if tests fail"
echo ""
echo "To bypass the hook (not recommended), use: git commit --no-verify"