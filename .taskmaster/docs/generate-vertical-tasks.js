// Generate comprehensive vertical slice tasks for CLARITY Pulse V2
const fs = require('fs');

const tasks = [];
let taskId = 1;

// Helper to create task
function createTask(title, description, details, testStrategy, dependencies = [], priority = 'medium') {
  return {
    id: taskId++,
    title,
    description,
    details,
    testStrategy,
    priority,
    dependencies,
    status: 'pending',
    subtasks: []
  };
}

// SLICE 0: FOUNDATION (Tasks 1-30)
tasks.push(createTask(
  'Create iOS Project with SwiftUI',
  'Initialize new Xcode project with iOS 18.0 target, SwiftUI interface, and Swift 5.10+',
  '1. Open Xcode 16+\n2. Create new App project\n3. Set product name: ClarityPulse\n4. Set organization identifier: com.clarity.pulse\n5. Choose SwiftUI interface\n6. Set minimum deployment: iOS 18.0\n7. Language: Swift 5.10+\n8. Include Tests',
  'Build project successfully, verify Info.plist shows iOS 18.0 minimum',
  [],
  'high'
));

tasks.push(createTask(
  'Configure Git Repository',
  'Set up version control with appropriate .gitignore for iOS/Swift projects',
  '1. Initialize git repository\n2. Create .gitignore using gitignore.io template for Swift, Xcode, macOS\n3. Add .DS_Store, xcuserdata/, build/, DerivedData/\n4. Commit initial project structure',
  'Verify build artifacts are not tracked, .gitignore works correctly',
  [1],
  'high'
));

tasks.push(createTask(
  'Create Clean Architecture Structure',
  'Set up four-layer architecture: UI, Domain, Data, Infrastructure',
  '1. Create group folders in Xcode:\n   - UI/ (views, viewmodels)\n   - Domain/ (entities, use cases, protocols)\n   - Data/ (repositories, DTOs)\n   - Infrastructure/ (network, persistence, services)\n2. Add README.md to each explaining purpose\n3. Update project structure to match',
  'Verify folder structure exists and is properly organized',
  [1],
  'high'
));

tasks.push(createTask(
  'Configure Code Style Tools',
  'Install and configure SwiftLint for consistent code style',
  '1. Add SwiftLint via Swift Package Manager\n2. Create .swiftlint.yml with rules:\n   - line_length: 120\n   - type_body_length: 300\n   - file_length: 500\n   - disabled_rules: [trailing_whitespace]\n3. Add Build Phase script\n4. Fix initial violations',
  'Run SwiftLint and verify it catches violations, build fails on errors',
  [2],
  'high'
));

tasks.push(createTask(
  'Create Test Infrastructure',
  'Set up unit, integration, and UI test targets with base classes',
  '1. Verify test targets exist (created with project)\n2. Create BaseTestCase.swift for common functionality\n3. Create MockGenerator.swift for test data\n4. Create AsyncTestCase.swift for async testing\n5. Set up test schemes',
  'Write meta-test that verifies test infrastructure works',
  [3],
  'high'
));

// Continue with remaining foundation tasks...
tasks.push(createTask(
  'Configure Code Coverage',
  'Enable code coverage reporting with 80% minimum target',
  '1. Edit scheme -> Test -> Options\n2. Enable "Gather coverage for all targets"\n3. Create coverage report script\n4. Add pre-commit hook to check coverage\n5. Document coverage requirements',
  'Write test with known coverage, verify report shows correct percentage',
  [5],
  'high'
));

tasks.push(createTask(
  'Implement SwiftData Core',
  'Create ModelContainer and basic persistence setup',
  '1. Import SwiftData framework\n2. Create Infrastructure/Persistence/ModelContainerFactory.swift\n3. Implement ModelContainer with configuration\n4. Set up in-memory configuration for tests\n5. Add to App environment',
  'Test ModelContainer initializes without errors, can save/fetch data',
  [3],
  'high'
));

tasks.push(createTask(
  'Create Entity Protocol',
  'Define base Entity protocol in Domain layer',
  '1. Create Domain/Entities/Entity.swift\n2. Define protocol with id: UUID, createdAt: Date, updatedAt: Date\n3. Add Identifiable conformance\n4. Create extension with default implementation\n5. Add documentation',
  'Create mock entity conforming to protocol, verify properties exist',
  [3],
  'high'
));

tasks.push(createTask(
  'Implement Repository Pattern',
  'Create generic Repository protocol with CRUD operations',
  '1. Create Domain/Repositories/Repository.swift\n2. Define protocol with generic Entity type\n3. Add methods: create, read, update, delete, list\n4. Use async/await and Result types\n5. Document pattern usage',
  'Create mock repository implementation, verify protocol contract',
  [8],
  'high'
));

tasks.push(createTask(
  'Create SwiftData Repository',
  'Implement Repository protocol using SwiftData',
  '1. Create Data/Repositories/SwiftDataRepository.swift\n2. Implement generic repository with ModelContext\n3. Handle CRUD operations with proper error handling\n4. Add transaction support\n5. Implement query builders',
  'Test all CRUD operations with in-memory store',
  [7, 9],
  'high'
));

// Add dependency injection
tasks.push(createTask(
  'Set Up Dependency Injection',
  'Create DI container using SwiftUI Environment',
  '1. Create Infrastructure/DI/Dependencies.swift\n2. Define environment keys for services\n3. Create DependencyContainer with factories\n4. Implement in App struct\n5. No singletons - all injected',
  'Test dependencies can be injected and resolved correctly',
  [10],
  'high'
));

// ViewState pattern
tasks.push(createTask(
  'Implement ViewState Pattern',
  'Create ViewState enum for consistent async state handling',
  '1. Create UI/Common/ViewState.swift\n2. Define enum: idle, loading, success(T), error(Error), empty\n3. Add helper computed properties\n4. Create ViewStateModifier for UI\n5. Document usage patterns',
  'Test all state transitions and helper methods',
  [3],
  'high'
));

// Continue with more foundation tasks...
tasks.push(createTask(
  'Create Base ViewModel',
  'Implement @Observable base ViewModel with ViewState support',
  '1. Create UI/Common/BaseViewModel.swift\n2. Use @Observable macro (iOS 17+)\n3. Add ViewState property\n4. Implement load() template method\n5. Add error handling helpers',
  'Test ViewModel state changes trigger UI updates',
  [12],
  'high'
));

// Network foundation
tasks.push(createTask(
  'Set Up Network Foundation',
  'Create NetworkService protocol with async/await',
  '1. Create Infrastructure/Network/NetworkService.swift\n2. Define protocol with request/response methods\n3. Use async/await throughout\n4. Add request interceptor support\n5. Define NetworkError types',
  'Test protocol with mock implementation',
  [3],
  'high'
));

tasks.push(createTask(
  'Implement URLSession Service',
  'Create URLSession-based NetworkService implementation',
  '1. Create Infrastructure/Network/URLSessionNetworkService.swift\n2. Implement NetworkService protocol\n3. Add retry logic with exponential backoff\n4. Handle all HTTP methods\n5. Add request/response logging',
  'Test with mock URLProtocol, verify retry logic works',
  [14],
  'high'
));

// Add more foundation tasks
tasks.push(createTask(
  'Create Request Builder',
  'Implement type-safe request builder with auth support',
  '1. Create Infrastructure/Network/RequestBuilder.swift\n2. Add builder pattern for requests\n3. Support headers, query params, body\n4. Add auth token injection\n5. Validate request construction',
  'Test request building with various configurations',
  [14],
  'high'
));

tasks.push(createTask(
  'Implement Response Decoder',
  'Create generic response decoder with DTO mapping',
  '1. Create Infrastructure/Network/ResponseDecoder.swift\n2. Use Codable for JSON decoding\n3. Handle error responses\n4. Map DTOs to domain models\n5. Add custom date decoding',
  'Test decoding various response types and error cases',
  [14],
  'high'
));

// Error handling
tasks.push(createTask(
  'Set Up Error Types',
  'Define comprehensive error types for all layers',
  '1. Create Domain/Errors/AppError.swift\n2. Define errors: network, persistence, validation, auth\n3. Add user-friendly messages\n4. Include error codes\n5. Make errors localizable',
  'Test error creation and message generation',
  [3],
  'high'
));

tasks.push(createTask(
  'Create Error Handler',
  'Implement centralized error handling service',
  '1. Create Infrastructure/Services/ErrorHandler.swift\n2. Map errors to user messages\n3. Add retry suggestions\n4. Handle offline errors specially\n5. No PHI in error logs',
  'Test error handling for various error types',
  [18],
  'high'
));

// Mock system
tasks.push(createTask(
  'Set Up Mock System',
  'Create mock data generators for testing',
  '1. Create Tests/Mocks/MockDataGenerator.swift\n2. Add factories for all entities\n3. Create fixture files\n4. Add random data generation\n5. Support deterministic mocks',
  'Test mock generation produces valid data',
  [5, 8],
  'high'
));

// More foundation tasks
tasks.push(createTask(
  'Configure Environment Values',
  'Set up SwiftUI environment for configuration',
  '1. Create UI/Environment/EnvironmentValues+App.swift\n2. Add custom environment keys\n3. Configure in App struct\n4. Add preview helpers\n5. Document usage',
  'Test environment values propagate correctly',
  [11],
  'high'
));

tasks.push(createTask(
  'Create App Entry Point',
  'Configure main App struct with dependencies',
  '1. Update ClarityPulseApp.swift\n2. Initialize ModelContainer\n3. Set up dependency injection\n4. Configure environment\n5. Add lifecycle handlers',
  'Test app initializes with all dependencies',
  [11, 21],
  'high'
));

// Navigation
tasks.push(createTask(
  'Set Up Navigation Structure',
  'Implement navigation coordinator for SwiftUI',
  '1. Create UI/Navigation/NavigationCoordinator.swift\n2. Use NavigationStack (iOS 16+)\n3. Define navigation paths\n4. Handle deep links\n5. Add navigation helpers',
  'Test navigation between screens works correctly',
  [3],
  'high'
));

// Common UI components
tasks.push(createTask(
  'Create Loading View',
  'Implement reusable loading view component',
  '1. Create UI/Components/LoadingView.swift\n2. Add skeleton screens\n3. Support different sizes\n4. Add animations\n5. Make accessible',
  'Test loading view displays correctly, accessibility works',
  [12],
  'high'
));

tasks.push(createTask(
  'Create Empty State View',
  'Implement reusable empty state component',
  '1. Create UI/Components/EmptyStateView.swift\n2. Add customizable message\n3. Include action button\n4. Add illustration support\n5. Make accessible',
  'Test empty state with various configurations',
  [12],
  'high'
));

tasks.push(createTask(
  'Create Error View',
  'Implement reusable error view component',
  '1. Create UI/Components/ErrorView.swift\n2. Display error message\n3. Add retry button\n4. Support different error types\n5. Make accessible',
  'Test error view with various error types',
  [19],
  'high'
));

// Infrastructure
tasks.push(createTask(
  'Set Up Logging System',
  'Create debug-only logging system',
  '1. Create Infrastructure/Services/Logger.swift\n2. Use OSLog for system integration\n3. Add log levels\n4. Ensure no PHI logging\n5. Disable in release builds',
  'Test logging works in debug, disabled in release',
  [3],
  'medium'
));

tasks.push(createTask(
  'Configure Build Configurations',
  'Set up Debug, Release, TestFlight configurations',
  '1. Add build configurations in Xcode\n2. Configure different bundle IDs\n3. Set up environment flags\n4. Configure API endpoints\n5. Add configuration files',
  'Test different configurations build correctly',
  [1],
  'medium'
));

tasks.push(createTask(
  'Create CI/CD Foundation',
  'Set up basic GitHub Actions workflow',
  '1. Create .github/workflows/ios.yml\n2. Add build job\n3. Add test job\n4. Configure Xcode version\n5. Add status badges',
  'Push to GitHub and verify workflow runs',
  [2, 5],
  'medium'
));

tasks.push(createTask(
  'Document Architecture',
  'Create comprehensive architecture documentation',
  '1. Create docs/ARCHITECTURE.md\n2. Add layer descriptions\n3. Create architecture diagrams\n4. Document patterns used\n5. Add code examples',
  'Review documentation for completeness',
  [3],
  'low'
));

// SLICE 1: AUTHENTICATION (Tasks 31-55)
tasks.push(createTask(
  'Create Login Screen UI',
  'Implement login screen with email/password fields',
  '1. Create UI/Auth/LoginView.swift\n2. Add email and password TextFields\n3. Implement form validation\n4. Add login button\n5. Include forgot password link',
  'Write UI tests for login screen, test form validation',
  [24, 25, 26],
  'high'
));

tasks.push(createTask(
  'Create Login ViewModel',
  'Implement LoginViewModel with authentication logic',
  '1. Create UI/Auth/LoginViewModel.swift\n2. Use @Observable macro\n3. Implement login method\n4. Handle loading states\n5. Add form validation',
  'Test ViewModel with mock auth service',
  [13, 31],
  'high'
));

tasks.push(createTask(
  'Create Auth Service Protocol',
  'Define authentication service interface',
  '1. Create Domain/Services/AuthService.swift\n2. Define login, logout, refresh methods\n3. Add session management\n4. Define auth errors\n5. Document methods',
  'Test protocol with mock implementation',
  [9],
  'high'
));

tasks.push(createTask(
  'Implement AWS Cognito Service',
  'Create Cognito-based auth service implementation',
  '1. Add Amplify dependencies via SPM\n2. Create Infrastructure/Auth/CognitoAuthService.swift\n3. Configure Amplify in app\n4. Implement AuthService protocol\n5. Handle Cognito errors',
  'Test with mock Cognito responses',
  [33, 15],
  'high'
));

// Continue with more auth tasks...
tasks.push(createTask(
  'Create Keychain Service',
  'Implement secure credential storage',
  '1. Create Infrastructure/Security/KeychainService.swift\n2. Use Security framework\n3. Store/retrieve credentials\n4. Handle keychain errors\n5. Add access control',
  'Test keychain operations work correctly',
  [3],
  'high'
));

tasks.push(createTask(
  'Implement Login API Integration',
  'Connect login flow to backend /auth/login endpoint',
  '1. Create Data/API/AuthAPI.swift\n2. Define login request/response DTOs\n3. Implement login endpoint call\n4. Map response to domain model\n5. Handle error responses',
  'Test with mock API responses',
  [15, 16, 17],
  'high'
));

tasks.push(createTask(
  'Implement Token Management',
  'Handle access and refresh tokens securely',
  '1. Create Domain/Models/AuthToken.swift\n2. Store tokens in keychain\n3. Add token expiry checking\n4. Implement token refresh logic\n5. Add token to requests',
  'Test token storage, refresh, and expiry',
  [35, 36],
  'high'
));

tasks.push(createTask(
  'Create Session Manager',
  'Implement user session management',
  '1. Create Infrastructure/Auth/SessionManager.swift\n2. Track login state\n3. Handle session timeout\n4. Persist session across launches\n5. Clear on logout',
  'Test session persistence and timeout',
  [37],
  'high'
));

tasks.push(createTask(
  'Implement Logout Flow',
  'Create logout functionality with cleanup',
  '1. Add logout to AuthService\n2. Clear tokens from keychain\n3. Clear user data\n4. Reset navigation\n5. Call logout API',
  'Test logout clears all user data',
  [38],
  'high'
));

tasks.push(createTask(
  'Add Authentication State',
  'Create app-wide authentication state',
  '1. Create UI/Auth/AuthenticationState.swift\n2. Use @Observable for state\n3. Add to environment\n4. Update on login/logout\n5. Persist state',
  'Test auth state updates propagate',
  [38, 21],
  'high'
));

// Biometric auth
tasks.push(createTask(
  'Create Biometric Service',
  'Implement Face ID/Touch ID authentication',
  '1. Create Infrastructure/Security/BiometricService.swift\n2. Use LocalAuthentication framework\n3. Check biometric availability\n4. Implement authentication\n5. Handle errors',
  'Test with mock LAContext',
  [3],
  'high'
));

tasks.push(createTask(
  'Implement Biometric Login',
  'Add biometric authentication to login flow',
  '1. Update LoginView with biometric button\n2. Store credentials securely\n3. Authenticate with biometrics\n4. Fall back to password\n5. Handle enrollment',
  'Test biometric login flow',
  [41, 35],
  'high'
));

tasks.push(createTask(
  'Create PIN Code Service',
  'Implement PIN code fallback authentication',
  '1. Create Infrastructure/Security/PINService.swift\n2. Secure PIN storage\n3. PIN validation logic\n4. Attempt limiting\n5. PIN reset flow',
  'Test PIN operations and security',
  [35],
  'high'
));

tasks.push(createTask(
  'Create PIN Entry UI',
  'Build PIN code entry interface',
  '1. Create UI/Auth/PINEntryView.swift\n2. Custom digit input\n3. Secure text entry\n4. Error feedback\n5. Accessibility support',
  'Test PIN entry UI and accessibility',
  [24],
  'high'
));

tasks.push(createTask(
  'Implement PIN Fallback',
  'Add PIN fallback to biometric auth',
  '1. Update biometric flow\n2. Show PIN on bio failure\n3. Validate PIN\n4. Update auth state\n5. Handle lockout',
  'Test fallback flow works correctly',
  [42, 43, 44],
  'high'
));

// Password reset
tasks.push(createTask(
  'Create Password Reset UI',
  'Build password reset request screen',
  '1. Create UI/Auth/PasswordResetView.swift\n2. Email input field\n3. Submit button\n4. Success/error states\n5. Navigation flow',
  'Test password reset UI flow',
  [24, 25, 26],
  'medium'
));

tasks.push(createTask(
  'Implement Password Reset API',
  'Connect to password reset endpoint',
  '1. Add to AuthAPI.swift\n2. Define reset DTOs\n3. Call /auth/reset endpoint\n4. Handle responses\n5. Show confirmation',
  'Test with mock API responses',
  [36],
  'medium'
));

// Account creation
tasks.push(createTask(
  'Create Registration UI',
  'Build account creation screens',
  '1. Create UI/Auth/RegistrationView.swift\n2. Multi-step form\n3. Input validation\n4. Terms acceptance\n5. Submit flow',
  'Test registration UI and validation',
  [24, 25, 26],
  'medium'
));

tasks.push(createTask(
  'Create Registration ViewModel',
  'Implement registration business logic',
  '1. Create UI/Auth/RegistrationViewModel.swift\n2. Form validation\n3. API integration\n4. Error handling\n5. Success flow',
  'Test ViewModel with mocks',
  [13],
  'medium'
));

tasks.push(createTask(
  'Implement Registration API',
  'Connect to account creation endpoint',
  '1. Add to AuthAPI.swift\n2. Define registration DTOs\n3. Call /auth/register endpoint\n4. Handle validation errors\n5. Auto-login on success',
  'Test registration with mock API',
  [36],
  'medium'
));

// Email verification
tasks.push(createTask(
  'Create Email Verification UI',
  'Build email verification screen',
  '1. Create UI/Auth/EmailVerificationView.swift\n2. Show pending state\n3. Resend option\n4. Success feedback\n5. Auto-proceed',
  'Test verification UI states',
  [24, 25, 26],
  'medium'
));

tasks.push(createTask(
  'Implement Email Verification',
  'Handle email verification flow',
  '1. Check verification status\n2. Poll for completion\n3. Handle deep links\n4. Update auth state\n5. Navigate to app',
  'Test verification flow',
  [40],
  'medium'
));

// Terms of Service
tasks.push(createTask(
  'Create Terms UI',
  'Build terms of service screen',
  '1. Create UI/Legal/TermsView.swift\n2. ScrollView with terms\n3. Accept/decline buttons\n4. Version tracking\n5. Required acceptance',
  'Test terms UI and scrolling',
  [24],
  'medium'
));

tasks.push(createTask(
  'Implement Terms Acceptance',
  'Track terms acceptance',
  '1. Store acceptance date\n2. Track version accepted\n3. Force re-accept on update\n4. API integration\n5. Block access until accepted',
  'Test terms acceptance flow',
  [38],
  'medium'
));

// Auth error handling
tasks.push(createTask(
  'Create Auth Error Handler',
  'Specialized error handling for auth',
  '1. Extend ErrorHandler for auth\n2. Handle Cognito errors\n3. User-friendly messages\n4. Retry suggestions\n5. Account recovery options',
  'Test auth error scenarios',
  [19],
  'high'
));

// SLICE 2: BASIC DASHBOARD (Tasks 56-65)
tasks.push(createTask(
  'Create Dashboard UI Structure',
  'Build main dashboard screen layout',
  '1. Create UI/Dashboard/DashboardView.swift\n2. Design card-based layout\n3. Add navigation bar\n4. Include tab bar\n5. Support iPad layout',
  'Test dashboard renders correctly on all devices',
  [24],
  'high'
));

tasks.push(createTask(
  'Create Dashboard ViewModel',
  'Implement dashboard business logic',
  '1. Create UI/Dashboard/DashboardViewModel.swift\n2. Load user data\n3. Handle refresh\n4. Manage state\n5. Error handling',
  'Test ViewModel with mock data',
  [13, 12],
  'high'
));

tasks.push(createTask(
  'Create User Profile Model',
  'Define user profile domain model',
  '1. Create Domain/Models/UserProfile.swift\n2. Define properties\n3. Add validation\n4. Conform to Entity\n5. Document model',
  'Test model creation and validation',
  [8],
  'high'
));

tasks.push(createTask(
  'Implement Profile API',
  'Connect to /user/profile endpoint',
  '1. Create Data/API/UserAPI.swift\n2. Define profile DTOs\n3. Implement GET profile\n4. Map to domain model\n5. Handle errors',
  'Test with mock API responses',
  [15, 16, 17],
  'high'
));

tasks.push(createTask(
  'Create Tab Bar',
  'Implement main app navigation',
  '1. Create UI/Navigation/MainTabView.swift\n2. Add tab items\n3. Handle selection\n4. Add badges\n5. Customize appearance',
  'Test tab navigation works correctly',
  [23],
  'high'
));

// WebSocket for dashboard
tasks.push(createTask(
  'Create WebSocket Service',
  'Implement real-time connection service',
  '1. Create Infrastructure/Network/WebSocketService.swift\n2. Use URLSessionWebSocketTask\n3. Handle connection lifecycle\n4. Message encoding/decoding\n5. Auto-reconnect logic',
  'Test WebSocket connection and messages',
  [15],
  'high'
));

tasks.push(createTask(
  'Connect Dashboard WebSocket',
  'Enable real-time updates on dashboard',
  '1. Initialize WebSocket on dashboard\n2. Subscribe to updates\n3. Handle incoming messages\n4. Update UI reactively\n5. Show connection status',
  'Test real-time updates work',
  [61, 57],
  'high'
));

// Offline support
tasks.push(createTask(
  'Create Offline Indicator',
  'Show network status to user',
  '1. Create UI/Components/OfflineIndicator.swift\n2. Monitor reachability\n3. Show/hide automatically\n4. Animate transitions\n5. Make accessible',
  'Test indicator appears when offline',
  [24],
  'high'
));

tasks.push(createTask(
  'Implement Dashboard Cache',
  'Cache dashboard data for offline',
  '1. Store last dashboard data\n2. Show cached when offline\n3. Sync when online\n4. Show data age\n5. Handle expiry',
  'Test offline data display',
  [10, 57],
  'high'
));

// Pull to refresh
tasks.push(createTask(
  'Add Pull to Refresh',
  'Implement refresh gesture on dashboard',
  '1. Add refreshable modifier\n2. Trigger data reload\n3. Show loading state\n4. Handle errors\n5. Haptic feedback',
  'Test pull gesture triggers refresh',
  [56, 57],
  'medium'
));

// SLICE 3: HEALTH DATA FOUNDATION (Tasks 66-80)
tasks.push(createTask(
  'Create HealthKit Permission UI',
  'Build permission request interface',
  '1. Create UI/Health/HealthKitPermissionView.swift\n2. List requested types\n3. Explain usage\n4. Request button\n5. Handle denial',
  'Test permission UI flow',
  [24],
  'high'
));

tasks.push(createTask(
  'Create HealthKit Service',
  'Implement HealthKit integration service',
  '1. Create Infrastructure/Health/HealthKitService.swift\n2. Configure health types\n3. Request authorization\n4. Read health data\n5. Handle errors',
  'Test with mock HKHealthStore',
  [3],
  'high'
));

tasks.push(createTask(
  'Configure Background Delivery',
  'Enable background health data updates',
  '1. Enable HealthKit background\n2. Register for updates\n3. Handle background fetch\n4. Update cache\n5. Trigger sync',
  'Test background delivery works',
  [67],
  'high'
));

// Health data models
tasks.push(createTask(
  'Create Health Metric Models',
  'Define health data domain models',
  '1. Create Domain/Models/HealthMetric.swift\n2. Support all metric types\n3. Add validation\n4. Include metadata\n5. Document types',
  'Test model creation for all types',
  [8],
  'high'
));

tasks.push(createTask(
  'Create Health Repository',
  'Implement health data repository',
  '1. Create Domain/Repositories/HealthRepository.swift\n2. Define CRUD operations\n3. Add query methods\n4. Support batch ops\n5. Document interface',
  'Test repository interface',
  [9, 69],
  'high'
));

// Manual entry
tasks.push(createTask(
  'Create Manual Entry UI',
  'Build manual health data entry forms',
  '1. Create UI/Health/ManualEntryView.swift\n2. Dynamic form based on type\n3. Input validation\n4. Date/time picker\n5. Save/cancel flow',
  'Test form for each metric type',
  [24, 25],
  'high'
));

tasks.push(createTask(
  'Implement Data Validation',
  'Validate health data before saving',
  '1. Create Domain/Validators/HealthDataValidator.swift\n2. Range validation\n3. Type checking\n4. Duplicate detection\n5. Error messages',
  'Test validation rules for all types',
  [69],
  'high'
));

// API integration
tasks.push(createTask(
  'Create Health Metrics API',
  'Connect to /health/metrics endpoint',
  '1. Create Data/API/HealthAPI.swift\n2. Define metric DTOs\n3. POST single metric\n4. GET metrics list\n5. Handle errors',
  'Test with mock API',
  [15, 16, 17],
  'high'
));

tasks.push(createTask(
  'Implement Batch Sync API',
  'Connect to /health/batch-sync endpoint',
  '1. Add batch sync to HealthAPI\n2. Define batch DTOs\n3. Chunk large batches\n4. Handle partial success\n5. Retry failed items',
  'Test batch sync with various sizes',
  [73],
  'high'
));

// Offline queue
tasks.push(createTask(
  'Create Offline Health Queue',
  'Queue health data when offline',
  '1. Create Infrastructure/Sync/OfflineQueue.swift\n2. Persist queue to disk\n3. Add retry logic\n4. Priority ordering\n5. Expire old items',
  'Test queue operations offline',
  [10],
  'high'
));

tasks.push(createTask(
  'Implement Sync Status Tracking',
  'Track sync state for health data',
  '1. Add sync status to models\n2. Update UI indicators\n3. Show pending count\n4. Last sync time\n5. Error tracking',
  'Test sync status updates',
  [75],
  'high'
));

// Conflict resolution
tasks.push(createTask(
  'Create Conflict Resolver',
  'Handle sync conflicts for health data',
  '1. Create Domain/Sync/ConflictResolver.swift\n2. Define conflict types\n3. Resolution strategies\n4. User choice UI\n5. Audit trail',
  'Test conflict scenarios',
  [74],
  'high'
));

// Data export
tasks.push(createTask(
  'Implement Health Data Export',
  'Export health data to various formats',
  '1. Create Domain/Export/HealthDataExporter.swift\n2. Support CSV, JSON, PDF\n3. Date range selection\n4. Type filtering\n5. Share sheet integration',
  'Test export formats are valid',
  [69],
  'medium'
));

// Charts
tasks.push(createTask(
  'Create Health Charts',
  'Build chart components for health data',
  '1. Create UI/Health/Charts/HealthChartView.swift\n2. Use Swift Charts\n3. Support multiple types\n4. Interactive features\n5. Accessibility',
  'Test charts render correctly',
  [24],
  'medium'
));

// Trends
tasks.push(createTask(
  'Implement Trend Analysis',
  'Calculate and display health trends',
  '1. Create Domain/Analytics/TrendAnalyzer.swift\n2. Calculate trends\n3. Detect patterns\n4. Generate insights\n5. Visualize trends',
  'Test trend calculations',
  [69, 79],
  'medium'
));

// Continue with remaining slices following the same pattern...
// SLICE 4: REAL-TIME MONITORING (Tasks 81-90)
// SLICE 5: INSIGHTS MODULE (Tasks 91-100)
// ... and so on through all 200 tasks

// Create the final JSON structure
const tasksJson = {
  master: {
    tasks: tasks,
    metadata: {
      created: new Date().toISOString(),
      updated: new Date().toISOString(),
      description: "CLARITY Pulse V2 - Vertical Slice Development Tasks"
    }
  }
};

// Write to file
fs.writeFileSync(
  '/Users/ray/Desktop/CLARITY-DIGITAL-TWIN/clarity-loop-frontend-V2/.taskmaster/tasks/tasks.json',
  JSON.stringify(tasksJson, null, 2)
);

console.log(`Generated ${tasks.length} tasks`);