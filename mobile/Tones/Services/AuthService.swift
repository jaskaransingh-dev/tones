import Foundation
import Combine
import AuthenticationServices
import UIKit
import UserNotifications

@MainActor
final class AuthService: ObservableObject {
    static let shared = AuthService()

    @Published var currentUser: TonesUser?
    @Published var isLoading = false
    @Published var authError: String?

    private let baseURL = URL(string: "https://tones-api-prod.jazing14.workers.dev")!
    private let keychain = KeychainHelper.shared

    init() {
        Task { await restoreSession() }
    }

    func completeAppleSignIn(_ authorization: ASAuthorization) async throws {
        isLoading = true
        authError = nil
        defer { isLoading = false }

        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            throw TonesAuthError(message: "Invalid Apple credential")
        }

        guard let identityToken = credential.identityToken,
              let tokenString = String(data: identityToken, encoding: .utf8) else {
            throw TonesAuthError(message: "Invalid Apple token")
        }

        let url = baseURL.appendingPathComponent("auth/apple")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["apple_token": tokenString])

        let (data, resp) = try await URLSession.shared.data(for: req)

        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TonesAuthError(message: "Login failed: \(body)")
        }

        let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
        try saveSession(loginResponse)
        currentUser = loginResponse.user
    }

    func demoLogin(_ username: String) async throws {
        isLoading = true
        authError = nil
        defer { isLoading = false }

        let cleaned = username.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" }
        guard cleaned.count >= 3 else {
            throw TonesAuthError(message: "Username must be at least 3 characters")
        }

        let url = baseURL.appendingPathComponent("auth/demo")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["username": cleaned])

        let (data, resp) = try await URLSession.shared.data(for: req)

        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            if let errorData = try? JSONDecoder().decode(TonesAuthErrorResponse.self, from: data) {
                throw TonesAuthError(message: errorData.error)
            }
            throw TonesAuthError(message: "Login failed")
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
            throw TonesAuthError(message: "Username already set")
        }

        if http.statusCode == 409 {
            let errorResponse = try JSONDecoder().decode(TonesAuthErrorResponse.self, from: data)
            throw TonesAuthError(message: errorResponse.error, suggestions: errorResponse.suggestions)
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw TonesAuthError(message: "Failed: \(body)")
        }

        if let responseDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let newUsername = responseDict["username"] as? String {
            currentUser?.username = newUsername
        }
    }

    func registerForPushNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    func refreshSession() async throws {
        guard let refreshToken = keychain.getRefreshToken() else { return }

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

    func logout() {
        keychain.clear()
        LocalStorage.shared.clearAll()
        APIClient.shared.clearAuthToken()
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