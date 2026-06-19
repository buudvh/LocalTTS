import Foundation
import libespeak_ng

final class EspeakPhonemizer {
    private static var isInitialized = false
    private static let lock = NSLock()

    static func phonemize(text: String) throws -> String {
        lock.lock()
        defer { lock.unlock() }

        if !isInitialized {
            guard let dataPath = findEspeakDataPath() else {
                throw APIError.internalError("Cannot find espeak-ng-data directory.")
            }
            
            // AUDIO_OUTPUT_RETRIEVAL = 1
            let sampleRate = espeak_Initialize(espeak_AUDIO_OUTPUT.AUDIO_OUTPUT_RETRIEVAL, 0, dataPath, 0)
            guard sampleRate >= 0 else {
                throw APIError.internalError("espeak_Initialize failed with code \(sampleRate).")
            }
            
            // Set voice to Vietnamese
            let voiceResult = espeak_SetVoiceByName("vi")
            // EE_OK = 0
            guard voiceResult == espeak_ERROR.EE_OK else {
                throw APIError.internalError("espeak_SetVoiceByName('vi') failed.")
            }
            
            isInitialized = true
        }

        guard let textData = text.data(using: .utf8) else {
            throw APIError.badRequest("Invalid UTF-8 text.")
        }
        
        var result = ""
        try textData.withUnsafeBytes { (rawBufferPointer: UnsafeRawBufferPointer) in
            guard let baseAddress = rawBufferPointer.baseAddress else { return }
            var textPointer: UnsafeRawPointer? = baseAddress
            
            while textPointer != nil {
                // textmode: espeakCHARS_UTF8 = 1
                // phonememode: 0 (ASCII phoneme names)
                if let phonemesCStr = espeak_TextToPhonemes(&textPointer, 1, 0) {
                    let part = String(cString: phonemesCStr)
                    if !result.isEmpty && !part.isEmpty {
                        result += " "
                    }
                    result += part
                } else {
                    break
                }
            }
        }
        
        return result
    }

    private static func findEspeakDataPath() -> String? {
        if let bundlePath = Bundle.main.path(forResource: "espeak-ng-spm_data", ofType: "bundle") {
            return bundlePath + "/espeak-ng-data"
        }
        if let frameworksURL = Bundle.main.privateFrameworksURL {
            let fm = FileManager.default
            let contents = (try? fm.contentsOfDirectory(at: frameworksURL, includingPropertiesForKeys: nil)) ?? []
            for url in contents {
                if let bundle = Bundle(url: url) {
                    if let path = bundle.path(forResource: "espeak-ng-spm_data", ofType: "bundle") {
                        return path + "/espeak-ng-data"
                    }
                }
            }
        }
        return nil
    }
}
