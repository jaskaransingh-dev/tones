import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioSession: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var isRecording = false
    @Published private(set) var isPlaying = false
    @Published private(set) var level: Double = 0

    private var recorder: AVAudioRecorder?
    private var player: AVPlayer?
    private var playerObserver: Any?
    private var meterTimer: Timer?

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
        recorder?.delegate = self
        recorder?.isMeteringEnabled = true
        recorder?.record()
        isRecording = true
        startMetering()
    }

    func stopRecording(completion: @escaping (URL?, TimeInterval?) -> Void) {
        guard let recorder else { completion(nil, nil); return }
        recorder.stop()
        isRecording = false
        stopMetering()
        completion(recorder.url, recorder.currentTime)
    }

    func play(url: URL) {
        if isPlaying {
            player?.pause()
            isPlaying = false
            return
        }
        let item = AVPlayerItem(url: url)
        player = AVPlayer(playerItem: item)
        // Observe end
        if let observer = playerObserver { NotificationCenter.default.removeObserver(observer) }
        playerObserver = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.isPlaying = false
            }
        }
        player?.play()
        isPlaying = true
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

    deinit {
        if let observer = playerObserver { NotificationCenter.default.removeObserver(observer) }
    }
}
