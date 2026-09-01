import SwiftUI

struct PositionsTabView: View {
    @EnvironmentObject private var appState: AppState

    private var positions: [Position] { appState.home?.positions ?? [] }
    private var waitingHome: Bool { appState.home == nil && appState.errorMessage == nil }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("Pozisyon")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                if waitingHome {
                    Text("Açık işlemler yükleniyor")
                        .font(.subheadline)
                        .foregroundStyle(Theme.mut)
                } else {
                    Text(positions.isEmpty ? "Açık işlem yok" : "\(positions.count) açık işlem")
                        .font(.subheadline)
                        .foregroundStyle(Theme.mut)
                }

                if let err = appState.errorMessage, appState.home == nil {
                    Text(err)
                        .font(.footnote)
                        .foregroundStyle(Theme.red)
                }

                if waitingHome {
                    Spacer(minLength: 20)
                    LoadingPanel(
                        title: "Yükleniyor",
                        subtitle: "Açık pozisyonlar sunucudan geliyor"
                    )
                    Spacer()
                } else if positions.isEmpty {
                    Spacer(minLength: 20)
                    EmptyPositionsArt(liveOn: appState.home?.live.on == true)
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 12) {
                            ForEach(positions) { PositionCardView(position: $0) }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Theme.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await appState.refresh() }
            .task {
                if appState.home == nil {
                    await appState.refresh()
                }
            }
        }
    }
}
