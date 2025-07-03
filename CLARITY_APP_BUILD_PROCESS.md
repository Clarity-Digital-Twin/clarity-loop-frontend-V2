# CLARITY APP BUILD PROCESS - DEFINITIVE GUIDE

## 🚨 CRITICAL: READ THIS BEFORE TOUCHING ANYTHING 🚨

This is the **ONLY** way to build and run the CLARITY Pulse app. Follow these steps exactly.

## ARCHITECTURE OVERVIEW

```
CLARITY-DIGITAL-TWIN/clarity-loop-frontend-V2/
├── BACKEND_REFERENCE/          # Complete AWS backend (Python/FastAPI)
├── clarity-loop-frontend-v2/   # Swift Package Manager (SPM) modules
│   ├── Core/                   # Core services, DI, security
│   ├── Domain/                 # Business logic, entities, use cases
│   ├── Data/                   # Repositories, DTOs, persistence
│   └── UI/                     # SwiftUI views, view models
└── ClarityPulseWrapper/        # Xcode wrapper project
    ├── ClarityPulse.xcworkspace # 👈 ALWAYS USE THIS
    └── amplifyconfiguration.json # AWS Amplify config
```

## 🎯 THE ONLY BUILD PROCESS THAT WORKS

### 1. OPEN THE WORKSPACE (NOT THE PROJECT)

```bash
cd /Users/ray/Desktop/CLARITY-DIGITAL-TWIN/clarity-loop-frontend-V2/ClarityPulseWrapper
open ClarityPulse.xcworkspace
```

**⚠️ NEVER OPEN:**
- `ClarityPulseWrapper.xcodeproj` (individual project)
- Any other `.xcodeproj` files

### 2. SELECT THE CORRECT SCHEME

In Xcode, select: **ClarityPulseWrapper** scheme (NOT ClarityPulseApp)

### 3. BUILD AND RUN

**Option A: Xcode GUI**
- Product → Run (⌘R)

**Option B: Command Line**
```bash
cd ClarityPulseWrapper
xcodebuild -workspace ClarityPulse.xcworkspace -scheme ClarityPulseWrapper -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## 🔧 REQUIRED CONFIGURATION FILES

### amplifyconfiguration.json
Must exist in `ClarityPulseWrapper/amplifyconfiguration.json`:

```json
{
    "auth": {
        "plugins": {
            "awsCognitoAuthPlugin": {
                "UserAgent": "aws-amplify-cli/0.1.0",
                "Version": "0.1.0",
                "IdentityManager": {
                    "Default": {}
                },
                "CredentialsProvider": {
                    "CognitoIdentity": {
                        "Default": {
                            "Region": "us-east-1"
                        }
                    }
                },
                "CognitoUserPool": {
                    "Default": {
                        "PoolId": "us-east-1_XXXXXXXXX",
                        "AppClientId": "XXXXXXXXXXXXXXXXXXXXXXXXXX",
                        "Region": "us-east-1"
                    }
                }
            }
        }
    }
}
```

## 🚨 COMMON PROBLEMS AND SOLUTIONS

### Problem: "Initializing..." Hang
**Solution:** Check `amplifyconfiguration.json` exists and has valid PoolId (not empty)

### Problem: Build Errors
**Solution:** Clean build folder: Product → Clean Build Folder (⌘⇧K)

### Problem: Simulator Crashes
**Solution:** Reset simulator: Device → Erase All Content and Settings

### Problem: Dependency Issues
**Solution:**
1. Close Xcode
2. Delete DerivedData: `rm -rf ~/Library/Developer/Xcode/DerivedData`
3. Reopen workspace (not project)

### Problem: Authentication Fails
**Solution:** Verify AWS Cognito configuration in backend and update `amplifyconfiguration.json`

## 📱 TESTING THE APP

1. **Launch App:** Should show initialization screen briefly, then login
2. **Login Test:** Use valid credentials from your AWS Cognito user pool
3. **Navigation:** Should access dashboard after successful login

## 🔄 DEVELOPMENT WORKFLOW

1. Make changes in SPM modules (`clarity-loop-frontend-v2/`)
2. Build and test in wrapper (`ClarityPulseWrapper`)
3. Always use the workspace, never individual projects

## 📋 AVAILABLE SCHEMES

- **ClarityPulseWrapper** - Main iOS app (USE THIS)
- **ClarityPulseApp** - SPM executable target
- Various Amplify schemes (auto-generated)

## 🎯 TARGET CONFIGURATION

- **Bundle ID:** `com.clarity.ClarityPulseWrapper`
- **Team:** `HJ7W9PTAD8`
- **iOS Version:** 18.0+
- **Architecture:** arm64 (Apple Silicon) + x86_64 (Intel)

## ⚡ QUICK START COMMANDS

```bash
# Navigate to wrapper
cd /Users/ray/Desktop/CLARITY-DIGITAL-TWIN/clarity-loop-frontend-V2/ClarityPulseWrapper

# Open workspace
open ClarityPulse.xcworkspace

# Build from command line
xcodebuild -workspace ClarityPulse.xcworkspace -scheme ClarityPulseWrapper -destination 'platform=iOS Simulator,name=iPhone 16' build

# Run on simulator
xcodebuild -workspace ClarityPulse.xcworkspace -scheme ClarityPulseWrapper -destination 'platform=iOS Simulator,name=iPhone 16' run
```

## 🔗 RELATED DOCUMENTATION

- Backend setup: `BACKEND_REFERENCE/README.md`
- AWS Amplify: `CLARITY_AWS_AMPLIFY_SETUP.md`
- Accessibility: `CLARITY_ACCESSIBILITY_GUIDE.md`

---

**🚨 REMEMBER: ALWAYS USE THE WORKSPACE, NEVER THE PROJECT 🚨**
