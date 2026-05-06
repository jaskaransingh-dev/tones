import SwiftUI
import AuthenticationServices

struct WelcomeView: View {
    @EnvironmentObject var authService: AuthService
    @State private var errorMessage: String?

    @State private var animationAmount: CGFloat = 1.0
    @State private var haptic: CGFloat = 1.0
    @State private var pulseTimer: Timer?
    @State private var demoTapCount = 0
    @State private var showDemoSheet = false

    var body: some View {
        ZStack {
            WarmBackground()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 14) {
                    ZStack {
                        Image("TonesLogo")
                            .resizable()
                            .scaledToFill()
                            .frame(width: 70, height: 70)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.warmCoral.opacity(0.3), lineWidth: 1)
                            )
                            .scaleEffect(animationAmount * haptic)
                            .onTapGesture {
                                demoTapCount += 1
                                if demoTapCount >= 5 {
                                    demoTapCount = 0
                                    showDemoSheet = true
                                }
                            }
                            .onAppear {
                                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                                    animationAmount = 1.02
                                }
                                pulseTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        haptic = 1.015
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            haptic = 1.0
                                        }
                                    }
                                }
                            }
                    }

                    Text("tones")
                        .font(.system(size: 44, weight: .thin, design: .rounded))
                        .foregroundStyle(Color.warmDark)
                        .tracking(8)

                    Text("voice messages, nothing else")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Color.warmBrown.opacity(0.85))
                        .tracking(2)
                }

                Spacer()

                VStack(spacing: 16) {
                    SignInWithAppleButton(.signIn) { req in
                        req.requestedScopes = [.fullName, .email]
                    } onCompletion: { result in
                        Task { await handleAppleResult(result) }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

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
        .onDisappear {
            pulseTimer?.invalidate()
            pulseTimer = nil
        }
        .sheet(isPresented: $showDemoSheet) {
            DemoLoginSheet()
                .environmentObject(authService)
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
}

struct DemoLoginSheet: View {
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var username = "appreview"
    @State private var error: String?
    @State private var isSigningIn = false

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackground()
                VStack(spacing: 24) {
                    Text("App Review Demo")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundStyle(Color.warmDark)
                    Text("Sign in with a demo username for App Store review.")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Color.warmBrown)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    TextField("username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.white.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 24)

                    if let error {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }

                    Button(action: signIn) {
                        HStack {
                            if isSigningIn {
                                ProgressView().tint(.white)
                            } else {
                                Text("sign in")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(username.count >= 3 ? Color.warmCoral : Color.warmCoral.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(username.count < 3 || isSigningIn)
                    .padding(.horizontal, 24)

                    Spacer()
                }
                .padding(.top, 40)
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close") { dismiss() }
                        .foregroundStyle(Color.warmBrown)
                }
            }
        }
    }

    private func signIn() {
        isSigningIn = true
        error = nil
        Task {
            do {
                try await authService.signInWithDemoUsername(username)
                dismiss()
            } catch let e as TonesAuthError {
                error = e.message
            } catch {
                self.error = error.localizedDescription
            }
            isSigningIn = false
        }
    }
}

#Preview {
    NavigationStack {
        WelcomeView()
            .environmentObject(AuthService.shared)
    }
}
