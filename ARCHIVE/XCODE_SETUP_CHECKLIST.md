# Xcode Setup Checklist for CLARITY Pulse V2

## ⚠️ IMPORTANT: Manual Steps Required in Xcode

The following steps MUST be completed manually in Xcode before proceeding with development:

### 1. Open the Project
- [ ] Open `clarity-loop-frontend-v2.xcodeproj` in Xcode

### 2. Update Swift Version
- [ ] Select the project in the navigator (top blue icon)
- [ ] Select the project (not target) in the editor
- [ ] Go to Build Settings tab
- [ ] Search for "Swift Language Version"
- [ ] Change from "Swift 5" to "Swift 6" for all configurations

### 3. Verify Deployment Target
- [ ] In the same Build Settings, search for "iOS Deployment Target"
- [ ] Confirm it's set to "iOS 18.0" (should already be correct)

### 4. Add Configuration Files
- [ ] Select the project in the navigator
- [ ] In the project editor, select the project (not targets)
- [ ] Go to the Info tab
- [ ] Under Configurations, you'll see Debug and Release
- [ ] For Debug configuration:
  - [ ] Click the arrow to expand
  - [ ] For each target, click the dropdown and select "clarity-loop-frontend-v2/Config/Debug"
- [ ] For Release configuration:
  - [ ] Click the arrow to expand
  - [ ] For each target, click the dropdown and select "clarity-loop-frontend-v2/Config/Release"

### 5. Verify Build Settings Applied
- [ ] Select each target
- [ ] Go to Build Settings
- [ ] Confirm these settings are applied (they should come from the .xcconfig files):
  - Swift Version: 6.2
  - Swift Strict Concurrency: Complete
  - Other Swift Flags: `-enable-actor-data-race-checks -enable-bare-slash-regex`
  - Treat Warnings as Errors: Yes

### 6. Clean Build Folder
- [ ] Product → Clean Build Folder (⌘⇧K)

### 7. Test Build
- [ ] Try to build the project (⌘B)
- [ ] If there are errors related to Swift 6.2, that's expected - we'll fix them as we implement

## What I've Already Done

✅ Updated Package.swift to swift-tools-version: 6.2
✅ Created Base.xcconfig with all Swift 6.2 settings
✅ Created Debug.xcconfig and Release.xcconfig
✅ Updated .swiftformat for Swift 6.2
✅ Updated .swiftlint.yml with Swift 6.2 rules
✅ All configuration files are ready

## After Xcode Setup

Once you've completed the checklist above:
1. Save the project
2. Close and reopen Xcode to ensure all settings are applied
3. Let me know it's done, and I'll continue with the next tasks

## Troubleshooting

If you encounter issues:
- Make sure Xcode is up to date (should be 16.4 or later for Swift 6.2)
- If configuration files don't appear in the dropdown, drag them from Finder into the Xcode project first
- If Swift 6 doesn't appear as an option, your Xcode might be too old