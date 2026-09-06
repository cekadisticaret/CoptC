import Foundation

// MARK: - Algo page mode (inline — XcodeGen discovery sorununu önler)

enum AlgoPageMode: String, CaseIterable, Identifiable {
    case algorithms
    case gainersUp
    case gainersDown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .algorithms: return "Algoritma"
        case .gainersUp: return "Yükselenler"
        case .gainersDown: return "Düşenler"
        }
    }

    var gainerSide: String {
        switch self {
        case .gainersDown: return "down"
        default: return "up"
        }
    }

    var showsGainers: Bool {
        switch self {
        case .algorithms: return false
        case .gainersUp, .gainersDown: return true
        }
    }
}

// MARK: - Gainer models (inline)

struct GainerFeed: Decodable {
    let ok: Bool?
    let error: String?
    let side: String?
    let note: String?
    let updated: String?
    let n: Int?
    let rows: [GainerRow]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok)
        error = try c.decodeIfPresent(String.self, forKey: .error)
        side = try c.decodeIfPresent(String.self, forKey: .side)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        updated = try c.decodeIfPresent(String.self, forKey: .updated)
        n = Self.int(c, .n)
        rows = (try? c.decode([GainerRow].self, forKey: .rows)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case ok, error, side, note, updated, n, rows
    }

    static func int(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int? {
        if let v = try? c.decode(Int.self, forKey: key) { return v }
        if let v = try? c.decode(Double.self, forKey: key) { return Int(v) }
        return nil
    }
}

struct GainerRow: Decodable, Identifiable, Hashable {
    let base: String
    let symbol: String
    let chg: Double?
    let price: Double?
    let qv: Double?

    var id: String { symbol }

    enum CodingKeys: String, CodingKey {
        case base, symbol, chg, price, qv
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        symbol = (try? c.decode(String.self, forKey: .symbol)) ?? ""
        base = (try? c.decode(String.self, forKey: .base)) ?? symbol.replacingOccurrences(of: "USDT", with: "")
        chg = Self.num(c, .chg)
        price = Self.num(c, .price)
        qv = Self.num(c, .qv)
    }

    var isUp: Bool { (chg ?? 0) >= 0 }

    var chgText: String {
        guard let chg else { return "—" }
        return String(format: "%@%.2f%%", chg >= 0 ? "+" : "", chg)
    }

    var ring: Double {
        min(max(abs(chg ?? 0) / 100.0, 0), 1)
    }

    var ringText: String {
        guard let chg else { return "—" }
        return String(format: "%.0f", abs(chg))
    }

    static func num(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
        if let v = try? c.decode(Double.self, forKey: key) { return v }
        if let v = try? c.decode(Int.self, forKey: key) { return Double(v) }
        if let s = try? c.decode(String.self, forKey: key) {
            return Double(s.replacingOccurrences(of: ",", with: "."))
        }
        return nil
    }
}

// MARK: - Algo feed & card

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

    var stakeLine: String { "$200×100x · $1000" }
}

struct AlgoCard: Decodable, Identifiable, Hashable {
    let ok: Bool?
    let error: String?
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
    let history: [CemapiTrade]

    enum CodingKeys: String, CodingKey {
        case ok, error, id, code, title, active, auto, equity, fees, trades, wins, positions, history
        case netPnl = "net_pnl"
        case winPct = "win_pct"
        case openN = "open_n"
        case lastSignal = "last_signal"
        case unreal
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok)
        error = try c.decodeIfPresent(String.self, forKey: .error)
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
        history = (try? c.decode([CemapiTrade].self, forKey: .history)) ?? []
    }

    var wrText: String {
        guard let winPct = winPct else { return "—" }
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
