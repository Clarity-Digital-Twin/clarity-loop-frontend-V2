import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var currentPage = 0
    
    private let totalPages = 4
    
    var body: some View {
        TabView(selection: $currentPage) {
            OnboardingPageView(
                title: "Welcome to CLARITY Pulse",
                subtitle: "Your personal health companion",
                imageName: "heart.text.square.fill",
                imageColor: .red,
                description: "Track and understand your health data with AI-powered insights",
                pageIndex: 0
            )
            .tag(0)
            
            OnboardingPageView(
                title: "Connect HealthKit",
                subtitle: "Sync your health data",
                imageName: "figure.walk",
                imageColor: .green,
                description: "Securely sync your health metrics from Apple Health to get personalized insights",
                pageIndex: 1
            )
            .tag(1)
            
            OnboardingPageView(
                title: "AI-Powered Analysis",
                subtitle: "Get intelligent insights",
                imageName: "brain",
                imageColor: .purple,
                description: "Our AI analyzes your patterns to provide actionable health recommendations",
                pageIndex: 2
            )
            .tag(2)
            
            OnboardingPageView(
                title: "Your Health Assistant",
                subtitle: "Chat with CLARITY",
                imageName: "bubble.left.and.bubble.right.fill",
                imageColor: .blue,
                description: "Ask questions about your health data and get personalized guidance",
                pageIndex: 3,
                showGetStarted: true,
                onGetStarted: {
                    withAnimation {
                        hasCompletedOnboarding = true
                    }
                }
            )
            .tag(3)
        }
        .tabViewStyle(PageTabViewStyle())
        .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
    }
}

struct OnboardingPageView: View {
    let title: String
    let subtitle: String
    let imageName: String
    let imageColor: Color
    let description: String
    let pageIndex: Int
    var showGetStarted = false
    var onGetStarted: (() -> Void)? = nil
    
    @State private var isAnimating = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            VStack(spacing: 24) {
                // Animated icon
                ZStack {
                    Circle()
                        .fill(imageColor.opacity(0.1))
                        .frame(width: 140, height: 140)
                        .scaleEffect(isAnimating ? 1.1 : 0.9)
                    
                    Image(systemName: imageName)
                        .font(.system(size: 70))
                        .foregroundColor(imageColor)
                        .symbolRenderingMode(.hierarchical)
                        .scaleEffect(isAnimating ? 1.0 : 0.8)
                }
                .animation(
                    .easeInOut(duration: 2.0)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )
                
                VStack(spacing: 16) {
                    Text(title)
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text(subtitle)
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            if showGetStarted, let onGetStarted {
                Button(action: onGetStarted) {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(imageColor)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
            } else {
                // Skip button for non-final pages
                Button(action: {
                    withAnimation {
                        hasCompletedOnboarding = true
                    }
                }) {
                    Text("Skip")
                        .font(.callout)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
    
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
}

// MARK: - Preview

#Preview {
    OnboardingView()
}