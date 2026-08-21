import Foundation

enum BookTab: String, CaseIterable, Identifiable {
    case coptc
    case cemapi

    var id: String { rawValue }

    var title: String {
        switch self {
        case .coptc: return "CoptC"
        case .cemapi: return "CEMAPI"
        }
    }

    var baseURL: String {
        switch self {
        case .coptc: return APIClient.defaultBaseURL
        case .cemapi: return APIClient.cemapiBaseURL
        }
    }
}

enum CryptoMarket: String, CaseIterable, Identifiable {
    case gps
    case xau

    var id: String { rawValue }

    var title: String {
        switch self {
        case .gps: return "GPSUSDT"
        case .xau: return "XAUUSDT"
        }
    }
}
