//
//  ViewState+Documentation.swift
//  clarity-loop-frontend-v2
//
//  Usage documentation and examples for ViewState pattern
//

import SwiftUI
import ClarityDomain

/// # ViewState Pattern Documentation
///
/// ViewState is a generic enum that standardizes async state handling across the app.
/// It ensures consistent UI behavior and user experience for all async operations.
///
/// ## Core States
///
/// - **idle**: Initial state before any operation
/// - **loading**: Operation in progress
/// - **success(T)**: Operation completed with data
/// - **error(Error)**: Operation failed
/// - **empty**: Operation completed but no data
///
/// ## Basic Usage in ViewModels
///
/// ```swift
/// @Observable
/// final class DashboardViewModel {
///     private(set) var metricsState: ViewState<[HealthMetric]> = .idle
///     
///     private let repository: HealthMetricRepositoryProtocol
///     
///     init(repository: HealthMetricRepositoryProtocol) {
///         self.repository = repository
///     }
///     
///     func loadMetrics() async {
///         metricsState = .loading
///         
///         do {
///             let metrics = try await repository.fetchRecentMetrics()
///             metricsState = metrics.isEmpty ? .empty : .success(metrics)
///         } catch {
///             metricsState = .error(error)
///         }
///     }
/// }
/// ```
///
/// ## Usage in SwiftUI Views
///
/// ### With Default Views
///
/// ```swift
/// struct DashboardView: View {
///     @State private var viewModel: DashboardViewModel
///     
///     var body: some View {
///         NavigationStack {
///             Color.clear
///                 .viewState(viewModel.metricsState) { metrics in
///                     MetricsList(metrics: metrics)
///                 }
///                 .navigationTitle("Dashboard")
///                 .task {
///                     await viewModel.loadMetrics()
///                 }
///         }
///     }
/// }
/// ```
///
/// ### With Custom Views
///
/// ```swift
/// struct CustomStateView: View {
///     let state: ViewState<User>
///     
///     var body: some View {
///         Color.clear
///             .viewState(
///                 state,
///                 idle: {
///                     Text("Welcome")
///                         .font(.largeTitle)
///                 },
///                 loading: {
///                     VStack {
///                         ProgressView()
///                             .scaleEffect(2)
///                         Text("Loading your profile...")
///                             .padding(.top)
///                     }
///                 },
///                 empty: {
///                     EmptyStateView(
///                         title: "No Profile Found",
///                         message: "Please complete your profile setup",
///                         systemImage: "person.crop.circle.badge.plus",
///                         action: { /* setup profile */ },
///                         actionTitle: "Setup Profile"
///                     )
///                 },
///                 error: { error in
///                     ErrorView(error: error) {
///                         // Retry action
///                     }
///                 }
///             ) { user in
///                 UserProfileView(user: user)
///             }
///     }
/// }
/// ```
///
/// ## Advanced Patterns
///
/// ### Multiple Async States
///
/// ```swift
/// @Observable
/// final class ComplexViewModel {
///     private(set) var userState: ViewState<User> = .idle
///     private(set) var metricsState: ViewState<[HealthMetric]> = .idle
///     private(set) var goalsState: ViewState<[Goal]> = .idle
///     
///     var isAnyLoading: Bool {
///         userState.isLoading || metricsState.isLoading || goalsState.isLoading
///     }
///     
///     var hasAnyError: Bool {
///         userState.isError || metricsState.isError || goalsState.isError
///     }
/// }
/// ```
///
/// ### State Transformation
///
/// ```swift
/// // Transform data type while preserving state
/// let numberState: ViewState<Int> = .success(42)
/// let stringState: ViewState<String> = numberState.map { "The answer is \($0)" }
/// // Result: .success("The answer is 42")
/// ```
///
/// ### Combining States
///
/// ```swift
/// extension ViewState {
///     /// Combine two ViewStates into a tuple
///     static func combine<U: Equatable>(
///         _ first: ViewState<T>,
///         _ second: ViewState<U>
///     ) -> ViewState<(T, U)> {
///         switch (first, second) {
///         case (.success(let a), .success(let b)):
///             return .success((a, b))
///         case (.loading, _), (_, .loading):
///             return .loading
///         case (.error(let e), _), (_, .error(let e)):
///             return .error(e)
///         case (.empty, _), (_, .empty):
///             return .empty
///         default:
///             return .idle
///         }
///     }
/// }
/// ```
///
/// ## Best Practices
///
/// 1. **Always start with .idle**: Initialize ViewState properties as .idle
///
/// 2. **Set .loading before async operations**: Shows immediate UI feedback
///
/// 3. **Handle empty states**: Distinguish between no data and errors
///
/// 4. **Provide retry actions**: For error states, offer retry functionality
///
/// 5. **Use appropriate error messages**: Transform technical errors to user-friendly messages
///
/// 6. **Avoid nested ViewStates**: Don't use ViewState<ViewState<T>>
///
/// 7. **Keep success data immutable**: Use `private(set)` for ViewState properties
///
/// ## Testing ViewState
///
/// ```swift
/// func testLoadMetrics_Success() async {
///     // Given
///     let mockRepo = MockHealthMetricRepository()
///     mockRepo.metricsToReturn = [/* test data */]
///     let viewModel = DashboardViewModel(repository: mockRepo)
///     
///     // When
///     await viewModel.loadMetrics()
///     
///     // Then
///     XCTAssertTrue(viewModel.metricsState.isSuccess)
///     XCTAssertEqual(viewModel.metricsState.value?.count, 3)
/// }
///
/// func testLoadMetrics_Error() async {
///     // Given
///     let mockRepo = MockHealthMetricRepository()
///     mockRepo.errorToThrow = NetworkError.offline
///     let viewModel = DashboardViewModel(repository: mockRepo)
///     
///     // When
///     await viewModel.loadMetrics()
///     
///     // Then
///     XCTAssertTrue(viewModel.metricsState.isError)
///     XCTAssertNotNil(viewModel.metricsState.error)
/// }
/// ```

// MARK: - Example Views

/// Example: Login Flow with ViewState
struct LoginExample: View {
    @Observable
    final class LoginViewModel {
        private(set) var loginState: ViewState<User> = .idle
        
        private let loginUseCase: LoginUseCaseProtocol
        
        init(loginUseCase: LoginUseCaseProtocol) {
            self.loginUseCase = loginUseCase
        }
        
        @MainActor
        func login(email: String, password: String) async {
            loginState = .loading
            
            do {
                let user = try await loginUseCase.execute(
                    email: email,
                    password: password
                )
                loginState = .success(user)
            } catch {
                loginState = .error(error)
            }
        }
    }
    
    @State private var email = ""
    @State private var password = ""
    @State private var viewModel: LoginViewModel
    
    var body: some View {
        VStack {
            // Login form
            TextField("Email", text: $email)
            SecureField("Password", text: $password)
            
            Button("Login") {
                Task {
                    await viewModel.login(email: email, password: password)
                }
            }
            .disabled(viewModel.loginState.isLoading)
            
            // State-based UI
            switch viewModel.loginState {
            case .idle:
                EmptyView()
            case .loading:
                ProgressView("Signing in...")
            case .success(let user):
                Text("Welcome, \(user.firstName)!")
            case .error(let error):
                Text(error.localizedDescription)
                    .foregroundColor(.red)
            case .empty:
                EmptyView() // Won't happen in login
            }
        }
        .padding()
    }
}

/// Example: Data List with ViewState
struct MetricsListExample: View {
    @State private var metricsState: ViewState<[HealthMetric]> = .idle
    
    var body: some View {
        NavigationStack {
            Color.clear
                .viewState(
                    metricsState,
                    empty: {
                        EmptyStateView(
                            title: "No Health Metrics",
                            message: "Start tracking your health to see metrics here",
                            systemImage: "heart.text.square",
                            action: { /* start tracking */ },
                            actionTitle: "Start Tracking"
                        )
                    }
                ) { metrics in
                    List(metrics) { metric in
                        ExampleMetricRow(metric: metric)
                    }
                }
                .navigationTitle("Health Metrics")
                .refreshable {
                    await loadMetrics()
                }
                .task {
                    if metricsState.isIdle {
                        await loadMetrics()
                    }
                }
        }
    }
    
    private func loadMetrics() async {
        // Implementation
    }
}

// Placeholder types for examples
private struct ExampleMetricRow: View {
    let metric: HealthMetric
    var body: some View { Text("Metric") }
}
