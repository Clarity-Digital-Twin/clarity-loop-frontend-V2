// swift-tools-version: 6.1
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "ClarityPulse",
    platforms: [
        .iOS(.v18)
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
            targets: ["ClarityUI"])
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
            path: "clarity-loop-frontend-v2/Core",
            exclude: []
        ),
        
        // Domain module - Business logic and models
        .target(
            name: "ClarityDomain",
            dependencies: ["ClarityCore"],
            path: "clarity-loop-frontend-v2/Domain",
            exclude: []
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
            exclude: []
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
            exclude: [],
            resources: [
                .process("Resources")
            ]
        ),
        
        // Test targets
        .testTarget(
            name: "ClarityCoreTests",
            dependencies: ["ClarityCore"],
            path: "clarity-loop-frontend-v2Tests/Core"
        ),
        .testTarget(
            name: "ClarityDomainTests",
            dependencies: ["ClarityDomain"],
            path: "clarity-loop-frontend-v2Tests/Domain"
        ),
        .testTarget(
            name: "ClarityDataTests",
            dependencies: ["ClarityData"],
            path: "clarity-loop-frontend-v2Tests/Data"
        ),
        .testTarget(
            name: "ClarityUITests",
            dependencies: ["ClarityUI"],
            path: "clarity-loop-frontend-v2Tests/UI"
        )
    ]
)
