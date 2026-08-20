import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var isLoggedIn = false
    @Published var selectedTab: BookTab = .coptc
    @Published var coptcBaseURL = KeychainHelper.load(key: "baseURL") ?? APIClient.defaultBaseURL
    @Published var coptcHome: HomeResponse?
    @Published var cemapiHome: HomeResponse?
    @Published var coptcSettings: SettingsResponse?
    @Published var cemapiSettings: SettingsResponse?
    @Published var coptcError: String?
    @Published var cemapiError: String?
    @Published var isLoading = false
    @Published var loadingTab: BookTab?
    @Published var lastRefresh: Date?

    var home: HomeResponse? {
        selectedTab == .coptc ? coptcHome : cemapiHome
    }

    var settings: SettingsResponse? {
        selectedTab == .coptc ? coptcSettings : cemapiSettings
    }

    var errorMessage: String? {
        get { selectedTab == .coptc ? coptcError : cemapiError }
        set {
            if selectedTab == .coptc { coptcError = newValue }
            else { cemapiError = newValue }
        }
    }

    var currentBaseURL: String {
        selectedTab == .coptc ? coptcBaseURL : BookTab.cemapi.baseURL
    }

    private var refreshTask: Task<Void, Never>?

    func bootstrap() async {
        guard KeychainHelper.load(key: "password") != nil else {
            isLoggedIn = false
            return
        }
        await refresh(tab: .coptc, silent: true)
        if coptcError == nil, coptcHome != nil {
            isLoggedIn = true
            startAutoRefresh()
            await refresh(tab: .cemapi, silent: true)
        }
    }

    func login(password: String, serverURL: String) async {
        isLoading = true
        coptcError = nil
        cemapiError = nil
        let url = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try await APIClient.shared.login(baseURL: url, password: password)
            KeychainHelper.save(password, key: "password")
            KeychainHelper.save(url, key: "baseURL")
            coptcBaseURL = url
            isLoggedIn = true
            await refresh(tab: .coptc, silent: false)
            startAutoRefresh()
            await refresh(tab: .cemapi, silent: true)
        } catch {
            coptcError = error.localizedDescription
            isLoggedIn = false
        }
        isLoading = false
    }

    func logout() async {
        stopAutoRefresh()
        await APIClient.shared.logout(baseURL: coptcBaseURL)
        await APIClient.shared.logout(baseURL: BookTab.cemapi.baseURL)
        KeychainHelper.delete(key: "password")
        coptcHome = nil
        cemapiHome = nil
        coptcSettings = nil
        cemapiSettings = nil
        isLoggedIn = false
        coptcError = nil
        cemapiError = nil
    }

    func refresh(silent: Bool = false) async {
        await refresh(tab: selectedTab, silent: silent)
    }

    func refresh(tab: BookTab, silent: Bool = false) async {
        if !silent {
            isLoading = true
            loadingTab = tab
        }
        defer {
            if !silent {
                isLoading = false
                loadingTab = nil
            }
        }
        guard let password = KeychainHelper.load(key: "password") else {
            isLoggedIn = false
            return
        }
        let url = tab == .coptc ? coptcBaseURL : tab.baseURL
        do {
            try await APIClient.shared.login(baseURL: url, password: password)
            let home = try await APIClient.shared.home(baseURL: url)
            if tab == .coptc {
                coptcHome = home
                coptcError = nil
            } else {
                cemapiHome = home
                cemapiError = nil
            }
            lastRefresh = Date()
        } catch APIClientError.unauthorized {
            if tab == .coptc {
                KeychainHelper.delete(key: "password")
                isLoggedIn = false
                coptcHome = nil
                coptcError = APIClientError.unauthorized.errorDescription
                stopAutoRefresh()
            } else {
                cemapiError = APIClientError.unauthorized.errorDescription
            }
        } catch {
            if tab == .coptc {
                if !silent { coptcError = error.localizedDescription }
            } else {
                cemapiError = error.localizedDescription
            }
        }
    }

    func toggleLive() async {
        guard let live = home?.live else { return }
        let tab = selectedTab
        let url = currentBaseURL
        isLoading = true
        loadingTab = tab
        defer {
            isLoading = false
            loadingTab = nil
        }
        do {
            _ = try await APIClient.shared.setLive(baseURL: url, on: !live.on)
            await refresh(tab: tab, silent: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadSettings() async {
        let tab = selectedTab
        let url = currentBaseURL
        do {
            let s = try await APIClient.shared.settings(baseURL: url)
            if tab == .coptc { coptcSettings = s }
            else { cemapiSettings = s }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveAmounts(low: Double, mid: Double, high: Double) async -> Bool {
        let tab = selectedTab
        let url = currentBaseURL
        isLoading = true
        defer { isLoading = false }
        do {
            let s = try await APIClient.shared.saveAmounts(baseURL: url, low: low, mid: mid, high: high)
            if tab == .coptc { coptcSettings = s }
            else { cemapiSettings = s }
            errorMessage = nil
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func selectTab(_ tab: BookTab) async {
        selectedTab = tab
        if (tab == .coptc && coptcHome == nil) || (tab == .cemapi && cemapiHome == nil) {
            await refresh(tab: tab, silent: false)
        }
    }

    private func startAutoRefresh() {
        stopAutoRefresh()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                if Task.isCancelled { break }
                await refresh(tab: .coptc, silent: true)
                await refresh(tab: .cemapi, silent: true)
            }
        }
    }

    private func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}
