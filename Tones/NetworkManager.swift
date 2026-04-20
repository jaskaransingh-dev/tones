import Foundation

class NetworkManager {
    static let shared = NetworkManager()
    // Replace this with your Cloudflare Worker URL
    let baseURL = "https://your-worker-url.workers.dev"
    
    func uploadTune(chatId: String, senderId: String, fileURL: URL) async throws {
        guard var components = URLComponents(string: "\(baseURL)/tunes/upload") else { throw URLError(.badURL) }
        components.queryItems = [
            URLQueryItem(name: "chatId", value: chatId),
            URLQueryItem(name: "senderId", value: senderId)
        ]
        guard let url = components.url else { throw URLError(.badURL) }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let audioData = try Data(contentsOf: fileURL)
        request.httpBody = audioData
        request.setValue("audio/m4a", forHTTPHeaderField: "Content-Type")
        
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
    }
    
    struct TuneItem: Decodable {
        let id: String
        let r2_key: String
    }
    
    func fetchUnplayedTunes(chatId: String) async throws -> [URL] {
        guard var components = URLComponents(string: "\(baseURL)/tunes/unplayed") else { return [] }
        components.queryItems = [URLQueryItem(name: "chatId", value: chatId)]
        guard let url = components.url else { return [] }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 else { return [] }
        
        struct ResponsePayload: Decodable { let tunes: [TuneItem] }
        let payload = try JSONDecoder().decode(ResponsePayload.self, from: data)
        
        var localURLs: [URL] = []
        for item in payload.tunes {
            let audioURL = URL(string: "\(baseURL)/audio/\(item.r2_key)")!
            let (audioData, audioResp) = try await URLSession.shared.data(from: audioURL)
            guard let audioHTTP = audioResp as? HTTPURLResponse, audioHTTP.statusCode == 200 else { continue }
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(item.id).m4a")
            try audioData.write(to: tempURL, options: .atomic)
            localURLs.append(tempURL)
            // mark as played after download to follow PRD flow (or after playback if you prefer)
            try await markTunePlayed(tuneId: item.id)
        }
        return localURLs
    }
    
    private func markTunePlayed(tuneId: String) async throws {
        guard let url = URL(string: "\(baseURL)/tunes/mark-played") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body = ["tuneId": tuneId]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        _ = try await URLSession.shared.data(for: request)
    }
}
