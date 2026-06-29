import SwiftUI
import UniformTypeIdentifiers

struct ModelManagerView: View {
    @EnvironmentObject private var appState: AppState
    @State private var voices: [Voice] = []
    @State private var isLoadingVoices = false
    @State private var isShowingFileImporter = false
    @State private var downloadingStatus: [String: Double] = [:]
    @State private var downloadingMessages: [String: String] = [:]
    
    @State private var isImportingModel = false
    @State private var importModelMessage = "Đang nhập model..."
    @State private var modelRefreshTrigger = 0
    
    @State private var toast: ToastConfig? = nil
    @State private var toastTask: Task<Void, Never>? = nil

    struct ToastConfig: Identifiable {
        let id = UUID()
        let message: String
        let isError: Bool
    }

    private func showToast(_ message: String, isError: Bool) {
        toastTask?.cancel()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            toast = ToastConfig(message: message, isError: isError)
        }
        toastTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) {
                toast = nil
            }
        }
    }

    private func dismissToast() {
        toastTask?.cancel()
        toastTask = nil
        withAnimation(.easeOut(duration: 0.25)) {
            toast = nil
        }
    }

    private var topVoices: [Voice] {
        let topNames = ["Ngọc Huyền (mới)", "Mai Phương", "Duy Onyx (mới)", "Ngọc Ngạn"].map { $0.precomposedStringWithCanonicalMapping }
        return NghiTTSClient.fallbackVietnameseVoices.filter { topNames.contains($0.name.precomposedStringWithCanonicalMapping) }
    }

    private var systemVoices: [Voice] {
        let _ = modelRefreshTrigger
        let topNames = ["Ngọc Huyền (mới)", "Mai Phương", "Duy Onyx (mới)", "Ngọc Ngạn"].map { $0.precomposedStringWithCanonicalMapping }
        let baseVoices = NghiTTSClient.fallbackVietnameseVoices.filter { !topNames.contains($0.name.precomposedStringWithCanonicalMapping) }
        
        let downloaded = baseVoices.filter { appState.modelStore.modelExists(for: $0.id) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        let notDownloaded = baseVoices.filter { !appState.modelStore.modelExists(for: $0.id) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            
        return downloaded + notDownloaded
    }

    private var customVoices: [Voice] {
        let _ = modelRefreshTrigger
        let localIDs = appState.modelStore.getLocalVoiceIDs()
        let fallbackIDs = NghiTTSClient.fallbackVietnameseVoices.map { $0.id }
        let customIDs = localIDs.filter { !fallbackIDs.contains($0) }
        let unsorted = customIDs.map { id in
            let name = id.replacingOccurrences(of: "_", with: " ").capitalized
            return Voice(id: id, name: name)
        }
        return unsorted.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                List {
                    Section {
                        Button(action: {
                            isShowingFileImporter = true
                        }) {
                            Label("Nhập Model Ngoài...", systemImage: "square.and.arrow.down")
                        }
                    }
                    
                    Section(header: HStack {
                        Text("Giọng đọc đặc sắc")
                        Spacer()
                        HStack(spacing: 12) {
                            Button("Tải tất cả") {
                                downloadAll(in: topVoices)
                            }
                            .buttonStyle(.borderless)
                            .textCase(.none)
                            .font(.caption)
                            
                            Button("Xóa tất cả", role: .destructive) {
                                deleteAll(in: topVoices)
                            }
                            .buttonStyle(.borderless)
                            .textCase(.none)
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                    }) {
                        ForEach(topVoices) { voice in
                            modelRow(for: voice)
                        }
                    }
                    
                    Section(header: HStack {
                        Text("Giọng đọc hệ thống")
                        Spacer()
                        HStack(spacing: 12) {
                            Button("Tải tất cả") {
                                downloadAll(in: systemVoices)
                            }
                            .buttonStyle(.borderless)
                            .textCase(.none)
                            .font(.caption)
                            
                            Button("Xóa tất cả", role: .destructive) {
                                deleteAll(in: systemVoices)
                            }
                            .buttonStyle(.borderless)
                            .textCase(.none)
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                    }) {
                        ForEach(systemVoices) { voice in
                            modelRow(for: voice)
                        }
                    }
                    
                    let custom = customVoices
                    if !custom.isEmpty {
                        Section(header: HStack {
                            Text("Giọng đọc tùy chỉnh")
                            Spacer()
                            Button("Xóa tất cả", role: .destructive) {
                                deleteAll(in: custom)
                            }
                            .buttonStyle(.borderless)
                            .textCase(.none)
                            .font(.caption)
                            .foregroundColor(.red)
                        }) {
                            ForEach(custom) { voice in
                                modelRow(for: voice, isCustom: true)
                            }
                        }
                    }
                }
                .navigationTitle("Quản lý Model")
                .background {
                    DocumentPickerPresenter(
                        isPresented: $isShowingFileImporter,
                        allowedContentTypes: [.onnx, .json],
                        allowsMultipleSelection: true,
                        onPick: { urls in
                            handleModelImportPick(urls: urls)
                        },
                        onCancel: nil
                    )
                }
                .task {
                    await loadVoices(forceRefresh: false)
                }

                if isImportingModel {
                    Color.black.opacity(0.35)
                        .edgesIgnoringSafeArea(.all)
                        .transition(.opacity)
                        .zIndex(998)

                    VStack(spacing: 16) {
                        ProgressView(importModelMessage)
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding(24)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .shadow(radius: 16)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(999)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if let toast = toast {
                    HStack(spacing: 10) {
                        Image(systemName: toast.isError
                            ? "exclamationmark.circle.fill"
                            : "checkmark.circle.fill")

                        Text(toast.message)
                            .font(.subheadline)
                            .multilineTextAlignment(.leading)
                    }
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .shadow(radius: 8)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 8)
                    .onTapGesture {
                        dismissToast()
                    }
                    .transition(
                        .asymmetric(
                            insertion: .move(edge: .bottom).combined(with: .opacity),
                            removal: .opacity
                        )
                    )
                    .zIndex(1000)
                }
            }
        }
    }

    @ViewBuilder
    private func modelRow(for voice: Voice, isCustom: Bool = false) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(voice.name)
                    .font(.body)
                
                let isDownloaded = appState.modelStore.modelExists(for: voice.id)
                if isDownloaded {
                    let bytes = appState.modelStore.bytesForVoice(voice.id)
                    Text(String(format: "Dung lượng: %.1f MB", Double(bytes) / 1024.0 / 1024.0))
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("Trạng thái: Chưa tải")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                if let progress = downloadingStatus[voice.name] {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: progress)
                        Text(downloadingMessages[voice.name] ?? "Đang tải...")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
            
            Spacer()
            
            let isDownloading = downloadingStatus[voice.name] != nil
            if isDownloading {
                ProgressView()
            } else {
                let isDownloaded = appState.modelStore.modelExists(for: voice.id)
                HStack(spacing: 8) {
                    if isDownloaded {
                        if !isCustom {
                            Button("Tải lại") {
                                Task {
                                    await downloadSingleModel(voice: voice)
                                }
                            }
                            .buttonStyle(.bordered)
                        }
                        
                        Button("Xóa", role: .destructive) {
                            deleteSingleModel(voice: voice)
                        }
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                    } else {
                        Button("Tải") {
                            Task {
                                    await downloadSingleModel(voice: voice)
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                }
            }
        .padding(.vertical, 4)
    }

    private func downloadSingleModel(voice: Voice) async {
        downloadingStatus[voice.name] = 0.0
        downloadingMessages[voice.name] = "Bắt đầu tải..."
        
        do {
            _ = try await appState.nghiClient.prefetchModels(voices: [voice.name]) { msg, progress in
                DispatchQueue.main.async {
                    self.downloadingStatus[voice.name] = progress
                    self.downloadingMessages[voice.name] = msg
                }
            }
            DispatchQueue.main.async {
                self.downloadingStatus.removeValue(forKey: voice.name)
                self.downloadingMessages.removeValue(forKey: voice.name)
                self.modelRefreshTrigger += 1
            }
            await loadVoices(forceRefresh: false)
        } catch {
            DispatchQueue.main.async {
                self.downloadingStatus.removeValue(forKey: voice.name)
                self.downloadingMessages.removeValue(forKey: voice.name)
                self.appState.lastError = "Lỗi tải model \(voice.name): \(error.localizedDescription)"
            }
        }
    }

    private func deleteSingleModel(voice: Voice) {
        do {
            try appState.modelStore.deleteModel(for: voice.id)
            modelRefreshTrigger += 1
            showToast("Đã xóa model \(voice.name) thành công.", isError: false)
            Task {
                await loadVoices(forceRefresh: false)
            }
        } catch {
            showToast("Lỗi xóa model \(voice.name): \(error.localizedDescription)", isError: true)
            appState.lastError = "Lỗi xóa model \(voice.name): \(error.localizedDescription)"
        }
    }

    private func downloadAll(in list: [Voice]) {
        let toDownload = list.filter { !appState.modelStore.modelExists(for: $0.id) && downloadingStatus[$0.name] == nil }
        for voice in toDownload {
            Task {
                await downloadSingleModel(voice: voice)
            }
        }
    }

    private func deleteAll(in list: [Voice]) {
        let toDelete = list.filter { appState.modelStore.modelExists(for: $0.id) }
        guard !toDelete.isEmpty else { return }
        for voice in toDelete {
            do {
                try appState.modelStore.deleteModel(for: voice.id)
            } catch {
                appState.lastError = "Lỗi xóa model \(voice.name): \(error.localizedDescription)"
            }
        }
        modelRefreshTrigger += 1
        Task {
            await loadVoices(forceRefresh: false)
        }
    }

    private func loadVoices(forceRefresh: Bool) async {
        isLoadingVoices = true
        defer { isLoadingVoices = false }

        do {
            let allVoices = try await appState.nghiClient.getAllVoices(forceRefresh: forceRefresh)
            voices = allVoices
        } catch {
            appState.lastError = error.localizedDescription
        }
    }

    private typealias ModelImportPair = (
        onnxURL: URL,
        onnxAccess: Bool,
        jsonURL: URL,
        jsonAccess: Bool,
        voiceId: String
    )

    private func handleModelImportPick(urls: [URL]) {
        let validURLs = urls.filter {
            let ext = $0.pathExtension.lowercased()
            return ext == "onnx" || ext == "json"
        }
        if validURLs.isEmpty {
            reportImportError("Vui lòng chọn tệp tin model (.onnx) và cấu hình (.json).")
            return
        }

        let onnxURLs = validURLs.filter { $0.pathExtension.lowercased() == "onnx" }
        let jsonURLs = validURLs.filter { $0.pathExtension.lowercased() == "json" }

        if onnxURLs.isEmpty || jsonURLs.isEmpty {
            reportImportError("Cần chọn cả hai tệp .onnx và .json cho model. Vui lòng thử lại.")
            return
        }

        func voiceId(for url: URL) -> String {
            let baseName = url.deletingPathExtension().lastPathComponent
            if url.pathExtension.lowercased() == "json", baseName.lowercased().hasSuffix(".onnx") {
                return String(baseName.dropLast(5)).toASCIIID
            }
            return baseName.toASCIIID
        }

        let jsonById = Dictionary(uniqueKeysWithValues: jsonURLs.compactMap { url in
            let id = voiceId(for: url)
            return id.isEmpty ? nil : (id, url)
        })

        var pairedFiles: [(onnxURL: URL, jsonURL: URL, voiceId: String)] = []
        var missingJSON: [String] = []
        for onnxURL in onnxURLs {
            let id = voiceId(for: onnxURL)
            if let jsonURL = jsonById[id] {
                pairedFiles.append((onnxURL: onnxURL, jsonURL: jsonURL, voiceId: id))
            } else {
                missingJSON.append(onnxURL.lastPathComponent)
            }
        }

        if !missingJSON.isEmpty {
            reportImportError("Thiếu tệp .json tương ứng cho: \(missingJSON.joined(separator: ", ")).")
            return
        }

        let pairsWithAccess = pairedFiles.map { pair in
            (
                onnxURL: pair.onnxURL,
                onnxAccess: pair.onnxURL.startAccessingSecurityScopedResource(),
                jsonURL: pair.jsonURL,
                jsonAccess: pair.jsonURL.startAccessingSecurityScopedResource(),
                voiceId: pair.voiceId
            )
        }

        isImportingModel = true
        importModelMessage = "Đang nhập model..."
        showToast("Đang nhập model...", isError: false)

        let result = performModelImportSync(from: pairsWithAccess)
        isImportingModel = false

        modelRefreshTrigger += 1
        Task {
            await finishModelImport(result: result, modelCount: pairsWithAccess.count)
        }
    }

    private func reportImportError(_ message: String) {
        appState.lastError = message
        showToast(message, isError: true)
    }

    private struct ModelImportResult {
        let importCount: Int
        let errorCount: Int
        let lastErrorMessage: String?
    }

    private func performModelImportSync(from pairs: [ModelImportPair]) -> ModelImportResult {
        let fm = FileManager.default
        var importCount = 0
        var errorCount = 0
        var lastErrorMessage: String?

        for pair in pairs {
            let onnxURL = pair.onnxURL
            let jsonURL = pair.jsonURL
            let voiceId = pair.voiceId

            defer {
                if pair.onnxAccess {
                    onnxURL.stopAccessingSecurityScopedResource()
                }
                if pair.jsonAccess {
                    jsonURL.stopAccessingSecurityScopedResource()
                }
            }

            let targets: [(source: URL, destination: URL)] = [
                (source: onnxURL, destination: appState.modelStore.modelURL(for: voiceId, extension: "onnx")),
                (source: jsonURL, destination: appState.modelStore.modelURL(for: voiceId, extension: "onnx.json"))
            ]

            for item in targets {
                var cleanupURL: URL?
                do {
                    let resourceValues = try item.source.resourceValues(forKeys: [.fileSizeKey])
                    let fileSize = resourceValues.fileSize ?? 0
                    if fileSize <= 0 {
                        throw NSError(domain: "ContentView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Tệp \(item.source.lastPathComponent) trống hoặc không thể đọc."])
                    }

                    if item.source.pathExtension.lowercased() == "json" {
                        let data = try Data(contentsOf: item.source)
                        guard let _ = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
                            throw NSError(domain: "ContentView", code: 2, userInfo: [NSLocalizedDescriptionKey: "Cấu hình JSON \(item.source.lastPathComponent) không hợp lệ."])
                        }
                    }

                    if fm.fileExists(atPath: item.destination.path) {
                        try fm.removeItem(at: item.destination)
                    }

                    cleanupURL = item.destination
                    try streamCopy(from: item.source, to: item.destination)
                    importCount += 1
                } catch {
                    let message = error.localizedDescription
                    appLog("Failed to import file \(item.source.lastPathComponent): \(message)")
                    lastErrorMessage = message
                    if let cleanupURL = cleanupURL, fm.fileExists(atPath: cleanupURL.path) {
                        try? fm.removeItem(at: cleanupURL)
                    }
                    errorCount += 1
                }
            }
        }

        appLog("Imported \(importCount) files. Errors: \(errorCount)")
        return ModelImportResult(
            importCount: importCount,
            errorCount: errorCount,
            lastErrorMessage: lastErrorMessage
        )
    }

    private func finishModelImport(result: ModelImportResult, modelCount: Int) async {
        await loadVoices(forceRefresh: false)

        if result.errorCount > 0 {
            let message = "Lỗi nhập model/cấu hình. Vui lòng kiểm tra lại các cặp .onnx và .json."
            appState.lastError = result.lastErrorMessage ?? message
            showToast(message, isError: true)
        } else if result.importCount > 0 {
            appState.lastError = nil
            showToast("Đã nhập thành công \(modelCount) model.", isError: false)
        } else {
            let message = "Không thể nhập model. Vui lòng kiểm tra lại tệp đã chọn."
            appState.lastError = message
            showToast(message, isError: true)
        }
    }

    private func streamCopy(from sourceURL: URL, to destinationURL: URL) throws {
        guard let inputStream = InputStream(url: sourceURL) else {
            throw NSError(domain: "StreamCopy", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to open input stream for \(sourceURL.lastPathComponent)"])
        }
        guard let outputStream = OutputStream(url: destinationURL, append: false) else {
            throw NSError(domain: "StreamCopy", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to open output stream for \(destinationURL.lastPathComponent)"])
        }
        
        inputStream.open()
        defer { inputStream.close() }
        outputStream.open()
        defer { outputStream.close() }
        
        let bufferSize = 65536 // 64KB
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        
        while inputStream.hasBytesAvailable {
            let bytesRead = inputStream.read(buffer, maxLength: bufferSize)
            if bytesRead < 0 {
                if let error = inputStream.streamError {
                    throw error
                }
                throw NSError(domain: "StreamCopy", code: 3, userInfo: [NSLocalizedDescriptionKey: "Error reading input stream"])
            } else if bytesRead == 0 {
                break // End of file
            }
            
            var bytesWritten = 0
            while bytesWritten < bytesRead {
                let written = outputStream.write(buffer.advanced(by: bytesWritten), maxLength: bytesRead - bytesWritten)
                if written < 0 {
                    if let error = outputStream.streamError {
                        throw error
                    }
                    throw NSError(domain: "StreamCopy", code: 4, userInfo: [NSLocalizedDescriptionKey: "Error writing output stream"])
                }
                bytesWritten += written
            }
        }
    }
}
