import SwiftUI
import AuthenticationServices

struct WelcomeView: View {
    @EnvironmentObject var authService: AuthService
    @State private var username = ""
    @State private var errorMessage: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack {
            WarmBackground()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .stroke(Color.warmCoral.opacity(0.12), lineWidth: 1)
                            .frame(width: 200, height: 200)
                        Image("TonesLogo")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 160, height: 160)
                            .scaleEffect(authService.isLoading ? 1.06 : 1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: authService.isLoading)
                    }

                    Text("tones")
                        .font(.system(size: 44, weight: .thin, design: .rounded))
                        .foregroundStyle(Color.warmDark)
                        .tracking(8)

                    Text("talk with your voice")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(Color.warmBrown)
                        .tracking(3)
                }

                Spacer()

                VStack(spacing: 14) {
                    SignInWithAppleButton(.signIn) { req in
                        req.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        Task { await handleAppleResult(result) }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    Text("or")
                        .font(.system(size: 12, weight: .light))
                        .foregroundStyle(Color.warmBrown.opacity(0.5))

                    TextField("pick a username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.system(size: 17, weight: .regular))
                        .foregroundStyle(Color.warmDark)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 15)
                        .padding(.horizontal, 16)
                        .background(Color.white.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .focused($isFocused)
                        .onChange(of: username) { _, newValue in
                            username = newValue.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" }
                            errorMessage = nil
                        }

                    Text("3-20 characters, no password needed")
                        .font(.system(size: 11, weight: .light))
                        .foregroundStyle(Color.warmBrown.opacity(0.6))

                    Button(action: demoSignIn) {
                        HStack {
                            if authService.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("try it")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 17)
                        .background(username.count >= 3 ? Color.warmCoral : Color.warmCoral.opacity(0.4))
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .shadow(color: Color.warmCoral.opacity(username.count >= 3 ? 0.25 : 0), radius: 12, y: 6)
                    }
                    .disabled(username.count < 3 || authService.isLoading)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12, weight: .light))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 44)
            }
        }
        .onAppear {
            authService.registerForPushNotifications()
        }
    }

    @MainActor
    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) async {
        switch result {
        case .success(let authorization):
            do {
                try await authService.completeAppleSignIn(authorization)
            } catch {
                errorMessage = error.localizedDescription
            }
        case .failure(let error):
            let nsError = error as NSError
            if nsError.code != ASAuthorizationError.canceled.rawValue {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func demoSignIn() {
        errorMessage = nil
        Task {
            do {
                try await authService.demoLogin(username)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    NavigationStack {
        WelcomeView()
            .environmentObject(AuthService.shared)
    }
}