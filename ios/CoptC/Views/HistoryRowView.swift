import SwiftUI

struct HistoryRowView: View {
    let trade: TradeHistory
    var isLast = false

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(trade.win ? Theme.lime : Theme.redSoft)
                    .frame(width: 44, height: 44)
                Image(systemName: trade.win ? "checkmark" : "xmark")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(trade.win ? Theme.onAccent : Theme.red)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("\(trade.symbol) · \(trade.platform ?? "Polymarket")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                Text("\(timeLabel)  \(trade.pred ?? "—") → \(trade.actual ?? "—")")
                    .font(.caption)
                    .foregroundStyle(Theme.mut)
            }
            Spacer()
            Text(String(format: "%+.2f$", trade.pnl))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Theme.pnlColor(trade.pnl))
        }
        .padding(14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .modifier(SoftShadow())
    }

    private var timeLabel: String {
        let parts = trade.time.split(separator: " ")
        return parts.count == 2 ? String(parts[1]) : trade.time
    }
}
