//
//  PersistedHealthMetric.swift
//  clarity-loop-frontend-v2
//
//  SwiftData model for persisting HealthMetric entities
//

import Foundation
import SwiftData

@Model
final class PersistedHealthMetric {
    @Attribute(.unique) var id: UUID
    var userId: UUID
    var type: String
    var value: Double
    var unit: String
    var recordedAt: Date
    var source: String?
    var notes: String?
    
    init(
        id: UUID,
        userId: UUID,
        type: String,
        value: Double,
        unit: String,
        recordedAt: Date,
        source: String? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.value = value
        self.unit = unit
        self.recordedAt = recordedAt
        self.source = source
        self.notes = notes
    }
}