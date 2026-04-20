import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject var authService: AuthService
    @State private var showingAddFriend = false
    @State private var showingSignOut = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                if viewModel.chats.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "waveform.circle")
                            .font(.system(size: 60))
                            .foregroundStyle(Color.yellow.opacity(0.6))

                        Text("No conversations yet")
                            .font(.headline)
                            .foregroundStyle(.gray)

                        Button(action: { showingAddFriend = true }) {
                            Text("Add a friend")
                                .fontWeight(.semibold)
                                .foregroundStyle(.black)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Color.yellow.opacity(0.85))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                } else {
                    List {
                        ForEach(viewModel.chats) { chat in
                            NavigationLink(destination: ChatView(chat: chat, viewModel: viewModel)) {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(chat.isGroup ? Color.purple : Color.yellow.opacity(0.8))
                                        .frame(width: 12, height: 12)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(chat.name)
                                            .font(.headline)
                                            .foregroundStyle(.black)

                                        let msgCount = LocalStorage.shared.loadMessages(chat.id).count
                                        Text(msgCount == 0 ? "No tones yet" : "\(msgCount) tone\(msgCount == 1 ? "" : "s")")
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                    }

                                    Spacer()

                                    let unheard = LocalStorage.shared.getUnheardCount(chatId: chat.id)
                                    if unheard > 0 {
                                        Text("\(unheard)")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.black)
                                            .padding(6)
                                            .background(Circle())
                                            .background(Color.yellow.opacity(0.9))
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete { indexSet in
                            for index in indexSet {
                                let chat = viewModel.chats[index]
                                viewModel.deleteChat(chat.id)
                            }
                        }
                        .listRowBackground(Color.white)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Tones")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack(spacing: 8) {
                        Image("TonesLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .clipShape(Circle())

                        if let username = authService.currentUser?.username {
                            Text("@\(username)")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundStyle(.gray)
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: { showingAddFriend = true }) {
                            Label("Add friend", systemImage: "person.badge.plus")
                        }
                        Button(action: { UIPasteboard.general.string = "@\(authService.currentUser?.username ?? "")" }) {
                            Label("Copy my @username", systemImage: "doc.on.doc")
                        }
                        Divider()
                        Button(role: .destructive, action: { showingSignOut = true }) {
                            Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.yellow.opacity(0.9))
                    }
                }
            }
            .onAppear { viewModel.loadChats() }
            .sheet(isPresented: $showingAddFriend) {
                AddFriendView(viewModel: viewModel)
            }
            .alert("Sign out?", isPresented: $showingSignOut) {
                Button("Sign out", role: .destructive) { authService.logout() }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("You'll need to sign in again to access your account.")
            }
        }
    }
}

struct AddFriendView: View {
    @ObservedObject var viewModel: HomeViewModel
    @Environment(\.dismiss) var dismiss
    @State private var username = ""
    @State private var addError: String?
    @State private var isAdding = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                VStack(spacing: 24) {
                    Text("Add a friend")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Enter their @username to start talking")
                        .foregroundStyle(.gray)
                        .font(.subheadline)

                    TextField("@username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .padding()
                        .background(Color.yellow.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .onChange(of: username) { _, newValue in
                            username = newValue.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "." || $0 == "_" }
                            addError = nil
                        }

                    if let addError {
                        Text(addError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    Button(action: addFriend) {
                        HStack {
                            if isAdding {
                                ProgressView().tint(.black)
                            } else {
                                Text("Add friend")
                                    .fontWeight(.semibold)
                            }
                        }
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(username.count >= 3 ? Color.yellow.opacity(0.85) : Color.gray.opacity(0.3))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .disabled(username.count < 3 || isAdding)

                    Spacer()
                }
                .padding(32)
            }
            .navigationTitle("Add Friend")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func addFriend() {
        isAdding = true
        addError = nil
        Task {
            do {
                let user = try await viewModel.addFriend(byUsername: username)
                let friendName = user.username.map { "@\($0)" } ?? user.displayName
                viewModel.createDM(with: user.id, friendName: friendName)
                dismiss()
            } catch {
                addError = error.localizedDescription
            }
            isAdding = false
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthService.shared)
}