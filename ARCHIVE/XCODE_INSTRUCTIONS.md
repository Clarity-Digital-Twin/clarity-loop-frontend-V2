# Running ClarityPulse in Xcode

We use a minimal Xcode wrapper project to create an iOS app bundle from our Swift Package.

## Quick Start

1. Install xcodegen (if needed):
   ```bash
   brew install xcodegen
   ```

2. Generate and open the project:
   ```bash
   cd ClarityPulseWrapper
   xcodegen generate
   open ClarityPulseWrapper.xcodeproj
   ```

3. In Xcode:
   - Select the `ClarityPulseWrapper` scheme
   - Choose an iOS Simulator (e.g., iPhone 16)
   - Press ⌘R to run

## Architecture

```
clarity-loop-frontend-V2/
├── Package.swift           # Main SPM package (all app code)
├── ClarityPulseWrapper/    # Minimal iOS app wrapper
│   ├── project.yml         # Xcodegen config
│   ├── ClarityPulseWrapperApp.swift
│   └── README.md
└── ...
```

## Why Not Pure SPM?

- `.iOSApplication` product type is still experimental/beta
- This wrapper approach is stable and production-ready
- Only adds 4 files to the repository
- Standard approach used by most SPM-based iOS apps

## Development Workflow

1. All app code goes in the main Package.swift targets
2. The wrapper just provides the iOS app bundle
3. Tests run via `swift test` in the root directory
4. CI/CD builds using the wrapper project