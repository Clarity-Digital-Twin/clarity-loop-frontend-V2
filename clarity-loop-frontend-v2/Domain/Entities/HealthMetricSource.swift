//
//  HealthMetricSource.swift
//  clarity-loop-frontend-v2
//
//  Source of health metric data
//

import Foundation

/// Source of health metric data
enum HealthMetricSource: String, Codable, CaseIterable {
    case manual = "manual"
    case appleHealth = "apple_health"
    case wearable = "wearable"
    case integration = "integration"
    
    var displayName: String {
        switch self {
        case .manual:
            return "Manual Entry"
        case .appleHealth:
            return "Apple Health"
        case .wearable:
            return "Wearable Device"
        case .integration:
            return "Third-party Integration"
        }
    }
}