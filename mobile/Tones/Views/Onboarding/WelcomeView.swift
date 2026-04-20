import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var authService: AuthService

    private var needsUsername: Bool {
        guard let user = authService.currentUser else { return false }
        return !user.hasUsername
    }

    var body: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            if needsUsername {
                UsernameView()
            } else {
                signedInContent
            }
        }
    }

    private var signedInContent: some View {
        ZStack {
            Color.white
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                VStack(spacing: 20) {
                    Image("TonesLogo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140, height: 140)
                        .clipShape(RoundedRectangle(cornerRadius: 30))

                    Text("Tones")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.yellow.opacity(0.9))

                    Text("Stop Messaging. Start Talking.")
                        .font(.title3)
                        .foregroundStyle(.gray)
                }

                Spacer()

                VStack(spacing: 14) {
                    Button(action: signInWithApple) {
                        HStack {
                            if authService.isLoading {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Image(systemName: "apple.logo")
                                    .font(.headline)
                                Text("Continue with Apple")
                                    .fontWeight(.semibold)
                            }
                        }
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.yellow.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(authService.isLoading)

                    Button(action: signInDemo) {
                        HStack {
                            if authService.isLoading {
                                ProgressView()
                                    .tint(.black)
                            } else {
                                Image(systemName: "person.circle.fill")
                                Text("Try Demo")
                                    .fontWeight(.semibold)
                            }
                        }
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.yellow.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(authService.isLoading)

                    if let error = authService.authError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }

                    if authService.isLoading {
                        Text("Connecting...")
                            .font(.caption)
                            .foregroundStyle(.gray)
                    }

                    Text("by continuing, you create your Tones account")
                        .font(.caption2)
                        .foregroundStyle(.gray.opacity(0.7))
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
        }
    }

    private func signInWithApple() {
        Task {
            do {
                try await authService.signInWithApple()
            } catch {
                authService.authError = error.localizedDescription
            }
        }
    }

    private func signInDemo() {
        Task {
            do {
                try await authService.signInDemo()
            } catch {
                authService.authError = error.localizedDescription
            }
        }
    }
}

struct UsernameView: View {
    @EnvironmentObject var authService: AuthService
    @State private var username = ""
    @State private var usernameError: String?
    @State private var suggestions: [String] = []
    @State private var isChecking = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 24) {
                Text("pick your username")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundStyle(.black)

                Text("this is permanent — friends add you by @username")
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)

                Text("@\(username.isEmpty ? "username" : username)")
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.yellow.opacity(0.9))

                TextField("username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.yellow.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onChange(of: username) { _, newValue in
                        username = newValue.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" }
                        usernameError = nil
                    }
                    .interactiveDismissDisabled(true)

                if let usernameError {
                    Text(usernameError)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                Text("letters, numbers, . _")
                    .font(.caption2)
                    .foregroundStyle(.gray.opacity(0.6))

                if !suggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("suggestions")
                            .font(.caption)
                            .foregroundStyle(.gray)

                        ForEach(suggestions, id: \.self) { suggestion in
                            Button(action: { username = suggestion }) {
                                Text("@\(suggestion)")
                                    .font(.subheadline)
                                    .foregroundStyle(Color.yellow.opacity(0.8))
                            }
                        }
                    }
                }

                Button(action: saveUsername) {
                    HStack {
                        if isChecking {
                            ProgressView()
                                .tint(.black)
                        } else {
                            Text("Claim this username")
                                .fontWeight(.semibold)
                        }
                    }
                    .font(.headline)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(username.count >= 3 ? Color.yellow.opacity(0.85) : Color.gray.opacity(0.3))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .disabled(username.count < 3 || isChecking)

                Text("you cannot change this later")
                    .font(.caption2)
                    .foregroundStyle(.gray.opacity(0.6))

                Spacer()
            }
            .padding(32)
        }
    }

    private func saveUsername() {
        isChecking = true
        usernameError = nil

        Task {
            do {
                try await authService.setUsername(username)
            } catch {
                let message = error.localizedDescription
                if message.contains("taken") {
                    usernameError = "That username is taken"
                } else if message.contains("already set") {
                    usernameError = "You already have a username"
                } else {
                    usernameError = message
                }
            }
            isChecking = false
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AuthService.shared)
}