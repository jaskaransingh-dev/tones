import Foundation
import Combine
import AuthenticationServices

@MainActor
final class AuthService: NSObject, ObservableObject {
    static let shared = AuthService()

    @Published var currentUser: TonesUser?
    @Published var isLoading = false
    @Published var authError: String?

    private let baseURL = URL(string: "https://tones-api-staging.jazing14.workers.dev")!
    private let keychain = KeychainHelper.shared

    override init() {
        super.init()
        Task {
            await restoreSession()
        }
    }

    func signInWithApple() async throws {
        isLoading = true
        authError = nil

        let appleIDProvider = ASAuthorizationAppleIDProvider()
        let request = appleIDProvider.createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func signInDemo() async throws {
        isLoading = true
        authError = nil

        let demoId: String
        if let existingId = keychain.getDemoId() {
            demoId = existingId
        } else {
            demoId = UUID().uuidString.lowercased()
            try keychain.saveDemoId(demoId)
        }

        let url = baseURL.appendingPathComponent("auth/demo")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["demo_id": demoId])

        let (data, resp) = try await URLSession.shared.data(for: req)

        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            if let errorData = try? JSONDecoder().decode(TonesAuthErrorResponse.self, from: data) {
                throw TonesAuthError(message: errorData.error)
            }
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TonesAuthError(message: "Demo login failed: \(body)")
        }

        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
        try saveSession(loginResponse)
        currentUser = loginResponse.user
        isLoading = false
    }

    private func handleAppleAuth(credential: ASAuthorizationAppleIDCredential) async throws {
        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw TonesAuthError(message: "Invalid Apple credential")
        }

        var displayName = "Tones User"
        if let fullName = credential.fullName {
            let parts = [fullName.givenName, fullName.familyName].compactMap { $0 }
            if !parts.isEmpty {
                displayName = parts.joined(separator: " ")
            }
        }

        let url = baseURL.appendingPathComponent("auth/apple")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: String] = ["apple_token": tokenString, "display_name": displayName]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)

        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            if let errorData = try? JSONDecoder().decode(TonesAuthErrorResponse.self, from: data) {
                throw TonesAuthError(message: errorData.error)
            }
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TonesAuthError(message: "Login failed: \(body)")
        }

        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
        try saveSession(loginResponse)
        currentUser = loginResponse.user
    }

    func setUsername(_ username: String) async throws {
        guard let token = keychain.getAccessToken() else {
            throw TonesAuthError(message: "Not authenticated")
        }

        let url = baseURL.appendingPathComponent("auth/username")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["username": username])

        let (data, resp) = try await URLSession.shared.data(for: req)

        guard let http = resp as? HTTPURLResponse else {
            throw TonesAuthError(message: "Request failed")
        }

        if http.statusCode == 403 {
            throw TonesAuthError(message: "Username already set and cannot be changed")
        }

        if http.statusCode == 409 {
            let errorResponse = try JSONDecoder().decode(TonesAuthErrorResponse.self, from: data)
            throw TonesAuthError(message: errorResponse.error, suggestions: errorResponse.suggestions)
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TonesAuthError(message: "Failed to set username: \(body)")
        }

        if let responseDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let newUsername = responseDict["username"] as? String {
            currentUser?.username = newUsername
            currentUser?.displayName = "@" + newUsername
        }
    }

    func refreshSession() async throws {
        guard let refreshToken = keychain.getRefreshToken() else {
            return
        }

        let url = baseURL.appendingPathComponent("auth/refresh")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["refresh_token": refreshToken])

        let (data, resp) = try await URLSession.shared.data(for: req)

        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            keychain.clear()
            currentUser = nil
            return
        }

        let tokens = try JSONDecoder().decode(TonesSession.self, from: data)
        try keychain.saveSession(tokens)
        APIClient.shared.setAuthToken(tokens.accessToken)
    }

    func registerDevice(pushToken: String) async throws {
        guard let token = keychain.getAccessToken() else { return }

        let url = baseURL.appendingPathComponent("devices/register")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        req.httpBody = try JSONEncoder().encode(["push_token": pushToken, "push_provider": "apns"])

        _ = try await URLSession.shared.data(for: req)
    }

    func logout() {
        keychain.clearAll()
        currentUser = nil
    }

    private func saveSession(_ response: LoginResponse) throws {
        let session = TonesSession(accessToken: response.accessToken, refreshToken: response.refreshToken)
        try keychain.saveSession(session)
        APIClient.shared.setAuthToken(response.accessToken)
    }

    private func restoreSession() async {
        guard let token = keychain.getAccessToken() else { return }

        APIClient.shared.setAuthToken(token)

        do {
            let url = baseURL.appendingPathComponent("auth/me")
            var req = URLRequest(url: url)
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            let (data, resp) = try await URLSession.shared.data(for: req)

            guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                try await refreshSession()
                return
            }

            currentUser = try JSONDecoder().decode(TonesUser.self, from: data)
        } catch {
            print("Restore session failed: \(error)")
        }
    }
}

extension AuthService: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            Task { @MainActor in
                self.authError = "Invalid credential"
                self.isLoading = false
            }
            return
        }

        Task { @MainActor in
            do {
                try await self.handleAppleAuth(credential: credential)
                self.isLoading = false
            } catch {
                self.authError = error.localizedDescription
                self.isLoading = false
            }
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        Task { @MainActor in
            let asError = error as NSError
            if asError.code == ASAuthorizationError.canceled.rawValue {
                self.isLoading = false
            } else {
                self.authError = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

extension AuthService: ASAuthorizationControllerPresentationContextProviding {
    @MainActor func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = scene.windows.first else {
            return UIWindow()
        }
        return window
    }
}