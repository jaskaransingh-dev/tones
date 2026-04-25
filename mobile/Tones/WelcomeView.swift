import SwiftUI
import AuthenticationServices
import AVFoundation
import AudioToolbox

struct WelcomeView: View {
    @EnvironmentObject var authService: AuthService
    @State private var errorMessage: String?

    @State private var animationAmount: CGFloat = 1.0
    @State private var haptic: CGFloat = 1.0

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
                            .onAppear {
                                withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                                    animationAmount = 1.02
                                }
                                Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        haptic = 1.015
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            haptic = 1.0
                                        }
                                    }
                                    AudioServicesPlaySystemSound(1519)
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

                VStack(spacing: 0) {
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
            AudioServicesPlaySystemSound(1519)
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

#Preview {
    NavigationStack {
        WelcomeView()
            .environmentObject(AuthService.shared)
    }
}