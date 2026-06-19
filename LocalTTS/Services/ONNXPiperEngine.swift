import Foundation
import OnnxRuntimeBindings

final class ONNXPiperEngine: PiperEngine {
    private struct PiperConfig: Decodable {
        struct AudioConfig: Decodable {
            let sample_rate: Int?
        }
        let audio: AudioConfig?
        let phoneme_id_map: [String: [Int]]?
    }

    private struct CachedSession {
        let modelURL: URL
        let env: ORTEnv
        let session: ORTSession
    }

    private var cached: CachedSession?
    private let sessionLock = NSLock()

    private func getSession(modelONNX: URL) throws -> (ORTEnv, ORTSession) {
        sessionLock.lock()
        defer { sessionLock.unlock() }

        if let cached = cached, cached.modelURL == modelONNX {
            return (cached.env, cached.session)
        }

        let env = try ORTEnv(loggingLevel: .warning)
        let options = try ORTSessionOptions()
        let session = try ORTSession(env: env, modelPath: modelONNX.path, sessionOptions: options)

        cached = CachedSession(modelURL: modelONNX, env: env, session: session)
        return (env, session)
    }

    func synthesize(text: String, modelONNX: URL, modelConfig: URL, speed: Double) async throws -> Data {
        // 1. Đọc và phân tích cú pháp tệp cấu hình JSON
        guard let configData = try? Data(contentsOf: modelConfig) else {
            throw APIError.internalError("Cannot read Piper config file: \(modelConfig.lastPathComponent)")
        }
        
        guard let config = try? JSONDecoder().decode(PiperConfig.self, from: configData),
              let phonemeIdMap = config.phoneme_id_map else {
            throw APIError.internalError("Failed to parse Piper config file: \(modelConfig.lastPathComponent)")
        }
        
        let sampleRate = config.audio?.sample_rate ?? 22050
        
        // Xác định các ký tự đặc biệt
        let padId = phonemeIdMap["_"]?.first ?? 0
        let bosId = phonemeIdMap["^"]?.first ?? 1
        let eosId = phonemeIdMap["$"]?.first ?? 2
        
        // 2. Chuyển văn bản sang âm vị sử dụng eSpeak NG
        let phonemes = try EspeakPhonemizer.phonemize(text: text)
        
        // 3. Ánh xạ âm vị sang mảng Phoneme IDs theo chuẩn VITS (BOS, PAD, P1, PAD, P2, ..., EOS)
        var phonemeIds: [Int64] = []
        phonemeIds.append(Int64(bosId))
        phonemeIds.append(Int64(padId))
        
        // Duyệt theo từng Unicode Scalar để tránh tách sai các ký tự ghép trong IPA
        for scalar in phonemes.unicodeScalars {
            let phonemeStr = String(scalar)
            if let ids = phonemeIdMap[phonemeStr] {
                for id in ids {
                    phonemeIds.append(Int64(id))
                    phonemeIds.append(Int64(padId))
                }
            } else {
                appLog("Warning: Missing phoneme mapping for: \(phonemeStr)")
            }
        }
        phonemeIds.append(Int64(eosId))
        
        // 4. Lấy môi trường và Session từ cache (hoặc khởi tạo mới nếu đổi model)
        let (_, session) = try getSession(modelONNX: modelONNX)
        
        let inputNames = try session.inputNames()
        let outputNames = try session.outputNames()
        guard let firstOutputName = outputNames.first else {
            throw APIError.internalError("Model has no output names.")
        }
        
        // 5. Chuẩn bị các Tensor đầu vào
        // Input 1: "input" -> shape [1, phoneme_count]
        let inputShape: [NSNumber] = [1, NSNumber(value: phonemeIds.count)]
        let inputData = phonemeIds.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return Data() }
            return Data(bytes: baseAddress, count: buffer.count * MemoryLayout<Int64>.size)
        }
        let inputTensor = try ORTValue(
            tensorData: NSMutableData(data: inputData),
            elementType: ORTTensorElementDataType.int64,
            shape: inputShape
        )
        
        // Input 2: "input_lengths" -> shape [1]
        let inputLengthValue: Int64 = Int64(phonemeIds.count)
        let lengthShape: [NSNumber] = [1]
        let lengthData = withUnsafePointer(to: inputLengthValue) { ptr in
            Data(bytes: ptr, count: MemoryLayout<Int64>.size)
        }
        let lengthTensor = try ORTValue(
            tensorData: NSMutableData(data: lengthData),
            elementType: ORTTensorElementDataType.int64,
            shape: lengthShape
        )
        
        // Input 3: "scales" -> shape [3] -> [noise_scale, length_scale, noise_w]
        let noiseScale: Float = 0.667
        let lengthScale: Float = Float(1.0 / speed)
        let noiseW: Float = 0.8
        let scales = [noiseScale, lengthScale, noiseW]
        let scalesShape: [NSNumber] = [3]
        let scalesData = scales.withUnsafeBufferPointer { buffer in
            guard let baseAddress = buffer.baseAddress else { return Data() }
            return Data(bytes: baseAddress, count: buffer.count * MemoryLayout<Float>.size)
        }
        let scalesTensor = try ORTValue(
            tensorData: NSMutableData(data: scalesData),
            elementType: ORTTensorElementDataType.float,
            shape: scalesShape
        )
        
        var feeds: [String: ORTValue] = [
            "input": inputTensor,
            "input_lengths": lengthTensor,
            "scales": scalesTensor
        ]
        
        // Hỗ trợ mô hình đa giọng đọc (Multi-speaker) nếu có yêu cầu "sid" (Speaker ID)
        if inputNames.contains("sid") {
            let speakerId: Int64 = 0
            let sidShape: [NSNumber] = [1]
            let sidData = withUnsafePointer(to: speakerId) { ptr in
                Data(bytes: ptr, count: MemoryLayout<Int64>.size)
            }
            let sidTensor = try ORTValue(
                tensorData: NSMutableData(data: sidData),
                elementType: ORTTensorElementDataType.int64,
                shape: sidShape
            )
            feeds["sid"] = sidTensor
        }
        
        // 6. Chạy suy luận (Run Inference)
        let outputs = try session.run(
            withInputs: feeds,
            outputNames: [firstOutputName],
            runOptions: nil
        )
        
        guard let outputValue = outputs[firstOutputName] else {
            throw APIError.internalError("Model did not return speech '\(firstOutputName)' tensor.")
        }
        
        let outputData = try outputValue.tensorData() as Data
        
        // 7. Chuyển đổi dữ liệu nhị phân đầu ra sang mảng PCM Float [-1.0, 1.0]
        let samplesCount = outputData.count / MemoryLayout<Float>.size
        var samples = [Float](repeating: 0.0, count: samplesCount)
        _ = samples.withUnsafeMutableBytes { samplesBuffer in
            outputData.copyBytes(to: samplesBuffer)
        }
        
        // 8. Đóng gói thành tệp WAV PCM 16-bit
        let wavData = WAVEncoder.encodePCM16(
            samples: samples,
            sampleRate: sampleRate,
            channels: 1
        )
        
        return wavData
    }
}
