//
//  ClarityPulseWrapperApp.swift
//  ClarityPulseWrapper
//
//  Minimal wrapper to create iOS app bundle from SPM package
//

import SwiftUI
import SwiftData
import ClarityCore
import ClarityDomain
import ClarityData
import ClarityUI
import Amplify

@main
struct ClarityPulseWrapperApp: App {
    @State private var appState = AppState()
    @State private var authenticationService: AuthenticationService?
    private let dependencies: Dependencies

    init() {
        // Configure dependencies ONCE
        let deps = Dependencies()
        let configurator = AppDependencyConfigurator()
        configurator.configure(deps)
        self.dependencies = deps

        print("✅ Dependencies configured successfully")
        print("📱 ClarityPulseWrapperApp initialized")

        // Debug: Check if amplifyconfiguration.json is in bundle
        if let path = Bundle.main.path(forResource: "amplifyconfiguration", ofType: "json") {
            print("✅ amplifyconfiguration.json found at: \(path)")
        } else {
            print("❌ amplifyconfiguration.json NOT found in bundle!")
            print("📁 Bundle path: \(Bundle.main.bundlePath)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
                .environment(appState)
                .environment(\.dependencies, dependencies)
                .environment(\.authenticationService, authenticationService)
                .task {
                    // Initialize authentication service
                    if authenticationService == nil,
                       let authService = dependencies.resolve(AuthServiceProtocol.self),
                       let userRepo = dependencies.resolve(UserRepositoryProtocol.self) {
                        authenticationService = AuthenticationService(
                            authService: authService,
                            userRepository: userRepo
                        )
                        print("✅ AuthenticationService initialized")
                    }
                }
        }
    }
}
