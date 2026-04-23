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
    @State private var tapeMessages: [LocalMessage] = []
    @State private var revealedTapeCount: Int = 0
    @State private var micPulse = false
    @State private var showEmptyGreeting = false
    @Environment(\.dismiss) private var dismiss

    private var myId: String { AuthService.shared.currentUser?.id ?? "" }
    private var friendName: String {
        let n = chat.name
        return n.hasPrefix("@") ? String(n.dropFirst()) : n
    }
    private var friendInitial: String { String(friendName.prefix(1)).uppercased() }
    private var friendAvatarURL: String? { chat.peerAvatarURL }

    var body: some View {
        ZStack {
            WarmBackground()

            if isRecording {
                recordingCallView
                    .transition(.opacity)
                    .zIndex(2)
            } else if playingIndex != nil {
                tapePlayerView
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

            let unheard = messages.filter { !$0.heard && $0.senderId != myId }
            if !unheard.isEmpty {
                checkForAutoPlay()
            } else if messages.isEmpty {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                        showEmptyGreeting = true
                    }
                }
                startAutoRecording()
            }

            Task {
                let hadNew = await syncRemoteMessages()
                if hadNew {
                    checkForAutoPlay()
                } else if messages.isEmpty {
                    startAutoRecording()
                }
            }
        }
        .onDisappear {
            audio.stopPlayback()
            _ = recorder.stopRecording()
            endPlayback()
        }
    }

    // MARK: - Tape Player

    private var tapePlayerView: some View {
        let currentMsg = playingIndex.flatMap { $0 < messages.count ? messages[$0] : nil }
        let remaining = (currentMsg?.duration ?? 0) * (1 - audio.playbackProgress)

        return ZStack {
            Color.warmCream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.warmPeach.opacity(0.3))
                        .frame(width: 180, height: 180)
                        .blur(radius: 2)

                    Circle()
                        .stroke(Color.warmCoral.opacity(0.12), lineWidth: 1)
                        .frame(width: 160, height: 160)

                    AvatarView(urlString: friendAvatarURL, initial: friendInitial, size: 88)
                }
                .padding(.bottom, 8)

                Text(friendName.lowercased())
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(Color.warmBrown)
                    .tracking(5)

                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 0) {
                            ForEach(0..<revealedTapeCount, id: \.self) { i in
                                let msg = tapeMessages[i]
                                let msgIndex = messages.firstIndex(where: { $0.id == msg.id })
                                let isNowPlaying = msgIndex == playingIndex

                                if i > 0 {
                                    tapeConnector
                                }

                                tapeSegment(message: msg, isPlaying: isNowPlaying, remaining: isNowPlaying ? remaining : msg.duration)
                                    .id("tape-\(i)")
                                    .transition(.asymmetric(
                                        insertion: .scale(scale: 0.85).combined(with: .opacity),
                                        removal: .opacity
                                    ))
                            }
                        }
                        .padding(.vertical, 20)
                    }
                    .frame(maxHeight: 320)
                    .onChange(of: revealedTapeCount) { _, newValue in
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                            proxy.scrollTo("tape-\(newValue - 1)", anchor: .bottom)
                        }
                    }
                }
                .padding(.top, 20)

                if tapeMessages.count > 1 {
                    let tapeIdx = playingIndex.flatMap { idx -> Int? in
                        (idx < messages.count) ? tapeMessages.firstIndex(where: { $0.id == messages[idx].id }) : nil
                    } ?? 0
                    Text("\(tapeIdx + 1) / \(tapeMessages.count)")
                        .font(.system(size: 11, weight: .light))
                        .foregroundStyle(Color.warmBrown.opacity(0.5))
                        .tracking(4)
                        .padding(.top, 8)
                }

                Spacer()

                Button(action: stopAndDismiss) {
                    hangUpButton
                }
                .padding(.bottom, 56)
            }
        }
    }

    private func tapeSegment(message: LocalMessage, isPlaying: Bool, remaining: Double) -> some View {
        Group {
            if isPlaying {
                VStack(spacing: 10) {
                    AudioWaveBars(isActive: true)
                        .frame(height: 36)

                    Text(String(format: "%.0f", max(0, remaining)))
                        .font(.system(size: 40, weight: .ultraLight, design: .monospaced))
                        .foregroundStyle(Color.warmDark)
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color.warmPeach.opacity(0.5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color.warmCoral.opacity(0.3), lineWidth: 1)
                        )
                )
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Color.callGreen)

                    Text(String(format: "%.0fs", message.duration))
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Color.warmBrown.opacity(0.6))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(Color.warmPeach.opacity(0.3))
                )
            }
        }
    }

    private var tapeConnector: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Color.warmCoral.opacity(0.2))
                .frame(width: 4, height: 4)
            Rectangle()
                .fill(Color.warmCoral.opacity(0.15))
                .frame(width: 1, height: 8)
            Circle()
                .fill(Color.warmCoral.opacity(0.3))
                .frame(width: 5, height: 5)
            Rectangle()
                .fill(Color.warmCoral.opacity(0.15))
                .frame(width: 1, height: 8)
            Circle()
                .fill(Color.warmCoral.opacity(0.2))
                .frame(width: 4, height: 4)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Recording (phone call style)

    private var recordingCallView: some View {
        ZStack {
            Color.warmCream.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Color.callGreen.opacity(0.06))
                        .frame(width: 280, height: 280)
                        .scaleEffect(1 + recorder.level * 0.3)
                        .animation(.easeOut(duration: 0.12), value: recorder.level)

                    Circle()
                        .fill(Color.callGreen.opacity(0.12))
                        .frame(width: 200, height: 200)
                        .scaleEffect(1 + recorder.level * 0.2)
                        .animation(.easeOut(duration: 0.15), value: recorder.level)

                    Circle()
                        .fill(Color.callGreen)
                        .frame(width: 110, height: 110)
                        .shadow(color: Color.callGreen.opacity(0.4), radius: 20, y: 8)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(.white)
                }

                Text("tap to send")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(Color.warmBrown.opacity(0.7))
                    .tracking(4)
                    .padding(.top, 28)

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
                VStack(spacing: 24) {
                    AvatarView(urlString: friendAvatarURL, initial: friendInitial, size: 100)
                        .scaleEffect(showEmptyGreeting ? 1.0 : 0.8)

                    Text("say hi to \(friendName.lowercased())")
                        .font(.system(size: 18, weight: .light))
                        .foregroundStyle(Color.warmBrown)
                        .opacity(showEmptyGreeting ? 1 : 0)

                    Text("tap to start talking")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Color.warmBrown.opacity(0.5))
                        .opacity(showEmptyGreeting ? 1 : 0)
                }
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: 6) {
                            ForEach(Array(messages.enumerated()), id: \.element.id) { index, msg in
                                ToneBubble(
                                    message: msg,
                                    isPlaying: audio.currentlyPlayingId == msg.id,
                                    progress: audio.currentlyPlayingId == msg.id ? audio.playbackProgress : 0,
                                    isMine: msg.senderId == myId,
                                    onTap: {
                                        tapeMessages = [msg]
                                        revealedTapeCount = 1
                                        playFrom(index: index)
                                    }
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
                        .fill(Color.callGreen.opacity(0.1))
                        .frame(width: 88, height: 88)
                        .scaleEffect(micPulse ? 1.15 : 1.0)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: micPulse)

                    Circle()
                        .fill(Color.callGreen)
                        .frame(width: 64, height: 64)
                        .shadow(color: Color.callGreen.opacity(0.35), radius: 12, y: 4)

                    Image(systemName: "mic.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white)
                }
            }
            .padding(.bottom, 44)
            .onAppear { micPulse = true }
        }
    }

    // MARK: - Connecting overlay

    private var connectingOverlay: some View {
        ZStack {
            Color.warmCream.opacity(0.92).ignoresSafeArea()

            VStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(Color.warmCoral.opacity(0.15), lineWidth: 1.5)
                        .frame(width: 140, height: 140)
                        .scaleEffect(isConnecting ? 1.15 : 0.8)
                        .opacity(isConnecting ? 0 : 1)
                        .animation(.easeOut(duration: 0.7).repeatForever(autoreverses: false), value: isConnecting)

                    Circle()
                        .fill(Color.warmPeach)
                        .frame(width: 100, height: 100)

                    AvatarView(urlString: friendAvatarURL, initial: friendInitial, size: 100)
                }
                Text("connecting")
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(Color.warmBrown.opacity(0.7))
                    .tracking(6)
                    .textCase(.uppercase)
            }
        }
    }

    // MARK: - Shared UI

    private var hangUpButton: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.85))
                .frame(width: 68, height: 68)
                .shadow(color: Color.red.opacity(0.25), radius: 14, y: 4)
            Image(systemName: "phone.down.fill")
                .font(.system(size: 24))
                .foregroundStyle(.white)
        }
    }

    // MARK: - Logic

    private func checkForAutoPlay() {
        let unheard = messages.filter { !$0.heard && $0.senderId != myId }
        guard !unheard.isEmpty else { return }
        tapeMessages = unheard
        revealedTapeCount = 1
        guard let first = unheard.first,
              let idx = messages.firstIndex(where: { $0.id == first.id }) else { return }
        Task {
            try? await Task.sleep(nanoseconds: 80_000_000)
            await MainActor.run {
                playFrom(index: idx)
            }
        }
    }

    private func playFrom(index: Int) {
        guard index < messages.count else {
            endPlayback()
            return
        }

        guard let url = messages[index].audioURL else {
            advanceTape()
            return
        }

        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        isConnecting = true
        playingIndex = index
        LocalStorage.shared.markMessageHeard(messages[index].id, chatId: chat.id)
        messages[index].heard = true
        Task {
            try? await APIClient.shared.markHeard(chatId: chat.id, messageIds: [messages[index].id])
        }

        if let tapeIdx = tapeMessages.firstIndex(where: { $0.id == messages[index].id }) {
            if tapeIdx + 1 > revealedTapeCount {
                revealedTapeCount = tapeIdx + 1
            }
        }

        audio.play(url: url, messageId: messages[index].id) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.onPlaybackFinished()
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            self.isConnecting = false
        }
    }

    private func onPlaybackFinished() {
        if tapeMessages.count > 1 {
            advanceTape()
        } else {
            endPlayback()
            startAutoRecording()
        }
    }

    private func advanceTape() {
        guard let currentIdx = playingIndex,
              currentIdx < messages.count else {
            endPlayback()
            startAutoRecording()
            return
        }
        let currentId = messages[currentIdx].id
        guard let currentTapeIdx = tapeMessages.firstIndex(where: { $0.id == currentId }) else {
            endPlayback()
            startAutoRecording()
            return
        }

        let nextTapeIdx = currentTapeIdx + 1
        if nextTapeIdx < tapeMessages.count {
            let nextMsg = tapeMessages[nextTapeIdx]
            guard let nextIdx = messages.firstIndex(where: { $0.id == nextMsg.id }) else {
                endPlayback()
                startAutoRecording()
                return
            }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                revealedTapeCount = nextTapeIdx + 1
            }
            playFrom(index: nextIdx)
        } else {
            endPlayback()
            startAutoRecording()
        }
    }

    private func endPlayback() {
        playingIndex = nil
        tapeMessages = []
        revealedTapeCount = 0
    }

    private func stopAndDismiss() {
        audio.stopPlayback()
        endPlayback()
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
        endPlayback()
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

    @discardableResult
    private func syncRemoteMessages() async -> Bool {
        let since = LocalStorage.shared.lastSyncedAt(chatId: chat.id)
        do {
            let remote = try await APIClient.shared.listMessages(chatId: chat.id, since: since)
            let existingIds = Set(messages.map { $0.id })
            var latestTs = since
            var foundNew = false
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
                    heard: r.heard == true || r.sender_id == myId
                )
                LocalStorage.shared.addMessage(msg)
                messages.append(msg)
                if !msg.heard && msg.senderId != myId { foundNew = true }
            }
            messages.sort { $0.createdAt < $1.createdAt }
            LocalStorage.shared.setLastSyncedAt(chatId: chat.id, ts: latestTs)
            return foundNew
        } catch {
            print("Sync failed: \(error)")
            return false
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
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.warmPeach.opacity(0.5))
                                    .frame(height: 3)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(isMine ? Color.warmCoral : Color.callGreen)
                                    .frame(width: isPlaying ? geo.size.width * CGFloat(progress) : (isMine ? geo.size.width * 0.6 : geo.size.width * 0.4), height: 3)
                                    .animation(.linear(duration: 0.05), value: progress)
                            }
                        }
                        .frame(height: 3)

                        HStack(spacing: 5) {
                            if !message.heard && !isMine {
                                Circle()
                                    .fill(Color.callGreen)
                                    .frame(width: 5, height: 5)
                            }
                            Text(String(format: "%.0fs", message.duration))
                                .font(.system(size: 11, weight: .light))
                                .foregroundStyle(Color.warmBrown.opacity(0.7))
                        }
                    }
                    .frame(minWidth: 52)

                    if isMine {
                        iconCircle
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(isMine ? Color.warmPeach.opacity(0.55) : Color.white.opacity(0.9))
                        .shadow(color: Color.warmDark.opacity(0.04), radius: 6, y: 3)
                )
            }
            .buttonStyle(PlainButtonStyle())

            if !isMine { Spacer(minLength: 64) }
        }
    }

    private var iconCircle: some View {
        ZStack {
            Circle()
                .fill(isMine ? Color.warmPeach : Color.warmCream)
                .frame(width: 36, height: 36)
                .shadow(color: Color.warmDark.opacity(0.06), radius: 3, y: 1)
            Image(systemName: isPlaying ? "speaker.wave.2.fill" : "play.fill")
                .font(.system(size: 12))
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
        HStack(spacing: 4) {
            ForEach(0..<9, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        LinearGradient(
                            colors: [Color.warmCoral, Color.warmCoral.opacity(0.6)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
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
        let angle = phase + Double(i) * 0.7
        return 6 + CGFloat((sin(angle) + 1) / 2) * 32
    }
}

#Preview {
    NavigationStack {
        ChatView(chat: LocalChat(id: "1", name: "friend", type: "dm"), viewModel: HomeViewModel())
    }
}