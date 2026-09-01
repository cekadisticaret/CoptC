import Foundation

struct KasaFeed: Decodable {
    let ok: Bool?
    let error: String?
    let subtitle: String?
    let books: [KasaCard]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = try c.decodeIfPresent(Bool.self, forKey: .ok)
        error = try c.decodeIfPresent(String.self, forKey: .error)
        subtitle = try c.decodeIfPresent(String.self, forKey: .subtitle)
        books = (try? c.decode([KasaCard].self, forKey: .books)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case ok, error, subtitle, books
    }
}

struct KasaCard: Decodable, Identifiable, Hashable {
    let id: String
    let name: String
    let src: String
    let balance: Double?
    let startBal: Double
    let unreal: Double?
    let openCount: Int
    let side: String?
    let entry: Double?
    let mark: Double?
    let openTime: String?
    let volume: Double?
    let margin: Double?
    let leverage: Double?

    var vsStart: Double? {
        guard let balance = balance else { return nil }
        return balance - startBal
    }

    var hasOpen: Bool {
        openCount > 0 && (side != nil || entry != nil)
    }

    var lotText: String {
        var bits: [String] = []
        if let volume = volume {
            bits.append(String(format: "%.2f lot", volume))
        }
        if let margin = margin, let leverage = leverage {
            bits.append("$\(Int(margin.rounded()))×\(Int(leverage.rounded()))x")
        }
        return bits.joined(separator: " · ")
    }

    var footer: String {
        "başlangıç $\(String(format: "%.0f", startBal))"
    }

    enum CodingKeys: String, CodingKey {
        case id, name, src, balance, unreal, side, entry, mark, volume, margin, leverage
        case startBal = "init"
        case openCount = "open"
        case openTime = "open_time"
    }

    init(
        id: String,
        name: String,
        src: String,
        balance: Double?,
        startBal: Double,
        unreal: Double?,
        openCount: Int,
        side: String?,
        entry: Double? = nil,
        mark: Double? = nil,
        openTime: String? = nil,
        volume: Double? = nil,
        margin: Double? = nil,
        leverage: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.src = src
        self.balance = balance
        self.startBal = startBal
        self.unreal = unreal
        self.openCount = openCount
        self.side = side
        self.entry = entry
        self.mark = mark
        self.openTime = openTime
        self.volume = volume
        self.margin = margin
        self.leverage = leverage
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        name = (try? c.decode(String.self, forKey: .name)) ?? id
        src = (try? c.decode(String.self, forKey: .src)) ?? ""
        balance = Self.num(c, .balance)
        startBal = Self.num(c, .startBal) ?? 500
        unreal = Self.num(c, .unreal)
        openCount = Self.int(c, .openCount) ?? 0
        side = try c.decodeIfPresent(String.self, forKey: .side)
        entry = Self.num(c, .entry)
        mark = Self.num(c, .mark)
        openTime = try c.decodeIfPresent(String.self, forKey: .openTime)
        volume = Self.num(c, .volume)
        margin = Self.num(c, .margin)
        leverage = Self.num(c, .leverage)
    }

    static func num(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Double? {
        if let v = try? c.decode(Double.self, forKey: key) { return v }
        if let v = try? c.decode(Int.self, forKey: key) { return Double(v) }
        if let s = try? c.decode(String.self, forKey: key) {
            return Double(s.replacingOccurrences(of: ",", with: "."))
        }
        return nil
    }

    static func int(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int? {
        if let v = try? c.decode(Int.self, forKey: key) { return v }
        if let v = try? c.decode(Double.self, forKey: key) { return Int(v) }
        return nil
    }
}
