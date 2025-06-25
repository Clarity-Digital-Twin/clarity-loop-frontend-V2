# CLARITY Build Command & Naming Consistency Fixes

## Overview

This document addresses the build command issues and naming inconsistencies in the CLARITY Pulse iOS frontend V2 project.

## Issues Identified

### 1. Naming Inconsistencies

**Problem**: Mixed naming conventions throughout the project:
- Directory name: `clarity-loop-frontend-V2`
- Project name: `clarity-loop-frontend.xcodeproj`
- Scheme name: `clarity-loop-frontend`
- Target names: `clarity-loop-frontend`, `clarity-loop-frontendTests`, `clarity-loop-frontendUITests`
- Some references may still use old names

**Impact**: 
- Confusing for developers and AI agents
- Potential build failures if names don't match
- Import statements may fail

### 2. Build Command Issues

**Problem**: User mentioned using `xcodemake` instead of standard `xcodebuild`
- `xcodemake` is not a standard tool
- Appears to be a build log file with an unusual name
- Not in system PATH

**Reality**: The file is actually a build log with a very long filename that includes the entire build command

## Fixes Required

### 1. Standardize Naming Convention

**Decision**: Use `ClarityPulse` as the canonical name moving forward

**⚠️ HUMAN INTERVENTION REQUIRED**:
```
1. Open Xcode
2. Select project in navigator
3. Rename project to "ClarityPulse"
4. When prompted, rename all targets and schemes
5. Update all file references
6. Clean build folder (Shift+Cmd+K)
7. Confirm: "Project renamed to ClarityPulse"
```

### 2. Fix Build Commands

Create proper build scripts instead of relying on non-standard tools:

```bash
#!/bin/bash
# scripts/build-debug.sh

PROJECT="ClarityPulse.xcodeproj"
SCHEME="ClarityPulse"
CONFIGURATION="Debug"
DESTINATION="platform=iOS Simulator,name=iPhone 16,OS=latest"

xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    -skipMacroValidation \
    build
```

```bash
#!/bin/bash
# scripts/build-release.sh

PROJECT="ClarityPulse.xcodeproj"
SCHEME="ClarityPulse"
CONFIGURATION="Release"
DESTINATION="generic/platform=iOS"

xcodebuild \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -configuration "$CONFIGURATION" \
    -destination "$DESTINATION" \
    clean build
```

```bash
#!/bin/bash
# scripts/run-tests.sh

PROJECT="ClarityPulse.xcodeproj"
SCHEME="ClarityPulseTests"
DESTINATION="platform=iOS Simulator,name=iPhone 16,OS=latest"

xcodebuild test \
    -project "$PROJECT" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -resultBundlePath TestResults.xcresult
```

### 3. Update Import Statements

After renaming, all Swift files need import updates:

```swift
// Before
@testable import clarity_loop_frontend

// After
@testable import ClarityPulse
```

### 4. Fix Module Names

Update module names in all configuration files:

```swift
// Package.swift (if using SPM)
.product(name: "ClarityPulse", package: "ClarityPulse")

// Test files
@testable import ClarityPulse
```

### 5. Clean Up Old References

Remove files with old naming:
- Old build logs
- Symlinks pointing to old locations
- Generated files with old names

```bash
# Clean up script
#!/bin/bash
# scripts/cleanup-old-names.sh

echo "Cleaning up old naming references..."

# Remove old build logs
rm -f "*clarity-loop-frontend*build.log"

# Remove broken symlinks
find . -type l -exec test ! -e {} \; -delete

# Clean derived data
rm -rf ~/Library/Developer/Xcode/DerivedData/clarity-loop-frontend*

echo "Cleanup complete"
```

## Implementation Steps

### Phase 1: Document Current State (COMPLETED)
- [x] Identify all naming inconsistencies
- [x] Document build command issues
- [x] Create this fix guide

### Phase 2: Prepare for Rename
- [ ] Create backup of project
- [ ] Document all import statements
- [ ] List all configuration files

### Phase 3: Execute Rename (HUMAN REQUIRED)
- [ ] Rename in Xcode
- [ ] Update all targets
- [ ] Update all schemes
- [ ] Clean and rebuild

### Phase 4: Update Code
- [ ] Fix all import statements
- [ ] Update configuration files
- [ ] Update build scripts
- [ ] Update documentation

### Phase 5: Verify
- [ ] Build successfully
- [ ] All tests pass
- [ ] No import errors
- [ ] Archive builds correctly

## Build Command Reference

### Standard xcodebuild Commands

```bash
# Build for simulator
xcodebuild -project ClarityPulse.xcodeproj \
           -scheme ClarityPulse \
           -destination 'platform=iOS Simulator,name=iPhone 16' \
           build

# Build for device
xcodebuild -project ClarityPulse.xcodeproj \
           -scheme ClarityPulse \
           -destination 'generic/platform=iOS' \
           build

# Run tests
xcodebuild test -project ClarityPulse.xcodeproj \
                -scheme ClarityPulseTests \
                -destination 'platform=iOS Simulator,name=iPhone 16'

# Archive for distribution
xcodebuild archive -project ClarityPulse.xcodeproj \
                   -scheme ClarityPulse \
                   -archivePath ./build/ClarityPulse.xcarchive
```

### Using xcodebuild with Options

```bash
# Skip macro validation (Swift 5.9+)
-skipMacroValidation

# Skip package updates
-skipPackageUpdates

# Parallel builds
-parallelizeTargets

# Show build times
-showBuildTimingSummary
```

## Makefile for Convenience

Create a Makefile for common operations:

```makefile
# Makefile
PROJECT = ClarityPulse.xcodeproj
SCHEME = ClarityPulse
TEST_SCHEME = ClarityPulseTests
SIMULATOR = platform=iOS Simulator,name=iPhone 16,OS=latest

.PHONY: build test clean archive

build:
	xcodebuild -project $(PROJECT) \
	           -scheme $(SCHEME) \
	           -destination '$(SIMULATOR)' \
	           build

test:
	xcodebuild test -project $(PROJECT) \
	                -scheme $(TEST_SCHEME) \
	                -destination '$(SIMULATOR)'

clean:
	xcodebuild clean -project $(PROJECT) -scheme $(SCHEME)
	rm -rf build/
	rm -rf *.xcresult

archive:
	xcodebuild archive -project $(PROJECT) \
	                   -scheme $(SCHEME) \
	                   -archivePath ./build/$(SCHEME).xcarchive
```

## Alternative: fastlane Integration

For more advanced build automation:

```ruby
# fastlane/Fastfile
default_platform(:ios)

platform :ios do
  desc "Build debug version"
  lane :build_debug do
    build_app(
      project: "ClarityPulse.xcodeproj",
      scheme: "ClarityPulse",
      configuration: "Debug",
      skip_codesigning: true
    )
  end

  desc "Run tests"
  lane :test do
    run_tests(
      project: "ClarityPulse.xcodeproj",
      scheme: "ClarityPulseTests",
      devices: ["iPhone 16"]
    )
  end
end
```

## ⚠️ CRITICAL HUMAN TASKS

1. **Confirm Build Tool**: 
   - Is `xcodemake` a custom tool you want to keep using?
   - Or should we standardize on `xcodebuild`?

2. **Approve Naming Convention**:
   - Confirm using "ClarityPulse" as the standard name
   - Or specify preferred naming

3. **Execute Xcode Rename**:
   - This MUST be done in Xcode GUI
   - Cannot be automated via command line

4. **Test Build Scripts**:
   - Run provided scripts after rename
   - Report any errors

## Next Steps After Fixes

1. Update all documentation to use new names
2. Update CI/CD pipelines
3. Notify team of naming changes
4. Update any external references

---

**Remember**: Naming consistency is crucial for a maintainable codebase. Take time to do this right!