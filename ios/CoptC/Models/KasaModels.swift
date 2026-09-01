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

    var vsStart: Double? {
        guard let balance = balance else { return nil }
        return balance - startBal
    }

    var footer: String {
        var bits: [String] = []
        if openCount > 0 {
            let s = (side ?? "").trimmingCharacters(in: .whitespaces)
            bits.append(s.isEmpty ? "açık" : "\(s) açık")
            if let unreal = unreal {
                let sign = unreal >= 0 ? "+" : ""
                bits.append("anlık \(sign)\(String(format: "%.2f", unreal))")
            }
        } else {
            bits.append("düz")
        }
        bits.append("başlangıç $\(String(format: "%.0f", startBal))")
        return bits.joined(separator: " · ")
    }

    enum CodingKeys: String, CodingKey {
        case id, name, src, balance, unreal, side
        case startBal = "init"
        case openCount = "open"
    }

    init(
        id: String,
        name: String,
        src: String,
        balance: Double?,
        startBal: Double,
        unreal: Double?,
        openCount: Int,
        side: String?
    ) {
        self.id = id
        self.name = name
        self.src = src
        self.balance = balance
        self.startBal = startBal
        self.unreal = unreal
        self.openCount = openCount
        self.side = side
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
