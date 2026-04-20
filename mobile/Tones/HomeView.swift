import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject var authService: AuthService
    @State private var showingAddChat = false

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

                        Button(action: { showingAddChat = true }) {
                            Text("Start a conversation")
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
                            NavigationLink(destination: ChatView(chat: chat, homeViewModel: viewModel)) {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(chat.isGroup ? Color.purple : Color.yellow.opacity(0.8))
                                        .frame(width: 12, height: 12)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(chat.title)
                                            .font(.headline)
                                            .foregroundStyle(.black)

                                        Text(chat.lastTuneDescription)
                                            .font(.caption)
                                            .foregroundStyle(.gray)
                                    }

                                    Spacer()

                                    if chat.unheardCount > 0 {
                                        Text("\(chat.unheardCount)")
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundStyle(.white)
                                            .padding(6)
                                            .background(Circle())
                                            .background(Color.yellow.opacity(0.9))
                                    }
                                }
                                .padding(.vertical, 4)
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
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: { viewModel.addFriendPrompt() }) {
                            Label("Add friend", systemImage: "person.badge.plus")
                        }
                        Button(action: { viewModel.addGroupPrompt() }) {
                            Label("New group", systemImage: "person.3.sequence.badge.plus")
                        }
                        Divider()
                        Button(role: .destructive, action: { authService.logout() }) {
                            Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Color.yellow.opacity(0.9))
                    }
                }
            }
            .onAppear { viewModel.createSampleData() }
            .sheet(isPresented: $showingAddChat) {
                AddChatView(viewModel: viewModel)
            }
        }
    }
}

struct AddChatView: View {
    @ObservedObject var viewModel: HomeViewModel
    @Environment(\.dismiss) var dismiss
    @State private var newChatName = ""
    @State private var isGroupChat = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color.white.ignoresSafeArea()

                VStack(spacing: 24) {
                    Toggle("Group chat", isOn: $isGroupChat)
                        .tint(Color.yellow.opacity(0.8))

                    TextField(isGroupChat ? "Group name" : "Friend's name", text: $newChatName)
                        .textFieldStyle(.roundedBorder)
                        .padding(.horizontal)

                    Button(action: {
                        if isGroupChat {
                            viewModel.chats.insert(Chat.group(title: newChatName, members: []), at: 0)
                        } else {
                            viewModel.chats.insert(Chat.friends(name: newChatName), at: 0)
                        }
                        dismiss()
                    }) {
                        Text("Create")
                            .fontWeight(.semibold)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.yellow.opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(newChatName.isEmpty)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("New conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthService.shared)
}