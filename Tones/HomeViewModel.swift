import Foundation
import SwiftUI

@MainActor
final class HomeViewModel: ObservableObject {
    @Published private(set) var chats: [Chat] = []
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

struct Chat: Identifiable, Hashable {
    let id: UUID
    var title: String
    var members: [String]
    var isGroup: Bool
    var tunes: [Tune]
    var color: Color

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

struct Tune: Identifiable, Hashable {
    let id: UUID
    let sender: String
    let date: Date
    let audioURL: URL
    let duration: TimeInterval
    var heard: Bool
}
