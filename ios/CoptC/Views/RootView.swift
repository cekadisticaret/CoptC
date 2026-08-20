import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        Group {
            if appState.isLoggedIn {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .background(Theme.bg.ignoresSafeArea())
        .task { await appState.bootstrap() }
    }
}
