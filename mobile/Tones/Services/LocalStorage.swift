import Foundation

class LocalStorage {
    static let shared = LocalStorage()

    private let fileManager = FileManager.default
    let documentsPath: URL
    private let chatsFileName = "chats.json"
    private let messagesFileName = "messages.json"

    private let saveRecordingsKey = "saveRecordings"

    private init() {
        documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    var shouldSaveRecordings: Bool {
        get { UserDefaults.standard.object(forKey: saveRecordingsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: saveRecordingsKey) }
    }

    func cleanupAudioIfNeeded(chatId: String) {
        guard !shouldSaveRecordings else { return }
        let messages = loadMessages(chatId)
        for msg in messages where msg.heard {
            deleteAudio(msg.audioPath)
        }
    }

    func cleanupAllAudioIfNeeded() {
        guard !shouldSaveRecordings else { return }
        let chats = loadChats()
        for chat in chats {
            cleanupAudioIfNeeded(chatId: chat.id)
        }
    }

    // MARK: - Audio Storage (Local File)

    func saveAudio(_ data: Data, chatId: String) throws -> URL {
        let audioDir = documentsPath.appendingPathComponent("audio", isDirectory: true)
        try fileManager.createDirectory(at: audioDir, withIntermediateDirectories: true)

        let fileName = "\(chatId)_\(UUID().uuidString).m4a"
        let audioURL = audioDir.appendingPathComponent(fileName)

        try data.write(to: audioURL)
        return audioURL
    }

    func getAudioURL(_ relativePath: String) -> URL? {
        let url = documentsPath.appendingPathComponent(relativePath)
        return fileManager.fileExists(atPath: url.path) ? url : nil
    }

    func deleteAudio(_ relativePath: String) {
        let url = documentsPath.appendingPathComponent(relativePath)
        try? fileManager.removeItem(at: url)
    }

    // MARK: - Chat Storage (JSON)

    func saveChats(_ chats: [LocalChat]) {
        let url = documentsPath.appendingPathComponent(chatsFileName)
        let data = try? JSONEncoder().encode(chats)
        try? data?.write(to: url)
    }

    func loadChats() -> [LocalChat] {
        let url = documentsPath.appendingPathComponent(chatsFileName)
        guard let data = try? Data(contentsOf: url),
              let chats = try? JSONDecoder().decode([LocalChat].self, from: data) else {
            return []
        }
        return chats
    }

    func addChat(_ chat: LocalChat) {
        var chats = loadChats()
        if let index = chats.firstIndex(where: { $0.id == chat.id }) {
            chats[index] = chat
        } else {
            chats.insert(chat, at: 0)
        }
        saveChats(chats)
    }

    func deleteChat(_ chatId: String) {
        var chats = loadChats()
        chats.removeAll { $0.id == chatId }
        saveChats(chats)

        let messages = loadMessages(chatId)
        for msg in messages {
            deleteAudio(msg.audioPath)
        }
        let fileName = "messages_\(chatId).json"
        let url = documentsPath.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: url)
    }

    // MARK: - Message Storage (JSON per chat)

    func saveMessages(_ chatId: String, _ messages: [LocalMessage]) {
        let fileName = "messages_\(chatId).json"
        let url = documentsPath.appendingPathComponent(fileName)
        let data = try? JSONEncoder().encode(messages)
        try? data?.write(to: url)
    }

    func loadMessages(_ chatId: String) -> [LocalMessage] {
        let fileName = "messages_\(chatId).json"
        let url = documentsPath.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url),
              let messages = try? JSONDecoder().decode([LocalMessage].self, from: data) else {
            return []
        }
        return messages
    }

    func addMessage(_ message: LocalMessage) {
        var messages = loadMessages(message.chatId)
        messages.append(message)
        saveMessages(message.chatId, messages)
    }

    func markMessageHeard(_ messageId: String, chatId: String) {
        var messages = loadMessages(chatId)
        if let index = messages.firstIndex(where: { $0.id == messageId }) {
            messages[index].heard = true
            saveMessages(chatId, messages)
        }
    }

    func getLatestMessage(chatId: String) -> LocalMessage? {
        loadMessages(chatId).last
    }

    func getUnheardCount(chatId: String, myId: String = "") -> Int {
        loadMessages(chatId).filter { !$0.heard && ($0.senderId != myId || myId.isEmpty) }.count
    }

    func totalUnreadCount(myId: String = "") -> Int {
        let chatIds = loadChats().map { $0.id }
        return chatIds.reduce(0) { $0 + getUnheardCount(chatId: $1, myId: myId) }
    }

    // MARK: - Sync State

    func lastSyncedAt(chatId: String) -> Int {
        let url = documentsPath.appendingPathComponent("sync_\(chatId).txt")
        guard let data = try? Data(contentsOf: url),
              let str = String(data: data, encoding: .utf8),
              let ts = Int(str.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return 0
        }
        return ts
    }

    func setLastSyncedAt(chatId: String, ts: Int) {
        let url = documentsPath.appendingPathComponent("sync_\(chatId).txt")
        try? String(ts).write(to: url, atomically: true, encoding: .utf8)
    }

    func clearAll() {
        try? fileManager.removeItem(at: documentsPath.appendingPathComponent(chatsFileName))
        let items = (try? fileManager.contentsOfDirectory(atPath: documentsPath.path)) ?? []
        for item in items where item.hasPrefix("messages_") || item.hasPrefix("sync_") {
            try? fileManager.removeItem(at: documentsPath.appendingPathComponent(item))
        }
        try? fileManager.removeItem(at: documentsPath.appendingPathComponent("audio", isDirectory: true))
    }
}

// MARK: - Models (Codable for JSON storage)

struct LocalChatMember: Codable, Identifiable, Equatable {
    var id: String
    var username: String?
    var avatarURL: String?

    enum CodingKeys: String, CodingKey {
        case id, username
        case avatarURL = "avatar_url"
    }
}

struct LocalChat: Codable, Identifiable {
    let id: String
    var name: String
    var type: String
    var createdAt: Int
    var updatedAt: Int
    var unreadCount: Int
    var peerAvatarURL: String?
    var avatarURL: String?
    var members: [LocalChatMember]?

    var isGroup: Bool { type == "group" }

    var displayName: String {
        if isGroup && !name.isEmpty {
            return name
        }
        return name
    }

    init(id: String = UUID().uuidString, name: String, type: String = "dm", createdAt: Int = Int(Date().timeIntervalSince1970), updatedAt: Int = Int(Date().timeIntervalSince1970), unreadCount: Int = 0, peerAvatarURL: String? = nil, avatarURL: String? = nil, members: [LocalChatMember]? = nil) {
        self.id = id
        self.name = name
        self.type = type
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.unreadCount = unreadCount
        self.peerAvatarURL = peerAvatarURL
        self.avatarURL = avatarURL
        self.members = members
    }
}

struct LocalMessage: Codable, Identifiable {
    let id: String
    let chatId: String
    let senderId: String
    let audioPath: String
    let senderName: String
    let senderAvatarURL: String?
    let duration: Double
    let createdAt: Int
    var heard: Bool

    var audioURL: URL? {
        LocalStorage.shared.getAudioURL(audioPath)
    }

    init(id: String = UUID().uuidString, chatId: String, senderId: String, senderName: String = "You", senderAvatarURL: String? = nil, audioPath: String, duration: Double, createdAt: Int = Int(Date().timeIntervalSince1970), heard: Bool = false) {
        self.id = id
        self.chatId = chatId
        self.senderId = senderId
        self.senderName = senderName
        self.senderAvatarURL = senderAvatarURL
        self.audioPath = audioPath
        self.duration = duration
        self.createdAt = createdAt
        self.heard = heard
    }
}