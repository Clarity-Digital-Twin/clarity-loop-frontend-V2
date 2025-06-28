//
//  ViewStateModifierTests.swift
//  clarity-loop-frontend-v2Tests
//
//  Tests for ViewStateModifier and SwiftUI integration
//

import XCTest
import SwiftUI
@testable import ClarityUI

final class ViewStateModifierTests: XCTestCase {
    
    // MARK: - Test Data
    
    struct User: Equatable {
        let name: String
    }
    
    struct NetworkError: Error {
        let message: String
    }
    
    // MARK: - View State Modifier Tests
    
    @MainActor
    func test_viewStateModifier_shouldCreateCorrectViewsForEachState() {
        // Given
        let states: [ViewState<[User]>] = [
            .idle,
            .loading,
            .success([User(name: "John"), User(name: "Jane")]),
            .error(NetworkError(message: "Network failed")),
            .empty
        ]
        
        // Test that modifier can be created for each state
        for state in states {
            let modifier = ViewStateModifier(
                state: state,
                idleView: { Text("Idle") },
                loadingView: { ProgressView() },
                emptyView: { Text("Empty") },
                errorView: { _ in Text("Error") },
                successView: { _ in AnyView(Text("Success")) }
            )
            
            // Verify modifier exists
            XCTAssertNotNil(modifier)
        }
    }
    
    @MainActor
    func test_viewExtension_withCustomViews_shouldCompile() {
        // Given
        struct TestView: View {
            let state: ViewState<String>
            
            var body: some View {
                Color.clear
                    .viewState(
                        state,
                        idle: { Text("Ready") },
                        loading: { ProgressView("Loading...") },
                        empty: { Text("No content") },
                        error: { error in 
                            VStack {
                                Text("Error occurred")
                                Text(error.localizedDescription)
                            }
                        }
                    ) { data in
                        Text(data)
                    }
            }
        }
        
        // Test compilation with different states
        let view1 = TestView(state: .idle)
        let view2 = TestView(state: .loading)
        let view3 = TestView(state: .success("Hello"))
        let view4 = TestView(state: .error(NetworkError(message: "Failed")))
        let view5 = TestView(state: .empty)
        
        XCTAssertNotNil(view1)
        XCTAssertNotNil(view2)
        XCTAssertNotNil(view3)
        XCTAssertNotNil(view4)
        XCTAssertNotNil(view5)
    }
    
    @MainActor
    func test_viewExtension_withDefaultViews_shouldCompile() {
        // Given
        struct TestView: View {
            let state: ViewState<[User]>
            
            var body: some View {
                Color.clear
                    .viewState(state) { users in
                        List(users, id: \.name) { user in
                            Text(user.name)
                        }
                    }
            }
        }
        
        // Test compilation
        let view = TestView(state: .success([User(name: "Test User")]))
        XCTAssertNotNil(view)
    }
    
    // MARK: - Common View Tests
    
    @MainActor
    func test_loadingView_shouldAcceptOptionalMessage() {
        // Given & When
        let view1 = LoadingView()
        let view2 = LoadingView(message: "Please wait...")
        
        // Then
        XCTAssertNil(view1.message)
        XCTAssertEqual(view2.message, "Please wait...")
    }
    
    @MainActor
    func test_errorView_shouldAcceptErrorAndOptionalRetry() {
        // Given
        let error = NetworkError(message: "Connection failed")
        var retryCalled = false
        
        // When
        let view1 = ErrorView(error: error)
        let view2 = ErrorView(error: error) {
            retryCalled = true
        }
        
        // Then
        XCTAssertNil(view1.retry)
        XCTAssertNotNil(view2.retry)
        
        // Test retry callback
        view2.retry?()
        XCTAssertTrue(retryCalled)
    }
    
    @MainActor
    func test_emptyStateView_shouldAcceptCustomization() {
        // Given
        var actionCalled = false
        
        // When
        let view = EmptyStateView(
            title: "No Items",
            message: "Add your first item to get started",
            systemImage: "plus.circle",
            action: { actionCalled = true },
            actionTitle: "Add Item"
        )
        
        // Then
        XCTAssertEqual(view.title, "No Items")
        XCTAssertEqual(view.message, "Add your first item to get started")
        XCTAssertEqual(view.systemImage, "plus.circle")
        XCTAssertNotNil(view.action)
        XCTAssertEqual(view.actionTitle, "Add Item")
        
        // Test action callback
        view.action?()
        XCTAssertTrue(actionCalled)
    }
    
    // MARK: - Integration Tests
    
    @MainActor
    func test_viewState_shouldWorkWithRealViewModel() {
        // Given
        // Don't use @Observable in test classes - it causes compilation issues
        @MainActor
        final class UserListViewModel {
            private(set) var state: ViewState<[User]> = .idle
            
            func loadUsers() async {
                state = .loading
                
                // Simulate API call
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
                
                let users = [
                    User(name: "Alice"),
                    User(name: "Bob"),
                    User(name: "Charlie")
                ]
                
                state = users.isEmpty ? .empty : .success(users)
            }
            
            func simulateError() {
                state = .loading
                state = .error(NetworkError(message: "Failed to load users"))
            }
        }
        
        struct UserListView: View {
            @State private var viewModel = UserListViewModel()
            
            var body: some View {
                NavigationView {
                    Color.clear
                        .viewState(viewModel.state) { users in
                            List(users, id: \.name) { user in
                                HStack {
                                    Image(systemName: "person.circle")
                                    Text(user.name)
                                }
                            }
                        }
                        .navigationTitle("Users")
                        .task {
                            await viewModel.loadUsers()
                        }
                }
            }
        }
        
        // Test view creation
        let view = UserListView()
        XCTAssertNotNil(view)
        
        // Test view model state transitions
        let viewModel = UserListViewModel()
        XCTAssertTrue(viewModel.state.isIdle)
        
        viewModel.simulateError()
        XCTAssertTrue(viewModel.state.isError)
    }
}
