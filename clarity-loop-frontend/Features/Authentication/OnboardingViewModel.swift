import Foundation
import Observation

@Observable
final class OnboardingViewModel {
    // MARK: - Dependencies

    private let authService: any AuthServiceProtocol
    private let healthKitService: any HealthKitServiceProtocol

    // MARK: - State Properties

    var currentStep = 0
    var isLoading = false
    var errorMessage: String?
    var isCompleted = false

    // Terms and Privacy
    var hasAcceptedTerms = false
    var hasAcceptedPrivacy = false

    // HealthKit
    var hasRequestedHealthKit = false
    var healthKitAuthorized = false

    // Notifications
    var hasRequestedNotifications = false
    var notificationsAuthorized = false

    // MARK: - Computed Properties

    var canProceedFromCurrentStep: Bool {
        switch currentStep {
        case 0: true // Welcome screen
        case 1: hasAcceptedTerms && hasAcceptedPrivacy // Terms
        case 2: hasRequestedHealthKit // HealthKit
        case 3: hasRequestedNotifications // Notifications
        case 4: true // Completion
        default: false
        }
    }

    var totalSteps: Int { 5 }

    var progressPercentage: Double {
        guard totalSteps > 1 else { return 0.0 }
        let percentage = Double(currentStep) / Double(totalSteps - 1)
        return percentage.isNaN || percentage.isInfinite ? 0.0 : percentage
    }

    // MARK: - Initializer

    init(authService: any AuthServiceProtocol, healthKitService: any HealthKitServiceProtocol) {
        self.authService = authService
        self.healthKitService = healthKitService
    }

    // MARK: - Navigation Methods

    func nextStep() {
        guard canProceedFromCurrentStep else { return }

        if currentStep < totalSteps - 1 {
            currentStep += 1
        } else {
            completeOnboarding()
        }
    }

    func previousStep() {
        if currentStep > 0 {
            currentStep -= 1
        }
    }

    func skipToStep(_ step: Int) {
        guard step >= 0, step < totalSteps else { return }
        currentStep = step
    }

    // MARK: - Terms and Privacy

    func acceptTerms() {
        hasAcceptedTerms = true
    }

    func acceptPrivacy() {
        hasAcceptedPrivacy = true
    }

    func toggleTermsAcceptance() {
        hasAcceptedTerms.toggle()
    }

    func togglePrivacyAcceptance() {
        hasAcceptedPrivacy.toggle()
    }

    // MARK: - HealthKit Setup

    func requestHealthKitPermissions() async {
        isLoading = true
        errorMessage = nil
        hasRequestedHealthKit = true

        do {
            try await healthKitService.requestAuthorization()
            healthKitAuthorized = true
            
            // 🔥 CRITICAL FIX: Setup background delivery immediately after authorization
            try await healthKitService.enableBackgroundDelivery()
            healthKitService.setupObserverQueries()
            print("✅ HealthKit background sync enabled during onboarding")
            
        } catch {
            errorMessage = "HealthKit authorization failed: \(error.localizedDescription)"
            healthKitAuthorized = false
        }

        isLoading = false
    }

    func skipHealthKit() {
        hasRequestedHealthKit = true
        healthKitAuthorized = false
    }

    // MARK: - Notifications Setup

    func requestNotificationPermissions() async {
        isLoading = true
        errorMessage = nil
        hasRequestedNotifications = true

        do {
            // In a real app, you'd request notification permissions here
            // For now, we'll simulate the request
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            notificationsAuthorized = true
        } catch {
            errorMessage = "Notification authorization failed: \(error.localizedDescription)"
            notificationsAuthorized = false
        }

        isLoading = false
    }

    func skipNotifications() {
        hasRequestedNotifications = true
        notificationsAuthorized = false
    }

    // MARK: - Completion

    func completeOnboarding() {
        // Save onboarding completion status
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        isCompleted = true
    }

    func restartOnboarding() {
        currentStep = 0
        isCompleted = false
        hasAcceptedTerms = false
        hasAcceptedPrivacy = false
        hasRequestedHealthKit = false
        healthKitAuthorized = false
        hasRequestedNotifications = false
        notificationsAuthorized = false
        errorMessage = nil

        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    }

    // MARK: - Utility Methods

    func clearError() {
        errorMessage = nil
    }

    // MARK: - Static Methods

    static func hasCompletedOnboarding() -> Bool {
        UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
    }

    static func resetOnboardingStatus() {
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
    }
}
