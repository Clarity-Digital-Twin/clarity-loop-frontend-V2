#if !TESTING
    import Amplify
    import AWSAPIPlugin
    import AWSCognitoAuthPlugin
    import AWSS3StoragePlugin
#endif
import Foundation

enum AmplifyConfigurator {
    private static var isConfigured = false

    static func configure() {
        #if TESTING
            print("🧪 AMPLIFY: Skipping configuration in test environment (TESTING flag active)")
            return
        #else
            guard !isConfigured else { return }

            do {
                try Amplify.add(plugin: AWSCognitoAuthPlugin())
                try Amplify.add(plugin: AWSAPIPlugin())
                try Amplify.add(plugin: AWSS3StoragePlugin())
                try Amplify.configure()
                isConfigured = true
                print("✅ Amplify configured")
            } catch {
                print("❌ Amplify configuration error: \(error)")
                print("⚠️  This is expected in test/development environments without AWS config")
                print("🔄 App will continue without Amplify backend functionality")
                // NEVER crash the app - degraded functionality is better than no app
                isConfigured = false
            }
        #endif
    }
}
