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
    @Published var totalUnreadCount: Int = 0

    private let storage = LocalStorage.shared
    private let api = APIClient.shared
    private var pollTimer: Timer?

    func loadChats() {
        chats = storage.loadChats()
        refreshUnreadCounts()
    }

    func loadFriends() {
        Task {
            do {
                friends = try await api.listFriends()
            } catch {
                print("loadFriends failed: \(error)")
            }
        }
    }

    func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.pollForNewMessages()
            }
        }
        Task { await pollForNewMessages() }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }

    private func pollForNewMessages() async {
        await syncChats()
        for chat in chats {
            await syncNewMessages(for: chat.id)
        }
        refreshUnreadCounts()
    }

    private func syncNewMessages(for chatId: String) async {
        let since = storage.lastSyncedAt(chatId: chatId)
        do {
            let remote = try await api.listMessages(chatId: chatId, since: since)
            guard !remote.isEmpty else { return }
            let existingIds = Set(storage.loadMessages(chatId).map { $0.id })
            var latestTs = since
            var hasNew = false
            let myId = AuthService.shared.currentUser?.id ?? ""
            for r in remote {
                latestTs = max(latestTs, r.created_at)
                guard !existingIds.contains(r.id) else { continue }
                guard let data = Data(base64Encoded: r.audio_base64) else { continue }
                let fileName = "\(chatId)_\(r.id).m4a"
                let destDir = storage.documentsPath.appendingPathComponent("audio", isDirectory: true)
                let destURL = destDir.appendingPathComponent(fileName)
                try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
                try? data.write(to: destURL)
                let senderName = r.sender_username.map { "@\($0)" } ?? "user"
                let msg = LocalMessage(
                    id: r.id,
                    chatId: chatId,
                    senderId: r.sender_id,
                    senderName: senderName,
                    audioPath: "audio/\(fileName)",
                    duration: Double(r.duration_ms) / 1000.0,
                    createdAt: r.created_at / 1000,
                    heard: r.heard == true || r.sender_id == myId
                )
                storage.addMessage(msg)
                hasNew = true
            }
            storage.setLastSyncedAt(chatId: chatId, ts: latestTs)
            if hasNew {
                try? await UNUserNotificationCenter.current().setBadgeCount(storage.totalUnreadCount(myId: myId))
            }
        } catch {
            print("syncNewMessages failed: \(error)")
        }
    }

    func refreshUnreadCounts() {
        var total = 0
        for i in chats.indices {
            let count = storage.getUnheardCount(chatId: chats[i].id, myId: AuthService.shared.currentUser?.id ?? "")
            chats[i].unreadCount = count
            total += count
        }
        totalUnreadCount = total
        Task { try? await UNUserNotificationCenter.current().setBadgeCount(total) }
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
                if let idx = merged.firstIndex(where: { $0.id == r.id }) {
                    merged[idx].unreadCount = r.unread_count ?? merged[idx].unreadCount
                    if let avatarURL = r.peer_avatar_url {
                        merged[idx].peerAvatarURL = avatarURL
                    }
                } else {
                    let name: String
                    if let u = r.peer_username { name = "@\(u)" }
                    else if let pid = r.peer_id { name = String(pid.prefix(8)) }
                    else { name = r.title ?? "chat" }
                    let chat = LocalChat(id: r.id, name: name, type: r.type, unreadCount: r.unread_count ?? 0, peerAvatarURL: r.peer_avatar_url)
                    storage.addChat(chat)
                    merged.insert(chat, at: 0)
                }
            }
            chats = merged
        } catch {
            print("syncChats failed: \(error)")
        }
    }

    func deleteChat(_ chatId: String) {
        storage.deleteChat(chatId)
        chats.removeAll { $0.id == chatId }
        refreshUnreadCounts()
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

    func openChat(with friend: TonesUser) async throws -> LocalChat {
        let name = friend.username.map { "@\($0)" } ?? "user"
        return try await createDM(with: friend.id, friendName: name)
    }
}
