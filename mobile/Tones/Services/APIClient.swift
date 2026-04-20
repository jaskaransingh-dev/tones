import Foundation

final class APIClient {
    static let shared = APIClient()

    private let baseURL: URL
    private let session: URLSession
    private var authToken: String?

    init(baseURL: URL = URL(string: "https://tones-api-staging.jazing14.workers.dev")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func setAuthToken(_ token: String) {
        self.authToken = token
    }

    private func authedReq(_ url: URL) -> URLRequest {
        var req = URLRequest(url: url)
        if let token = authToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return req
    }

    func listChats() async throws -> [ChatListItem] {
        let url = baseURL.appendingPathComponent("chats")
        var req = authedReq(url)
        let (data, resp) = try await session.data(for: req)
        try validate(resp: resp, data: data)
        return try JSONDecoder().decode([ChatListItem].self, from: data)
    }

    func createDM(friendId: String) async throws -> String {
        let url = baseURL.appendingPathComponent("chats/dm")
        var req = authedReq(url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(CreateDMRequest(friend_id: friendId))

        let (data, resp) = try await session.data(for: req)
        try validate(resp: resp, data: data)

        let result = try JSONDecoder().decode(ChatOpenResponse.self, from: data)
        return result.message?.uuid?.uuidString ?? ""
    }

    func createGroup(title: String, memberIds: [String]) async throws -> String {
        let url = baseURL.appendingPathComponent("chats/group")
        var req = authedReq(url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(CreateGroupRequest(title: title, member_ids: memberIds))

        let (data, resp) = try await session.data(for: req)
        try validate(resp: resp, data: data)

        let result = try JSONDecoder().decode(ChatOpenResponse.self, from: data)
        return result.message?.uuid?.uuidString ?? ""
    }

    func openChat(chatId: String) async throws -> ChatOpenResponse {
        let url = baseURL.appendingPathComponent("chats/\(chatId)/open")
        var req = authedReq(url)
        let (data, resp) = try await session.data(for: req)
        try validate(resp: resp, data: data)
        return try JSONDecoder().decode(ChatOpenResponse.self, from: data)
    }

    func getUploadURL(chatId: String, durationMs: Int) async throws -> UploadURLResponse {
        let url = baseURL.appendingPathComponent("messages/upload-url")
        var req = authedReq(url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(UploadURLRequest(chat_id: chatId, duration_ms: durationMs))

        let (data, resp) = try await session.data(for: req)
        try validate(resp: resp, data: data)
        return try JSONDecoder().decode(UploadURLResponse.self, from: data)
    }

    func sendMessage(chatId: String, r2Key: String, durationMs: Int) async throws -> String {
        let url = baseURL.appendingPathComponent("messages/send")
        var req = authedReq(url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(SendMessageRequest(chat_id: chatId, r2_key: r2Key, duration_ms: durationMs))

        let (data, resp) = try await session.data(for: req)
        try validate(resp: resp, data: data)

        let result = try JSONDecoder().decode(MessageSendResponse.self, from: data)
        return result.id
    }

    func markPlayed(messageId: String) async throws {
        let url = baseURL.appendingPathComponent("messages/\(messageId)/played")
        var req = authedReq(url)
        req.httpMethod = "POST"
        let (_, resp) = try await session.data(for: req)
        try validate(resp: resp, data: Data())
    }

    func searchUsers(query: String) async throws -> [TonesUser] {
        let url = baseURL.appendingPathComponent("users/search?q=\(query)")
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

    private func validate(resp: URLResponse, data: Data) throws {
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "APIClient", code: (resp as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: body])
        }
    }
}