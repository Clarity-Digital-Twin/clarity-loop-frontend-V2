import SwiftUI

struct PATAnalysisView: View {
    @Environment(\.healthKitService) private var healthKitService
    @Environment(\.insightsRepository) private var insightsRepository
    @State private var isAnalyzing = false
    @State private var analysisProgress = 0.0
    @State private var currentStep = ""
    @State private var analysisResult: PATAnalysisViewResult?
    @State private var error: Error?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if isAnalyzing {
                        AnalysisProgressView(
                            progress: analysisProgress,
                            currentStep: currentStep
                        )
                    } else if let result = analysisResult {
                        AnalysisResultView(result: result)
                    } else {
                        StartAnalysisView(onStart: startAnalysis)
                    }
                    
                    if let error {
                        ErrorView(
                            title: "Analysis Failed",
                            message: error.localizedDescription,
                            systemImage: "exclamationmark.triangle.fill",
                            retryAction: startAnalysis
                        )
                    }
                }
                .padding()
            }
            .navigationTitle("PAT Analysis")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    private func startAnalysis() {
        Task {
            await performAnalysis()
        }
    }
    
    @MainActor
    private func performAnalysis() async {
        isAnalyzing = true
        analysisProgress = 0.0
        error = nil
        
        do {
            // Step 1: Fetch sleep data
            currentStep = "Fetching sleep data..."
            analysisProgress = 0.2
            
            let endDate = Date()
            let startDate = Calendar.current.date(byAdding: .day, value: -30, to: endDate)!
            
            // For now, simulate fetching data since these methods aren't in the protocol
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            // Step 2: Fetch activity data
            currentStep = "Fetching activity data..."
            analysisProgress = 0.4
            
            // Simulate activity data fetch
            try await Task.sleep(nanoseconds: 1_000_000_000)
            
            // Step 3: Analyze patterns
            currentStep = "Analyzing patterns..."
            analysisProgress = 0.6
            
            // Simulate analysis time
            try await Task.sleep(nanoseconds: 2_000_000_000)
            
            // Step 4: Generate insights
            currentStep = "Generating insights..."
            analysisProgress = 0.8
            
            // Create mock result (in real app, this would come from backend)
            let result = PATAnalysisViewResult(
                overallScore: 85,
                sleepQuality: 78,
                activityLevel: 92,
                consistency: 81,
                insights: [
                    "Your sleep consistency has improved by 15% this month",
                    "Peak activity times align well with optimal circadian rhythm",
                    "Consider earlier bedtime on weekdays for better recovery"
                ],
                recommendations: [
                    "Maintain your current wake time consistency",
                    "Add 10 minutes of morning light exposure",
                    "Reduce screen time 1 hour before bed"
                ]
            )
            
            analysisProgress = 1.0
            currentStep = "Analysis complete!"
            
            // Wait a moment before showing results
            try await Task.sleep(nanoseconds: 500_000_000)
            
            analysisResult = result
            isAnalyzing = false
            
        } catch {
            self.error = error
            isAnalyzing = false
        }
    }
}

// MARK: - Start Analysis View

struct StartAnalysisView: View {
    let onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Image(systemName: "waveform.path.ecg")
                .font(.system(size: 80))
                .foregroundColor(.blue)
                .symbolRenderingMode(.hierarchical)
            
            VStack(spacing: 16) {
                Text("Personalized Activity & Timing Analysis")
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                Text("Analyze your sleep patterns and activity levels to optimize your daily routine and improve overall health.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(alignment: .leading, spacing: 12) {
                FeatureRow(
                    icon: "moon.zzz.fill",
                    title: "Sleep Analysis",
                    description: "Understand your sleep quality and patterns"
                )
                
                FeatureRow(
                    icon: "figure.run",
                    title: "Activity Tracking",
                    description: "Analyze your movement and exercise habits"
                )
                
                FeatureRow(
                    icon: "brain.head.profile",
                    title: "AI Insights",
                    description: "Get personalized recommendations"
                )
            }
            .padding(.horizontal)
            
            Button(action: onStart) {
                Label("Start Analysis", systemImage: "play.fill")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(12)
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

// MARK: - Analysis Progress View

struct AnalysisProgressView: View {
    let progress: Double
    let currentStep: String
    
    var body: some View {
        VStack(spacing: 32) {
            // Animated waveform
            WaveformAnimationView()
                .frame(height: 120)
            
            VStack(spacing: 16) {
                Text("Analyzing Your Data")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(currentStep)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .animation(.easeInOut, value: currentStep)
            }
            
            // Progress indicator
            VStack(spacing: 12) {
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(x: 1, y: 2, anchor: .center)
                
                Text("\(Int(progress * 100))%")
                    .font(.headline)
                    .foregroundColor(.blue)
            }
            .padding(.horizontal)
            
            // Step indicators
            HStack(spacing: 40) {
                AnalysisStep(
                    icon: "moon.zzz",
                    title: "Sleep",
                    isActive: progress >= 0,
                    isComplete: progress >= 0.3
                )
                
                AnalysisStep(
                    icon: "figure.walk",
                    title: "Activity",
                    isActive: progress >= 0.3,
                    isComplete: progress >= 0.5
                )
                
                AnalysisStep(
                    icon: "brain",
                    title: "Analysis",
                    isActive: progress >= 0.5,
                    isComplete: progress >= 0.8
                )
                
                AnalysisStep(
                    icon: "lightbulb",
                    title: "Insights",
                    isActive: progress >= 0.8,
                    isComplete: progress >= 1.0
                )
            }
            .padding(.horizontal)
        }
        .padding(.vertical)
    }
}

// MARK: - Analysis Step

struct AnalysisStep: View {
    let icon: String
    let title: String
    let isActive: Bool
    let isComplete: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(backgroundColor)
                    .frame(width: 50, height: 50)
                
                Image(systemName: isComplete ? "checkmark" : icon)
                    .font(.title3)
                    .foregroundColor(iconColor)
            }
            
            Text(title)
                .font(.caption)
                .foregroundColor(textColor)
        }
        .animation(.spring(), value: isActive)
        .animation(.spring(), value: isComplete)
    }
    
    private var backgroundColor: Color {
        if isComplete {
            return .green.opacity(0.2)
        } else if isActive {
            return .blue.opacity(0.2)
        } else {
            return Color(.systemGray5)
        }
    }
    
    private var iconColor: Color {
        if isComplete || isActive {
            return isComplete ? .green : .blue
        } else {
            return .secondary
        }
    }
    
    private var textColor: Color {
        isActive || isComplete ? .primary : .secondary
    }
}

// MARK: - Waveform Animation

struct WaveformAnimationView: View {
    @State private var phase = 0.0
    
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let midHeight = height / 2
                
                path.move(to: CGPoint(x: 0, y: midHeight))
                
                for x in stride(from: 0, to: width, by: 2) {
                    let relativeX = x / width
                    let sine = sin((relativeX + phase) * .pi * 4)
                    let y = midHeight + sine * (height / 3)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(
                LinearGradient(
                    colors: [.blue, .purple],
                    startPoint: .leading,
                    endPoint: .trailing
                ),
                lineWidth: 3
            )
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

// MARK: - Analysis Result View

struct AnalysisResultView: View {
    let result: PATAnalysisViewResult
    
    var body: some View {
        VStack(spacing: 24) {
            // Overall score
            ScoreCircleView(
                score: result.overallScore,
                title: "Overall PAT Score"
            )
            
            // Category scores
            HStack(spacing: 20) {
                ScoreCardView(
                    title: "Sleep",
                    score: result.sleepQuality,
                    icon: "moon.zzz.fill",
                    color: .purple
                )
                
                ScoreCardView(
                    title: "Activity",
                    score: result.activityLevel,
                    icon: "figure.run",
                    color: .green
                )
                
                ScoreCardView(
                    title: "Consistency",
                    score: result.consistency,
                    icon: "chart.line.uptrend.xyaxis",
                    color: .orange
                )
            }
            
            // Insights
            VStack(alignment: .leading, spacing: 16) {
                Text("Key Insights")
                    .font(.headline)
                
                ForEach(result.insights, id: \.self) { insight in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                        
                        Text(insight)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
            )
            
            // Recommendations
            VStack(alignment: .leading, spacing: 16) {
                Text("Recommendations")
                    .font(.headline)
                
                ForEach(Array(result.recommendations.enumerated()), id: \.offset) { index, recommendation in
                    HStack(alignment: .top, spacing: 12) {
                        Text("\(index + 1).")
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        
                        Text(recommendation)
                            .font(.callout)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue.opacity(0.1))
            )
        }
    }
}

// MARK: - Supporting Views

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.callout)
                    .fontWeight(.semibold)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

struct ScoreCircleView: View {
    let score: Int
    let title: String
    
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(lineWidth: 20)
                    .opacity(0.3)
                    .foregroundColor(.blue)
                
                Circle()
                    .trim(from: 0.0, to: CGFloat(score) / 100.0)
                    .stroke(style: StrokeStyle(lineWidth: 20, lineCap: .round, lineJoin: .round))
                    .foregroundColor(.blue)
                    .rotationEffect(Angle(degrees: 270.0))
                    .animation(.spring(), value: score)
                
                VStack(spacing: 4) {
                    Text("\(score)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    
                    Text("out of 100")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 200, height: 200)
            
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)
        }
    }
}

struct ScoreCardView: View {
    let title: String
    let score: Int
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            
            Text("\(score)")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(color.opacity(0.1))
        )
    }
}

// MARK: - Data Models

struct PATAnalysisViewResult {
    let overallScore: Int
    let sleepQuality: Int
    let activityLevel: Int
    let consistency: Int
    let insights: [String]
    let recommendations: [String]
}

// MARK: - Preview

#Preview {
    PATAnalysisView()
}