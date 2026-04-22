import SwiftUI

struct SetUsernameView: View {
    @EnvironmentObject var authService: AuthService
    @State private var username = ""
    @State private var errorMessage: String?
    @State private var suggestions: [String]?
    @State private var isSubmitting = false
    @FocusState private var isFocused: Bool

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
                    Text("pick a username")
                        .font(.system(size: 28, weight: .thin))
                        .foregroundStyle(Color.warmDark)
                        .tracking(2)

                    Text("this is how others find you on tones")
                        .font(.system(size: 14, weight: .light))
                        .foregroundStyle(Color.warmBrown)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 16) {
                    TextField("@username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.title3)
                        .foregroundStyle(Color.warmDark)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.white.opacity(0.85))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .focused($isFocused)
                        .onChange(of: username) { _, newValue in
                            username = newValue.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" }
                            errorMessage = nil
                            suggestions = nil
                        }

                    Text("3-20 characters: letters, numbers, . _")
                        .font(.system(size: 11, weight: .light))
                        .foregroundStyle(Color.warmBrown.opacity(0.8))

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    if let suggestions, !suggestions.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(suggestions, id: \.self) { suggestion in
                                    Button(action: { username = suggestion }) {
                                        Text("@\(suggestion)")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(Color.warmCoral)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(Color.warmCoral.opacity(0.1))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                    }
                                }
                            }
                        }
                    }

                    Button(action: submitUsername) {
                        HStack {
                            if isSubmitting {
                                ProgressView().tint(.white)
                            } else {
                                Text("continue")
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
                    .disabled(username.count < 3 || isSubmitting)

                    Button(action: { authService.logout() }) {
                        Text("sign out")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Color.warmBrown.opacity(0.6))
                    }
                    .padding(.top, 4)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
        }
        .onAppear {
            isFocused = true
        }
    }

    private func submitUsername() {
        errorMessage = nil
        suggestions = nil
        isSubmitting = true
        Task {
            do {
                try await authService.setUsername(username)
            } catch let error as TonesAuthError {
                errorMessage = error.message
                suggestions = error.suggestions
            } catch {
                errorMessage = error.localizedDescription
            }
            isSubmitting = false
        }
    }
}

#Preview {
    NavigationStack {
        SetUsernameView()
            .environmentObject(AuthService.shared)
    }
}