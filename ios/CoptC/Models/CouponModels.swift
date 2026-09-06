import Foundation

enum CouponTab: String, CaseIterable {
    case open
    case done

    var title: String {
        switch self {
        case .open: return "Açık"
        case .done: return "Sonuçlar"
        }
    }
}

struct CouponFeed: Codable {
    let ok: Bool?
    let league: String?
    let leagueId: String?
    let book: String?
    let bookLabel: String?
    let bookTitle: String?
    let books: [CouponBook]?
    let updated: String?
    let stats: CouponStats?
    let n: Int?
    let coupons: [CouponSlip]?
    let note: String?

    enum CodingKeys: String, CodingKey {
        case ok, league, book, books, updated, stats, n, coupons, note
        case leagueId = "league_id"
        case bookLabel = "book_label"
        case bookTitle = "book_title"
    }
}

struct CouponBook: Codable, Identifiable {
    let id: String
    let label: String
    let title: String?
    let note: String?
    let starting: Double?
    let stats: CouponStats?
}

struct CouponStats: Codable {
    let n: Int?
    let open: Int?
    let won: Int?
    let lost: Int?
    let pnl: Double?
    let staked: Double?
    let roi: Double?
    let starting: Double?
    let equity: Double?
    let balance: Double?
    let locked: Double?
    let possible: Double?
}

struct CouponSlip: Codable, Identifiable {
    let id: String
    let status: String?
    let tone: String?
    let kind: String?
    let book: String?
    let bookLabel: String?
    let leagueShort: String?
    let placedAt: String?
    let placedTr: String?
    let oddsProduct: Double?
    let stake: Double?
    let potential: Double?
    let pnl: Double?
    let paid: Double?
    let legs: [CouponLeg]?
    let system: String?
    let sysK: Int?
    let sysN: Int?
    let sysWon: Int?
    let nCombos: Int?
    let unit: Double?

    enum CodingKeys: String, CodingKey {
        case id, status, tone, kind, book, stake, potential, pnl, paid, legs, system, unit
        case bookLabel = "book_label"
        case leagueShort = "league_short"
        case placedAt = "placed_at"
        case placedTr = "placed_tr"
        case oddsProduct = "odds_product"
        case sysK = "sys_k"
        case sysN = "sys_n"
        case sysWon = "sys_won"
        case nCombos = "n_combos"
    }

    var displayTone: String { tone ?? status ?? "open" }

    var kindLabel: String {
        if kind == "sys" {
            let k = sysK ?? 2
            let n = sysN ?? legs?.count ?? 0
            return "SİSTEM \(k)/\(n)"
        }
        if kind == "tek" { return "TEK MAÇ" }
        return ""
    }
}

struct CouponLeg: Codable, Identifiable {
    let matchId: String?
    let market: String?
    let marketLabel: String?
    let sel: String?
    let selBox: String?
    let home: String?
    let away: String?
    let whenTr: String?
    let kickoff: String?
    let odds: Double?
    let hit: Bool?
    let hg: Int?
    let ag: Int?
    let live: Bool?
    let phase: String?
    let liveHit: Bool?
    let minute: String?
    let homeCrest: String?
    let awayCrest: String?
    let homeShort: String?
    let awayShort: String?
    let homeColor: String?
    let awayColor: String?

    enum CodingKeys: String, CodingKey {
        case matchId = "id"
        case market, sel, home, away, kickoff, odds, hit, hg, ag, live, phase, minute
        case marketLabel = "market_label"
        case selBox = "sel_box"
        case whenTr = "when_tr"
        case liveHit = "live_hit"
        case homeCrest = "home_crest"
        case awayCrest = "away_crest"
        case homeShort = "home_short"
        case awayShort = "away_short"
        case homeColor = "home_color"
        case awayColor = "away_color"
    }

    var id: String {
        matchId ?? "\(home ?? "")-\(away ?? "")-\(sel ?? "")"
    }
}

struct LeaguesResponse: Codable {
    let ok: Bool?
    let leagues: [LeagueChip]?
}

struct LeagueChip: Codable, Identifiable, Hashable {
    let id: String
    let name: String?
    let short: String?
    let flag: String?
    let current: Bool?
}
