# ClarityPulse iOS App Wrapper

This is a minimal Xcode wrapper project that creates an iOS app bundle from our Swift Package.

## Why This Exists

- Pure SPM's `.iOSApplication` product is still experimental/beta
- This wrapper provides a stable, production-ready iOS app target
- Only 4 files needed to create a full iOS app

## Setup

1. Install xcodegen if needed: `brew install xcodegen`
2. Generate the Xcode project: `xcodegen generate`
3. Open `ClarityPulseWrapper.xcodeproj` in Xcode
4. Run on simulator with ⌘R

## What's in This Folder

- `ClarityPulseWrapperApp.swift` - The @main app entry point
- `project.yml` - Xcodegen configuration
- `.gitignore` - Keeps generated files out of git
- This README

The actual app code lives in the parent Swift Package.