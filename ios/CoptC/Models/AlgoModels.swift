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
        n = JSONFlex.int(c, .n)
        rows = (try? c.decode([GainerRow].self, forKey: .rows)) ?? []
    }

    enum CodingKeys: String, CodingKey {
        case ok, error, side, note, updated, n, rows
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
        chg = JSONFlex.num(c, .chg)
        price = JSONFlex.num(c, .price)
        qv = JSONFlex.num(c, .qv)
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
        netPnl = JSONFlex.num(c, .netPnl)
        fees = JSONFlex.num(c, .fees)
        openN = JSONFlex.int(c, .openN)
        algos = (try? c.decode([AlgoCard].self, forKey: .algos)) ?? []
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
        equity = JSONFlex.num(c, .equity)
        netPnl = JSONFlex.num(c, .netPnl)
        unreal = JSONFlex.num(c, .unreal)
        fees = JSONFlex.num(c, .fees)
        winPct = JSONFlex.num(c, .winPct)
        trades = JSONFlex.int(c, .trades)
        wins = JSONFlex.int(c, .wins)
        openN = JSONFlex.int(c, .openN)
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
