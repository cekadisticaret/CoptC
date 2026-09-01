import SwiftUI

struct AlgoDetailView: View {
    let algo: AlgoCard
    @EnvironmentObject private var appState: AppState

    private let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    private var current: AlgoCard {
        appState.algoDetails[algo.id]
            ?? appState.algos.first { $0.id == algo.id }
            ?? algo
    }

    private var history: [CemapiTrade] { current.history }

    private var positions: [AlgoPos] {
        current.positions.sorted { ($0.net ?? 0) > ($1.net ?? 0) }
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                header
                hero
                stats
                Text("Açık pozisyonlar")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.ink)
                if positions.isEmpty {
                    SoftCard {
                        Text("Açık pozisyon yok.")
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                        if let sig = current.lastSignal {
                            Text(sig).font(.caption).foregroundStyle(Theme.mut)
                        }
                    }
                } else {
                    LazyVGrid(columns: cols, spacing: 10) {
                        ForEach(positions) { pos in
                            posCard(pos)
                        }
                    }
                }
                summaryBar
                CemapiHistoryBlock(code: current.code, trades: history)
                if let sig = current.lastSignal, !sig.isEmpty, !positions.isEmpty {
                    SoftCard {
                        Text("Son sinyal")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.mut)
                        Text(sig)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.ink)
                    }
                }
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(current.code)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.ink)
            }
        }
        .toolbarBackground(Theme.bg, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .refreshable {
            await appState.refreshAlgos()
            await appState.refreshAlgoDetail(algo.id)
        }
        .task { await appState.refreshAlgoDetail(algo.id) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(current.code)
                    .font(.system(size: 32, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Spacer()
                Text(current.active ? "LIVE" : "KAPALI")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(current.active ? Theme.onAccent : Theme.ink)
                    .background(current.active ? Theme.lime : Theme.navy)
                    .clipShape(Capsule())
            }
            Text(current.title)
                .font(.subheadline)
                .foregroundStyle(Theme.mut)
            Text(metaLine)
                .font(.caption)
                .foregroundStyle(Theme.mut)
        }
    }

    private var metaLine: String {
        let wr = current.winPct.map { String(format: "Win %% %.0f", $0) } ?? "Win —"
        let n = current.trades.map { "\($0) işlem" } ?? "—"
        return "\(wr) — \(n) — \(appState.algoFeed?.stakeLine ?? "$100×10x — max 6")"
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(current.active ? "CANLI" : "KAPALI") Isolated \(appState.algoFeed?.stakeLine ?? "$100×10x") · \(current.openN ?? 0) açık")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.onAccent.opacity(0.7))
            Text(Theme.money(current.equity))
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.onAccent)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("equity · net \(signed(current.netPnl)) · anlık \(signed(current.unreal))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.onAccent.opacity(0.75))
            HStack(spacing: 8) {
                mini("Net", signed(current.netPnl))
                mini("Anlık", signed(current.unreal))
                mini("WR", current.winPct.map { String(format: "%.0f%%", $0) } ?? "—")
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.lime)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func mini(_ k: String, _ v: String) -> some View {
        VStack(spacing: 2) {
            Text(k)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(Theme.onAccent.opacity(0.55))
            Text(v)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.onAccent)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Theme.onAccent.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var stats: some View {
        HStack(spacing: 8) {
            stat("Bakiye", Theme.money(current.equity), Theme.ink)
            stat("Net PNL", signed(current.netPnl), Theme.pnlColor(current.netPnl))
            stat("Anlık", signed(current.unreal), Theme.pnlColor(current.unreal))
            stat("Kom", signed(current.fees.map { -$0 }), Theme.red)
        }
    }

    private func stat(_ k: String, _ v: String, _ c: Color) -> some View {
        VStack(spacing: 4) {
            Text(k)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(Theme.mut)
            Text(v)
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundStyle(c)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func posCard(_ p: AlgoPos) -> some View {
        let pnl = p.net
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(p.base)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                Text(p.side)
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .foregroundStyle(p.isLong ? Theme.onAccent : .white)
                    .background(p.isLong ? Theme.lime : Theme.red)
                    .clipShape(Capsule())
            }
            Text(p.symbol)
                .font(.caption)
                .foregroundStyle(Theme.mut)
            HStack {
                Text((pnl ?? 0) >= 0 ? "KÂR" : "ZARAR")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.pnlColor(pnl))
                Spacer()
                Text(signed(pnl))
                    .font(.subheadline.bold())
                    .foregroundStyle(Theme.pnlColor(pnl))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .padding(8)
            .background(Theme.bg)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Theme.pnlColor(pnl).opacity(0.55), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke((pnl ?? 0) >= 0 ? Theme.lime.opacity(0.35) : Theme.red.opacity(0.35), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var summaryBar: some View {
        let n = current.trades ?? 0
        let w = current.wins ?? 0
        let open = current.openN ?? positions.count
        return Text("\(current.code) — \(open) açık — \(n) işlem — \(w) kazanç — Anlık \(signed(current.unreal))")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.mut)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func signed(_ v: Double?) -> String {
        guard let v = v else { return "—" }
        return (v >= 0 ? "+" : "") + String(format: "%.2f", v)
    }
}
