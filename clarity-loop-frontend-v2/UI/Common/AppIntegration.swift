//
//  AppIntegration.swift
//  clarity-loop-frontend-v2
//
//  Example of SwiftUI App integration with Environment DI
//

import SwiftUI
import ClarityCore
import ClarityDomain
import ClarityData

/// Example of how to integrate dependencies in the main App struct
///
/// Usage in ClarityPulseApp.swift:
/// ```swift
/// @main
/// struct ClarityPulseApp: App {
///     var body: some Scene {
///         WindowGroup {
///             RootView()
///                 .configuredDependencies()
///         }
///     }
/// }
/// ```
public struct DependencyInjectedApp: View {
    @StateObject private var dependencies = Dependencies()

    public init() {}

    public var body: some View {
        ContentView()
            .onAppear {
                // Configure dependencies on app launch
                let configurator = AppDependencyConfigurator()
                configurator.configure(dependencies)
            }
            .dependencies(dependencies)
    }
}

// MARK: - Example ContentView

private struct ContentView: View {
    @Environment(\.dependencies) private var dependencies
    @Environment(\.authService) private var authService
    @Environment(\.userRepository) private var userRepository

    var body: some View {
        Text("Dependencies Configured")
            .onAppear {
                // Example of accessing dependencies
                print("Auth service available: \(type(of: authService))")

                // Or through the container
                if let repo = dependencies.resolve(UserRepositoryProtocol.self) {
                    print("User repository available: \(type(of: repo))")
                }
            }
    }
}

// MARK: - View Model Factory Pattern

/// Example of creating ViewModels with dependencies from environment
public struct ViewModelFactory {
    let dependencies: Dependencies

    public init(dependencies: Dependencies) {
        self.dependencies = dependencies
    }

    @MainActor
    public func makeLoginViewModel() -> LoginViewModel {
        LoginViewModel(
            loginUseCase: dependencies.require(LoginUseCaseProtocol.self)
        )
    }

    @MainActor
    public func makeDashboardViewModel(for user: User) -> DashboardViewModel {
        DashboardViewModel(
            user: user,
            healthMetricRepository: dependencies.require(HealthMetricRepositoryProtocol.self)
        )
    }
}

// MARK: - Environment View Model Factory

public struct ViewModelFactoryKey: EnvironmentKey {
    nonisolated(unsafe) public static let defaultValue: ViewModelFactory? = nil
}

public extension EnvironmentValues {
    var viewModelFactory: ViewModelFactory? {
        get { self[ViewModelFactoryKey.self] }
        set { self[ViewModelFactoryKey.self] = newValue }
    }
}

public extension View {
    /// Inject view model factory into the environment
    func viewModelFactory(_ factory: ViewModelFactory) -> some View {
        self.environment(\.viewModelFactory, factory)
    }
}

// MARK: - Test Support

public extension Dependencies {
    /// Create test dependencies with mocked services
    static func test(configure: (Dependencies) -> Void = { _ in }) -> Dependencies {
        let dependencies = Dependencies()

        // Register default test doubles
        dependencies.register(APIClientProtocol.self) {
            MockAPIClient()
        }

        dependencies.register(PersistenceServiceProtocol.self) {
            MockPersistenceService()
        }

        // Allow custom configuration
        configure(dependencies)

        return dependencies
    }
}

// MARK: - Mock Services for Testing

private struct MockAPIClient: APIClientProtocol {
    func get<T: Decodable>(_ endpoint: String, parameters: [String: String]?) async throws -> T {
        throw NetworkError.offline
    }

    func post<T: Decodable, U: Encodable>(_ endpoint: String, body: U) async throws -> T {
        throw NetworkError.offline
    }

    func put<T: Decodable, U: Encodable>(_ endpoint: String, body: U) async throws -> T {
        throw NetworkError.offline
    }

    func delete<T: Decodable>(_ endpoint: String) async throws -> T {
        throw NetworkError.offline
    }

    func delete<T: Identifiable>(type: T.Type, id: T.ID) async throws {
        throw NetworkError.offline
    }
}

private struct MockPersistenceService: PersistenceServiceProtocol {
    func save<T: Identifiable>(_ object: T) async throws {}
    func fetch<T: Identifiable>(_ id: T.ID) async throws -> T? { nil }
    func delete<T: Identifiable>(type: T.Type, id: T.ID) async throws {}
    func fetchAll<T: Identifiable>() async throws -> [T] { [] }
}
