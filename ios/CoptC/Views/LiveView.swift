import SwiftUI

struct LiveView: View {
    @EnvironmentObject private var appState: AppState

    private let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    private var live: CemapiLive? { appState.cemapiLive }

    private var positions: [CemapiPos] {
        (live?.positions ?? []).sorted { ($0.net ?? 0) > ($1.net ?? 0) }
    }

    private var kasalar: [KasaCard] { appState.kasaFeed?.books ?? [] }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if let err = appState.liveError {
                        Text(err).font(.footnote).foregroundStyle(Theme.red)
                    }
                    if kasalar.isEmpty {
                        SoftCard {
                            Text(appState.isLoading ? "Kasalar yükleniyor…" : "Kasa verisi yok")
                                .foregroundStyle(Theme.mut)
                        }
                    } else {
                        VStack(spacing: 12) {
                            ForEach(kasalar) { row in
                                kasaCard(row)
                            }
                        }
                    }
                    if let live {
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

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Forex")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text("kasa")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(Theme.onAccent)
                    .background(Color(red: 0.83, green: 0.69, blue: 0.22))
                    .clipShape(Capsule())
                Spacer()
                if appState.isLoading { ProgressView().tint(Theme.lime) }
            }
            Text(appState.kasaFeed?.subtitle ?? "Dört sanal Isolated kasa · anlık bakiye")
                .font(.subheadline)
                .foregroundStyle(Theme.mut)
        }
    }

    private func kasaCard(_ row: KasaCard) -> some View {
        let vs = row.vsInit
        let balColor: Color = {
            guard let vs else { return Theme.ink }
            if vs > 0 { return Color(red: 0.49, green: 0.91, blue: 0.77) }
            if vs < 0 { return Theme.red }
            return Theme.ink
        }()
        return VStack(alignment: .leading, spacing: 4) {
            Text(row.name)
                .font(.system(size: 14, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(red: 0.83, green: 0.69, blue: 0.22))
            if !row.src.isEmpty {
                Text(row.src)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.mut)
            }
            Text(Theme.money(row.balance))
                .font(.system(size: 32, weight: .heavy, design: .rounded))
                .foregroundStyle(balColor)
                .padding(.top, 8)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(row.footer)
                .font(.caption)
                .foregroundStyle(Theme.mut)
                .padding(.top, 2)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
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
