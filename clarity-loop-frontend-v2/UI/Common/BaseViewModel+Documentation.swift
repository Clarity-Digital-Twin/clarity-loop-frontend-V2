//
//  BaseViewModel+Documentation.swift
//  clarity-loop-frontend-v2
//
//  Extended documentation and usage examples for BaseViewModel
//

import Foundation
import SwiftUI

// MARK: - BaseViewModel Documentation

/**
 # BaseViewModel
 
 A base class for ViewModels that provides consistent state management and loading patterns
 for SwiftUI views in the CLARITY app.
 
 ## Overview
 
 `BaseViewModel` is designed to standardize how ViewModels handle asynchronous operations
 and state management. It uses the `@Observable` macro for automatic SwiftUI integration
 and implements the template method pattern for data loading.
 
 ## Key Features
 
 - **Automatic State Management**: Built-in `ViewState` property that tracks loading, success, error, and empty states
 - **Template Method Pattern**: Override `loadData()` to provide specific implementation
 - **Swift 6 Concurrency**: Full support for async/await and actor isolation
 - **SwiftUI Integration**: Works seamlessly with `@Observable` macro
 - **Error Handling**: Consistent error handling across all ViewModels
 - **Testability**: Easy to test with MockBaseViewModel
 
 ## State Transitions
 
 ```
 ┌──────┐
 │ Idle │ ──────────┐
 └──────┘           │
     ▲              ▼
     │         ┌─────────┐
     │         │ Loading │
     │         └─────────┘
     │              │
     │      ┌───────┴────────┬─────────────┐
     │      ▼                ▼             ▼
     │  ┌─────────┐     ┌───────┐    ┌───────┐
     └──│ Success │     │ Error │    │ Empty │
        └─────────┘     └───────┘    └───────┘
 ```
 
 ## Basic Usage
 
 ### 1. Create a ViewModel by extending BaseViewModel
 
 ```swift
 @Observable
 final class DashboardViewModel: BaseViewModel<DashboardData> {
     private let healthService: HealthServiceProtocol
     private let userRepository: UserRepositoryProtocol
     
     init(healthService: HealthServiceProtocol, userRepository: UserRepositoryProtocol) {
         self.healthService = healthService
         self.userRepository = userRepository
         super.init()
     }
     
     override func loadData() async throws -> DashboardData? {
         async let healthMetrics = healthService.fetchLatestMetrics()
         async let user = userRepository.getCurrentUser()
         
         let (metrics, currentUser) = try await (healthMetrics, user)
         
         guard let currentUser = currentUser else {
             return nil // Will set state to .empty
         }
         
         return DashboardData(user: currentUser, metrics: metrics)
     }
 }
 ```
 
 ### 2. Use in SwiftUI View
 
 ```swift
 struct DashboardView: View {
     @State private var viewModel: DashboardViewModel
     
     init(dependencies: Dependencies) {
         self._viewModel = State(wrappedValue: DashboardViewModel(
             healthService: dependencies.healthService,
             userRepository: dependencies.userRepository
         ))
     }
     
     var body: some View {
         Group {
             switch viewModel.viewState {
             case .idle:
                 Color.clear.onAppear {
                     Task { await viewModel.load() }
                 }
                 
             case .loading:
                 ProgressView("Loading dashboard...")
                 
             case .success(let data):
                 DashboardContent(data: data)
                 
             case .error(let error):
                 ErrorView(error: error) {
                     Task { await viewModel.reload() }
                 }
                 
             case .empty:
                 EmptyStateView(
                     message: "No data available",
                     action: {
                         Task { await viewModel.reload() }
                     }
                 )
             }
         }
     }
 }
 ```
 
 ## Advanced Usage
 
 ### Custom Error Handling
 
 ```swift
 @Observable
 final class LoginViewModel: BaseViewModel<User> {
     private let authService: AuthServiceProtocol
     
     override func loadData() async throws -> User? {
         // loadData is typically for fetching, not actions
         // For actions, create custom methods:
         fatalError("Use login() method instead")
     }
     
     @MainActor
     func login(email: String, password: String) async {
         viewState = .loading
         
         do {
             let token = try await authService.login(email: email, password: password)
             let user = try await authService.getCurrentUser(token: token)
             viewState = .success(user)
         } catch AuthError.invalidCredentials {
             viewState = .error(LoginError.invalidCredentials)
         } catch AuthError.networkError {
             viewState = .error(LoginError.noConnection)
         } catch {
             viewState = .error(error)
         }
     }
 }
 ```
 
 ### Combining Multiple Data Sources
 
 ```swift
 @Observable
 final class HealthSummaryViewModel: BaseViewModel<HealthSummary> {
     private let healthKit: HealthKitServiceProtocol
     private let backend: APIClientProtocol
     
     override func loadData() async throws -> HealthSummary? {
         // Fetch from multiple sources concurrently
         async let localData = healthKit.fetchTodaysSummary()
         async let remoteData = backend.get("/health/summary")
         
         do {
             let (local, remote) = try await (localData, remoteData)
             return HealthSummary.merge(local: local, remote: remote)
         } catch {
             // If remote fails, try to use local only
             if let local = try? await healthKit.fetchTodaysSummary() {
                 return HealthSummary(local: local)
             }
             throw error
         }
     }
 }
 ```
 
 ### Pagination Support
 
 ```swift
 @Observable
 final class MetricsListViewModel: BaseViewModel<[HealthMetric]> {
     private let repository: MetricsRepositoryProtocol
     private var currentPage = 1
     private var hasMorePages = true
     
     override func loadData() async throws -> [HealthMetric]? {
         currentPage = 1
         hasMorePages = true
         return try await repository.fetchMetrics(page: currentPage)
     }
     
     @MainActor
     func loadMore() async {
         guard hasMorePages, !isLoading else { return }
         
         do {
             let moreMetrics = try await repository.fetchMetrics(page: currentPage + 1)
             
             if moreMetrics.isEmpty {
                 hasMorePages = false
             } else {
                 currentPage += 1
                 if case .success(let current) = viewState {
                     viewState = .success(current + moreMetrics)
                 }
             }
         } catch {
             // Don't change main state for pagination errors
             print("Failed to load more: \(error)")
         }
     }
 }
 ```
 
 ## Testing
 
 ### Using MockBaseViewModel
 
 ```swift
 final class DashboardViewTests: XCTestCase {
     func test_dashboardView_showsLoadingState() async {
         // Given
         let mockViewModel = MockBaseViewModel<DashboardData>()
         mockViewModel.simulateLoading()
         
         // When
         let view = DashboardView(viewModel: mockViewModel)
         
         // Then
         XCTAssertTrue(view.isShowingProgressView)
     }
     
     func test_dashboardView_showsErrorState() async {
         // Given
         let mockViewModel = MockBaseViewModel<DashboardData>()
         mockViewModel.simulateError(TestError.networkError)
         
         // When
         let view = DashboardView(viewModel: mockViewModel)
         
         // Then
         XCTAssertTrue(view.isShowingErrorView)
     }
 }
 ```
 
 ### Testing Custom ViewModels
 
 ```swift
 final class LoginViewModelTests: XCTestCase {
     private var sut: LoginViewModel!
     private var mockAuthService: MockAuthService!
     
     override func setUp() {
         super.setUp()
         mockAuthService = MockAuthService()
         sut = LoginViewModel(authService: mockAuthService)
     }
     
     @MainActor
     func test_login_withValidCredentials_setsSuccessState() async {
         // Given
         let expectedUser = User(id: UUID(), email: "test@example.com")
         mockAuthService.mockUser = expectedUser
         
         // When
         await sut.login(email: "test@example.com", password: "password123")
         
         // Then
         XCTAssertEqual(sut.viewState, .success(expectedUser))
     }
 }
 ```
 
 ## Best Practices
 
 1. **Keep ViewModels Focused**: Each ViewModel should have a single responsibility
 2. **Use Dependency Injection**: Always inject dependencies through init
 3. **Handle All Error Cases**: Provide meaningful error states for users
 4. **Test State Transitions**: Ensure all state transitions are tested
 5. **Avoid Side Effects in loadData()**: Keep it pure for fetching data
 6. **Use @MainActor for UI Updates**: Ensure state changes happen on main thread
 
 ## Common Patterns
 
 ### Auto-Loading on Init
 
 ```swift
 @Observable
 final class AutoLoadingViewModel: BaseViewModel<Data> {
     override init(...) {
         super.init()
         Task { await load() }
     }
 }
 ```
 
 ### Refresh Control Integration
 
 ```swift
 struct ListView: View {
     @State private var viewModel: ListViewModel
     
     var body: some View {
         List {
             // content
         }
         .refreshable {
             await viewModel.reload()
         }
     }
 }
 ```
 
 ### Combining with @AppStorage
 
 ```swift
 @Observable
 final class SettingsViewModel: BaseViewModel<Settings> {
     @AppStorage("userId") private var userId: String?
     
     override func loadData() async throws -> Settings? {
         guard let userId = userId else { return nil }
         return try await settingsRepository.fetch(for: userId)
     }
 }
 ```
 
 ## See Also
 
 - ``ViewState``: The enum that represents different UI states
 - ``BaseViewModelProtocol``: The protocol that defines ViewModel requirements
 - ``MockBaseViewModel``: Mock implementation for testing
 */

// MARK: - Code Examples

enum BaseViewModelExamples {
    
    // Example data structures used in documentation
    struct DashboardData: Equatable {
        let user: User
        let metrics: [HealthMetric]
    }
    
    struct HealthSummary: Equatable {
        let steps: Int
        let calories: Int
        let activeMinutes: Int
        
        static func merge(local: HealthSummary?, remote: HealthSummary?) -> HealthSummary {
            // Implementation would merge local and remote data
            fatalError("Example only")
        }
        
        init(local: HealthSummary) {
            self = local
        }
    }
    
    struct User: Equatable, Identifiable {
        let id: UUID
        let email: String
    }
    
    struct HealthMetric: Equatable {
        let id: UUID
        let type: String
        let value: Double
        let timestamp: Date
    }
    
    struct Settings: Equatable {
        let notificationsEnabled: Bool
        let theme: String
    }
    
    enum LoginError: Error {
        case invalidCredentials
        case noConnection
    }
    
    enum AuthError: Error {
        case invalidCredentials
        case networkError
    }
}