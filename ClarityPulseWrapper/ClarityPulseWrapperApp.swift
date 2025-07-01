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

@main
struct ClarityPulseWrapperApp: App {
    @State private var appState = AppState()
    private let dependencies = Dependencies()
    
    init() {
        // Configure Dependencies properly - NO MORE BRIDGES!
        let configurator = AppDependencyConfigurator()
        configurator.configure(dependencies)
    }
    
    var body: some Scene {
        WindowGroup {
            LoginView()
                .environment(appState)
                .withDependencies(dependencies)
        }
    }
}
