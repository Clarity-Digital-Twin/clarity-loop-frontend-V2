//
//  TrendIndicator.swift
//  clarity-loop-frontend-v2
//
//  Shows trend direction and percentage change between values
//

import SwiftUI

public struct TrendIndicator: View {
    let current: Double
    let previous: Double
    
    public init(current: Double, previous: Double) {
        self.current = current
        self.previous = previous
    }
    
    private var trend: Trend {
        if current > previous {
            return .up
        } else if current < previous {
            return .down
        } else {
            return .stable
        }
    }
    
    private var percentageChange: Double {
        guard previous != 0 else { return 0 }
        return ((current - previous) / previous) * 100
    }
    
    public var body: some View {
        HStack(spacing: 4) {
            Image(systemName: trend.icon)
                .font(.caption)
                .foregroundColor(trend.color)
            
            Text(String(format: "%.1f%%", abs(percentageChange)))
                .font(.caption)
                .foregroundColor(trend.color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(trend.accessibilityLabel(with: percentageChange))
    }
}

// MARK: - Trend Type
extension TrendIndicator {
    enum Trend {
        case up, down, stable
        
        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .stable: return "arrow.right"
            }
        }
        
        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .stable: return .gray
            }
        }
        
        func accessibilityLabel(with percentage: Double) -> String {
            switch self {
            case .up:
                return "Increased by \(String(format: "%.1f", abs(percentage))) percent"
            case .down:
                return "Decreased by \(String(format: "%.1f", abs(percentage))) percent"
            case .stable:
                return "No change"
            }
        }
    }
}

// MARK: - SwiftUI Preview
#if DEBUG
struct TrendIndicator_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            TrendIndicator(current: 75, previous: 70)
                .previewDisplayName("Upward Trend")
            
            TrendIndicator(current: 65, previous: 70)
                .previewDisplayName("Downward Trend")
            
            TrendIndicator(current: 70, previous: 70)
                .previewDisplayName("Stable")
            
            TrendIndicator(current: 100, previous: 0)
                .previewDisplayName("Edge Case: Previous Zero")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
#endif
