# CLARITY Frontend Testing Setup Guide

## Quick/Nimble Installation

Since this is an Xcode project, you'll need to add Quick and Nimble through Xcode's Swift Package Manager integration:

### Steps to Add Quick/Nimble:

1. **Open Xcode**
   ```bash
   open clarity-loop-frontend.xcodeproj
   ```

2. **Add Swift Packages**
   - Go to File → Add Package Dependencies
   - Add Quick: `https://github.com/Quick/Quick`
   - Add Nimble: `https://github.com/Quick/Nimble`
   - Select version: Latest (Quick 7.x, Nimble 13.x)
   - Add to test targets only

3. **Configure Test Targets**
   - Select clarity-loop-frontendTests target
   - Under "Frameworks and Libraries", ensure Quick and Nimble are added
   - Repeat for clarity-loop-frontendUITests if needed

## Alternative: Command Line Installation

If you prefer automation, we can create a Package.swift for test dependencies:

```swift
// Package.swift (for test dependencies only)
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ClarityTestDependencies",
    platforms: [
        .iOS(.v18)
    ],
    dependencies: [
        .package(url: "https://github.com/Quick/Quick", from: "7.0.0"),
        .package(url: "https://github.com/Quick/Nimble", from: "13.0.0"),
        .package(url: "https://github.com/typelift/SwiftCheck", from: "0.12.0"),
    ],
    targets: [
        .testTarget(
            name: "ClarityTests",
            dependencies: ["Quick", "Nimble", "SwiftCheck"]
        )
    ]
)
```

## Test File Template

Create your first BDD test:

```swift
import Quick
import Nimble
@testable import clarity_loop_frontend

class AuthServiceSpec: QuickSpec {
    override class func spec() {
        describe("AuthService") {
            var sut: AuthService!
            var mockAPIClient: MockAPIClient!
            
            beforeEach {
                mockAPIClient = MockAPIClient()
                sut = AuthService(apiClient: mockAPIClient)
            }
            
            afterEach {
                sut = nil
                mockAPIClient = nil
            }
            
            describe("login") {
                context("with valid credentials") {
                    it("returns user session") {
                        // Given
                        let expectedUser = UserSessionResponseDTO.mock()
                        mockAPIClient.loginResult = .success(LoginResponseDTO.mock(user: expectedUser))
                        
                        // When
                        let result = try await sut.signIn(withEmail: "test@example.com", password: "password123")
                        
                        // Then
                        expect(result.userId).to(equal(expectedUser.userId))
                        expect(mockAPIClient.loginCalled).to(beTrue())
                    }
                }
                
                context("with invalid credentials") {
                    it("throws authentication error") {
                        // Given
                        mockAPIClient.loginResult = .failure(APIError.unauthorized)
                        
                        // Then
                        await expect {
                            try await sut.signIn(withEmail: "wrong@example.com", password: "wrong")
                        }.to(throwError(AuthenticationError.invalidCredentials))
                    }
                }
            }
        }
    }
}
```

## Next Steps

After installation:
1. Create mock infrastructure (Task #28)
2. Set up contract validation (Task #29)
3. Build test data generators (Task #30)

Run this command to verify installation:
```bash
xcodebuild test -scheme clarity-loop-frontendTests -destination 'platform=iOS Simulator,name=iPhone 16' | grep -E "(Quick|Nimble)"
```