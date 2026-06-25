import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    let modelStore: ModelStore
    let nghiClient: NghiTTSClient
    let ttsService: PiperTTSService
    let apiHandler: APIHandler
    let server: LocalHTTPServer
    private let keepAlive = BackgroundKeepAlive()

    @Published var lastError: String?
    private var cancellables: Set<AnyCancellable> = []

    init() {
        do {
            let store = try ModelStore()
            self.modelStore = store
            self.nghiClient = NghiTTSClient(modelStore: store)
            self.ttsService = PiperTTSService(modelStore: store)
            self.apiHandler = APIHandler(nghiClient: nghiClient, ttsService: ttsService, modelStore: store)
            self.server = LocalHTTPServer(port: 17771, handler: apiHandler)
            store.objectWillChange
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                }
                .store(in: &cancellables)
            self.server.objectWillChange
                .receive(on: DispatchQueue.main)
                .sink { [weak self] _ in
                    self?.objectWillChange.send()
                }
                .store(in: &cancellables)
        } catch {
            fatalError("Failed to initialize LocalTTS: \(error)")
        }
    }

    func startServer() {
        do {
            try server.start()
            keepAlive.start()
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    func stopServer() {
        server.stop()
        keepAlive.stop()
    }
}
