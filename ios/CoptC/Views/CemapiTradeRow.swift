import SwiftUI

struct CemapiTradeRow: View {
    let trade: CemapiTrade

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(trade.whenText.isEmpty ? "—" : trade.whenText)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.mut)
                .frame(width: 70, alignment: .leading)
            Text(trade.base.isEmpty ? "—" : trade.base)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.ink)
                .frame(minWidth: 36, alignment: .leading)
                .lineLimit(1)
            Text(trade.side.isEmpty ? "—" : trade.side.uppercased())
                .font(.system(size: 9, weight: .bold))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .foregroundStyle(trade.isLong ? Color(red: 0.55, green: 0.95, blue: 0.62) : Color(red: 1.0, green: 0.55, blue: 0.58))
                .background(trade.isLong ? Color(red: 0.12, green: 0.28, blue: 0.16) : Color(red: 0.32, green: 0.12, blue: 0.14))
                .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            Text(trade.detailLine)
                .font(.system(size: 11))
                .foregroundStyle(Theme.mut)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(Theme.dolarPnl(trade.pnl))
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.pnlColor(trade.pnl))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(.vertical, 8)
    }
}

struct CemapiHistoryBlock: View {
    let code: String
    let trades: [CemapiTrade]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("GEÇMİŞ İŞLEMLER — \(code) (\(trades.count) TOPLAM)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.mut)
            if trades.isEmpty {
                SoftCard {
                    Text("Kapanmış işlem yok.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.mut)
                }
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(trades) { trade in
                        CemapiTradeRow(trade: trade)
                        if trade.id != trades.last?.id {
                            Divider().overlay(Color.white.opacity(0.06))
                        }
                    }
                }
                .padding(.horizontal, 10)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
        }
    }
}
