import SwiftUI

struct ChatView: View {
    let chat: Chat
    @ObservedObject var homeViewModel: HomeViewModel
    @StateObject private var audio = AudioSession()
    @State private var localChat: Chat

    init(chat: Chat, homeViewModel: HomeViewModel) {
        self.chat = chat
        self.homeViewModel = homeViewModel
        _localChat = State(initialValue: chat)
    }

    var body: some View {
        VStack(spacing: 0) {
            List {
                ForEach(localChat.tunes) { tune in
                    HStack(spacing: 12) {
                        Circle().fill(tune.heard ? Color.gray.opacity(0.3) : .blue).frame(width: 10, height: 10)
                        VStack(alignment: .leading) {
                            Text(tune.sender).font(.caption).foregroundStyle(.secondary)
                            Text("\(Int(tune.duration))s")
                        }
                        Spacer()
                        Button(action: { audio.play(url: tune.audioURL) }) {
                            Image(systemName: audio.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.title2)
                        }
                    }
                }
            }
            .listStyle(.plain)

            RecordBar(isRecording: audio.isRecording, level: audio.level) {
                if audio.isRecording {
                    audio.stopRecording { url, dur in
                        if let url, let dur {
                            let new = Tune(id: UUID(), sender: "You", date: Date(), audioURL: url, duration: dur, heard: true)
                            localChat.tunes.append(new)
                            homeViewModel.update(chat: localChat)
                        }
                    }
                } else {
                    Task { try? await audio.startRecording() }
                }
            }
            .padding()
        }
        .navigationTitle(localChat.title)
        .onAppear {
            // Auto-play the latest incoming tune if present
            if let last = localChat.tunes.last { audio.play(url: last.audioURL) }
        }
    }
}

struct RecordBar: View {
    let isRecording: Bool
    let level: Double
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: isRecording ? "stop.circle.fill" : "mic.circle.fill")
                    .font(.largeTitle)
                VStack(alignment: .leading) {
                    Text(isRecording ? "Tap to end" : "Tap to speak")
                        .font(.headline)
                    ProgressView(value: level)
                        .progressViewStyle(.linear)
                        .tint(.blue)
                }
                Spacer()
            }
            .padding()
            .background(.thinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let vm = HomeViewModel()
    vm.createSampleData()
    return NavigationStack { ChatView(chat: vm.chats[0], homeViewModel: vm) }
}
