import Foundation
import AVFoundation
#if os(iOS)
import UIKit
#endif

final class BackgroundKeepAlive {
    private var audioPlayer: AVAudioPlayer?
    private var isPlaying = false
    private var observers: [Any] = []

    init() {
        setupObservers()
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func start() {
        guard !isPlaying else { return }
        
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
            
            // Sinh 1 giây âm thanh im lặng với sample rate thấp hơn để giảm overhead
            let sampleRate = 8000
            let silenceSamples = Array(repeating: Float(0.0), count: sampleRate)
            let silentWavData = WAVEncoder.encodePCM16(samples: silenceSamples, sampleRate: sampleRate)
            
            audioPlayer = try AVAudioPlayer(data: silentWavData)
            audioPlayer?.numberOfLoops = -1 // Lặp vô hạn
            audioPlayer?.volume = 0.0 // Âm lượng bằng 0 để không gây tiếng ồn
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlaying = true
            appLog("🔊 Background keep-alive started.")
        } catch {
            appLog("⚠️ Failed to start background keep-alive: \(error)")
        }
    }

    func stop() {
        guard isPlaying else { return }
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        appLog("🔊 Background keep-alive stopped.")
        
        // Hủy kích hoạt audio session để giải phóng tài nguyên
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func resumePlayerIfNeeded() {
        guard isPlaying else { return }
        
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setActive(true)
            if let player = audioPlayer {
                if !player.isPlaying {
                    player.prepareToPlay()
                    player.play()
                    appLog("🔊 Background keep-alive audio player resumed successfully.")
                } else {
                    appLog("🔊 Background keep-alive audio player is already playing.")
                }
            } else {
                appLog("⚠️ Audio player is nil during resume. Recreating player...")
                isPlaying = false
                start()
            }
        } catch {
            appLog("⚠️ Failed to resume audio session: \(error)")
        }
    }

    private func setupObservers() {
        let center = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()

        // 1. Lắng nghe gián đoạn âm thanh (Interruption)
        let interruptionObserver = center.addObserver(
            forName: AVAudioSession.interruptionNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let userInfo = notification.userInfo,
                  let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
                  let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
                return
            }

            if type == .began {
                appLog("🔊 AVAudioSession interruption began.")
            } else if type == .ended {
                appLog("🔊 AVAudioSession interruption ended.")
                if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                    let options = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    if options.contains(.shouldResume) {
                        self.resumePlayerIfNeeded()
                    }
                } else {
                    // Mặc định thử phục hồi nếu không có option cụ thể
                    self.resumePlayerIfNeeded()
                }
            }
        }
        observers.append(interruptionObserver)

        // 2. Lắng nghe thay đổi Route (ngắt cắm tai nghe/bluetooth)
        let routeChangeObserver = center.addObserver(
            forName: AVAudioSession.routeChangeNotification,
            object: session,
            queue: .main
        ) { [weak self] notification in
            guard let self = self else { return }
            guard let userInfo = notification.userInfo,
                  let reasonValue = userInfo[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
                return
            }

            appLog("🔊 Audio route changed, reason: \(reasonValue)")
            if reason == .oldDeviceUnavailable {
                // Thiết bị âm thanh cũ bị ngắt kết nối (ví dụ rút tai nghe), cần play lại
                self.resumePlayerIfNeeded()
            }
        }
        observers.append(routeChangeObserver)

        #if os(iOS)
        // 3. Lắng nghe sự kiện chuyển xuống background
        let enterBackgroundObserver = center.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            appLog("📱 App entered background. Verifying keep-alive player...")
            self.resumePlayerIfNeeded()
        }
        observers.append(enterBackgroundObserver)

        // 4. Lắng nghe sự kiện active trở lại
        let becomeActiveObserver = center.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            appLog("📱 App became active. Verifying keep-alive player...")
            self.resumePlayerIfNeeded()
        }
        observers.append(becomeActiveObserver)
        #endif
    }
}

