//
//  DashboardViewModel.swift
//  clarity-loop-frontend-v2
//
//  ViewModel for dashboard screen showing health metrics
//

import Foundation
import ClarityDomain
import ClarityData
import ClarityCore

@MainActor
@Observable
public final class DashboardViewModel {
    
    // MARK: - Published Properties
    
    public let user: User
    public private(set) var metricsState: ViewState<[HealthMetric]> = .idle
    public private(set) var recentMetrics: [HealthMetric] = []
    public var selectedMetricType: HealthMetricType?
    
    // MARK: - Computed Properties
    
    public var filteredMetrics: [HealthMetric] {
        guard let selectedType = selectedMetricType else {
            return recentMetrics
        }
        return recentMetrics.filter { $0.type == selectedType }
    }
    
    public var isRefreshing: Bool {
        metricsState.isLoading
    }
    
    // MARK: - Dependencies
    
    private let healthMetricRepository: HealthMetricRepositoryProtocol
    
    // MARK: - Initialization
    
    public init(
        user: User,
        healthMetricRepository: HealthMetricRepositoryProtocol
    ) {
        self.user = user
        self.healthMetricRepository = healthMetricRepository
    }
    
    // MARK: - Public Methods
    
    public func loadRecentMetrics() async {
        metricsState = .loading
        
        do {
            let metrics = try await healthMetricRepository.findByUserId(user.id)
            
            // Sort by most recent first
            let sortedMetrics = metrics.sorted { $0.recordedAt > $1.recordedAt }
            
            recentMetrics = sortedMetrics
            metricsState = sortedMetrics.isEmpty ? .empty : .success(sortedMetrics)
            
        } catch {
            metricsState = .error(error)
            recentMetrics = []
        }
    }
    
    public func refresh() async {
        await loadRecentMetrics()
    }
    
    public func summaryForType(_ type: HealthMetricType) -> MetricSummary? {
        let typeMetrics = recentMetrics.filter { $0.type == type }
        
        guard !typeMetrics.isEmpty else { return nil }
        
        let values = typeMetrics.map { $0.value }
        let sum = values.reduce(0, +)
        let average = sum / Double(values.count)
        let latest = typeMetrics.first?.value ?? 0
        
        return MetricSummary(
            type: type,
            average: average,
            latest: latest,
            count: typeMetrics.count
        )
    }
    
    public func previousValueFor(_ metric: HealthMetric) -> Double? {
        // Find metrics of the same type that are older than the current metric
        let sameTypeMetrics = recentMetrics
            .filter { $0.type == metric.type && $0.recordedAt < metric.recordedAt }
            .sorted { $0.recordedAt > $1.recordedAt }
        
        // Return the most recent one before this metric
        return sameTypeMetrics.first?.value
    }
}

// MARK: - Metric Summary

public struct MetricSummary: Equatable, Sendable {
    public let type: HealthMetricType
    public let average: Double
    public let latest: Double
    public let count: Int
}