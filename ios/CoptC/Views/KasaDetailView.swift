import SwiftUI

struct KasaVaultCard: View {
    let row: KasaCard

    private let gold = Color(red: 0.83, green: 0.69, blue: 0.22)
    private let profit = Color(red: 0.224, green: 1.0, blue: 0.557)

    private var balColor: Color {
        guard let vs = row.vsStart else { return Theme.ink }
        if vs > 0 { return profit }
        if vs < 0 { return Theme.red }
        return Theme.ink
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            left
            if row.hasOpen {
                Rectangle()
                    .fill(gold.opacity(0.18))
                    .frame(width: 1)
                right
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var left: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(row.name)
                .font(.system(size: 13, weight: .heavy, design: .rounded))
                .foregroundStyle(gold)
            if !row.src.isEmpty {
                Text(row.src)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Theme.mut)
                    .lineLimit(2)
            }
            Text(Theme.money(row.balance))
                .font(.system(size: 26, weight: .heavy, design: .rounded))
                .foregroundStyle(balColor)
                .padding(.top, 6)
                .minimumScaleFactor(0.55)
                .lineLimit(1)
            Text(row.footer)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Theme.mut)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var right: some View {
        let side = (row.side ?? "").trimmingCharacters(in: .whitespaces)
        let isBuy = side == "AL"
        let pnl = row.unreal
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Text(row.name)
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(gold)
                    .lineLimit(1)
                if !side.isEmpty {
                    Text("\(side) açık")
                        .font(.system(size: 9, weight: .heavy))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .foregroundStyle(isBuy ? profit : Theme.red)
                        .background((isBuy ? profit : Theme.red).opacity(0.16))
                        .clipShape(Capsule())
                }
            }
            HStack(alignment: .top, spacing: 10) {
                mini("GİRİŞ", px(row.entry))
                mini("ANLIK", px(row.mark))
            }
            HStack(alignment: .top, spacing: 10) {
                mini("LOT", row.lotText.isEmpty ? "—" : row.lotText)
                mini("K/Z", pnlText(pnl), color: Theme.pnlColor(pnl))
            }
            if let t = row.openTime, !t.isEmpty {
                Text(t)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Theme.mut)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func mini(_ k: String, _ v: String, color: Color = Theme.ink) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(k)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Theme.mut)
            Text(v)
                .font(.system(size: 12, weight: .heavy, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func px(_ v: Double?) -> String {
        guard let v = v else { return "—" }
        return String(format: "%.2f", v)
    }

    private func pnlText(_ v: Double?) -> String {
        guard let v = v else { return "—" }
        let sign = v >= 0 ? "+" : ""
        return sign + String(format: "%.2f", v)
    }
}

struct KasaDetailView: View {
    let kasa: KasaCard
    @EnvironmentObject private var appState: AppState

    private var live: CemapiLive? { appState.kasaDetails[kasa.id] }

    private var positions: [CemapiPos] {
        (live?.positions ?? []).sorted { ($0.net ?? 0) > ($1.net ?? 0) }
    }

    private var history: [CemapiTrade] { live?.history ?? [] }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                KasaVaultCard(row: painted)
                Text("Açık pozisyonlar")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.ink)
                if live == nil, appState.isLoading {
                    SoftCard {
                        Text("Yükleniyor…").foregroundStyle(Theme.mut)
                    }
                } else if positions.isEmpty {
                    SoftCard {
                        Text("Açık pozisyon yok.")
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                    }
                } else {
                    ForEach(positions) { pos in
                        posCard(pos)
                    }
                }
                CemapiHistoryBlock(code: kasa.name, trades: history)
            }
            .padding(16)
            .padding(.bottom, 24)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(kasa.name)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.ink)
            }
        }
        .toolbarBackground(Theme.bg, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .refreshable { await appState.refreshKasaDetail(kasa.id) }
        .task { await appState.refreshKasaDetail(kasa.id) }
    }

    private var painted: KasaCard {
        guard let live = live else { return kasa }
        let side: String? = {
            if let p = positions.first { return p.isLong ? "AL" : "SAT" }
            return nil
        }()
        return KasaCard(
            id: kasa.id,
            name: kasa.name,
            src: kasa.src,
            balance: live.wallet ?? live.equity ?? kasa.balance,
            startBal: kasa.startBal,
            unreal: live.unreal ?? kasa.unreal,
            openCount: live.openN ?? positions.count,
            side: side,
            entry: kasa.entry,
            mark: kasa.mark,
            openTime: kasa.openTime,
            volume: kasa.volume,
            margin: kasa.margin,
            leverage: kasa.leverage
        )
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
                Text(Theme.dolarPnl(pnl))
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
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke((pnl ?? 0) >= 0 ? Theme.lime.opacity(0.35) : Theme.red.opacity(0.35), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
