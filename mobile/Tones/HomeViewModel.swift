import Foundation
import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var chats: [Chat] = []
    @Published var pendingAlert: PendingAlert?

    func createSampleData() {
        if chats.isEmpty {
            let alice = Chat.friends(name: "Alice")
            let bob = Chat.friends(name: "Bob")
            let group = Chat.group(title: "Crew", members: ["Alice", "Bob", "You"])
            chats = [alice, bob, group]
        }
    }

    func addFriendPrompt() {
        let name = "Friend \(Int.random(in: 100...999))"
        let chat = Chat.friends(name: name)
        chats.insert(chat, at: 0)
        pendingAlert = PendingAlert(kind: .addFriend, message: name)
    }

    func addGroupPrompt() {
        let title = "Group \(Int.random(in: 1...50))"
        let chat = Chat.group(title: title, members: ["You", "A", "B"])
        chats.insert(chat, at: 0)
        pendingAlert = PendingAlert(kind: .addGroup, message: title)
    }

    func chat(id: UUID) -> Chat? { chats.first { $0.id == id } }

    func update(chat: Chat) {
        if let idx = chats.firstIndex(where: { $0.id == chat.id }) {
            chats[idx] = chat
        }
    }
}

struct PendingAlert: Identifiable {
    enum Kind { case addFriend, addGroup }
    let id = UUID()
    let kind: Kind
    var message: String?
}

struct Chat: Identifiable, Hashable, Codable {
    let id: UUID
    var title: String
    var members: [String]
    var isGroup: Bool
    var tunes: [Tune]
    var color: Color

    enum CodingKeys: String, CodingKey {
        case id, title, members, isGroup, tunes, color
    }

    init(id: UUID = UUID(), title: String, members: [String], isGroup: Bool, tunes: [Tune], color: Color) {
        self.id = id
        self.title = title
        self.members = members
        self.isGroup = isGroup
        self.tunes = tunes
        self.color = color
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        members = try container.decode([String].self, forKey: .members)
        isGroup = try container.decode(Bool.self, forKey: .isGroup)
        tunes = try container.decode([Tune].self, forKey: .tunes)
        let colorValue = try container.decode(String.self, forKey: .color)
        color = colorValue == "purple" ? .purple : .blue
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(members, forKey: .members)
        try container.encode(isGroup, forKey: .isGroup)
        try container.encode(tunes, forKey: .tunes)
        try container.encode(color == .purple ? "purple" : "blue", forKey: .color)
    }

    var unheardCount: Int { tunes.filter { !$0.heard }.count }
    var lastTuneDescription: String {
        if let last = tunes.last {
            let secs = String(format: "%.0fs", last.duration)
            return last.sender + " • " + secs
        }
        return "No tunes yet"
    }

    static func friends(name: String) -> Chat {
        Chat(id: UUID(), title: name, members: ["You", name], isGroup: false, tunes: [], color: .blue)
    }

    static func group(title: String, members: [String]) -> Chat {
        Chat(id: UUID(), title: title, members: members, isGroup: true, tunes: [], color: .purple)
    }
}

struct Tune: Identifiable, Hashable, Codable {
    let id: UUID
    let sender: String
    let date: Date
    let audioURL: URL
    let duration: TimeInterval
    var heard: Bool

    enum CodingKeys: String, CodingKey {
        case id, sender, date, audioURL, duration, heard
    }

    init(id: UUID = UUID(), sender: String, date: Date = Date(), audioURL: URL, duration: TimeInterval, heard: Bool = false) {
        self.id = id
        self.sender = sender
        self.date = date
        self.audioURL = audioURL
        self.duration = duration
        self.heard = heard
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        sender = try container.decode(String.self, forKey: .sender)
        date = try container.decode(Date.self, forKey: .date)
        audioURL = try container.decode(URL.self, forKey: .audioURL)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        heard = try container.decode(Bool.self, forKey: .heard)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(sender, forKey: .sender)
        try container.encode(date, forKey: .date)
        try container.encode(audioURL, forKey: .audioURL)
        try container.encode(duration, forKey: .duration)
        try container.encode(heard, forKey: .heard)
    }
}
