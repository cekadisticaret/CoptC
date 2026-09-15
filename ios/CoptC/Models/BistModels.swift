import Foundation

enum BistSide: String, CaseIterable, Identifiable, Hashable {
    case up
    case wait

    var id: String { rawValue }

    var title: String {
        switch self {
        case .up: return "Yükselecek"
        case .wait: return "Yakın"
        }
    }

    var apiSide: String { rawValue }
}

struct BistFeed: Decodable {
    let ok: Bool?
    let error: String?
    let side: String?
    let scan: BistScan?
    let history: BistHistoryBundle?

    var rows: [BistRow] { scan?.rows ?? [] }
    var subtitle: String { scan?.note ?? "BIST 100 · 1 saat" }
    var updated: String? { scan?.updated }
    var session: Bool? { scan?.session }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok)
        error = try c.decodeIfPresent(String.self, forKey: .error)
        side = try c.decodeIfPresent(String.self, forKey: .side)
        scan = try c.decodeIfPresent(BistScan.self, forKey: .scan)
        history = try c.decodeIfPresent(BistHistoryBundle.self, forKey: .history)
    }

    private enum CodingKeys: String, CodingKey {
        case ok, error, side, scan, history
    }
}

struct BistScan: Decodable {
    let ok: Bool?
    let tf: String?
    let n: Int?
    let updated: String?
    let session: Bool?
    let note: String?
    let rows: [BistRow]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok)
        tf = try c.decodeIfPresent(String.self, forKey: .tf)
        n = JSONFlex.int(c, .n)
        updated = try c.decodeIfPresent(String.self, forKey: .updated)
        session = try c.decodeIfPresent(Bool.self, forKey: .session)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        rows = (try? c.decode([BistRow].self, forKey: .rows)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case ok, tf, n, updated, session, note, rows
    }

}

struct BistRow: Decodable, Identifiable, Hashable {
    let symbol: String
    let name: String
    let price: Double?
    let chg: Double?
    let chg1h: Double?
    let signal: String?
    let side: String?
    let quality: Int?
    let rsi: Double?
    let emaGap: Double?
    let sl: Double?
    let tp: Double?
    let guidance: String?

    var id: String { symbol }

    var isLong: Bool {
        let s = (signal ?? "").uppercased()
        return s == "AL" || s == "LONG" || side == "up"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        symbol = (try? c.decode(String.self, forKey: .symbol)) ?? ""
        name = (try? c.decode(String.self, forKey: .name)) ?? symbol
        price = JSONFlex.num(c, .price)
        chg = JSONFlex.num(c, .chg)
        chg1h = JSONFlex.num(c, .chg1h) ?? JSONFlex.num(c, .chg_1h)
        signal = try c.decodeIfPresent(String.self, forKey: .signal)
        side = try c.decodeIfPresent(String.self, forKey: .side)
        quality = JSONFlex.int(c, .quality)
        rsi = JSONFlex.num(c, .rsi)
        emaGap = JSONFlex.num(c, .emaGap) ?? JSONFlex.num(c, .ema_gap)
        sl = JSONFlex.num(c, .sl)
        tp = JSONFlex.num(c, .tp)
        guidance = try c.decodeIfPresent(String.self, forKey: .guidance)
    }

    private enum CodingKeys: String, CodingKey {
        case symbol, name, price, chg, signal, side, quality, rsi, sl, tp, guidance
        case chg1h, chg_1h
        case emaGap, ema_gap
    }


}

struct BistHistoryBundle: Decodable {
    let h3: BistHistoryBlock?
    let h5: BistHistoryBlock?
    let h10: BistHistoryBlock?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        h3 = try c.decodeIfPresent(BistHistoryBlock.self, forKey: .h3)
        h5 = try c.decodeIfPresent(BistHistoryBlock.self, forKey: .h5)
        h10 = try c.decodeIfPresent(BistHistoryBlock.self, forKey: .h10)
    }

    private enum CodingKeys: String, CodingKey {
        case h3 = "3"
        case h5 = "5"
        case h10 = "10"
    }
}

struct BistHistoryBlock: Decodable {
    let ok: Bool?
    let checkHours: Int?
    let rows: [BistHistRow]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok)
        checkHours = JSONFlex.int(c, .checkHours) ?? JSONFlex.int(c, .check_hours)
        rows = (try? c.decode([BistHistRow].self, forKey: .rows)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case ok, rows
        case checkHours, check_hours
    }

}

struct BistHistRow: Decodable, Identifiable, Hashable {
    let id: String
    let symbol: String
    let signal: String?
    let quality: Int?
    let signalTr: String?
    let signalPrice: Double?
    let dueTr: String?
    let checkTr: String?
    let checkPrice: Double?
    let pnlPct: Double?
    let pnlTotalPct: Double?
    let status: String?
    let crossDay: Bool?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        symbol = (try? c.decode(String.self, forKey: .symbol)) ?? ""
        signal = try c.decodeIfPresent(String.self, forKey: .signal)
        quality = JSONFlex.int(c, .quality)
        signalTr = try c.decodeIfPresent(String.self, forKey: .signalTr)
            ?? (try? c.decode(String.self, forKey: .signal_tr))
        signalPrice = JSONFlex.num(c, .signalPrice) ?? JSONFlex.num(c, .signal_price)
        dueTr = try c.decodeIfPresent(String.self, forKey: .dueTr)
            ?? (try? c.decode(String.self, forKey: .due_tr))
        checkTr = try c.decodeIfPresent(String.self, forKey: .checkTr)
            ?? (try? c.decode(String.self, forKey: .check_tr))
        checkPrice = JSONFlex.num(c, .checkPrice) ?? JSONFlex.num(c, .check_price)
        pnlPct = JSONFlex.num(c, .pnlPct) ?? JSONFlex.num(c, .pnl_pct)
        pnlTotalPct = JSONFlex.num(c, .pnlTotalPct) ?? JSONFlex.num(c, .pnl_total_pct)
        status = try c.decodeIfPresent(String.self, forKey: .status)
        crossDay = (try? c.decode(Bool.self, forKey: .crossDay))
            ?? (try? c.decode(Bool.self, forKey: .cross_day))
    }

    private enum CodingKeys: String, CodingKey {
        case id, symbol, signal, quality, status
        case signalTr, signal_tr
        case signalPrice, signal_price
        case dueTr, due_tr
        case checkTr, check_tr
        case checkPrice, check_price
        case pnlPct, pnl_pct
        case pnlTotalPct, pnl_total_pct
        case crossDay, cross_day
    }



    var isDone: Bool { status == "done" }
}
