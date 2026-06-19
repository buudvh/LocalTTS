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
            let sampleRate = espeak_Initialize(AUDIO_OUTPUT_RETRIEVAL, 0, dataPath, 0)
            guard sampleRate >= 0 else {
                throw APIError.internalError("espeak_Initialize failed with code \(sampleRate).")
            }
            
            // Set voice to Vietnamese
            let voiceResult = espeak_SetVoiceByName("vi")
            // EE_OK = 0
            guard voiceResult.rawValue == 0 else {
                throw APIError.internalError("espeak_SetVoiceByName('vi') failed.")
            }
            
            isInitialized = true
        }

        guard let textData = text.data(using: .utf8) else {
            throw APIError.badRequest("Invalid UTF-8 text.")
        }
        
        var result = ""
        var iterations = 0
        textData.withUnsafeBytes { (rawBufferPointer: UnsafeRawBufferPointer) in
            guard let baseAddress = rawBufferPointer.baseAddress else { return }
            var textPointer: UnsafeRawPointer? = baseAddress
            
            while textPointer != nil {
                iterations += 1
                if iterations > 10000 {
                    break
                }
                // textmode: espeakCHARS_UTF8 = 1
                // phonememode: 2 (IPA - International Phonetic Alphabet as UTF-8)
                if let phonemesCStr = espeak_TextToPhonemes(&textPointer, 1, 2) {
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
        let fm = FileManager.default
        let roots: [URL] = [
            Bundle.main.bundleURL,
            Bundle.main.resourceURL,
            Bundle.main.privateFrameworksURL
        ].compactMap { $0 }

        for root in roots {
            if let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: nil) {
                for case let url as URL in enumerator {
                    if url.lastPathComponent == "espeak-ng-data" {
                        print("FOUND: \(url.path)")
                        return url.path
                    }
                }
            }
        }
        return nil
    }
}
