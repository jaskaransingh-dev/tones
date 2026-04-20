import Foundation
import AVFoundation
import Combine

class AudioManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    var audioRecorder: AVAudioRecorder?
    var audioPlayer: AVAudioPlayer?
    
    @Published var isRecording = false
    @Published var isPlaying = false
    
    var currentRecordURL: URL?
    var onPlaybackFinished: (() -> Void)?
    
    override init() {
        super.init()
        setupSession()
    }
    
    private func setupSession() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
            session.requestRecordPermission { granted in
                if !granted { print("Microphone permission not granted") }
            }
        } catch {
            print("Audio session setup failed: \(error)")
        }
    }
    
    func startRecording() {
        let tempDir = FileManager.default.temporaryDirectory
        currentRecordURL = tempDir.appendingPathComponent("\(UUID().uuidString).m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        do {
            guard let url = currentRecordURL else { return }
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()
            DispatchQueue.main.async { self.isRecording = true }
        } catch {
            print("Could not start recording: \(error)")
        }
    }
    
    func stopRecording() -> URL? {
        audioRecorder?.stop()
        DispatchQueue.main.async { self.isRecording = false }
        return currentRecordURL
    }
    
    func playAudio(from url: URL, completion: @escaping () -> Void) {
        do {
            let data = try Data(contentsOf: url)
            audioPlayer = try AVAudioPlayer(data: data)
            audioPlayer?.delegate = self
            self.onPlaybackFinished = completion
            audioPlayer?.play()
            DispatchQueue.main.async { self.isPlaying = true }
        } catch {
            print("Playback failed: \(error)")
            completion()
        }
    }
    
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async { self.isPlaying = false }
        onPlaybackFinished?()
    }
}
