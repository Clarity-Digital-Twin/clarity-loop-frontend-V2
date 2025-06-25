# CLARITY Pulse V2 - Comprehensive Build System
# Usage: make [command]

# Configuration
PROJECT_NAME = clarity-loop-frontend-v2
WORKSPACE = $(PROJECT_NAME).xcworkspace
PROJECT = $(PROJECT_NAME).xcodeproj
SCHEME = $(PROJECT_NAME)
TEST_SCHEME = $(PROJECT_NAME)Tests
UI_TEST_SCHEME = $(PROJECT_NAME)UITests

# Simulator Configuration
SIMULATOR_NAME = iPhone 16
SIMULATOR_OS = latest
DESTINATION = "platform=iOS Simulator,name=$(SIMULATOR_NAME),OS=$(SIMULATOR_OS)"

# Build Configuration
CONFIGURATION_DEBUG = Debug
CONFIGURATION_RELEASE = Release

# Paths
BUILD_DIR = build
DERIVED_DATA = $(BUILD_DIR)/DerivedData
COVERAGE_DIR = $(BUILD_DIR)/coverage
DOCS_DIR = docs
SCRIPTS_DIR = Scripts

# Colors for output
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[1;33m
BLUE = \033[0;34m
NC = \033[0m # No Color

# Default target
.DEFAULT_GOAL := help

# MARK: - Help

.PHONY: help
help: ## Show this help message
	@echo "$(BLUE)CLARITY Pulse V2 - Build System$(NC)"
	@echo "Usage: make [command]"
	@echo ""
	@echo "$(YELLOW)Common Commands:$(NC)"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-20s$(NC) %s\n", $$1, $$2}'

# MARK: - Setup

.PHONY: setup
setup: ## Initial project setup
	@echo "$(BLUE)Setting up CLARITY Pulse V2...$(NC)"
	@./$(SCRIPTS_DIR)/setup.sh
	@echo "$(GREEN)✓ Setup complete$(NC)"

.PHONY: install-tools
install-tools: ## Install required development tools
	@echo "$(BLUE)Installing development tools...$(NC)"
	@which mint || brew install mint
	@mint bootstrap
	@which taskmaster || npm install -g @taskmaster-ai/cli
	@echo "$(GREEN)✓ Tools installed$(NC)"

# MARK: - Taskmaster Integration

.PHONY: task-init
task-init: ## Initialize Taskmaster for the project
	@echo "$(BLUE)Initializing Taskmaster...$(NC)"
	@taskmaster init --project-root .

.PHONY: task-next
task-next: ## Get next task to work on
	@taskmaster next-task

.PHONY: task-list
task-list: ## List all pending tasks
	@taskmaster list --status pending

.PHONY: task-expand
task-expand: ## Expand task with TDD subtasks (usage: make task-expand ID=15)
	@taskmaster expand-task $(ID) --prompt "Create TDD subtasks for this feature"

# MARK: - Building

.PHONY: clean
clean: ## Clean all build artifacts
	@echo "$(BLUE)Cleaning build artifacts...$(NC)"
	@./$(SCRIPTS_DIR)/clean.sh
	@echo "$(GREEN)✓ Clean complete$(NC)"

.PHONY: build
build: ## Build for Debug (simulator)
	@echo "$(BLUE)Building $(PROJECT_NAME) (Debug)...$(NC)"
	@./$(SCRIPTS_DIR)/build-debug.sh
	@echo "$(GREEN)✓ Build complete$(NC)"

.PHONY: build-release
build-release: ## Build for Release (simulator)
	@echo "$(BLUE)Building $(PROJECT_NAME) (Release)...$(NC)"
	@./$(SCRIPTS_DIR)/build-release.sh
	@echo "$(GREEN)✓ Release build complete$(NC)"

.PHONY: build-device
build-device: ## Build for physical device
	@echo "$(BLUE)Building for device...$(NC)"
	@xcodebuild build \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION_DEBUG) \
		-destination generic/platform=iOS \
		-derivedDataPath $(DERIVED_DATA) \
		| xcpretty
	@echo "$(GREEN)✓ Device build complete$(NC)"

# MARK: - Testing

.PHONY: test
test: ## Run all tests
	@echo "$(BLUE)Running all tests...$(NC)"
	@./$(SCRIPTS_DIR)/run-tests.sh all
	@echo "$(GREEN)✓ Tests complete$(NC)"

.PHONY: test-unit
test-unit: ## Run unit tests only
	@echo "$(BLUE)Running unit tests...$(NC)"
	@./$(SCRIPTS_DIR)/run-tests.sh unit
	@echo "$(GREEN)✓ Unit tests complete$(NC)"

.PHONY: test-ui
test-ui: ## Run UI tests only
	@echo "$(BLUE)Running UI tests...$(NC)"
	@./$(SCRIPTS_DIR)/run-tests.sh ui
	@echo "$(GREEN)✓ UI tests complete$(NC)"

.PHONY: test-tdd
test-tdd: ## Run tests in TDD watch mode
	@echo "$(BLUE)Starting TDD watch mode...$(NC)"
	@echo "$(YELLOW)Watching for changes... (Ctrl+C to stop)$(NC)"
	@while true; do \
		fswatch -o Sources Tests | xargs -n1 -I{} make test-unit; \
	done

.PHONY: coverage
coverage: test ## Generate test coverage report
	@echo "$(BLUE)Generating coverage report...$(NC)"
	@mkdir -p $(COVERAGE_DIR)
	@xcrun xccov view --report $(DERIVED_DATA)/Logs/Test/*.xcresult > $(COVERAGE_DIR)/coverage.txt
	@echo "$(GREEN)✓ Coverage report: $(COVERAGE_DIR)/coverage.txt$(NC)"

# MARK: - Running

.PHONY: run
run: build ## Build and run in simulator
	@echo "$(BLUE)Installing and running...$(NC)"
	@xcrun simctl boot "$(SIMULATOR_NAME)" 2>/dev/null || true
	@open -a Simulator
	@xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/$(SCHEME).app
	@xcrun simctl launch booted com.clarity.pulse
	@echo "$(GREEN)✓ App launched$(NC)"

.PHONY: stop
stop: ## Stop running app in simulator
	@echo "$(BLUE)Stopping app...$(NC)"
	@xcrun simctl terminate booted com.clarity.pulse || true
	@echo "$(GREEN)✓ App stopped$(NC)"

# MARK: - Code Quality

.PHONY: lint
lint: ## Run SwiftLint
	@echo "$(BLUE)Running SwiftLint...$(NC)"
	@if command -v swiftlint >/dev/null 2>&1; then \
		swiftlint; \
	else \
		echo "$(YELLOW)⚠️  SwiftLint not installed. Install with: brew install swiftlint$(NC)"; \
	fi

.PHONY: format
format: ## Format code with SwiftFormat
	@echo "$(BLUE)Formatting code...$(NC)"
	@if command -v swiftformat >/dev/null 2>&1; then \
		swiftformat . --swiftversion 5.9; \
	else \
		echo "$(YELLOW)⚠️  SwiftFormat not installed. Install with: brew install swiftformat$(NC)"; \
	fi

.PHONY: analyze
analyze: ## Run static analysis
	@echo "$(BLUE)Running static analysis...$(NC)"
	@xcodebuild analyze \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION_DEBUG) \
		-destination $(DESTINATION) \
		| xcpretty
	@echo "$(GREEN)✓ Analysis complete$(NC)"

# MARK: - Documentation

.PHONY: docs
docs: ## Generate documentation
	@echo "$(BLUE)Generating documentation...$(NC)"
	@if command -v swift-doc >/dev/null 2>&1; then \
		swift-doc generate Sources \
			--module-name $(PROJECT_NAME) \
			--output $(DOCS_DIR)/api \
			--format html; \
		echo "$(GREEN)✓ Documentation generated: $(DOCS_DIR)/api$(NC)"; \
	else \
		echo "$(YELLOW)⚠️  swift-doc not installed. Install with: brew install swift-doc$(NC)"; \
	fi

.PHONY: readme-check
readme-check: ## Verify all documentation is up to date
	@echo "$(BLUE)Checking documentation...$(NC)"
	@grep -r "TODO" *.md || echo "$(GREEN)✓ No TODOs in documentation$(NC)"
	@grep -r "FIXME" *.md || echo "$(GREEN)✓ No FIXMEs in documentation$(NC)"

# MARK: - Git Hooks

.PHONY: install-hooks
install-hooks: ## Install Git hooks
	@echo "$(BLUE)Installing Git hooks...$(NC)"
	@if [ -f Scripts/pre-commit ]; then \
		cp Scripts/pre-commit .git/hooks/pre-commit; \
		chmod +x .git/hooks/pre-commit; \
		echo "$(GREEN)✓ Git hooks installed$(NC)"; \
	else \
		echo "$(YELLOW)⚠️  No pre-commit script found$(NC)"; \
	fi

.PHONY: pre-commit
pre-commit: lint test-unit ## Run pre-commit checks

# MARK: - Utilities

.PHONY: simulator-list
simulator-list: ## List available simulators
	@echo "$(BLUE)Available simulators:$(NC)"
	@xcrun simctl list devices available

.PHONY: simulator-reset
simulator-reset: ## Reset simulator content
	@echo "$(YELLOW)Resetting simulator...$(NC)"
	@xcrun simctl shutdown all
	@xcrun simctl erase all
	@echo "$(GREEN)✓ Simulators reset$(NC)"

.PHONY: check-deps
check-deps: ## Check dependencies
	@echo "$(BLUE)Checking dependencies...$(NC)"
	@command -v xcodebuild >/dev/null 2>&1 || { echo "$(RED)❌ xcodebuild not found$(NC)"; exit 1; }
	@command -v xcpretty >/dev/null 2>&1 || echo "$(YELLOW)⚠️  xcpretty not found (optional)$(NC)"
	@command -v swiftlint >/dev/null 2>&1 || echo "$(YELLOW)⚠️  swiftlint not found (optional)$(NC)"
	@command -v taskmaster >/dev/null 2>&1 || echo "$(YELLOW)⚠️  taskmaster not found (recommended)$(NC)"
	@echo "$(GREEN)✓ Essential dependencies found$(NC)"

.PHONY: size
size: ## Show app size
	@echo "$(BLUE)Calculating app size...$(NC)"
	@find $(BUILD_DIR) -name '*.app' -exec du -sh {} \; 2>/dev/null || echo "Build first with 'make build'"

# MARK: - CI/CD

.PHONY: ci-test
ci-test: ## Run tests for CI
	@xcodebuild test \
		-project $(PROJECT) \
		-scheme $(TEST_SCHEME) \
		-destination $(DESTINATION) \
		-enableCodeCoverage YES \
		-resultBundlePath $(BUILD_DIR)/test-results \
		CODE_SIGN_IDENTITY="" \
		CODE_SIGNING_REQUIRED=NO

.PHONY: archive
archive: ## Create release archive
	@echo "$(BLUE)Creating archive...$(NC)"
	@xcodebuild archive \
		-project $(PROJECT) \
		-scheme $(SCHEME) \
		-configuration $(CONFIGURATION_RELEASE) \
		-archivePath $(BUILD_DIR)/ClarityPulse.xcarchive
	@echo "$(GREEN)✓ Archive created: $(BUILD_DIR)/ClarityPulse.xcarchive$(NC)"

# MARK: - SwiftData Migration

.PHONY: migrate-check
migrate-check: ## Check SwiftData migration status
	@echo "$(BLUE)Checking SwiftData migrations...$(NC)"
	@echo "$(YELLOW)TODO: Implement migration check$(NC)"

.PHONY: migrate-generate
migrate-generate: ## Generate new SwiftData migration
	@echo "$(BLUE)Generating migration...$(NC)"
	@echo "$(YELLOW)TODO: Implement migration generation$(NC)"

# MARK: - TDD Workflow

.PHONY: tdd-start
tdd-start: ## Start TDD session for a feature (usage: make tdd-start FEATURE=authentication)
	@echo "$(BLUE)Starting TDD for $(FEATURE)...$(NC)"
	@taskmaster add-task --prompt "TDD: Implement $(FEATURE)" || echo "Install taskmaster: npm install -g @taskmaster-ai/cli"
	@echo "$(YELLOW)1. Write failing test$(NC)"
	@echo "$(YELLOW)2. Run 'make test' to see it fail$(NC)"
	@echo "$(YELLOW)3. Write minimal code to pass$(NC)"
	@echo "$(YELLOW)4. Run 'make test' to see it pass$(NC)"
	@echo "$(YELLOW)5. Refactor if needed$(NC)"

.PHONY: tdd-new-test
tdd-new-test: ## Create new test file (usage: make tdd-new-test NAME=LoginViewModel)
	@echo "$(BLUE)Creating test for $(NAME)...$(NC)"
	@mkdir -p $(TEST_SCHEME)
	@echo "import XCTest\n@testable import $(PROJECT_NAME)\n\nfinal class $(NAME)Tests: XCTestCase {\n    func test_whenInitialized_shouldHaveExpectedState() {\n        // Given\n        let sut = $(NAME)()\n        \n        // Then\n        XCTFail(\"Write your first assertion\")\n    }\n}" > $(TEST_SCHEME)/$(NAME)Tests.swift
	@echo "$(GREEN)✓ Created $(TEST_SCHEME)/$(NAME)Tests.swift$(NC)"
	@echo "$(YELLOW)Now write your first failing test!$(NC)"

# MARK: - Backend Integration

.PHONY: backend-test
backend-test: ## Test backend endpoints
	@echo "$(BLUE)Testing backend endpoints...$(NC)"
	@./$(SCRIPTS_DIR)/test_backend_endpoints.sh

.PHONY: backend-validate
backend-validate: ## Validate backend contract
	@echo "$(BLUE)Validating backend contract...$(NC)"
	@swift $(SCRIPTS_DIR)/validate_backend_contract.swift

# MARK: - Quick Commands

.PHONY: q
q: quick-test ## Quick test (alias)

.PHONY: quick-test
quick-test: ## Run last modified test file
	@echo "$(BLUE)Running last modified test...$(NC)"
	@LAST_TEST=$$(find $(TEST_SCHEME) -name "*.swift" -exec ls -t {} + | head -1); \
	if [ -n "$$LAST_TEST" ]; then \
		xcodebuild test \
			-project $(PROJECT) \
			-scheme $(TEST_SCHEME) \
			-only-testing:$(TEST_SCHEME)/$$(basename $$LAST_TEST .swift) \
			-destination $(DESTINATION) \
			| xcpretty; \
	else \
		echo "$(RED)No test files found$(NC)"; \
	fi

.PHONY: reset
reset: clean simulator-reset ## Full reset (clean + simulator reset)
	@echo "$(GREEN)✓ Full reset complete$(NC)"

# MARK: - Debug

.PHONY: debug-env
debug-env: ## Show build environment
	@echo "$(BLUE)Build Environment:$(NC)"
	@echo "PROJECT_NAME: $(PROJECT_NAME)"
	@echo "PROJECT: $(PROJECT)"
	@echo "SCHEME: $(SCHEME)"
	@echo "SIMULATOR_NAME: $(SIMULATOR_NAME)"
	@echo "DESTINATION: $(DESTINATION)"
	@echo ""
	@echo "$(BLUE)Xcode Version:$(NC)"
	@xcodebuild -version
	@echo ""
	@echo "$(BLUE)Swift Version:$(NC)"
	@swift --version

# Keep build directory
.PRECIOUS: $(BUILD_DIR)/

# Create build directory if needed
$(BUILD_DIR)/:
	@mkdir -p $(BUILD_DIR)