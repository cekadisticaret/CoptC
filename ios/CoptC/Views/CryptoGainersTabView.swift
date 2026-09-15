import SwiftUI

struct CryptoGainersTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var query = ""

    private let purple = Color(red: 0.55, green: 0.45, blue: 0.95)
    private let profit = Color(red: 0.20, green: 0.90, blue: 0.55)

    private var feed: CryptoGainerFeed? { appState.cryptoGainerFeed }
    private var rows: [GainerRow] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let base = feed?.rows ?? []
        guard !q.isEmpty else { return base }
        return base.filter {
            $0.base.uppercased().contains(q) || $0.symbol.uppercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    sidePicker
                    searchBar
                    if let err = appState.cryptoGainerError {
                        Text(err).font(.footnote).foregroundStyle(Theme.red)
                    }
                    scalpAlerts
                    if rows.isEmpty {
                        SoftCard {
                            Text(appState.isLoading ? "Liste yükleniyor…" : "Kayıt yok")
                                .foregroundStyle(Theme.mut)
                        }
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                                CryptoGainerCard(row: row, rank: idx + 1, down: appState.cryptoGainerSide == .down)
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(Theme.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await appState.refreshCryptoGainers() }
            .task {
                await appState.refreshCryptoGainers(silent: true)
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 30_000_000_000)
                    if Task.isCancelled { break }
                    await appState.refreshCryptoGainers(silent: true)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(appState.cryptoGainerSide.title)
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if appState.isLoading { ProgressView().tint(Theme.lime) }
            }
            Text(subtitleLine)
                .font(.system(size: 11))
                .foregroundStyle(Theme.mut)
        }
    }

    private var subtitleLine: String {
        var bits: [String] = [feed?.note ?? "Binance USDT-M perpetual · son 24 saat"]
        if let u = feed?.updated, !u.isEmpty { bits.append(u) }
        return bits.joined(separator: " · ")
    }

    private var sidePicker: some View {
        Picker("Mod", selection: $appState.cryptoGainerSide) {
            ForEach(CryptoGainerSide.allCases) { side in
                Text(side.title).tag(side)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: appState.cryptoGainerSide) { _ in
            Task { await appState.refreshCryptoGainers() }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.mut)
            TextField("Coin ara…", text: $query)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var scalpAlerts: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Scalp uyarıları (1 dk)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.mut)
            let alerts = feed?.alerts ?? []
            if alerts.isEmpty {
                Text("Yeni AL/SAT sinyali yok · \(feed?.scalpUpdated ?? "—")")
                    .font(.footnote)
                    .foregroundStyle(Theme.mut)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            } else {
                ForEach(alerts.prefix(6)) { alert in
                    CryptoScalpAlertRow(alert: alert)
                }
            }
        }
    }
}

struct CryptoGainerCard: View {
    let row: GainerRow
    let rank: Int
    let down: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("#\(rank)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.mut)
                Spacer()
                Text(chgText)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundStyle(down ? Theme.red : Color(red: 0.20, green: 0.90, blue: 0.55))
            }
            Text(row.base)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text(row.symbol)
                .font(.system(size: 11))
                .foregroundStyle(Theme.mut)
            HStack {
                mini("Fiyat", priceText)
                mini("Hacim", volumeText)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var chgText: String {
        guard let chg = row.chg else { return "—" }
        if down { return String(format: "%.2f%%", chg) }
        return String(format: "+%.2f%%", chg)
    }

    private var priceText: String {
        guard let price = row.price else { return "—" }
        if price >= 1000 { return String(format: "%.1f", price) }
        if price >= 1 { return String(format: "%.4f", price) }
        return String(format: "%.6f", price)
    }

    private var volumeText: String {
        guard let qv = row.qv else { return "—" }
        if qv >= 1_000_000_000 { return String(format: "%.2fB", qv / 1_000_000_000) }
        if qv >= 1_000_000 { return String(format: "%.1fM", qv / 1_000_000) }
        if qv >= 1_000 { return String(format: "%.0fK", qv / 1_000) }
        return String(format: "%.0f", qv)
    }

    private func mini(_ k: String, _ v: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.mut)
            Text(v)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CryptoScalpAlertRow: View {
    let alert: CryptoScalpAlert

    private var tag: String {
        alert.isLong ? "AL" : "SAT"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text("\(alert.base) · Kalite \(alert.quality ?? 0)/100")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("TP \(px(alert.tp)) · SL \(px(alert.sl))")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.mut)
                if let g = alert.guidance, !g.isEmpty {
                    Text(g)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.mut)
                        .lineLimit(2)
                }
            }
            Spacer()
            Text(tag)
                .font(.system(size: 10, weight: .heavy))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .foregroundStyle(alert.isLong ? Color(red: 0.20, green: 0.90, blue: 0.55) : Theme.red)
                .background((alert.isLong ? Color(red: 0.20, green: 0.90, blue: 0.55) : Theme.red).opacity(0.14))
                .clipShape(Capsule())
        }
        .padding(12)
        .background(Theme.card)
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(alert.isLong ? Color(red: 0.20, green: 0.90, blue: 0.55) : Theme.red)
                .frame(width: 3)
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func px(_ v: Double?) -> String {
        guard let v else { return "—" }
        if v >= 1 { return String(format: "%.4f", v) }
        return String(format: "%.6f", v)
    }
}
