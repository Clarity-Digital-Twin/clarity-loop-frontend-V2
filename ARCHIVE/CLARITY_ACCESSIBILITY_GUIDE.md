# CLARITY Accessibility Guide

## Overview
This guide ensures CLARITY Pulse V2 is fully accessible to users with disabilities, following WCAG 2.1 AA standards and Apple's accessibility guidelines. Health apps have a special responsibility to be accessible to all users.

## Core Principles

### 1. Perceivable
Information must be presentable in ways users can perceive
- Text alternatives for non-text content
- Sufficient color contrast
- Content that adapts to user preferences

### 2. Operable
Interface components must be operable
- All functionality available via keyboard/assistive tech
- No seizure-inducing content
- Sufficient time limits

### 3. Understandable
Information and UI operation must be understandable
- Readable text
- Predictable functionality
- Input assistance

### 4. Robust
Content must be robust enough for assistive technologies
- Valid, well-structured code
- Compatible with screen readers
- Future-proof implementation

## VoiceOver Support

### 1. Custom Accessibility Actions

```swift
// MARK: - Health Metric Card Accessibility
extension HealthMetricCard {
    func accessibilitySetup() -> some View {
        self
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel)
            .accessibilityValue(accessibilityValue)
            .accessibilityHint(accessibilityHint)
            .accessibilityAddTraits(accessibilityTraits)
            .accessibilityCustomActions(customActions)
    }
    
    private var accessibilityLabel: String {
        "\(configuration.title) metric"
    }
    
    private var accessibilityValue: String {
        let value = "\(configuration.value) \(configuration.unit)"
        
        if let trend = configuration.trend {
            let trendText = switch trend {
            case .up(let percent):
                "up \(Int(percent))% from last reading"
            case .down(let percent):
                "down \(Int(percent))% from last reading"
            case .stable:
                "stable"
            }
            return "\(value), \(trendText)"
        }
        
        return value
    }
    
    private var accessibilityHint: String {
        "Double tap to view detailed \(configuration.title) history"
    }
    
    private var accessibilityTraits: AccessibilityTraits {
        [.isButton, .isStaticText]
    }
    
    private var customActions: [AccessibilityCustomAction] {
        var actions: [AccessibilityCustomAction] = []
        
        // View Details
        actions.append(
            AccessibilityCustomAction(
                name: "View Details",
                image: Image(systemName: "info.circle")
            ) {
                viewDetails()
                return true
            }
        )
        
        // Share Data
        actions.append(
            AccessibilityCustomAction(
                name: "Share \(configuration.title) Data",
                image: Image(systemName: "square.and.arrow.up")
            ) {
                shareData()
                return true
            }
        )
        
        // Add Manual Entry
        if configuration.allowsManualEntry {
            actions.append(
                AccessibilityCustomAction(
                    name: "Add Manual Entry",
                    image: Image(systemName: "plus.circle")
                ) {
                    addManualEntry()
                    return true
                }
            )
        }
        
        return actions
    }
}
```

### 2. Chart Accessibility

```swift
// MARK: - Accessible Charts
struct AccessibleHeartRateChart: View {
    let dataPoints: [HeartRateDataPoint]
    @State private var selectedPoint: HeartRateDataPoint?
    @AccessibilityFocusState private var chartFocus: Bool
    
    var body: some View {
        Chart(dataPoints) { dataPoint in
            LineMark(
                x: .value("Time", dataPoint.timestamp),
                y: .value("BPM", dataPoint.value)
            )
            .accessibilityLabel(dataPointAccessibilityLabel(dataPoint))
            .accessibilityValue("\(Int(dataPoint.value)) beats per minute")
        }
        .accessibilityElement()
        .accessibilityLabel("Heart rate chart")
        .accessibilityValue(chartSummary)
        .accessibilityHint("Use rotor to navigate individual data points")
        .accessibilityChartDescriptor(self)
        .onAppear {
            announceChartSummary()
        }
    }
    
    private var chartSummary: String {
        guard !dataPoints.isEmpty else {
            return "No heart rate data available"
        }
        
        let average = dataPoints.map(\.value).reduce(0, +) / Double(dataPoints.count)
        let min = dataPoints.map(\.value).min() ?? 0
        let max = dataPoints.map(\.value).max() ?? 0
        
        return "Heart rate over \(formattedTimeRange). Average \(Int(average)) BPM, ranging from \(Int(min)) to \(Int(max))"
    }
    
    private func dataPointAccessibilityLabel(_ point: HeartRateDataPoint) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        
        return "Heart rate at \(timeFormatter.string(from: point.timestamp))"
    }
    
    private func announceChartSummary() {
        UIAccessibility.post(
            notification: .announcement,
            argument: chartSummary
        )
    }
}

// MARK: - Audio Chart Description
extension AccessibleHeartRateChart: AXChartDescriptorRepresentable {
    func makeChartDescriptor() -> AXChartDescriptor {
        let xAxis = AXCategoricalDataAxisDescriptor(
            title: "Time",
            categoryOrder: dataPoints.map { 
                DateFormatter.localizedString(
                    from: $0.timestamp,
                    dateStyle: .none,
                    timeStyle: .short
                )
            }
        )
        
        let yAxis = AXNumericDataAxisDescriptor(
            title: "Heart Rate (BPM)",
            range: 40...200,
            gridlinePositions: [40, 60, 80, 100, 120, 140, 160, 180, 200],
            valueDescriptionProvider: { value in
                "\(Int(value)) beats per minute"
            }
        )
        
        let series = AXDataSeriesDescriptor(
            name: "Heart Rate",
            isContinuous: true,
            dataPoints: dataPoints.enumerated().map { index, point in
                AXDataPoint(
                    x: index,
                    y: point.value,
                    additionalValues: [],
                    label: "\(Int(point.value)) BPM"
                )
            }
        )
        
        return AXChartDescriptor(
            title: "Heart Rate Over Time",
            summary: chartSummary,
            xAxis: xAxis,
            yAxis: yAxis,
            additionalAxes: [],
            series: [series]
        )
    }
}
```

### 3. Custom Rotor Support

```swift
// MARK: - Health Data Rotor
struct HealthDataRotor: ViewModifier {
    let healthMetrics: [HealthMetric]
    
    func body(content: Content) -> some View {
        content
            .accessibilityRotor("Health Metrics") {
                ForEach(healthMetrics) { metric in
                    AccessibilityRotorEntry(
                        metric.title,
                        id: metric.id,
                        textRange: nil
                    )
                }
            }
            .accessibilityRotor("Abnormal Values") {
                ForEach(healthMetrics.filter { $0.isAbnormal }) { metric in
                    AccessibilityRotorEntry(
                        "\(metric.title): \(metric.value) - \(metric.status)",
                        id: metric.id
                    )
                }
            }
            .accessibilityRotor("Recent Updates") {
                ForEach(healthMetrics.filter { $0.isRecent }) { metric in
                    AccessibilityRotorEntry(
                        "\(metric.title) updated \(metric.timeAgo)",
                        id: metric.id
                    )
                }
            }
    }
}
```

## Dynamic Type Support

### 1. Scalable Text Implementation

```swift
// MARK: - Dynamic Type Extensions
extension Font {
    static func clarityScalable(_ textStyle: Font.TextStyle, design: Font.Design = .default) -> Font {
        .system(textStyle, design: design)
    }
    
    // Health-specific scaled fonts
    static var clarityMetricValue: Font {
        .system(.largeTitle, design: .rounded)
            .monospacedDigit()
    }
    
    static var clarityMetricUnit: Font {
        .system(.callout)
    }
}

// MARK: - Scaled Metric Values
struct ScaledMetric<Value> where Value: BinaryFloatingPoint {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    private let baseValue: Value
    private let textStyle: Font.TextStyle
    
    init(baseValue: Value, relativeTo textStyle: Font.TextStyle = .body) {
        self.baseValue = baseValue
        self.textStyle = textStyle
    }
    
    var value: Value {
        baseValue * scaleFactor
    }
    
    private var scaleFactor: Value {
        switch dynamicTypeSize {
        case .xSmall: return 0.75
        case .small: return 0.85
        case .medium: return 1.0
        case .large: return 1.1
        case .xLarge: return 1.2
        case .xxLarge: return 1.35
        case .xxxLarge: return 1.5
        case .accessibility1: return 1.75
        case .accessibility2: return 2.0
        case .accessibility3: return 2.5
        case .accessibility4: return 3.0
        case .accessibility5: return 3.5
        @unknown default: return 1.0
        }
    }
}

// MARK: - Dynamic Layout
struct DynamicStack<Content: View>: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    let content: () -> Content
    
    var body: some View {
        if dynamicTypeSize.isAccessibilitySize {
            // Vertical layout for large text
            VStack(alignment: .leading, spacing: 12) {
                content()
            }
        } else {
            // Horizontal layout for regular text
            HStack(spacing: 16) {
                content()
            }
        }
    }
}
```

### 2. Adaptive Layouts

```swift
// MARK: - Accessibility Size Aware Component
struct AdaptiveHealthMetricCard: View {
    let metric: HealthMetric
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric private var iconSize: CGFloat = 24
    @ScaledMetric private var cardPadding: CGFloat = 16
    
    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                accessibilityLayout
            } else {
                standardLayout
            }
        }
        .padding(cardPadding)
        .background(Color.claritySecondaryBackground)
        .cornerRadius(12)
    }
    
    private var standardLayout: some View {
        HStack {
            Image(systemName: metric.icon)
                .font(.system(size: iconSize))
                .foregroundColor(metric.color)
                .frame(width: iconSize * 1.5, height: iconSize * 1.5)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(metric.title)
                    .font(.clarityScalable(.headline))
                    .foregroundColor(.claritySecondaryLabel)
                
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(metric.value)
                        .font(.clarityMetricValue)
                        .foregroundColor(.clarityLabel)
                    
                    Text(metric.unit)
                        .font(.clarityMetricUnit)
                        .foregroundColor(.claritySecondaryLabel)
                }
            }
            
            Spacer()
            
            if let trend = metric.trend {
                TrendIndicator(trend: trend)
            }
        }
    }
    
    private var accessibilityLayout: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: metric.icon)
                    .font(.system(size: iconSize))
                    .foregroundColor(metric.color)
                
                Text(metric.title)
                    .font(.clarityScalable(.headline))
                    .foregroundColor(.claritySecondaryLabel)
            }
            
            Text("\(metric.value) \(metric.unit)")
                .font(.clarityMetricValue)
                .foregroundColor(.clarityLabel)
                .fixedSize(horizontal: false, vertical: true)
            
            if let trend = metric.trend {
                TrendIndicator(trend: trend)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
```

## Color & Contrast

### 1. High Contrast Support

```swift
// MARK: - Contrast Aware Colors
extension Color {
    static func clarityAdaptive(
        light: Color,
        dark: Color,
        highContrastLight: Color? = nil,
        highContrastDark: Color? = nil
    ) -> Color {
        #if os(iOS)
        let baseColor = Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        
        if UIAccessibility.isDarkerSystemColorsEnabled {
            return Color(UIColor { traits in
                if traits.userInterfaceStyle == .dark {
                    return UIColor(highContrastDark ?? dark)
                } else {
                    return UIColor(highContrastLight ?? light)
                }
            })
        }
        
        return baseColor
        #else
        return light
        #endif
    }
}

// MARK: - Contrast Ratios
struct ContrastValidator {
    static func validateContrast(
        foreground: UIColor,
        background: UIColor,
        level: WCAGLevel = .aa
    ) -> Bool {
        let ratio = contrastRatio(between: foreground, and: background)
        
        switch level {
        case .aa:
            return ratio >= 4.5 // Normal text
        case .aaa:
            return ratio >= 7.0 // Enhanced contrast
        case .largeText:
            return ratio >= 3.0 // Large text (18pt+)
        }
    }
    
    private static func contrastRatio(between color1: UIColor, and color2: UIColor) -> Double {
        let l1 = relativeLuminance(of: color1)
        let l2 = relativeLuminance(of: color2)
        
        let lighter = max(l1, l2)
        let darker = min(l1, l2)
        
        return (lighter + 0.05) / (darker + 0.05)
    }
    
    private static func relativeLuminance(of color: UIColor) -> Double {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        
        let components = [red, green, blue].map { component in
            component <= 0.03928 
                ? component / 12.92 
                : pow((component + 0.055) / 1.055, 2.4)
        }
        
        return 0.2126 * components[0] + 0.7152 * components[1] + 0.0722 * components[2]
    }
    
    enum WCAGLevel {
        case aa
        case aaa
        case largeText
    }
}
```

### 2. Color Blind Friendly Palettes

```swift
// MARK: - Color Blind Safe Colors
extension Color {
    // Optimized for Protanopia, Deuteranopia, and Tritanopia
    static let clarityColorBlindSafe = ColorBlindPalette()
    
    struct ColorBlindPalette {
        // Use shapes and patterns in addition to colors
        let success = Color(red: 0.0, green: 0.5, blue: 0.0) // Dark green
        let warning = Color(red: 1.0, green: 0.6, blue: 0.0) // Orange
        let error = Color(red: 0.8, green: 0.0, blue: 0.0) // Dark red
        let info = Color(red: 0.0, green: 0.4, blue: 0.8) // Blue
        
        // Health categories with distinct hues
        let activity = Color(red: 0.0, green: 0.6, blue: 0.4) // Teal
        let heart = Color(red: 0.9, green: 0.3, blue: 0.3) // Coral
        let sleep = Color(red: 0.3, green: 0.3, blue: 0.7) // Indigo
        let nutrition = Color(red: 0.9, green: 0.6, blue: 0.0) // Amber
    }
}

// MARK: - Pattern Overlays for Accessibility
struct AccessibilityPattern: ViewModifier {
    let pattern: PatternType
    @Environment(\.colorSchemeContrast) private var contrast
    
    enum PatternType {
        case stripes
        case dots
        case cross
        case none
    }
    
    func body(content: Content) -> some View {
        content
            .overlay(
                contrast == .increased ? 
                    PatternOverlay(type: pattern) : nil
            )
    }
}
```

## Motion & Animation

### 1. Reduced Motion Support

```swift
// MARK: - Motion Sensitive Animations
extension View {
    func accessibilityAnimation<V>(
        _ animation: Animation? = .default,
        value: V
    ) -> some View where V: Equatable {
        self.animation(
            UIAccessibility.isReduceMotionEnabled ? .none : animation,
            value: value
        )
    }
    
    func accessibilityTransition(
        _ transition: AnyTransition
    ) -> some View {
        self.transition(
            UIAccessibility.isReduceMotionEnabled 
                ? .opacity 
                : transition
        )
    }
}

// MARK: - Adaptive Loading Indicators
struct AccessibleLoadingView: View {
    @State private var isAnimating = false
    
    var body: some View {
        Group {
            if UIAccessibility.isReduceMotionEnabled {
                // Static indicator for reduced motion
                Image(systemName: "hourglass")
                    .font(.largeTitle)
                    .foregroundColor(.claritySecondaryLabel)
            } else {
                // Animated indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
            }
        }
        .accessibilityLabel("Loading")
        .accessibilityHint("Please wait while we load your health data")
    }
}
```

### 2. Haptic Feedback

```swift
// MARK: - Accessible Haptics
struct AccessibleHaptics {
    static func impact(
        _ style: UIImpactFeedbackGenerator.FeedbackStyle,
        intensity: CGFloat = 1.0
    ) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred(intensity: intensity)
    }
    
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
    
    static func selection() {
        guard !UIAccessibility.isReduceMotionEnabled else { return }
        
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
}
```

## Focus Management

### 1. Focus Order & Navigation

```swift
// MARK: - Accessibility Focus Management
struct HealthDashboardView: View {
    @AccessibilityFocusState private var isHeaderFocused: Bool
    @AccessibilityFocusState private var isFirstMetricFocused: Bool
    @State private var shouldAnnounceUpdate = false
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header with focus management
                HeaderView()
                    .accessibilityFocused($isHeaderFocused)
                    .accessibilitySortPriority(1000)
                
                // Metrics section
                VStack(alignment: .leading, spacing: 16) {
                    Text("Today's Summary")
                        .font(.clarityTitle3)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilitySortPriority(900)
                    
                    ForEach(Array(metrics.enumerated()), id: \.1.id) { index, metric in
                        HealthMetricCard(metric: metric)
                            .accessibilityFocused(
                                index == 0 ? $isFirstMetricFocused : .constant(false)
                            )
                            .accessibilitySortPriority(800 - index * 10)
                    }
                }
            }
        }
        .onAppear {
            // Set initial focus
            if UIAccessibility.isVoiceOverRunning {
                isHeaderFocused = true
            }
        }
        .onChange(of: metrics) { _ in
            announceDataUpdate()
        }
    }
    
    private func announceDataUpdate() {
        guard UIAccessibility.isVoiceOverRunning else { return }
        
        let announcement = "Health data updated. \(metrics.count) metrics available."
        
        UIAccessibility.post(
            notification: .announcement,
            argument: announcement
        )
    }
}
```

### 2. Modal & Alert Accessibility

```swift
// MARK: - Accessible Alerts
struct AccessibleAlert: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String
    let actions: [AlertAction]
    
    struct AlertAction {
        let title: String
        let role: ButtonRole?
        let action: () -> Void
    }
    
    func body(content: Content) -> some View {
        content
            .alert(title, isPresented: $isPresented) {
                ForEach(actions, id: \.title) { action in
                    Button(action.title, role: action.role) {
                        action.action()
                        
                        // Announce action result
                        announceActionResult(action.title)
                    }
                }
            } message: {
                Text(message)
            }
            .onChange(of: isPresented) { presented in
                if presented {
                    // Post accessibility notification
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        UIAccessibility.post(
                            notification: .screenChanged,
                            argument: "\(title). \(message)"
                        )
                    }
                }
            }
    }
    
    private func announceActionResult(_ action: String) {
        let announcement = "\(action) selected"
        
        UIAccessibility.post(
            notification: .announcement,
            argument: announcement
        )
    }
}
```

## Form Accessibility

### 1. Input Field Accessibility

```swift
// MARK: - Accessible Text Field
struct AccessibleHealthDataInput: View {
    let title: String
    let unit: String
    @Binding var value: String
    let validator: (String) -> ValidationResult
    
    @State private var validationResult: ValidationResult = .valid
    @AccessibilityFocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.clarityScalable(.subheadline))
                .foregroundColor(.claritySecondaryLabel)
                .accessibilityHidden(true) // Included in field label
            
            HStack {
                TextField("", text: $value)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.decimalPad)
                    .accessibilityLabel("\(title) input field")
                    .accessibilityValue("\(value.isEmpty ? "empty" : value) \(unit)")
                    .accessibilityHint(accessibilityHint)
                    .accessibilityFocused($isFocused)
                    .accessibilityIdentifier("health_input_\(title.lowercased())")
                    .onChange(of: value) { newValue in
                        validationResult = validator(newValue)
                        announceValidationResult()
                    }
                
                Text(unit)
                    .font(.clarityScalable(.body))
                    .foregroundColor(.claritySecondaryLabel)
                    .accessibilityHidden(true) // Included in field value
            }
            
            if case .invalid(let message) = validationResult {
                Label(message, systemImage: "exclamationmark.circle.fill")
                    .font(.clarityScalable(.caption1))
                    .foregroundColor(.clarityError)
                    .accessibilityLabel("Error: \(message)")
            }
        }
    }
    
    private var accessibilityHint: String {
        switch title {
        case "Blood Pressure":
            return "Enter systolic value. Normal range is 90 to 120"
        case "Heart Rate":
            return "Enter beats per minute. Normal range is 60 to 100"
        case "Weight":
            return "Enter your weight in \(unit)"
        default:
            return "Enter \(title) value"
        }
    }
    
    private func announceValidationResult() {
        guard UIAccessibility.isVoiceOverRunning else { return }
        
        switch validationResult {
        case .valid:
            break // No announcement for valid input
        case .invalid(let message):
            UIAccessibility.post(
                notification: .announcement,
                argument: message
            )
        case .warning(let message):
            UIAccessibility.post(
                notification: .announcement,
                argument: "Warning: \(message)"
            )
        }
    }
    
    enum ValidationResult {
        case valid
        case invalid(String)
        case warning(String)
    }
}
```

## Testing Accessibility

### 1. Automated Testing

```swift
// MARK: - Accessibility Tests
final class AccessibilityTests: XCTestCase {
    func test_healthMetricCard_hasCorrectAccessibilityTraits() {
        // Given
        let metric = HealthMetric(
            title: "Heart Rate",
            value: "72",
            unit: "BPM",
            icon: "heart.fill"
        )
        
        // When
        let view = HealthMetricCard(metric: metric)
        let host = UIHostingController(rootView: view)
        
        // Then
        XCTAssertTrue(host.view.accessibilityTraits.contains(.button))
        XCTAssertEqual(host.view.accessibilityLabel, "Heart Rate metric")
        XCTAssertEqual(host.view.accessibilityValue, "72 BPM")
        XCTAssertFalse(host.view.accessibilityHint?.isEmpty ?? true)
    }
    
    func test_colorContrast_meetsWCAG_AA() {
        // Test all color combinations
        let combinations: [(foreground: UIColor, background: UIColor)] = [
            (.clarityLabel, .clarityBackground),
            (.claritySecondaryLabel, .clarityBackground),
            (.white, .clarityPrimary),
            (.clarityError, .clarityBackground)
        ]
        
        for combination in combinations {
            let isValid = ContrastValidator.validateContrast(
                foreground: combination.foreground,
                background: combination.background,
                level: .aa
            )
            
            XCTAssertTrue(
                isValid,
                "Color combination failed WCAG AA: \(combination)"
            )
        }
    }
}
```

### 2. Manual Testing Checklist

```swift
// MARK: - Accessibility Audit Checklist
struct AccessibilityAudit {
    static let voiceOverChecklist = [
        "All interactive elements are reachable",
        "Labels are clear and descriptive",
        "Values update dynamically",
        "Hints provide useful context",
        "Custom actions work correctly",
        "Rotor navigation is logical",
        "Announcements are timely and relevant",
        "Focus order follows visual hierarchy",
        "Modal presentations announce correctly",
        "Gestures have accessible alternatives"
    ]
    
    static let dynamicTypeChecklist = [
        "Text scales appropriately",
        "Layouts adapt at larger sizes",
        "No text truncation at maximum size",
        "Icons scale with text",
        "Spacing adjusts proportionally",
        "Horizontal layouts switch to vertical when needed"
    ]
    
    static let colorAndContrastChecklist = [
        "4.5:1 contrast for normal text",
        "3:1 contrast for large text",
        "3:1 contrast for UI elements",
        "Information not conveyed by color alone",
        "High contrast mode supported",
        "Dark mode maintains contrast ratios"
    ]
    
    static let motionChecklist = [
        "Reduce Motion disables animations",
        "Essential animations have alternatives",
        "No auto-playing videos",
        "Parallax effects can be disabled",
        "Loading states are accessible"
    ]
}
```

## Best Practices Summary

1. **Always test with assistive technologies** - Real device testing is essential
2. **Design with accessibility first** - Not as an afterthought
3. **Use semantic colors and fonts** - Let the system handle adaptations
4. **Provide multiple ways to access information** - Visual, auditory, and haptic
5. **Keep accessibility labels concise but descriptive** - Balance detail with brevity
6. **Test at all Dynamic Type sizes** - Especially accessibility sizes
7. **Validate color contrast** - Use tools to verify WCAG compliance
8. **Respect user preferences** - Motion, contrast, transparency
9. **Make gestures optional** - Always provide button alternatives
10. **Document accessibility features** - Help users discover them

## Resources

- [Apple Accessibility Guidelines](https://developer.apple.com/accessibility/)
- [WCAG 2.1 Guidelines](https://www.w3.org/WAI/WCAG21/quickref/)
- [iOS Accessibility Handbook](https://developer.apple.com/accessibility/ios/)
- [SwiftUI Accessibility](https://developer.apple.com/documentation/swiftui/view-accessibility)