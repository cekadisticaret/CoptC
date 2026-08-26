import Foundation

struct AlgoFeed: Decodable {
    let ok: Bool?
    let error: String?
    let subtitle: String?
    let lastScan: String?
    let netPnl: Double?
    let fees: Double?
    let openN: Int?
    let algos: [AlgoCard]

    enum CodingKeys: String, CodingKey {
        case ok, error, subtitle, algos, fees
        case lastScan = "last_scan"
        case netPnl = "net_pnl"
        case openN = "open_n"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok)
        error = try c.decodeIfPresent(String.self, forKey: .error)
        subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle)
        lastScan = try c.decodeIfPresent(String.self, forKey: .lastScan)
        netPnl = Self.num(c, .netPnl)
        fees = Self.num(c, .fees)
        openN = Self.int(c, .openN)
        algos = (try? c.decode([AlgoCard].self, forKey: .algos)) ?? []
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

    var stakeLine: String { "$100×10x — max 6" }
}

struct AlgoCard: Decodable, Identifiable, Hashable {
    let id: String
    let code: String
    let title: String
    let active: Bool
    let auto: Bool
    let equity: Double?
    let netPnl: Double?
    let unreal: Double?
    let fees: Double?
    let winPct: Double?
    let trades: Int?
    let wins: Int?
    let openN: Int?
    let lastSignal: String?
    let positions: [AlgoPos]

    enum CodingKeys: String, CodingKey {
        case id, code, title, active, auto, equity, fees, trades, wins, positions
        case netPnl = "net_pnl"
        case winPct = "win_pct"
        case openN = "open_n"
        case lastSignal = "last_signal"
        case unreal
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        code = (try? c.decode(String.self, forKey: .code)) ?? id
        title = (try? c.decode(String.self, forKey: .title)) ?? ""
        active = (try? c.decode(Bool.self, forKey: .active)) ?? false
        auto = (try? c.decode(Bool.self, forKey: .auto)) ?? false
        equity = Self.num(c, .equity)
        netPnl = Self.num(c, .netPnl)
        unreal = Self.num(c, .unreal)
        fees = Self.num(c, .fees)
        winPct = Self.num(c, .winPct)
        trades = Self.int(c, .trades)
        wins = Self.int(c, .wins)
        openN = Self.int(c, .openN)
        lastSignal = try c.decodeIfPresent(String.self, forKey: .lastSignal)
        positions = (try? c.decode([AlgoPos].self, forKey: .positions)) ?? []
    }

    var wrText: String {
        guard let winPct else { return "—" }
        return String(format: "%.0f", winPct)
    }

    var ring: Double {
        min(max((winPct ?? 0) / 100.0, 0), 1)
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
        if let s = try? c.decode(String.self, forKey: key), let v = Int(s) { return v }
        return nil
    }
}

struct AlgoPos: Decodable, Identifiable, Hashable {
    let symbol: String
    let base: String
    let side: String
    let net: Double?

    var id: String { "\(symbol)-\(side)" }
    var isLong: Bool { side.uppercased() == "LONG" }

    enum CodingKeys: String, CodingKey {
        case symbol, base, side, net
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        symbol = (try? c.decode(String.self, forKey: .symbol)) ?? ""
        base = (try? c.decode(String.self, forKey: .base)) ?? symbol.replacingOccurrences(of: "USDT", with: "")
        side = (try? c.decode(String.self, forKey: .side)) ?? ""
        if let v = try? c.decode(Double.self, forKey: .net) { net = v }
        else if let v = try? c.decode(Int.self, forKey: .net) { net = Double(v) }
        else { net = nil }
    }
}
