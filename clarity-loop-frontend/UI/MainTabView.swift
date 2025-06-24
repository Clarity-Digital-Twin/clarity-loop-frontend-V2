import SwiftUI

struct MainTabView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                LazyTabContent(tab: 0, selectedTab: selectedTab) {
                    DashboardView()
                }
            }
            .tabItem {
                Image(systemName: "heart.fill")
                Text("Dashboard")
            }
            .tag(0)

            NavigationStack {
                LazyTabContent(tab: 1, selectedTab: selectedTab) {
                    ChatView()
                }
            }
            .tabItem {
                Image(systemName: "message.fill")
                Text("AI Chat")
            }
            .tag(1)

            NavigationStack {
                LazyTabContent(tab: 2, selectedTab: selectedTab) {
                    SettingsView()
                }
            }
            .tabItem {
                Image(systemName: "gearshape.fill")
                Text("Settings")
            }
            .tag(2)
        }
        .accentColor(.red)
    }
}

struct LazyTabContent<Content: View>: View {
    let tab: Int
    let selectedTab: Int
    let content: () -> Content

    var body: some View {
        if tab == selectedTab {
            content()
        } else {
            Color.clear
        }
    }
}

#Preview {
    guard
        let previewAPIClient = APIClient(
            baseURLString: AppConfig.previewAPIBaseURL,
            tokenProvider: { nil }
        ) else {
        return MainTabView()
    }

    return MainTabView()
        .environment(\.authService, AuthService(apiClient: previewAPIClient))
        .environment(\.healthKitService, HealthKitService(apiClient: previewAPIClient))
}
