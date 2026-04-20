import Foundation
import SwiftUI

struct TuneChat: Codable, Identifiable {
    var id: String
    var name: String
    var memberIds: [String]
    var isGroup: Bool
    var tunes: [TuneMessage]
    var colorValue: String

    enum CodingKeys: String, CodingKey {
        case id, name, memberIds, isGroup, tunes, colorValue
    }

    var color: Color {
        get { colorValue == "purple" ? .purple : .blue }
        set { colorValue = newValue == .purple ? "purple" : "blue" }
    }

    var uuid: UUID? {
        UUID(uuidString: id)
    }

    init(id: String = UUID().uuidString, name: String, memberIds: [String] = [], isGroup: Bool = false, tunes: [TuneMessage] = [], color: Color = .blue) {
        self.id = id
        self.name = name
        self.memberIds = memberIds
        self.isGroup = isGroup
        self.tunes = tunes
        self.colorValue = color == .purple ? "purple" : "blue"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        memberIds = try container.decode([String].self, forKey: .memberIds)
        isGroup = try container.decode(Bool.self, forKey: .isGroup)
        tunes = try container.decodeIfPresent([TuneMessage].self, forKey: .tunes) ?? []
        let colorStr = try container.decodeIfPresent(String.self, forKey: .colorValue) ?? "blue"
        colorValue = colorStr
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(memberIds, forKey: .memberIds)
        try container.encode(isGroup, forKey: .isGroup)
        try container.encode(tunes, forKey: .tunes)
        try container.encode(colorValue, forKey: .colorValue)
    }
}

struct TuneMessage: Codable, Identifiable {
    var id: String
    var chatId: String?
    var senderId: String
    var audioURL: URL?
    var duration: TimeInterval
    var createdAt: Int
    var heard: Bool

    enum CodingKeys: String, CodingKey {
        case id, chatId, senderId, audioURL, duration, createdAt, heard
    }

    var uuid: UUID? {
        UUID(uuidString: id)
    }

    init(id: String = UUID().uuidString, chatId: String? = nil, senderId: String, audioURL: URL? = nil, duration: TimeInterval, createdAt: Int = Int(Date().timeIntervalSince1970 * 1000), heard: Bool = false) {
        self.id = id
        self.chatId = chatId
        self.senderId = senderId
        self.audioURL = audioURL
        self.duration = duration
        self.createdAt = createdAt
        self.heard = heard
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        chatId = try container.decodeIfPresent(String.self, forKey: .chatId)
        senderId = try container.decode(String.self, forKey: .senderId)
        audioURL = try container.decodeIfPresent(URL.self, forKey: .audioURL)
        duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration) ?? 0
        createdAt = try container.decodeIfPresent(Int.self, forKey: .createdAt) ?? Int(Date().timeIntervalSince1970 * 1000)
        heard = try container.decodeIfPresent(Bool.self, forKey: .heard) ?? false
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(chatId, forKey: .chatId)
        try container.encode(senderId, forKey: .senderId)
        try container.encodeIfPresent(audioURL, forKey: .audioURL)
        try container.encode(duration, forKey: .duration)
        try container.encode(createdAt, forKey: .createdAt)
        try container.encode(heard, forKey: .heard)
    }
}

struct CreateTuneUpload: Codable {
    var chatId: UUID
    var senderId: UUID
    var duration: TimeInterval
}

struct CreateTuneUploadResponse: Codable {
    var uploadURL: URL
    var messageId: UUID
}

struct LatestTuneResponse: Codable {
    var message: TuneMessage?
}

struct CreateChatRequest: Codable {
    var name: String
    var memberIds: [String]

    init(name: String, memberIds: [String]) {
        self.name = name
        self.memberIds = memberIds
    }
}