import SwiftUI

struct KuponlarView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            Group {
                if appState.couponFeed == nil && appState.couponError == nil {
                    VStack(spacing: 24) {
                        header
                        Spacer(minLength: 8)
                        LoadingPanel(
                            title: "Kuponlar yükleniyor",
                            subtitle: "Sanal kupon defteri sunucudan geliyor"
                        )
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 18) {
                            header
                            if let err = appState.couponError {
                                Text(err)
                                    .font(.footnote)
                                    .foregroundStyle(Theme.bahisNo)
                            }
                            bookPicker
                            leaguePicker
                            tabPicker
                            statsSection
                            couponList
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 28)
                    }
                }
            }
            .background(bahisBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await appState.refreshCoupons() }
            .task {
                if appState.couponFeed == nil {
                    await appState.refreshCoupons()
                }
                if appState.couponLeagues.isEmpty {
                    await appState.loadCouponLeagues()
                }
            }
        }
    }

    private var bahisBackground: some View {
        ZStack {
            Theme.bahisBg
            RadialGradient(
                colors: [Theme.bahisGold.opacity(0.10), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 420
            )
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("KUPONLAR")
                        .font(.system(size: 34, weight: .heavy, design: .default))
                        .italic()
                        .foregroundStyle(Theme.bahisGold)
                    if let note = appState.couponFeed?.note {
                        Text(note)
                            .font(.caption)
                            .foregroundStyle(Theme.mut)
                            .lineLimit(3)
                    }
                }
                Spacer(minLength: 8)
                if appState.isLoadingCoupons {
                    ProgressView()
                        .tint(Theme.bahisGold)
                }
            }
            if let updated = appState.couponFeed?.updated {
                Text(updated)
                    .font(.caption2)
                    .foregroundStyle(Theme.mut.opacity(0.8))
            }
        }
    }

    private var bookPicker: some View {
        let books = appState.couponFeed?.books ?? []
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(books) { book in
                    Button {
                        appState.couponBook = book.id
                        Task { await appState.refreshCoupons() }
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(book.label)
                                    .font(.system(size: 14, weight: .heavy, design: .rounded))
                                Text(book.title ?? "")
                                    .font(.caption2)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.leading)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            if let pct = bookRoiLabel(book.stats) {
                                Text(pct.text)
                                    .font(.system(size: 11, weight: .heavy, design: .rounded))
                                    .foregroundStyle(pct.color(active: appState.couponBook == book.id))
                            }
                        }
                        .foregroundStyle(appState.couponBook == book.id ? Theme.onAccent : Theme.ink.opacity(0.85))
                        .frame(width: 132, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(appState.couponBook == book.id ? Theme.bahisGold : Theme.bahisCard)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Theme.bahisGold.opacity(appState.couponBook == book.id ? 0 : 0.28), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }

    private var leaguePicker: some View {
        let chips: [LeagueChip] = [
            LeagueChip(id: "all", name: "Tüm ligler", short: "TÜM", flag: "🌍", current: nil)
        ] + appState.couponLeagues
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(chips) { chip in
                    Button {
                        appState.couponLeague = chip.id
                        Task { await appState.refreshCoupons() }
                    } label: {
                        HStack(spacing: 5) {
                            Text(chip.flag ?? "")
                            Text(chip.short ?? chip.id.uppercased())
                                .font(.caption.weight(.bold))
                        }
                        .foregroundStyle(appState.couponLeague == chip.id ? Theme.onAccent : Theme.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(appState.couponLeague == chip.id ? Theme.bahisGold : Theme.bahisCard)
                        .clipShape(Capsule())
                        .overlay {
                            Capsule().stroke(Theme.bahisGold.opacity(0.25), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var tabPicker: some View {
        let st = appState.couponFeed?.stats
        let openN = st?.open ?? 0
        let doneN = (st?.won ?? 0) + (st?.lost ?? 0)
        return HStack(spacing: 8) {
            ForEach(CouponTab.allCases, id: \.self) { tab in
                Button {
                    appState.couponTab = tab
                    Task { await appState.refreshCoupons() }
                } label: {
                    let count = tab == .open ? openN : doneN
                    Text(tab == .open ? "AÇIK · \(count)" : "SONUÇLAR · \(count)")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(appState.couponTab == tab ? Theme.onAccent : Theme.mut)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(appState.couponTab == tab ? Theme.bahisGold : Theme.bahisCard)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var statsSection: some View {
        let st = appState.couponFeed?.stats
        let label = appState.couponFeed?.bookLabel ?? "KASA"
        if let st {
            VStack(spacing: 12) {
                kasaHero(st: st, label: label)
                if appState.couponTab == .done {
                    doneStatsRow(st: st)
                } else {
                    openStatsRow(st: st)
                }
            }
        }
    }

    private func kasaHero(st: CouponStats, label: String) -> some View {
        let pnl = st.pnl ?? 0
        let balance = appState.couponTab == .done
            ? (st.equity ?? (st.starting ?? 0) + pnl)
            : (st.balance ?? st.starting ?? 0)
        return ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.09, green: 0.11, blue: 0.06),
                            Color(red: 0.05, green: 0.06, blue: 0.04),
                            Color(red: 0.10, green: 0.13, blue: 0.07),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text(appState.couponTab == .done ? "BİTEN KUPON BAKİYESİ" : "\(label) KASA")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(Theme.bahisLime.opacity(0.85))
                        .tracking(1.2)
                    Text(Theme.tlPlain(balance))
                        .font(.system(size: 30, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.bahisLime)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    if appState.couponTab == .done {
                        Text("\((st.won ?? 0) + (st.lost ?? 0)) kupon · oynanan \(Theme.tlPlain(st.staked))")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.mut)
                        Text("net \(Theme.tl(pnl))")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(pnl >= 0 ? Theme.bahisOk : Theme.bahisNo)
                    } else {
                        Text("açık \(st.open ?? 0) · kilitli \(Theme.tlPlain(st.locked))")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.mut)
                        Text("olası kazanç \(Theme.tlPlain(st.possible))")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.bahisLime.opacity(0.8))
                    }
                }
                Spacer(minLength: 0)
                Capsule()
                    .fill(Theme.bahisLime)
                    .frame(width: 10)
                    .padding(.vertical, 6)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 118)
        .modifier(SoftShadow())
    }

    private func openStatsRow(st: CouponStats) -> some View {
        let pnl = st.pnl ?? 0
        return HStack(spacing: 8) {
            statPill(title: "BAŞLANGIÇ", value: Theme.tlPlain(st.starting))
            statPill(
                title: "TOPLAM",
                value: Theme.tl(pnl),
                valueColor: pnl >= 0 ? Theme.bahisOk : Theme.bahisNo
            )
            statPill(title: "AÇIK", value: "\(st.open ?? 0) · \(Theme.tlPlain(st.locked).replacingOccurrences(of: " TL", with: ""))")
        }
    }

    private func doneStatsRow(st: CouponStats) -> some View {
        let pnl = st.pnl ?? 0
        let doneN = (st.won ?? 0) + (st.lost ?? 0)
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                statPill(title: "BAŞLANGIÇ", value: Theme.tlPlain(st.starting))
                statPill(title: "OYUNANAN", value: Theme.tlPlain(st.staked), subtitle: "\(doneN) kupon")
            }
            HStack(spacing: 8) {
                statPill(
                    title: "KÂR / ZARAR",
                    value: Theme.tl(pnl),
                    valueColor: pnl >= 0 ? Theme.bahisOk : Theme.bahisNo,
                    subtitle: st.roi != nil ? "%\(String(format: "%.1f", st.roi!)) getiri" : nil
                )
                statPill(title: "BAKİYE", value: Theme.tlPlain(st.equity))
            }
        }
    }

    private func statPill(
        title: String,
        value: String,
        valueColor: Color = Theme.ink,
        subtitle: String? = nil
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(Theme.mut)
                .tracking(0.8)
            Text(value)
                .font(.system(size: 15, weight: .heavy, design: .rounded))
                .foregroundStyle(valueColor)
                .minimumScaleFactor(0.65)
                .lineLimit(1)
            if let subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(Theme.mut)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.bahisCard)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.bahisGold.opacity(0.18), lineWidth: 1)
        }
    }

    private struct BookRoiLabel {
        let text: String
        let positive: Bool
        let negative: Bool

        func color(active: Bool) -> Color {
            if positive { return active ? Color(red: 0.09, green: 0.40, blue: 0.20) : Theme.bahisOk }
            if negative { return active ? Color(red: 0.60, green: 0.11, blue: 0.11) : Theme.bahisNo }
            return Theme.mut
        }
    }

    private func bookRoiLabel(_ st: CouponStats?) -> BookRoiLabel? {
        let done = (st?.won ?? 0) + (st?.lost ?? 0)
        guard done > 0, let roi = st?.roi else { return nil }
        let sign = roi > 0 ? "+" : ""
        return BookRoiLabel(
            text: "\(sign)\(String(format: "%.1f", roi))%",
            positive: roi > 0,
            negative: roi < 0
        )
    }

    @ViewBuilder
    private var couponList: some View {
        let slips = appState.couponFeed?.coupons ?? []
        if slips.isEmpty {
            SoftCard(fill: Theme.bahisCard) {
                Text(appState.couponTab == .done
                     ? "Henüz bitmiş kupon yok — maçlar bitince burada görünür."
                     : "Açık kupon yok.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.mut)
            }
        } else {
            LazyVStack(spacing: 16) {
                ForEach(slips) { slip in
                    CouponSlipCard(slip: slip, showBook: appState.couponBook == "all")
                }
            }
        }
    }
}

struct CouponSlipCard: View {
    let slip: CouponSlip
    var showBook: Bool = false

    private var tone: String { slip.displayTone }

    private var borderColor: Color {
        switch tone {
        case "won", "win": return Theme.bahisOk
        case "lost": return Theme.bahisNo
        case "live": return Theme.bahisGold
        default: return Theme.bahisGold.opacity(0.45)
        }
    }

    private var bgTint: Color {
        switch tone {
        case "won", "win": return Theme.bahisOk.opacity(0.12)
        case "lost": return Theme.bahisNo.opacity(0.12)
        case "live": return Theme.bahisGold.opacity(0.08)
        default: return Theme.bahisCard
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(headerLine)
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(Theme.bahisGold)
                    if let placed = slip.placedTr, !placed.isEmpty {
                        Text("Oynandı · \(placed)")
                            .font(.caption2)
                            .foregroundStyle(Theme.mut)
                    }
                }
                Spacer(minLength: 8)
                statusBadge
            }

            ForEach(slip.legs ?? []) { leg in
                CouponLegRow(leg: leg)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("MATCHDAY")
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(Theme.bahisGold)
                    Text("Kazandırır!")
                        .font(.caption2)
                        .foregroundStyle(Theme.mut)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Toplam Oran")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.onAccent.opacity(0.7))
                    Text(String(format: "%.2f", slip.oddsProduct ?? 0))
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(Theme.onAccent)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Theme.bahisGold)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            payoutBlock

            HStack {
                Text("Yatırım \(Theme.tlPlain(slip.stake ?? 200))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.mut)
                Spacer()
                if slip.status == "open" || tone == "live" || tone == "open" {
                    Text("Olası getiri \(Theme.tlPlain(slip.potential))")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Theme.ink)
                }
            }
        }
        .padding(14)
        .background(bgTint)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(borderColor, lineWidth: 2)
        }
    }

    private var headerLine: String {
        var parts: [String] = []
        if let lg = slip.leagueShort { parts.append(lg) }
        if showBook, let b = slip.bookLabel { parts.append(b) }
        if !slip.kindLabel.isEmpty { parts.append(slip.kindLabel) }
        return parts.joined(separator: " · ")
    }

    private var statusBadge: some View {
        let (text, color, fg): (String, Color, Color) = {
            switch tone {
            case "won": return ("KAZANDI", Theme.bahisOk.opacity(0.2), Theme.bahisOk)
            case "lost": return ("KAYBETTİ", Theme.bahisNo.opacity(0.2), Theme.bahisNo)
            case "win": return ("TUTUYOR", Theme.bahisOk.opacity(0.2), Theme.bahisOk)
            case "live": return ("CANLI", Theme.bahisGold.opacity(0.2), Theme.bahisGold)
            default: return ("AÇIK", Theme.bahisGold.opacity(0.15), Theme.bahisGold)
            }
        }()
        return Text(text)
            .font(.system(size: 10, weight: .heavy))
            .foregroundStyle(fg)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(color)
            .clipShape(Capsule())
    }

    @ViewBuilder
    private var payoutBlock: some View {
        if tone == "won" || tone == "lost" {
            let stake = slip.stake ?? 200
            let paid = slip.paid ?? (tone == "won" ? stake * (slip.oddsProduct ?? 1) : 0)
            let won = tone == "won" && paid > 0
            let net = slip.pnl ?? 0
            VStack(spacing: 6) {
                Text(won ? "KUPON KAZANDI" : "KUPON KAYBETTİ")
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(Theme.mut)
                    .tracking(1.5)
                Text(Theme.tlPlain(paid))
                    .font(.system(size: 36, weight: .heavy, design: .rounded))
                    .foregroundStyle(won ? Theme.bahisOk : Theme.bahisNo)
                Text(won ? "net \(Theme.tl(net))" : "yatırım −\(Theme.tlPlain(stake))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.mut)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background((won ? Theme.bahisOk : Theme.bahisNo).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke((won ? Theme.bahisOk : Theme.bahisNo).opacity(0.45), lineWidth: 1)
            }
        }
    }
}

struct CouponLegRow: View {
    let leg: CouponLeg

    private var boxTone: (Color, Color) {
        if leg.hit == true { return (Theme.bahisOk, Theme.bahisOk) }
        if leg.hit == false { return (Theme.bahisNo, Theme.bahisNo) }
        if leg.live == true || leg.phase == "live" {
            return leg.liveHit == true
                ? (Theme.bahisOk, Theme.bahisGold)
                : (Theme.bahisGold, Theme.bahisGold)
        }
        return (.white, Theme.bahisGold)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 4) {
                TeamCrest(url: leg.homeCrest, short: leg.homeShort, hex: leg.homeColor)
                TeamCrest(url: leg.awayCrest, short: leg.awayShort, hex: leg.awayColor)
            }
            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(leg.home ?? "—")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.onAccent)
                        Text("vs")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(Theme.bahisGold)
                        Text(leg.away ?? "—")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Theme.onAccent)
                        if let sc = scoreText {
                            Text(sc)
                                .font(.caption.weight(.heavy))
                                .foregroundStyle(Theme.onAccent.opacity(0.7))
                        }
                    }
                    Text(timeLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(Theme.mut.opacity(0.9))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.white)
                HStack {
                    Text(leg.marketLabel ?? "Maç Sonucu 1X2")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(red: 0.16, green: 0.20, blue: 0.25))
                    Spacer()
                    Text(leg.selBox ?? leg.sel ?? "")
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(Theme.onAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.bahisGold)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(Color(red: 0.84, green: 0.87, blue: 0.89))
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(boxTone.0.opacity(leg.hit != nil || leg.live == true ? 1 : 0), lineWidth: 2)
            }

            Text(String(format: "%.2f", leg.odds ?? 0))
                .font(.system(size: 22, weight: .heavy, design: .rounded))
                .foregroundStyle(leg.hit == false ? .white : Theme.onAccent)
                .frame(width: 64, height: 64)
                .background(leg.hit == true ? Theme.bahisOk : (leg.hit == false ? Theme.bahisNo : Theme.bahisGold))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        if let hint = legHint {
            Text(hint)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(hintColor)
        }
    }

    private var scoreText: String? {
        guard let hg = leg.hg, let ag = leg.ag else { return nil }
        return "\(hg)–\(ag)"
    }

    private var timeLabel: String {
        if leg.live == true || leg.phase == "live" {
            return leg.minute ?? "CANLI"
        }
        return leg.whenTr ?? ""
    }

    private var legHint: String? {
        if leg.hit == true { return "TUTTU" + (scoreText.map { " \($0)" } ?? "") }
        if leg.hit == false { return "TUTMADI" + (scoreText.map { " \($0)" } ?? "") }
        if leg.live == true || leg.phase == "live" {
            if leg.liveHit == true { return "CANLI TUTUYOR" + (scoreText.map { " \($0)" } ?? "") }
            return (leg.minute ?? "CANLI") + (scoreText.map { " · \($0)" } ?? "")
        }
        return "bekliyor"
    }

    private var hintColor: Color {
        if leg.hit == true || leg.liveHit == true { return Theme.bahisOk }
        if leg.hit == false { return Theme.bahisNo }
        if leg.live == true || leg.phase == "live" { return Theme.bahisGold }
        return Theme.mut
    }
}

struct TeamCrest: View {
    let url: String?
    let short: String?
    let hex: String?

    var body: some View {
        Group {
            if let url, let u = URL(string: url), !url.isEmpty {
                AsyncImage(url: u) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    default:
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: 34, height: 34)
        .clipShape(Circle())
        .overlay { Circle().stroke(Color.white, lineWidth: 2) }
    }

    private var fallback: some View {
        Circle()
            .fill(Color(hex: hex) ?? Theme.navy)
            .overlay {
                Text((short ?? "?").prefix(3).uppercased())
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(.white)
            }
    }
}

private extension Color {
    init?(hex: String?) {
        guard var s = hex?.trimmingCharacters(in: .whitespacesAndNewlines), !s.isEmpty else {
            return nil
        }
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6, let v = UInt64(s, radix: 16) else { return nil }
        self.init(
            red: Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue: Double(v & 0xFF) / 255
        )
    }
}
