import Amplify
import AWSCognitoAuthPlugin
import AWSPluginsCore
import BackgroundTasks
import SwiftData
import SwiftUI
#if canImport(UIKit) && DEBUG
    import UIKit
#endif

@main
struct ClarityPulseApp: App {
    // MARK: - Properties

    let modelContainer: ModelContainer

    /// Detects if running in test environment using comprehensive checks
    private static var isRunningInTestEnvironment: Bool {
        // Check for TESTING compiler flag first (most reliable)
        #if TESTING
            return true
        #endif

        // Check 1: Direct test environment flags (works for unit tests)
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            return true
        }

        // Check 2: Test class availability (works for unit tests)
        if NSClassFromString("XCTestCase") != nil {
            return true
        }

        // Check 3: Bundle name contains test indicators (works for unit tests)
        if Bundle.main.bundlePath.hasSuffix(".xctest") {
            return true
        }

        // Check 4: Process name contains test indicators (works for both unit and UI tests)
        let processName = ProcessInfo.processInfo.processName
        if processName.contains("Test") || processName.contains("-Runner") {
            return true
        }

        // Check 5: Look for UI test environment indicators
        if
            ProcessInfo.processInfo.environment["XCUITestMode"] != nil ||
            ProcessInfo.processInfo.environment["XCTEST_SESSION_ID"] != nil {
            return true
        }

        // Check 6: Arguments contain test indicators (works for UI tests)
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains(where: { $0.contains("XCTest") || $0.contains("UITest") }) {
            return true
        }

        // Check 7: Special case for simulator launched by test runner
        if
            ProcessInfo.processInfo.environment["SIMULATOR_UDID"] != nil,
            arguments.contains(where: { $0.contains("-XCTest") || $0.contains("-UITest") }) {
            return true
        }

        // Check 8: UI Test specific - check for test bundle injection
        if ProcessInfo.processInfo.environment["DYLD_INSERT_LIBRARIES"]?.contains("XCTestBundleInject") == true {
            return true
        }

        // Check 9: UI Test specific - check for test session identifier
        if ProcessInfo.processInfo.environment["XCTestSessionIdentifier"] != nil {
            return true
        }

        return false
    }

    // By using the @State property wrapper, we ensure that the AuthViewModel
    // is instantiated only once for the entire lifecycle of the app.
    @State private var authViewModel: AuthViewModel

    // The APIClient and services are instantiated here and injected into the environment.
    private let authService: AuthServiceProtocol
    private let healthKitService: HealthKitServiceProtocol
    private let apiClient: APIClientProtocol
    private let insightsRepository: InsightsRepositoryProtocol
    private let healthDataRepository: HealthDataRepositoryProtocol
    private let backgroundTaskManager: BackgroundTaskManagerProtocol
    private let offlineQueueManager: OfflineQueueManagerProtocol

    // MARK: - Initializer

    init() {
        // Configure Amplify, but skip during test execution to prevent crashes
        let isTest = Self.isRunningInTestEnvironment
        if !isTest {
            AmplifyConfigurator.configure()
        }

        // Initialize SwiftData ModelContainer
        do {
            if isTest {
                // For tests, use the test container which should be simpler
                self.modelContainer = try SwiftDataConfigurator.shared.createTestContainer()
                print("✅ Created test ModelContainer")
            } else {
                // Production container with full schema
                self.modelContainer = try SwiftDataConfigurator.shared.createModelContainer()
                print("✅ Created production ModelContainer")
            }
        } catch {
            // For tests only, provide a more detailed error and continue with a dummy container
            if isTest {
                print("❌ Test ModelContainer creation failed: \(error)")
                print("❌ This is expected if models aren't included in test target")
                
                // Create a dummy container that won't be used but satisfies the property requirement
                // This is a workaround for test execution
                let dummySchema = Schema([])
                let dummyConfig = ModelConfiguration(
                    schema: dummySchema,
                    isStoredInMemoryOnly: true,
                    allowsSave: false
                )
                
                do {
                    self.modelContainer = try ModelContainer(
                        for: dummySchema,
                        configurations: [dummyConfig]
                    )
                    print("✅ Created dummy ModelContainer for tests")
                } catch {
                    print("⚠️ Cannot create even dummy ModelContainer: \(error)")
                    print("⚠️ Tests will run without SwiftData support")
                    // As absolute last resort, create container with TestOnlyModel
                    self.modelContainer = try! ModelContainer(for: TestOnlyModel.self)
                }
            } else {
                print("❌ Production ModelContainer creation failed: \(error)")
                print("🔄 Creating fallback in-memory container...")
                
                // 🔥 CRITICAL FIX: Create fallback in-memory container instead of crashing
                let fallbackSchema = Schema([
                    HealthMetric.self,
                    UserProfileModel.self,
                    PATAnalysis.self,
                    AIInsight.self
                ])
                
                let fallbackConfig = ModelConfiguration(
                    schema: fallbackSchema,
                    isStoredInMemoryOnly: true,
                    allowsSave: true
                )
                
                do {
                    self.modelContainer = try ModelContainer(
                        for: fallbackSchema,
                        configurations: [fallbackConfig]
                    )
                    print("✅ Created fallback in-memory ModelContainer")
                } catch {
                    print("🚨 Even fallback failed, using minimal container")
                    // Last resort - minimal container
                    self.modelContainer = try! ModelContainer(for: TestOnlyModel.self)
                }
            }
        }

        // Initialize the BackendAPIClient with proper token provider
        // Use safe fallback for background launch compatibility
        let client: APIClientProtocol
        if
            let backendClient = BackendAPIClient(tokenProvider: {
                // Skip Amplify Auth during tests to prevent crashes
                if Self.isRunningInTestEnvironment {
                    return "mock-test-token"
                }

                // Use Amplify Auth to get token
                do {
                    let authSession = try await Amplify.Auth.fetchAuthSession()

                    if let cognitoTokenProvider = authSession as? AuthCognitoTokensProvider {
                        let tokens = try cognitoTokenProvider.getCognitoTokens().get()
                        let token = tokens.accessToken
                        return token
                    }
                } catch {
                    // Silently fail - Amplify will handle retry
                }

                return nil
            }) {
            client = backendClient
        } else {
            // Fallback to dummy client instead of crashing
            client = DummyAPIClient()
        }

        self.apiClient = client
        
        // Initialize user data service
        let userDataService = UserDataService(modelContext: modelContainer.mainContext)

        // Initialize services with shared APIClient
        let service = AuthService(apiClient: client, userDataService: userDataService)
        self.authService = service

        // TokenManagementService no longer needed - using Amplify Auth

        let healthKit = HealthKitService(apiClient: client)
        self.healthKitService = healthKit

        // Initialize repositories with shared APIClient
        self.insightsRepository = RemoteInsightsRepository(apiClient: client)
        self.healthDataRepository = RemoteHealthDataRepository(apiClient: client)

        // Initialize service locator for background tasks
        ServiceLocator.shared.healthKitService = healthKitService
        ServiceLocator.shared.healthDataRepository = healthDataRepository
        ServiceLocator.shared.insightsRepository = insightsRepository

        // Initialize background task manager
        self.backgroundTaskManager = BackgroundTaskManager(
            healthKitService: healthKitService,
            healthDataRepository: healthDataRepository
        )

        // Register background tasks
        backgroundTaskManager.registerBackgroundTasks()

        // Initialize offline queue manager
        let queueManager = OfflineQueueManager(
            modelContext: modelContainer.mainContext,
            healthDataRepository: healthDataRepository,
            insightsRepository: insightsRepository
        )
        self.offlineQueueManager = queueManager

        // Connect offline queue manager to HealthKitService
        healthKit.setOfflineQueueManager(queueManager)

        // Start offline queue monitoring
        offlineQueueManager.startMonitoring()

        // The AuthViewModel is created with the concrete AuthService instance.
        _authViewModel = State(initialValue: AuthViewModel(authService: service))
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            AppRootView(
                authService: authService,
                backgroundTaskManager: backgroundTaskManager
            )
            .onAppear {
                print("🔥 APP ROOT APPEARED")
                print("🔥 ENVIRONMENT AVAILABLE: AuthService type = \(type(of: authService))")
            }
            .modelContainer(modelContainer)
            .environment(authViewModel)
            .environment(\.authService, authService)
            .environment(\.healthKitService, healthKitService)
            .environment(\.apiClient, apiClient)
            .environment(\.insightsRepository, insightsRepository)
            .environment(\.healthDataRepository, healthDataRepository)
        }
    }
}

// MARK: - App Root View with Lifecycle Management

private struct AppRootView: View {
    let authService: AuthServiceProtocol
    let backgroundTaskManager: BackgroundTaskManagerProtocol

    @Environment(AuthViewModel.self) private var authViewModel

    var body: some View {
        ContentView()
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                // Schedule background tasks when app enters background
                backgroundTaskManager.scheduleHealthDataSync()
                backgroundTaskManager.scheduleAppRefresh()
            }
            .onChange(of: authViewModel.isLoggedIn) { _, newValue in
                // Update service locator with current user ID
                if newValue {
                    Task {
                        if let currentUser = await authService.currentUser {
                            ServiceLocator.shared.currentUserId = currentUser.id
                            
                            // 🔥 CRITICAL FIX: Setup HealthKit background sync after login
                            await setupHealthKitSyncAfterAuth()
                        }
                    }
                } else {
                    ServiceLocator.shared.currentUserId = nil
                }
            }
    }
    
    // 🔥 NEW: Critical HealthKit setup function
    @MainActor
    private func setupHealthKitSyncAfterAuth() async {
        guard let healthKitService = ServiceLocator.shared.healthKitService else {
            print("❌ HealthKitService not available in ServiceLocator")
            return
        }
        
        // Only set up if HealthKit is available
        guard healthKitService.isHealthDataAvailable() else {
            print("⚠️ HealthKit not available on this device")
            return
        }
        
        do {
            print("🚀 Setting up HealthKit background delivery...")
            try await healthKitService.enableBackgroundDelivery()
            print("✅ HealthKit background delivery enabled")
            
            print("🚀 Setting up HealthKit observer queries...")
            healthKitService.setupObserverQueries()
            print("✅ HealthKit observer queries set up")
            
        } catch {
            print("❌ Failed to setup HealthKit background sync: \(error)")
        }
    }
}
