import Foundation

public struct User: Codable, Identifiable, Hashable {
    public let id: String
    public var handle: String
    
    public init(id: String, handle: String) {
        self.id = id
        self.handle = handle
    }
}

public struct Chat: Codable, Identifiable, Hashable {
    public let id: String
    public var name: String
    public var memberIds: [String]
    
    public init(id: String, name: String, memberIds: [String]) {
        self.id = id
        self.name = name
        self.memberIds = memberIds
    }
}

public struct TuneMessage: Codable, Identifiable, Hashable {
    public let id: String
    public let chatId: String
    public let senderId: String
    public let audioURL: URL
    public let duration: TimeInterval
    public let createdAt: Date
    
    public init(id: String, chatId: String, senderId: String, audioURL: URL, duration: TimeInterval, createdAt: Date) {
        self.id = id
        self.chatId = chatId
        self.senderId = senderId
        self.audioURL = audioURL
        self.duration = duration
        self.createdAt = createdAt
    }
}

public struct CreateTuneUpload: Codable {
    public let chatId: String
    public let senderId: String
    public let duration: TimeInterval
    
    public init(chatId: String, senderId: String, duration: TimeInterval) {
        self.chatId = chatId
        self.senderId = senderId
        self.duration = duration
    }
}

public struct CreateTuneUploadResponse: Codable {
    public let uploadURL: URL
    public let messageId: String
    
    public init(uploadURL: URL, messageId: String) {
        self.uploadURL = uploadURL
        self.messageId = messageId
    }
}

public struct LatestTuneResponse: Codable {
    public let message: TuneMessage?
    
    public init(message: TuneMessage?) {
        self.message = message
    }
}
