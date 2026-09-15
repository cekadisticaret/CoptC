import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        MainTabView()
            .background(Theme.bg.ignoresSafeArea())
            .task { await appState.bootstrap() }
    }
}
