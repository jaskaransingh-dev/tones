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
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                if localChat.tunes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "waveform.circle")
                            .font(.system(size: 50))
                            .foregroundStyle(Color.yellow.opacity(0.6))

                        Text("No tones yet")
                            .font(.headline)
                            .foregroundStyle(.gray)

                        Text("Tap the mic to record")
                            .font(.subheadline)
                            .foregroundStyle(.gray.opacity(0.7))
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List {
                        ForEach(localChat.tunes) { tune in
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(tune.heard ? Color.gray.opacity(0.3) : Color.yellow.opacity(0.8))
                                    .frame(width: 10, height: 10)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tune.sender)
                                        .font(.caption)
                                        .foregroundStyle(.gray)

                                    Text("\(Int(tune.duration))s")
                                        .font(.caption2)
                                        .foregroundStyle(.gray.opacity(0.7))
                                }

                                Spacer()

                                Button(action: { audio.play(url: tune.audioURL) }) {
                                    Image(systemName: audio.isPlaying && tune.id == localChat.tunes.last?.id ? "pause.circle.fill" : "play.circle.fill")
                                        .font(.title)
                                        .foregroundStyle(Color.yellow.opacity(0.8))
                                }
                            }
                            .padding(.vertical, 8)
                            .listRowBackground(Color.white)
                        }
                    }
                    .listStyle(.plain)
                }

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
        }
        .navigationTitle(localChat.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
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
                ZStack {
                    Circle()
                        .fill(isRecording ? Color.red : Color.yellow.opacity(0.8))
                        .frame(width: 50, height: 50)

                    Image(systemName: isRecording ? "stop.fill" : "mic.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(isRecording ? "Tap to end" : "Tap to speak")
                        .font(.headline)
                        .foregroundStyle(.black)

                    if isRecording {
                        ProgressView(value: min(level, 1.0))
                            .progressViewStyle(.linear)
                            .tint(Color.yellow.opacity(0.8))
                    }
                }

                Spacer()

                Text(isRecording ? "Recording..." : "Ready")
                    .font(.caption)
                    .foregroundStyle(.gray)
            }
            .padding()
            .background(Color.yellow.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

@available(iOS 16.0, *)
#Preview {
    let vm = HomeViewModel()
    vm.createSampleData()
    return NavigationStack { ChatView(chat: vm.chats[0], homeViewModel: vm) }
}