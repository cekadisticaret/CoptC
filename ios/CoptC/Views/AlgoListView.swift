import SwiftUI

struct AlgoListView: View {
    @EnvironmentObject private var appState: AppState

    private let cols = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    if let err = appState.algoError {
                        Text(err).font(.footnote).foregroundStyle(Theme.red)
                    }
                    LazyVGrid(columns: cols, spacing: 10) {
                        ForEach(Array(appState.algos.enumerated()), id: \.element.id) { i, algo in
                            NavigationLink {
                                AlgoDetailView(algo: algo)
                            } label: {
                                AlgoMiniCard(algo: algo, featured: i == 0)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if appState.algos.isEmpty, appState.algoError == nil {
                        SoftCard {
                            Text(appState.isLoading ? "Algoritmalar yükleniyor…" : "Liste boş")
                                .foregroundStyle(Theme.mut)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 6)
                .padding(.bottom, 28)
            }
            .background(Theme.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await appState.refreshAlgos() }
            .task { await appState.refreshAlgos(silent: true) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Algoritma")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Spacer()
                if appState.isLoading { ProgressView().tint(Theme.lime) }
            }
            if let sub = appState.algoFeed?.subtitle, !sub.isEmpty {
                Text(sub)
                    .font(.caption)
                    .foregroundStyle(Theme.mut)
                    .lineLimit(3)
            }
            HStack(spacing: 10) {
                if let pnl = appState.algoFeed?.netPnl {
                    Text("Net \(signed(pnl))")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.pnlColor(pnl))
                }
                if let open = appState.algoFeed?.openN {
                    Text("\(open) açık")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.mut)
                }
                if let scan = appState.algoFeed?.lastScan, !scan.isEmpty {
                    Text(scan)
                        .font(.caption)
                        .foregroundStyle(Theme.mut)
                        .lineLimit(1)
                }
            }
        }
    }

    private func signed(_ v: Double) -> String {
        (v >= 0 ? "+" : "") + String(format: "%.2f", v)
    }
}

struct AlgoMiniCard: View {
    let algo: AlgoCard
    var featured = false

    private var fg: Color { featured ? Theme.onAccent : Theme.ink }
    private var dim: Color { featured ? Theme.onAccent.opacity(0.7) : Theme.mut }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("ALGORİTMA")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(dim)
                    Text(algo.code)
                        .font(.system(size: 16, weight: .heavy, design: .rounded))
                        .foregroundStyle(fg)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: 4)
                ZStack {
                    Circle()
                        .stroke(featured ? Theme.onAccent.opacity(0.25) : Theme.lime.opacity(0.2), lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: algo.ring)
                        .stroke(featured ? Theme.onAccent : Theme.lime, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text(algo.wrText)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(fg)
                }
                .frame(width: 28, height: 28)
            }
            Text(algo.title)
                .font(.system(size: 10))
                .foregroundStyle(dim)
                .lineLimit(2)
                .frame(minHeight: 26, alignment: .top)
            Text("Bakiye")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(dim)
            Text(Theme.money(algo.equity))
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(fg)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Rectangle()
                .fill(featured ? Theme.onAccent.opacity(0.35) : Theme.lime)
                .frame(height: 2)
            HStack {
                metric("Net", algo.netPnl)
                metric("Anlık", algo.unreal)
                VStack(spacing: 1) {
                    Text("WR")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(dim)
                    Text((algo.winPct.map { String(format: "%.0f%%", $0) }) ?? "—")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(fg)
                }
                .frame(maxWidth: .infinity)
            }
            tags
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(featured ? Theme.lime : Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func metric(_ title: String, _ value: Double?) -> some View {
        VStack(spacing: 1) {
            Text(title)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(dim)
            Text(value.map { ($0 >= 0 ? "+" : "") + String(format: "%.1f", $0) } ?? "—")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(featured ? fg : Theme.pnlColor(value))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

    private var tags: some View {
        FlowTags(items: tagItems, featured: featured)
    }

    private var tagItems: [(String, Bool, Bool)] {
        var out: [(String, Bool, Bool)] = []
        if algo.active { out.append(("LIVE", true, false)) }
        for p in algo.positions.prefix(4) {
            out.append(("\(p.base) \(p.side)", false, p.isLong))
        }
        return out
    }
}

struct FlowTags: View {
    let items: [(String, Bool, Bool)]
    var featured = false

    var body: some View {
        FlexibleHStack(spacing: 4) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                let live = item.1
                let long = item.2
                Text(item.0)
                    .font(.system(size: 8, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .foregroundStyle(live || featured ? Theme.onAccent : .white)
                    .background(live ? Theme.lime : (long ? Theme.lime.opacity(0.22) : Theme.red.opacity(0.55)))
                    .clipShape(Capsule())
            }
        }
    }
}

struct FlexibleHStack<Content: View>: View {
    var spacing: CGFloat = 4
    @ViewBuilder var content: Content

    var body: some View {
        // 2 satır sığsın diye wrap yerine sınırlı HStack
        HStack(spacing: spacing) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
