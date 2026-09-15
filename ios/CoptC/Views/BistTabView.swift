import SwiftUI

struct BistTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var query = ""

    private let orange = Color(red: 1.0, green: 0.55, blue: 0.16)
    private let profit = Color(red: 0.20, green: 0.90, blue: 0.55)

    private var feed: BistFeed? { appState.bistFeed }
    private var rows: [BistRow] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let base = feed?.rows ?? []
        guard !q.isEmpty else { return base }
        return base.filter {
            $0.symbol.uppercased().contains(q) || $0.name.uppercased().contains(q)
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    sidePicker
                    searchBar
                    if let err = appState.bistError {
                        Text(err).font(.footnote).foregroundStyle(Theme.red)
                    }
                    if rows.isEmpty {
                        SoftCard {
                            Text(emptyText)
                                .font(.subheadline)
                                .foregroundStyle(Theme.mut)
                        }
                    } else {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(Array(rows.enumerated()), id: \.element.id) { idx, row in
                                BistCard(row: row, rank: idx + 1)
                            }
                        }
                    }
                    if appState.bistSide == .up {
                        historySection("Geçmiş · 3 saat", feed?.history?.h3?.rows ?? [])
                        historySection("Geçmiş · 5 saat", feed?.history?.h5?.rows ?? [])
                        historySection("Geçmiş · 10 saat", feed?.history?.h10?.rows ?? [])
                    }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(Theme.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await appState.refreshBist() }
            .task {
                await appState.refreshBist(silent: true)
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 120_000_000_000)
                    if Task.isCancelled { break }
                    await appState.refreshBist(silent: true)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("BIST · \(appState.bistSide.title)")
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
        var bits: [String] = [feed?.subtitle ?? "BIST 100 · 1 saat · EMA5/13 + RSI5"]
        if feed?.session == true { bits.append("seans açık") }
        else if feed?.session == false { bits.append("seans kapalı") }
        if let u = feed?.updated, !u.isEmpty { bits.append(u) }
        return bits.joined(separator: " · ")
    }

    private var sidePicker: some View {
        Picker("Mod", selection: $appState.bistSide) {
            ForEach(BistSide.allCases) { side in
                Text(side.title).tag(side)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: appState.bistSide) { _ in
            Task { await appState.refreshBist() }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.mut)
            TextField("Hisse ara…", text: $query)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .foregroundStyle(Theme.ink)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var emptyText: String {
        if feed?.session == false {
            return "Seans kapalı — BIST 09:50'de açılır. Geçmiş sinyaller altta."
        }
        return appState.bistSide == .wait
            ? "Yakın aday yok"
            : "Bu saatte yükselme sinyali yok — Yakın sekmesine bak"
    }

    private func historySection(_ title: String, rows: [BistHistRow]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.mut)
            if rows.isEmpty {
                Text("Henüz kayıtlı AL sinyali yok")
                    .font(.footnote)
                    .foregroundStyle(Theme.mut)
            } else {
                ForEach(Array(rows.prefix(12))) { row in
                    BistHistCard(row: row, hoursLabel: title.contains("3") ? "3s" : title.contains("5") ? "5s" : "10s")
                }
            }
        }
        .padding(.top, 6)
    }
}

struct BistCard: View {
    let row: BistRow
    let rank: Int

    private let profit = Color(red: 0.20, green: 0.90, blue: 0.55)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("#\(rank)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.mut)
                Text((row.signal ?? "BEKLE").uppercased())
                    .font(.system(size: 10, weight: .heavy))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .foregroundStyle(row.isLong ? profit : Theme.red)
                    .background((row.isLong ? profit : Theme.red).opacity(0.14))
                    .clipShape(Capsule())
                Spacer()
                Text("\(row.quality ?? 0)/100")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.mut)
            }
            Text(row.symbol)
                .font(.system(size: 18, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text(row.name)
                .font(.system(size: 10))
                .foregroundStyle(Theme.mut)
                .lineLimit(2)
            grid
            if let g = row.guidance, !g.isEmpty {
                Text(g)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.mut)
                    .lineLimit(3)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke((row.isLong ? profit : Theme.red).opacity(0.25), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var grid: some View {
        VStack(spacing: 6) {
            HStack {
                mini("Fiyat", px(row.price), pnl: row.chg)
                mini("1s", pct(row.chg1h))
            }
            HStack {
                mini("RSI", row.rsi.map { String(format: "%.1f", $0) } ?? "—")
                mini("EMA fark", row.emaGap.map { String(format: "%.3f%%", $0) } ?? "—")
            }
            HStack {
                mini("TP", px(row.tp))
                mini("SL", px(row.sl))
            }
        }
    }

    private func mini(_ k: String, _ v: String, pnl: Double? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.mut)
            if let pnl {
                HStack(spacing: 4) {
                    Text(v)
                        .font(.system(size: 12, weight: .heavy))
                        .foregroundStyle(Theme.ink)
                    Text(pct(pnl))
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.pnlColor(pnl))
                }
            } else {
                Text(v)
                    .font(.system(size: 12, weight: .heavy))
                    .foregroundStyle(Theme.ink)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func px(_ v: Double?) -> String {
        guard let v else { return "—" }
        return v >= 100 ? String(format: "%.2f", v) : String(format: "%.2f", v)
    }

    private func pct(_ v: Double?) -> String {
        guard let v else { return "—" }
        return String(format: "%@%.2f%%", v >= 0 ? "+" : "", v)
    }
}

struct BistHistCard: View {
    let row: BistHistRow
    let hoursLabel: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(row.symbol)
                    .font(.system(size: 14, weight: .heavy))
                Spacer()
                Text(pnlText)
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.pnlColor(row.pnlPct))
            }
            HStack {
                Text((row.signal ?? "AL").uppercased())
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .foregroundStyle(Color(red: 0.20, green: 0.90, blue: 0.55))
                    .background(Color(red: 0.20, green: 0.90, blue: 0.55).opacity(0.14))
                    .clipShape(Capsule())
                Text("\(row.quality ?? 0)/100")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.mut)
            }
            Text("Sinyal · \(row.signalTr ?? "—") · \(px(row.signalPrice)) TL")
                .font(.system(size: 11))
                .foregroundStyle(Theme.mut)
            Text("\(row.isDone ? "\(hoursLabel) sonra" : "Kontrol") · \(row.dueTr ?? row.checkTr ?? "—") · \(px(row.checkPrice)) TL\(crossNote)")
                .font(.system(size: 11))
                .foregroundStyle(Theme.mut)
        }
        .padding(12)
        .background(Theme.card)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(row.isDone ? 0.06 : 0.12), style: StrokeStyle(lineWidth: 1, dash: row.isDone ? [] : [4, 3]))
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var pnlText: String {
        if row.status == "skipped" { return "veri yok" }
        if !row.isDone { return "bekliyor" }
        let p = row.pnlPct ?? 0
        return String(format: "%@%.2f%%", p >= 0 ? "+" : "", p)
    }

    private var crossNote: String {
        guard row.crossDay == true, let tot = row.pnlTotalPct else { return "" }
        return " · kontrol günü · toplam \(tot >= 0 ? "+" : "")\(String(format: "%.2f", tot))%"
    }

    private func px(_ v: Double?) -> String {
        guard let v else { return "—" }
        return String(format: "%.2f", v)
    }
}
