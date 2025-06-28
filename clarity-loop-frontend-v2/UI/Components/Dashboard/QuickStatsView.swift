//
//  QuickStatsView.swift
//  clarity-loop-frontend-v2
//
//  Horizontal scrolling quick stats cards for dashboard
//

import SwiftUI
import ClarityDomain

public struct QuickStatsView: View {
    let viewModel: DashboardViewModel
    
    public init(viewModel: DashboardViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 16) {
                if let heartRateSummary = viewModel.summaryForType(HealthMetricType.heartRate) {
                    QuickStatCard(
                        icon: "heart.fill",
                        title: "Heart Rate",
                        value: "\(Int(heartRateSummary.latest))",
                        unit: "BPM",
                        color: .red
                    )
                }
                
                if let stepsSummary = viewModel.summaryForType(HealthMetricType.steps) {
                    QuickStatCard(
                        icon: "figure.walk",
                        title: "Steps",
                        value: "\(Int(stepsSummary.latest))",
                        unit: "steps",
                        color: .green
                    )
                }
                
                if let weightSummary = viewModel.summaryForType(HealthMetricType.weight) {
                    QuickStatCard(
                        icon: "scalemass.fill",
                        title: "Weight",
                        value: String(format: "%.1f", weightSummary.latest),
                        unit: "kg",
                        color: .blue
                    )
                }
                
                if let glucoseSummary = viewModel.summaryForType(HealthMetricType.bloodGlucose) {
                    QuickStatCard(
                        icon: "drop.fill",
                        title: "Glucose",
                        value: String(format: "%.1f", glucoseSummary.latest),
                        unit: "mg/dL",
                        color: .orange
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

// MARK: - Quick Stat Card
public struct QuickStatCard: View {
    let icon: String
    let title: String
    let value: String
    let unit: String
    let color: Color
    
    public init(icon: String, title: String, value: String, unit: String, color: Color) {
        self.icon = icon
        self.title = title
        self.value = value
        self.unit = unit
        self.color = color
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.title2)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(alignment: .lastTextBaseline, spacing: 4) {
                    Text(value)
                        .font(.title)
                        .fontWeight(.semibold)
                    
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(width: 150)
        #if os(iOS)
        .background(Color(.systemGray6))
        #else
        .background(Color.gray.opacity(0.1))
        #endif
        .cornerRadius(12)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value) \(unit)")
    }
}

// MARK: - SwiftUI Preview
#if DEBUG
struct QuickStatsView_Previews: PreviewProvider {
    static var previews: some View {
        QuickStatCard(
            icon: "heart.fill",
            title: "Heart Rate",
            value: "72",
            unit: "BPM",
            color: .red
        )
        .previewLayout(.sizeThatFits)
        .padding()
    }
}
#endif
