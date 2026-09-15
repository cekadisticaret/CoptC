import Foundation

enum CryptoGainerSide: String, CaseIterable, Identifiable, Hashable {
    case up
    case down

    var id: String { rawValue }

    var title: String {
        switch self {
        case .up: return "Yükselenler"
        case .down: return "Düşenler"
        }
    }

    var apiSide: String { rawValue }
}

struct CryptoGainerFeed: Decodable {
    let ok: Bool?
    let error: String?
    let side: String?
    let gainers: GainerFeed?
    let scalp: CryptoScalpFeed?

    var rows: [GainerRow] { gainers?.rows ?? [] }
    var note: String? { gainers?.note }
    var updated: String? { gainers?.updated }
    var alerts: [CryptoScalpAlert] { scalp?.alerts ?? [] }
    var scalpUpdated: String? { scalp?.updated }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok)
        error = try c.decodeIfPresent(String.self, forKey: .error)
        side = try c.decodeIfPresent(String.self, forKey: .side)
        gainers = try c.decodeIfPresent(GainerFeed.self, forKey: .gainers)
        scalp = try c.decodeIfPresent(CryptoScalpFeed.self, forKey: .scalp)
    }

    private enum CodingKeys: String, CodingKey {
        case ok, error, side, gainers, scalp
    }
}

struct CryptoScalpFeed: Decodable {
    let ok: Bool?
    let updated: String?
    let note: String?
    let alerts: [CryptoScalpAlert]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok)
        updated = try c.decodeIfPresent(String.self, forKey: .updated)
        note = try c.decodeIfPresent(String.self, forKey: .note)
        alerts = (try? c.decode([CryptoScalpAlert].self, forKey: .alerts)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case ok, updated, note, alerts
    }
}

struct CryptoScalpAlert: Decodable, Identifiable, Hashable {
    let symbol: String
    let base: String
    let quality: Int?
    let tp: Double?
    let sl: Double?
    let guidance: String?
    let alertKind: String?
    let listSide: String?
    let signal: String?

    var id: String { "\(symbol)-\(alertKind ?? signal ?? "")" }

    var isLong: Bool {
        let k = (alertKind ?? "").lowercased()
        return k == "al" || (signal ?? "").uppercased() == "AL"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        symbol = (try? c.decode(String.self, forKey: .symbol)) ?? ""
        base = (try? c.decode(String.self, forKey: .base)) ?? symbol.replacingOccurrences(of: "USDT", with: "")
        quality = Self.int(c, .quality)
        tp = Self.num(c, .tp)
        sl = Self.num(c, .sl)
        guidance = try c.decodeIfPresent(String.self, forKey: .guidance)
        alertKind = try c.decodeIfPresent(String.self, forKey: .alertKind)
            ?? (try? c.decode(String.self, forKey: .alert_kind))
            ?? (try? c.decode(String.self, forKey: .band))
        listSide = try c.decodeIfPresent(String.self, forKey: .listSide)
            ?? (try? c.decode(String.self, forKey: .list_side))
        signal = try c.decodeIfPresent(String.self, forKey: .signal)
    }

    private enum CodingKeys: String, CodingKey {
        case symbol, base, quality, tp, sl, guidance, signal
        case alertKind, alert_kind, band
        case listSide, list_side
    }

    private static func num(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
        if let v = try? c.decode(Double.self, forKey: key) { return v }
        if let v = try? c.decode(Int.self, forKey: key) { return Double(v) }
        return nil
    }

    private static func int(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int? {
        if let v = try? c.decode(Int.self, forKey: key) { return v }
        if let v = try? c.decode(Double.self, forKey: key) { return Int(v) }
        return nil
    }
}
