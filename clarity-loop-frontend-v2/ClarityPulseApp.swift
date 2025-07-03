//
//  ClarityPulseApp.swift
//  ClarityPulse
//
//  Created on 2025-06-25.
//  Copyright © 2025 CLARITY. All rights reserved.
//

import SwiftUI

@main
struct ClarityPulseApp: App {

    var body: some Scene {
        WindowGroup {
            // SUPER SIMPLE - NO AMPLIFY, NO COMPLEXITY
            VStack(spacing: 30) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)

                Text("CLARITY Digital Twin")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Concierge Psychiatry Platform")
                    .font(.title2)
                    .foregroundColor(.secondary)

                VStack(spacing: 16) {
                    Button("Sign In") {
                        print("🔐 Sign In tapped")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button("Create Account") {
                        print("👤 Create Account tapped")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button("Continue as Guest") {
                        print("👋 Guest mode tapped")
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }
                .padding(.top, 20)

                Spacer()

                Text("✅ App is working!")
                    .font(.caption)
                    .foregroundColor(.green)
            }
            .padding()
            .onAppear {
                print("🎯 CLARITY app launched successfully!")
                print("📱 UI is rendering correctly")
                print("🚀 Ready for user interaction")
            }
        }
    }
}
