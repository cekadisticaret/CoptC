import SwiftUI

struct PolyAlgoTabView: View {
    @EnvironmentObject private var appState: AppState

    private var feed: PolyAlgoFeed? { appState.polyAlgoFeed }
    private let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    if let err = appState.polyAlgoError {
                        Text(err).font(.footnote).foregroundStyle(Theme.red)
                    }
                    marketTape
                    pathTape
                    if let watch = feed?.watchBooks, !watch.isEmpty {
                        sectionTitle("İzleme")
                        LazyVGrid(columns: cols, spacing: 10) {
                            ForEach(watch) { book in
                                PolyBookCard(book: book)
                            }
                        }
                    }
                    if let rest = feed?.otherBooks, !rest.isEmpty {
                        sectionTitle("Tüm defterler")
                        LazyVGrid(columns: cols, spacing: 10) {
                            ForEach(rest.prefix(40)) { book in
                                PolyBookCard(book: book)
                            }
                        }
                    }
                    if (feed?.books ?? []).isEmpty, appState.polyAlgoError == nil {
                        SoftCard {
                            Text(appState.isLoading ? "Poly defterler yükleniyor…" : "Liste boş")
                                .foregroundStyle(Theme.mut)
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(Theme.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await appState.refreshPolyAlgos() }
            .task {
                await appState.refreshPolyAlgos(silent: true)
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 15_000_000_000)
                    if Task.isCancelled { break }
                    await appState.refreshPolyAlgos(silent: true)
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Algoritma işlemler")
                    .font(.system(size: 24, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if appState.isLoading { ProgressView().tint(Theme.lime) }
            }
            Text("Poly sanal defter · yerel motor")
                .font(.system(size: 11))
                .foregroundStyle(Theme.mut)
            if let feed {
                Text(summaryLine(feed))
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(Theme.lime)
            }
        }
    }

    private func summaryLine(_ feed: PolyAlgoFeed) -> String {
        let bal = feed.totalBalance.map { "Σ $\(Int($0.rounded()))" } ?? "Σ —"
        let pnl = feed.totalPnl.map { signed($0) } ?? "—"
        let trades = feed.totalTrades.map(String.init) ?? "—"
        let open = feed.totalOpen.map(String.init) ?? "—"
        return "\(bal) · Net P&L \(pnl) · \(trades) işlem · açık \(open)"
    }

    private var marketTape: some View {
        guard let m = feed?.market, m.ok != false else { return AnyView(EmptyView()) }
        return AnyView(
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("PİYASA · 1S")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Theme.mut)
                    Spacer()
                    Text(m.overallLabel ?? "—")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(PolyBookStyle.regimeColor(m.overall))
                }
                if let hint = m.hint, !hint.isEmpty {
                    Text(hint)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.mut)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(m.coins) { coin in
                            marketCoin(coin)
                        }
                    }
                }
            }
            .padding(12)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
    }

    private func marketCoin(_ coin: PolyMarketCoin) -> some View {
        let dir = coin.dir == "UP" ? "↑" : (coin.dir == "DOWN" ? "↓" : "·")
        return VStack(alignment: .leading, spacing: 4) {
            Text("\(coin.symbol) \(dir)")
                .font(.system(size: 13, weight: .heavy))
                .foregroundStyle(Theme.ink)
            Text(coin.label ?? "—")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(PolyBookStyle.regimeColor(coin.regime))
            Text([
                coin.adx.map { "ADX \(Int($0.rounded()))" },
                coin.atrRatio.map { "vol ×\(String(format: "%.2f", $0))" },
            ].compactMap { $0 }.joined(separator: " · "))
                .font(.system(size: 10))
                .foregroundStyle(Theme.mut)
        }
        .padding(10)
        .frame(minWidth: 130, alignment: .leading)
        .background(Theme.navy)
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(PolyBookStyle.regimeColor(coin.regime).opacity(0.45), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var pathTape: some View {
        guard let p = feed?.path, p.ok != false, let n = p.hoursN, n > 0 else {
            return AnyView(EmptyView())
        }
        let span = [pathHour(p.firstHour), pathHour(p.lastHour)]
            .compactMap { $0 }
            .joined(separator: " → ")
        return AnyView(
            VStack(alignment: .leading, spacing: 4) {
                Text("SAATLİK YOL")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.mut)
                Text("\(n) saatlik veri oluştu")
                    .font(.system(size: 14, weight: .heavy))
                    .foregroundStyle(Theme.ink)
                if !span.isEmpty {
                    Text(span)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.mut)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        )
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold))
            .foregroundStyle(Theme.mut)
            .padding(.top, 4)
    }

    private func signed(_ v: Double) -> String {
        (v >= 0 ? "+" : "") + String(format: "%.1f", v)
    }

    private func pathHour(_ raw: String?) -> String? {
        guard let raw, raw.count >= 13 else { return raw }
        let dd = raw.suffix(11).prefix(2)
        let mm = raw.dropFirst(5).prefix(2)
        let hh = raw.suffix(2)
        return "\(dd).\(mm) \(hh):00"
    }
}

struct PolyBookCard: View {
    let book: PolyBook

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text(book.name)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(book.cardInk)
                Spacer()
                Text(book.wr == nil ? "WR —" : "WR %\(String(format: "%.1f", book.wr!).replacingOccurrences(of: ".", with: ","))")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(book.cardInk)
            }
            Text(book.title)
                .font(.system(size: 10))
                .foregroundStyle(book.cardMuted)
                .lineLimit(2)
                .frame(minHeight: 28, alignment: .topLeading)
            Text(book.regimeLabel ?? "Canlı")
                .font(.system(size: 9, weight: .heavy))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .foregroundStyle(book.id.lowercased() == "ref01" ? .white : PolyBookStyle.regimeColor(book.regime))
                .background(PolyBookStyle.regimeColor(book.regime).opacity(book.id.lowercased() == "ref01" ? 0.35 : 0.14))
                .clipShape(Capsule())
            row("Bakiye", usd(book.balance), book.cardInk)
            row("Net P&L", signed(book.totalPnl), pnlColor(book.totalPnl))
            row("Anlık net", signed(book.unrealizedPnl), pnlColor(book.unrealizedPnl))
            Text("\(book.openCount ?? 0) açık · \(book.opensText)")
                .font(.system(size: 10))
                .foregroundStyle(book.cardMuted)
                .lineLimit(2)
            if book.isHomeDisplay {
                Text("✓ Poly overview aktif")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(book.cardInk.opacity(0.8))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(book.cardFill)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func row(_ k: String, _ v: String, _ color: Color) -> some View {
        HStack {
            Text(k)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(book.cardMuted)
            Spacer()
            Text(v)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
        }
    }

    private func usd(_ v: Double?) -> String {
        guard let v else { return "—" }
        return "$" + String(format: "%.2f", v)
    }

    private func signed(_ v: Double?) -> String {
        guard let v else { return "—" }
        return (v >= 0 ? "+" : "") + String(format: "%.2f", v)
    }

    private func pnlColor(_ v: Double?) -> Color {
        guard let v else { return book.cardInk }
        if book.id.lowercased().hasPrefix("ref0") && book.id.lowercased() != "ref07" {
            if v > 0 { return Color(red: 0.02, green: 0.27, blue: 0.13) }
            if v < 0 { return Color(red: 0.61, green: 0.07, blue: 0.16) }
        }
        return Theme.pnlColor(v)
    }
}
