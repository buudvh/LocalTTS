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
            
            let fm = FileManager.default
            appLog("[EspeakPhonemizer] [Check] dataPath exists: \(fm.fileExists(atPath: dataPath))")
            appLog("[EspeakPhonemizer] [Check] phondata exists: \(fm.fileExists(atPath: dataPath + "/phondata"))")
            appLog("[EspeakPhonemizer] [Check] phontab exists: \(fm.fileExists(atPath: dataPath + "/phontab"))")
            appLog("[EspeakPhonemizer] [Check] voices exists: \(fm.fileExists(atPath: dataPath + "/voices"))")
            
            appLog("[EspeakPhonemizer] [P1] calling espeak_Initialize(dataPath: \(dataPath))")
            // AUDIO_OUTPUT_RETRIEVAL = 1
            let sampleRate = espeak_Initialize(AUDIO_OUTPUT_RETRIEVAL, 0, dataPath, 0)
            appLog("[EspeakPhonemizer] [P2] espeak_Initialize completed. sampleRate: \(sampleRate)")
            guard sampleRate >= 0 else {
                throw APIError.internalError("espeak_Initialize failed with code \(sampleRate).")
            }
            
            appLog("[EspeakPhonemizer] [P3] calling espeak_SetVoiceByName('vi')")
            // Set voice to Vietnamese
            let voiceResult = espeak_SetVoiceByName("vi")
            appLog("[EspeakPhonemizer] [P4] espeak_SetVoiceByName completed. voiceResult: \(voiceResult.rawValue)")
            // EE_OK = 0
            guard voiceResult.rawValue == 0 else {
                throw APIError.internalError("espeak_SetVoiceByName('vi') failed.")
            }
            
            isInitialized = true
        }

        guard let cString = text.cString(using: .utf8) else {
            throw APIError.badRequest("Invalid UTF-8 text.")
        }
        
        var result = ""
        var iterations = 0
        appLog("[EspeakPhonemizer] [P5] starting phonemization loop for text: '\(text)'")
        cString.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return }
            var textPointer: UnsafeRawPointer? = UnsafeRawPointer(baseAddress)
            
            while textPointer != nil {
                iterations += 1
                if iterations > 10000 {
                    appLog("[EspeakPhonemizer] [P_WARN] iterations exceeded limit, breaking")
                    break
                }
                // textmode: espeakCHARS_UTF8 = 1
                // phonememode: 2 (IPA - International Phonetic Alphabet as UTF-8)
                appLog("[EspeakPhonemizer] [P6] calling espeak_TextToPhonemes (iteration: \(iterations))")
                if let phonemesCStr = espeak_TextToPhonemes(&textPointer, 1, 2) {
                    let part = String(cString: phonemesCStr)
                    appLog("[EspeakPhonemizer] [P7] espeak_TextToPhonemes completed. phonemes: '\(part)'")
                    if !result.isEmpty && !part.isEmpty {
                        result += " "
                    }
                    result += part
                } else {
                    appLog("[EspeakPhonemizer] [P8] espeak_TextToPhonemes returned nil (end of text)")
                    break
                }
            }
        }
        appLog("[EspeakPhonemizer] [P9] phonemization finished. result: '\(result)'")
        return result
    }

    private static func findEspeakDataPath() -> String? {
        let fm = FileManager.default
        
        appLog("=== DEBUG: findEspeakDataPath ===")
        appLog("Bundle.main.bundlePath: \(Bundle.main.bundlePath)")
        if let resourcePath = Bundle.main.resourcePath {
            appLog("Bundle.main.resourcePath: \(resourcePath)")
            if let files = try? fm.subpathsOfDirectory(atPath: resourcePath) {
                appLog("--- FILES IN RESOURCE PATH ---")
                for file in files {
                    if file.lowercased().contains("espeak") || file.lowercased().contains("bundle") {
                        appLog("  \(file)")
                    }
                }
            }
        }
        
        appLog("--- ALL BUNDLES ---")
        for bundle in Bundle.allBundles {
            appLog("  \(bundle.bundlePath)")
        }
        
        appLog("--- ALL FRAMEWORKS ---")
        for framework in Bundle.allFrameworks {
            appLog("  \(framework.bundlePath)")
        }
        
        let roots: [URL] = (
            [
                Bundle.main.bundleURL,
                Bundle.main.resourceURL,
                Bundle.main.privateFrameworksURL
            ] +
            Bundle.allBundles.map(\.bundleURL) +
            Bundle.allFrameworks.map(\.bundleURL)
        ).compactMap { $0 }

        // Remove duplicates to prevent redundant scans
        let uniqueRoots = Array(Set(roots))
        
        appLog("--- SCANNING ROOTS ---")
        for root in uniqueRoots {
            appLog("  Scanning root: \(root.path)")
            if let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: nil) {
                for case let url as URL in enumerator {
                    if url.lastPathComponent == "espeak-ng-data" {
                        appLog("FOUND MATCH: \(url.path)")
                        return url.path
                    }
                }
            }
        }
        
        appLog("=== DEBUG END: NOT FOUND ===")
        return nil
    }
}
