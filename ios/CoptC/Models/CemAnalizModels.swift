import Foundation

struct CemAnalizFeed: Decodable {
    let ok: Bool?
    let error: String?
    let running: Bool?
    let equity: Double?
    let balance: Double?
    let initBalance: Double?
    let totalPnl: Double?
    let totalFees: Double?
    let winCount: Int?
    let lossCount: Int?
    let tradeCount: Int?
    let positions: [CemAnalizPos]
    let closed: [CemAnalizClosed]
    let logs: [CemAnalizLog]
    let lastDir: [String: String]

    var openCount: Int { positions.count }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok)
        error = try c.decodeIfPresent(String.self, forKey: .error)
        running = try c.decodeIfPresent(Bool.self, forKey: .running)
        equity = JSONFlex.num(c, .equity)
        balance = JSONFlex.num(c, .balance)
        initBalance = JSONFlex.num(c, .initBalance) ?? JSONFlex.num(c, .init_balance)
        totalPnl = JSONFlex.num(c, .totalPnl) ?? JSONFlex.num(c, .total_pnl)
        totalFees = JSONFlex.num(c, .totalFees) ?? JSONFlex.num(c, .total_fees)
        winCount = JSONFlex.int(c, .winCount) ?? JSONFlex.int(c, .win_count)
        lossCount = JSONFlex.int(c, .lossCount) ?? JSONFlex.int(c, .loss_count)
        tradeCount = JSONFlex.int(c, .tradeCount) ?? JSONFlex.int(c, .trade_count)
        positions = (try? c.decode([CemAnalizPos].self, forKey: .positions)) ?? []
        closed = (try? c.decode([CemAnalizClosed].self, forKey: .closed)) ?? []
        logs = (try? c.decode([CemAnalizLog].self, forKey: .logs)) ?? []
        lastDir = (try? c.decode([String: String].self, forKey: .lastDir))
            ?? (try? c.decode([String: String].self, forKey: .last_dir))
            ?? [:]
    }

    private enum CodingKeys: String, CodingKey {
        case ok, error, running, equity, balance, positions, closed, logs
        case initBalance, init_balance
        case totalPnl, total_pnl
        case totalFees, total_fees
        case winCount, win_count
        case lossCount, loss_count
        case tradeCount, trade_count
        case lastDir, last_dir
    }


}

struct CemAnalizPos: Decodable, Identifiable, Hashable {
    let id: String
    let deskId: String
    let symbol: String
    let name: String
    let side: String
    let qty: Double?
    let entry: Double?
    let mark: Double?
    let floatPnl: Double?
    let openedAt: Double?
    let signal: String?
    let margin: Double?
    let leverage: Double?
    let src: String?
    let engine: String?

    var isLong: Bool { side.lowercased() != "sell" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        deskId = (try? c.decode(String.self, forKey: .deskId))
            ?? (try? c.decode(String.self, forKey: .desk_id))
            ?? ""
        symbol = (try? c.decode(String.self, forKey: .symbol)) ?? ""
        name = (try? c.decode(String.self, forKey: .name)) ?? symbol
        side = (try? c.decode(String.self, forKey: .side)) ?? "buy"
        qty = JSONFlex.num(c, .qty)
        entry = JSONFlex.num(c, .entry)
        mark = JSONFlex.num(c, .mark)
        floatPnl = JSONFlex.num(c, .floatPnl) ?? JSONFlex.num(c, .float_pnl)
        openedAt = JSONFlex.num(c, .openedAt) ?? JSONFlex.num(c, .opened_at)
        signal = try c.decodeIfPresent(String.self, forKey: .signal)
        margin = JSONFlex.num(c, .margin)
        leverage = JSONFlex.num(c, .leverage)
        src = try c.decodeIfPresent(String.self, forKey: .src)
        engine = try c.decodeIfPresent(String.self, forKey: .engine)
    }

    private enum CodingKeys: String, CodingKey {
        case id, symbol, name, side, qty, entry, mark, signal, margin, leverage, src, engine
        case deskId, desk_id
        case floatPnl, float_pnl
        case openedAt, opened_at
    }

}

struct CemAnalizClosed: Decodable, Identifiable, Hashable {
    let id: String
    let deskId: String
    let symbol: String
    let side: String
    let entry: Double?
    let exit: Double?
    let qty: Double?
    let pnl: Double?
    let fee: Double?
    let reason: String?
    let openedAt: Double?
    let closedAt: Double?
    let src: String?

    var isLong: Bool { side.lowercased() != "sell" }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        deskId = (try? c.decode(String.self, forKey: .deskId))
            ?? (try? c.decode(String.self, forKey: .desk_id))
            ?? ""
        symbol = (try? c.decode(String.self, forKey: .symbol)) ?? ""
        side = (try? c.decode(String.self, forKey: .side)) ?? "buy"
        entry = JSONFlex.num(c, .entry)
        exit = JSONFlex.num(c, .exit)
        qty = JSONFlex.num(c, .qty)
        pnl = JSONFlex.num(c, .pnl)
        fee = JSONFlex.num(c, .fee)
        reason = try c.decodeIfPresent(String.self, forKey: .reason)
        openedAt = JSONFlex.num(c, .openedAt) ?? JSONFlex.num(c, .opened_at)
        closedAt = JSONFlex.num(c, .closedAt) ?? JSONFlex.num(c, .closed_at)
        src = try c.decodeIfPresent(String.self, forKey: .src)
    }

    private enum CodingKeys: String, CodingKey {
        case id, symbol, side, entry, exit, qty, pnl, fee, reason, src
        case deskId, desk_id
        case openedAt, opened_at
        case closedAt, closed_at
    }

}

struct CemAnalizLog: Decodable, Identifiable, Hashable {
    let id: String
    let timestamp: Double?
    let type: String
    let symbol: String?
    let message: String
    let details: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        timestamp = {
            if let v = try? c.decode(Double.self, forKey: .timestamp) { return v }
            if let v = try? c.decode(Int.self, forKey: .timestamp) { return Double(v) }
            return nil
        }()
        type = (try? c.decode(String.self, forKey: .type)) ?? "SCAN"
        symbol = try c.decodeIfPresent(String.self, forKey: .symbol)
        message = (try? c.decode(String.self, forKey: .message)) ?? ""
        details = try c.decodeIfPresent(String.self, forKey: .details)
    }

    private enum CodingKeys: String, CodingKey {
        case id, timestamp, type, symbol, message, details
    }
}
