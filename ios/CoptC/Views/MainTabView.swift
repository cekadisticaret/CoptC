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
            CryptoView()
                .tabItem { Label("Kripto", systemImage: "bitcoinsign.circle.fill") }
                .tag(2)
            SettingsView()
                .tabItem { Label("Profil", systemImage: "person.fill") }
                .tag(3)
        }
        .tint(Theme.ink)
    }

    private static func styleChrome() {
        let ink = UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)
        let mut = UIColor(red: 0.55, green: 0.56, blue: 0.58, alpha: 1)
        let lime = UIColor(red: 0.816, green: 0.992, blue: 0.243, alpha: 1)
        let bg = UIColor(red: 0.965, green: 0.968, blue: 0.955, alpha: 1)

        let bar = UITabBarAppearance()
        bar.configureWithOpaqueBackground()
        bar.backgroundColor = .white
        bar.shadowColor = UIColor.black.withAlphaComponent(0.06)
        let item = UITabBarItemAppearance()
        item.selected.iconColor = ink
        item.selected.titleTextAttributes = [.foregroundColor: ink]
        item.normal.iconColor = mut
        item.normal.titleTextAttributes = [.foregroundColor: mut]
        bar.stackedLayoutAppearance = item
        bar.inlineLayoutAppearance = item
        bar.compactInlineLayoutAppearance = item
        UITabBar.appearance().standardAppearance = bar
        UITabBar.appearance().scrollEdgeAppearance = bar

        UISegmentedControl.appearance().selectedSegmentTintColor = lime
        UISegmentedControl.appearance().backgroundColor = bg
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: ink, .font: UIFont.systemFont(ofSize: 13, weight: .semibold)],
            for: .selected
        )
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: mut],
            for: .normal
        )
    }
}
