#!/bin/bash

# CLARITY V2 - VS Code Setup Script
# This script sets up VS Code for optimal SwiftUI/SwiftData development

set -e

echo "🚀 Setting up VS Code for CLARITY V2 development..."

# Check if VS Code CLI is available
if ! command -v code &> /dev/null; then
    echo "⚠️  VS Code CLI not found. Please install VS Code and add 'code' to PATH."
    echo "   Instructions: https://code.visualstudio.com/docs/setup/mac#_launching-from-the-command-line"
    exit 1
fi

echo "📦 Installing VS Code extensions..."

# Swift language support
code --install-extension sswg.swift-lang || true

# Debugging support
code --install-extension vadimcn.vscode-lldb || true

# SwiftFormat integration
code --install-extension vknabel.vscode-swiftformat || true

# SwiftLint integration  
code --install-extension vknabel.vscode-swiftlint || true

# GitHub Copilot (optional but recommended for AI assistance)
echo "💡 Optional: Install GitHub Copilot for AI assistance?"
echo "   Run: code --install-extension GitHub.copilot"

# Create recommended extensions file
mkdir -p .vscode
cat > .vscode/extensions.json << 'EOF'
{
    "recommendations": [
        "sswg.swift-lang",
        "vadimcn.vscode-lldb",
        "vknabel.vscode-swiftformat",
        "vknabel.vscode-swiftlint",
        "GitHub.copilot",
        "eamodio.gitlens",
        "streetsidesoftware.code-spell-checker"
    ]
}
EOF

echo "✅ VS Code extensions configured!"

# Check for required tools
echo ""
echo "🔍 Checking required tools..."

# Check Swift
if command -v swift &> /dev/null; then
    SWIFT_VERSION=$(swift --version | head -1)
    echo "✅ Swift installed: $SWIFT_VERSION"
else
    echo "❌ Swift not found. Please install Xcode."
fi

# Check SwiftLint
if command -v swiftlint &> /dev/null; then
    echo "✅ SwiftLint installed: $(swiftlint version)"
else
    echo "⚠️  SwiftLint not installed. Install with: brew install swiftlint"
fi

# Check SwiftFormat
if command -v swiftformat &> /dev/null; then
    echo "✅ SwiftFormat installed: $(swiftformat --version)"
else
    echo "⚠️  SwiftFormat not installed. Install with: brew install swiftformat"
fi

# Check xcodebuild
if command -v xcodebuild &> /dev/null; then
    echo "✅ Xcode Command Line Tools installed"
else
    echo "❌ Xcode Command Line Tools not found. Install with: xcode-select --install"
fi

echo ""
echo "🎉 VS Code setup complete!"
echo ""
echo "📝 Next steps:"
echo "1. Open VS Code: code ."
echo "2. Install recommended extensions when prompted"
echo "3. Use Command Palette (Cmd+Shift+P) for Swift commands"
echo "4. Run tests with: Cmd+Shift+P > Tasks: Run Test Task"
echo "5. Format code with: Cmd+Shift+P > Format Document"
echo ""
echo "🚦 TDD Workflow in VS Code:"
echo "1. Create test file: Cmd+N, save as *Tests.swift"
echo "2. Write failing test"
echo "3. Run test: Cmd+Shift+P > Tasks: Run Test Task"
echo "4. Implement minimal code to pass"
echo "5. Run test again to verify"
echo "6. Refactor with confidence"