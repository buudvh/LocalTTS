import Foundation
import AVFoundation

final class BackgroundKeepAlive {
    private var audioPlayer: AVAudioPlayer?
    private var isPlaying = false

    func start() {
        guard !isPlaying else { return }
        
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            
            // Sinh 1 giây âm thanh im lặng (tần số 16kHz)
            let sampleRate = 16000
            let silenceSamples = Array(repeating: Float(0.0), count: sampleRate)
            let silentWavData = WAVEncoder.encodePCM16(samples: silenceSamples, sampleRate: sampleRate)
            
            audioPlayer = try AVAudioPlayer(data: silentWavData)
            audioPlayer?.numberOfLoops = -1 // Lặp vô hạn
            audioPlayer?.volume = 0.0 // Âm lượng bằng 0 để không gây tiếng ồn
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlaying = true
        } catch {
            appLog("Failed to start background keep-alive: \(error)")
        }
    }

    func stop() {
        guard isPlaying else { return }
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        
        // Hủy kích hoạt audio session để giải phóng tài nguyên
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }
}
