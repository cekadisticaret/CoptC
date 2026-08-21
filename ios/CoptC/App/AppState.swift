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
    @Published var mirrorRows: [MirrorBook] = []
    @Published var mirrorPick: [String] = []
    @Published var mirrorHint: String?
    @Published var crypto: GpsSnapshot?
    @Published var cryptoError: String?
    static let mirrorMax = 3

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
            await refreshCrypto(silent: true)
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
            await refreshCrypto(silent: true)
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
        crypto = nil
        cryptoError = nil
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
        let url = tab == .coptc ? coptcBaseURL : tab.baseURL
        guard let password = panelPassword(for: tab) else {
            if tab == .coptc { isLoggedIn = false }
            else { cemapiError = "CEMAPI parolası yok" }
            return
        }
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
                cemapiError = "CEMAPI panele girilemedi. Panel parolası CoptC ile aynı değilse Ayarlar’dan CEMAPI parolasını yaz."
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
        await loadMirrorBooks()
    }

    func loadMirrorBooks() async {
        guard let password = panelPassword(for: selectedTab) else { return }
        let url = currentBaseURL
        do {
            try await APIClient.shared.login(baseURL: url, password: password)
            let res = try await APIClient.shared.mirrorBooks(baseURL: url)
            mirrorRows = res.books
            mirrorPick = res.selected
            if let err = res.error, res.books.isEmpty {
                mirrorHint = err
            } else {
                mirrorHint = nil
            }
        } catch {
            mirrorHint = error.localizedDescription
        }
    }

    func toggleMirrorBook(_ book: String) {
        var cur = mirrorPick
        if let i = cur.firstIndex(of: book) {
            if cur.count == 1 {
                mirrorHint = "En az bir algoritma seçili kalmalı."
                return
            }
            cur.remove(at: i)
        } else if cur.count >= Self.mirrorMax {
            mirrorHint = "En fazla \(Self.mirrorMax) algoritma seçebilirsin."
            return
        } else {
            cur.append(book)
        }
        mirrorPick = cur
        mirrorHint = nil
    }

    func saveMirrorBooks() async -> Bool {
        guard !mirrorPick.isEmpty else { return false }
        guard let password = panelPassword(for: selectedTab) else { return false }
        let url = currentBaseURL
        isLoading = true
        defer { isLoading = false }
        do {
            try await APIClient.shared.login(baseURL: url, password: password)
            let saved = try await APIClient.shared.selectBooks(baseURL: url, books: mirrorPick)
            mirrorPick = saved
            let names = saved.compactMap { id in mirrorRows.first(where: { $0.book == id })?.title ?? id }
            mirrorHint = "Kaydedildi — \(names.joined(separator: " + "))"
            errorMessage = nil
            await refresh(tab: selectedTab, silent: true)
            return true
        } catch {
            mirrorHint = error.localizedDescription
            errorMessage = error.localizedDescription
            return false
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
        if tab == .cemapi, cemapiHome == nil || cemapiError != nil {
            await refresh(tab: tab, silent: false)
        } else if tab == .coptc, coptcHome == nil {
            await refresh(tab: tab, silent: false)
        }
    }

    func saveCemapiPassword(_ password: String) async {
        let trimmed = password.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            KeychainHelper.delete(key: "cemapiPassword")
        } else {
            KeychainHelper.save(trimmed, key: "cemapiPassword")
        }
        cemapiHome = nil
        await refresh(tab: .cemapi, silent: false)
    }

    private func panelPassword(for tab: BookTab) -> String? {
        if tab == .cemapi, let extra = KeychainHelper.load(key: "cemapiPassword"), !extra.isEmpty {
            return extra
        }
        return KeychainHelper.load(key: "password")
    }

    private func startAutoRefresh() {
        stopAutoRefresh()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                if Task.isCancelled { break }
                await refresh(tab: .coptc, silent: true)
                await refresh(tab: .cemapi, silent: true)
                await refreshCrypto(silent: true)
            }
        }
    }

    func refreshCrypto(silent: Bool = false) async {
        if !silent { isLoading = true }
        defer { if !silent { isLoading = false } }
        do {
            crypto = try await APIClient.shared.gpsusdt()
            cryptoError = nil
        } catch {
            if !silent || crypto == nil {
                cryptoError = error.localizedDescription
            }
        }
    }

    private func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}
