# CLARITY Pulse V2 - Taskmaster Implementation Guide

## Overview

This guide explains how to use Taskmaster CLI to iteratively build the CLARITY Pulse V2 iOS frontend following strict TDD principles. We have 30 main tasks with expandable subtasks that will guide the entire development process.

## Current Status

- **Tasks Created**: 30 main tasks covering the entire project scope
- **Current Tag**: master
- **Next Task**: Task #1 - Project Setup and Configuration (expanded with 10 subtasks)
- **Methodology**: Test-Driven Development (TDD) with Red-Green-Refactor cycle

## Getting Started with Taskmaster

### View Current Tasks
```bash
# Show all pending tasks
task-master list --status pending

# Show the next task to work on
task-master next-task

# Get detailed info about a specific task
task-master get-task --id=1
```

### Working on Tasks

1. **Start with the Next Task**
   ```bash
   task-master next-task
   ```
   This shows you the highest priority task with no blocking dependencies.

2. **Expand Complex Tasks**
   ```bash
   task-master expand --id=<task-id> --num=10 --prompt="Create TDD subtasks..."
   ```
   Each main task can be expanded into detailed subtasks following TDD.

3. **Update Task Status**
   ```bash
   # Mark as in-progress when starting
   task-master set-task-status --id=1 --status=in-progress
   
   # Mark as done when completed
   task-master set-task-status --id=1 --status=done
   
   # For subtasks use dot notation
   task-master set-task-status --id=1.1 --status=done
   ```

## TDD Implementation Pattern

For EVERY task and subtask, follow this pattern:

### 1. Red Phase - Write Failing Test First
```swift
// Example: Testing project configuration
func test_projectConfiguration_shouldTargetIOS18() {
    // This test will fail initially
    let deployment = Bundle.main.infoDictionary?["MinimumOSVersion"] as? String
    XCTAssertEqual(deployment, "18.0")
}
```

### 2. Green Phase - Minimal Implementation
Write just enough code to make the test pass. No more.

### 3. Refactor Phase - Improve Code Quality
Clean up while keeping tests green.

## Task Execution Flow

### Phase 1: Foundation (Tasks 1-5)
Start here. These tasks set up the project structure and core dependencies.

```bash
# Current focus: Task 1 - Project Setup
task-master get-task --id=1

# Work through each subtask
task-master set-task-status --id=1.1 --status=in-progress
# ... implement with TDD ...
task-master set-task-status --id=1.1 --status=done
```

### Phase 2: Core Infrastructure (Tasks 6-14)
Build the essential services: auth, networking, persistence, state management.

### Phase 3: Feature Modules (Tasks 15-20)
Implement the actual app features: Dashboard, Health Data, Insights, etc.

### Phase 4: Polish & Release (Tasks 21-30)
Performance, accessibility, testing, and deployment.

## Key Commands Reference

```bash
# Task Management
task-master list                     # Show all tasks
task-master next-task                # Find next task to work on
task-master get-task --id=15         # Get specific task details
task-master set-task-status --id=15 --status=in-progress

# Task Expansion
task-master expand --id=2 --num=8    # Expand task 2 into 8 subtasks

# Progress Tracking
task-master list --status=done       # Show completed tasks
task-master list --status=pending    # Show remaining tasks

# Task Updates
task-master update-task --id=5 --prompt="Add SwiftData migration support"
```

## Implementation Checklist

- [ ] **Before Starting ANY Task**
  - Read the task description and test strategy
  - Expand complex tasks into TDD subtasks if needed
  - Mark task as in-progress

- [ ] **During Implementation**
  - Write failing test FIRST (Red)
  - Write minimal code to pass (Green)  
  - Refactor if needed (Refactor)
  - Run tests frequently
  - Commit after each green state

- [ ] **After Completing a Task**
  - Ensure all tests pass
  - Check code coverage (must be 80%+)
  - Mark task as done
  - Check for next unblocked task

## Common Patterns

### Creating a New Feature Module
1. Expand the module task with TDD subtasks
2. Start with the ViewModel tests
3. Then implement the View tests
4. Finally integration tests

### Adding Backend Integration
1. Write tests for the repository interface
2. Create mock implementations
3. Test the actual API integration
4. Handle error cases

### Implementing UI Components
1. Test the component's public interface
2. Test accessibility
3. Test dark mode
4. Snapshot test if needed

## Troubleshooting

### If Tests Aren't Running
- Check test target configuration
- Verify imports are correct
- Ensure test files are in test target

### If Stuck on a Task
```bash
# Add more context to the task
task-master update-task --id=<task-id> --prompt="Additional implementation notes..."

# Or break it down further
task-master expand --id=<task-id> --num=5
```

### To Skip Blocked Tasks
```bash
# Find tasks not blocked by incomplete dependencies
task-master list --status=pending | grep -v "blocked"
```

## Progress Monitoring

Track your progress with:
```bash
# See completion percentage
task-master list | grep -c "done"
task-master list | wc -l

# Generate reports (if needed)
task-master complexity-report
```

## Next Steps

1. Start with Task #1 (already expanded)
2. Work through each subtask using TDD
3. Mark subtasks complete as you go
4. Move to Task #2 when Task #1 is done
5. Continue iteratively through all 30 tasks

Remember: **NO PRODUCTION CODE WITHOUT A FAILING TEST FIRST!**

## Human Intervention Required

These tasks require human interaction with Xcode:
- Task #1: Initial project creation in Xcode
- Task #2: Test target configuration
- Task #26: CI/CD certificate setup
- Task #28: App Store submission

For these tasks, the AI agent should provide detailed instructions and wait for human confirmation before marking as complete.