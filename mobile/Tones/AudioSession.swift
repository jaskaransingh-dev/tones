import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioSession: NSObject, ObservableObject {
    @Published private(set) var isRecording = false
    @Published private(set) var currentlyPlayingId: String? = nil
    @Published private(set) var playbackProgress: Double = 0
    @Published private(set) var level: Double = 0

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var meterTimer: Timer?
    private var playbackTimer: Timer?
    private var currentPlayingURL: URL?
    private var onPlaybackFinished: (() -> Void)?

    override init() {
        super.init()
    }

    func startRecording() async throws {
        try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try AVAudioSession.sharedInstance().setActive(true)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("tune_\(UUID().uuidString).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.delegate = nil
        recorder?.isMeteringEnabled = true
        recorder?.record()
        isRecording = true
        startMetering()
    }

    func stopRecording() -> (url: URL?, duration: TimeInterval?) {
        guard let rec = recorder else { return (nil, nil) }
        rec.stop()
        isRecording = false
        stopMetering()
        let url = rec.url
        let duration = rec.currentTime
        return (url, duration)
    }

    func play(url: URL, messageId: String? = nil, onFinished: (() -> Void)? = nil) {
        stopPlayback()
        currentPlayingURL = url
        onPlaybackFinished = onFinished
        currentlyPlayingId = messageId

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try AVAudioSession.sharedInstance().setActive(true)

            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.play()
            startPlaybackProgress()
        } catch {
            print("Playback failed: \(error)")
            currentlyPlayingId = nil
            onPlaybackFinished?()
            onPlaybackFinished = nil
        }
    }

    func stopPlayback() {
        player?.stop()
        player = nil
        currentlyPlayingId = nil
        playbackProgress = 0
        stopPlaybackProgress()
        onPlaybackFinished = nil
    }

    func pausePlayback() {
        player?.pause()
    }

    func resumePlayback() {
        player?.play()
    }

    func seekTo(_ fraction: Double) {
        guard let player else { return }
        let time = fraction * player.duration
        player.currentTime = time
    }

    var isPlaying: Bool {
        currentlyPlayingId != nil
    }

    var duration: TimeInterval {
        player?.duration ?? 0
    }

    var currentTime: TimeInterval {
        player?.currentTime ?? 0
    }

    private func startMetering() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let recorder = self.recorder, recorder.isRecording else { return }
            recorder.updateMeters()
            let avg = Double(recorder.averagePower(forChannel: 0))
            let norm = max(0.0, (avg + 50.0) / 50.0)
            Task { @MainActor in
                self.level = norm
            }
        }
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
        level = 0
    }

    private func startPlaybackProgress() {
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, let player = self.player else { return }
            if player.duration > 0 {
                Task { @MainActor in
                    self.playbackProgress = player.currentTime / player.duration
                }
            }
        }
    }

    private func stopPlaybackProgress() {
        playbackTimer?.invalidate()
        playbackTimer = nil
    }
}

extension AudioSession: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.currentlyPlayingId = nil
            self.playbackProgress = 0
            self.stopPlaybackProgress()
            self.onPlaybackFinished?()
            self.onPlaybackFinished = nil
        }
    }
}