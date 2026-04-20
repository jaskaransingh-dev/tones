import Foundation
import AVFoundation

@MainActor
final class AudioSession: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published private(set) var isRecording = false
    @Published private(set) var isPlaying = false
    @Published private(set) var level: Double = 0

    private var recorder: AVAudioRecorder?
    private var player: AVAudioPlayer?
    private var meterTimer: Timer?

    func startRecording() async throws {
        try AVAudioSession.sharedInstance().setCategory(.playAndRecord, mode: .voiceChat, options: [.defaultToSpeaker, .allowBluetooth])
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
            player?.stop()
            isPlaying = false
            return
        }
        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.play()
            isPlaying = true
        } catch {
            print("play error: \(error)")
        }
    }

    private func startMetering() {
        meterTimer?.invalidate()
        meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let recorder = self.recorder, recorder.isRecording else { return }
            recorder.updateMeters()
            let avg = recorder.averagePower(forChannel: 0)
            let norm = max(0, (avg + 50) / 50)
            Task { @MainActor in self.level = norm }
        }
    }

    private func stopMetering() {
        meterTimer?.invalidate()
        meterTimer = nil
        level = 0
    }
}
