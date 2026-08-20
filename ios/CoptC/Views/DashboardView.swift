import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    header
                    tabPicker
                    if let err = appState.errorMessage {
                        Text(err)
                            .font(.footnote)
                            .foregroundStyle(Theme.red)
                    }
                    walletCard
                    resultsSection
                    historySection
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 28)
            }
            .background(Theme.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await appState.refresh() }
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.green)
                        .frame(width: 36, height: 36)
                    Text("C")
                        .font(.headline.bold())
                        .foregroundStyle(.white)
                }
                Text("CoptC")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.green)
            }
            Spacer()
            Button {
                Task { await appState.toggleLive() }
            } label: {
                Image(systemName: appState.home?.live.on == true ? "bell.fill" : "bell.slash.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(appState.home?.live.on == true ? Theme.green : Theme.mut)
                    .frame(width: 42, height: 42)
                    .background(Theme.card)
                    .clipShape(Circle())
                    .modifier(SoftShadow())
            }
            .disabled(appState.isLoading || appState.home == nil)
        }
    }

    private var tabPicker: some View {
        HStack(spacing: 8) {
            ForEach(BookTab.allCases) { tab in
                let on = appState.selectedTab == tab
                Button {
                    Task { await appState.selectTab(tab) }
                } label: {
                    Text(tab.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(on ? .white : Theme.green)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(on ? Theme.green : Theme.card)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var walletCard: some View {
        if let w = appState.home?.wallet {
            let rich = (w.cash ?? 0) > 3000
            let accent = rich ? Theme.green : Theme.gold
            VStack(alignment: .leading, spacing: 14) {
                Text("Toplam bakiye")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.green)
                    .frame(maxWidth: .infinity)
                Text(w.cashText)
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                    .frame(maxWidth: .infinity)
                Text(w.subtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accent)
                    .frame(maxWidth: .infinity)
                    .fixedSize(horizontal: false, vertical: true)
                if !w.footer.isEmpty {
                    Text(w.footer)
                        .font(.caption)
                        .foregroundStyle(Theme.mut)
                        .frame(maxWidth: .infinity)
                }
                HStack(spacing: 10) {
                    miniCard(
                        icon: "creditcard.fill",
                        title: "Nakit",
                        value: Theme.money(w.cash)
                    )
                    miniCard(
                        icon: "leaf.fill",
                        title: "Anlık",
                        value: Theme.money(w.equity)
                    )
                }
            }
            .padding(20)
            .background(Theme.cream)
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(accent, lineWidth: 5)
            }
        }
    }

    private func miniCard(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Theme.green)
                .font(.title3)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Theme.mut)
                Text(value)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .modifier(SoftShadow())
    }

    @ViewBuilder
    private var resultsSection: some View {
        let history = appState.home?.history ?? []
        if !history.isEmpty {
            let pnls = history.map(\.pnl)
            let total = pnls.reduce(0, +)
            let wins = history.filter(\.win).count
            let losses = max(history.count - wins, 0)
            VStack(alignment: .leading, spacing: 12) {
                Text("Son sonuçlar")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.green)
                SoftCard(fill: Theme.cream) {
                    VStack(alignment: .leading, spacing: 14) {
                        AreaChart(values: pnls.reversed())
                            .frame(height: 120)
                        HStack(alignment: .center, spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Toplam PnL")
                                    .font(.caption)
                                    .foregroundStyle(Theme.mut)
                                Text(String(format: "%+.2f$", total))
                                    .font(.title2.bold())
                                    .foregroundStyle(Theme.pnlColor(total))
                            }
                            Spacer()
                            WinDonut(wins: wins, losses: losses)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var historySection: some View {
        let history = appState.home?.history ?? []
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Son işlemler")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.green)
                Spacer()
                if appState.isLoading { ProgressView() }
            }
            if history.isEmpty {
                SoftCard(fill: Theme.cream) {
                    Text("Henüz kapanmış işlem yok")
                        .font(.subheadline)
                        .foregroundStyle(Theme.mut)
                }
            } else {
                VStack(spacing: 10) {
                    ForEach(history) { trade in
                        HistoryRowView(trade: trade)
                    }
                }
            }
        }
    }
}

struct AreaChart: View {
    let values: [Double]

    var body: some View {
        GeometryReader { geo in
            let pts = points(in: geo.size)
            if pts.count >= 2 {
                Path { p in
                    p.move(to: CGPoint(x: pts[0].x, y: geo.size.height))
                    p.addLine(to: pts[0])
                    for pt in pts.dropFirst() { p.addLine(to: pt) }
                    p.addLine(to: CGPoint(x: pts.last!.x, y: geo.size.height))
                    p.closeSubpath()
                }
                .fill(Theme.green.opacity(0.16))
                Path { p in
                    p.move(to: pts[0])
                    for pt in pts.dropFirst() { p.addLine(to: pt) }
                }
                .stroke(Theme.green, style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
            }
        }
    }

    private func points(in size: CGSize) -> [CGPoint] {
        guard values.count >= 2 else { return [] }
        let minV = min(values.min() ?? 0, 0)
        let maxV = max(values.max() ?? 0, 0)
        let span = max(maxV - minV, 1)
        return values.enumerated().map { i, v in
            let x = size.width * CGFloat(i) / CGFloat(values.count - 1)
            let y = size.height * (1 - CGFloat((v - minV) / span))
            return CGPoint(x: x, y: y)
        }
    }
}

struct WinDonut: View {
    let wins: Int
    let losses: Int

    private var total: Double { Double(max(wins + losses, 1)) }
    private var winShare: Double { Double(wins) / total }

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Theme.gold.opacity(0.35), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: winShare)
                    .stroke(Theme.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: 56, height: 56)
            VStack(alignment: .leading, spacing: 3) {
                legend("Kazanç", value: wins, color: Theme.green)
                legend("Kayıp", value: losses, color: Theme.gold)
            }
        }
    }

    private func legend(_ title: String, value: Int, color: Color) -> some View {
        HStack(spacing: 6) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text("\(title) \(value)")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.mut)
        }
    }
}
