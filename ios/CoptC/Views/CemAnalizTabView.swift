import SwiftUI

struct CemAnalizTabView: View {
    @EnvironmentObject private var appState: AppState
    @State private var inner = InnerTab.positions

    private let cyan = Color(red: 0.40, green: 0.85, blue: 0.95)
    private let profit = Color(red: 0.20, green: 0.90, blue: 0.55)
    private let amber = Color(red: 0.98, green: 0.78, blue: 0.28)

    private var feed: CemAnalizFeed? { appState.cemAnalizFeed }

    private static let desks: [(id: String, name: String, src: String)] = [
        ("ace", "ACEUSDT", "A1#26 MACD Histogram Diverjansı"),
        ("near", "NEARUSDT", "MELEZ · Mean Reversion"),
        ("broccoli", "BROCCOLI714USDT", "A2#07 Hurst Proxy (trend/MR)"),
    ]

    private enum InnerTab: String, CaseIterable {
        case positions, logs, closed, settings
        var title: String {
            switch self {
            case .positions: return "Açık"
            case .logs: return "Karar"
            case .closed: return "Kapanan"
            case .settings: return "Risk"
            }
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    if let err = appState.cemAnalizError {
                        Text(err).font(.footnote).foregroundStyle(Theme.red)
                    }
                    hud
                    innerPicker
                    switch inner {
                    case .positions: positionsBlock
                    case .logs: logsBlock
                    case .closed: closedBlock
                    case .settings: settingsBlock
                    }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(Theme.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await appState.refreshCemananaliz() }
            .task {
                await appState.refreshCemananaliz(silent: true)
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 2_500_000_000)
                    if Task.isCancelled { break }
                    await appState.refreshCemananaliz(silent: true)
                }
            }
        }
    }

    private var header: some View {
        let on = feed?.running == true
        return HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text("CEMANALİZ")
                        .font(.system(size: 24, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text("ACE · NEAR · BROCCOLI")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundStyle(cyan)
                        .background(cyan.opacity(0.12))
                        .overlay(Capsule().stroke(cyan.opacity(0.35), lineWidth: 1))
                        .clipShape(Capsule())
                }
                Text("Motor: analytic forex kasası. Ayna — ayrı işlem açmaz.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.mut)
            }
            Spacer()
            Text(on ? "Tarama açık" : "Yeni emir kapalı")
                .font(.system(size: 10, weight: .bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .foregroundStyle(on ? profit : Theme.mut)
                .background(on ? profit.opacity(0.14) : Theme.card)
                .overlay(
                    Capsule().stroke(on ? profit.opacity(0.4) : Color.white.opacity(0.08), lineWidth: 1)
                )
                .clipShape(Capsule())
        }
    }

    private var hud: some View {
        let eq = feed?.equity ?? feed?.balance
        let initBal = feed?.initBalance ?? 1500
        let pnl = feed?.totalPnl
        let fees = feed?.totalFees
        let trades = feed?.tradeCount ?? 0
        let wins = feed?.winCount ?? 0
        let losses = feed?.lossCount ?? 0
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            hudCard("ÖZSERMAYE", usd(eq), color: (eq ?? 0) >= initBal ? profit : Theme.red, sub: "nakit \(usd(feed?.balance))")
            hudCard("GERÇEKLEŞEN", signedUsd(pnl), color: Theme.pnlColor(pnl))
            hudCard("KOMİSYON", usd(fees), color: amber)
            hudCard("İŞLEM", "\(trades)", color: Theme.ink, sub: "\(wins) kâr / \(losses) zarar")
        }
    }

    private func hudCard(_ title: String, _ value: String, color: Color, sub: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.mut)
            Text(value)
                .font(.system(size: 20, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            if let sub {
                Text(sub)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.mut)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var innerPicker: some View {
        let openN = feed?.openCount ?? 0
        let logN = feed?.logs.count ?? 0
        let closedN = feed?.closed.count ?? 0
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(.positions, "Açık (\(openN))")
                chip(.logs, "Karar (\(logN))")
                chip(.closed, "Kapanan (\(closedN))")
                chip(.settings, "Risk")
            }
        }
    }

    private func chip(_ tab: InnerTab, _ label: String) -> some View {
        Button {
            inner = tab
        } label: {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .foregroundStyle(inner == tab ? Color.black : Theme.mut)
                .background(inner == tab ? amber : Theme.card)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var positionsBlock: some View {
        VStack(spacing: 10) {
            ForEach(Self.desks, id: \.id) { desk in
                deskCard(desk)
            }
        }
    }

    private func deskCard(_ desk: (id: String, name: String, src: String)) -> some View {
        let pos = feed?.positions.first(where: { $0.deskId == desk.id })
        let dir = (feed?.lastDir[desk.id] ?? "NEUTRAL").uppercased()
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(desk.name)
                        .font(.system(size: 14, weight: .heavy, design: .monospaced))
                        .foregroundStyle(cyan)
                    Text(desk.src)
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.mut)
                        .lineLimit(1)
                }
                Spacer()
                Text(dir)
                    .font(.system(size: 10, weight: .heavy))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(dirColor(dir))
                    .overlay(Capsule().stroke(dirColor(dir).opacity(0.4), lineWidth: 1))
                    .clipShape(Capsule())
            }
            if let pos {
                HStack {
                    Text(pos.isLong ? "AL açık" : "SAT açık")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Theme.mut)
                    Spacer()
                    Text(signedUsd(pos.floatPnl))
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.pnlColor(pos.floatPnl))
                }
                HStack(alignment: .top, spacing: 10) {
                    mini("Giriş", px(pos.entry))
                    mini("Anlık", px(pos.mark))
                    mini("Lot / marj", lotText(pos), color: amber)
                    mini("Sinyal", pos.engine ?? pos.signal ?? "—")
                }
            } else {
                Text("Açık işlem yok · Isolated $100×20x bekliyor")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.mut)
                    .padding(.top, 4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var logsBlock: some View {
        let rows = feed?.logs ?? []
        return VStack(alignment: .leading, spacing: 0) {
            if rows.isEmpty {
                SoftCard { Text("Karar günlüğü boş.").foregroundStyle(Theme.mut) }
            } else {
                ForEach(rows) { row in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 8) {
                            Text(clock(row.timestamp))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(Theme.mut)
                            Text(row.type)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(cyan)
                        }
                        Text(row.message)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.ink)
                        if let d = row.details, !d.isEmpty {
                            Text(d)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.mut)
                        }
                    }
                    .padding(.vertical, 8)
                    if row.id != rows.last?.id {
                        Divider().overlay(Color.white.opacity(0.06))
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var closedBlock: some View {
        let rows = feed?.closed ?? []
        return VStack(alignment: .leading, spacing: 0) {
            if rows.isEmpty {
                SoftCard { Text("Henüz kapanmış işlem yok.").foregroundStyle(Theme.mut) }
            } else {
                ForEach(rows) { row in
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(row.symbol)
                                    .font(.system(size: 13, weight: .heavy, design: .monospaced))
                                    .foregroundStyle(Theme.ink)
                                Text(row.isLong ? "LONG" : "SHORT")
                                    .font(.system(size: 9, weight: .heavy))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .foregroundStyle(row.isLong ? profit : Theme.red)
                                    .background((row.isLong ? profit : Theme.red).opacity(0.14))
                                    .clipShape(Capsule())
                                Text("20x")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(amber)
                            }
                            Text("\(px(row.entry)) → \(px(row.exit)) · \(reasonLabel(row.reason))")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.mut)
                            Text(clock(row.closedAt))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(Theme.mut)
                        }
                        Spacer()
                        Text(signedUsd(row.pnl))
                            .font(.system(size: 14, weight: .heavy, design: .rounded))
                            .foregroundStyle(Theme.pnlColor(row.pnl))
                    }
                    .padding(.vertical, 9)
                    if row.id != rows.last?.id {
                        Divider().overlay(Color.white.opacity(0.06))
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var settingsBlock: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Strateji & Risk (kilitli)")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.ink)
            Text("Algoritma bozulmasın diye salt okunur. Ana kaldıraç botunun ayarları ayrıdır.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.mut)
            ForEach(Self.desks, id: \.id) { desk in
                VStack(alignment: .leading, spacing: 4) {
                    Text(desk.name).font(.system(size: 13, weight: .heavy, design: .monospaced)).foregroundStyle(cyan)
                    Text(desk.src).font(.system(size: 11)).foregroundStyle(Theme.mut)
                    Text("Kaldıraç: Isolated $100 × 20x")
                    Text("Taker: %0.05 · TF: 1h")
                    Text("TP: $35 (%35 marj) · SL: $15 (%15)")
                    Text("Başabaşa kilit: +$15 · ATR SL: 0.5× · max 24s")
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(Theme.ink)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
    }

    private func mini(_ k: String, _ v: String, color: Color = Theme.ink) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(k)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.mut)
            Text(v)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dirColor(_ dir: String) -> Color {
        switch dir {
        case "UP": return profit
        case "DOWN": return Theme.red
        default: return Theme.mut
        }
    }

    private func lotText(_ pos: CemAnalizPos) -> String {
        let qty = pos.qty.map { String(format: "%.2f", $0) } ?? "—"
        return "\(qty) · $100×20x"
    }

    private func usd(_ v: Double?) -> String {
        guard let v else { return "—" }
        let sign = v < 0 ? "-" : ""
        return sign + "$" + String(format: "%.2f", abs(v))
    }

    private func signedUsd(_ v: Double?) -> String {
        guard let v else { return "—" }
        return (v >= 0 ? "+" : "−") + "$" + String(format: "%.2f", abs(v))
    }

    private func px(_ v: Double?) -> String {
        guard let v else { return "—" }
        let a = abs(v)
        let d = a >= 100 ? 2 : a >= 1 ? 4 : 6
        return String(format: "%.\(d)f", v)
    }

    private func clock(_ ms: Double?) -> String {
        guard let ms else { return "—" }
        let date = Date(timeIntervalSince1970: ms / 1000)
        let f = DateFormatter()
        f.locale = Locale(identifier: "tr_TR")
        f.dateFormat = "HH:mm:ss"
        return f.string(from: date)
    }

    private func reasonLabel(_ raw: String?) -> String {
        switch raw {
        case "tp": return "TP"
        case "stop_margin": return "SL marj"
        case "atr_stop": return "ATR SL"
        case "be_stop": return "Başabaşa"
        case "max_hold": return "24s"
        case "flip": return "Sinyal çevir"
        case "manual": return "Manuel"
        default: return raw?.isEmpty == false ? raw! : "—"
        }
    }
}
