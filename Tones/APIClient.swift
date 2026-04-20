import Foundation

actor APIClient {
    static let shared = APIClient()

    private let baseURL: URL
    private let session: URLSession

    init(baseURL: URL = URL(string: "https://your-pages-domain.pages.dev")!, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    func registerUser(handle: String) async throws -> User {
        let url = baseURL.appendingPathComponent("api/register")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["handle": handle])
        let (data, resp) = try await session.data(for: req)
        try validate(resp: resp, data: data)
        return try JSONDecoder().decode(User.self, from: data)
    }

    func searchOrCreateChat(name: String, memberIds: [String]) async throws -> Chat {
        let url = baseURL.appendingPathComponent("api/chat")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["name": name, "memberIds": memberIds])
        let (data, resp) = try await session.data(for: req)
        try validate(resp: resp, data: data)
        return try JSONDecoder().decode(Chat.self, from: data)
    }

    func listChats(userId: String) async throws -> [Chat] {
        let url = baseURL.appendingPathComponent("api/chats").appending(queryItems: [URLQueryItem(name: "userId", value: userId)])
        let (data, resp) = try await session.data(from: url)
        try validate(resp: resp, data: data)
        return try JSONDecoder().decode([Chat].self, from: data)
    }

    func latestTune(chatId: String) async throws -> TuneMessage? {
        let url = baseURL.appendingPathComponent("api/latest").appending(queryItems: [URLQueryItem(name: "chatId", value: chatId)])
        let (data, resp) = try await session.data(from: url)
        try validate(resp: resp, data: data)
        return try JSONDecoder().decode(LatestTuneResponse.self, from: data).message
    }

    func createUpload(chatId: String, senderId: String, duration: TimeInterval) async throws -> CreateTuneUploadResponse {
        let url = baseURL.appendingPathComponent("api/create-upload")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(CreateTuneUpload(chatId: chatId, senderId: senderId, duration: duration))
        let (data, resp) = try await session.data(for: req)
        try validate(resp: resp, data: data)
        return try JSONDecoder().decode(CreateTuneUploadResponse.self, from: data)
    }

    func finishUpload(messageId: String, audioURL: URL) async throws -> TuneMessage {
        let url = baseURL.appendingPathComponent("api/finish-upload")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(["messageId": messageId, "audioURL": audioURL.absoluteString])
        let (data, resp) = try await session.data(for: req)
        try validate(resp: resp, data: data)
        return try JSONDecoder().decode(TuneMessage.self, from: data)
    }

    private func validate(resp: URLResponse, data: Data) throws {
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw NSError(domain: "APIClient", code: (resp as? HTTPURLResponse)?.statusCode ?? -1, userInfo: [NSLocalizedDescriptionKey: body])
        }
    }
}

private extension URL {
    func appending(queryItems: [URLQueryItem]) -> URL {
        var comps = URLComponents(url: self, resolvingAgainstBaseURL: false)!
        comps.queryItems = (comps.queryItems ?? []) + queryItems
        return comps.url!
    }
}
