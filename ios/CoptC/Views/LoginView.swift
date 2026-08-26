import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var appState: AppState
    @State private var password = ""
    @State private var serverURL = APIClient.defaultBaseURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 12) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 52, height: 52)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        Text("CoptC")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.lime)
                    }
                    Text("PUSH")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text("YOUR LIMITS")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.lime)
                    Text("EVERY DAY")
                        .font(.system(size: 36, weight: .heavy, design: .rounded))
                        .foregroundStyle(Theme.ink)
                    Text("Live Control")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.mut)
                }
                .padding(.top, 24)

                SoftCard {
                    VStack(alignment: .leading, spacing: 14) {
                        fieldLabel("Sunucu")
                        TextField("https://deadella.com.tr/admin", text: $serverURL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.URL)
                            .padding(14)
                            .background(Theme.bg)
                            .foregroundStyle(Theme.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                        fieldLabel("Parola")
                        SecureField("Panel parolası", text: $password)
                            .padding(14)
                            .background(Theme.bg)
                            .foregroundStyle(Theme.ink)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                }

                if let err = appState.errorMessage {
                    Text(err).font(.footnote).foregroundStyle(Theme.red)
                }

                Button {
                    Task { await appState.login(password: password, serverURL: serverURL) }
                } label: {
                    HStack {
                        if appState.isLoading { ProgressView().tint(Theme.onAccent) }
                        Text("Giriş yap")
                            .fontWeight(.bold)
                        Image(systemName: "arrow.right")
                            .font(.subheadline.weight(.bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .foregroundStyle(Theme.onAccent)
                    .background(password.isEmpty || appState.isLoading ? Theme.navy : Theme.lime)
                    .clipShape(Capsule())
                }
                .disabled(password.isEmpty || appState.isLoading)
            }
            .padding(24)
        }
        .background(Theme.bg.ignoresSafeArea())
    }

    private func fieldLabel(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.mut)
    }
}
