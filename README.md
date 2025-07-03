# CLARITY Digital Twin - Frontend V2

## 🚨 CRITICAL BUILD INSTRUCTIONS 🚨

**BEFORE DOING ANYTHING:** Read `CLARITY_APP_BUILD_PROCESS.md` for complete build instructions.

**QUICK START:**
```bash
cd ClarityPulseWrapper
open ClarityPulse.xcworkspace  # ⚠️ WORKSPACE, NOT PROJECT
# Select ClarityPulseWrapper scheme in Xcode
# Product → Run (⌘R)
```

## Architecture

This is a Swift iOS application for CLARITY's concierge psychiatry platform with clean architecture:

- **Backend:** Complete AWS infrastructure in `BACKEND_REFERENCE/`
- **SPM Package:** Modular Swift package in `clarity-loop-frontend-v2/`
- **Wrapper:** Xcode project in `ClarityPulseWrapper/`

## Project Structure

```
├── BACKEND_REFERENCE/          # AWS backend (Python/FastAPI)
├── clarity-loop-frontend-v2/   # Swift Package Manager modules
│   ├── Core/                   # Services, DI, security
│   ├── Domain/                 # Business logic, entities
│   ├── Data/                   # Repositories, persistence
│   └── UI/                     # SwiftUI views, ViewModels
└── ClarityPulseWrapper/        # Xcode wrapper
    └── ClarityPulse.xcworkspace # 👈 ALWAYS USE THIS
```

## Development Workflow

1. **Open:** `ClarityPulseWrapper/ClarityPulse.xcworkspace` (NEVER the .xcodeproj)
2. **Select:** ClarityPulseWrapper scheme
3. **Build:** Product → Run (⌘R)
4. **Edit:** Make changes in `clarity-loop-frontend-v2/` modules
5. **Test:** Build and run through the workspace

## Key Features

- AWS Cognito authentication
- Health data tracking
- SwiftUI + Swift 6 strict concurrency
- Clean architecture with dependency injection
- Comprehensive testing suite

## Documentation

- **Build Process:** `CLARITY_APP_BUILD_PROCESS.md` ⭐ **READ THIS FIRST**
- **AWS Setup:** `CLARITY_AWS_AMPLIFY_SETUP.md`
- **Accessibility:** `CLARITY_ACCESSIBILITY_GUIDE.md`
- **Agents:** `AGENTS.md`

---

**🚨 REMEMBER: ALWAYS USE THE WORKSPACE (`ClarityPulse.xcworkspace`), NEVER THE PROJECT 🚨**
