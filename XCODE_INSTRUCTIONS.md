# Running ClarityPulse in Xcode

Since we're using a pure SPM setup without `.iOSApplication` support (requires Xcode 16), you need to manually configure Xcode to run the app:

## Steps to Run in Simulator

1. Open `Package.swift` in Xcode:
   ```bash
   open Package.swift
   ```

2. In Xcode:
   - Wait for package resolution to complete
   - Select the `ClarityPulseApp` scheme from the scheme selector (top of window)
   - Select an iOS Simulator (e.g., iPhone 16)
   - Press ⌘R to run

3. Xcode will prompt for:
   - **Product Type**: Select "iOS App" 
   - **Bundle Identifier**: Use `com.clarity.pulse`
   - **Team**: Select your development team or "None"

4. The app should now launch in the simulator

## Alternative: Create iOS App Target

If the above doesn't work, you can create a minimal iOS app target:

1. In Xcode: File → New → Target → iOS App
2. Product Name: `ClarityPulseApp`
3. Bundle Identifier: `com.clarity.pulse`
4. Interface: SwiftUI
5. Language: Swift
6. Delete the generated files (ContentView, Assets, etc.)
7. Link to your SPM modules in Build Phases → Link Binary

## Future: Swift 6.1 / Xcode 16

Once Xcode 16 is available, we can use the `.iOSApplication` product type directly in Package.swift for a pure SPM setup.