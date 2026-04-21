import Foundation
import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var chats: [LocalChat] = []
    @Published var friends: [TonesUser] = []
    @Published var isLoading = false
    @Published var searchResults: [TonesUser] = []
    @Published var isSearching = false

    private let storage = LocalStorage.shared
    private let api = APIClient.shared

    func loadChats() {
        chats = storage.loadChats()
    }

    func createDM(with friendId: String, friendName: String) async throws -> LocalChat {
        let chatId = try await api.createDM(friendId: friendId)
        if let existing = storage.loadChats().first(where: { $0.id == chatId }) {
            if !chats.contains(where: { $0.id == chatId }) {
                chats.insert(existing, at: 0)
            }
            return existing
        }
        let chat = LocalChat(id: chatId, name: friendName, type: "dm")
        storage.addChat(chat)
        chats.insert(chat, at: 0)
        return chat
    }

    func syncChats() async {
        do {
            let remote = try await api.listChats()
            let local = storage.loadChats()
            var merged = local
            for r in remote {
                if merged.contains(where: { $0.id == r.id }) { continue }
                let name: String
                if let u = r.peer_username { name = "@\(u)" }
                else if let pid = r.peer_id { name = String(pid.prefix(8)) }
                else { name = r.title ?? "chat" }
                let chat = LocalChat(id: r.id, name: name, type: r.type)
                storage.addChat(chat)
                merged.insert(chat, at: 0)
            }
            chats = merged
        } catch {
            print("syncChats failed: \(error)")
        }
    }

    func deleteChat(_ chatId: String) {
        storage.deleteChat(chatId)
        chats.removeAll { $0.id == chatId }
    }

    func searchUsers(query: String) async {
        guard query.count >= 2 else {
            searchResults = []
            return
        }
        isSearching = true
        do {
            searchResults = try await api.searchUsers(query: query)
        } catch {
            searchResults = []
        }
        isSearching = false
    }

    func addFriend(byUsername username: String) async throws -> TonesUser {
        let users = try await api.searchUsers(query: username)
        guard let user = users.first(where: { $0.username?.lowercased() == username.lowercased() }) else {
            throw TonesAuthError(message: "@\(username) doesn't exist yet — tell them to get tones!")
        }
        if friends.contains(where: { $0.id == user.id }) {
            throw TonesAuthError(message: "you're already friends with @\(username)")
        }
        try await api.addFriend(friendId: user.id)
        if !friends.contains(where: { $0.id == user.id }) {
            friends.insert(user, at: 0)
        }
        return user
    }

    func loadFriends() async {
        do {
            friends = try await api.listFriends()
        } catch {
            print("loadFriends failed: \(error)")
        }
    }

    func openChat(with friend: TonesUser) async throws -> LocalChat {
        let name = friend.username.map { "@\($0)" } ?? "user"
        return try await createDM(with: friend.id, friendName: name)
    }
}
