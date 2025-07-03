# ClarityPulseWrapper - Xcode Wrapper

## 🚨 CRITICAL: HOW TO BUILD AND RUN 🚨

### ALWAYS USE THE WORKSPACE

```bash
# Navigate here
cd ClarityPulseWrapper

# Open workspace (NOT the .xcodeproj)
open ClarityPulse.xcworkspace
```

### IN XCODE

1. **Select Scheme:** ClarityPulseWrapper (NOT ClarityPulseApp)
2. **Build:** Product → Run (⌘R)
3. **Target:** iPhone 16 simulator or physical device

### COMMAND LINE BUILD

```bash
# Build
xcodebuild -workspace ClarityPulse.xcworkspace -scheme ClarityPulseWrapper -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run
xcodebuild -workspace ClarityPulse.xcworkspace -scheme ClarityPulseWrapper -destination 'platform=iOS Simulator,name=iPhone 16' run
```

## FILES IN THIS DIRECTORY

- **ClarityPulse.xcworkspace** ← **USE THIS**
- **ClarityPulseWrapper.xcodeproj** ← Never open directly
- **amplifyconfiguration.json** ← AWS Amplify config
- **LoginView.swift** ← Login UI component
- **RootView.swift** ← App initialization
- **ClarityPulseWrapperApp.swift** ← App entry point

## ARCHITECTURE

This wrapper project:
1. Imports the SPM package (`clarity-loop-frontend-v2`)
2. Provides iOS app shell and entry point
3. Configures AWS Amplify authentication
4. Handles app lifecycle and dependencies

## TROUBLESHOOTING

### "Initializing..." Hang
- Check `amplifyconfiguration.json` exists
- Verify PoolId is not empty
- Clean build folder: ⌘⇧K

### Build Errors
- Use workspace, not project
- Clean DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData`
- Reset simulator if needed

### Authentication Issues
- Verify AWS backend is running
- Check Cognito configuration
- Ensure valid credentials

## RELATED DOCS

- **Complete Build Guide:** `../CLARITY_APP_BUILD_PROCESS.md`
- **Backend Reference:** `../BACKEND_REFERENCE/`
- **SPM Package:** `../clarity-loop-frontend-v2/`

---

**🚨 REMEMBER: WORKSPACE ONLY, NEVER THE PROJECT 🚨**
