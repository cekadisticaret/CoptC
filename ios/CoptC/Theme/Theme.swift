import SwiftUI

enum Theme {
    static let bg = Color(red: 0.965, green: 0.941, blue: 0.890)       // krem
    static let green = Color(red: 0.145, green: 0.365, blue: 0.275)    // orman yeşili
    static let greenSoft = Color(red: 0.82, green: 0.90, blue: 0.84)
    static let cream = Color(red: 0.988, green: 0.965, blue: 0.910)
    static let card = Color.white
    static let ink = Color(red: 0.12, green: 0.18, blue: 0.14)
    static let mut = Color(red: 0.48, green: 0.50, blue: 0.46)
    static let gold = Color(red: 0.82, green: 0.62, blue: 0.22)
    static let red = Color(red: 0.75, green: 0.28, blue: 0.28)
    static let redSoft = Color(red: 0.98, green: 0.91, blue: 0.90)
    static let navy = green
    static let radius: CGFloat = 28

    static func money(_ value: Double?) -> String {
        guard let value else { return "—" }
        let sign = value < 0 ? "-" : ""
        return sign + "$" + String(format: "%.2f", abs(value)).replacingOccurrences(of: ".", with: ",")
    }

    static func pnlColor(_ value: Double?) -> Color {
        guard let value else { return mut }
        if value > 0 { return green }
        if value < 0 { return red }
        return mut
    }

    static func pnlFill(_ value: Double?) -> Color {
        guard let value else { return cream }
        if value > 0 { return greenSoft }
        if value < 0 { return redSoft }
        return cream
    }
}

struct SoftShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: Theme.green.opacity(0.08), radius: 16, x: 0, y: 8)
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
            .background(color.opacity(0.12))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
