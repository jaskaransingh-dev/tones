import Foundation
import SwiftUI

struct TonesUser: Codable, Identifiable {
    var id: String
    var appleSub: String?
    var username: String?
    var avatarURL: String?
    var createdAt: Int?
    var lastActiveAt: Int?
    var notificationToken: String?

    enum CodingKeys: String, CodingKey {
        case id, appleSub = "apple_sub", username
        case avatarURL = "avatar_url"
        case createdAt = "created_at", lastActiveAt = "last_active_at"
        case notificationToken = "notification_token"
    }

    var hasUsername: Bool {
        username != nil && !username!.isEmpty && username != ""
    }

    var hasAvatar: Bool {
        guard let url = avatarURL, !url.isEmpty else { return false }
        return url != "none"
    }

    var hasCompletedOnboarding: Bool {
        hasUsername && (avatarURL != nil && !avatarURL!.isEmpty)
    }

    var uuid: UUID? {
        UUID(uuidString: id)
    }
}

struct TonesSession: Codable {
    var accessToken: String
    var refreshToken: String
}

struct LoginResponse: Codable {
    var user: TonesUser
    var accessToken: String
    var refreshToken: String

    enum CodingKeys: String, CodingKey {
        case user
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}

struct TonesAuthError: Error, LocalizedError {
    var message: String
    var suggestions: [String]?

    init(message: String, suggestions: [String]? = nil) {
        self.message = message
        self.suggestions = suggestions
    }

    var errorDescription: String? {
        return message
    }
}

struct TonesAuthErrorResponse: Codable {
    var error: String
    var suggestions: [String]?
}

struct AvatarUploadResponse: Codable {
    var avatar_url: String
}

struct ChatListItem: Codable, Identifiable {
    var id: String
    var type: String
    var title: String?
    var lastMessageAt: Int?
    var unreadCount: Int

    var uuid: UUID? {
        UUID(uuidString: id)
    }
}

struct ChatOpenResponse: Codable {
    var message: ToneMessage?
}

struct ToneMessage: Codable, Identifiable {
    var id: String
    var audioUrl: String?
    var r2Key: String?
    var durationMs: Int
    var senderId: String
    var senderUsername: String
    var replyState: String

    var uuid: UUID? {
        UUID(uuidString: id)
    }
}

struct RemoteChat: Codable {
    var id: String
    var type: String
    var title: String?
    var updated_at: Int?
    var peer_id: String?
    var peer_username: String?
    var peer_avatar_url: String?
    var unread_count: Int?
}

struct CreateDMResponse: Codable {
    var id: String
    var type: String
}

struct RemoteMessage: Codable {
    var id: String
    var chat_id: String
    var sender_id: String
    var audio_base64: String
    var duration_ms: Int
    var created_at: Int
    var sender_username: String?
    var heard: Bool?
}

struct SendMessageResult: Codable {
    var id: String
    var created_at: Int
}

struct CreateDMRequest: Codable {
    var friend_id: String

    enum CodingKeys: String, CodingKey {
        case friend_id
    }
}

struct CreateGroupRequest: Codable {
    var title: String
    var member_ids: [String]

    enum CodingKeys: String, CodingKey {
        case title, member_ids
    }
}

struct AddFriendRequest: Codable {
    var friend_id: String

    enum CodingKeys: String, CodingKey {
        case friend_id
    }
}