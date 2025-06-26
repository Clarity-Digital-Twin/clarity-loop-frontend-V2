# UI Layer

The UI layer contains all user interface components built with SwiftUI and follows the MVVM pattern with iOS 17's `@Observable` macro.

## Structure

```
UI/
├── Views/                 # SwiftUI Views
│   ├── RootView.swift     # App entry point
│   ├── LoginView.swift    # Authentication screens
│   ├── DashboardView.swift # Main dashboard
│   ├── HealthMetricsView.swift # Metric entry
│   └── ProfileView.swift  # User profile
├── ViewModels/            # @Observable ViewModels
│   ├── LoginViewModel.swift
│   ├── DashboardViewModel.swift
│   └── ViewState.swift    # Generic state handling
└── UIModule.swift         # Module definition
```

## Key Components

### Views
Pure SwiftUI views that:
- Display data from ViewModels
- Handle user input
- Navigate between screens
- Are free of business logic

### ViewModels (@Observable)
State containers that:
- Manage view state
- Call domain use cases
- Transform domain models for display
- Handle async operations

### ViewState Pattern
Generic state management for async operations:
```swift
enum ViewState<T: Sendable>: Sendable {
    case idle
    case loading
    case success(T)
    case error(String)
}
```

## Modern SwiftUI Patterns

### @Observable ViewModels (iOS 17+)
```swift
@MainActor
@Observable
final class DashboardViewModel {
    private(set) var metrics: [HealthMetric] = []
    private(set) var viewState: ViewState<[HealthMetric]> = .idle
    
    func loadMetrics() async {
        viewState = .loading
        do {
            metrics = try await repository.findAll()
            viewState = .success(metrics)
        } catch {
            viewState = .error(error.localizedDescription)
        }
    }
}
```

### View Integration
```swift
struct DashboardView: View {
    @State private var viewModel: DashboardViewModel
    
    init(user: User) {
        let container = DIContainer.shared
        let factory = container.require(DashboardViewModelFactory.self)
        self._viewModel = State(wrappedValue: factory.create(user))
    }
    
    var body: some View {
        NavigationStack {
            // View implementation
        }
        .task {
            await viewModel.loadMetrics()
        }
    }
}
```

## Navigation

Using SwiftUI's NavigationStack for modern navigation:
```swift
NavigationStack {
    List(items) { item in
        NavigationLink(value: item) {
            ItemRow(item: item)
        }
    }
    .navigationDestination(for: Item.self) { item in
        DetailView(item: item)
    }
}
```

## Dependency Injection

Views receive dependencies through DI container:
```swift
struct LoginView: View {
    @State private var viewModel: LoginViewModel
    
    init() {
        let container = DIContainer.shared
        let factory = container.require(LoginViewModelFactory.self)
        let loginUseCase = factory.create()
        self._viewModel = State(wrappedValue: LoginViewModel(loginUseCase: loginUseCase))
    }
}
```

## Testing ViewModels

ViewModels are tested with mock dependencies:
```swift
@MainActor
func test_loadMetrics_success() async {
    // Given
    let mockRepo = MockHealthMetricRepository()
    mockRepo.metrics = [testMetric1, testMetric2]
    let sut = DashboardViewModel(repository: mockRepo)
    
    // When
    await sut.loadMetrics()
    
    // Then
    XCTAssertEqual(sut.viewState, .success([testMetric1, testMetric2]))
    XCTAssertEqual(sut.metrics.count, 2)
}
```

## Best Practices

1. **State Management**: Use `ViewState` for consistent async state handling
2. **@MainActor**: Mark ViewModels with @MainActor for UI safety
3. **Composition**: Build complex views from smaller, reusable components
4. **Testability**: Keep views thin, test logic in ViewModels
5. **Accessibility**: Add proper labels and hints for VoiceOver
6. **Error Handling**: Always show user-friendly error states