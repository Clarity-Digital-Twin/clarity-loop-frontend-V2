import SwiftUI

/// A reusable loading view component with various styles
struct LoadingView: View {
    let message: String?
    let style: LoadingStyle
    
    init(message: String? = nil, style: LoadingStyle = .standard) {
        self.message = message
        self.style = style
    }
    
    var body: some View {
        switch style {
        case .standard:
            standardLoadingView
        case .fullScreen:
            fullScreenLoadingView
        case .inline:
            inlineLoadingView
        case .overlay:
            overlayLoadingView
        }
    }
    
    // MARK: - View Styles
    
    private var standardLoadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
            
            if let message {
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
    
    private var fullScreenLoadingView: some View {
        VStack(spacing: 24) {
            Spacer()
            
            ProgressView()
                .scaleEffect(2.0)
                .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
            
            if let message {
                Text(message)
                    .font(.title3)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    private var inlineLoadingView: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.8)
            
            if let message {
                Text(message)
                    .font(.callout)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var overlayLoadingView: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            standardLoadingView
        }
    }
}

// MARK: - Loading Style

enum LoadingStyle {
    case standard
    case fullScreen
    case inline
    case overlay
}

// MARK: - Specialized Loading Views

struct DataLoadingView: View {
    let dataType: String
    
    var body: some View {
        LoadingView(
            message: "Loading \(dataType)...",
            style: .standard
        )
    }
}

struct SyncingView: View {
    let progress: Double?
    
    var body: some View {
        VStack(spacing: 20) {
            if let progress {
                CircularProgressView(progress: progress)
                    .frame(width: 60, height: 60)
            } else {
                ProgressView()
                    .scaleEffect(1.5)
                    .progressViewStyle(CircularProgressViewStyle(tint: .accentColor))
            }
            
            Text("Syncing health data...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
}

struct ProcessingView: View {
    let message: String
    
    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 8) {
                ForEach(0..<3) { index in
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 12, height: 12)
                        .opacity(0.3)
                        .animation(
                            Animation.easeInOut(duration: 0.6)
                                .repeatForever()
                                .delay(Double(index) * 0.2),
                            value: true
                        )
                        .onAppear {
                            withAnimation {
                                // Trigger animation
                            }
                        }
                }
            }
            
            Text(message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(40)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 5)
        )
    }
}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: 8)
                .opacity(0.3)
                .foregroundColor(.accentColor)
            
            Circle()
                .trim(from: 0.0, to: CGFloat(min(progress, 1.0)))
                .stroke(style: StrokeStyle(lineWidth: 8, lineCap: .round, lineJoin: .round))
                .foregroundColor(.accentColor)
                .rotationEffect(Angle(degrees: 270.0))
                .animation(.linear, value: progress)
            
            Text("\(Int(progress * 100))%")
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
}

// MARK: - Shimmer Loading Effect

struct ShimmerView: View {
    @State private var isAnimating = false
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color.gray.opacity(0.3),
                Color.gray.opacity(0.1),
                Color.gray.opacity(0.3)
            ]),
            startPoint: .leading,
            endPoint: .trailing
        )
        .animation(
            Animation.linear(duration: 1.5)
                .repeatForever(autoreverses: false),
            value: isAnimating
        )
        .offset(x: isAnimating ? 300 : -300)
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Skeleton Loading

struct SkeletonLoadingView<Content: View>: View {
    let isLoading: Bool
    @ViewBuilder let content: () -> Content
    
    var body: some View {
        if isLoading {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.3))
                .overlay(ShimmerView().mask(RoundedRectangle(cornerRadius: 8)))
        } else {
            content()
        }
    }
}

// MARK: - Preview

#Preview("Standard Loading") {
    LoadingView(message: "Loading your data...", style: .standard)
}

#Preview("Full Screen Loading") {
    LoadingView(message: "Please wait...", style: .fullScreen)
}

#Preview("Inline Loading") {
    LoadingView(message: "Updating...", style: .inline)
}

#Preview("Overlay Loading") {
    ZStack {
        Color.blue.opacity(0.3)
            .ignoresSafeArea()
        
        LoadingView(message: "Processing...", style: .overlay)
    }
}

#Preview("Syncing View") {
    SyncingView(progress: 0.65)
}

#Preview("Processing View") {
    ProcessingView(message: "Analyzing your health data...")
}

#Preview("Skeleton Loading") {
    VStack(spacing: 16) {
        SkeletonLoadingView(isLoading: true) {
            Text("Loaded Content")
        }
        .frame(height: 60)
        .frame(maxWidth: .infinity)
        
        SkeletonLoadingView(isLoading: false) {
            Text("This content is loaded")
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(8)
        }
    }
    .padding()
}