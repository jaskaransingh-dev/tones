import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject var authService: AuthService
    @State private var showUsernamePicker = false

    var body: some View {
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
            .onChange(of: authService.currentUser?.hasUsername) { _, hasUsername in
                let hasUser = authService.currentUser != nil
                showUsernamePicker = hasUsername == false && hasUser
            }

            if showUsernamePicker {
                UsernameView(showing: $showUsernamePicker)
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
    @Binding var showing: Bool
    @State private var username = ""
    @State private var error: String?
    @State private var suggestions: [String] = []
    @State private var isChecking = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 28) {
                Text("choose your username")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.black)

                Text("@username")
                    .foregroundStyle(.gray)

                TextField("username", text: $username)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.title3)
                    .multilineTextAlignment(.center)
                    .padding()
                    .background(Color.yellow.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onChange(of: username) { _, newValue in
                        username = newValue.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
                        error = nil
                    }

                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

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
                            Text("Continue")
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

                Spacer()
            }
            .padding(32)
        }
    }

    private func saveUsername() {
        isChecking = true
        error = nil

        Task {
            do {
                try await authService.setUsername(username)
                if authService.currentUser?.hasUsername == true {
                    showing = false
                }
            } catch let nsError as NSError {
                if let sugg = nsError.userInfo["suggestions"] as? [String] {
                    suggestions = sugg
                }
                error = nsError.localizedDescription
            }
            isChecking = false
        }
    }
}

#Preview {
    WelcomeView()
        .environmentObject(AuthService.shared)
}