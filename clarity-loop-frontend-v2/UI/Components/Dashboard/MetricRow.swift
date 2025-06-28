//
//  MetricRow.swift
//  clarity-loop-frontend-v2
//
//  Extracted from DashboardView for better modularity
//

import SwiftUI
import ClarityDomain

public struct MetricRow: View {
    let metric: HealthMetric
    let previousValue: Double?
    
    @State private var isExpanded = false
    
    public init(metric: HealthMetric, previousValue: Double? = nil) {
        self.metric = metric
        self.previousValue = previousValue
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                // Metric Icon
                Image(systemName: metric.type.icon)
                    .font(.title2)
                    .foregroundColor(metric.type.color)
                    .frame(width: 40, height: 40)
                    .background(metric.type.color.opacity(0.1))
                    .cornerRadius(10)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(metric.type.displayName)
                        .font(.headline)
                    
                    Text(formatDate(metric.recordedAt))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(metric.formattedValue)
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text(metric.unit)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Trend indicator
                    if let previous = previousValue {
                        TrendIndicator(current: metric.value, previous: previous)
                    }
                }
            }
            .padding()
            
            // Expandable notes section
            if let notes = metric.notes, !notes.isEmpty {
                if isExpanded {
                    VStack(alignment: .leading, spacing: 8) {
                        Divider()
                        
                        Text("Notes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(notes)
                            .font(.footnote)
                    }
                    .padding(.horizontal)
                    .padding(.bottom)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        #if os(iOS)
        .background(Color(.systemGray6))
        #else
        .background(Color.gray.opacity(0.1))
        #endif
        .cornerRadius(12)
        .onTapGesture {
            if metric.notes != nil {
                withAnimation(.spring(duration: 0.3)) {
                    isExpanded.toggle()
                }
            }
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - HealthMetric Extension for Formatting
extension HealthMetric {
    var formattedValue: String {
        switch type {
        case .steps, .heartRate, .bloodPressureSystolic, .bloodPressureDiastolic:
            return "\(Int(value))"
        case .weight, .height, .bodyTemperature, .bloodGlucose:
            return String(format: "%.1f", value)
        default:
            return String(format: "%.2f", value)
        }
    }
}
