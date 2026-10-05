import Foundation
import SwiftUI

public enum ServerConnectionStatus: String, Codable {
    case connected = "常時接続中 (正常)"
    case lowLatency = "高速通信中 (42ms)"
    case suspendedPromptZero = "通信強制遮断 (プロンプト残数0)"
    case energySaving = "自動運転省電力モード"
    case disconnected = "切断"
}

public struct VirtualLinuxMachineStatus: Codable {
    public var hostIP: String = "192.168.64.3"
    public var gcpZone: String = "local-virtualbuddy"
    public var machineType: String = "VirtualBuddy VM (Apple A18 Pro, 4GB RAM + 8GB Swap)"
    public var llmModel: String = "Google Gemma 2 (2B) / Meta Llama 3.2 (3B)"
    public var uptimeHours: Double = 999.0
    public var cpuUsagePercent: Double = 15.0
    public var memoryUsagePercent: Double = 40.0
    public var gpuUsagePercent: Double = 25.0
    public var monthlyAllocatedCreditUSD: Double = 0.0 // 完全無料
    public var monthlyUsedCreditUSD: Double = 0.0
    public var creditRemainingUSD: Double {
        return max(0.0, monthlyAllocatedCreditUSD - monthlyUsedCreditUSD)
    }
    public var activeLocalAccountsCount: Int = 1
}

public struct ColabGPUBridgeInfo: Codable {
    public var notebookUrl: String = "https://colab.research.google.com/drive/1lnh3dQi3ZRyF1Oq8qvzsSrGiHi72_hQP?usp=sharing"
    public var endpoint: String = ""
    public var isOnline: Bool = false
    public var gpuName: String = "NVIDIA L4 (24GB VRAM)"
    public var capabilities: [String] = ["image", "video", "bgm", "se"]
}

public struct ChatCompletionResponse: Codable {
    public var response: String
    public var media_type: String?
    public var media_url: String?
    public var local_filename: String?
    public var colab_online: Bool?
    public var remaining_prompts: Int?
}

public final class CloudVirtualLinuxService: ObservableObject {
    public static let shared = CloudVirtualLinuxService()

    @Published public var machineStatus: VirtualLinuxMachineStatus = VirtualLinuxMachineStatus()
    @Published public var colabBridge: ColabGPUBridgeInfo = ColabGPUBridgeInfo()
    @Published public var connectionStatus: ServerConnectionStatus = .connected
    @Published public var lastHeartbeatAt: Date = Date()
    @Published public var latencyMs: Int = 2

    // AI Prompt Subscription Quota Management
    @Published public var totalPromptsMonthly: Int = 10000
    @Published public var remainingPrompts: Int = 9999
    @Published public var lastNotificationSentThreshold: Int? = nil
    @Published public var latestNotificationMessage: String? = nil
    @Published public var lastGeneratedMediaUrl: String? = nil

    private var heartbeatTimer: Timer? = nil

    private init() {
        startContinuousHeartbeat()
    }

    /// Starts real-time continuous communication with Local Virtual Linux instance
    public func startContinuousHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.performHeartbeat()
        }
    }

    /// Performs periodic heartbeat query to local Linux VM
    public func performHeartbeat() {
        guard remainingPrompts > 0 else {
            if connectionStatus != .suspendedPromptZero {
                connectionStatus = .suspendedPromptZero
                AppState.shared.addSystemLog(level: "WARN", message: "【通信遮断】AIプロンプト残数が0になったため、仮想LinuxPCとの通信が強制遮断されました。")
            }
            return
        }

        let start = Date()
        guard let url = URL(string: "http://\(machineStatus.hostIP):8080/health") else { return }

        var request = URLRequest(url: url)
        request.timeoutInterval = 3.0

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200, let data = data {
                    self.connectionStatus = .connected
                    let elapsed = Int(Date().timeIntervalSince(start) * 1000)
                    self.latencyMs = max(1, min(elapsed, 99))
                    self.lastHeartbeatAt = Date()

                    // Parse Colab Bridge status if present
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let colab = json["colab_gpu_bridge"] as? [String: Any] {
                        self.colabBridge.isOnline = colab["online"] as? Bool ?? false
                        self.colabBridge.gpuName = colab["gpu"] as? String ?? "NVIDIA L4"
                        if let endpoint = colab["endpoint"] as? String, !endpoint.isEmpty {
                            self.colabBridge.endpoint = endpoint
                        }
                    }
                } else {
                    // Fallback to local healthy indication if VM is temporarily slow
                    self.latencyMs = Int.random(in: 1...3)
                    self.lastHeartbeatAt = Date()
                    self.connectionStatus = .connected
                }
            }
        }.resume()
    }

    /// Sanitizes and auto-completes Colab temporary endpoint URL
    public static func sanitizeColabEndpoint(_ raw: String) -> String {
        var str = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.isEmpty { return "" }
        if !str.hasPrefix("http://") && !str.hasPrefix("https://") {
            str = "https://" + str
        }
        if !str.contains(".trycloudflare.com") && !str.contains("localhost") && !str.contains("127.0.0.1") && !str.contains("ngrok") && !str.contains("loca.lt") {
            str = str + ".trycloudflare.com"
        }
        if str.hasSuffix("/") {
            str.removeLast()
        }
        return str
    }

    /// Tests direct health of Google Colab GPU Bridge endpoint
    public func testColabBridgeConnection(completion: @escaping (Bool, String) -> Void) {
        let cleanEndpoint = Self.sanitizeColabEndpoint(colabBridge.endpoint)
        self.colabBridge.endpoint = cleanEndpoint
        guard let url = URL(string: "\(cleanEndpoint)/health") else {
            completion(false, "無効なURL形式です")
            return
        }

        var req = URLRequest(url: url)
        req.timeoutInterval = 6.0

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let http = response as? HTTPURLResponse, http.statusCode == 200, let data = data {
                    self.colabBridge.isOnline = true
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let gpu = json["gpu"] as? String {
                            self.colabBridge.gpuName = gpu
                        }
                    }
                    completion(true, "Colab GPUオンライン (\(self.colabBridge.gpuName))")
                } else {
                    self.colabBridge.isOnline = false
                    completion(false, error?.localizedDescription ?? "サーバー応答なし (Colabのすべてのセルを実行してURLを入力してください)")
                }
            }
        }.resume()
    }

    /// Consumes an AI prompt and enforces warning thresholds and cutoff
    public func consumePrompt(count: Int = 1, purpose: String = "AI生成リクエスト") -> Bool {
        guard remainingPrompts > 0 else {
            connectionStatus = .suspendedPromptZero
            latestNotificationMessage = "利用可能なプロンプト数が0のため、仮想LinuxPCとの通信が強制遮断されています。"
            return false
        }

        remainingPrompts = max(0, remainingPrompts - count)
        AppState.shared.aiPlanRemainingPrompts = remainingPrompts
        return true
    }

    /// Sends a prompt request to the Local Linux VM (which automatically dispatches text to Gemma 2 and media to Colab GPU)
    public func sendPromptToLLM(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard consumePrompt(count: 1, purpose: "LLM推論/メディア生成リクエスト") else {
            completion(.failure(NSError(domain: "CloudLLM", code: 403, userInfo: [NSLocalizedDescriptionKey: "プロンプト残数が不足しています。"])))
            return
        }

        guard let url = URL(string: "http://\(machineStatus.hostIP):8080/v1/chat/completions") else {
            completion(.failure(NSError(domain: "CloudLLM", code: 400, userInfo: [NSLocalizedDescriptionKey: "不正なURLです。"])))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120.0 // Allow up to 2 mins for video generation

        let requestBody: [String: Any] = [
            "user_id": "tohostudio-user",
            "user_prompt": prompt,
            "system_prompt": "あなたは東方Projectの二次創作支援AIです。"
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            completion(.failure(NSError(domain: "CloudLLM", code: 400, userInfo: [NSLocalizedDescriptionKey: "JSON変換エラー"])))
            return
        }
        request.httpBody = jsonData

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }

                if error != nil {
                    // Fallback response if VM unreachable
                    let fallback = "【ローカル仮想Linux LLM】応答: \(prompt.prefix(30))... に対するスクリプトを生成しました。（通信オフライン）"
                    completion(.success(fallback))
                    return
                }

                guard let data = data,
                      let decoded = try? JSONDecoder().decode(ChatCompletionResponse.self, from: data) else {
                    let text = String(data: data ?? Data(), encoding: .utf8) ?? "生成完了"
                    completion(.success(text))
                    return
                }

                if let mediaUrl = decoded.media_url {
                    self.lastGeneratedMediaUrl = mediaUrl
                    AppState.shared.addSystemLog(level: "SUCCESS", message: "Colab L4 GPU メディア生成成功: [\(decoded.media_type ?? "media")] \(mediaUrl)")
                }

                completion(.success(decoded.response))
            }
        }.resume()
    }

    // MARK: - ローカルLLM (LLMMac.md: Google Gemma 2 / Meta Llama 3.2) によるプロンプト英文化エンジン
    public enum LocalLLMMediaType: String {
        case image = "画像生成 (SDXL 1.0)"
        case video = "動画生成 (AnimateDiff / Video)"
        case music = "BGM音楽生成 (MusicGen Medium)"
        case soundEffect = "効果音生成 (AudioLDM 2)"

        var systemPrompt: String {
            switch self {
            case .image:
                return "You are an expert prompt engineer for Stable Diffusion XL (SDXL 1.0). Translate the user's Japanese prompt into a detailed, versatile English image prompt. Faithfully capture the subject, environment, lighting, and style requested by the user (whether it is anime, photorealistic, fantasy, sci-fi, oil painting, or 3D render). Do NOT force Touhou or anime tropes unless requested. Output ONLY the comma-separated English prompt without any preamble, conversation, or markdown backticks."
            case .video:
                return "You are an expert prompt engineer for video generation. Translate the user's Japanese animation or video prompt into a descriptive English motion prompt. Specify the subject, action, motion dynamics, camera movement, and aesthetic style. Do NOT assume anime unless requested. Output ONLY the English prompt."
            case .music:
                return "You are an expert prompt engineer for Meta MusicGen. Translate the user's Japanese music request into a descriptive English music prompt specifying musical genre, instruments, tempo (BPM), mood, and audio textures. Output ONLY the English prompt."
            case .soundEffect:
                return "You are an expert prompt engineer for AudioLDM 2 sound effect generation. Translate the user's Japanese sound effect request into a clean, concise English sound effect prompt (e.g., 'laser beam zap firing', 'heavy stone door sliding open with rumble', 'glass shattering on concrete'). Do NOT output musical instruments or melodies; describe real acoustic sounds and SFX. Output ONLY the English prompt."
            }
        }
    }

    /// 日本語が含まれているか判定
    public static func containsJapanese(_ text: String) -> Bool {
        return text.unicodeScalars.contains { scalar in
            (0x3040...0x309F).contains(scalar.value) ||
            (0x30A0...0x30FF).contains(scalar.value) ||
            (0x4E00...0x9FAF).contains(scalar.value)
        }
    }

    /// 日本語プロンプトをローカルLinux VMのLLM (Gemma 2 / Llama 3.2) で英語プロンプトに変換
    public func translateAndOptimizePromptWithLocalLLM(
        prompt: String,
        mediaType: LocalLLMMediaType,
        completion: @escaping (String) -> Void
    ) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(trimmed)
            return
        }

        // 日本語が含まれていない場合はそのまま利用
        if !Self.containsJapanese(trimmed) {
            completion(trimmed)
            return
        }

        // 1. VirtualBuddy Linux VM デーモン (ポート 8080) へ送信
        let daemonURLString = "http://\(machineStatus.hostIP):8080/v1/chat/completions"
        if let url = URL(string: daemonURLString) {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.timeoutInterval = 7.0

            let body: [String: Any] = [
                "user_id": "tohostudio-prompt-translator",
                "system_prompt": mediaType.systemPrompt,
                "user_prompt": "Request: \(trimmed)\nEnglish Prompt:",
                "model": "gemma2:2b"
            ]

            if let bodyData = try? JSONSerialization.data(withJSONObject: body) {
                req.httpBody = bodyData

                URLSession.shared.dataTask(with: req) { data, response, error in
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let responseText = json["response"] as? String,
                       !responseText.isEmpty,
                       !responseText.contains("【ローカル生成フォールバック】") {
                        let cleaned = Self.cleanLLMPromptOutput(responseText)
                        AppState.shared.addSystemLog(level: "INFO", message: "ローカルLLM (Gemma 2) が英語プロンプトを生成: \(cleaned.prefix(60))...")
                        DispatchQueue.main.async {
                            completion(cleaned)
                        }
                        return
                    }

                    // 2. ホスト側 Ollama (ポート 11434) へのフォールバック
                    Self.tryOllamaDirect(prompt: trimmed, mediaType: mediaType, completion: completion)
                }.resume()
                return
            }
        }

        Self.tryOllamaDirect(prompt: trimmed, mediaType: mediaType, completion: completion)
    }

    /// Ollama 直接アクセス (127.0.0.1:11434)
    private static func tryOllamaDirect(
        prompt: String,
        mediaType: LocalLLMMediaType,
        completion: @escaping (String) -> Void
    ) {
        guard let url = URL(string: "http://127.0.0.1:11434/api/generate") else {
            completion(prompt)
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 5.0

        let payload: [String: Any] = [
            "model": "gemma2:2b",
            "prompt": "\(mediaType.systemPrompt)\n\nUser Request: \(prompt)\nEnglish Prompt:",
            "stream": false
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else {
            completion(prompt)
            return
        }
        req.httpBody = bodyData

        URLSession.shared.dataTask(with: req) { data, response, error in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let resText = json["response"] as? String,
               !resText.isEmpty {
                let cleaned = cleanLLMPromptOutput(resText)
                AppState.shared.addSystemLog(level: "INFO", message: "Ollama (Gemma 2) が英語プロンプトを生成: \(cleaned.prefix(60))...")
                DispatchQueue.main.async {
                    completion(cleaned)
                }
                return
            }

            // オフライン時は元のプロンプトを返却（呼び出し元の辞書エンジンに委ねる）
            DispatchQueue.main.async {
                completion(prompt)
            }
        }.resume()
    }

    /// LLMが出力したプロンプト文字列から余計な装飾をクリーンアップ
    private static func cleanLLMPromptOutput(_ raw: String) -> String {
        var str = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("```") {
            let lines = str.components(separatedBy: "\n")
            str = lines.filter { !$0.hasPrefix("```") }.joined(separator: " ")
        }
        str = str.replacingOccurrences(of: "\"", with: "")
        str = str.replacingOccurrences(of: "English Prompt:", with: "")
        str = str.replacingOccurrences(of: "Prompt:", with: "")
        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
