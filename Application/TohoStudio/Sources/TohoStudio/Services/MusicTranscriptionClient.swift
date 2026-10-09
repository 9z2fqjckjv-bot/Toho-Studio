import Foundation

/// 音楽メディア（WAV/MP3/M4A等）から五線譜PDFへの自動採譜を行う通信クライアント
public final class MusicTranscriptionClient {
    public static let shared = MusicTranscriptionClient()

    public enum TranscriptionError: LocalizedError {
        case invalidURL
        case fileNotFound(URL)
        case unreadableFile(String)
        case serverError(statusCode: Int, message: String)
        case networkError(Error)
        case invalidResponseData

        public var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "無効なサーバーURLです。"
            case .fileNotFound(let url):
                return "指定された音声ファイルが見つかりません: \(url.lastPathComponent)"
            case .unreadableFile(let msg):
                return "音声ファイルの読み込みに失敗しました: \(msg)"
            case .serverError(let code, let msg):
                return "サーバーエラー (\(code)): \(msg)"
            case .networkError(let error):
                return "通信エラーが発生しました: \(error.localizedDescription)"
            case .invalidResponseData:
                return "サーバーから返却されたPDFデータが無効または空です。"
            }
        }
    }

    /// 対象のホストIP（初期値は CloudVirtualLinuxService.shared の設定を参照）
    public var customHostIP: String? = nil

    public var effectiveHostIP: String {
        if let custom = customHostIP, !custom.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return custom
        }
        return CloudVirtualLinuxService.shared.machineStatus.hostIP
    }

    public var port: Int = 8080

    public init(customHostIP: String? = nil, port: Int = 8080) {
        self.customHostIP = customHostIP
        self.port = port
    }

    /// サーバーのヘルスチェックおよび自動採譜サポート状況を確認
    public func checkServerCapability() async -> (isOnline: Bool, isTranscriptionSupported: Bool, message: String) {
        guard let url = URL(string: "http://\(effectiveHostIP):\(port)/health") else {
            return (false, false, "無効なURL形式です")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
                return (false, false, "サーバー応答コード異常")
            }

            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let status = json["status"] as? String ?? ""
                if let transcription = json["music_transcription"] as? [String: Any],
                   let supported = transcription["supported"] as? Bool {
                    return (status == "OPERATIONAL", supported, supported ? "採譜エンジン利用可能" : "採譜モジュール初期化待ち")
                }
                return (status == "OPERATIONAL", true, "接続成功 (通常モード)")
            }
            return (true, true, "接続成功")
        } catch {
            return (false, false, error.localizedDescription)
        }
    }

    /// 音声ファイルから自動採譜を実行し、生成された五線譜PDFバイナリ (Data) を取得
    /// - Parameter audioFileURL: 入力オーディオファイルのローカルURL
    /// - Returns: 生成されたPDFのバイナリデータ
    public func transcribe(audioFileURL: URL) async throws -> Data {
        let isSecurityScoped = audioFileURL.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                audioFileURL.stopAccessingSecurityScopedResource()
            }
        }

        guard FileManager.default.fileExists(atPath: audioFileURL.path) else {
            throw TranscriptionError.fileNotFound(audioFileURL)
        }

        let fileData: Data
        do {
            fileData = try Data(contentsOf: audioFileURL)
        } catch {
            throw TranscriptionError.unreadableFile(error.localizedDescription)
        }

        guard let endpointURL = URL(string: "http://\(effectiveHostIP):\(port)/v1/audio/transcribe-to-sheet") else {
            throw TranscriptionError.invalidURL
        }

        var request = URLRequest(url: endpointURL)
        request.httpMethod = "POST"
        // AI音声解析とLilyPond楽譜組版に時間を要するため180秒に設定
        request.timeoutInterval = 180.0

        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let filename = audioFileURL.lastPathComponent
        let mimeType = mimeTypeForPath(extension: audioFileURL.pathExtension)

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(fileData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        let responseData: Data
        let response: URLResponse
        do {
            (responseData, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw TranscriptionError.networkError(error)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TranscriptionError.invalidResponseData
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorMsg = String(data: responseData, encoding: .utf8) ?? "不明なサーバーエラー"
            throw TranscriptionError.serverError(statusCode: httpResponse.statusCode, message: errorMsg)
        }

        guard !responseData.isEmpty else {
            throw TranscriptionError.invalidResponseData
        }

        return responseData
    }

    private func mimeTypeForPath(extension ext: String) -> String {
        switch ext.lowercased() {
        case "wav": return "audio/wav"
        case "mp3": return "audio/mpeg"
        case "m4a": return "audio/mp4"
        case "flac": return "audio/flac"
        case "ogg": return "audio/ogg"
        case "aif", "aiff": return "audio/aiff"
        default: return "application/octet-stream"
        }
    }
}
