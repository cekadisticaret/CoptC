import SwiftUI

struct LiveView: View {
    @EnvironmentObject private var appState: AppState

    private var kasalar: [KasaCard] { appState.kasaFeed?.books ?? [] }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    if let err = appState.liveError {
                        Text(err).font(.footnote).foregroundStyle(Theme.red)
                    }
                    if kasalar.isEmpty {
                        SoftCard {
                            Text(appState.isLoading ? "Kasalar yükleniyor…" : "Kasa verisi yok")
                                .foregroundStyle(Theme.mut)
                        }
                    } else {
                        VStack(spacing: 12) {
                            ForEach(kasalar) { row in
                                NavigationLink {
                                    KasaDetailView(kasa: row)
                                } label: {
                                    KasaVaultCard(row: row)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(16)
                .padding(.bottom, 24)
            }
            .background(Theme.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .refreshable { await appState.refreshLive() }
            .task { await appState.refreshLive(silent: true) }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Forex")
                    .font(.system(size: 28, weight: .heavy, design: .rounded))
                    .foregroundStyle(Theme.ink)
                Text("kasa")
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .foregroundStyle(Theme.onAccent)
                    .background(Color(red: 0.83, green: 0.69, blue: 0.22))
                    .clipShape(Capsule())
                Spacer()
                if appState.isLoading { ProgressView().tint(Theme.lime) }
            }
            Text(appState.kasaFeed?.subtitle ?? "Dört sanal Isolated kasa · anlık bakiye")
                .font(.subheadline)
                .foregroundStyle(Theme.mut)
        }
    }
}
