import Foundation

final class APIClient {
    static let shared = APIClient()

    private let baseURL: URL
    private let session: URLSession
    private var authToken: String?

    init(baseURL: URL = URL(string: "https://tones-api-prod.jazing14.workers.dev")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func setAuthToken(_ token: String) {
        self.authToken = token
    }

    func clearAuthToken() {
        self.authToken = nil
    }

    private func authedReq(_ url: URL) -> URLRequest {
        var req = URLRequest(url: url)
        if let token = authToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    func listChats() async throws -> [RemoteChat] {
        let url = baseURL.appendingPathComponent("chats")
        var req = authedReq(url)
        let (data, resp) = try await session.data(for: req)
        try validate(resp: resp, data: data)
        return try JSONDecoder().decode([RemoteChat].self, from: data)
    }

    func createDM(friendId: String) async throws -> String {
        let url = baseURL.appendingPathComponent("chats/dm")
        var req = authedReq(url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(CreateDMRequest(friend_id: friendId))

        let (data, resp) = try await session.data(for: req)
        try validate(resp: resp, data: data)

        let result = try JSONDecoder().decode(CreateDMResponse.self, from: data)
        return result.id
    }

    func listMessages(chatId: String, since: Int) async throws -> [RemoteMessage] {
        var components = URLComponents(url: baseURL.appendingPathComponent("chats/\(chatId)/messages"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "since", value: String(since))]
        let url = components.url!
        var req = authedReq(url)
        let (data, resp) = try await session.data(for: req)
        try validate(resp: resp, data: data)
        return try JSONDecoder().decode([RemoteMessage].self, from: data)
    }

    func sendAudioMessage(chatId: String, messageId: String, audioBase64: String, durationMs: Int) async throws -> SendMessageResult {
        let url = baseURL.appendingPathComponent("chats/\(chatId)/messages")
        var req = authedReq(url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["id": messageId, "audio_base64": audioBase64, "duration_ms": durationMs]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await session.data(for: req)
        try validate(resp: resp, data: data)
        return try JSONDecoder().decode(SendMessageResult.self, from: data)
    }

    func searchUsers(query: String) async throws -> [TonesUser] {
        var components = URLComponents(url: baseURL.appendingPathComponent("users/search"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        let url = components.url!
        var req = authedReq(url)
        let (data, resp) = try await session.data(for: req)
        try validate(resp: resp, data: data)
        return try JSONDecoder().decode([TonesUser].self, from: data)
    }

    func listFriends() async throws -> [TonesUser] {
        let url = baseURL.appendingPathComponent("friends")
        var req = authedReq(url)
        let (data, resp) = try await session.data(for: req)
        try validate(resp: resp, data: data)
        return try JSONDecoder().decode([TonesUser].self, from: data)
    }

    func addFriend(friendId: String) async throws {
        let url = baseURL.appendingPathComponent("friends/add")
        var req = authedReq(url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(AddFriendRequest(friend_id: friendId))

        let (_, resp) = try await session.data(for: req)
        try validate(resp: resp, data: Data())
    }

    func registerPushToken(_ pushToken: String, platform: String = "ios") async throws {
        let url = baseURL.appendingPathComponent("auth/push-token")
        var req = authedReq(url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["push_token": pushToken, "platform": platform])

        let (_, resp) = try await session.data(for: req)
        try validate(resp: resp, data: Data())
    }

    private func validate(resp: URLResponse, data: Data) throws {
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "Unknown error"
            
            // Try to parse JSON error response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let errorMsg = json["error"] as? String {
                throw TonesAuthError(message: errorMsg)
            }
            
            let statusCode = (resp as? HTTPURLResponse)?.statusCode ?? -1
            throw NSError(domain: "APIClient", code: statusCode, userInfo: [NSLocalizedDescriptionKey: body])
        }
    }
}