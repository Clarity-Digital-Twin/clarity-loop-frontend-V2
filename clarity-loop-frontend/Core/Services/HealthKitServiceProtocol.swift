import Foundation
import HealthKit

/// A protocol that defines the contract for a service that interacts with HealthKit.
/// This abstraction allows for mocking the HealthKit interactions during testing.
protocol HealthKitServiceProtocol {
    /// Checks if HealthKit data is available on the current device.
    /// - Returns: A boolean indicating if `HKHealthStore.isHealthDataAvailable()` is true.
    func isHealthDataAvailable() -> Bool

    /// Requests authorization from the user to read health data.
    /// - Throws: An error if the authorization request fails.
    func requestAuthorization() async throws

    /// Fetches the total step count for a given day.
    /// - Parameter date: The date for which to fetch the step count.
    /// - Returns: The total step count as a `Double`.
    func fetchDailySteps(for date: Date) async throws -> Double

    /// Fetches the resting heart rate for a given day.
    /// - Parameter date: The date for which to fetch the resting heart rate.
    /// - Returns: The resting heart rate as a `Double`, or `nil` if no data is available.
    func fetchRestingHeartRate(for date: Date) async throws -> Double?

    /// Fetches and processes sleep analysis data for a given night.
    /// - Parameter date: The date representing the night to analyze (e.g., the morning of).
    /// - Returns: A `SleepData` object containing the analysis, or `nil` if no data is available.
    func fetchSleepAnalysis(for date: Date) async throws -> SleepData?

    /// Fetches all the required daily health metrics concurrently.
    /// - Parameter date: The date for which to fetch the metrics.
    /// - Returns: A `DailyHealthMetrics` object containing all the fetched data.
    func fetchAllDailyMetrics(for date: Date) async throws -> DailyHealthMetrics

    /// Uploads HealthKit data to the backend
    /// - Parameter uploadRequest: The HealthKit upload request containing samples to upload
    /// - Returns: A response indicating the upload status
    func uploadHealthKitData(_ uploadRequest: HealthKitUploadRequestDTO) async throws -> HealthKitUploadResponseDTO

    /// Enables background delivery for HealthKit data types
    /// - Throws: An error if background delivery setup fails
    func enableBackgroundDelivery() async throws

    /// Disables background delivery for HealthKit data types
    /// - Throws: An error if background delivery disable fails
    func disableBackgroundDelivery() async throws

    /// Sets up observer queries to monitor HealthKit data changes
    func setupObserverQueries()
    
    /// Fetch all health data for upload in the correct format
    /// - Parameters:
    ///   - startDate: The start date for data collection
    ///   - endDate: The end date for data collection
    ///   - userId: The user ID for the upload
    /// - Returns: A HealthKitUploadRequestDTO ready for upload
    func fetchHealthDataForUpload(from startDate: Date, to endDate: Date, userId: String) async throws -> HealthKitUploadRequestDTO
}
