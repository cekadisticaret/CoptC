import SwiftUI

enum Theme {
    static let bg = Color(red: 0.04, green: 0.04, blue: 0.045)
    static let lime = Color(red: 0.812, green: 1.0, blue: 0.0)
    static let green = lime
    static let greenSoft = Color(red: 0.812, green: 1.0, blue: 0.0).opacity(0.16)
    static let cream = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let card = Color(red: 0.11, green: 0.11, blue: 0.12)
    static let ink = Color.white
    static let mut = Color(red: 0.62, green: 0.63, blue: 0.65)
    static let gold = lime
    static let red = Color(red: 0.95, green: 0.32, blue: 0.38)
    static let redSoft = Color(red: 0.95, green: 0.32, blue: 0.38).opacity(0.16)
    static let navy = Color(red: 0.16, green: 0.16, blue: 0.17)
    static let purple = navy
    static let onAccent = Color.black
    static let radius: CGFloat = 26

    static func money(_ value: Double?) -> String {
        guard let value else { return "—" }
        let sign = value < 0 ? "-" : ""
        return sign + "$" + String(format: "%.2f", abs(value)).replacingOccurrences(of: ".", with: ",")
    }

    static func dolarPnl(_ value: Double?) -> String {
        guard let value else { return "—" }
        if abs(value - value.rounded()) < 0.005 {
            return String(format: "%+.0f dolar", value)
        }
        return String(format: "%+.2f dolar", value)
    }

    static func price(_ value: Double?, digits: Int = 5) -> String {
        guard let value else { return "—" }
        let d = abs(value) >= 10 ? 2 : digits
        return String(format: "%.\(d)f", value)
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
        if value > 0 { return lime }
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
        content.shadow(color: Color.black.opacity(0.45), radius: 18, x: 0, y: 8)
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
            .overlay {
                RoundedRectangle(cornerRadius: Theme.radius, style: .continuous)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            }
            .modifier(SoftShadow())
    }
}

struct ProgressRing: View {
    let progress: Double
    let text: String
    var color: Color = Theme.lime

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
    var darkText: Bool = false

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color)
            .foregroundStyle(darkText ? Theme.onAccent : .white)
            .clipShape(Capsule())
    }
}

struct LimeCTA: View {
    let title: String
    var icon: String? = nil
    var disabled: Bool = false

    var body: some View {
        HStack(spacing: 8) {
            Text(title)
                .fontWeight(.bold)
            if let icon {
                Image(systemName: icon)
                    .font(.subheadline.weight(.bold))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .foregroundStyle(Theme.onAccent)
        .background(disabled ? Theme.navy : Theme.lime)
        .clipShape(Capsule())
    }
}
