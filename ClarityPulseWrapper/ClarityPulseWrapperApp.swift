//
//  ClarityPulseWrapperApp.swift
//  ClarityPulseWrapper
//
//  Minimal wrapper to create iOS app bundle from SPM package
//

import SwiftUI
import ClarityUI
import ClarityCore
import ClarityDomain
import ClarityData

@main
struct ClarityPulseWrapperApp: App {
    init() {
        // Initialize app dependencies
        AppDependencies().configure()
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .modelContainer(DIContainer.shared.require(ModelContainer.self))
                .environment(AppState())
        }
    }
}