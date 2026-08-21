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
        .tint(Theme.green)
    }

    private static func styleChrome() {
        let green = UIColor(red: 0.75, green: 0.95, blue: 0.39, alpha: 1)
        let mut = UIColor(red: 0.62, green: 0.62, blue: 0.66, alpha: 1)
        let cream = UIColor(red: 0.43, green: 0.16, blue: 0.85, alpha: 1)
        let dark = UIColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1)

        let bar = UITabBarAppearance()
        bar.configureWithOpaqueBackground()
        bar.backgroundColor = dark
        bar.shadowColor = UIColor.black.withAlphaComponent(0.4)
        let item = UITabBarItemAppearance()
        item.selected.iconColor = green
        item.selected.titleTextAttributes = [.foregroundColor: green]
        item.normal.iconColor = mut
        item.normal.titleTextAttributes = [.foregroundColor: mut]
        bar.stackedLayoutAppearance = item
        bar.inlineLayoutAppearance = item
        bar.compactInlineLayoutAppearance = item
        UITabBar.appearance().standardAppearance = bar
        UITabBar.appearance().scrollEdgeAppearance = bar

        UISegmentedControl.appearance().selectedSegmentTintColor = cream
        UISegmentedControl.appearance().backgroundColor = dark
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: green, .font: UIFont.systemFont(ofSize: 13, weight: .semibold)],
            for: .selected
        )
        UISegmentedControl.appearance().setTitleTextAttributes(
            [.foregroundColor: mut],
            for: .normal
        )
    }
}
