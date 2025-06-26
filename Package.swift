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
        .package(url: "https://github.com/aws-amplify/amplify-swift.git", from: "2.48.1")
        // Add any additional dependencies here as needed
    ],
    targets: [
        // Core module - Infrastructure and shared utilities
        .target(
            name: "ClarityCore",
            dependencies: [],
            path: "clarity-loop-frontend-v2/Core"
        ),
        
        // Domain module - Business logic and models
        .target(
            name: "ClarityDomain",
            dependencies: ["ClarityCore"],
            path: "clarity-loop-frontend-v2/Domain"
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
            path: "clarity-loop-frontend-v2/Data"
        ),
        
        // UI module - SwiftUI views and view models
        .target(
            name: "ClarityUI",
            dependencies: [
                "ClarityCore",
                "ClarityDomain",
                "ClarityData"
            ],
            path: "clarity-loop-frontend-v2/UI",
            exclude: []
        ),
        
        // Test targets
        .testTarget(
            name: "ClarityDomainTests",
            dependencies: ["ClarityDomain"],
            path: "clarity-loop-frontend-v2Tests/Domain"
        ),
        .testTarget(
            name: "ClarityInfrastructureTests",
            dependencies: ["ClarityData", "ClarityDomain"],
            path: "clarity-loop-frontend-v2Tests/Infrastructure"
        ),
        .testTarget(
            name: "ClarityUITests",
            dependencies: ["ClarityUI", "ClarityDomain", "ClarityData"],
            path: "clarity-loop-frontend-v2Tests/UI"
        )
    ]
)
