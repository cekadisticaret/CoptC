import SwiftUI

struct KasaVaultCard: View {
    let row: KasaCard

    var body: some View {
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
        guard let live else { return kasa }
        let side: String? = {
            if let p = positions.first { return p.isLong ? "AL" : "SAT" }
            return nil
        }()
        return KasaCard(
            id: kasa.id,
            name: kasa.name,
            src: kasa.src,
            balance: live.wallet ?? live.equity ?? kasa.balance,
            initBal: kasa.initBal,
            unreal: live.unreal ?? kasa.unreal,
            open: live.openN ?? positions.count,
            side: side
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
