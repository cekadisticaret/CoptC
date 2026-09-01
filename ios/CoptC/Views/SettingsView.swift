import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var cemapiPassword = ""
    @State private var saved = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Profil")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.ink)

                    NavigationLink {
                        SettingsDetailView()
                    } label: {
                        HStack {
                            Text("Ayarlar")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(Theme.ink)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.mut)
                        }
                        .padding(16)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    }
                    .buttonStyle(.plain)

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
                            if saved {
                                Text("Kaydedildi").font(.footnote).foregroundStyle(Theme.lime)
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
            .task { cemapiPassword = KeychainHelper.load(key: "cemapiPassword") ?? "" }
        }
    }
}

struct SettingsDetailView: View {
    @EnvironmentObject private var appState: AppState
    @State private var low = ""
    @State private var mid = ""
    @State private var high = ""
    @State private var minProfit = ""
    @State private var saved = false

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 18) {
                SoftCard {
                    SourcesPickerCard()
                }

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

                Text("Asgari kâr — tüm API")
                    .font(.title3.bold())
                    .foregroundStyle(Theme.ink)
                Text(minProfitHint)
                    .font(.subheadline)
                    .foregroundStyle(Theme.mut)
                SoftCard {
                    amountField("Kâr eşiği (%)", text: $minProfit)
                }

                if let err = appState.coptcError {
                    Text(err).font(.footnote).foregroundStyle(Theme.red)
                }
                if saved {
                    Text("Kaydedildi").font(.footnote).foregroundStyle(Theme.lime)
                }

                Button {
                    Task { await save() }
                } label: {
                    LimeCTA(title: "Ayarları kaydet", disabled: appState.isLoading)
                }
                .disabled(appState.isLoading)
            }
            .padding(20)
        }
        .background(Theme.bg.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("Ayarlar")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(Theme.ink)
            }
        }
        .toolbarBackground(Theme.bg, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .task {
            await appState.loadSettings()
            if let a = appState.settings?.amounts {
                low = String(a.low)
                mid = String(a.mid)
                high = String(a.high)
            }
            if let p = appState.settings?.minProfitPct {
                minProfit = String(format: "%.0f", p)
            } else if minProfit.isEmpty {
                minProfit = "56"
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
        let mp = Double(minProfit.replacingOccurrences(of: ",", with: ".")) ?? 56
        saved = await appState.saveAmounts(low: lo, mid: mi, high: hi, minProfitPct: mp)
    }

    private var minProfitHint: String {
        let pct = Double(minProfit.replacingOccurrences(of: ",", with: ".")) ?? 56
        if pct <= 0 { return "Eşik kapalı — token fiyatına bakılmaz." }
        let cap = 1.0 / (1.0 + pct / 100.0)
        return String(
            format: "Kazanınca kâr, harcananın %%%.0f altındaysa işlem açılmaz — token en fazla %.3f.",
            pct, cap
        )
    }
}
