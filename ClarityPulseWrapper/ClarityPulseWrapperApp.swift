//
//  ClarityPulseWrapperApp.swift
//  ClarityPulseWrapper
//
//  Minimal wrapper to create iOS app bundle from SPM package
//

import SwiftUI
import SwiftData
import ClarityUI
import ClarityCore
import ClarityDomain
import ClarityData

@main
struct ClarityPulseWrapperApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .configuredDependencies()
        }
    }
}