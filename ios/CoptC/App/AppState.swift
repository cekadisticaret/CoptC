import Foundation

@MainActor
final class AppState: ObservableObject {
    @Published var selectedTab: BookTab = .cemapi
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
    @Published var algoFeed: AlgoFeed?
    @Published var algoError: String?
    @Published var algoDetails: [String: AlgoCard] = [:]
    @Published var algoMode: AlgoPageMode = .gainersUp
    @Published var gainerFeed: GainerFeed?
    @Published var gainerError: String?
    @Published var cemapiLive: CemapiLive?
    @Published var kasaFeed: KasaFeed?
    @Published var kasaDetails: [String: CemapiLive] = [:]
    @Published var liveError: String?
    @Published var cemAnalizFeed: CemAnalizFeed?
    @Published var cemAnalizError: String?
    @Published var polyAlgoFeed: PolyAlgoFeed?
    @Published var polyAlgoError: String?
    @Published var bistFeed: BistFeed?
    @Published var bistError: String?
    @Published var bistSide: BistSide = .up
    @Published var cryptoGainerFeed: CryptoGainerFeed?
    @Published var cryptoGainerError: String?
    @Published var cryptoGainerSide: CryptoGainerSide = .up
    @Published var couponFeed: CouponFeed?
    @Published var couponLeagues: [LeagueChip] = []
    @Published var couponError: String?
    @Published var couponBook = "all"
    @Published var couponLeague = "all"
    @Published var couponTab: CouponTab = .open
    @Published var isLoadingCoupons = false
    static let mirrorMax = 3

    var algos: [AlgoCard] {
        let rows = algoFeed?.algos ?? []
        return rows.sorted {
            if $0.active != $1.active { return $0.active && !$1.active }
            return ($0.equity ?? 0) > ($1.equity ?? 0)
        }
    }

    var gainers: [GainerRow] { gainerFeed?.rows ?? [] }

    var home: HomeResponse? { cemapiHome }

    var settings: SettingsResponse? { coptcSettings }

    var errorMessage: String? {
        get { cemapiError }
        set { cemapiError = newValue }
    }

    var currentBaseURL: String { BookTab.cemapi.baseURL }

    private var refreshTask: Task<Void, Never>?

    func bootstrap() async {
        selectedTab = .cemapi
        startAutoRefresh()
        await refreshCemananaliz(silent: true)
        await refreshBist(silent: true)
        await refreshCryptoGainers(silent: true)
        await refreshPolyAlgos(silent: true)
        await refreshAlgoPage(silent: true)
        await refreshLive(silent: true)
        await refreshCoupons(silent: true)
        await refresh(tab: .cemapi, silent: true)
        await loadCouponLeagues()
    }

    func logout() async {
        stopAutoRefresh()
        await APIClient.shared.logout(baseURL: coptcBaseURL)
        await APIClient.shared.logout(baseURL: BookTab.cemapi.baseURL)
        KeychainHelper.delete(key: "password")
        KeychainHelper.delete(key: "cemapiPassword")
        coptcHome = nil
        cemapiHome = nil
        coptcSettings = nil
        cemapiSettings = nil
        algoFeed = nil
        algoError = nil
        algoDetails = [:]
        gainerFeed = nil
        gainerError = nil
        cemapiLive = nil
        kasaFeed = nil
        kasaDetails = [:]
        liveError = nil
        cemAnalizFeed = nil
        cemAnalizError = nil
        polyAlgoFeed = nil
        polyAlgoError = nil
        bistFeed = nil
        bistError = nil
        cryptoGainerFeed = nil
        cryptoGainerError = nil
        couponFeed = nil
        couponLeagues = []
        couponError = nil
        coptcError = nil
        cemapiError = nil
        await bootstrap()
    }

    func refresh(silent: Bool = false) async {
        await refresh(tab: .cemapi, silent: silent)
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
        do {
            let home = try await APIClient.shared.home(baseURL: url)
            if tab == .coptc {
                coptcHome = home
                coptcError = nil
            } else {
                cemapiHome = home
                cemapiError = nil
            }
            lastRefresh = Date()
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
        isLoading = true
        loadingTab = .cemapi
        defer {
            isLoading = false
            loadingTab = nil
        }
        do {
            _ = try await APIClient.shared.setLive(baseURL: BookTab.cemapi.baseURL, on: !live.on)
            await refresh(tab: .cemapi, silent: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadSettings() async {
        do {
            let s = try await APIClient.shared.settings(baseURL: coptcBaseURL)
            coptcSettings = s
        } catch {
            coptcError = error.localizedDescription
        }
        await loadMirrorBooks()
    }

    func loadMirrorBooks() async {
        let url = coptcBaseURL
        do {
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
        let url = coptcBaseURL
        isLoading = true
        defer { isLoading = false }
        do {
            let saved = try await APIClient.shared.selectBooks(baseURL: url, books: mirrorPick)
            mirrorPick = saved
            let names = saved.compactMap { id in mirrorRows.first(where: { $0.book == id })?.title ?? id }
            mirrorHint = "Kaydedildi — \(names.joined(separator: " + "))"
            coptcError = nil
            return true
        } catch {
            mirrorHint = error.localizedDescription
            errorMessage = error.localizedDescription
            return false
        }
    }

    func saveAmounts(low: Double, mid: Double, high: Double, minProfitPct: Double? = nil) async -> Bool {
        isLoading = true
        defer { isLoading = false }
        do {
            let s = try await APIClient.shared.saveAmounts(
                baseURL: coptcBaseURL, low: low, mid: mid, high: high, minProfitPct: minProfitPct
            )
            coptcSettings = s
            coptcError = nil
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

    private func startAutoRefresh() {
        stopAutoRefresh()
        refreshTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 20_000_000_000)
                if Task.isCancelled { break }
                await refreshCemananaliz(silent: true)
                await refreshBist(silent: true)
                await refreshCryptoGainers(silent: true)
                await refreshPolyAlgos(silent: true)
                await refreshAlgoPage(silent: true)
                await refreshLive(silent: true)
                await refreshCoupons(silent: true)
                await refresh(tab: .cemapi, silent: true)
            }
        }
    }

    func refreshAlgos(silent: Bool = false) async {
        if !silent { isLoading = true }
        defer { if !silent { isLoading = false } }
        do {
            let feed = try await APIClient.shared.algos(baseURL: coptcBaseURL)
            algoFeed = feed
            if feed.ok == false, let err = feed.error, !err.isEmpty {
                algoError = err
            } else {
                algoError = nil
            }
        } catch {
            if !silent || algoFeed == nil {
                algoError = error.localizedDescription
            }
        }
    }

    func refreshGainers(silent: Bool = false) async {
        if !silent { isLoading = true }
        defer { if !silent { isLoading = false } }
        let side = algoMode.gainerSide
        do {
            let feed = try await APIClient.shared.gainers(baseURL: coptcBaseURL, side: side)
            gainerFeed = feed
            if feed.ok == false, let err = feed.error, !err.isEmpty {
                gainerError = err
            } else {
                gainerError = nil
            }
        } catch {
            if !silent || gainerFeed == nil {
                gainerError = error.localizedDescription
            }
        }
    }

    func refreshAlgoPage(silent: Bool = false) async {
        switch algoMode {
        case .algorithms:
            await refreshAlgos(silent: silent)
        case .gainersUp, .gainersDown:
            await refreshGainers(silent: silent)
        }
    }

    func refreshAlgoDetail(_ id: String) async {
        do {
            let card = try await APIClient.shared.algoDetail(baseURL: coptcBaseURL, id: id)
            if card.ok == false { return }
            algoDetails[card.id] = card
            if card.id != id { algoDetails[id] = card }
        } catch {
            if algoDetails[id] == nil {
                algoError = error.localizedDescription
            }
        }
    }

    func refreshLive(silent: Bool = false) async {
        if !silent { isLoading = true }
        defer { if !silent { isLoading = false } }
        do {
            let feed = try await APIClient.shared.kasalar(baseURL: coptcBaseURL)
            kasaFeed = feed
            if feed.ok == false, let err = feed.error, !err.isEmpty {
                liveError = err
            } else {
                liveError = nil
            }
        } catch {
            if !silent || kasaFeed == nil {
                liveError = error.localizedDescription
            }
        }
    }

    func refreshCemananaliz(silent: Bool = false) async {
        if !silent { isLoading = true }
        defer { if !silent { isLoading = false } }
        do {
            let feed = try await APIClient.shared.cemananaliz(baseURL: coptcBaseURL)
            cemAnalizFeed = feed
            if feed.ok == false, let err = feed.error, !err.isEmpty {
                cemAnalizError = err
            } else {
                cemAnalizError = nil
            }
        } catch {
            if !silent || cemAnalizFeed == nil {
                cemAnalizError = error.localizedDescription
            }
        }
    }

    func refreshPolyAlgos(silent: Bool = false) async {
        if !silent { isLoading = true }
        defer { if !silent { isLoading = false } }
        do {
            let feed = try await APIClient.shared.polyAlgos(baseURL: coptcBaseURL)
            polyAlgoFeed = feed
            if feed.ok == false, let err = feed.error, !err.isEmpty {
                polyAlgoError = err
            } else {
                polyAlgoError = nil
            }
        } catch {
            if !silent || polyAlgoFeed == nil {
                polyAlgoError = error.localizedDescription
            }
        }
    }

    func refreshBist(silent: Bool = false) async {
        if !silent { isLoading = true }
        defer { if !silent { isLoading = false } }
        do {
            let feed = try await APIClient.shared.bist(baseURL: coptcBaseURL, side: bistSide.apiSide)
            bistFeed = feed
            if feed.ok == false, let err = feed.error, !err.isEmpty {
                bistError = err
            } else {
                bistError = nil
            }
        } catch {
            if !silent || bistFeed == nil {
                bistError = error.localizedDescription
            }
        }
    }

    func refreshCryptoGainers(silent: Bool = false) async {
        if !silent { isLoading = true }
        defer { if !silent { isLoading = false } }
        do {
            let feed = try await APIClient.shared.cryptoGainers(
                baseURL: coptcBaseURL,
                side: cryptoGainerSide.apiSide
            )
            cryptoGainerFeed = feed
            if feed.ok == false, let err = feed.error, !err.isEmpty {
                cryptoGainerError = err
            } else {
                cryptoGainerError = nil
            }
        } catch {
            if !silent || cryptoGainerFeed == nil {
                cryptoGainerError = error.localizedDescription
            }
        }
    }

    func refreshKasaDetail(_ id: String) async {
        do {
            let feed = try await APIClient.shared.kasaDetail(baseURL: coptcBaseURL, id: id)
            if feed.ok == false { return }
            kasaDetails[feed.id ?? id] = feed
            if feed.id != id { kasaDetails[id] = feed }
        } catch {
            if kasaDetails[id] == nil {
                liveError = error.localizedDescription
            }
        }
    }

    func loadCouponLeagues() async {
        do {
            let res = try await APIClient.shared.bahisLeagues(baseURL: coptcBaseURL)
            couponLeagues = res.leagues ?? []
        } catch {
            if couponLeagues.isEmpty {
                couponError = error.localizedDescription
            }
        }
    }

    func refreshCoupons(silent: Bool = false) async {
        if !silent { isLoadingCoupons = true }
        defer { if !silent { isLoadingCoupons = false } }
        let url = coptcBaseURL
        do {
            let feed = try await APIClient.shared.coupons(
                baseURL: url,
                league: couponLeague,
                tab: couponTab.rawValue,
                book: couponBook,
                limit: 80
            )
            couponFeed = feed
            if feed.ok == false {
                couponError = "Kupon verisi alınamadı"
            } else {
                couponError = nil
            }
        } catch {
            if !silent || couponFeed == nil {
                couponError = error.localizedDescription
            }
        }
    }

    private func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }
}
