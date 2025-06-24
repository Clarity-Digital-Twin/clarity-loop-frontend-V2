import Foundation

/// Centralized application configuration
/// Provides a single source of truth for environment-specific settings
enum AppConfig {
    // MARK: - API Configuration

    /// Base URL for the CLARITY backend API
    /// Reads from Info.plist APIBaseURL key with fallback to production URL
    static var apiBaseURL: String {
        Bundle.main.object(forInfoDictionaryKey: "APIBaseURL") as? String
            ?? "https://clarity.novamindnyc.com"
    }

    // MARK: - Preview Configuration

    /// Base URL specifically for SwiftUI previews
    /// Uses the same API URL but can be overridden for preview-specific needs
    static var previewAPIBaseURL: String {
        // For previews, you can override this to use a different URL if needed
        // For now, use the same configuration as the main app
        apiBaseURL
    }

    // MARK: - Environment Detection

    /// Returns true if running in debug mode
    static var isDebugMode: Bool {
        #if DEBUG
            return true
        #else
            return false
        #endif
    }

    /// Returns true if running in a simulator
    static var isSimulator: Bool {
        #if targetEnvironment(simulator)
            return true
        #else
            return false
        #endif
    }
}

// MARK: - Future Enhancement Ideas

/// Example: Environment-based configuration with multiple Info.plist keys
/// You can extend this pattern by adding more keys to Info.plist:
/// - APIBaseURL_Dev, APIBaseURL_Staging, APIBaseURL_Prod
/// - Then use build configurations to switch between them
/*
 extension AppConfig {
     enum Environment {
         case development
         case staging
         case production

         var configKey: String {
             switch self {
             case .development: return "APIBaseURL_Dev"
             case .staging: return "APIBaseURL_Staging"
             case .production: return "APIBaseURL_Prod"
             }
         }
     }

     static var currentEnvironment: Environment {
         #if DEBUG
         return .development
         #else
         return .production
         #endif
     }

     static var environmentSpecificURL: String {
         let environment = currentEnvironment
         return Bundle.main.object(forInfoDictionaryKey: environment.configKey) as? String
         ?? apiBaseURL // fallback to main APIBaseURL
     }
 }
 */
