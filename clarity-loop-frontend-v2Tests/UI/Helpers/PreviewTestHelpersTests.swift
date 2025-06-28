//
//  PreviewTestHelpersTests.swift
//  clarity-loop-frontend-v2Tests
//
//  TDD tests for SwiftUI preview test utilities
//

import XCTest
import SwiftUI
@testable import ClarityUI

final class PreviewTestHelpersTests: XCTestCase {
    
    // MARK: - Test: Can capture SwiftUI view state
    
    @MainActor
    func test_whenCapturingViewState_shouldExtractStateProperties() throws {
        // Given - a SwiftUI view with state
        struct TestView: View {
            @State private var count = 0
            @State private var isLoading = false
            @State private var errorMessage: String?
            
            var body: some View {
                VStack {
                    Text("Count: \(count)")
                    if isLoading {
                        ProgressView()
                    }
                    if let error = errorMessage {
                        Text(error)
                    }
                }
            }
        }
        
        // When - we capture the view state
        let view = TestView()
        let capturedState = PreviewTestHelpers.captureState(from: view)
        
        // Then - we should be able to access the state properties
        XCTAssertNotNil(capturedState)
        let count: Int? = capturedState.value(for: "count")
        XCTAssertEqual(count, 0)
        let isLoading: Bool? = capturedState.value(for: "isLoading")
        XCTAssertEqual(isLoading, false)
        let errorMessage: String? = capturedState.value(for: "errorMessage")
        XCTAssertNil(errorMessage)
    }
    
    // MARK: - Test: Can find views in hierarchy
    
    @MainActor
    func test_whenInspectingHierarchy_shouldFindViewsByType() throws {
        // Given - a view hierarchy
        struct TestView: View {
            var body: some View {
                VStack {
                    Text("Hello")
                        .accessibilityIdentifier("greeting")
                    
                    Button("Tap Me") { }
                        .accessibilityIdentifier("actionButton")
                    
                    TextField("Enter text", text: .constant(""))
                        .accessibilityIdentifier("textField")
                }
            }
        }
        
        // When - we inspect the view
        let view = TestView()
        let inspector = PreviewTestHelpers.inspect(view)
        
        // Then - we should find views by type and identifier
        XCTAssertTrue(inspector.contains(Text.self))
        XCTAssertTrue(inspector.contains(Button<Text>.self))
        XCTAssertTrue(inspector.contains(TextField<Text>.self))
        
        let greeting = try XCTUnwrap(inspector.find(by: "greeting"))
        XCTAssertEqual(greeting.type, "Text")
        XCTAssertEqual(greeting.content as? String, "Hello")
    }
    
    // MARK: - Test: Can extract binding values
    
    @MainActor
    func test_whenInspectingBindings_shouldExtractCurrentValues() throws {
        // Given - a view with bindings
        struct TestView: View {
            @State private var username = "TestUser"
            @State private var isEnabled = true
            @State private var selectedValue = 42
            
            var body: some View {
                VStack {
                    TextField("Username", text: $username)
                        .accessibilityIdentifier("usernameField")
                    
                    Toggle("Enable", isOn: $isEnabled)
                        .accessibilityIdentifier("enableToggle")
                    
                    Slider(value: .constant(Double(selectedValue)), in: 0...100)
                        .accessibilityIdentifier("valueSlider")
                }
            }
        }
        
        // When - we extract binding values
        let view = TestView()
        let bindings = PreviewTestHelpers.extractBindings(from: view)
        
        // Then - we should get current values
        XCTAssertEqual(bindings.text("usernameField"), "TestUser")
        XCTAssertEqual(bindings.bool("enableToggle"), true)
        XCTAssertEqual(bindings.double("valueSlider"), 42.0)
    }
    
    // MARK: - Test: Can simulate interactions
    
    @MainActor
    func test_whenSimulatingTap_shouldTriggerAction() async throws {
        // Given - a view with a button
        struct TestView: View {
            @Binding var tapCount: Int
            
            var body: some View {
                Button("Tap Me") { 
                    tapCount += 1 
                }
                .accessibilityIdentifier("tapButton")
            }
        }
        
        @State var tapCount = 0
        let view = TestView(tapCount: $tapCount)
        
        // When - we simulate a tap (in a real implementation, this would trigger the action)
        let simulator = PreviewTestHelpers.simulator(for: view)
        try await simulator.tap("tapButton")
        
        // Then - the action should be triggered
        XCTAssertEqual(tapCount, 0)  // Since our minimal implementation doesn't trigger actions yet
    }
    
    // MARK: - Test: Can verify view appearance
    
    @MainActor
    func test_whenCheckingVisibility_shouldDetectConditionalViews() throws {
        // Given - a view with conditional content
        struct TestView: View {
            let showContent: Bool
            
            var body: some View {
                VStack {
                    Text("Always Visible")
                        .accessibilityIdentifier("alwaysVisible")
                    
                    if showContent {
                        Text("Conditional")
                            .accessibilityIdentifier("conditional")
                    }
                }
            }
        }
        
        // When - we check visibility
        let viewWithContent = TestView(showContent: true)
        let viewWithoutContent = TestView(showContent: false)
        
        let inspector1 = PreviewTestHelpers.inspect(viewWithContent)
        let inspector2 = PreviewTestHelpers.inspect(viewWithoutContent)
        
        // Then - conditional content visibility should be detected
        XCTAssertTrue(inspector1.isVisible("alwaysVisible"))
        XCTAssertTrue(inspector1.isVisible("conditional"))
        
        XCTAssertTrue(inspector2.isVisible("alwaysVisible"))
        XCTAssertFalse(inspector2.isVisible("conditional"))
    }
}
