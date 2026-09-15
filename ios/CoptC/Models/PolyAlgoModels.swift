import Foundation
import SwiftUI

struct PolyAlgoFeed: Decodable {
    let ok: Bool?
    let error: String?
    let totalBalance: Double?
    let totalPnl: Double?
    let totalOpen: Int?
    let totalTrades: Int?
    let watchPin: [String]
    let books: [PolyBook]
    let market: PolyMarketTape?
    let path: PolyPathTape?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok)
        error = try c.decodeIfPresent(String.self, forKey: .error)
        totalBalance = JSONFlex.num(c, .totalBalance) ?? JSONFlex.num(c, .total_balance)
        totalPnl = JSONFlex.num(c, .totalPnl) ?? JSONFlex.num(c, .total_pnl)
        totalOpen = JSONFlex.int(c, .totalOpen) ?? JSONFlex.int(c, .total_open)
        totalTrades = JSONFlex.int(c, .totalTrades) ?? JSONFlex.int(c, .total_trades)
        watchPin = (try? c.decode([String].self, forKey: .watchPin))
            ?? (try? c.decode([String].self, forKey: .watch_pin))
            ?? []
        books = (try? c.decode([PolyBook].self, forKey: .books)) ?? []
        market = try c.decodeIfPresent(PolyMarketTape.self, forKey: .market)
        path = try c.decodeIfPresent(PolyPathTape.self, forKey: .path)
    }

    private enum CodingKeys: String, CodingKey {
        case ok, error, books, market, path
        case totalBalance, total_balance
        case totalPnl, total_pnl
        case totalOpen, total_open
        case totalTrades, total_trades
        case watchPin, watch_pin
    }



    var watchBooks: [PolyBook] {
        let map = Dictionary(uniqueKeysWithValues: books.map { ($0.id.lowercased(), $0) })
        let pinned = watchPin.compactMap { map[$0.lowercased()] }
        if !pinned.isEmpty { return pinned }
        return books.filter(\.watchPin).sorted { ($0.balance ?? 0) > ($1.balance ?? 0) }
    }

    var otherBooks: [PolyBook] {
        let pinIds = Set(watchBooks.map { $0.id.lowercased() })
        return books.filter { !pinIds.contains($0.id.lowercased()) }
            .sorted { ($0.totalPnl ?? 0) > ($1.totalPnl ?? 0) }
    }
}

struct PolyMarketTape: Decodable {
    let ok: Bool?
    let overall: String?
    let overallLabel: String?
    let hint: String?
    let coins: [PolyMarketCoin]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok)
        overall = try c.decodeIfPresent(String.self, forKey: .overall)
        overallLabel = try c.decodeIfPresent(String.self, forKey: .overallLabel)
            ?? (try? c.decode(String.self, forKey: .overall_label))
        hint = try c.decodeIfPresent(String.self, forKey: .hint)
        coins = (try? c.decode([PolyMarketCoin].self, forKey: .coins)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case ok, overall, hint, coins
        case overallLabel, overall_label
    }
}

struct PolyMarketCoin: Decodable, Identifiable {
    let symbol: String
    let regime: String?
    let label: String?
    let adx: Double?
    let atrRatio: Double?
    let dir: String?

    var id: String { symbol }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        symbol = (try? c.decode(String.self, forKey: .symbol)) ?? ""
        regime = try c.decodeIfPresent(String.self, forKey: .regime)
        label = try c.decodeIfPresent(String.self, forKey: .label)
        dir = try c.decodeIfPresent(String.self, forKey: .dir)
        adx = JSONFlex.num(c, .adx)
        atrRatio = JSONFlex.num(c, .atrRatio) ?? JSONFlex.num(c, .atr_ratio)
    }

    private enum CodingKeys: String, CodingKey {
        case symbol, regime, label, dir, adx
        case atrRatio, atr_ratio
    }

}

struct PolyPathTape: Decodable {
    let ok: Bool?
    let hoursN: Int?
    let firstHour: String?
    let lastHour: String?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok)
        hoursN = JSONFlex.int(c, .hoursN) ?? JSONFlex.int(c, .hours_n)
        firstHour = try c.decodeIfPresent(String.self, forKey: .firstHour)
            ?? (try? c.decode(String.self, forKey: .first_hour))
        lastHour = try c.decodeIfPresent(String.self, forKey: .lastHour)
            ?? (try? c.decode(String.self, forKey: .last_hour))
    }

    private enum CodingKeys: String, CodingKey {
        case ok
        case hoursN, hours_n
        case firstHour, first_hour
        case lastHour, last_hour
    }

}

struct PolyBook: Decodable, Identifiable {
    let id: String
    let name: String
    let title: String
    let balance: Double?
    let totalPnl: Double?
    let unrealizedPnl: Double?
    let wr: Double?
    let historyN: Int?
    let openCount: Int?
    let regime: String?
    let regimeLabel: String?
    let watchPin: Bool
    let isHomeDisplay: Bool
    let cards: [PolyOpenCard]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        name = (try? c.decode(String.self, forKey: .name))
            ?? (try? c.decode(String.self, forKey: .label))
            ?? id.uppercased()
        title = (try? c.decode(String.self, forKey: .title))
            ?? (try? c.decode(String.self, forKey: .category))
            ?? ""
        balance = JSONFlex.num(c, .balance)
        totalPnl = JSONFlex.num(c, .totalPnl) ?? JSONFlex.num(c, .total_pnl)
        unrealizedPnl = JSONFlex.num(c, .unrealizedPnl) ?? JSONFlex.num(c, .unrealized_pnl)
        wr = JSONFlex.num(c, .wr)
        historyN = JSONFlex.int(c, .historyN) ?? JSONFlex.int(c, .history_n)
        openCount = JSONFlex.int(c, .openCount) ?? JSONFlex.int(c, .open_count)
        regime = try c.decodeIfPresent(String.self, forKey: .regime)
        regimeLabel = try c.decodeIfPresent(String.self, forKey: .regimeLabel)
            ?? (try? c.decode(String.self, forKey: .regime_label))
        watchPin = (try? c.decode(Bool.self, forKey: .watchPin))
            ?? (try? c.decode(Bool.self, forKey: .watch_pin))
            ?? false
        isHomeDisplay = (try? c.decode(Bool.self, forKey: .isHomeDisplay))
            ?? (try? c.decode(Bool.self, forKey: .is_home_display))
            ?? false
        cards = (try? c.decode([PolyOpenCard].self, forKey: .cards)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, label, title, category, balance, wr, cards, regime
        case totalPnl, total_pnl
        case unrealizedPnl, unrealized_pnl
        case historyN, history_n
        case openCount, open_count
        case regimeLabel, regime_label
        case watchPin, watch_pin
        case isHomeDisplay, is_home_display
    }



    var opensText: String {
        if cards.isEmpty { return "açık yok" }
        return cards.map { card in
            let side = card.side == "LONG" ? "UP" : "DOWN"
            let pnl = card.winProfit.map { String(format: "%+.0f", $0) } ?? ""
            return "\(card.name) \(side)\(pnl.isEmpty ? "" : " \(pnl)$")"
        }.joined(separator: " · ")
    }

    var cardFill: Color { PolyBookStyle.fill(for: id) }
    var cardInk: Color { PolyBookStyle.ink(for: id) }
    var cardMuted: Color { PolyBookStyle.muted(for: id) }
}

struct PolyOpenCard: Decodable {
    let name: String
    let side: String
    let winProfit: Double?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        side = (try? c.decode(String.self, forKey: .side)) ?? ""
        winProfit = JSONFlex.num(c, .winProfit) ?? JSONFlex.num(c, .win_profit)
    }

    private enum CodingKeys: String, CodingKey {
        case name, side
        case winProfit, win_profit
    }

}

enum PolyBookStyle {
    static func fill(for id: String) -> Color {
        switch id.lowercased() {
        case "ref01": return Color(red: 0.37, green: 0.84, blue: 0.54)
        case "ref02": return Color(red: 0.23, green: 0.69, blue: 0.43)
        case "ref03": return Color(red: 0.18, green: 0.58, blue: 0.36)
        case "ref04": return Color(red: 0.72, green: 0.48, blue: 0.22)
        case "ref05": return Color(red: 0.22, green: 0.45, blue: 0.82)
        case "ref06": return Color(red: 0.52, green: 0.28, blue: 0.72)
        case "ref07": return Color(red: 0.20, green: 0.24, blue: 0.34)
        case "refsa": return Color(red: 0.38, green: 0.18, blue: 0.52)
        default: return Theme.card
        }
    }

    static func ink(for id: String) -> Color {
        switch id.lowercased() {
        case "ref01", "ref02", "ref03": return Color(red: 0.05, green: 0.12, blue: 0.07)
        default: return Theme.ink
        }
    }

    static func muted(for id: String) -> Color {
        switch id.lowercased() {
        case "ref01", "ref02", "ref03": return Color(red: 0.10, green: 0.24, blue: 0.16)
        default: return Theme.mut
        }
    }

    static func regimeColor(_ regime: String?) -> Color {
        switch regime?.lowercased() {
        case "range": return Color(red: 0.22, green: 1.0, blue: 0.56)
        case "trend": return Color(red: 0.78, green: 0.95, blue: 0.21)
        case "live": return Color(red: 0.82, green: 0.55, blue: 1.0)
        default: return Theme.mut
        }
    }
}
