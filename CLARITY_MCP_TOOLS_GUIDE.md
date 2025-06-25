# CLARITY MCP Tools & Taskmaster CLI Guide

## Overview
This guide documents all MCP tools available for CLARITY development and emphasizes using Taskmaster CLI for comprehensive task management. These tools are essential for automated development, testing, and project management.

## 🎯 Taskmaster CLI (Primary Task Management)

### Why Taskmaster CLI Over MCP?
The Taskmaster CLI provides a more comprehensive and interactive experience than the MCP version. Use the CLI for all major task management operations.

### Initial Setup

```bash
# Install Taskmaster globally
npm install -g @taskmaster-ai/cli

# Initialize in project root
cd /Users/ray/Desktop/CLARITY-DIGITAL-TWIN/clarity-loop-frontend-v2
taskmaster init --project-root .
```

### Core Taskmaster Commands

#### Project Initialization
```bash
# Initialize with Git and aliases
taskmaster init --init-git --add-aliases

# Parse PRD into tasks
taskmaster parse-prd .taskmaster/docs/prd.txt --num-tasks 30 --research

# Import existing tasks
taskmaster import legacy-tasks.json
```

#### Task Management
```bash
# View all tasks
taskmaster list
taskmaster list --status pending
taskmaster list --status in-progress

# Get next task to work on
taskmaster next-task

# Get specific task details
taskmaster get-task 15
taskmaster get-task 15,16,17  # Multiple tasks

# Update task status
taskmaster set-task-status 15 in-progress
taskmaster set-task-status 15 done
```

#### Task Expansion with TDD Focus
```bash
# Expand task into TDD subtasks
taskmaster expand-task 15 --prompt "Create TDD subtasks for authentication feature"

# Expand with specific number of subtasks
taskmaster expand-task 15 --num 8 --prompt "Break down into testable units"

# Expand all pending tasks
taskmaster expand-all --prompt "Create TDD/BDD subtasks for each feature"
```

#### Research Integration
```bash
# Research with project context
taskmaster research "Best practices for SwiftUI health app accessibility" --detail-level high

# Research and save to task
taskmaster research "HealthKit background sync implementation" --save-to 15.3

# Research with file context
taskmaster research "How to implement this pattern" --file-paths "src/NetworkClient.swift,docs/api.md"
```

#### Complexity Analysis
```bash
# Analyze all tasks
taskmaster analyze-project-complexity

# Analyze specific tasks
taskmaster analyze-project-complexity --ids "15,16,17"

# Set complexity threshold
taskmaster analyze-project-complexity --threshold 7
```

### Advanced Taskmaster Workflows

#### TDD Workflow
```bash
# 1. Create feature task
taskmaster add-task --prompt "Implement user authentication with biometric support"

# 2. Expand into TDD subtasks
taskmaster expand-task <id> --prompt "Create TDD subtasks: test first, then implementation"

# 3. Work through tasks
taskmaster next-task
taskmaster set-task-status <id> in-progress

# 4. Update with findings
taskmaster update-task <id> --prompt "Tests revealed need for error recovery flow"
```

#### Dependency Management
```bash
# Add dependencies
taskmaster add-dependency --id 20 --depends-on 15

# Validate dependencies
taskmaster validate-dependencies

# Fix circular dependencies
taskmaster fix-dependencies
```

## 🔧 XcodeBuild MCP Tools

### Project Discovery
```swift
// Find all Xcode projects
mcp__XcodeBuildMCP__discover_projs({
    workspaceRoot: "/Users/ray/Desktop/CLARITY-DIGITAL-TWIN/clarity-loop-frontend-v2",
    maxDepth: 3
})
```

### Build Commands
```swift
// Build for simulator
mcp__XcodeBuildMCP__build_sim_name_ws({
    workspacePath: "clarity-loop-frontend-v2.xcworkspace",
    scheme: "clarity-loop-frontend-v2",
    simulatorName: "iPhone 16",
    configuration: "Debug"
})

// Build and run
mcp__XcodeBuildMCP__build_run_sim_name_ws({
    workspacePath: "clarity-loop-frontend-v2.xcworkspace",
    scheme: "clarity-loop-frontend-v2",
    simulatorName: "iPhone 16"
})
```

### Testing
```swift
// Run unit tests
mcp__XcodeBuildMCP__test_sim_name_ws({
    workspacePath: "clarity-loop-frontend-v2.xcworkspace",
    scheme: "clarity-loop-frontend-v2Tests",
    simulatorName: "iPhone 16"
})

// Run UI tests with specific simulator
mcp__XcodeBuildMCP__test_sim_id_ws({
    workspacePath: "clarity-loop-frontend-v2.xcworkspace",
    scheme: "clarity-loop-frontend-v2UITests",
    simulatorId: "DEVICE-UUID-HERE"
})
```

### UI Automation
```swift
// Get UI hierarchy
mcp__XcodeBuildMCP__describe_ui({
    simulatorUuid: "SIMULATOR-UUID"
})

// Perform UI actions
mcp__XcodeBuildMCP__tap({
    simulatorUuid: "UUID",
    x: 100,
    y: 200
})

// Type text
mcp__XcodeBuildMCP__type_text({
    simulatorUuid: "UUID",
    text: "test@example.com"
})

// Take screenshot
mcp__XcodeBuildMCP__screenshot({
    simulatorUuid: "UUID"
})
```

### Simulator Management
```swift
// List simulators
mcp__XcodeBuildMCP__list_sims({ enabled: true })

// Boot simulator
mcp__XcodeBuildMCP__boot_sim({
    simulatorUuid: "UUID"
})

// Install app
mcp__XcodeBuildMCP__install_app_sim({
    simulatorUuid: "UUID",
    appPath: "/path/to/MyApp.app"
})

// Launch app
mcp__XcodeBuildMCP__launch_app_sim({
    simulatorUuid: "UUID",
    bundleId: "com.clarity.pulse"
})
```

## 📂 Filesystem MCP Tools

### File Operations
```javascript
// Read file
mcp__Filesystem__read_file({
    path: "Sources/NetworkClient.swift"
})

// Read multiple files efficiently
mcp__Filesystem__read_multiple_files({
    paths: [
        "Sources/NetworkClient.swift",
        "Sources/AuthService.swift",
        "Tests/NetworkClientTests.swift"
    ]
})

// Write file
mcp__Filesystem__write_file({
    path: "Sources/NewFeature.swift",
    content: "// Implementation here"
})

// Edit file with diffs
mcp__Filesystem__edit_file({
    path: "Sources/ViewModel.swift",
    edits: [{
        oldText: "class ViewModel",
        newText: "@Observable\nfinal class ViewModel"
    }],
    dryRun: true  // Preview changes first
})
```

### Directory Operations
```javascript
// List directory
mcp__Filesystem__list_directory({
    path: "Sources"
})

// Get directory tree
mcp__Filesystem__directory_tree({
    path: "Sources"
})

// Search files
mcp__Filesystem__search_files({
    path: ".",
    pattern: "*ViewModel.swift",
    excludePatterns: ["*.generated.swift"]
})
```

## 🧠 Sequential Thinking Tool

For complex problem solving:

```javascript
mcp__sequential-thinking__sequentialthinking({
    thought: "Breaking down health data sync: 1) Check offline queue, 2) Validate data integrity, 3) Batch by priority, 4) Handle conflicts",
    nextThoughtNeeded: true,
    thoughtNumber: 1,
    totalThoughts: 10
})
```

## 🔍 Search Tools

### Perplexity Search
```javascript
mcp__mcp-omnisearch__perplexity_search({
    query: "iOS 17 SwiftData migration best practices health apps",
    limit: 5
})
```

### Tavily Search
```javascript
mcp__mcp-omnisearch__tavily_search({
    query: "HIPAA compliance mobile app requirements 2024",
    include_domains: ["hhs.gov", "apple.com"],
    limit: 10
})
```

## 📝 Memory Management

### Store Important Information
```javascript
mcp__Memory__create_entities({
    entities: [{
        name: "NetworkClientImplementation",
        entityType: "Implementation",
        observations: [
            "Uses async/await pattern",
            "Implements retry logic with exponential backoff",
            "Handles offline queue"
        ]
    }]
})

// Create relationships
mcp__Memory__create_relations({
    relations: [{
        from: "NetworkClient",
        to: "AuthService",
        relationType: "depends on"
    }]
})

// Search memory
mcp__Memory__search_nodes({
    query: "retry logic"
})
```

## 🛠️ Development Workflows

### TDD Feature Development

```bash
# 1. Create feature task
taskmaster add-task --prompt "Implement health metrics dashboard"

# 2. Research requirements
taskmaster research "SwiftUI charts for health data visualization" --save-to-file

# 3. Expand into TDD tasks
taskmaster expand-task <id> --prompt "Create TDD tasks: failing tests first"

# 4. For each subtask:
taskmaster next-task

# 5. Create test file using MCP
mcp__Filesystem__write_file({
    path: "Tests/DashboardViewModelTests.swift",
    content: "// TDD: Write failing test first"
})

# 6. Run test to see it fail
mcp__XcodeBuildMCP__test_sim_name_ws({
    workspacePath: "clarity-loop-frontend-v2.xcworkspace",
    scheme: "clarity-loop-frontend-v2Tests",
    simulatorName: "iPhone 16"
})

# 7. Implement minimal code to pass
# 8. Refactor if needed
# 9. Mark task complete
taskmaster set-task-status <id> done
```

### Debugging Workflow

```bash
# 1. Identify issue
taskmaster add-task --prompt "Fix: Network requests failing with 401 after token expiry"

# 2. Research
mcp__sequential-thinking__sequentialthinking({
    thought: "Token refresh issue: Check 1) Token storage, 2) Refresh logic, 3) Retry mechanism",
    nextThoughtNeeded: true,
    thoughtNumber: 1,
    totalThoughts: 5
})

# 3. Search codebase
Grep({
    pattern: "refreshToken|401|unauthorized",
    include: "*.swift"
})

# 4. Read relevant files
mcp__Filesystem__read_multiple_files({
    paths: ["Sources/AuthService.swift", "Sources/NetworkClient.swift"]
})

# 5. Fix and test
mcp__Filesystem__edit_file({
    path: "Sources/AuthService.swift",
    edits: [{
        oldText: "// existing refresh logic",
        newText: "// improved refresh logic with retry"
    }]
})
```

### Code Review Workflow

```javascript
// 1. Get changed files
Bash({ command: "git diff --name-only" })

// 2. Read changed files
mcp__Filesystem__read_multiple_files({
    paths: changedFiles
})

// 3. Analyze with thinking
mcp__sequential-thinking__sequentialthinking({
    thought: "Reviewing changes for: 1) TDD compliance, 2) HIPAA compliance, 3) Error handling",
    nextThoughtNeeded: true,
    thoughtNumber: 1,
    totalThoughts: 5
})

// 4. Create review task
taskmaster add-task --prompt "Code review findings: Missing tests for error cases"
```

## 🎯 Best Practices

### 1. Task Management First
Always start with Taskmaster to organize work:
```bash
taskmaster next-task
taskmaster list --status pending
```

### 2. TDD Workflow
For every feature:
1. Create task in Taskmaster
2. Write failing test using MCP file tools
3. Run test with XcodeBuild MCP
4. Implement minimal code
5. Refactor
6. Update task status

### 3. Parallel Operations
Use multiple MCP tools concurrently:
```javascript
// Read multiple files at once
const [auth, network, tests] = await Promise.all([
    mcp__Filesystem__read_file({ path: "AuthService.swift" }),
    mcp__Filesystem__read_file({ path: "NetworkClient.swift" }),
    mcp__Filesystem__read_file({ path: "AuthServiceTests.swift" })
])
```

### 4. Memory for Context
Store important decisions:
```javascript
mcp__Memory__create_entities({
    entities: [{
        name: "TDDPattern",
        entityType: "DesignDecision",
        observations: ["All features must have failing test first"]
    }]
})
```

## ⚠️ Common Pitfalls

1. **Don't use MCP Taskmaster for complex operations** - Use CLI instead
2. **Always check simulator state** before UI automation
3. **Read files before editing** - MCP requires this
4. **Use dry run** for complex edits
5. **Store context in Memory** for cross-session persistence

## 🚀 Quick Reference Card

```bash
# Taskmaster CLI
taskmaster init
taskmaster next-task
taskmaster expand-task <id>
taskmaster set-task-status <id> done

# Build & Test
mcp__XcodeBuildMCP__build_sim_name_ws
mcp__XcodeBuildMCP__test_sim_name_ws

# File Operations
mcp__Filesystem__read_file
mcp__Filesystem__write_file
mcp__Filesystem__edit_file

# Search
Grep({ pattern: "TODO|FIXME", include: "*.swift" })

# Memory
mcp__Memory__create_entities
mcp__Memory__search_nodes
```

---

✅ Use these tools in combination for maximum productivity. Taskmaster CLI drives the work, MCP tools execute it.