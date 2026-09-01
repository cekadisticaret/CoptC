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
    let initBal: Double
    let unreal: Double?
    let open: Int
    let side: String?

    var vsInit: Double? {
        guard let balance else { return nil }
        return balance - initBal
    }

    var footer: String {
        var bits: [String] = []
        if open > 0 {
            let s = (side ?? "").trimmingCharacters(in: .whitespaces)
            bits.append(s.isEmpty ? "açık" : "\(s) açık")
            if let unreal {
                let sign = unreal >= 0 ? "+" : ""
                bits.append("anlık \(sign)\(String(format: "%.2f", unreal))")
            }
        } else {
            bits.append("düz")
        }
        bits.append("başlangıç $\(String(format: "%.0f", initBal))")
        return bits.joined(separator: " · ")
    }

    enum CodingKeys: String, CodingKey {
        case id, name, src, balance, init, unreal, open, side
    }

    init(
        id: String,
        name: String,
        src: String,
        balance: Double?,
        initBal: Double,
        unreal: Double?,
        open: Int,
        side: String?
    ) {
        self.id = id
        self.name = name
        self.src = src
        self.balance = balance
        self.initBal = initBal
        self.unreal = unreal
        self.open = open
        self.side = side
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? c.decode(String.self, forKey: .id)) ?? UUID().uuidString
        name = (try? c.decode(String.self, forKey: .name)) ?? id
        src = (try? c.decode(String.self, forKey: .src)) ?? ""
        balance = Self.num(c, .balance)
        initBal = Self.num(c, .init) ?? 500
        unreal = Self.num(c, .unreal)
        open = Self.int(c, .open) ?? 0
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
