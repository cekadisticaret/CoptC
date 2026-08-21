import Foundation

struct GpsSnapshot: Decodable {
    let ok: Bool?
    let symbol: String
    let title: String?
    let balance: Double?
    let available: Double?
    let equity: Double?
    let wallet: Double?
    let initBalance: Double?
    let floatPnl: Double?
    let totalPnl: Double?
    let mid: Double?
    let bid: Double?
    let ask: Double?
    let leverage: Double?
    let margin: Double?
    let marginType: String?
    let startedAt: String?
    let tradeCount: Int?
    let openCount: Int?
    let lastDir: String?
    let nightQuiet: Bool?
    let costs: GpsCosts?
    let live: GpsLive?
    let lastReject: GpsReject?
    let positions: [GpsPosition]
    let history: [GpsTrade]

    enum CodingKeys: String, CodingKey {
        case ok, symbol, title, balance, available, equity, wallet
        case mid, bid, ask, leverage, margin, costs, live, positions, history
        case initBalance = "init_balance"
        case floatPnl = "float_pnl"
        case totalPnl = "total_pnl"
        case marginType = "margin_type"
        case startedAt = "started_at"
        case tradeCount = "trade_count"
        case openCount = "open_count"
        case lastDir = "last_dir"
        case nightQuiet = "night_quiet"
        case lastReject = "last_reject"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok)
        symbol = (try? c.decode(String.self, forKey: .symbol)) ?? "GPSUSDT"
        title = try c.decodeIfPresent(String.self, forKey: .title)
        balance = Self.num(c, .balance)
        available = Self.num(c, .available)
        equity = Self.num(c, .equity)
        wallet = Self.num(c, .wallet)
        initBalance = Self.num(c, .initBalance)
        floatPnl = Self.num(c, .floatPnl)
        totalPnl = Self.num(c, .totalPnl)
        mid = Self.num(c, .mid)
        bid = Self.num(c, .bid)
        ask = Self.num(c, .ask)
        leverage = Self.num(c, .leverage)
        margin = Self.num(c, .margin)
        marginType = try c.decodeIfPresent(String.self, forKey: .marginType)
        startedAt = try c.decodeIfPresent(String.self, forKey: .startedAt)
        tradeCount = Self.int(c, .tradeCount)
        openCount = Self.int(c, .openCount)
        lastDir = try c.decodeIfPresent(String.self, forKey: .lastDir)
        nightQuiet = try c.decodeIfPresent(Bool.self, forKey: .nightQuiet)
        costs = try c.decodeIfPresent(GpsCosts.self, forKey: .costs)
        live = try c.decodeIfPresent(GpsLive.self, forKey: .live)
        lastReject = try c.decodeIfPresent(GpsReject.self, forKey: .lastReject)
        positions = (try? c.decode([GpsPosition].self, forKey: .positions)) ?? []
        history = (try? c.decode([GpsTrade].self, forKey: .history)) ?? []
    }

    var displayBalance: Double? { live?.usdtEquity ?? equity ?? live?.usdtWallet ?? wallet ?? balance }
    var displayWallet: Double? { live?.usdtWallet ?? wallet ?? balance }
    var displayEquity: Double? { live?.usdtEquity ?? equity }
    var displayFree: Double? { live?.usdtAvailable ?? available }
    var displayUnrealized: Double? { live?.positionUnrealized ?? live?.usdtUnrealized ?? floatPnl }

    var headline: String {
        let iso = (marginType ?? "ISOLATED").capitalized
        let m = margin.map { String(format: "$%.0f", $0) } ?? "$50"
        let lev = leverage.map { String(format: "%.0fx", $0) } ?? "15x"
        let liveTag = live?.enabled == true && live?.paused != true ? "CANLI" : "KAPALI"
        return "\(liveTag) \(iso) \(m)×\(lev)"
    }

    var rejectText: String? {
        guard let r = lastReject else { return nil }
        let side = (r.side ?? lastDir ?? "").lowercased()
        let dir = side == "buy" || side == "up" ? "AL" : "SAT"
        if r.reason == "bekleme", let wait = r.wait {
            return "\(dir) sinyali var — kapanış sonrası bekleme \(wait) sn."
        }
        if let reason = r.reason, !reason.isEmpty {
            return "\(dir) — \(reason)"
        }
        return nil
    }

    var activeText: String? {
        guard let startedAt, let start = Self.parseTime(startedAt) else { return startedAt }
        let sec = max(Int(Date().timeIntervalSince(start)), 0)
        let h = sec / 3600
        let m = (sec % 3600) / 60
        return "\(startedAt.prefix(16)) · \(h) sa \(m) dk aktif"
    }

    static func parseTime(_ raw: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 3 * 3600)
        f.dateFormat = "yyyy.MM.dd HH:mm:ss"
        return f.date(from: raw)
    }

    fileprivate static func num(_ c: KeyedDecodingContainer<CodingKeys>, _ k: CodingKeys) -> Double? {
        if let d = try? c.decode(Double.self, forKey: k) { return d }
        if let i = try? c.decode(Int.self, forKey: k) { return Double(i) }
        return nil
    }

    fileprivate static func int(_ c: KeyedDecodingContainer<CodingKeys>, _ k: CodingKeys) -> Int? {
        if let i = try? c.decode(Int.self, forKey: k) { return i }
        if let d = try? c.decode(Double.self, forKey: k) { return Int(d) }
        return nil
    }
}

struct GpsCosts: Decodable {
    let takerPct: Double?
    let note: String?

    enum CodingKeys: String, CodingKey {
        case note
        case takerPct = "taker_pct"
    }
}

struct GpsLive: Decodable {
    let enabled: Bool?
    let paused: Bool?
    let symbol: String?
    let usdtAvailable: Double?
    let usdtEquity: Double?
    let usdtUnrealized: Double?
    let usdtWallet: Double?
    let positionUnrealized: Double?

    enum CodingKeys: String, CodingKey {
        case enabled, paused, symbol, position
        case usdtAvailable = "usdt_available"
        case usdtEquity = "usdt_equity"
        case usdtUnrealized = "usdt_unrealized"
        case usdtWallet = "usdt_wallet"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled)
        paused = try c.decodeIfPresent(Bool.self, forKey: .paused)
        symbol = try c.decodeIfPresent(String.self, forKey: .symbol)
        usdtAvailable = try? c.decode(Double.self, forKey: .usdtAvailable)
        usdtEquity = try? c.decode(Double.self, forKey: .usdtEquity)
        usdtUnrealized = try? c.decode(Double.self, forKey: .usdtUnrealized)
        usdtWallet = try? c.decode(Double.self, forKey: .usdtWallet)
        if let pos = try? c.decode(GpsLivePos.self, forKey: .position) {
            positionUnrealized = pos.unrealized
        } else {
            positionUnrealized = nil
        }
    }
}

private struct GpsLivePos: Decodable {
    let unrealized: Double?
}

struct GpsReject: Decodable {
    let at: String?
    let reason: String?
    let side: String?
    let wait: Int?
}

struct GpsPosition: Decodable, Identifiable {
    let id: String
    let symbol: String
    let side: String
    let entry: Double?
    let qty: Double?
    let stop: Double?
    let target: Double?
    let pnl: Double?
    let openTime: String?

    enum CodingKeys: String, CodingKey {
        case id, symbol, side, entry, qty, stop, target, pnl, volume
        case openTime = "open_time"
        case floatPnl = "float_pnl"
        case floatNet = "float_net"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        symbol = (try? c.decode(String.self, forKey: .symbol)) ?? "GPSUSDT"
        side = (try? c.decode(String.self, forKey: .side)) ?? ""
        entry = Self.num(c, .entry)
        qty = Self.num(c, .qty) ?? Self.num(c, .volume)
        stop = Self.num(c, .stop)
        target = Self.num(c, .target)
        pnl = Self.num(c, .pnl) ?? Self.num(c, .floatPnl) ?? Self.num(c, .floatNet)
        openTime = try c.decodeIfPresent(String.self, forKey: .openTime)
        if let raw = try? c.decode(String.self, forKey: .id) {
            id = raw
        } else {
            id = "\(symbol)-\(side)-\(openTime ?? "")-\(entry ?? 0)"
        }
    }

    var isBuy: Bool { side.lowercased() == "buy" }

    private static func num(_ c: KeyedDecodingContainer<CodingKeys>, _ k: CodingKeys) -> Double? {
        if let d = try? c.decode(Double.self, forKey: k) { return d }
        if let i = try? c.decode(Int.self, forKey: k) { return Double(i) }
        return nil
    }
}

struct GpsTrade: Decodable, Identifiable {
    let id: String
    let symbol: String
    let side: String
    let entry: Double?
    let exit: Double?
    let qty: Double?
    let pnl: Double
    let commission: Double?
    let commissionOpen: Double?
    let commissionClose: Double?
    let openTime: String?
    let closeTime: String?
    let reason: String?

    enum CodingKeys: String, CodingKey {
        case id, symbol, side, entry, exit, qty, pnl, commission, volume, reason
        case commissionOpen = "commission_open"
        case commissionClose = "commission_close"
        case openTime = "open_time"
        case closeTime = "close_time"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        symbol = (try? c.decode(String.self, forKey: .symbol)) ?? "GPSUSDT"
        side = (try? c.decode(String.self, forKey: .side)) ?? ""
        entry = Self.num(c, .entry)
        exit = Self.num(c, .exit)
        qty = Self.num(c, .qty) ?? Self.num(c, .volume)
        pnl = Self.num(c, .pnl) ?? 0
        commission = Self.num(c, .commission)
        commissionOpen = Self.num(c, .commissionOpen)
        commissionClose = Self.num(c, .commissionClose)
        openTime = try c.decodeIfPresent(String.self, forKey: .openTime)
        closeTime = try c.decodeIfPresent(String.self, forKey: .closeTime)
        reason = try c.decodeIfPresent(String.self, forKey: .reason)
    }

    var isBuy: Bool { side.lowercased() == "buy" }
    var isWin: Bool { pnl >= 0 }

    var clock: String {
        guard let raw = closeTime ?? openTime else { return "" }
        let parts = raw.split(separator: " ")
        if parts.count == 2 { return String(parts[1].prefix(5)) }
        return raw
    }

    var openClock: String {
        guard let raw = openTime else { return "—" }
        let parts = raw.split(separator: " ")
        if parts.count == 2 { return String(parts[1].prefix(5)) }
        return raw
    }

    var durationText: String {
        guard
            let a = openTime.flatMap(GpsSnapshot.parseTime),
            let b = closeTime.flatMap(GpsSnapshot.parseTime)
        else { return "—" }
        let sec = max(Int(b.timeIntervalSince(a)), 0)
        let m = sec / 60
        let s = sec % 60
        return "\(m) dk \(s) sn"
    }

    private static func num(_ c: KeyedDecodingContainer<CodingKeys>, _ k: CodingKeys) -> Double? {
        if let d = try? c.decode(Double.self, forKey: k) { return d }
        if let i = try? c.decode(Int.self, forKey: k) { return Double(i) }
        return nil
    }
}
