# UI Test Setup Instructions

## What Was Done

1. **Updated project.yml** to include UI test target:
   - Added `ClarityPulseWrapperUITests` target
   - Configured to use existing UI test files from `clarity-loop-frontend-v2UITests`
   - Set up proper dependencies

2. **Regenerated Xcode project** with `xcodegen generate`

3. **Created test plan** at `ClarityPulseWrapper/ClarityPulse.xctestplan`
   - Configured for UI tests
   - Enabled code coverage
   - Set test timeouts to 60 seconds

## How to Run UI Tests

### Via Xcode
1. Open `ClarityPulseWrapper/ClarityPulseWrapper.xcodeproj`
2. Select scheme: `ClarityPulseWrapper`
3. Select a simulator (e.g., iPhone 16)
4. Press `⌘U` or Product → Test

### Via Command Line
```bash
cd ClarityPulseWrapper
xcodebuild test \
  -project ClarityPulseWrapper.xcodeproj \
  -scheme ClarityPulseWrapper \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  -testPlan ClarityPulse
```

## Test Organization

The UI tests are located in `clarity-loop-frontend-v2UITests/` and include:
- `BaseUITestCase.swift` - Base class for UI tests
- `Screens/` - Page object pattern implementations
- `Utilities/` - Helper utilities for screenshots, etc.

## Next Steps

1. Verify UI tests run successfully
2. Add more UI test coverage
3. Set up CI/CD integration for automated UI testing
4. Consider adding performance tests