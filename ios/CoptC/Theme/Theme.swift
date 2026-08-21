import SwiftUI

enum Theme {
    static let bg = Color(red: 0.965, green: 0.968, blue: 0.955)       // off-white
    static let lime = Color(red: 0.816, green: 0.992, blue: 0.243)     // neon
    static let green = lime
    static let greenSoft = Color(red: 0.90, green: 0.97, blue: 0.72)
    static let cream = Color(red: 0.94, green: 0.96, blue: 0.90)
    static let card = Color.white
    static let ink = Color(red: 0.07, green: 0.07, blue: 0.08)
    static let mut = Color(red: 0.45, green: 0.46, blue: 0.48)
    static let gold = Color(red: 0.82, green: 0.64, blue: 0.18)
    static let red = Color(red: 0.94, green: 0.22, blue: 0.32)
    static let redSoft = Color(red: 1.0, green: 0.90, blue: 0.91)
    static let navy = Color(red: 0.08, green: 0.09, blue: 0.10)         // charcoal
    static let purple = navy
    static let onAccent = Color.black
    static let radius: CGFloat = 28

    static func money(_ value: Double?) -> String {
        guard let value else { return "—" }
        let sign = value < 0 ? "-" : ""
        return sign + "$" + String(format: "%.2f", abs(value)).replacingOccurrences(of: ".", with: ",")
    }

    static func price(_ value: Double?, digits: Int = 5) -> String {
        guard let value else { return "—" }
        return String(format: "%.\(digits)f", value)
    }

    static func qty(_ value: Double?) -> String {
        guard let value else { return "—" }
        let nf = NumberFormatter()
        nf.locale = Locale(identifier: "tr_TR")
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 3
        return nf.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
    }

    static func pnlColor(_ value: Double?) -> Color {
        guard let value else { return mut }
        if value > 0 { return Color(red: 0.25, green: 0.55, blue: 0.12) }
        if value < 0 { return red }
        return mut
    }

    static func pnlFill(_ value: Double?) -> Color {
        guard let value else { return card }
        if value > 0 { return lime }
        if value < 0 { return red }
        return card
    }

    static func onPnl(_ value: Double?) -> Color {
        guard let value, value != 0 else { return ink }
        return value > 0 ? onAccent : .white
    }
}

struct SoftShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: Color.black.opacity(0.07), radius: 14, x: 0, y: 6)
    }
}

struct SoftCard<Content: View>: View {
    var fill: Color = Theme.card
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: Theme.radius, style: .continuous))
            .modifier(SoftShadow())
    }
}

struct ProgressRing: View {
    let progress: Double
    let text: String
    var color: Color = Theme.gold

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.18), lineWidth: 8)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(text)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
        }
        .frame(width: 72, height: 72)
    }
}

struct TagView: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.14))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
