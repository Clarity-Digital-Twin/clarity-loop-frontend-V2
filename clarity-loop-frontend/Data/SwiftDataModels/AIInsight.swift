import Foundation
import SwiftData

@Model
final class AIInsight: @unchecked Sendable {
    // MARK: - Properties

    var insightID: UUID?
    var remoteID: String?

    // Content - All optional with defaults for CloudKit
    var content: String?
    var summary: String?
    var title: String?

    // Metadata - All optional with defaults for CloudKit
    var timestamp: Date?
    var category: InsightCategory?
    var priority: InsightPriority?
    var type: AIInsightType?

    // Context
    var contextData: [String: String]?
    var dateRange: InsightDateRange?

    // AI metadata
    var modelVersion: String?
    var confidenceScore: Double?
    var generationTime: Double? // Seconds

    // User interaction - All optional with defaults for CloudKit
    var isRead: Bool?
    var isFavorite: Bool?
    var userRating: Int? // 1-5 stars
    var userFeedback: String?

    // Chat context
    var conversationID: UUID?
    var messageRole: MessageRole?
    var parentMessageID: UUID?

    // Sync tracking - All optional with defaults for CloudKit
    var syncStatus: SyncStatus?
    var lastSyncedAt: Date?

    // CloudKit compliant relationships with inverses
    @Relationship(inverse: \UserProfileModel.aiInsights) 
    var userProfile: UserProfileModel?
    
    // New relationship to fix PATAnalysis inverse
    var patAnalysis: PATAnalysis?
    
    // Relationship to health metrics
    var relatedMetrics: [HealthMetric]?

    // MARK: - Initialization

    init(
        content: String? = nil,
        category: InsightCategory? = .general,
        type: AIInsightType? = .suggestion,
        messageRole: MessageRole? = .assistant
    ) {
        self.insightID = UUID()
        self.content = content
        self.timestamp = Date()
        self.category = category ?? .general
        self.priority = .medium
        self.type = type ?? .suggestion
        self.messageRole = messageRole ?? .assistant
        self.isRead = false
        self.isFavorite = false
        self.syncStatus = .pending
    }
}

// MARK: - Supporting Types

enum InsightCategory: String, Codable, CaseIterable {
    case general
    case sleep
    case activity
    case heartHealth = "heart_health"
    case nutrition
    case mentalHealth = "mental_health"
    case medication
    case vitals

    var displayName: String {
        switch self {
        case .general: "General"
        case .sleep: "Sleep"
        case .activity: "Activity"
        case .heartHealth: "Heart Health"
        case .nutrition: "Nutrition"
        case .mentalHealth: "Mental Health"
        case .medication: "Medication"
        case .vitals: "Vitals"
        }
    }

    var icon: String {
        switch self {
        case .general: "sparkles"
        case .sleep: "moon.fill"
        case .activity: "figure.walk"
        case .heartHealth: "heart.fill"
        case .nutrition: "fork.knife"
        case .mentalHealth: "brain.head.profile"
        case .medication: "pills.fill"
        case .vitals: "waveform.path.ecg"
        }
    }
}

enum InsightPriority: String, Codable {
    case high
    case medium
    case low

    var sortOrder: Int {
        switch self {
        case .high: 0
        case .medium: 1
        case .low: 2
        }
    }
}

enum AIInsightType: String, Codable {
    case alert
    case suggestion
    case observation
    case achievement
    case trend
    case chat

    var icon: String {
        switch self {
        case .alert: "exclamationmark.triangle.fill"
        case .suggestion: "lightbulb.fill"
        case .observation: "eye.fill"
        case .achievement: "star.fill"
        case .trend: "chart.line.uptrend.xyaxis"
        case .chat: "message.fill"
        }
    }
}

enum MessageRole: String, Codable {
    case user
    case assistant
    case system
}

struct InsightDateRange: Codable {
    let startDate: Date
    let endDate: Date

    var duration: TimeInterval {
        endDate.timeIntervalSince(startDate)
    }
}

// MARK: - Conversation Management

extension AIInsight {
    static func createUserMessage(content: String, category: InsightCategory = .general) -> AIInsight {
        let message = AIInsight(
            content: content,
            category: category,
            type: .chat,
            messageRole: .user
        )
        message.conversationID = UUID()
        return message
    }

    static func createAssistantMessage(
        content: String,
        category: InsightCategory,
        conversationID: UUID,
        parentMessageID: UUID? = nil
    ) -> AIInsight {
        let message = AIInsight(
            content: content,
            category: category,
            type: .chat,
            messageRole: .assistant
        )
        message.conversationID = conversationID
        message.parentMessageID = parentMessageID
        return message
    }
}

// MARK: - Search Support

extension AIInsight {
    var searchableText: String {
        [title, content, summary].compactMap { $0 }.joined(separator: " ")
    }
}
