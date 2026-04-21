import SwiftUI
import AuthenticationServices

struct WelcomeView: View {
    @EnvironmentObject var authService: AuthService
    @State private var errorMessage: String?

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
                        Circle()
                            .fill(Color.warmPeach.opacity(0.85))
                            .frame(width: 130, height: 130)
                            .scaleEffect(authService.isLoading ? 1.06 : 1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: authService.isLoading)
                        Image(systemName: "waveform")
                            .font(.system(size: 46, weight: .ultraLight))
                            .foregroundStyle(Color.warmCoral)
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

                    HStack(spacing: 24) {
                        NavigationLink(destination: LoginView()) {
                            Text("sign in")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.warmBrown)
                        }

                        Circle()
                            .fill(Color.warmBrown.opacity(0.3))
                            .frame(width: 4, height: 4)

                        NavigationLink(destination: CreateAccountView()) {
                            Text("create account")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.warmCoral)
                        }
                    }
                    .padding(.top, 4)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 12, weight: .light))
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.top, 4)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 44)
            }
        }
    }

    @MainActor
    private func handleAppleResult(_ result: Result<ASAuthorization, Error>) async {
        errorMessage = nil
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
}

struct LoginView: View {
    @EnvironmentObject var authService: AuthService
    @State private var username = ""
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            WarmBackground()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.warmPeach.opacity(0.6))
                            .frame(width: 100, height: 100)
                        Image(systemName: "person.circle")
                            .font(.system(size: 36, weight: .ultraLight))
                            .foregroundStyle(Color.warmCoral)
                    }
                    Text("welcome back")
                        .font(.system(size: 28, weight: .thin))
                        .foregroundStyle(Color.warmDark)
                        .tracking(2)
                }

                Spacer()

                VStack(spacing: 16) {
                    TextField("username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.white.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .onChange(of: username) { _, newValue in
                            username = newValue.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" }
                            errorMessage = nil
                        }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button(action: signIn) {
                        HStack {
                            if authService.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("sign in")
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
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
        }
        .navigationTitle("")
    }

    private func signIn() {
        errorMessage = nil
        Task {
            do {
                try await authService.loginByUsername(username)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

struct CreateAccountView: View {
    @EnvironmentObject var authService: AuthService
    @State private var username = ""
    @State private var displayName = ""
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            WarmBackground()

            VStack(spacing: 28) {
                Spacer()

                VStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.warmPeach.opacity(0.6))
                            .frame(width: 100, height: 100)
                        Image(systemName: "person.badge.plus")
                            .font(.system(size: 36, weight: .ultraLight))
                            .foregroundStyle(Color.warmCoral)
                    }
                    Text("create account")
                        .font(.system(size: 28, weight: .thin))
                        .foregroundStyle(Color.warmDark)
                        .tracking(2)
                }

                Spacer()

                VStack(spacing: 16) {
                    TextField("display name", text: $displayName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.white.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    TextField("@username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.white.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .onChange(of: username) { _, newValue in
                            username = newValue.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" }
                            errorMessage = nil
                        }

                    Text("3-20 characters: letters, numbers, . _")
                        .font(.system(size: 11, weight: .light))
                        .foregroundStyle(Color.warmBrown.opacity(0.8))

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button(action: createAccount) {
                        HStack {
                            if authService.isLoading {
                                ProgressView().tint(.white)
                            } else {
                                Text("create")
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
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
        }
        .navigationTitle("")
    }

    private func createAccount() {
        errorMessage = nil
        Task {
            do {
                let name = displayName.trimmingCharacters(in: .whitespaces).isEmpty ? nil : displayName.trimmingCharacters(in: .whitespaces)
                try await authService.registerByUsername(username, displayName: name)
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