#!/bin/bash
# Setup script for new developers
# Usage: ./scripts/setup.sh

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Setting up CLARITY Pulse development environment...${NC}"

# Check for Xcode
echo -e "${GREEN}📱 Checking Xcode installation...${NC}"
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}❌ Xcode is not installed!${NC}"
    echo -e "${YELLOW}Please install Xcode from the Mac App Store${NC}"
    exit 1
fi

XCODE_VERSION=$(xcodebuild -version | head -n 1)
echo -e "${GREEN}✅ $XCODE_VERSION${NC}"

# Check for Xcode command line tools
echo -e "${GREEN}🔧 Checking Xcode Command Line Tools...${NC}"
if ! xcode-select -p &> /dev/null; then
    echo -e "${YELLOW}Installing Xcode Command Line Tools...${NC}"
    xcode-select --install
    echo -e "${YELLOW}Please complete the installation and run this script again${NC}"
    exit 1
fi

# Check for xcpretty (optional but recommended)
echo -e "${GREEN}🎨 Checking for xcpretty...${NC}"
if ! command -v xcpretty &> /dev/null; then
    echo -e "${YELLOW}xcpretty not found. Installing...${NC}"
    if command -v gem &> /dev/null; then
        sudo gem install xcpretty
    else
        echo -e "${YELLOW}⚠️  xcpretty not installed (improves build output readability)${NC}"
        echo -e "${YELLOW}Install with: sudo gem install xcpretty${NC}"
    fi
else
    echo -e "${GREEN}✅ xcpretty installed${NC}"
fi

# Make scripts executable
echo -e "${GREEN}🔐 Making scripts executable...${NC}"
chmod +x scripts/*.sh

# Check for AWS Amplify CLI
echo -e "${GREEN}☁️  Checking AWS Amplify CLI...${NC}"
if ! command -v amplify &> /dev/null; then
    echo -e "${YELLOW}⚠️  AWS Amplify CLI not found${NC}"
    echo -e "${YELLOW}Install with: npm install -g @aws-amplify/cli${NC}"
else
    AMPLIFY_VERSION=$(amplify --version)
    echo -e "${GREEN}✅ Amplify CLI $AMPLIFY_VERSION${NC}"
fi

# Check for SwiftLint (optional)
echo -e "${GREEN}🧹 Checking SwiftLint...${NC}"
if ! command -v swiftlint &> /dev/null; then
    echo -e "${YELLOW}⚠️  SwiftLint not found (code style checker)${NC}"
    echo -e "${YELLOW}Install with: brew install swiftlint${NC}"
else
    echo -e "${GREEN}✅ SwiftLint installed${NC}"
fi

# Create necessary directories
echo -e "${GREEN}📁 Creating project directories...${NC}"
mkdir -p TestResults
mkdir -p build
mkdir -p docs

# Check for required files
echo -e "${GREEN}📄 Checking required configuration files...${NC}"
REQUIRED_FILES=(
    "amplifyconfiguration.json"
    "awsconfiguration.json"
    "Info.plist"
)

MISSING_FILES=()
for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "clarity-loop-frontend-v2/$file" ]; then
        MISSING_FILES+=("$file")
    fi
done

if [ ${#MISSING_FILES[@]} -ne 0 ]; then
    echo -e "${YELLOW}⚠️  Missing configuration files:${NC}"
    printf '%s\n' "${MISSING_FILES[@]}"
    echo -e "${YELLOW}These may be generated during the build process${NC}"
fi

# Git hooks setup (optional)
if [ -d ".git" ]; then
    echo -e "${GREEN}🪝 Setting up Git hooks...${NC}"
    # Create pre-commit hook for tests
    cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
# Run unit tests before commit
echo "Running unit tests..."
./scripts/run-tests.sh unit
EOF
    chmod +x .git/hooks/pre-commit
    echo -e "${GREEN}✅ Git hooks configured${NC}"
fi

# Summary
echo -e "${GREEN}✨ Setup complete!${NC}"
echo ""
echo -e "${BLUE}Available commands:${NC}"
echo -e "  ${GREEN}./scripts/build-debug.sh${NC}    - Build debug version"
echo -e "  ${GREEN}./scripts/build-release.sh${NC}  - Build release version"
echo -e "  ${GREEN}./scripts/run-tests.sh${NC}      - Run tests"
echo -e "  ${GREEN}./scripts/clean.sh${NC}          - Clean build artifacts"
echo ""
echo -e "${YELLOW}⚠️  HUMAN INTERVENTION REQUIRED:${NC}"
echo -e "1. Open the project in Xcode"
echo -e "2. Select your development team in Signing & Capabilities"
echo -e "3. Ensure all Swift packages are resolved"
echo -e "4. Build once in Xcode to generate any missing files"