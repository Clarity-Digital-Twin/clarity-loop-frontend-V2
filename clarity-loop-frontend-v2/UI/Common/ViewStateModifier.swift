//
//  ViewStateModifier.swift
//  clarity-loop-frontend-v2
//
//  SwiftUI view modifiers for handling ViewState
//

import SwiftUI

/// View modifier that renders content based on ViewState
public struct ViewStateModifier<T: Equatable & Sendable, IdleView: View, LoadingView: View, EmptyView: View, ErrorView: View>: ViewModifier {
    let state: ViewState<T>
    let idleView: () -> IdleView
    let loadingView: () -> LoadingView
    let emptyView: () -> EmptyView
    let errorView: (Error) -> ErrorView
    let successView: (T) -> AnyView
    
    public func body(content: Content) -> some View {
        Group {
            switch state {
            case .idle:
                idleView()
            case .loading:
                loadingView()
            case .success(let value):
                successView(value)
            case .error(let error):
                errorView(error)
            case .empty:
                emptyView()
            }
        }
    }
}

// MARK: - View Extension

public extension View {
    /// Handle ViewState with custom views for each state
    ///
    /// Example:
    /// ```swift
    /// ContentView()
    ///     .viewState(
    ///         viewModel.state,
    ///         idle: { Text("Ready to load") },
    ///         loading: { ProgressView() },
    ///         empty: { Text("No data available") },
    ///         error: { error in Text("Error: \(error.localizedDescription)") }
    ///     ) { data in
    ///         List(data) { item in
    ///             Text(item.name)
    ///         }
    ///     }
    /// ```
    func viewState<T: Equatable & Sendable, IdleView: View, LoadingView: View, EmptyContentView: View, ErrorView: View, SuccessView: View>(
        _ state: ViewState<T>,
        idle: @escaping () -> IdleView = { SwiftUI.EmptyView() },
        loading: @escaping () -> LoadingView = { ProgressView() },
        empty: @escaping () -> EmptyContentView = { Text("No data") },
        error: @escaping (Error) -> ErrorView = { Text("Error: \($0.localizedDescription)") },
        success: @escaping (T) -> SuccessView
    ) -> some View {
        modifier(
            ViewStateModifier(
                state: state,
                idleView: idle,
                loadingView: loading,
                emptyView: empty,
                errorView: error,
                successView: { AnyView(success($0)) }
            )
        )
    }
    
    /// Handle ViewState with default views for non-success states
    ///
    /// Example:
    /// ```swift
    /// ContentView()
    ///     .viewState(viewModel.state) { users in
    ///         List(users) { user in
    ///             Text(user.name)
    ///         }
    ///     }
    /// ```
    func viewState<T: Equatable & Sendable, SuccessView: View>(
        _ state: ViewState<T>,
        success: @escaping (T) -> SuccessView
    ) -> some View {
        viewState(
            state,
            idle: { Color.clear },
            loading: { 
                VStack {
                    ProgressView()
                    Text("Loading...")
                        .foregroundColor(.secondary)
                }
            },
            empty: {
                VStack(spacing: 16) {
                    Image(systemName: "tray")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No data available")
                        .foregroundColor(.secondary)
                }
            },
            error: { error in
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundColor(.red)
                    Text("Error")
                        .font(.headline)
                    Text(error.localizedDescription)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            },
            success: success
        )
    }
}

// MARK: - Common Loading Views

/// A full-screen loading view with optional message
public struct LoadingView: View {
    let message: String?
    
    public init(message: String? = nil) {
        self.message = message
    }
    
    public var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            if let message = message {
                Text(message)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
    }
}

/// A full-screen error view with retry action
public struct ErrorView: View {
    let error: Error
    let retry: (() -> Void)?
    
    public init(error: Error, retry: (() -> Void)? = nil) {
        self.error = error
        self.retry = retry
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 64))
                .foregroundColor(.red)
            
            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text(error.localizedDescription)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if let retry = retry {
                Button(action: retry) {
                    Label("Try Again", systemImage: "arrow.clockwise")
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
    }
}

/// A full-screen empty state view
public struct EmptyStateView: View {
    let title: String
    let message: String?
    let systemImage: String
    let action: (() -> Void)?
    let actionTitle: String?
    
    public init(
        title: String,
        message: String? = nil,
        systemImage: String = "tray",
        action: (() -> Void)? = nil,
        actionTitle: String? = nil
    ) {
        self.title = title
        self.message = message
        self.systemImage = systemImage
        self.action = action
        self.actionTitle = actionTitle
    }
    
    public var body: some View {
        VStack(spacing: 24) {
            Image(systemName: systemImage)
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if let message = message {
                    Text(message)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            }
            
            if let action = action, let actionTitle = actionTitle {
                Button(action: action) {
                    Text(actionTitle)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(red: 0.95, green: 0.95, blue: 0.97))
    }
}