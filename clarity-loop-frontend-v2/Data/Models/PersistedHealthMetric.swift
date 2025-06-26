//
//  PersistedHealthMetric.swift
//  clarity-loop-frontend-v2
//
//  SwiftData model for persisting HealthMetric entities
//

import Foundation
import SwiftData

@Model
public final class PersistedHealthMetric {
    @Attribute(.unique) public var id: UUID
    public var userId: UUID
    public var type: String
    public var value: Double
    public var unit: String
    public var recordedAt: Date
    public var source: String?
    public var notes: String?
    
    public init(
        id: UUID,
        userId: UUID,
        type: String,
        value: Double,
        unit: String,
        recordedAt: Date
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.value = value
        self.unit = unit
        self.recordedAt = recordedAt
        self.source = nil
        self.notes = nil
    }
}