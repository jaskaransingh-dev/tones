import SwiftUI

struct ActiveTuneView: View {
    let chatId: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioManager = AudioManager()
    @State private var statusText = "loading..."
    
    var body: some View {
        ZStack {
            if audioManager.isPlaying {
                Color.blue.ignoresSafeArea()
            } else if audioManager.isRecording {
                Color.red.ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }
            
            Text(statusText)
                .font(.largeTitle)
                .foregroundStyle(.white)
                .bold()
                .multilineTextAlignment(.center)
                .padding()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if audioManager.isRecording {
                sendTune()
            }
        }
        .onAppear { startTuneSequence() }
        .toolbar(.hidden, for: .navigationBar)
    }
    
    private func startTuneSequence() {
        Task {
            statusText = "checking tunes..."
            let unplayedURLs = try? await NetworkManager.shared.fetchUnplayedTunes(chatId: chatId)
            if let urls = unplayedURLs, !urls.isEmpty {
                statusText = "playing..."
                playSequence(urls: urls, index: 0)
            } else {
                startRecording()
            }
        }
    }
    
    private func playSequence(urls: [URL], index: Int) {
        if index < urls.count {
            audioManager.playAudio(from: urls[index]) {
                self.playSequence(urls: urls, index: index + 1)
            }
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        statusText = "listening...\ntap screen to end"
        audioManager.startRecording()
    }
    
    private func sendTune() {
        statusText = "sending..."
        guard let fileURL = audioManager.stopRecording() else { return }
        Task {
            do {
                try await NetworkManager.shared.uploadTune(chatId: chatId, senderId: "me", fileURL: fileURL)
                await MainActor.run { dismiss() }
            } catch {
                statusText = "failed to send"
            }
        }
    }
}

#Preview {
    ActiveTuneView(chatId: "alice")
}
