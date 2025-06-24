import Foundation
import SwiftData

@Model
final class PATAnalysis: @unchecked Sendable {
    // MARK: - Properties

    // CloudKit compliant - no @Attribute(.unique) allowed
    var analysisID: UUID?
    var remoteID: String?

    // Analysis metadata - all optional with defaults
    var startDate: Date?
    var endDate: Date?
    var analysisDate: Date?
    var analysisType: PATAnalysisType?

    // Sleep stages data - all optional with defaults
    var sleepStages: [PATSleepStage]?
    var totalSleepMinutes: Int?
    var sleepEfficiency: Double?
    var sleepLatency: Int? // Minutes to fall asleep
    var wakeAfterSleepOnset: Int? // WASO in minutes

    // Sleep quality metrics - all optional with defaults
    var remSleepMinutes: Int?
    var deepSleepMinutes: Int?
    var lightSleepMinutes: Int?
    var awakeMinutes: Int?
    
    // Sleep stage percentages
    var deepSleepPercentage: Double?
    var remSleepPercentage: Double?
    var lightSleepPercentage: Double?

    // Analysis scores - all optional with defaults
    var overallScore: Double?
    var confidenceScore: Double?
    var qualityMetrics: SleepQualityMetrics?

    // Actigraphy data - optional
    var actigraphyData: [ActigraphyDataPoint]?
    var movementIntensity: [Double]?

    // Sync tracking - optional
    var syncStatus: SyncStatus?
    var lastSyncedAt: Date?

    // CloudKit compliant relationships with inverses
    @Relationship(inverse: \UserProfileModel.patAnalyses) 
    var userProfile: UserProfileModel?
    
    @Relationship(deleteRule: .cascade, inverse: \AIInsight.patAnalysis) 
    var relatedInsights: [AIInsight]?

    // MARK: - Initialization

    init(
        analysisID: UUID = UUID(),
        startDate: Date = Date(),
        endDate: Date = Date(),
        analysisType: PATAnalysisType = .overnight
    ) {
        self.analysisID = analysisID
        self.startDate = startDate
        self.endDate = endDate
        self.analysisDate = Date()
        self.analysisType = analysisType
        self.sleepStages = []
        self.totalSleepMinutes = 0
        self.sleepEfficiency = 0
        self.sleepLatency = 0
        self.wakeAfterSleepOnset = 0
        self.remSleepMinutes = 0
        self.deepSleepMinutes = 0
        self.lightSleepMinutes = 0
        self.awakeMinutes = 0
        self.deepSleepPercentage = 0
        self.remSleepPercentage = 0
        self.lightSleepPercentage = 0
        self.overallScore = 0
        self.confidenceScore = 0
        self.qualityMetrics = SleepQualityMetrics()
        self.syncStatus = .pending
    }
}

// MARK: - Supporting Types

enum PATAnalysisType: String, Codable {
    case overnight
    case nap
    case extended // Multi-day analysis
}

struct PATSleepStage: Codable {
    let timestamp: Date
    let stage: SleepStageType
    let duration: Int // Minutes
    let confidence: Double

    enum SleepStageType: String, Codable {
        case awake
        case light
        case deep
        case rem

        var color: String {
            switch self {
            case .awake: "#FF6B6B"
            case .light: "#4ECDC4"
            case .deep: "#45B7D1"
            case .rem: "#96CEB4"
            }
        }
    }
}

struct ActigraphyDataPoint: Codable {
    let timestamp: Date
    let movementCount: Int
    let intensity: Double
    let ambientLight: Double?
    let soundLevel: Double?
}

struct SleepQualityMetrics: Codable {
    var continuityScore: Double = 0 // How uninterrupted the sleep was
    var depthScore: Double = 0 // Quality of deep sleep
    var regularityScore: Double = 0 // Consistency of sleep patterns
    var restorationScore: Double = 0 // How restorative the sleep was

    var averageScore: Double {
        (continuityScore + depthScore + regularityScore + restorationScore) / 4
    }
}

// MARK: - Hypnogram Generation

extension PATAnalysis {
    var hypnogramData: [(Date, PATSleepStage.SleepStageType)] {
        sleepStages?.map { ($0.timestamp, $0.stage) } ?? []
    }

    var sleepSummary: String {
        let totalMinutes = totalSleepMinutes ?? 0
        let efficiency = sleepEfficiency ?? 0
        let rem = remSleepMinutes ?? 0
        let deep = deepSleepMinutes ?? 0
        let light = lightSleepMinutes ?? 0
        
        return """
        Total Sleep: \(totalMinutes / 60)h \(totalMinutes % 60)m
        Efficiency: \(Int(efficiency * 100))%
        REM: \(rem)m | Deep: \(deep)m | Light: \(light)m
        """
    }
}
