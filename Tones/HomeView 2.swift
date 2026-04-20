import SwiftUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if viewModel.chats.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "waveform.circle.fill")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 96, height: 96)
                            .foregroundStyle(.tint)
                            .opacity(0.9)
                        Text("Tune")
                            .font(.largeTitle.bold())
                        Text("Add friends. Tap a chat. Speak. Tap to end.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        Button(action: { viewModel.createSampleData() }) {
                            Label("Add a friend", systemImage: "person.badge.plus")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    List {
                        Section {
                            ForEach(viewModel.chats) { chat in
                                NavigationLink(value: chat.id) {
                                    HStack(spacing: 12) {
                                        Circle()
                                            .fill(chat.color)
                                            .frame(width: 36, height: 36)
                                            .overlay(Image(systemName: chat.isGroup ? "person.3.fill" : "person.fill").foregroundStyle(.white))
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(chat.title)
                                                .font(.headline)
                                            Text(chat.lastTuneDescription)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        if chat.unheardCount > 0 {
                                            Text("\(chat.unheardCount)")
                                                .font(.caption2.bold())
                                                .padding(6)
                                                .background(Capsule().fill(Color.blue.opacity(0.15)))
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Tune")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("New Friend", systemImage: "person.badge.plus") { viewModel.addFriendPrompt() }
                        Button("New Group", systemImage: "person.3") { viewModel.addGroupPrompt() }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .navigationDestination(for: UUID.self) { id in
                if let chat = viewModel.chat(id: id) {
                    ChatView(chat: chat, homeViewModel: viewModel)
                } else {
                    Text("Chat not found")
                }
            }
            .alert(item: $viewModel.pendingAlert) { alert in
                switch alert.kind {
                case .addFriend:
                    return Alert(title: Text("Friend added"), message: Text(alert.message ?? ""))
                case .addGroup:
                    return Alert(title: Text("Group created"), message: Text(alert.message ?? ""))
                }
            }
        }
    }
}

#Preview {
    HomeView()
}
