import SwiftUI

struct ChatView: View {
    let chat: LocalChat
    @ObservedObject var viewModel: HomeViewModel
    @StateObject private var audio = AudioSession()
    @StateObject private var recorder = AudioSession()
    @State private var messages: [LocalMessage] = []
    @State private var isRecording = false
    @State private var playbackIndex: Int? = nil
    @State private var showSignOutConfirm = false

    var body: some View {
        ZStack {
            Color.white.ignoresSafeArea()

            VStack(spacing: 0) {
                if messages.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "waveform.circle")
                            .font(.system(size: 50))
                            .foregroundStyle(Color.yellow.opacity(0.6))

                        Text("No tones yet")
                            .font(.headline)
                            .foregroundStyle(.gray)

                        Text("Tap the mic to start talking")
                            .font(.subheadline)
                            .foregroundStyle(.gray.opacity(0.7))
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 8) {
                                ForEach(Array(messages.enumerated()), id: \.element.id) { index, msg in
                                    MessageRow(
                                        message: msg,
                                        isPlaying: audio.currentlyPlayingId == msg.id,
                                        progress: audio.currentlyPlayingId == msg.id ? audio.playbackProgress : 0,
                                        isMine: msg.senderId == AuthService.shared.currentUser?.id,
                                        onTap: {
                                            playFrom(index: index)
                                        },
                                        onSeek: { fraction in
                                            audio.seekTo(fraction)
                                        }
                                    )
                                    .id(msg.id)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .onChange(of: messages.count) { _, _ in
                            if let last = messages.last {
                                withAnimation {
                                    proxy.scrollTo(last.id, anchor: .bottom)
                                }
                            }
                        }
                    }
                }

                RecordBar(isRecording: isRecording, level: recorder.level) {
                    if isRecording {
                        let result = recorder.stopRecording()
                        isRecording = false
                        if let url = result.url, let dur = result.duration, dur > 0.3 {
                            saveRecording(url: url, duration: dur)
                        }
                    } else {
                        audio.stopPlayback()
                        playbackIndex = nil
                        Task {
                            do {
                                try await recorder.startRecording()
                                isRecording = true
                            } catch {
                                print("Recording failed: \(error)")
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
        }
        .navigationTitle(chat.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(action: { playAllFromBeginning() }) {
                        Label("Play all", systemImage: "play.circle")
                    }
                    Divider()
                    Button(role: .destructive, action: { showSignOutConfirm = true }) {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(.gray)
                }
            }
        }
        .alert("Sign out?", isPresented: $showSignOutConfirm) {
            Button("Sign out", role: .destructive) { AuthService.shared.logout() }
            Button("Cancel", role: .cancel) {}
        }
        .onAppear {
            messages = LocalStorage.shared.loadMessages(chat.id)
        }
    }

    private func saveRecording(url: URL, duration: TimeInterval) {
        let fileName = "\(chat.id)_\(UUID().uuidString).m4a"
        let destDir = LocalStorage.shared.documentsPath.appendingPathComponent("audio", isDirectory: true)
        let destURL = destDir.appendingPathComponent(fileName)
        try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        try? FileManager.default.moveItem(at: url, to: destURL)

        let msg = LocalMessage(
            chatId: chat.id,
            senderId: AuthService.shared.currentUser?.id ?? "unknown",
            senderName: AuthService.shared.currentUser?.displayName ?? "You",
            audioPath: "audio/\(fileName)",
            duration: duration
        )
        LocalStorage.shared.addMessage(msg)
        messages.append(msg)
    }

    private func playFrom(index: Int) {
        guard index < messages.count else { return }
        guard let url = messages[index].audioURL else { return }

        playbackIndex = index
        audio.stopPlayback()
        LocalStorage.shared.markMessageHeard(messages[index].id, chatId: chat.id)
        messages[index].heard = true

        audio.play(url: url, messageId: messages[index].id) {
            let nextIndex = index + 1
            if nextIndex < messages.count {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    playFrom(index: nextIndex)
                }
            } else {
                playbackIndex = nil
            }
        }
    }

    private func playAllFromBeginning() {
        if !messages.isEmpty {
            playFrom(index: 0)
        }
    }
}

struct MessageRow: View {
    let message: LocalMessage
    let isPlaying: Bool
    let progress: Double
    let isMine: Bool
    let onTap: () -> Void
    let onSeek: (Double) -> Void

    var body: some View {
        HStack(spacing: 10) {
            if !isMine {
                Circle()
                    .fill(Color.yellow.opacity(0.8))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text(String(message.senderName.prefix(1)))
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.black)
                    )
            }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                if !isMine {
                    Text(message.senderName)
                        .font(.caption2)
                        .foregroundStyle(.gray)
                }

                HStack(spacing: 6) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.yellow.opacity(0.9))

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.gray.opacity(0.2))
                                .frame(height: 4)

                            if isPlaying {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.yellow.opacity(0.8))
                                    .frame(width: geo.size.width * CGFloat(progress), height: 4)
                            }
                        }
                        .frame(height: 4)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let fraction = max(0, min(1, value.location.x / geo.size.width))
                                    onSeek(fraction)
                                }
                        )
                    }
                    .frame(height: 4)

                    Text(String(format: "%.0fs", message.duration))
                        .font(.caption2)
                        .foregroundStyle(.gray)
                        .frame(width: 28)
                }

                if !message.heard && !isMine {
                    Text("NEW")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.yellow)
                        .clipShape(Capsule())
                }
            }

            if isMine {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 32, height: 32)
                    .overlay(
                        Text("You")
                            .font(.caption2)
                            .foregroundStyle(.gray)
                    )
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isMine ? Color.gray.opacity(0.08) : Color.yellow.opacity(0.06))
        )
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
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
                    Text(isRecording ? "Tap to stop" : "Hold to talk")
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