import SwiftUI
import Combine

struct ChatView: View {
    let chat: LocalChat
    @ObservedObject var viewModel: HomeViewModel

    @StateObject private var audio = AudioSession()
    @StateObject private var recorder = AudioSession()

    @State private var messages: [LocalMessage] = []
    @State private var playingIndex: Int? = nil
    @State private var isRecording = false
    @State private var isConnecting = false
    @Environment(\.dismiss) private var dismiss

    private var myId: String { AuthService.shared.currentUser?.id ?? "" }
    private var friendName: String {
        let n = chat.name
        return n.hasPrefix("@") ? String(n.dropFirst()) : n
    }
    private var friendInitial: String { String(friendName.prefix(1)).uppercased() }

    var body: some View {
        ZStack {
            WarmBackground()

            if isRecording {
                recordingCallView
                    .transition(.opacity)
                    .zIndex(2)
            } else if let idx = playingIndex {
                playingCallView(index: idx)
                    .transition(.opacity)
                    .zIndex(2)
            } else {
                idleView
                    .transition(.opacity)
            }

            if isConnecting {
                connectingOverlay
                    .transition(.opacity)
                    .zIndex(3)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isRecording)
        .animation(.easeInOut(duration: 0.15), value: playingIndex)
        .animation(.easeInOut(duration: 0.12), value: isConnecting)
        .navigationTitle(friendName.lowercased())
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(Color.warmCream, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: { dismiss() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("back")
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Color.warmDark.opacity(0.6))
                }
            }
        }
        .onAppear {
            messages = LocalStorage.shared.loadMessages(chat.id)
            audio.prewarm()
            recorder.prewarm()
            Task {
                await syncRemoteMessages()
                checkForAutoPlay()
            }
        }
        .onDisappear {
            audio.stopPlayback()
            _ = recorder.stopRecording()
        }
    }

    // MARK: - Playing (phone call style)

    private func playingCallView(index: Int) -> some View {
        let msg = index < messages.count ? messages[index] : nil
        let isMe = msg?.senderId == myId
        let remaining = (msg?.duration ?? 0) * (1 - audio.playbackProgress)

        return ZStack {
            Color.warmCream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Avatar with pulse rings
                ZStack {
                    Circle()
                        .stroke(Color.warmCoral.opacity(0.15), lineWidth: 1)
                        .frame(width: 240, height: 240)

                    Circle()
                        .stroke(Color.warmCoral.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 186, height: 186)

                    Circle()
                        .fill(Color.warmPeach)
                        .frame(width: 130, height: 130)

                    Text(isMe ? "Y" : friendInitial)
                        .font(.system(size: 50, weight: .light))
                        .foregroundStyle(Color.warmCoral)
                }
                .padding(.bottom, 28)

                Text(isMe ? "you" : friendName.lowercased())
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(Color.warmBrown)
                    .tracking(5)

                // Animated wave bars
                AudioWaveBars(isActive: true)
                    .frame(height: 44)
                    .padding(.top, 20)
                    .padding(.bottom, 14)

                // Countdown
                Text(String(format: "%.0f", max(0, remaining)))
                    .font(.system(size: 62, weight: .ultraLight, design: .monospaced))
                    .foregroundStyle(Color.warmDark)
                    .contentTransition(.numericText())

                Text("\(index + 1) / \(messages.count)")
                    .font(.system(size: 11, weight: .light))
                    .foregroundStyle(Color.warmBrown.opacity(0.7))
                    .tracking(4)
                    .padding(.top, 10)

                Spacer()

                // Hang up = stop
                Button(action: {
                    audio.stopPlayback()
                    playingIndex = nil
                }) {
                    hangUpButton
                }
                .padding(.bottom, 56)
            }
        }
    }

    // MARK: - Recording (phone call style)

    private var recordingCallView: some View {
        ZStack {
            Color.warmCream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.callGreen.opacity(0.07))
                        .frame(width: 250, height: 250)
                        .scaleEffect(1 + recorder.level * 0.45)
                        .animation(.easeOut(duration: 0.08), value: recorder.level)

                    Circle()
                        .fill(Color.callGreen.opacity(0.13))
                        .frame(width: 175, height: 175)
                        .scaleEffect(1 + recorder.level * 0.28)
                        .animation(.easeOut(duration: 0.1), value: recorder.level)

                    Circle()
                        .fill(Color.callGreen)
                        .frame(width: 104, height: 104)
                        .shadow(color: Color.callGreen.opacity(0.45), radius: 18, y: 6)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 38))
                        .foregroundStyle(.white)
                }

                Text("tap to send")
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(Color.warmBrown.opacity(0.8))
                    .tracking(5)
                    .padding(.top, 32)

                Spacer()

                Button(action: stopAndSend) {
                    hangUpButton
                }
                .padding(.bottom, 56)
            }
            .contentShape(Rectangle())
            .onTapGesture { stopAndSend() }
        }
    }

    // MARK: - Idle

    private var idleView: some View {
        VStack(spacing: 0) {
            if messages.isEmpty {
                Spacer()
                VStack(spacing: 20) {
                    ZStack {
                        Circle()
                            .fill(Color.warmPeach.opacity(0.55))
                            .frame(width: 120, height: 120)
                        Text(friendInitial)
                            .font(.system(size: 48, weight: .light))
                            .foregroundStyle(Color.warmCoral)
                    }
                    Text("say hi to \(friendName.lowercased())")
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(Color.warmBrown)
                }
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 4) {
                            ForEach(Array(messages.enumerated()), id: \.element.id) { index, msg in
                                ToneBubble(
                                    message: msg,
                                    isPlaying: audio.currentlyPlayingId == msg.id,
                                    progress: audio.currentlyPlayingId == msg.id ? audio.playbackProgress : 0,
                                    isMine: msg.senderId == myId,
                                    onTap: { playFrom(index: index, autoRecordAfter: true, chain: false) }
                                )
                                .id(msg.id)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 120)
                    }
                    .onChange(of: messages.count) { _, _ in
                        if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                    .onAppear {
                        if let last = messages.last { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
            }

            Button(action: startManualRecording) {
                ZStack {
                    Circle()
                        .fill(Color.callGreen)
                        .frame(width: 72, height: 72)
                        .shadow(color: Color.callGreen.opacity(0.4), radius: 16, y: 6)
                    Image(systemName: "mic.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(.white)
                }
            }
            .padding(.bottom, 44)
        }
    }

    // MARK: - Connecting overlay (brief ring expand on call start)

    private var connectingOverlay: some View {
        ZStack {
            Color.warmCream.opacity(0.92).ignoresSafeArea()

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(Color.warmCoral.opacity(0.25), lineWidth: 1.5)
                        .frame(width: 140, height: 140)
                        .scaleEffect(isConnecting ? 1.15 : 0.8)
                        .opacity(isConnecting ? 0 : 1)
                        .animation(.easeOut(duration: 0.7).repeatForever(autoreverses: false), value: isConnecting)
                    Circle()
                        .fill(Color.warmPeach)
                        .frame(width: 96, height: 96)
                    Image(systemName: "phone.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.warmCoral)
                }
                Text("connecting")
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(Color.warmBrown.opacity(0.8))
                    .tracking(6)
                    .textCase(.uppercase)
            }
        }
    }

    // MARK: - Shared UI

    private var hangUpButton: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.88))
                .frame(width: 72, height: 72)
                .shadow(color: Color.red.opacity(0.3), radius: 14, y: 4)
            Image(systemName: "phone.down.fill")
                .font(.system(size: 26))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Logic

    private func checkForAutoPlay() {
        let unheard = messages.filter { !$0.heard && $0.senderId != myId }
        guard let first = unheard.first,
              let idx = messages.firstIndex(where: { $0.id == first.id }) else { return }
        Task {
            try? await Task.sleep(nanoseconds: 80_000_000)
            await MainActor.run {
                playFrom(index: idx, autoRecordAfter: true, chain: true)
            }
        }
    }

    private func playFrom(index: Int, autoRecordAfter: Bool, chain: Bool) {
        guard index < messages.count else {
            playingIndex = nil
            if autoRecordAfter { startAutoRecording() }
            return
        }

        guard let url = messages[index].audioURL else {
            if chain {
                playFrom(index: index + 1, autoRecordAfter: autoRecordAfter, chain: chain)
            } else {
                playingIndex = nil
                if autoRecordAfter { startAutoRecording() }
            }
            return
        }

        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        isConnecting = true
        playingIndex = index
        LocalStorage.shared.markMessageHeard(messages[index].id, chatId: chat.id)
        messages[index].heard = true

        audio.play(url: url, messageId: messages[index].id) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                let hasNext = index + 1 < self.messages.count
                if chain && hasNext {
                    self.playFrom(index: index + 1, autoRecordAfter: autoRecordAfter, chain: chain)
                } else {
                    self.playingIndex = nil
                    if autoRecordAfter { self.startAutoRecording() }
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            self.isConnecting = false
        }
    }

    private func startAutoRecording() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isConnecting = true
        isRecording = true
        Task {
            do { try await recorder.startRecording() }
            catch { isRecording = false }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            self.isConnecting = false
        }
    }

    private func startManualRecording() {
        audio.stopPlayback()
        playingIndex = nil
        startAutoRecording()
    }

    private func stopAndSend() {
        let result = recorder.stopRecording()
        isRecording = false
        guard let url = result.url, let dur = result.duration, dur > 0.5 else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        let msgId = UUID().uuidString
        saveAndUpload(url: url, duration: dur, messageId: msgId)
    }

    private func saveAndUpload(url: URL, duration: TimeInterval, messageId: String) {
        let fileName = "\(chat.id)_\(messageId).m4a"
        let destDir = LocalStorage.shared.documentsPath.appendingPathComponent("audio", isDirectory: true)
        let destURL = destDir.appendingPathComponent(fileName)
        try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
        try? FileManager.default.moveItem(at: url, to: destURL)

        let msg = LocalMessage(
            id: messageId,
            chatId: chat.id,
            senderId: myId,
            senderName: AuthService.shared.currentUser?.username.map { "@\($0)" } ?? "you",
            audioPath: "audio/\(fileName)",
            duration: duration,
            heard: true
        )
        LocalStorage.shared.addMessage(msg)
        messages.append(msg)

        Task {
            do {
                let audioData = try Data(contentsOf: destURL)
                let base64 = audioData.base64EncodedString()
                let result = try await APIClient.shared.sendAudioMessage(
                    chatId: chat.id,
                    messageId: messageId,
                    audioBase64: base64,
                    durationMs: Int(duration * 1000)
                )
                LocalStorage.shared.setLastSyncedAt(chatId: chat.id, ts: result.created_at)
            } catch {
                print("Upload failed: \(error)")
            }
        }
    }

    private func syncRemoteMessages() async {
        let since = LocalStorage.shared.lastSyncedAt(chatId: chat.id)
        do {
            let remote = try await APIClient.shared.listMessages(chatId: chat.id, since: since)
            let existingIds = Set(messages.map { $0.id })
            var latestTs = since
            for r in remote {
                latestTs = max(latestTs, r.created_at)
                guard !existingIds.contains(r.id) else { continue }
                guard let data = Data(base64Encoded: r.audio_base64) else { continue }
                let fileName = "\(chat.id)_\(r.id).m4a"
                let destDir = LocalStorage.shared.documentsPath.appendingPathComponent("audio", isDirectory: true)
                let destURL = destDir.appendingPathComponent(fileName)
                try? FileManager.default.createDirectory(at: destDir, withIntermediateDirectories: true)
                try? data.write(to: destURL)
                let senderName = r.sender_username.map { "@\($0)" } ?? "user"
                let msg = LocalMessage(
                    id: r.id,
                    chatId: chat.id,
                    senderId: r.sender_id,
                    senderName: senderName,
                    audioPath: "audio/\(fileName)",
                    duration: Double(r.duration_ms) / 1000.0,
                    createdAt: r.created_at / 1000,
                    heard: r.sender_id == myId
                )
                LocalStorage.shared.addMessage(msg)
                messages.append(msg)
            }
            messages.sort { $0.createdAt < $1.createdAt }
            LocalStorage.shared.setLastSyncedAt(chatId: chat.id, ts: latestTs)
        } catch {
            print("Sync failed: \(error)")
        }
    }
}

// MARK: - ToneBubble

struct ToneBubble: View {
    let message: LocalMessage
    let isPlaying: Bool
    let progress: Double
    let isMine: Bool
    let onTap: () -> Void

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 64) }

            Button(action: onTap) {
                HStack(spacing: 10) {
                    if !isMine {
                        iconCircle
                    }

                    VStack(alignment: isMine ? .trailing : .leading, spacing: 5) {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(Color.warmPeach.opacity(0.6))
                                    .frame(height: 2.5)
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(isMine ? Color.warmCoral : Color.callGreen)
                                    .frame(width: isPlaying ? geo.size.width * CGFloat(progress) : 0, height: 2.5)
                                    .animation(.linear(duration: 0.05), value: progress)
                            }
                        }
                        .frame(height: 2.5)

                        HStack(spacing: 5) {
                            if !message.heard && !isMine {
                                Circle()
                                    .fill(Color.callGreen)
                                    .frame(width: 5, height: 5)
                            }
                            Text(String(format: "%.0fs", message.duration))
                                .font(.system(size: 11, weight: .light))
                                .foregroundStyle(Color.warmBrown.opacity(0.8))
                        }
                    }
                    .frame(minWidth: 52)

                    if isMine {
                        iconCircle
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(isMine ? Color.warmPeach.opacity(0.6) : Color.white.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .shadow(color: Color.warmDark.opacity(0.05), radius: 4, y: 2)
            }
            .buttonStyle(PlainButtonStyle())

            if !isMine { Spacer(minLength: 64) }
        }
    }

    private var iconCircle: some View {
        ZStack {
            Circle()
                .fill(isMine ? Color.warmPeach : Color.warmCream)
                .frame(width: 34, height: 34)
            Image(systemName: isPlaying ? "speaker.wave.2.fill" : "play.fill")
                .font(.system(size: 11))
                .foregroundStyle(isMine ? Color.warmCoral : Color.callGreen)
        }
    }
}

// MARK: - AudioWaveBars

struct AudioWaveBars: View {
    let isActive: Bool
    @State private var phase: Double = 0
    private let ticker = Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<7, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.warmCoral)
                    .frame(width: 5, height: barHeight(for: i))
                    .animation(.easeInOut(duration: 0.1), value: phase)
            }
        }
        .onReceive(ticker) { _ in
            guard isActive else { return }
            phase += 0.28
        }
    }

    private func barHeight(for i: Int) -> CGFloat {
        let angle = phase + Double(i) * 0.9
        return 8 + CGFloat((sin(angle) + 1) / 2) * 30
    }
}

#Preview {
    NavigationStack {
        ChatView(chat: LocalChat(id: "1", name: "friend", type: "dm"), viewModel: HomeViewModel())
    }
}
