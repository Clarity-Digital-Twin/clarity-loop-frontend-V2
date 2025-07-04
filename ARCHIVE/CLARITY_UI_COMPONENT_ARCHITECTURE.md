# CLARITY UI Component Architecture Guide

## Overview
This guide defines the SwiftUI component architecture for CLARITY Pulse V2, ensuring consistent, reusable, and testable UI components that follow Apple's Human Interface Guidelines for health applications.

## Core Principles

### 1. Component-Based Architecture
- **Atomic Design**: Small, reusable components that compose into larger features
- **Single Responsibility**: Each component has one clear purpose
- **Testability**: All components must be testable in isolation
- **Accessibility**: Built-in VoiceOver and Dynamic Type support

### 2. Health App UI Patterns
Following Apple Health app conventions:
- **Card-based layouts** for health metrics
- **Progressive disclosure** for detailed data
- **Clear visual hierarchy** with proper spacing
- **Consistent color coding** for health categories

## Component Structure

### Base Component Protocol
```swift
protocol CLARITYComponent: View {
    associatedtype Configuration
    var configuration: Configuration { get }
    var accessibilityIdentifier: String { get }
}
```

### Component Categories

#### 1. Foundation Components
Lowest-level building blocks:

```swift
// MARK: - Typography
struct CLARITYText: View {
    enum Style {
        case largeTitle
        case title1
        case title2
        case title3
        case headline
        case body
        case callout
        case subheadline
        case footnote
        case caption1
        case caption2
    }
    
    let text: String
    let style: Style
    var color: Color = .label
    
    var body: some View {
        Text(text)
            .font(style.font)
            .foregroundColor(color)
            .accessibilityIdentifier("clarity.text.\(style)")
    }
}

// MARK: - Buttons
struct CLARITYButton: View {
    enum Style {
        case primary
        case secondary
        case tertiary
        case destructive
        case minimal
    }
    
    let title: String
    let style: Style
    let action: () -> Void
    var isLoading: Bool = false
    var isEnabled: Bool = true
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(0.8)
                }
                Text(title)
            }
            .frame(maxWidth: style.isFullWidth ? .infinity : nil)
            .padding(.horizontal, style.horizontalPadding)
            .padding(.vertical, style.verticalPadding)
            .background(style.backgroundColor(isEnabled: isEnabled))
            .foregroundColor(style.foregroundColor)
            .cornerRadius(style.cornerRadius)
        }
        .disabled(!isEnabled || isLoading)
        .accessibilityIdentifier("clarity.button.\(title.lowercased())")
    }
}

// MARK: - Cards
struct CLARITYCard: View {
    let content: AnyView
    var padding: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16)
    var backgroundColor: Color = .secondarySystemBackground
    
    var body: some View {
        content
            .padding(padding)
            .background(backgroundColor)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
}
```

#### 2. Health-Specific Components

```swift
// MARK: - Health Metric Card
struct HealthMetricCard: View {
    struct Configuration {
        let icon: String
        let title: String
        let value: String
        let unit: String
        let trend: Trend?
        let lastUpdated: Date?
        let color: Color
    }
    
    enum Trend {
        case up(Double)
        case down(Double)
        case stable
        
        var icon: String {
            switch self {
            case .up: return "arrow.up.circle.fill"
            case .down: return "arrow.down.circle.fill"
            case .stable: return "equal.circle.fill"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .stable: return .orange
            }
        }
    }
    
    let configuration: Configuration
    
    var body: some View {
        CLARITYCard(content: AnyView(
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: configuration.icon)
                        .font(.title2)
                        .foregroundColor(configuration.color)
                    
                    Text(configuration.title)
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    if let trend = configuration.trend {
                        Image(systemName: trend.icon)
                            .foregroundColor(trend.color)
                    }
                }
                
                // Value
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(configuration.value)
                        .font(.system(size: 34, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text(configuration.unit)
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                
                // Last Updated
                if let lastUpdated = configuration.lastUpdated {
                    Text("Updated \(lastUpdated, style: .relative)")
                        .font(.caption)
                        .foregroundColor(.tertiary)
                }
            }
        ))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(configuration.title): \(configuration.value) \(configuration.unit)")
    }
}

// MARK: - Heart Rate Chart
struct HeartRateChart: View {
    @State private var selectedDataPoint: HeartRateDataPoint?
    let dataPoints: [HeartRateDataPoint]
    let showAnnotations: Bool = true
    
    struct HeartRateDataPoint: Identifiable {
        let id = UUID()
        let timestamp: Date
        let value: Double
        let isResting: Bool
    }
    
    var body: some View {
        Chart(dataPoints) { dataPoint in
            LineMark(
                x: .value("Time", dataPoint.timestamp),
                y: .value("BPM", dataPoint.value)
            )
            .foregroundStyle(dataPoint.isResting ? Color.blue : Color.red)
            .interpolationMethod(.catmullRom)
            
            if showAnnotations {
                RuleMark(y: .value("Normal Range Min", 60))
                    .foregroundStyle(Color.green.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
                
                RuleMark(y: .value("Normal Range Max", 100))
                    .foregroundStyle(Color.green.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 5]))
            }
            
            if let selected = selectedDataPoint, selected.id == dataPoint.id {
                PointMark(
                    x: .value("Time", dataPoint.timestamp),
                    y: .value("BPM", dataPoint.value)
                )
                .symbol(Circle())
                .foregroundStyle(Color.primary)
            }
        }
        .frame(height: 200)
        .chartYAxis {
            AxisMarks(position: .leading)
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 4))
        }
        .chartBackground { chartProxy in
            Color.clear
                .onTapGesture { location in
                    // Handle tap to show detail
                }
        }
    }
}

// MARK: - Activity Ring
struct ActivityRing: View {
    let progress: Double // 0.0 to 1.0
    let color: Color
    let lineWidth: CGFloat = 20
    
    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(color.opacity(0.3), lineWidth: lineWidth)
            
            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        gradient: Gradient(colors: [color, color.opacity(0.8)]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * progress)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.spring(response: 0.5, dampingFraction: 0.8), value: progress)
        }
    }
}
```

#### 3. Form Components

```swift
// MARK: - Health Data Input Field
struct HealthDataInputField: View {
    let title: String
    let unit: String
    @Binding var value: String
    let keyboardType: UIKeyboardType
    let validator: (String) -> Bool
    @State private var isValid: Bool = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack {
                TextField("0", text: $value)
                    .keyboardType(keyboardType)
                    .onChange(of: value) { newValue in
                        isValid = validator(newValue)
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isValid ? Color.clear : Color.red, lineWidth: 1)
                    )
                
                Text(unit)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .frame(minWidth: 40)
            }
            
            if !isValid {
                Text("Please enter a valid value")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title) input field")
    }
}

// MARK: - Biometric Auth View
struct BiometricAuthView: View {
    @State private var authState: AuthState = .idle
    let onSuccess: () -> Void
    let onFailure: (Error) -> Void
    
    enum AuthState {
        case idle
        case authenticating
        case success
        case failure(Error)
    }
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: authIcon)
                .font(.system(size: 64))
                .foregroundColor(authColor)
                .symbolEffect(.bounce, value: authState)
            
            Text(authMessage)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
            
            if case .failure = authState {
                CLARITYButton(
                    title: "Try Again",
                    style: .primary,
                    action: authenticate
                )
            }
        }
        .padding(32)
        .onAppear {
            authenticate()
        }
    }
    
    private var authIcon: String {
        switch authState {
        case .idle, .authenticating:
            return "faceid"
        case .success:
            return "checkmark.circle.fill"
        case .failure:
            return "xmark.circle.fill"
        }
    }
    
    private var authColor: Color {
        switch authState {
        case .idle, .authenticating:
            return .blue
        case .success:
            return .green
        case .failure:
            return .red
        }
    }
    
    private var authMessage: String {
        switch authState {
        case .idle:
            return "Authenticate to access health data"
        case .authenticating:
            return "Authenticating..."
        case .success:
            return "Authentication successful"
        case .failure:
            return "Authentication failed"
        }
    }
    
    private func authenticate() {
        // Implementation
    }
}
```

#### 4. Layout Components

```swift
// MARK: - Dashboard Grid
struct DashboardGrid: View {
    let items: [AnyView]
    let columns: Int = 2
    
    var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16), count: columns)
    }
    
    var body: some View {
        LazyVGrid(columns: gridColumns, spacing: 16) {
            ForEach(0..<items.count, id: \.self) { index in
                items[index]
            }
        }
        .padding()
    }
}

// MARK: - Section Container
struct SectionContainer<Content: View>: View {
    let title: String
    let content: Content
    var showSeeAll: Bool = false
    var onSeeAll: (() -> Void)?
    
    init(
        title: String,
        showSeeAll: Bool = false,
        onSeeAll: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.showSeeAll = showSeeAll
        self.onSeeAll = onSeeAll
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                if showSeeAll {
                    Button("See All", action: onSeeAll ?? {})
                        .font(.subheadline)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal)
            
            content
        }
    }
}
```

#### 5. Feedback Components

```swift
// MARK: - Loading View
struct LoadingView: View {
    let message: String?
    
    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
            
            if let message = message {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.systemBackground)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: icon)
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let actionTitle = actionTitle, let action = action {
                CLARITYButton(
                    title: actionTitle,
                    style: .primary,
                    action: action
                )
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Error View
struct ErrorView: View {
    let error: Error
    let onRetry: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.red)
            
            VStack(spacing: 8) {
                Text("Something went wrong")
                    .font(.headline)
                
                Text(error.localizedDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if let onRetry = onRetry {
                CLARITYButton(
                    title: "Try Again",
                    style: .primary,
                    action: onRetry
                )
            }
        }
        .padding(32)
    }
}
```

## Component Usage Guidelines

### 1. Composition Pattern
```swift
struct HealthDashboardView: View {
    @StateObject private var viewModel: HealthDashboardViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Today's Summary
                SectionContainer(title: "Today's Summary") {
                    DashboardGrid(items: [
                        AnyView(HealthMetricCard(configuration: .steps)),
                        AnyView(HealthMetricCard(configuration: .heartRate)),
                        AnyView(HealthMetricCard(configuration: .calories)),
                        AnyView(HealthMetricCard(configuration: .sleep))
                    ])
                }
                
                // Heart Rate Trends
                SectionContainer(
                    title: "Heart Rate",
                    showSeeAll: true,
                    onSeeAll: viewModel.showHeartRateDetails
                ) {
                    CLARITYCard(content: AnyView(
                        HeartRateChart(dataPoints: viewModel.heartRateData)
                    ))
                    .padding(.horizontal)
                }
                
                // Activity Rings
                SectionContainer(title: "Activity") {
                    HStack(spacing: 32) {
                        ForEach(viewModel.activityRings) { ring in
                            VStack {
                                ActivityRing(
                                    progress: ring.progress,
                                    color: ring.color
                                )
                                .frame(width: 80, height: 80)
                                
                                Text(ring.label)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                }
            }
            .padding(.vertical)
        }
        .background(Color.systemGroupedBackground)
    }
}
```

### 2. State Management
```swift
extension View {
    func withViewState<T>(
        _ state: ViewState<T>,
        onRetry: @escaping () -> Void = {},
        @ViewBuilder content: @escaping (T) -> some View
    ) -> some View {
        Group {
            switch state {
            case .idle:
                EmptyView()
            case .loading:
                LoadingView(message: nil)
            case .success(let data):
                content(data)
            case .failure(let error):
                ErrorView(error: error, onRetry: onRetry)
            }
        }
    }
}
```

### 3. Accessibility
All components must:
- Have proper `accessibilityLabel` and `accessibilityHint`
- Support Dynamic Type
- Provide `accessibilityValue` for data
- Use semantic colors (`.primary`, `.secondary`, etc.)
- Support VoiceOver navigation

### 4. Dark Mode Support
- Use semantic colors from the design system
- Test all components in both light and dark mode
- Ensure proper contrast ratios (WCAG AA minimum)

## Testing Components

### Component Test Template
```swift
final class HealthMetricCardTests: XCTestCase {
    func test_whenConfigured_displaysCorrectValues() throws {
        // Given
        let configuration = HealthMetricCard.Configuration(
            icon: "heart.fill",
            title: "Heart Rate",
            value: "72",
            unit: "BPM",
            trend: .stable,
            lastUpdated: Date(),
            color: .red
        )
        
        // When
        let view = HealthMetricCard(configuration: configuration)
        let controller = UIHostingController(rootView: view)
        
        // Then
        XCTAssertNotNil(controller.view)
        // Additional snapshot or accessibility tests
    }
}
```

## Component Library Structure
```
UI/
├── Components/
│   ├── Foundation/
│   │   ├── CLARITYText.swift
│   │   ├── CLARITYButton.swift
│   │   └── CLARITYCard.swift
│   ├── Health/
│   │   ├── HealthMetricCard.swift
│   │   ├── HeartRateChart.swift
│   │   └── ActivityRing.swift
│   ├── Forms/
│   │   ├── HealthDataInputField.swift
│   │   └── BiometricAuthView.swift
│   ├── Layout/
│   │   ├── DashboardGrid.swift
│   │   └── SectionContainer.swift
│   └── Feedback/
│       ├── LoadingView.swift
│       ├── EmptyStateView.swift
│       └── ErrorView.swift
├── Modifiers/
│   ├── AccessibilityModifier.swift
│   └── ThemeModifier.swift
└── Protocols/
    └── CLARITYComponent.swift
```

## Next Steps
1. Implement component preview providers for SwiftUI previews
2. Create component documentation with DocC
3. Build Xcode snippets for common patterns
4. Set up component visual regression testing