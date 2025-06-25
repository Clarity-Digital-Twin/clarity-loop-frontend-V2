# CLARITY Human Intervention Requirements Guide

## 🚨 CRITICAL: AI Agents MUST Request Human Help for These Tasks

This document defines ALL scenarios where AI agents MUST STOP and request human intervention. These requirements are NON-NEGOTIABLE due to Xcode-specific operations that cannot be performed via command line or file editing.

## 🛑 MANDATORY HUMAN INTERVENTION POINTS

### 1. Xcode Project Configuration

#### 🔴 STOP: Adding New Files to Xcode Project
```
AI MUST SAY: "I've created [filename.swift]. HUMAN INTERVENTION REQUIRED: 
Please add this file to the Xcode project:
1. Open Xcode
2. Right-click on the appropriate group
3. Select 'Add Files to "clarity-loop-frontend-v2"'
4. Select the file and ensure target membership is checked
5. Confirm: 'File added to Xcode project'"
```

#### 🔴 STOP: Modifying Build Settings
```
AI MUST SAY: "Build settings need modification. HUMAN INTERVENTION REQUIRED:
1. Open Xcode
2. Select project in navigator
3. Go to Build Settings tab
4. Change [specific setting] to [value]
5. Confirm: 'Build settings updated'"
```

#### 🔴 STOP: Managing Target Dependencies
```
AI MUST SAY: "Target dependencies need updating. HUMAN INTERVENTION REQUIRED:
1. Open Xcode
2. Select project → target → Build Phases
3. Add/modify dependencies as follows: [list]
4. Confirm: 'Dependencies updated'"
```

### 2. Code Signing & Capabilities

#### 🔴 STOP: Provisioning Profile Issues
```
AI MUST SAY: "Code signing requires attention. HUMAN INTERVENTION REQUIRED:
1. Open Xcode
2. Select project → Signing & Capabilities
3. Select team and fix provisioning profile
4. Confirm: 'Code signing resolved'"
```

#### 🔴 STOP: Adding Capabilities
```
AI MUST SAY: "New capability needed: [capability]. HUMAN INTERVENTION REQUIRED:
1. Open Xcode
2. Select project → Signing & Capabilities
3. Click '+' and add [capability]
4. Configure as follows: [settings]
5. Confirm: 'Capability added'"
```

### 3. Testing Operations

#### 🔴 STOP: Running Tests
```
AI MUST SAY: "Tests need to be run. HUMAN INTERVENTION REQUIRED:
1. Open Xcode
2. Press Cmd+U to run all tests
3. Report results: 'X passed, Y failed'
4. If failures, provide error messages"
```

#### 🔴 STOP: UI Testing
```
AI MUST SAY: "UI tests need execution. HUMAN INTERVENTION REQUIRED:
1. Open Xcode
2. Select UI test scheme
3. Run on [specific simulator/device]
4. Report: 'UI test results: [details]'"
```

#### 🔴 STOP: Performance Testing
```
AI MUST SAY: "Performance testing required. HUMAN INTERVENTION REQUIRED:
1. Open Xcode
2. Product → Profile (Cmd+I)
3. Select [Instrument type]
4. Run and analyze
5. Report metrics: [specific measurements]"
```

### 4. Asset Management

#### 🔴 STOP: Adding Images to Asset Catalog
```
AI MUST SAY: "New images need adding. HUMAN INTERVENTION REQUIRED:
1. Open Assets.xcassets in Xcode
2. Drag images to catalog
3. Set proper scales (1x, 2x, 3x)
4. Confirm: 'Assets added'"
```

#### 🔴 STOP: Configuring Launch Screen
```
AI MUST SAY: "Launch screen needs update. HUMAN INTERVENTION REQUIRED:
1. Open LaunchScreen.storyboard in Xcode
2. Make changes: [specific changes]
3. Test on different devices
4. Confirm: 'Launch screen updated'"
```

### 5. Build & Run Operations

#### 🔴 STOP: Building for Device
```
AI MUST SAY: "Device build needed. HUMAN INTERVENTION REQUIRED:
1. Connect iOS device
2. Select device in Xcode scheme
3. Build (Cmd+B)
4. Report: 'Build succeeded/failed with [errors]'"
```

#### 🔴 STOP: Debugging on Device
```
AI MUST SAY: "Device debugging needed. HUMAN INTERVENTION REQUIRED:
1. Set breakpoints at: [locations]
2. Run on device
3. Trigger issue
4. Report debugger output: [details]"
```

### 6. Framework & Library Management

#### 🔴 STOP: Adding Swift Packages
```
AI MUST SAY: "Swift Package needed: [package]. HUMAN INTERVENTION REQUIRED:
1. File → Add Package Dependencies
2. Enter URL: [package URL]
3. Select version: [version]
4. Add to target: [target name]
5. Confirm: 'Package added'"
```

#### 🔴 STOP: Embedding Frameworks
```
AI MUST SAY: "Framework embedding needed. HUMAN INTERVENTION REQUIRED:
1. Select target → General → Frameworks
2. Add framework: [name]
3. Set 'Embed & Sign'
4. Confirm: 'Framework embedded'"
```

### 7. Debugging & Diagnostics

#### 🔴 STOP: Memory Leak Detection
```
AI MUST SAY: "Memory leak check needed. HUMAN INTERVENTION REQUIRED:
1. Product → Profile
2. Select 'Leaks' instrument
3. Run scenario: [specific steps]
4. Report: 'Leaks found: [details]' or 'No leaks'"
```

#### 🔴 STOP: View Hierarchy Debugging
```
AI MUST SAY: "UI debugging needed. HUMAN INTERVENTION REQUIRED:
1. Run app
2. Debug → View Debugging → Capture View Hierarchy
3. Inspect: [specific view]
4. Report findings: [details]"
```

### 8. HealthKit Specific

#### 🔴 STOP: HealthKit Permissions Testing
```
AI MUST SAY: "HealthKit permissions test needed. HUMAN INTERVENTION REQUIRED:
1. Reset simulator/device permissions
2. Run app fresh
3. Trigger HealthKit request
4. Grant/deny permissions
5. Report behavior: [what happened]"
```

#### 🔴 STOP: HealthKit Background Delivery
```
AI MUST SAY: "Background delivery test needed. HUMAN INTERVENTION REQUIRED:
1. Enable background delivery in Xcode capabilities
2. Run on device (not simulator)
3. Background the app
4. Trigger health data change
5. Report: 'Background delivery [worked/failed]'"
```

### 9. AWS Amplify Configuration

#### 🔴 STOP: Amplify CLI Operations
```
AI MUST SAY: "Amplify configuration needed. HUMAN INTERVENTION REQUIRED:
1. Run: amplify [command]
2. Follow prompts: [expected inputs]
3. Report output: [result]
4. Commit generated files"
```

### 10. Archive & Distribution

#### 🔴 STOP: Creating Archive
```
AI MUST SAY: "Archive creation needed. HUMAN INTERVENTION REQUIRED:
1. Select 'Any iOS Device' as destination
2. Product → Archive
3. Wait for completion
4. Report: 'Archive created successfully' or errors"
```

## 🔄 INTEGRATION WITH OTHER DOCUMENTS

### In Every Document, Add These Reminders:

#### For SwiftData Documents:
```markdown
⚠️ HUMAN INTERVENTION: When adding new @Model classes, you MUST:
1. Add the Swift file to Xcode project manually
2. Ensure Core Data model generation is disabled
3. Clean build folder before first run
```

#### For Testing Documents:
```markdown
⚠️ HUMAN INTERVENTION: All test execution MUST be done in Xcode:
1. AI can write tests but CANNOT run them
2. Use Cmd+U in Xcode for test execution
3. Report specific failures back to AI
```

#### For Security Documents:
```markdown
⚠️ HUMAN INTERVENTION: Keychain and biometric testing requires:
1. Real device testing (simulator limitations)
2. Manual permission grants
3. Settings.app configuration
```

#### For State Management Documents:
```markdown
⚠️ HUMAN INTERVENTION: SwiftUI Preview issues require:
1. Xcode preview panel debugging
2. Manual preview refresh
3. Clean derived data if needed
```

## 📋 HUMAN RESPONSE TEMPLATES

### For Successful Operations:
```
"COMPLETED: [Task name]
- Result: Success
- Details: [Specific outcomes]
- Next: Ready for next step"
```

### For Failed Operations:
```
"FAILED: [Task name]
- Error: [Exact error message]
- Location: [File:Line if applicable]
- Console: [Relevant console output]
- Screenshot: [If UI related]"
```

### For Partial Success:
```
"PARTIAL: [Task name]
- Succeeded: [What worked]
- Failed: [What didn't work]
- Warnings: [Any warnings]
- Suggestion: [What might help]"
```

## 🚦 AI BEHAVIOR RULES

### AI MUST:
1. **STOP IMMEDIATELY** when encountering any task above
2. **CLEARLY STATE** what human intervention is needed
3. **WAIT FOR CONFIRMATION** before proceeding
4. **NEVER ASSUME** Xcode operations were successful
5. **REQUEST SPECIFICS** if human response is vague

### AI MUST NOT:
1. Attempt to simulate Xcode operations via CLI
2. Skip testing because it requires human help
3. Proceed past intervention points without confirmation
4. Generate code that requires Xcode without alerting human

## 🎯 ENFORCEMENT IN AI PROMPTS

Every AI session should begin with:
```
CRITICAL RULES:
1. This is an iOS app requiring Xcode for many operations
2. You CANNOT run tests - request human to run in Xcode
3. You CANNOT modify project structure - request human Xcode help
4. You CANNOT build/run - request human to use Xcode
5. Read CLARITY_HUMAN_INTERVENTION_GUIDE.md for all stop points
```

## 📊 QUICK REFERENCE CARD

| Task | Can AI Do? | Human Required |
|------|------------|----------------|
| Write Swift code | ✅ Yes | ❌ No |
| Create .swift files | ✅ Yes | ⚠️ Adding to Xcode |
| Run tests | ❌ No | ✅ Always |
| Build project | ❌ No | ✅ Always |
| Debug on device | ❌ No | ✅ Always |
| Add capabilities | ❌ No | ✅ Always |
| Profile performance | ❌ No | ✅ Always |
| View hierarchy debug | ❌ No | ✅ Always |
| Archive for release | ❌ No | ✅ Always |

## 🔄 CONTINUOUS REMINDERS

Insert these reminders throughout implementation:

```swift
// ⚠️ HUMAN INTERVENTION: After creating this file, add it to Xcode project

// ⚠️ HUMAN INTERVENTION: Run these tests in Xcode with Cmd+U

// ⚠️ HUMAN INTERVENTION: Test this on real device, not simulator

// ⚠️ HUMAN INTERVENTION: Check Xcode console for actual error
```

---

**Remember**: The success of this project depends on clear AI-Human collaboration. When in doubt, STOP and ASK for human help!