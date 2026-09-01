import Foundation

struct HomeResponse: Codable {
    let live: LiveState
    let wallet: Wallet
    let positions: [Position]
    let history: [TradeHistory]
}

struct LiveState: Codable {
    let on: Bool
    let book: String
    let label: String
}

struct Wallet: Codable {
    let label: String
    let cash: Double?
    let equity: Double?
    let cashText: String
    let subtitle: String
    let footer: String
    let warn: Bool
    let ringPct: Double?
    let ringText: String

    enum CodingKeys: String, CodingKey {
        case label, cash, equity, subtitle, footer, warn
        case cashText = "cash_text"
        case ringPct = "ring_pct"
        case ringText = "ring_text"
    }
}

struct Position: Codable, Identifiable {
    let id: String
    let symbol: String
    let dir: String
    let dirLabel: String
    let badge: String
    let source: String
    let slot: String
    let entry: Double?
    let spotNow: Double?
    let spotDiff: Double?
    let closePnl: Double?
    let pnlPct: Double?
    let closeVal: Double?
    let spent: Double
    let toWin: Double?
    let tokenBid: Double?
    let winning: Bool?
    let noLiquidity: Bool

    enum CodingKeys: String, CodingKey {
        case id, symbol, dir, badge, source, slot, entry, spent, winning
        case dirLabel = "dir_label"
        case spotNow = "spot_now"
        case spotDiff = "spot_diff"
        case closePnl = "close_pnl"
        case pnlPct = "pnl_pct"
        case closeVal = "close_val"
        case toWin = "to_win"
        case tokenBid = "token_bid"
        case noLiquidity = "no_liquidity"
    }
}

struct TradeHistory: Codable, Identifiable {
    let symbol: String
    let pred: String?
    let actual: String?
    let win: Bool
    let pnl: Double
    let time: String
    let platform: String?

    var id: String { "\(symbol)-\(time)-\(pnl)" }
}

struct SettingsResponse: Codable {
    let book: String
    let amounts: Amounts
    let min: Double
    let max: Double
    let labels: AmountLabels
    let minProfitPct: Double?
    let minProfitMaxToken: Double?

    enum CodingKeys: String, CodingKey {
        case book, amounts, min, max, labels
        case minProfitPct = "min_profit_pct"
        case minProfitMaxToken = "min_profit_max_token"
    }
}

struct Amounts: Codable {
    var low: Double
    var mid: Double
    var high: Double
}

struct AmountLabels: Codable {
    let low: String
    let mid: String
    let high: String
}

struct LiveResponse: Codable {
    let live: LiveState
}

struct APIErrorResponse: Codable {
    let error: String?
}

struct MirrorBooksResponse: Decodable {
    let books: [MirrorBook]
    let selected: [String]
    let error: String?
}

struct MirrorBook: Decodable, Identifiable {
    var id: String { book }
    let book: String
    let label: String?
    let short: String?
    let open: Int?
    let balance: Double?
    let pnl: Double?
    let wr: Double?
    let trades: Int?

    var title: String { short ?? label ?? book }

    var wrText: String {
        guard let wr else { return "—" }
        return String(format: "WR %%%.1f", wr)
    }

    enum CodingKeys: String, CodingKey {
        case book, label, short, balance, pnl, wr, trades
        case openCount = "open"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        book = try c.decode(String.self, forKey: .book)
        label = try c.decodeIfPresent(String.self, forKey: .label)
        short = try c.decodeIfPresent(String.self, forKey: .short)
        open = Self.int(c, .openCount)
        balance = Self.num(c, .balance)
        pnl = Self.num(c, .pnl)
        wr = Self.num(c, .wr)
        trades = Self.int(c, .trades)
    }

    private static func num(_ c: KeyedDecodingContainer<CodingKeys>, _ k: CodingKeys) -> Double? {
        if let d = try? c.decode(Double.self, forKey: k) { return d }
        if let i = try? c.decode(Int.self, forKey: k) { return Double(i) }
        return nil
    }

    private static func int(_ c: KeyedDecodingContainer<CodingKeys>, _ k: CodingKeys) -> Int? {
        if let i = try? c.decode(Int.self, forKey: k) { return i }
        if let d = try? c.decode(Double.self, forKey: k) { return Int(d) }
        return nil
    }
}
