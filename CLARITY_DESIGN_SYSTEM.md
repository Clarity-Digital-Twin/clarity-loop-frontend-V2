# CLARITY Design System

## Overview
This design system ensures visual consistency across CLARITY Pulse V2, following Apple's Human Interface Guidelines while establishing our unique health-focused brand identity.

## Design Principles

### 1. Clarity First
- **Clear hierarchy**: Users should instantly understand what's most important
- **Minimal cognitive load**: Simple, intuitive interfaces
- **Progressive disclosure**: Show details only when needed

### 2. Trust & Reliability
- **Medical-grade appearance**: Clean, professional aesthetic
- **Consistent patterns**: Familiar interactions throughout
- **Error prevention**: Guide users to success

### 3. Accessibility Always
- **WCAG AA compliance**: Minimum contrast ratios
- **Dynamic Type support**: All text must scale
- **VoiceOver optimized**: Complete screen reader support

## Color System

### Brand Colors
```swift
extension Color {
    // MARK: - Primary Brand Colors
    static let clarityPrimary = Color("ClarityPrimary") // #007AFF - iOS Blue
    static let claritySecondary = Color("ClaritySecondary") // #5856D6 - Purple
    static let clarityAccent = Color("ClarityAccent") // #32ADE6 - Cyan
    
    // MARK: - Health Category Colors (Apple Health Compatible)
    static let clarityActivity = Color("ClarityActivity") // #1FD655 - Green
    static let clarityMindfulness = Color("ClarityMindfulness") // #5E5CE6 - Indigo
    static let clarityNutrition = Color("ClarityNutrition") // #FF9500 - Orange
    static let claritySleep = Color("ClaritySleep") // #30D5C8 - Turquoise
    static let clarityVitals = Color("ClarityVitals") // #FF3B30 - Red
    static let clarityMedications = Color("ClarityMedications") // #8E8E93 - Gray
    
    // MARK: - Semantic Colors
    static let claritySuccess = Color("ClaritySuccess") // #34C759
    static let clarityWarning = Color("ClarityWarning") // #FF9500
    static let clarityError = Color("ClarityError") // #FF3B30
    static let clarityInfo = Color("ClarityInfo") // #007AFF
    
    // MARK: - Background Colors
    static let clarityBackground = Color("ClarityBackground")
    static let claritySecondaryBackground = Color("ClaritySecondaryBackground")
    static let clarityTertiaryBackground = Color("ClarityTertiaryBackground")
    static let clarityGroupedBackground = Color("ClarityGroupedBackground")
    
    // MARK: - Text Colors
    static let clarityLabel = Color("ClarityLabel")
    static let claritySecondaryLabel = Color("ClaritySecondaryLabel")
    static let clarityTertiaryLabel = Color("ClarityTertiaryLabel")
    static let clarityQuaternaryLabel = Color("ClarityQuaternaryLabel")
    static let clarityPlaceholder = Color("ClarityPlaceholder")
    
    // MARK: - Separator Colors
    static let claritySeparator = Color("ClaritySeparator")
    static let clarityOpaqueSeparator = Color("ClarityOpaqueSeparator")
}
```

### Color Usage Guidelines
```swift
// MARK: - Color Semantic Mapping
struct ColorSemantics {
    // Status Colors
    static let normal = Color.claritySuccess
    static let elevated = Color.clarityWarning
    static let critical = Color.clarityError
    
    // Data Visualization
    static let chartPrimary = Color.clarityPrimary
    static let chartSecondary = Color.claritySecondary
    static let chartTertiary = Color.clarityAccent
    
    // Interactive States
    static let interactive = Color.clarityPrimary
    static let interactivePressed = Color.clarityPrimary.opacity(0.8)
    static let interactiveDisabled = Color.claritySecondaryLabel
}
```

## Typography

### Type Scale
```swift
extension Font {
    // MARK: - Display Styles
    static let clarityLargeTitle = Font.system(size: 34, weight: .bold, design: .rounded)
    static let clarityTitle1 = Font.system(size: 28, weight: .bold, design: .rounded)
    static let clarityTitle2 = Font.system(size: 22, weight: .bold, design: .rounded)
    static let clarityTitle3 = Font.system(size: 20, weight: .semibold, design: .rounded)
    
    // MARK: - Text Styles
    static let clarityHeadline = Font.system(size: 17, weight: .semibold, design: .default)
    static let clarityBody = Font.system(size: 17, weight: .regular, design: .default)
    static let clarityCallout = Font.system(size: 16, weight: .regular, design: .default)
    static let claritySubheadline = Font.system(size: 15, weight: .regular, design: .default)
    static let clarityFootnote = Font.system(size: 13, weight: .regular, design: .default)
    static let clarityCaption1 = Font.system(size: 12, weight: .regular, design: .default)
    static let clarityCaption2 = Font.system(size: 11, weight: .regular, design: .default)
    
    // MARK: - Numeric Styles
    static let clarityMetricLarge = Font.system(size: 52, weight: .bold, design: .rounded)
    static let clarityMetricMedium = Font.system(size: 34, weight: .semibold, design: .rounded)
    static let clarityMetricSmall = Font.system(size: 22, weight: .medium, design: .rounded)
}
```

### Typography Usage
```swift
// MARK: - Text Style Examples
struct TypographyExamples {
    // Headers
    Text("Dashboard")
        .font(.clarityLargeTitle)
        .foregroundColor(.clarityLabel)
    
    // Section Titles
    Text("Today's Summary")
        .font(.clarityTitle3)
        .foregroundColor(.clarityLabel)
    
    // Body Text
    Text("Your heart rate is within normal range")
        .font(.clarityBody)
        .foregroundColor(.claritySecondaryLabel)
    
    // Metric Display
    HStack(alignment: .lastTextBaseline, spacing: 4) {
        Text("72")
            .font(.clarityMetricLarge)
            .foregroundColor(.clarityVitals)
        
        Text("BPM")
            .font(.clarityCallout)
            .foregroundColor(.claritySecondaryLabel)
    }
    
    // Captions
    Text("Last updated 2 minutes ago")
        .font(.clarityCaption1)
        .foregroundColor(.clarityTertiaryLabel)
}
```

## Spacing System

### Grid & Layout
```swift
enum Spacing {
    // MARK: - Base Unit (8pt grid)
    static let unit: CGFloat = 8
    
    // MARK: - Spacing Scale
    static let xxs: CGFloat = unit * 0.5  // 4pt
    static let xs: CGFloat = unit * 1     // 8pt
    static let sm: CGFloat = unit * 1.5   // 12pt
    static let md: CGFloat = unit * 2     // 16pt
    static let lg: CGFloat = unit * 3     // 24pt
    static let xl: CGFloat = unit * 4     // 32pt
    static let xxl: CGFloat = unit * 6    // 48pt
    static let xxxl: CGFloat = unit * 8   // 64pt
    
    // MARK: - Component Spacing
    static let cardPadding = EdgeInsets(
        top: md, leading: md, bottom: md, trailing: md
    )
    
    static let sectionSpacing: CGFloat = lg
    static let itemSpacing: CGFloat = sm
    static let iconTextSpacing: CGFloat = xs
    
    // MARK: - Safe Area Margins
    static let horizontalMargin: CGFloat = md
    static let verticalMargin: CGFloat = md
}
```

## Iconography

### System Icons Usage
```swift
struct ClarityIcons {
    // MARK: - Health Categories
    static let activity = "figure.walk"
    static let heartRate = "heart.fill"
    static let sleep = "bed.double.fill"
    static let nutrition = "fork.knife"
    static let mindfulness = "brain.head.profile"
    static let medications = "pills.fill"
    static let bloodPressure = "drop.fill"
    static let weight = "scalemass.fill"
    static let temperature = "thermometer"
    
    // MARK: - Navigation
    static let dashboard = "square.grid.2x2"
    static let insights = "chart.line.uptrend.xyaxis"
    static let records = "doc.text.fill"
    static let profile = "person.crop.circle"
    static let settings = "gearshape.fill"
    
    // MARK: - Actions
    static let add = "plus.circle.fill"
    static let edit = "pencil"
    static let delete = "trash"
    static let share = "square.and.arrow.up"
    static let filter = "line.3.horizontal.decrease.circle"
    static let search = "magnifyingglass"
    static let refresh = "arrow.clockwise"
    static let sync = "arrow.triangle.2.circlepath"
    
    // MARK: - Status
    static let success = "checkmark.circle.fill"
    static let warning = "exclamationmark.triangle.fill"
    static let error = "xmark.circle.fill"
    static let info = "info.circle.fill"
    
    // MARK: - Trends
    static let trendUp = "arrow.up.circle.fill"
    static let trendDown = "arrow.down.circle.fill"
    static let trendStable = "equal.circle.fill"
}
```

### Icon Styling
```swift
extension Image {
    func clarityIconStyle(
        size: ClarityIconSize = .medium,
        color: Color = .clarityPrimary
    ) -> some View {
        self
            .font(.system(size: size.rawValue))
            .foregroundColor(color)
            .symbolRenderingMode(.hierarchical)
    }
}

enum ClarityIconSize: CGFloat {
    case small = 16
    case medium = 22
    case large = 28
    case xlarge = 34
}
```

## Component Styling

### Buttons
```swift
struct ClarityButtonStyle: ButtonStyle {
    enum Style {
        case primary
        case secondary
        case tertiary
        case destructive
        
        var backgroundColor: Color {
            switch self {
            case .primary: return .clarityPrimary
            case .secondary: return .claritySecondaryBackground
            case .tertiary: return .clear
            case .destructive: return .clarityError
            }
        }
        
        var foregroundColor: Color {
            switch self {
            case .primary, .destructive: return .white
            case .secondary: return .clarityPrimary
            case .tertiary: return .clarityPrimary
            }
        }
    }
    
    let style: Style
    let isFullWidth: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.clarityHeadline)
            .foregroundColor(style.foregroundColor)
            .frame(maxWidth: isFullWidth ? .infinity : nil)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(style.backgroundColor)
            .cornerRadius(12)
            .scaleEffect(configuration.isPressed ? 0.97 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}
```

### Cards
```swift
struct ClarityCardModifier: ViewModifier {
    let backgroundColor: Color
    let hasShadow: Bool
    
    func body(content: Content) -> some View {
        content
            .padding(Spacing.cardPadding)
            .background(backgroundColor)
            .cornerRadius(16)
            .shadow(
                color: hasShadow ? Color.black.opacity(0.05) : .clear,
                radius: 8,
                x: 0,
                y: 2
            )
    }
}

extension View {
    func clarityCard(
        backgroundColor: Color = .claritySecondaryBackground,
        hasShadow: Bool = true
    ) -> some View {
        modifier(ClarityCardModifier(
            backgroundColor: backgroundColor,
            hasShadow: hasShadow
        ))
    }
}
```

### Form Elements
```swift
struct ClarityTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.clarityBody)
            .padding(Spacing.sm)
            .background(Color.clarityTertiaryBackground)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.claritySeparator, lineWidth: 0.5)
            )
    }
}

struct ClarityToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
                .font(.clarityBody)
                .foregroundColor(.clarityLabel)
            
            Spacer()
            
            // Custom toggle implementation
            RoundedRectangle(cornerRadius: 16)
                .fill(configuration.isOn ? Color.clarityPrimary : Color.claritySecondaryBackground)
                .frame(width: 51, height: 31)
                .overlay(
                    Circle()
                        .fill(Color.white)
                        .frame(width: 27, height: 27)
                        .offset(x: configuration.isOn ? 10 : -10)
                )
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        configuration.isOn.toggle()
                    }
                }
        }
    }
}
```

## Animation Guidelines

### Standard Animations
```swift
extension Animation {
    // MARK: - Clarity Standard Animations
    static let claritySpring = Animation.spring(
        response: 0.5,
        dampingFraction: 0.8,
        blendDuration: 0
    )
    
    static let clarityEase = Animation.easeInOut(duration: 0.3)
    static let clarityQuick = Animation.easeInOut(duration: 0.2)
    static let claritySlow = Animation.easeInOut(duration: 0.5)
    
    // MARK: - Specialized Animations
    static let clarityBounce = Animation.interpolatingSpring(
        stiffness: 180,
        damping: 15
    )
    
    static let claritySlide = Animation.easeOut(duration: 0.25)
}
```

### Animation Usage
```swift
// MARK: - Animation Examples
struct AnimationExamples {
    // View appearance
    @State private var isVisible = false
    
    var body: some View {
        VStack {
            // Fade in
            if isVisible {
                ContentView()
                    .transition(.opacity)
                    .animation(.clarityEase, value: isVisible)
            }
            
            // Scale animation
            HeartIcon()
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .animation(.clarityBounce, value: isAnimating)
            
            // Progress animation
            ProgressBar(value: progress)
                .animation(.claritySpring, value: progress)
        }
    }
}
```

## Layout Patterns

### Dashboard Grid
```swift
struct DashboardLayout {
    static let columns = [
        GridItem(.flexible(), spacing: Spacing.md),
        GridItem(.flexible(), spacing: Spacing.md)
    ]
    
    static let compactColumns = [
        GridItem(.flexible())
    ]
    
    static func columnsForSizeClass(_ sizeClass: UserInterfaceSizeClass?) -> [GridItem] {
        sizeClass == .compact ? compactColumns : columns
    }
}
```

### List Styles
```swift
struct ClarityListStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listStyle(InsetGroupedListStyle())
            .scrollContentBackground(.hidden)
            .background(Color.clarityGroupedBackground)
    }
}

// Usage
List {
    // Content
}
.modifier(ClarityListStyle())
```

### Navigation Patterns
```swift
struct ClarityNavigationStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .navigationBarTitleDisplayMode(.large)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarBackground(Color.clarityBackground, for: .navigationBar)
    }
}
```

## Dark Mode Support

### Adaptive Colors
All colors in the design system automatically adapt to dark mode:

```swift
// In Assets.xcassets, define color sets with:
// - Any Appearance (Light)
// - Dark Appearance

// Example Color Definition:
ClarityPrimary:
- Light: #007AFF
- Dark: #0A84FF

ClarityBackground:
- Light: #FFFFFF
- Dark: #000000

ClaritySecondaryBackground:
- Light: #F2F2F7
- Dark: #1C1C1E
```

### Testing Dark Mode
```swift
#if DEBUG
struct DarkModePreview<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        Group {
            content
                .preferredColorScheme(.light)
                .previewDisplayName("Light Mode")
            
            content
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
        }
    }
}
#endif
```

## Accessibility

### Color Contrast Requirements
- Normal text: 4.5:1 minimum
- Large text: 3:1 minimum
- Interactive elements: 3:1 minimum

### Focus Indicators
```swift
extension View {
    func clarityFocusable() -> some View {
        self
            .focusable()
            .focusEffectDisabled(false)
            .accessibilityAddTraits(.isButton)
    }
}
```

## Motion & Haptics

### Haptic Feedback
```swift
struct ClarityHaptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    static func selection() {
        let generator = UISelectionFeedbackGenerator()
        generator.prepare()
        generator.selectionChanged()
    }
    
    static func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}

// Usage
Button("Save") {
    ClarityHaptics.impact(.light)
    // Save action
}
```

## Component Examples

### Health Metric Card
```swift
struct HealthMetricCardExample: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            HStack {
                Image(systemName: ClarityIcons.heartRate)
                    .clarityIconStyle(size: .medium, color: .clarityVitals)
                
                Text("Heart Rate")
                    .font(.clarityHeadline)
                    .foregroundColor(.claritySecondaryLabel)
                
                Spacer()
                
                Image(systemName: ClarityIcons.trendStable)
                    .clarityIconStyle(size: .small, color: .clarityWarning)
            }
            
            HStack(alignment: .lastTextBaseline, spacing: Spacing.xxs) {
                Text("72")
                    .font(.clarityMetricMedium)
                    .foregroundColor(.clarityLabel)
                
                Text("BPM")
                    .font(.clarityCallout)
                    .foregroundColor(.claritySecondaryLabel)
            }
            
            Text("Updated 2 min ago")
                .font(.clarityCaption1)
                .foregroundColor(.clarityTertiaryLabel)
        }
        .clarityCard()
    }
}
```

### Empty State
```swift
struct EmptyStateExample: View {
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "heart.text.square")
                .font(.system(size: 64))
                .foregroundColor(.claritySecondaryLabel)
                .symbolRenderingMode(.hierarchical)
            
            VStack(spacing: Spacing.xs) {
                Text("No Health Data")
                    .font(.clarityTitle3)
                    .foregroundColor(.clarityLabel)
                
                Text("Connect your Apple Watch to start tracking")
                    .font(.clarityBody)
                    .foregroundColor(.claritySecondaryLabel)
                    .multilineTextAlignment(.center)
            }
            
            Button("Connect Apple Watch") {
                // Action
            }
            .buttonStyle(ClarityButtonStyle(style: .primary, isFullWidth: false))
        }
        .padding(Spacing.xl)
    }
}
```

## Design Tokens Export
```swift
// For design tool integration
struct ClarityDesignTokens {
    static let tokens: [String: Any] = [
        "colors": [
            "primary": "#007AFF",
            "secondary": "#5856D6",
            "activity": "#1FD655",
            // ... all colors
        ],
        "typography": [
            "largeTitle": ["size": 34, "weight": "bold"],
            "title1": ["size": 28, "weight": "bold"],
            // ... all text styles
        ],
        "spacing": [
            "xxs": 4,
            "xs": 8,
            "sm": 12,
            // ... all spacing values
        ],
        "radius": [
            "small": 8,
            "medium": 12,
            "large": 16
        ]
    ]
}
```

## Implementation Checklist

- [ ] Import color assets into Assets.xcassets
- [ ] Create Color+Clarity.swift extension
- [ ] Create Font+Clarity.swift extension
- [ ] Create standard ViewModifiers
- [ ] Create component library
- [ ] Set up design token documentation
- [ ] Create Figma/Sketch library
- [ ] Test all components in light/dark mode
- [ ] Verify accessibility compliance
- [ ] Create component playground