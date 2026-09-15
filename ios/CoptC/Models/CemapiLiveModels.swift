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
    let virtual: Bool
    let positions: [CemapiPos]
    let history: [CemapiTrade]

    enum CodingKeys: String, CodingKey {
        case ok, error, id, code, title, active, live, equity, fees, trades, wins
        case positions, history, unreal, wallet, available, margin, lev, virtual
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
        equity = JSONFlex.num(c, .equity) ?? JSONFlex.num(c, .wallet)
        netPnl = JSONFlex.num(c, .netPnl)
        unreal = JSONFlex.num(c, .unreal)
        fees = JSONFlex.num(c, .fees)
        winPct = JSONFlex.num(c, .winPct)
        trades = JSONFlex.int(c, .trades)
        wins = JSONFlex.int(c, .wins)
        openN = JSONFlex.int(c, .openN)
        lastSignal = try c.decodeIfPresent(String.self, forKey: .lastSignal)
        lastScan = try c.decodeIfPresent(String.self, forKey: .lastScan)
        lev = JSONFlex.int(c, .lev)
        margin = JSONFlex.num(c, .margin)
        available = JSONFlex.num(c, .available)
        wallet = JSONFlex.num(c, .wallet)
        virtual = (try? c.decode(Bool.self, forKey: .virtual)) ?? false
        positions = (try? c.decode([CemapiPos].self, forKey: .positions)) ?? []
        history = (try? c.decode([CemapiTrade].self, forKey: .history)) ?? []
    }

    var stakeLine: String {
        let m = margin.map { String(format: "$%.0f", $0) } ?? "$100"
        if let lev = lev { return "\(m)×\(lev)x" }
        return "\(m)×30x"
    }

    var modeLabel: String {
        if virtual { return "SANAL" }
        if active || live { return "CANLI" }
        return "KAPALI"
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
        net = JSONFlex.num(c, .net)
        entry = JSONFlex.num(c, .entry)
        mark = JSONFlex.num(c, .mark)
        pct = JSONFlex.num(c, .pct)
        qty = JSONFlex.num(c, .qty)
        sl = JSONFlex.num(c, .sl)
        tp = JSONFlex.num(c, .tp)
        opened = try c.decodeIfPresent(String.self, forKey: .opened)
        mins = JSONFlex.int(c, .mins)
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
        pnl = JSONFlex.num(c, .pnl)
        entry = JSONFlex.num(c, .entry)
        exit = JSONFlex.num(c, .exit) ?? JSONFlex.num(c, .exitPrice) ?? JSONFlex.num(c, .close) ?? JSONFlex.num(c, .closePrice)
        fee = JSONFlex.num(c, .fee) ?? JSONFlex.num(c, .kom) ?? JSONFlex.num(c, .commission) ?? JSONFlex.num(c, .fees)
        reason = try c.decodeIfPresent(String.self, forKey: .reason)
        opened = (try? c.decode(String.self, forKey: .opened))
            ?? (try? c.decode(String.self, forKey: .openTime))
            ?? (try? c.decode(String.self, forKey: .openedAt))
        closed = (try? c.decode(String.self, forKey: .closed))
            ?? (try? c.decode(String.self, forKey: .closeTime))
            ?? (try? c.decode(String.self, forKey: .exitTime))
        mins = JSONFlex.int(c, .mins) ?? JSONFlex.int(c, .duration)
    }

    var whenText: String { Self.shortTime(closed ?? opened) }

    var durationText: String {
        guard let mins = mins, mins > 0 else { return "" }
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
        if let reason = reason, !reason.isEmpty { parts.append("— \(reason) —") }
        if let fee = fee { parts.append(String(format: "Kom: $%.2f", fee)) }
        if parts.isEmpty, let pnl = pnl {
            parts.append((pnl >= 0 ? "+" : "") + String(format: "%.2f", pnl))
        }
        return parts.joined(separator: " · ").replacingOccurrences(of: " · — ", with: " — ")
    }

    static func shortTime(_ raw: String?) -> String {
        guard let raw = raw, !raw.isEmpty else { return "" }
        let s = raw.replacingOccurrences(of: "T", with: " ")
        if s.count >= 16, s.contains(".") || s.contains("-") {
            let body = String(s.dropFirst(5).prefix(11))
            return body.replacingOccurrences(of: ".", with: "-")
        }
        return raw
    }

    static func px(_ v: Double?) -> String {
        guard let v = v else { return "—" }
        if abs(v) >= 1000 { return String(format: "$%.1f", v) }
        if abs(v) >= 1 { return String(format: "$%.2f", v) }
        var s = String(format: "$%.7f", v)
        while s.last == "0" { s.removeLast() }
        if s.last == "." { s.removeLast() }
        return s
    }


}
