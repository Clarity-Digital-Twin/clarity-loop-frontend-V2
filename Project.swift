import ProjectDescription

let project = Project(
    name: "clarity-loop-frontend",
    targets: [
        Target(
            name: "clarity-loop-frontend",
            platform: .iOS,
            product: .app,
            bundleId: "com.novamindnyc.clarity-loop-frontend",
            infoPlist: .extendingDefault(with: [
                "CFBundleDisplayName": "CLARITY Pulse",
                "NSHealthShareUsageDescription": "CLARITY Pulse reads your health data to provide personalized health insights.",
                "NSHealthUpdateUsageDescription": "CLARITY Pulse updates your health records to sync wellness data.",
                "UIBackgroundModes": ["fetch", "processing"],
                "NSFaceIDUsageDescription": "CLARITY Pulse uses Face ID to securely access your health data.",
            ]),
            sources: ["clarity-loop-frontend/**"],
            resources: ["clarity-loop-frontend/Resources/**"]
        ),
    ]
)
