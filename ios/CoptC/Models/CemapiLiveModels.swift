import Foundation

struct CemapiLive: Decodable {
    let ok: Bool?
    let error: String?
    let id: String?
    let code: String
    let title: String
    let active: Bool
    let live: Bool
    let equity: Double?
    let netPnl: Double?
    let unreal: Double?
    let fees: Double?
    let winPct: Double?
    let trades: Int?
    let wins: Int?
    let openN: Int?
    let lastSignal: String?
    let lastScan: String?
    let lev: Int?
    let margin: Double?
    let available: Double?
    let wallet: Double?
    let positions: [CemapiPos]
    let history: [CemapiTrade]

    enum CodingKeys: String, CodingKey {
        case ok, error, id, code, title, active, live, equity, fees, trades, wins
        case positions, history, unreal, wallet, available, margin, lev
        case netPnl = "net_pnl"
        case winPct = "win_pct"
        case openN = "open_n"
        case lastSignal = "last_signal"
        case lastScan = "last_scan"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok)
        error = try c.decodeIfPresent(String.self, forKey: .error)
        id = try c.decodeIfPresent(String.self, forKey: .id)
        code = (try? c.decode(String.self, forKey: .code)) ?? "LIVE"
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        active = (try? c.decode(Bool.self, forKey: .active)) ?? ((try? c.decode(Bool.self, forKey: .live)) ?? false)
        live = (try? c.decode(Bool.self, forKey: .live)) ?? active
        equity = Self.num(c, .equity) ?? Self.num(c, .wallet)
        netPnl = Self.num(c, .netPnl)
        unreal = Self.num(c, .unreal)
        fees = Self.num(c, .fees)
        winPct = Self.num(c, .winPct)
        trades = Self.int(c, .trades)
        wins = Self.int(c, .wins)
        openN = Self.int(c, .openN)
        lastSignal = try c.decodeIfPresent(String.self, forKey: .lastSignal)
        lastScan = try c.decodeIfPresent(String.self, forKey: .lastScan)
        lev = Self.int(c, .lev)
        margin = Self.num(c, .margin)
        available = Self.num(c, .available)
        wallet = Self.num(c, .wallet)
        positions = (try? c.decode([CemapiPos].self, forKey: .positions)) ?? []
        history = (try? c.decode([CemapiTrade].self, forKey: .history)) ?? []
    }

    var stakeLine: String {
        if let lev { return "$100×\(lev)x — max 6" }
        return "$100×10x — max 6"
    }

    static func num(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
        if let v = try? c.decode(Double.self, forKey: key) { return v }
        if let v = try? c.decode(Int.self, forKey: key) { return Double(v) }
        if let s = try? c.decode(String.self, forKey: key) { return Double(s.replacingOccurrences(of: ",", with: ".")) }
        return nil
    }

    static func int(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int? {
        if let v = try? c.decode(Int.self, forKey: key) { return v }
        if let v = try? c.decode(Double.self, forKey: key) { return Int(v) }
        return nil
    }
}

struct CemapiPos: Decodable, Identifiable, Hashable {
    let id: String
    let symbol: String
    let base: String
    let side: String
    let net: Double?
    let entry: Double?
    let mark: Double?
    let pct: Double?
    let qty: Double?
    let sl: Double?
    let tp: Double?
    let opened: String?
    let mins: Int?

    var isLong: Bool { side.uppercased() == "LONG" }

    enum CodingKeys: String, CodingKey {
        case id, symbol, base, side, net, entry, mark, pct, qty, sl, tp, opened, mins
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        symbol = (try? c.decode(String.self, forKey: .symbol)) ?? ""
        base = (try? c.decode(String.self, forKey: .base)) ?? symbol.replacingOccurrences(of: "USDT", with: "")
        side = (try? c.decode(String.self, forKey: .side)) ?? ""
        id = (try? c.decode(String.self, forKey: .id)) ?? "\(symbol)-\(side)"
        net = Self.num(c, .net)
        entry = Self.num(c, .entry)
        mark = Self.num(c, .mark)
        pct = Self.num(c, .pct)
        qty = Self.num(c, .qty)
        sl = Self.num(c, .sl)
        tp = Self.num(c, .tp)
        opened = try c.decodeIfPresent(String.self, forKey: .opened)
        mins = Self.int(c, .mins)
    }

    static func num(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
        if let v = try? c.decode(Double.self, forKey: key) { return v }
        if let v = try? c.decode(Int.self, forKey: key) { return Double(v) }
        return nil
    }

    static func int(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int? {
        if let v = try? c.decode(Int.self, forKey: key) { return v }
        if let v = try? c.decode(Double.self, forKey: key) { return Int(v) }
        return nil
    }
}

struct CemapiTrade: Decodable, Identifiable, Hashable {
    let id: String
    let base: String
    let side: String
    let pnl: Double?
    let entry: Double?
    let exit: Double?
    let fee: Double?
    let reason: String?
    let opened: String?
    let closed: String?
    let mins: Int?

    var isLong: Bool { side.uppercased() == "LONG" }

    enum CodingKeys: String, CodingKey {
        case id, base, side, pnl, entry, reason, opened, mins
        case symbol, fee, kom, commission, fees
        case exit, exitPrice = "exit_price", close, closePrice = "close_price"
        case closed, closeTime = "close_time", exitTime = "exit_time"
        case openTime = "open_time", openedAt = "opened_at"
        case duration
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let symbol = (try? c.decode(String.self, forKey: .symbol)) ?? ""
        base = (try? c.decode(String.self, forKey: .base)) ?? symbol.replacingOccurrences(of: "USDT", with: "")
        side = (try? c.decode(String.self, forKey: .side)) ?? ""
        id = (try? c.decode(String.self, forKey: .id))
            ?? "\(base)-\(side)-\((try? c.decode(String.self, forKey: .closed)) ?? UUID().uuidString)"
        pnl = Self.num(c, .pnl)
        entry = Self.num(c, .entry)
        exit = Self.num(c, .exit) ?? Self.num(c, .exitPrice) ?? Self.num(c, .close) ?? Self.num(c, .closePrice)
        fee = Self.num(c, .fee) ?? Self.num(c, .kom) ?? Self.num(c, .commission) ?? Self.num(c, .fees)
        reason = try c.decodeIfPresent(String.self, forKey: .reason)
        opened = (try? c.decode(String.self, forKey: .opened))
            ?? (try? c.decode(String.self, forKey: .openTime))
            ?? (try? c.decode(String.self, forKey: .openedAt))
        closed = (try? c.decode(String.self, forKey: .closed))
            ?? (try? c.decode(String.self, forKey: .closeTime))
            ?? (try? c.decode(String.self, forKey: .exitTime))
        mins = Self.int(c, .mins) ?? Self.int(c, .duration)
    }

    var whenText: String { Self.shortTime(closed ?? opened) }

    var durationText: String {
        guard let mins, mins > 0 else { return "" }
        let h = mins / 60
        let r = mins % 60
        if h > 0 { return "\(h)s \(r)dk aktif" }
        return "\(r)dk aktif"
    }

    var detailLine: String {
        var parts: [String] = []
        let inn = Self.shortTime(opened)
        let out = Self.shortTime(closed)
        if !inn.isEmpty || !out.isEmpty {
            parts.append("Giriş \(inn.isEmpty ? "—" : inn) -> Çıkış \(out.isEmpty ? "—" : out)")
        }
        if !durationText.isEmpty { parts.append(durationText) }
        if entry != nil || exit != nil {
            parts.append("\(Self.px(entry)) -> \(Self.px(exit))")
        }
        if let reason, !reason.isEmpty { parts.append("— \(reason) —") }
        if let fee { parts.append(String(format: "Kom: $%.2f", fee)) }
        if parts.isEmpty, let pnl {
            parts.append((pnl >= 0 ? "+" : "") + String(format: "%.2f", pnl))
        }
        return parts.joined(separator: " · ").replacingOccurrences(of: " · — ", with: " — ")
    }

    static func shortTime(_ raw: String?) -> String {
        guard let raw, !raw.isEmpty else { return "" }
        if raw.count >= 16, raw.contains("T") {
            let s = raw.replacingOccurrences(of: "T", with: " ")
            return String(s.dropFirst(5).prefix(11))
        }
        return raw
    }

    static func px(_ v: Double?) -> String {
        guard let v else { return "—" }
        if abs(v) >= 1000 { return String(format: "$%.1f", v) }
        if abs(v) >= 1 { return String(format: "$%.2f", v) }
        var s = String(format: "$%.7f", v)
        while s.last == "0" { s.removeLast() }
        if s.last == "." { s.removeLast() }
        return s
    }

    static func num(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
        if let v = try? c.decode(Double.self, forKey: key) { return v }
        if let v = try? c.decode(Int.self, forKey: key) { return Double(v) }
        return nil
    }

    static func int(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int? {
        if let v = try? c.decode(Int.self, forKey: key) { return v }
        if let v = try? c.decode(Double.self, forKey: key) { return Int(v) }
        return nil
    }
}
