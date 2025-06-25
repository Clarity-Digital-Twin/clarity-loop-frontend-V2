# CLARITY State Management & @Observable Pattern Guide

## Overview
This document provides comprehensive state management patterns using iOS 17's @Observable macro, replacing the legacy ObservableObject pattern.

## Core Principles

### 1. @Observable Over ObservableObject
- Use `@Observable` for all ViewModels
- No more `@Published` property wrappers
- Automatic dependency tracking
- Better performance with precise updates

### 2. State Management Hierarchy
```
App State (Global)
    ↓
Screen State (ViewModels)  
    ↓
Component State (Local)
```

## Complete State Management Architecture

### App State Container
```swift
import SwiftUI
import Observation

@Observable
final class AppState {
    // MARK: - Authentication State
    var currentUser: User?
    var authToken: String?
    var isAuthenticated: Bool {
        currentUser != nil && authToken != nil
    }
    
    // MARK: - Navigation State
    var selectedTab: AppTab = .dashboard
    var navigationPath = NavigationPath()
    var presentedSheet: SheetType?
    var presentedAlert: AlertType?
    
    // MARK: - Global UI State
    var isLoading = false
    var globalError: AppError?
    var syncStatus: SyncStatus = .idle
    
    // MARK: - Feature Flags
    var isOfflineMode = false
    var isPATAnalysisEnabled = true
    
    // MARK: - Singleton
    static let shared = AppState()
    private init() {}
}

enum AppTab: String, CaseIterable {
    case dashboard = "Dashboard"
    case health = "Health"
    case insights = "Insights"
    case profile = "Profile"
}

enum SheetType: Identifiable {
    case login
    case settings
    case healthDetail(HealthMetric)
    case insightDetail(Insight)
    
    var id: String {
        switch self {
        case .login: return "login"
        case .settings: return "settings"
        case .healthDetail(let metric): return "health-\(metric.id)"
        case .insightDetail(let insight): return "insight-\(insight.id)"
        }
    }
}

enum AlertType: Identifiable {
    case error(Error)
    case confirmation(title: String, message: String, action: () -> Void)
    case info(String)
    
    var id: String {
        switch self {
        case .error: return "error"
        case .confirmation: return "confirmation"
        case .info: return "info"
        }
    }
}

enum SyncStatus {
    case idle
    case syncing(progress: Double)
    case failed(Error)
    case completed(Date)
}
```

### Feature ViewModels with @Observable

#### AuthViewModel
```swift
@Observable
final class AuthViewModel {
    // MARK: - Dependencies
    private let authRepository: AuthRepositoryProtocol
    private let appState: AppState
    
    // MARK: - State
    var email = ""
    var password = ""
    var isLoading = false
    var error: AuthError?
    
    // MARK: - Computed Properties
    var isLoginButtonEnabled: Bool {
        !email.isEmpty && !password.isEmpty && !isLoading
    }
    
    var errorMessage: String? {
        error?.localizedDescription
    }
    
    // MARK: - Initialization
    init(
        authRepository: AuthRepositoryProtocol = DependencyContainer.shared.authRepository,
        appState: AppState = .shared
    ) {
        self.authRepository = authRepository
        self.appState = appState
    }
    
    // MARK: - Actions
    func login() async {
        guard isLoginButtonEnabled else { return }
        
        isLoading = true
        error = nil
        
        do {
            let response = try await authRepository.login(
                email: email,
                password: password
            )
            
            // Update app state
            await MainActor.run {
                appState.authToken = response.accessToken
                appState.currentUser = User(
                    id: response.userId,
                    email: email,
                    firstName: "",
                    lastName: ""
                )
                
                // Clear sensitive data
                password = ""
            }
            
        } catch let authError as AuthError {
            await MainActor.run {
                error = authError
                
                // Handle specific errors
                switch authError {
                case .emailNotVerified:
                    appState.presentedSheet = .emailVerification
                case .invalidCredentials:
                    password = "" // Clear password on auth failure
                default:
                    break
                }
            }
        } catch {
            await MainActor.run {
                self.error = .unknown(error)
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
    
    func logout() async {
        isLoading = true
        
        do {
            try await authRepository.logout()
            
            await MainActor.run {
                // Clear app state
                appState.currentUser = nil
                appState.authToken = nil
                appState.navigationPath = NavigationPath()
                
                // Clear local state
                email = ""
                password = ""
                error = nil
            }
        } catch {
            await MainActor.run {
                self.error = .logoutFailed(error)
            }
        }
        
        await MainActor.run {
            isLoading = false
        }
    }
}
```

#### DashboardViewModel
```swift
@Observable
final class DashboardViewModel {
    // MARK: - Dependencies
    private let healthRepository: HealthDataRepositoryProtocol
    private let insightRepository: InsightRepositoryProtocol
    private let modelContext: ModelContext
    
    // MARK: - State
    var viewState: ViewState<DashboardData> = .idle
    var selectedDateRange: DateRange = .week
    var refreshTrigger = UUID()
    
    // MARK: - Cached Data
    private(set) var dashboardData: DashboardData?
    
    // MARK: - Initialization
    init(
        healthRepository: HealthDataRepositoryProtocol = DependencyContainer.shared.healthRepository,
        insightRepository: InsightRepositoryProtocol = DependencyContainer.shared.insightRepository,
        modelContext: ModelContext = DataController.shared.viewContext
    ) {
        self.healthRepository = healthRepository
        self.insightRepository = insightRepository
        self.modelContext = modelContext
    }
    
    // MARK: - Actions
    func loadDashboard() async {
        await MainActor.run {
            viewState = .loading
        }
        
        do {
            // Fetch from local store first
            let localData = try await fetchLocalData()
            
            await MainActor.run {
                dashboardData = localData
                viewState = .success(localData)
            }
            
            // Then sync with backend
            try await syncWithBackend()
            
            // Refresh local data after sync
            let updatedData = try await fetchLocalData()
            
            await MainActor.run {
                dashboardData = updatedData
                viewState = .success(updatedData)
            }
            
        } catch {
            await MainActor.run {
                viewState = .error(error.localizedDescription)
            }
        }
    }
    
    func refresh() async {
        refreshTrigger = UUID()
        await loadDashboard()
    }
    
    private func fetchLocalData() async throws -> DashboardData {
        let startDate = selectedDateRange.startDate
        let endDate = Date()
        
        // Fetch health metrics
        let metricsDescriptor = FetchDescriptor<HealthMetric>(
            predicate: #Predicate { metric in
                metric.timestamp >= startDate && metric.timestamp <= endDate
            },
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        
        let metrics = try modelContext.fetch(metricsDescriptor)
        
        // Fetch recent insights
        let insightsDescriptor = FetchDescriptor<Insight>(
            predicate: #Predicate { insight in
                insight.generatedAt >= startDate
            },
            sortBy: [SortDescriptor(\.generatedAt, order: .reverse)]
        )
        insightsDescriptor.fetchLimit = 5
        
        let insights = try modelContext.fetch(insightsDescriptor)
        
        return DashboardData(
            metrics: metrics,
            insights: insights,
            summary: calculateSummary(from: metrics)
        )
    }
    
    private func syncWithBackend() async throws {
        // Sync implementation
    }
    
    private func calculateSummary(from metrics: [HealthMetric]) -> HealthSummary {
        // Summary calculation logic
        HealthSummary(
            averageHeartRate: metrics.filter { $0.type == .heartRate }.map(\.value).average(),
            totalSteps: metrics.filter { $0.type == .steps }.map(\.value).sum(),
            sleepDuration: metrics.filter { $0.type == .sleepDuration }.map(\.value).sum()
        )
    }
}

// MARK: - Supporting Types
struct DashboardData {
    let metrics: [HealthMetric]
    let insights: [Insight]
    let summary: HealthSummary
}

struct HealthSummary {
    let averageHeartRate: Double
    let totalSteps: Double
    let sleepDuration: Double
}

enum DateRange {
    case day
    case week
    case month
    case custom(start: Date, end: Date)
    
    var startDate: Date {
        let calendar = Calendar.current
        switch self {
        case .day:
            return calendar.startOfDay(for: Date())
        case .week:
            return calendar.date(byAdding: .weekOfYear, value: -1, to: Date())!
        case .month:
            return calendar.date(byAdding: .month, value: -1, to: Date())!
        case .custom(let start, _):
            return start
        }
    }
}
```

### Generic ViewState Pattern
```swift
enum ViewState<T> {
    case idle
    case loading
    case success(T)
    case error(String)
    
    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
    
    var data: T? {
        if case .success(let data) = self { return data }
        return nil
    }
    
    var errorMessage: String? {
        if case .error(let message) = self { return message }
        return nil
    }
}
```

### WebSocket State Management
```swift
@Observable
final class WebSocketManager {
    // MARK: - State
    var connectionState: ConnectionState = .disconnected
    var receivedMessages: [WebSocketMessage] = []
    var reconnectAttempts = 0
    
    // MARK: - Configuration
    private let maxReconnectAttempts = 5
    private let reconnectDelay: TimeInterval = 2.0
    
    // MARK: - WebSocket
    private var webSocketTask: URLSessionWebSocketTask?
    private var pingTimer: Timer?
    
    enum ConnectionState {
        case disconnected
        case connecting
        case connected
        case reconnecting(attempt: Int)
        case failed(Error)
        
        var isConnected: Bool {
            if case .connected = self { return true }
            return false
        }
    }
    
    // MARK: - Connection Management
    func connect(token: String) async {
        await MainActor.run {
            connectionState = .connecting
        }
        
        var request = URLRequest(url: AppConfig.webSocketURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        webSocketTask = URLSession.shared.webSocketTask(with: request)
        webSocketTask?.resume()
        
        await MainActor.run {
            connectionState = .connected
            reconnectAttempts = 0
        }
        
        startPingTimer()
        await receiveMessages()
    }
    
    func disconnect() {
        pingTimer?.invalidate()
        pingTimer = nil
        
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        Task { @MainActor in
            connectionState = .disconnected
            reconnectAttempts = 0
        }
    }
    
    private func handleConnectionFailure(_ error: Error) async {
        await MainActor.run {
            if reconnectAttempts < maxReconnectAttempts {
                reconnectAttempts += 1
                connectionState = .reconnecting(attempt: reconnectAttempts)
            } else {
                connectionState = .failed(error)
            }
        }
        
        if reconnectAttempts < maxReconnectAttempts {
            try? await Task.sleep(nanoseconds: UInt64(reconnectDelay * 1_000_000_000))
            
            if let token = AppState.shared.authToken {
                await connect(token: token)
            }
        }
    }
    
    private func receiveMessages() async {
        guard let webSocketTask = webSocketTask else { return }
        
        do {
            while connectionState.isConnected {
                let message = try await webSocketTask.receive()
                
                switch message {
                case .string(let text):
                    await handleTextMessage(text)
                case .data(let data):
                    await handleDataMessage(data)
                @unknown default:
                    break
                }
            }
        } catch {
            await handleConnectionFailure(error)
        }
    }
    
    private func startPingTimer() {
        pingTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
            Task {
                try? await self.webSocketTask?.sendPing()
            }
        }
    }
}
```

### Form State Management
```swift
@Observable
final class HealthDataFormViewModel {
    // MARK: - Form Fields
    var selectedMetricType: HealthMetricType = .heartRate
    var value: String = ""
    var date = Date()
    var notes = ""
    
    // MARK: - Validation State
    var validationErrors: [ValidationError] = []
    var isValid: Bool {
        validationErrors.isEmpty && !value.isEmpty
    }
    
    // MARK: - UI State
    var isSubmitting = false
    var submitResult: SubmitResult?
    
    enum ValidationError: LocalizedError {
        case invalidValue
        case futureDate
        case valueOutOfRange(min: Double, max: Double)
        
        var errorDescription: String? {
            switch self {
            case .invalidValue:
                return "Please enter a valid number"
            case .futureDate:
                return "Date cannot be in the future"
            case .valueOutOfRange(let min, let max):
                return "Value must be between \(min) and \(max)"
            }
        }
    }
    
    enum SubmitResult: Identifiable {
        case success
        case failure(Error)
        
        var id: String {
            switch self {
            case .success: return "success"
            case .failure: return "failure"
            }
        }
    }
    
    // MARK: - Validation
    func validate() {
        validationErrors.removeAll()
        
        // Validate value
        guard let numericValue = Double(value) else {
            validationErrors.append(.invalidValue)
            return
        }
        
        // Validate date
        if date > Date() {
            validationErrors.append(.futureDate)
        }
        
        // Validate range based on metric type
        let range = selectedMetricType.validRange
        if numericValue < range.min || numericValue > range.max {
            validationErrors.append(.valueOutOfRange(min: range.min, max: range.max))
        }
    }
    
    // MARK: - Actions
    func submit() async {
        validate()
        guard isValid else { return }
        
        isSubmitting = true
        
        do {
            let metric = HealthMetric(
                type: selectedMetricType,
                value: Double(value)!,
                unit: selectedMetricType.unit,
                timestamp: date,
                source: "Manual Entry"
            )
            
            // Save to local store
            let context = DataController.shared.viewContext
            context.insert(metric)
            try context.save()
            
            // Queue for sync
            let syncManager = DependencyContainer.shared.syncManager
            try await syncManager.queueOperation(.create, for: metric)
            
            await MainActor.run {
                submitResult = .success
                resetForm()
            }
            
        } catch {
            await MainActor.run {
                submitResult = .failure(error)
            }
        }
        
        await MainActor.run {
            isSubmitting = false
        }
    }
    
    private func resetForm() {
        value = ""
        date = Date()
        notes = ""
        validationErrors.removeAll()
    }
}

// MARK: - HealthMetricType Extensions
extension HealthMetricType {
    var unit: String {
        switch self {
        case .steps: return "steps"
        case .heartRate, .restingHeartRate: return "bpm"
        case .bloodOxygen: return "%"
        case .bodyTemperature: return "°F"
        case .respiratoryRate: return "breaths/min"
        case .sleepDuration, .deepSleep, .remSleep, .lightSleep: return "hours"
        case .activeCalories: return "kcal"
        case .distance: return "miles"
        case .heartRateVariability: return "ms"
        }
    }
    
    var validRange: (min: Double, max: Double) {
        switch self {
        case .steps: return (0, 100000)
        case .heartRate: return (30, 220)
        case .restingHeartRate: return (40, 100)
        case .bloodOxygen: return (70, 100)
        case .bodyTemperature: return (95, 105)
        case .respiratoryRate: return (8, 30)
        case .sleepDuration: return (0, 24)
        case .deepSleep, .remSleep, .lightSleep: return (0, 12)
        case .activeCalories: return (0, 5000)
        case .distance: return (0, 100)
        case .heartRateVariability: return (0, 200)
        }
    }
}
```

## SwiftUI Integration Patterns

### Environment Injection
```swift
@main
struct ClarityApp: App {
    let appState = AppState.shared
    let dataController = DataController.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appState)
                .environment(\.modelContext, dataController.viewContext)
        }
    }
}
```

### View with @Observable
```swift
struct DashboardView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = DashboardViewModel()
    
    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.viewState {
                case .idle, .loading:
                    ProgressView("Loading dashboard...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                case .success(let data):
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            HealthSummaryCard(summary: data.summary)
                            
                            ForEach(data.insights) { insight in
                                InsightCard(insight: insight)
                                    .onTapGesture {
                                        appState.presentedSheet = .insightDetail(insight)
                                    }
                            }
                        }
                        .padding()
                    }
                    
                case .error(let message):
                    ErrorView(message: message) {
                        Task { await viewModel.refresh() }
                    }
                }
            }
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Refresh") {
                        Task { await viewModel.refresh() }
                    }
                    .disabled(viewModel.viewState.isLoading)
                }
            }
            .refreshable {
                await viewModel.refresh()
            }
            .task {
                await viewModel.loadDashboard()
            }
        }
    }
}
```

### Bindable Pattern
```swift
struct SettingsView: View {
    @Bindable var settings: SettingsViewModel
    
    var body: some View {
        Form {
            Section("Notifications") {
                Toggle("Daily Insights", isOn: $settings.dailyInsightsEnabled)
                Toggle("Health Alerts", isOn: $settings.healthAlertsEnabled)
                
                if settings.healthAlertsEnabled {
                    Picker("Alert Threshold", selection: $settings.alertThreshold) {
                        ForEach(AlertThreshold.allCases) { threshold in
                            Text(threshold.displayName).tag(threshold)
                        }
                    }
                }
            }
            
            Section("Sync") {
                Toggle("Background Sync", isOn: $settings.backgroundSyncEnabled)
                
                HStack {
                    Text("Sync Frequency")
                    Spacer()
                    Picker("", selection: $settings.syncFrequency) {
                        ForEach(SyncFrequency.allCases) { frequency in
                            Text(frequency.displayName).tag(frequency)
                        }
                    }
                    .pickerStyle(.menu)
                }
            }
        }
        .onChange(of: settings.backgroundSyncEnabled) { _, newValue in
            Task { await settings.updateBackgroundSync(enabled: newValue) }
        }
    }
}
```

## Performance Best Practices

### 1. Computed Properties vs Stored Properties
```swift
@Observable
final class OptimizedViewModel {
    // Good: Computed property for derived state
    var displayTitle: String {
        "\(firstName) \(lastName)"
    }
    
    // Avoid: Updating stored property in response to other changes
    var fullName: String = "" // Don't do this
    
    func updateName() {
        // Bad: Manual synchronization
        fullName = "\(firstName) \(lastName)"
    }
}
```

### 2. Batch Updates
```swift
@Observable
final class BatchUpdateViewModel {
    var items: [Item] = []
    
    // Good: Batch update
    func updateMultipleItems(_ updates: [(id: String, value: Double)]) {
        for update in updates {
            if let index = items.firstIndex(where: { $0.id == update.id }) {
                items[index].value = update.value
            }
        }
    }
    
    // Avoid: Individual updates in a loop (causes multiple UI updates)
    func inefficientUpdate(_ updates: [(id: String, value: Double)]) {
        for update in updates {
            updateSingleItem(id: update.id, value: update.value) // Each call triggers UI update
        }
    }
}
```

### 3. Async State Updates
```swift
@Observable
final class AsyncViewModel {
    var data: [DataItem] = []
    var isLoading = false
    
    // Good: Batch UI updates on main actor
    func loadData() async {
        await MainActor.run {
            isLoading = true
        }
        
        do {
            let fetchedData = try await fetchFromAPI()
            let processedData = await processInBackground(fetchedData)
            
            // Single UI update
            await MainActor.run {
                self.data = processedData
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}
```

## Testing @Observable ViewModels

```swift
@MainActor
final class ViewModelTests: XCTestCase {
    func testAuthViewModelLogin() async throws {
        // Arrange
        let mockRepository = MockAuthRepository()
        let appState = AppState()
        let viewModel = AuthViewModel(
            authRepository: mockRepository,
            appState: appState
        )
        
        // Set up expectation
        mockRepository.mockResponse = LoginResponseDTO(
            accessToken: "token",
            refreshToken: "refresh",
            expiresIn: 3600,
            userId: "123"
        )
        
        // Act
        viewModel.email = "test@example.com"
        viewModel.password = "password"
        await viewModel.login()
        
        // Assert
        XCTAssertNil(viewModel.error)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertEqual(appState.authToken, "token")
        XCTAssertNotNil(appState.currentUser)
        XCTAssertEqual(viewModel.password, "") // Password cleared
    }
}
```

## Migration from ObservableObject

### Before (ObservableObject)
```swift
class OldViewModel: ObservableObject {
    @Published var name = ""
    @Published var isLoading = false
    
    func update() {
        objectWillChange.send() // Manual notification
    }
}
```

### After (@Observable)
```swift
@Observable
final class NewViewModel {
    var name = ""
    var isLoading = false
    
    func update() {
        // Automatic change tracking
    }
}
```

### View Changes
```swift
// Before
struct OldView: View {
    @StateObject private var viewModel = OldViewModel()
    // or
    @ObservedObject var viewModel: OldViewModel
    
    var body: some View {
        Text(viewModel.name)
    }
}

// After
struct NewView: View {
    @State private var viewModel = NewViewModel()
    
    var body: some View {
        Text(viewModel.name)
    }
}
```

---

This state management architecture provides a robust, performant foundation for the CLARITY app, leveraging iOS 17's latest capabilities while maintaining clean, testable code.