import SwiftUI

struct CreateGroupChatView: View {
    @ObservedObject var viewModel: HomeViewModel
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    @State private var groupTitle = ""
    @State private var selectedFriendIds: Set<String> = []
    @State private var isCreating = false
    @State private var errorMessage: String?

    private var friends: [TonesUser] {
        viewModel.friends
    }

    private var canCreate: Bool {
        !selectedFriendIds.isEmpty && !isCreating
    }

    var body: some View {
        NavigationStack {
            ZStack {
                WarmBackground()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        VStack(spacing: 14) {
                            Image("TonesLogo")
                                .resizable()
                                .scaledToFill()
                                .frame(width: 64, height: 64)
                                .clipShape(Circle())
                            Text("new group")
                                .font(.system(size: 24, weight: .thin))
                                .foregroundStyle(Color.warmDark)
                                .tracking(2)
                        }

                        VStack(spacing: 12) {
                            TextField("group name (optional)", text: $groupTitle)
                                .textInputAutocapitalization(.words)
                                .font(.title3)
                                .foregroundStyle(Color.warmDark)
                                .multilineTextAlignment(.center)
                                .padding()
                                .background(Color.white.opacity(0.7))
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("add members")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(Color.warmBrown)
                                    .tracking(3)
                                    .textCase(.uppercase)
                                Spacer()
                                if !selectedFriendIds.isEmpty {
                                    Text("\(selectedFriendIds.count) selected")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.callGreen)
                                }
                            }
                            .padding(.horizontal, 4)

                            LazyVStack(spacing: 4) {
                                ForEach(friends) { friend in
                                    friendRow(friend)
                                }
                            }
                        }

                        if let errorMessage {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundStyle(.red)
                        }

                        Button(action: createGroup) {
                            HStack {
                                if isCreating {
                                    ProgressView().tint(.white)
                                } else {
                                    Image(systemName: "person.2.fill")
                                        .font(.system(size: 15, weight: .semibold))
                                    Text("create group")
                                        .font(.system(size: 17, weight: .semibold))
                                }
                            }
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 17)
                            .background(canCreate ? Color.warmCoral : Color.warmCoral.opacity(0.4))
                            .clipShape(RoundedRectangle(cornerRadius: 18))
                            .shadow(color: canCreate ? Color.warmCoral.opacity(0.25) : .clear, radius: 12, y: 6)
                        }
                        .disabled(!canCreate)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 20)
                    .padding(.bottom, 50)
                }
            }
            .navigationTitle("")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                        .foregroundStyle(Color.warmBrown)
                }
            }
        }
    }

    private func friendRow(_ friend: TonesUser) -> some View {
        let isSelected = selectedFriendIds.contains(friend.id)
        let name = friend.username ?? "user"
        return Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                if isSelected {
                    selectedFriendIds.remove(friend.id)
                } else {
                    selectedFriendIds.insert(friend.id)
                }
            }
        }) {
            HStack(spacing: 14) {
                AvatarView(urlString: friend.avatarURL, initial: String(name.prefix(1)).uppercased(), size: 44)

                Text(name.lowercased())
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.warmDark)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.callGreen)
                } else {
                    Circle()
                        .strokeBorder(Color.warmBrown.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 22, height: 22)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.callGreen.opacity(0.06) : Color.white.opacity(0.8))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func createGroup() {
        isCreating = true
        errorMessage = nil
        Task {
            do {
                let selectedFriends = friends.filter { selectedFriendIds.contains($0.id) }
                let members = selectedFriends.map { (id: $0.id, username: $0.username) }
                let chat = try await viewModel.createGroupChat(title: groupTitle.isEmpty ? nil : groupTitle, members: members)
                dismiss()
            } catch let error as TonesAuthError {
                errorMessage = error.message
            } catch {
                errorMessage = error.localizedDescription
            }
            isCreating = false
        }
    }
}