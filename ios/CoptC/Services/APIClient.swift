import Foundation

enum APIClientError: LocalizedError {
    case invalidURL
    case unauthorized
    case server(String)
    case decode

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Geçersiz sunucu adresi"
        case .unauthorized: return "Oturum süresi doldu — tekrar giriş yap"
        case .server(let msg): return msg
        case .decode: return "Veri okunamadı"
        }
    }
}

final class APIClient {
    static let shared = APIClient()
    static let defaultBaseURL = "https://deadella.com.tr/admin"
    static let cemapiBaseURL = "http://168.144.210.201/admin"
    static let gpsBaseURL = "https://bursaapp.com/forex/api/gpsusdt"
    static let gpsToken = "l1A6idRdTvs5KkbSoVa_vnHQFoIQIOTNsdjI7O27gXA"

    private let session: URLSession
    private let cookieLock = NSLock()
    /// host → cookie adı → değer  (iOS HTTP IP çerezini bazen atıyor)
    private var hostCookies: [String: [String: String]] = [:]

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let cfg = URLSessionConfiguration.ephemeral
            cfg.httpCookieAcceptPolicy = .always
            cfg.httpShouldSetCookies = true
            cfg.httpCookieStorage = HTTPCookieStorage.shared
            cfg.timeoutIntervalForRequest = 25
            HTTPCookieStorage.shared.cookieAcceptPolicy = .always
            self.session = URLSession(configuration: cfg)
        }
    }

    func login(baseURL: String, password: String) async throws {
        _ = try await request(baseURL, path: "/api/mobile/login", method: "POST", body: ["password": password])
    }

    func logout(baseURL: String) async {
        _ = try? await request(baseURL, path: "/api/mobile/logout", method: "POST", body: [:])
        if let host = URL(string: baseURL)?.host {
            cookieLock.lock()
            hostCookies[host] = [:]
            cookieLock.unlock()
        }
    }

    func home(baseURL: String) async throws -> HomeResponse {
        try decode(try await request(baseURL, path: "/api/mobile/home", method: "GET"))
    }

    func setLive(baseURL: String, on: Bool) async throws -> LiveResponse {
        try decode(try await request(baseURL, path: "/api/mobile/live", method: "POST", body: ["on": on]))
    }

    func settings(baseURL: String) async throws -> SettingsResponse {
        try decode(try await request(baseURL, path: "/api/mobile/settings", method: "GET"))
    }

    func saveAmounts(baseURL: String, low: Double, mid: Double, high: Double) async throws -> SettingsResponse {
        try decode(try await request(
            baseURL,
            path: "/api/mobile/settings/amounts",
            method: "POST",
            body: ["low": low, "mid": mid, "high": high]
        ))
    }

    func mirrorBooks(baseURL: String) async throws -> MirrorBooksResponse {
        try decode(try await request(baseURL, path: "/api/mirror/books", method: "GET"))
    }

    func gpsusdt(limit: Int = 50) async throws -> GpsSnapshot {
        guard var parts = URLComponents(string: Self.gpsBaseURL) else {
            throw APIClientError.invalidURL
        }
        parts.queryItems = [URLQueryItem(name: "limit", value: "\(limit)")]
        guard let url = parts.url else { throw APIClientError.invalidURL }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.setValue(Self.gpsToken, forHTTPHeaderField: "X-Gpsusdt-Token")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, resp) = try await session.data(for: req)
        try check(data: data, response: resp)
        return try decode(data)
    }

    func selectBooks(baseURL: String, books: [String]) async throws -> [String] {
        struct Sel: Decodable { let selected: [String] }
        let data = try await request(
            baseURL,
            path: "/api/mirror/select",
            method: "POST",
            body: ["books": books]
        )
        if let sel = try? JSONDecoder().decode(Sel.self, from: data) {
            return sel.selected
        }
        return books
    }

    private func decode<T: Decodable>(_ data: Data) throws -> T {
        do { return try JSONDecoder().decode(T.self, from: data) }
        catch { throw APIClientError.decode }
    }

    private func request(
        _ baseURL: String,
        path: String,
        method: String,
        body: [String: Any]? = nil
    ) async throws -> Data {
        let url = try endpoint(baseURL, path: path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.httpShouldHandleCookies = true
        applyCookies(to: &req, url: url)
        if let body {
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }
        let (data, resp) = try await session.data(for: req)
        if let http = resp as? HTTPURLResponse {
            ingestCookies(from: http, url: url)
        }
        try check(data: data, response: resp)
        return data
    }

    private func applyCookies(to req: inout URLRequest, url: URL) {
        guard let host = url.host else { return }
        cookieLock.lock()
        let bag = hostCookies[host] ?? [:]
        cookieLock.unlock()
        guard !bag.isEmpty else { return }
        let header = bag.map { "\($0.key)=\($0.value)" }.joined(separator: "; ")
        req.setValue(header, forHTTPHeaderField: "Cookie")
    }

    private func ingestCookies(from http: HTTPURLResponse, url: URL) {
        guard let host = url.host else { return }
        var incoming: [String: String] = [:]
        let parsed = HTTPCookie.cookies(
            withResponseHeaderFields: stringHeaders(http.allHeaderFields),
            for: url
        )
        for c in parsed { incoming[c.name] = c.value }
        if incoming.isEmpty, let raw = http.value(forHTTPHeaderField: "Set-Cookie") {
            for part in raw.components(separatedBy: ",") {
                let pair = part.split(separator: ";", maxSplits: 1).first.map(String.init) ?? ""
                let kv = pair.split(separator: "=", maxSplits: 1)
                if kv.count == 2 {
                    incoming[kv[0].trimmingCharacters(in: .whitespaces)] =
                        kv[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }
        guard !incoming.isEmpty else { return }
        cookieLock.lock()
        var bag = hostCookies[host] ?? [:]
        incoming.forEach { bag[$0.key] = $0.value }
        hostCookies[host] = bag
        cookieLock.unlock()
        for (name, value) in incoming {
            if let cookie = HTTPCookie(properties: [
                .domain: host,
                .path: "/admin",
                .name: name,
                .value: value,
                .originURL: url,
            ]) {
                HTTPCookieStorage.shared.setCookie(cookie)
            }
        }
    }

    private func stringHeaders(_ fields: [AnyHashable: Any]) -> [String: String] {
        var out: [String: String] = [:]
        for (k, v) in fields {
            out["\(k)"] = "\(v)"
        }
        return out
    }

    private func endpoint(_ baseURL: String, path: String) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(trimmed)\(path)") else {
            throw APIClientError.invalidURL
        }
        return url
    }

    private func check(data: Data, response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { return }
        if http.statusCode == 401 {
            throw APIClientError.unauthorized
        }
        guard (200...299).contains(http.statusCode) else {
            if let err = try? JSONDecoder().decode(APIErrorResponse.self, from: data),
               let msg = err.error {
                throw APIClientError.server(msg)
            }
            throw APIClientError.server("HTTP \(http.statusCode)")
        }
    }
}
