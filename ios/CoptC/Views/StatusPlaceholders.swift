import SwiftUI

struct LimeSpinner: View {
    @State private var spin = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.lime.opacity(0.14), lineWidth: 4)
            Circle()
                .trim(from: 0.08, to: 0.72)
                .stroke(Theme.lime, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(spin ? 360 : 0))
        }
        .frame(width: 56, height: 56)
        .onAppear {
            withAnimation(.linear(duration: 0.85).repeatForever(autoreverses: false)) {
                spin = true
            }
        }
    }
}

struct LoadingPanel: View {
    var title: String = "Yükleniyor"
    var subtitle: String = "Veriler API’den çekiliyor"

    @State private var pulse = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Theme.lime.opacity(0.10))
                    .frame(width: 124, height: 124)
                    .scaleEffect(pulse ? 1.08 : 0.92)
                Circle()
                    .stroke(Theme.lime.opacity(0.22), lineWidth: 1)
                    .frame(width: 96, height: 96)
                LimeSpinner()
            }
            Text(title)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.ink)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Theme.mut)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.15).repeatForever(autoreverses: true)) {
                pulse = true
            }
        }
    }
}

struct EmptyPositionsArt: View {
    var liveOn: Bool

    @State private var glow = false

    var body: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Theme.lime.opacity(glow ? 0.14 : 0.06))
                    .frame(width: 168, height: 168)
                Circle()
                    .stroke(Theme.lime.opacity(0.18), lineWidth: 1)
                    .frame(width: 132, height: 132)
                Circle()
                    .fill(Theme.card)
                    .frame(width: 104, height: 104)
                    .overlay {
                        Circle().stroke(Color.white.opacity(0.06), lineWidth: 1)
                    }
                Image(systemName: "chart.pie.fill")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(Theme.lime)
                    .offset(x: -2, y: 2)
                Capsule()
                    .fill(Theme.ink)
                    .frame(width: 6, height: 62)
                    .rotationEffect(.degrees(-32))
            }
            VStack(spacing: 8) {
                Text("Pozisyon yok")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text(liveOn ? "Şu an açık işlem yok.\nYeni emir gelince burada görünür." : "Live kapalı — emir açılmıyor.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.mut)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Text(liveOn ? "düz" : "live off")
                .font(.caption.weight(.bold))
                .foregroundStyle(liveOn ? Theme.onAccent : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(liveOn ? Theme.lime : Theme.navy)
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 24)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}
