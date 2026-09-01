import SwiftUI
import UIKit

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var tab = 0

    init() {
        Self.styleChrome()
    }

    var body: some View {
        TabView(selection: $tab) {
            DashboardView()
                .tabItem { Label("Ana sayfa", systemImage: "house.fill") }
                .tag(0)
            PositionsTabView()
                .tabItem { Label("Pozisyon", systemImage: "chart.pie.fill") }
                .tag(1)
            NavigationStack {
                ScrollView(showsIndicators: false) {
                    AlgoListView()
                        .padding(.horizontal, 16)
                        .padding(.top, 6)
                        .padding(.bottom, 28)
                }
                .background(Theme.bg.ignoresSafeArea())
                .toolbar(.hidden, for: .navigationBar)
                .refreshable { await appState.refreshAlgos() }
            }
            .tabItem { Label("Algo", systemImage: "square.grid.2x2.fill") }
            .tag(2)
            LiveView()
                .tabItem { Label("LIVE", systemImage: "bolt.fill") }
                .tag(3)
            SettingsView()
                .tabItem { Label("Profil", systemImage: "person.fill") }
                .tag(4)
        }
        .tint(Theme.lime)
    }

    private static func styleChrome() {
        let ink = UIColor.white
        let mut = UIColor(red: 0.55, green: 0.56, blue: 0.58, alpha: 1)
        let lime = UIColor(red: 0.812, green: 1.0, blue: 0.0, alpha: 1)
        let bg = UIColor(red: 0.04, green: 0.04, blue: 0.045, alpha: 1)
        let card = UIColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1)
        let black = UIColor.black

        let bar = UITabBarAppearance()
        bar.configureWithOpaqueBackground()
        bar.backgroundColor = bg
        bar.shadowColor = UIColor.white.withAlphaComponent(0.06)
        let item = UITabBarItemAppearance()
        item.selected.iconColor = lime
        item.selected.titleTextAttributes = [.foregroundColor: lime]
        item.normal.iconColor = mut
        item.normal.titleTextAttributes = [.foregroundColor: mut]
        bar.stackedLayoutAppearance = item
        bar.inlineLayoutAppearance = item
        bar.compactInlineLayoutAppearance = item
        UITabBar.appearance().standardAppearance = bar
        UITabBar.appearance().scrollEdgeAppearance = bar
        UITabBar.appearance().unselectedItemTintColor = mut

        UISegmentedControl.appearance().selectedSegmentTintColor = lime
        UISegmentedControl.appearance().backgroundColor = card
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: black, .font: UIFont.systemFont(ofSize: 13, weight: .semibold)],
            for: .selected
        )
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: ink],
            for: .normal
        )
    }
}
