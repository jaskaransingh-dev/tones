import Foundation
import SwiftUI

struct TonesUser: Codable, Identifiable {
    var id: String
    var appleSub: String?
    var phoneNumber: String?
    var username: String?
    var displayName: String
    var avatarURL: String?
    var createdAt: Int?
    var lastActiveAt: Int?
    var notificationToken: String?

    enum CodingKeys: String, CodingKey {
        case id, appleSub = "apple_sub", phoneNumber = "phone_number", username
        case displayName = "display_name", avatarURL = "avatar_url"
        case createdAt = "created_at", lastActiveAt = "last_active_at"
        case notificationToken = "notification_token"
    }

    var hasUsername: Bool {
        username != nil && !username!.isEmpty && username != ""
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

struct UploadURLResponse: Codable {
    var uploadUrl: String
    var r2Key: String
}

struct UploadURLRequest: Codable {
    var chat_id: String
    var duration_ms: Int

    enum CodingKeys: String, CodingKey {
        case chat_id, duration_ms
    }
}

struct MessageSendResponse: Codable {
    var id: String
}

struct SendMessageRequest: Codable {
    var chat_id: String
    var r2_key: String
    var duration_ms: Int

    enum CodingKeys: String, CodingKey {
        case chat_id, r2_key, duration_ms
    }
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