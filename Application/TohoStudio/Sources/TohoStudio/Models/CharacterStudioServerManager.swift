import Foundation
import Network

/// 東方キャラ立絵スタジオ (ローカル HTTP & REST API サーバー: 8088) のプロセスライフサイクル管理
public class CharacterStudioServerManager: ObservableObject {
    public static let shared = CharacterStudioServerManager()

    @Published public var isRunning: Bool = false
    @Published public var serverPort: Int = 8088
    @Published public var serverURL: URL = URL(string: "http://127.0.0.1:8088")!
    @Published public var lastError: String? = nil

    private var process: Process?

    public init() {
        startServerIfNeeded()
    }

    deinit {
        stopServer()
    }

    /// サーバーが稼働中かチェックし、未稼働であれば起動する
    public func startServerIfNeeded() {
        checkPortListening(port: serverPort) { [weak self] isListening in
            guard let self = self else { return }
            if isListening {
                DispatchQueue.main.async {
                    self.isRunning = true
                    print("TohoStudio: CharacterStudio server already running on port \(self.serverPort)")
                }
            } else {
                self.launchPythonServer()
            }
        }
    }

    /// ポートがすでにリッスン中か確認
    private func checkPortListening(port: Int, completion: @escaping (Bool) -> Void) {
        let endpoint = NWEndpoint.hostPort(host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: UInt16(port))!)
        let connection = NWConnection(to: endpoint, using: .tcp)
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                connection.cancel()
                completion(true)
            case .failed, .cancelled:
                completion(false)
            default:
                break
            }
        }
        connection.start(queue: DispatchQueue.global(qos: .userInitiated))
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.4) {
            if connection.state != .ready {
                connection.cancel()
                completion(false)
            }
        }
    }

    /// psd_studio_server.py のスクリプトパスを探索
    public func resolveScriptPath() -> String? {
        let repoRoot = PSDToolService.resolveRepoRoot()
        let candidates = [
            "\(repoRoot)/Application/Resource/CharacterStudio/psd_studio_server.py",
            "\(repoRoot)/Resource/CharacterStudio/psd_studio_server.py",
            Bundle.main.resourcePath.map { "\($0)/Resource/CharacterStudio/psd_studio_server.py" },
            Bundle.main.resourcePath.map { "\($0)/psd_studio_server.py" }
        ].compactMap { $0 }

        for path in candidates {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        return nil
    }

    /// Python サーバープロセスの起動
    public func launchPythonServer() {
        guard let scriptPath = resolveScriptPath() else {
            print("TohoStudio: psd_studio_server.py not found")
            return
        }

        let pythonCandidates = ["/usr/bin/python3", "/usr/local/bin/python3", "/opt/homebrew/bin/python3"]
        let pythonPath = pythonCandidates.first { FileManager.default.fileExists(atPath: $0) } ?? "/usr/bin/python3"

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: pythonPath)
        proc.arguments = [scriptPath, String(serverPort)]
        proc.currentDirectoryURL = URL(fileURLWithPath: (scriptPath as NSString).deletingLastPathComponent)

        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isRunning = false
                print("TohoStudio: CharacterStudio server stopped")
            }
        }

        do {
            try proc.run()
            self.process = proc
            DispatchQueue.main.async {
                self.isRunning = true
                print("TohoStudio: CharacterStudio server launched on http://127.0.0.1:\(self.serverPort)")
            }
        } catch {
            DispatchQueue.main.async {
                self.lastError = error.localizedDescription
                print("TohoStudio: Failed to launch CharacterStudio server: \(error)")
            }
        }
    }

    public func stopServer() {
        if let proc = process, proc.isRunning {
            proc.terminate()
        }
        process = nil
        isRunning = false
    }
}

