import Foundation
import SwiftUI
import Combine

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var chats: [LocalChat] = []
    @Published var isLoading = false
    @Published var searchResults: [TonesUser] = []
    @Published var isSearching = false

    private let storage = LocalStorage.shared
    private let api = APIClient.shared

    func loadChats() {
        chats = storage.loadChats()
    }

    func createDM(with friendId: String, friendName: String) {
        let chatId = UUID().uuidString
        let chat = LocalChat(id: chatId, name: friendName, type: "dm")
        storage.addChat(chat)
        chats.insert(chat, at: 0)
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
            throw TonesAuthError(message: "User @\(username) not found. Make sure they have a username set.")
        }
        
        // Actually add the friend via API
        try await api.addFriend(friendId: user.id)
        
        return user
    }
}