import SwiftUI

struct CryptoView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if let err = appState.cryptoError {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(Theme.red)
                    }
                    if let snap = appState.crypto {
                        walletCard(snap)
                        positionsCard(snap)
                        tradesSection(snap)
                        footerCard(snap)
                    } else if appState.isLoading {
                        SoftCard(fill: Theme.cream) {
                            HStack {
                                ProgressView()
                                Text("GPSUSDT yükleniyor…")
                                    .foregroundStyle(Theme.mut)
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 28)
            }
            .background(Theme.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await appState.refreshCrypto() }
            .task { await appState.refreshCrypto(silent: true) }
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Kripto")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.green)
                Text("GPSUSDT")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.mut)
            }
            Spacer()
            if appState.isLoading { ProgressView() }
        }
    }

    private func walletCard(_ snap: GpsSnapshot) -> some View {
        let bal = snap.displayBalance
        let pnl = snap.totalPnl
        return VStack(alignment: .leading, spacing: 10) {
            Text(snap.headline)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.green)
                .frame(maxWidth: .infinity)
            Text(Theme.money(bal))
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
                .frame(maxWidth: .infinity)
            Text("bakiye · serbest \(Theme.money(snap.displayFree))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.pnlColor(pnl))
                .frame(maxWidth: .infinity)
            HStack(spacing: 10) {
                mini("Mid", Theme.price(snap.mid))
                mini("Bid", Theme.price(snap.bid))
                mini("Ask", Theme.price(snap.ask))
            }
            if let pct = snap.costs?.takerPct {
                Text("taker %\(String(format: "%.2f", pct).replacingOccurrences(of: ".", with: ","))")
                    .font(.caption)
                    .foregroundStyle(Theme.mut)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(20)
        .background(Theme.cream)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Theme.green, lineWidth: 5)
        }
    }

    private func mini(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(Theme.mut)
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.ink)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func positionsCard(_ snap: GpsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pozisyonlar")
                .font(.title3.bold())
                .foregroundStyle(Theme.green)
            SoftCard(fill: Theme.cream) {
                VStack(alignment: .leading, spacing: 10) {
                    if snap.positions.isEmpty {
                        Text("Açık pozisyon yok.")
                            .font(.headline)
                            .foregroundStyle(Theme.ink)
                    } else {
                        ForEach(snap.positions) { pos in
                            positionRow(pos)
                        }
                    }
                    if let note = snap.rejectText {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(Theme.mut)
                    }
                    if let u = snap.displayUnrealized {
                        Text("Anlık \(Theme.money(u))")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.pnlColor(u))
                    }
                }
            }
        }
    }

    private func positionRow(_ pos: GpsPosition) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("\(pos.symbol)  \(pos.isBuy ? "buy" : "sell") \(Theme.qty(pos.qty))")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(pos.isBuy ? Theme.green : Theme.red)
                Spacer()
                Text(String(format: "%+.2f", pos.pnl ?? 0))
                    .font(.title3.bold())
                    .foregroundStyle(Theme.pnlColor(pos.pnl))
            }
            Text("giriş \(Theme.price(pos.entry)) · sl \(Theme.price(pos.stop)) · tp \(Theme.price(pos.target))")
                .font(.caption)
                .foregroundStyle(Theme.mut)
        }
    }

    private func tradesSection(_ snap: GpsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("İşlemler")
                .font(.title3.bold())
                .foregroundStyle(Theme.green)
            if snap.history.isEmpty {
                SoftCard(fill: Theme.cream) {
                    Text("Henüz kapanmış işlem yok")
                        .font(.subheadline)
                        .foregroundStyle(Theme.mut)
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(snap.history) { trade in
                        CryptoTradeRow(trade: trade)
                    }
                }
            }
        }
    }

    private func footerCard(_ snap: GpsSnapshot) -> some View {
        SoftCard(fill: Theme.cream) {
            VStack(alignment: .leading, spacing: 8) {
                Text("bakiye")
                    .font(.caption)
                    .foregroundStyle(Theme.mut)
                HStack(alignment: .firstTextBaseline) {
                    Text(Theme.money(snap.displayBalance))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Spacer()
                    Text("toplam \(snap.tradeCount ?? snap.history.count) işlem")
                        .font(.subheadline)
                        .foregroundStyle(Theme.mut)
                }
                if let pnl = snap.totalPnl {
                    Text("toplam PnL \(String(format: "%+.2f$", pnl))")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.pnlColor(pnl))
                }
                Text("başlangıç \(Theme.money(snap.initBalance)) · \(snap.activeText ?? "—")")
                    .font(.caption)
                    .foregroundStyle(Theme.mut)
            }
        }
    }
}

struct CryptoTradeRow: View {
    let trade: GpsTrade

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(trade.isWin ? Theme.greenSoft : Theme.redSoft)
                    .frame(width: 44, height: 44)
                Image(systemName: trade.isBuy ? "arrow.up.right" : "arrow.down.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(trade.isBuy ? Theme.green : Theme.red)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("\(trade.symbol), \(trade.side) \(Theme.qty(trade.qty))")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(trade.isBuy ? Theme.green : Theme.red)
                Text("\(Theme.price(trade.entry)) → \(Theme.price(trade.exit))")
                    .font(.caption)
                    .foregroundStyle(Theme.mut)
                Text("aç \(trade.openClock) · kom aç \(Theme.money(trade.commissionOpen)) + kapa \(Theme.money(trade.commissionClose))")
                    .font(.caption2)
                    .foregroundStyle(Theme.mut)
                Text("süre \(trade.durationText)")
                    .font(.caption2)
                    .foregroundStyle(Theme.mut)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 4) {
                Text(String(format: "%+.2f", trade.pnl))
                    .font(.title3.bold())
                    .foregroundStyle(Theme.pnlColor(trade.pnl))
                Text(trade.clock)
                    .font(.caption)
                    .foregroundStyle(Theme.mut)
            }
        }
        .padding(14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .modifier(SoftShadow())
    }
}
