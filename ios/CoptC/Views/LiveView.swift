import SwiftUI

struct LiveView: View {
    @EnvironmentObject private var appState: AppState

    private let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    private var live: CemapiLive? { appState.cemapiLive }

    private var positions: [CemapiPos] {
        (live?.positions ?? []).sorted { ($0.net ?? 0) > ($1.net ?? 0) }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    if let err = appState.liveError {
                        Text(err).font(.footnote).foregroundStyle(Theme.red)
                    }
                    if let live {
                        header(live)
                        hero(live)
                        stats(live)
                        Text("Açık pozisyonlar")
                            .font(.title3.bold())
                            .foregroundStyle(Theme.ink)
                        if positions.isEmpty {
                            SoftCard {
                                Text("Açık pozisyon yok.")
                                    .font(.headline)
                                    .foregroundStyle(Theme.ink)
                                if let sig = live.lastSignal, !sig.isEmpty {
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
                        summaryBar(live)
                        CemapiHistoryBlock(code: live.code, trades: live.history)
                    } else if appState.liveError == nil {
                        SoftCard {
                            Text(appState.isLoading ? "LIVE yükleniyor…" : "LIVE veri yok")
                                .foregroundStyle(Theme.mut)
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(Theme.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await appState.refreshLive() }
            .task { await appState.refreshLive(silent: true) }
        }
    }

    private func header(_ live: CemapiLive) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("XAUUSDT Binance")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                Spacer()
                Text(live.virtual ? "SANAL" : (live.active || live.live ? "LIVE" : "KAPALI"))
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(live.active || live.live || live.virtual ? Theme.onAccent : Theme.ink)
                    .background(live.active || live.live || live.virtual ? Theme.lime : Theme.navy)
                    .clipShape(Capsule())
            }
            if !live.title.isEmpty {
                Text(live.title)
                    .font(.subheadline)
                    .foregroundStyle(Theme.mut)
            }
            Text(metaLine(live))
                .font(.caption)
                .foregroundStyle(Theme.mut)
        }
    }

    private func metaLine(_ live: CemapiLive) -> String {
        let wr = live.winPct.map { String(format: "Win %% %.0f", $0) } ?? "Win —"
        let n = live.trades.map { "\($0) işlem" } ?? "—"
        return "\(wr) — \(n) — \(live.stakeLine)"
    }

    private func hero(_ live: CemapiLive) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(live.modeLabel) Isolated \(live.stakeLine) · \(live.openN ?? positions.count) açık")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Theme.onAccent.opacity(0.7))
            Text(Theme.money(live.equity))
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .foregroundStyle(Theme.onAccent)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("equity · net \(signed(live.netPnl)) · anlık \(signed(live.unreal))")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.onAccent.opacity(0.75))
            HStack(spacing: 8) {
                mini("Net", signed(live.netPnl))
                mini("Anlık", signed(live.unreal))
                mini("WR", live.winPct.map { String(format: "%.0f%%", $0) } ?? "—")
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

    private func stats(_ live: CemapiLive) -> some View {
        HStack(spacing: 8) {
            stat("Bakiye", Theme.money(live.wallet ?? live.equity), Theme.ink)
            stat("Net PNL", signed(live.netPnl), Theme.pnlColor(live.netPnl))
            stat("Anlık", signed(live.unreal), Theme.pnlColor(live.unreal))
            stat("Kom", signed(live.fees.map { -$0 }), Theme.red)
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

    private func posCard(_ p: CemapiPos) -> some View {
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

    private func summaryBar(_ live: CemapiLive) -> some View {
        let n = live.trades ?? 0
        let w = live.wins ?? 0
        let open = live.openN ?? positions.count
        return Text("XAUUSDT — \(open) açık — \(n) işlem — \(w) kazanç — Anlık \(signed(live.unreal))")
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.mut)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func signed(_ v: Double?) -> String {
        guard let v else { return "—" }
        return (v >= 0 ? "+" : "") + String(format: "%.2f", v)
    }
}
