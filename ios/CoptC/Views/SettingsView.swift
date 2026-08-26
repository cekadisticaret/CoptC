import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var low = ""
    @State private var mid = ""
    @State private var high = ""
    @State private var saved = false
    @State private var cemapiPassword = ""

    var body: some View {
        NavigationStack {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                Text("Profil")
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.ink)
                liveCard

                Text("Giriş tutarları")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.ink)
                Text("Sembol win rate'e göre kademe seçilir.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.mut)

                SoftCard {
                    VStack(alignment: .leading, spacing: 14) {
                        amountField(appState.settings?.labels.low ?? "Low", text: $low)
                        amountField(appState.settings?.labels.mid ?? "Mid", text: $mid)
                        amountField(appState.settings?.labels.high ?? "High", text: $high)
                    }
                }

                if let err = appState.errorMessage {
                    Text(err).font(.footnote).foregroundStyle(Theme.red)
                }
                if saved {
                    Text("Kaydedildi").font(.footnote).foregroundStyle(Theme.lime)
                }

                Button {
                    Task { await save() }
                } label: {
                    LimeCTA(title: "Tutarları kaydet", disabled: appState.isLoading)
                }
                .disabled(appState.isLoading)

                SoftCard {
                    SourcesPickerCard()
                }

                SoftCard {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CEMAPI parola")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.mut)
                        Text("Boş bırakırsan CoptC parolası kullanılır. Panele girilemiyorsa buraya CEMAPI panel parolasını yaz.")
                            .font(.caption)
                            .foregroundStyle(Theme.mut)
                        SecureField("CEMAPI panel parolası", text: $cemapiPassword)
                            .padding(14)
                            .background(Theme.bg)
                            .foregroundStyle(Theme.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        Button {
                            Task {
                                await appState.saveCemapiPassword(cemapiPassword)
                                saved = true
                            }
                        } label: {
                            LimeCTA(title: "CEMAPI parolasını kaydet")
                        }
                    }
                }

                Button {
                    Task { await appState.logout() }
                } label: {
                    Text("Çıkış yap")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .foregroundStyle(Theme.red)
                }
            }
            .padding(20)
        }
        .background(Theme.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await appState.loadSettings()
            if let a = appState.settings?.amounts {
                low = String(a.low)
                mid = String(a.mid)
                high = String(a.high)
            }
            cemapiPassword = KeychainHelper.load(key: "cemapiPassword") ?? ""
        }
        }
    }

    private var liveOn: Bool { appState.home?.live.on == true }

    private var liveCard: some View {
        SoftCard {
            VStack(alignment: .leading, spacing: 12) {
                Text("Live")
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                Text(liveOn ? "Açık — sonraki slotta PM emri gider." : "Kapalı — cron çalışır, emir basılmaz.")
                    .font(.caption)
                    .foregroundStyle(Theme.mut)
                HStack(spacing: 10) {
                    Button {
                        Task { if !liveOn { await appState.toggleLive() } }
                    } label: {
                        Text("Live aç")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(liveOn ? Theme.onAccent : Theme.ink)
                            .background(liveOn ? Theme.lime : Theme.navy)
                            .clipShape(Capsule())
                    }
                    .disabled(appState.isLoading || appState.home == nil || liveOn)
                    Button {
                        Task { if liveOn { await appState.toggleLive() } }
                    } label: {
                        Text("Live kapat")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .foregroundStyle(.white)
                            .background(liveOn ? Theme.red : Theme.navy)
                            .clipShape(Capsule())
                    }
                    .disabled(appState.isLoading || appState.home == nil || !liveOn)
                }
            }
        }
    }

    private func amountField(_ title: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.mut)
            TextField("0.00", text: text)
                .keyboardType(.decimalPad)
                .padding(14)
                .background(Theme.bg)
                .foregroundStyle(Theme.ink)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    private func save() async {
        saved = false
        let lo = Double(low.replacingOccurrences(of: ",", with: ".")) ?? 0
        let mi = Double(mid.replacingOccurrences(of: ",", with: ".")) ?? 0
        let hi = Double(high.replacingOccurrences(of: ",", with: ".")) ?? 0
        saved = await appState.saveAmounts(low: lo, mid: mi, high: hi)
    }
}
