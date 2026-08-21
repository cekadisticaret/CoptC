import SwiftUI

struct PositionsTabView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Pozisyon")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    let positions = appState.home?.positions ?? []
                    Text(positions.isEmpty ? "Açık işlem yok" : "\(positions.count) açık işlem")
                        .font(.subheadline)
                        .foregroundStyle(Theme.mut)
                    if positions.isEmpty {
                        SoftCard(fill: Theme.cream) {
                            Text(appState.home?.live.on == true ? "Şu an açık pozisyon yok" : "Live kapalı — emir açılmıyor")
                                .font(.subheadline)
                                .foregroundStyle(Theme.mut)
                        }
                    } else {
                        ForEach(positions) { PositionCardView(position: $0) }
                    }
                }
                .padding(20)
            }
            .background(Theme.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await appState.refresh() }
        }
    }
}
