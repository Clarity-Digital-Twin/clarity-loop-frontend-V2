//
//  ClarityPulseWrapperApp.swift
//  ClarityPulseWrapper
//
//  Created on 2025.
//  Copyright © 2025 CLARITY. All rights reserved.
//

import SwiftUI

@main
struct ClarityPulseWrapperApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    var body: some View {
        VStack(spacing: 40) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                Text("CLARITY")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)

                Text("Digital Twin Platform")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }

            // Features
            VStack(spacing: 20) {
                FeatureRow(icon: "heart.fill", title: "Health Monitoring", color: .red)
                FeatureRow(icon: "brain", title: "Mental Wellness", color: .purple)
                FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Analytics", color: .green)
                FeatureRow(icon: "person.crop.circle", title: "Concierge Care", color: .orange)
            }

            // Action Button
            Button(action: {
                print("🎯 App is working perfectly!")
            }) {
                Text("Get Started")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .onAppear {
            print("🎉 CLARITY app launched successfully!")
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 30)

            Text(title)
                .font(.body)
                .foregroundColor(.primary)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
}

// Preview
#Preview {
    ContentView()
}
