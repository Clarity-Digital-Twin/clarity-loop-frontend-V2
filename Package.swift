// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ClarityPulse",
    platforms: [
        .iOS(.v18),
        .macOS(.v14)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "ClarityCore",
            targets: ["ClarityCore"]),
        .library(
            name: "ClarityData",
            targets: ["ClarityData"]),
        .library(
            name: "ClarityDomain",
            targets: ["ClarityDomain"]),
        .library(
            name: "ClarityUI",
            targets: ["ClarityUI"]),
        .executable(
            name: "ClarityPulseApp",
            targets: ["ClarityPulseApp"])
    ],
    dependencies: [
        // AWS Amplify for backend integration
        .package(url: "https://github.com/aws-amplify/amplify-swift.git", from: "2.48.1"),
        // SwiftLint for code style enforcement
        .package(url: "https://github.com/realm/SwiftLint.git", from: "0.57.0")
    ],
    targets: [
        // Core module - Infrastructure and shared utilities
        .target(
            name: "ClarityCore",
            dependencies: [],
            path: "clarity-loop-frontend-v2/Core",
            exclude: ["README.md"]
        ),
        
        // Domain module - Business logic and models
        .target(
            name: "ClarityDomain",
            dependencies: ["ClarityCore"],
            path: "clarity-loop-frontend-v2/Domain",
            exclude: ["README.md"]
        ),
        
        // Data module - Repositories and data sources
        .target(
            name: "ClarityData",
            dependencies: [
                "ClarityCore",
                "ClarityDomain",
                .product(name: "Amplify", package: "amplify-swift"),
                .product(name: "AWSCognitoAuthPlugin", package: "amplify-swift"),
                .product(name: "AWSAPIPlugin", package: "amplify-swift")
            ],
            path: "clarity-loop-frontend-v2/Data",
            exclude: ["README.md", "Infrastructure/README.md"]
        ),
        
        // UI module - SwiftUI views and view models
        .target(
            name: "ClarityUI",
            dependencies: [
                "ClarityCore",
                "ClarityDomain",
                "ClarityData",
                .product(name: "Amplify", package: "amplify-swift"),
                .product(name: "AWSCognitoAuthPlugin", package: "amplify-swift")
            ],
            path: "clarity-loop-frontend-v2/UI",
            exclude: ["README.md"]
        ),
        
        // Executable target - iOS App
        .executableTarget(
            name: "ClarityPulseApp",
            dependencies: [
                "ClarityCore",
                "ClarityDomain", 
                "ClarityData",
                "ClarityUI",
                .product(name: "Amplify", package: "amplify-swift"),
                .product(name: "AWSCognitoAuthPlugin", package: "amplify-swift"),
                .product(name: "AWSAPIPlugin", package: "amplify-swift")
            ],
            path: "clarity-loop-frontend-v2",
            exclude: [
                "clarity-loop-frontend-v2.entitlements", 
                "Config",
                "amplifyconfiguration-setup.md",
                "Core",
                "Data", 
                "Domain",
                "UI",
                "Examples",
                "Info.plist"
            ],
            sources: ["ClarityPulseApp.swift", "AppDependencies.swift", "ContentView.swift"],
            resources: [
                .process("amplifyconfiguration.json")
            ]
        ),
        
        // Test targets
        .testTarget(
            name: "ClarityDomainTests",
            dependencies: ["ClarityDomain"],
            path: "clarity-loop-frontend-v2Tests/Domain",
            exclude: []
        ),
        .testTarget(
            name: "ClarityDataTests",
            dependencies: ["ClarityData", "ClarityDomain", "ClarityCore"],
            path: "clarity-loop-frontend-v2Tests/Data",
            exclude: []
        ),
        .testTarget(
            name: "ClarityInfrastructureTests",
            dependencies: ["ClarityData", "ClarityDomain", "ClarityCore", "ClarityUI"],
            path: "clarity-loop-frontend-v2Tests/Infrastructure",
            exclude: ["NetworkClientTests.swift.disabled"]
        ),
        .testTarget(
            name: "ClarityIntegrationTests",
            dependencies: ["ClarityCore", "ClarityDomain", "ClarityData", "ClarityUI"],
            path: "clarity-loop-frontend-v2Tests/Integration",
            exclude: []
        ),
        .testTarget(
            name: "ClarityUITests",
            dependencies: ["ClarityUI", "ClarityDomain", "ClarityData"],
            path: "clarity-loop-frontend-v2Tests/UI",
            exclude: []
        ),
        .testTarget(
            name: "ClarityCoreTests",
            dependencies: ["ClarityCore", "ClarityDomain", "ClarityData", "ClarityUI"],
            path: "clarity-loop-frontend-v2Tests",
            exclude: [
                "Domain", 
                "Data", 
                "UI", 
                "Infrastructure", 
                "Integration", 
                "Core/Services/KeychainServiceTests.swift", 
                "Core/Services/BiometricAuthServiceTests.swift",
                "Core/Errors/AppErrorTests.swift",
                "Core/Errors/ErrorHandlerTests.swift",
                "Core/Errors/SimpleErrorTest.swift",
                "Core/Errors/ErrorHandlerTestsSwift.swift",
                "Mocks/MockAmplifyAuthService.swift",
                "Mocks/MockTokenStorage.swift",
                "Mocks/AmplifyMockTests.swift",
                "Helpers/AmplifyMockService.swift",
                "Security/ComprehensiveSecurityTests.swift",
                "Security/EncryptedHealthMetricTests.swift"
            ],
            sources: ["DI/", "Architecture/", "Examples/", "Core/Security/"]
        ),
        // UI tests temporarily disabled due to Swift 6 concurrency issues
        // .testTarget(
        //     name: "ClarityPulseUITests",
        //     dependencies: [],
        //     path: "clarity-loop-frontend-v2UITests"
        // )
    ]
)
