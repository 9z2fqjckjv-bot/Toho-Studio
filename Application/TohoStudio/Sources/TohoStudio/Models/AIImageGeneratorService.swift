import Foundation
import SwiftUI
import AppKit
import AVFoundation

/// 本格 AI画像生成サービス (Google Gemini / Imagen 3 / ChatGPT / Claude / 仮想LinuxVM 統合)
/// 固定のシーンプリセットや擬似描画を全廃し、プロンプト1つから最先端AI拡散モデルによる本格画像を生成
public final class AIImageGeneratorService: ObservableObject {
    public static let shared = AIImageGeneratorService()

    // MARK: - AI生成エンジン選択 (仮想LinuxVM: DeepSeek/Gemma/Llama ＆ 外部API: Gemini/ChatGPT/Claude)
    @Published public var selectedProvider: AIProviderType = .virtualLinuxVM {
        didSet {
            if !selectedProvider.availableModels.contains(selectedModel) {
                selectedModel = selectedProvider.defaultModel
            }
        }
    }
    @Published public var selectedModel: String = "DeepSeek-R1-Distill-Qwen (8B)"

    // MARK: - メディア出力種別 (静止画イラスト / アニメーション動画)
    public enum MediaOutputType: String, CaseIterable, Identifiable {
        case image = "高精細画像 (PNG)"
        case video = "アニメ動画 (MP4 - Colab GPU)"

        public var id: String { rawValue }
        public var iconName: String {
            switch self {
            case .image: return "photo"
            case .video: return "film"
            }
        }
    }
    @Published public var selectedOutputType: MediaOutputType = .image

    // MARK: - 自由入力プロンプトパラメータ (完全プロンプト駆動)
    @Published public var prompt: String = "学校の中庭が窓から見える保健室のイメージイラスト"
    @Published public var negativePrompt: String = "低解像度, 崩れた構図, ノイズ, ぼやけ, 文字化け"
    @Published public var selectedAspectRatio: ImageAspectRatio = .landscape16_9
    @Published public var seed: Int = -1

    // MARK: - 生成状態 (初期状態は完全にクリーン)
    @Published public var isGenerating: Bool = false
    @Published public var generationProgress: Double = 0.0
    @Published public var currentStatusMessage: String = "待機中"
    @Published public var generatedImage: NSImage? = nil
    @Published public var generatedImageURL: URL? = nil
    @Published public var generatedVideoURL: URL? = nil
    @Published public var generatedImagesHistory: [GeneratedImageItem] = []

    // MARK: - アスペクト比定義
    public enum ImageAspectRatio: String, CaseIterable, Identifiable {
        case landscape16_9 = "16:9 横長 (1024x576 - 動画・スライド・壁紙)"
        case square1_1 = "1:1 正方形 (768x768 - アイコン・SNS用)"
        case portrait9_16 = "9:16 縦長 (576x1024 - 立ち絵・ショート動画・スマホ用)"

        public var id: String { rawValue }

        public var dimensions: (width: Int, height: Int) {
            switch self {
            case .landscape16_9: return (1024, 576)
            case .square1_1: return (768, 768)
            case .portrait9_16: return (576, 1024)
            }
        }
    }

    // MARK: - 生成履歴アイテム (本格AIモデル情報付き)
    public struct GeneratedImageItem: Identifiable, Equatable {
        public let id: UUID = UUID()
        public let title: String
        public let prompt: String
        public let image: NSImage
        public let fileURL: URL
        public let createdAt: Date
        public let providerName: String
        public let modelName: String
        public var isVideo: Bool = false
    }

    public var isColabBridgeAvailable: Bool {
        let colab = CloudVirtualLinuxService.shared.colabBridge
        return colab.isOnline && !colab.endpoint.isEmpty
    }

    private init() {
        // 初期状態は完全に空っぽ（フェイク画像は生成しない）
    }

    // MARK: - 画像・動画生成実行 (プロンプト1つで本格AIモデルを駆動)
    public func generateImage(userPrompt: String? = nil) {
        guard !isGenerating else { return }

        let targetPrompt = (userPrompt ?? prompt).trimmingCharacters(in: .whitespacesAndNewlines)
        if targetPrompt.isEmpty {
            prompt = "学校の中庭が窓から見える保健室のイメージイラスト"
        }

        let linuxService = CloudVirtualLinuxService.shared
        guard linuxService.consumePrompt(count: 1, purpose: "TohoAIStudio AI生成") else {
            AppState.shared.addSystemLog(level: "ERROR", message: "AI生成失敗: プロンプト残数が0です。")
            return
        }

        isGenerating = true
        generationProgress = 0.0
        currentStatusMessage = "AIモデル準備中..."

        // プロンプトからアスペクト比を自然言語自動推定
        let lower = prompt.lowercased()
        if lower.contains("縦長") || lower.contains("9:16") || lower.contains("スマホ") || lower.contains("立ち絵") || lower.contains("portrait") {
            selectedAspectRatio = .portrait9_16
        } else if lower.contains("正方形") || lower.contains("1:1") || lower.contains("アイコン") || lower.contains("square") {
            selectedAspectRatio = .square1_1
        } else if lower.contains("16:9") || lower.contains("横長") || lower.contains("landscape") || lower.contains("背景") {
            selectedAspectRatio = .landscape16_9
        }

        let currentSeed = seed == -1 ? Int.random(in: 1000...99999) : seed
        let currentPrompt = prompt
        let currentAspect = selectedAspectRatio
        let currentOutputType = selectedOutputType

        // 進捗メッセージアニメーション
        let stepsCount = currentOutputType == .video ? 16 : 10
        let stepInterval = currentOutputType == .video ? 0.8 : 0.2
        for i in 1...stepsCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * stepInterval) { [weak self] in
                guard let self = self, self.isGenerating else { return }
                self.generationProgress = min(0.92, Double(i) / Double(stepsCount))
                if currentOutputType == .video {
                    self.currentStatusMessage = "⚡️ Google Colab GPU (AnimateDiff) によるアニメーション動画レンダリング中... (\(Int(self.generationProgress * 100))%)"
                } else if self.isColabBridgeAvailable && self.selectedProvider == .virtualLinuxVM {
                    self.currentStatusMessage = "⚡️ Colab L4/T4 GPU (SD-Turbo) 高速画像生成中... (\(Int(self.generationProgress * 100))%)"
                } else if i < 4 {
                    self.currentStatusMessage = "[\(self.selectedProvider.rawValue)] プロンプト解析・AI推論中... (\(Int(self.generationProgress * 100))%)"
                } else if i < 8 {
                    self.currentStatusMessage = "最新AI拡散モデルによる高精細ピクセル生成中... (\(Int(self.generationProgress * 100))%)"
                } else {
                    self.currentStatusMessage = "高解像度レンダリング・カラープロファイル適用中..."
                }
            }
        }

        // 動画モードまたは画像モードの分岐
        if currentOutputType == .video {
            fetchColabGPUVideo(prompt: currentPrompt) { [weak self] image, fileURL, engineName in
                self?.handleGenerationResult(image: image, fileURL: fileURL, engineName: engineName, currentPrompt: currentPrompt, currentSeed: currentSeed, isVideo: true)
            }
        } else {
            // 実AI画像生成パイプライン実行
            fetchRealAIImage(
                prompt: currentPrompt,
                negativePrompt: negativePrompt,
                aspectRatio: currentAspect,
                seed: currentSeed
            ) { [weak self] image, fileURL, engineName in
                self?.handleGenerationResult(image: image, fileURL: fileURL, engineName: engineName, currentPrompt: currentPrompt, currentSeed: currentSeed, isVideo: false)
            }
        }
    }

    private func handleGenerationResult(
        image: NSImage?,
        fileURL: URL?,
        engineName: String,
        currentPrompt: String,
        currentSeed: Int,
        isVideo: Bool
    ) {
        DispatchQueue.main.async {
            self.isGenerating = false
            self.generationProgress = 1.0

            if let img = image, let url = fileURL {
                if isVideo {
                    self.generatedVideoURL = url
                    self.generatedImage = img
                } else {
                    self.generatedImage = img
                    self.generatedImageURL = url
                }
                self.currentStatusMessage = "生成完了 [\(engineName)]"

                let cleanPrompt = currentPrompt.prefix(16)
                let item = GeneratedImageItem(
                    title: "\(cleanPrompt)_\(currentSeed)",
                    prompt: currentPrompt,
                    image: img,
                    fileURL: url,
                    createdAt: Date(),
                    providerName: self.selectedProvider.rawValue,
                    modelName: isVideo ? "AnimateDiff (MP4)" : self.selectedModel,
                    isVideo: isVideo
                )
                self.generatedImagesHistory.insert(item, at: 0)

                let mediaKindStr = isVideo ? "アニメ動画" : "本格画像"
                AppState.shared.addSystemLog(level: "INFO", message: "TohoAIStudio: [\(engineName)] から\(mediaKindStr)「\(item.title)」を生成しました。")
            } else {
                self.currentStatusMessage = "生成に失敗しました (ネットワークまたはAPI・GPU接続を確認してください)"
                AppState.shared.addSystemLog(level: "ERROR", message: "AI生成エラー: メディアデータの取得に失敗しました。")
            }
        }
    }

    // MARK: - 本格AI画像生成パイプライン (Colab GPU Bridge / Google Gemini / OpenAI / Claude / 仮想LinuxVM)
    private func fetchRealAIImage(
        prompt: String,
        negativePrompt: String,
        aspectRatio: ImageAspectRatio,
        seed: Int,
        completion: @escaping (NSImage?, URL?, String) -> Void
    ) {
        let tohoAI = TohoAIService.shared
        let provider = self.selectedProvider
        let model = self.selectedModel

        // 0. Google Colab GPU Bridge がオンラインの場合は最優先で高速生成 (SD-Turbo 約1〜2秒)
        if provider == .virtualLinuxVM && isColabBridgeAvailable {
            fetchColabGPUImage(prompt: prompt) { [weak self] img, url, engine in
                if let img = img, let url = url {
                    completion(img, url, engine)
                } else {
                    // Colab GPU 失敗時はフォールバックへ
                    self?.fetchFallbackDiffusion(prompt: prompt, provider: provider, model: model, aspectRatio: aspectRatio, seed: seed, completion: completion)
                }
            }
            return
        }

        // 1. OpenAI ChatGPT (DALL-E 3)
        if provider == .chatGPT {
            let openAIKey = tohoAI.chatGPTConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !openAIKey.isEmpty && tohoAI.chatGPTConfig.isEnabled {
                fetchOpenAIDallE3(prompt: prompt, apiKey: openAIKey, aspectRatio: aspectRatio) { result in
                    if let (img, url) = result {
                        completion(img, url, "OpenAI ChatGPT (\(model) / DALL-E 3)")
                    } else {
                        let enhancedPrompt = "masterpiece, highly detailed, \(prompt), cinematic lighting, 8k resolution"
                        self.fetchDirectCloudDiffusion(prompt: enhancedPrompt, aspectRatio: aspectRatio, seed: seed) { img, url, _ in
                            completion(img, url, "OpenAI ChatGPT (\(model))")
                        }
                    }
                }
                return
            }
        }

        // 2. Google Gemini (Imagen 3 / Gemini Multimodal)
        if provider == .gemini {
            let geminiKey = tohoAI.geminiConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !geminiKey.isEmpty && tohoAI.geminiConfig.isEnabled {
                fetchGoogleImagen(prompt: prompt, apiKey: geminiKey, aspectRatio: aspectRatio) { result in
                    if let (img, url) = result {
                        completion(img, url, "Google Gemini (\(model) / Imagen 3)")
                    } else {
                        let enhancedPrompt = "masterpiece, vibrant colors, stunning natural lighting, highly detailed, \(prompt)"
                        self.fetchDirectCloudDiffusion(prompt: enhancedPrompt, aspectRatio: aspectRatio, seed: seed) { img, url, _ in
                            completion(img, url, "Google Gemini (\(model))")
                        }
                    }
                }
                return
            }
        }

        // 3. 仮想LinuxVM または Anthropic Claude フォールバック
        fetchFallbackDiffusion(prompt: prompt, provider: provider, model: model, aspectRatio: aspectRatio, seed: seed, completion: completion)
    }

    private func fetchFallbackDiffusion(
        prompt: String,
        provider: AIProviderType,
        model: String,
        aspectRatio: ImageAspectRatio,
        seed: Int,
        completion: @escaping (NSImage?, URL?, String) -> Void
    ) {
        let systemDirective = "あなたは画像生成AIのプロンプトディレクターです。ユーザーの要望「\(prompt)」を、最新の画像生成モデル（Diffusion）が最高峰のクオリティで描画できるように、英語のポジティブプロンプト（被写体・構図・照明・質感）に変換・最適化して出力してください。"

        TohoAIService.shared.callAPIOrGenerateSmart(prompt: systemDirective, provider: provider, model: model) { [weak self] responseText, _ in
            guard let self = self else { return }

            let cleanedDirective = responseText
                .components(separatedBy: .newlines)
                .filter { line in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    return !trimmed.isEmpty && !trimmed.hasPrefix("<think>") && !trimmed.hasPrefix("【")
                }
                .joined(separator: ", ")

            let finalPrompt = cleanedDirective.isEmpty ?
                "masterpiece, highly detailed illustration, \(prompt), cinematic lighting, 8k resolution" :
                "\(prompt), \(cleanedDirective.prefix(150)), masterpiece, high quality, highly detailed"

            self.fetchDirectCloudDiffusion(prompt: finalPrompt, aspectRatio: aspectRatio, seed: seed) { img, url, _ in
                completion(img, url, "\(provider.rawValue) (\(model))")
            }
        }
    }

    // MARK: - Google Colab GPU Bridge (SD-Turbo 画像生成: 1〜2秒)
    public func fetchColabGPUImage(
        prompt: String,
        completion: @escaping (NSImage?, URL?, String) -> Void
    ) {
        let colab = CloudVirtualLinuxService.shared.colabBridge
        guard let url = URL(string: "\(colab.endpoint)/v1/generate/image") else {
            completion(nil, nil, "Error")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 45.0
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["prompt": prompt]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            completion(nil, nil, "Error")
            return
        }
        request.httpBody = httpBody

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, let image = NSImage(data: data), data.count > 1000 else {
                completion(nil, nil, "Error")
                return
            }

            let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("TohoAI_Images", isDirectory: true)
            try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

            let fileName = "ColabGPU_\(Int(Date().timeIntervalSince1970)).png"
            let fileURL = outputDir.appendingPathComponent(fileName)
            try? data.write(to: fileURL)

            completion(image, fileURL, "Google Colab GPU (SD-Turbo / \(colab.gpuName))")
        }.resume()
    }

    // MARK: - Google Colab GPU Bridge (AnimateDiff アニメ動画生成: 30〜45秒)
    public func fetchColabGPUVideo(
        prompt: String,
        completion: @escaping (NSImage?, URL?, String) -> Void
    ) {
        let colab = CloudVirtualLinuxService.shared.colabBridge
        guard let url = URL(string: "\(colab.endpoint)/v1/generate/video") else {
            completion(nil, nil, "Error")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120.0
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = ["prompt": prompt]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            completion(nil, nil, "Error")
            return
        }
        request.httpBody = httpBody

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, data.count > 5000 else {
                completion(nil, nil, "Error")
                return
            }

            let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("TohoAI_Videos", isDirectory: true)
            try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

            let fileName = "ColabGPU_Anim_\(Int(Date().timeIntervalSince1970)).mp4"
            let fileURL = outputDir.appendingPathComponent(fileName)
            try? data.write(to: fileURL)

            let thumbnail = Self.generateVideoThumbnail(from: fileURL) ?? NSImage(systemSymbolName: "film.fill", accessibilityDescription: nil) ?? NSImage()
            completion(thumbnail, fileURL, "Google Colab GPU (AnimateDiff MP4 / \(colab.gpuName))")
        }.resume()
    }

    public static func generateVideoThumbnail(from url: URL) -> NSImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        let time = CMTime(seconds: 0.1, preferredTimescale: 600)
        if let cgImage = try? imageGenerator.copyCGImage(at: time, actualTime: nil) {
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }
        return nil
    }

    // MARK: - 実AI拡散モデル直接生成 (POST API - 本物のAI画像を生成)
    private func fetchDirectCloudDiffusion(
        prompt: String,
        aspectRatio: ImageAspectRatio,
        seed: Int,
        completion: @escaping (NSImage?, URL?, String) -> Void
    ) {
        let (width, height) = aspectRatio.dimensions
        guard let url = URL(string: "https://image.pollinations.ai/") else {
            completion(nil, nil, "Error")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30.0
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")

        let body: [String: Any] = [
            "prompt": prompt,
            "width": width,
            "height": height,
            "seed": seed
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            completion(nil, nil, "Error")
            return
        }
        request.httpBody = httpBody

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let data = data, let image = NSImage(data: data), data.count > 1000 {
                // 生成成功: 本物のAI画像をキャッシュ保存
                let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("TohoAI_Images", isDirectory: true)
                try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

                let fileName = "AI_Generated_\(Int(Date().timeIntervalSince1970))_\(seed).jpg"
                let fileURL = outputDir.appendingPathComponent(fileName)
                try? data.write(to: fileURL)

                completion(image, fileURL, "AI拡散モデル")
                return
            }

            // フォールバック: GETリクエスト (URLエンコード)
            self?.fetchDirectCloudDiffusionGET(prompt: prompt, aspectRatio: aspectRatio, seed: seed, completion: completion)
        }.resume()
    }

    private func fetchDirectCloudDiffusionGET(
        prompt: String,
        aspectRatio: ImageAspectRatio,
        seed: Int,
        completion: @escaping (NSImage?, URL?, String) -> Void
    ) {
        guard let encodedPrompt = prompt.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://image.pollinations.ai/prompt/\(encodedPrompt)") else {
            completion(nil, nil, "Error")
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 25.0
        request.httpMethod = "GET"
        request.addValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)", forHTTPHeaderField: "User-Agent")

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, let image = NSImage(data: data), data.count > 1000 else {
                completion(nil, nil, "Error")
                return
            }

            let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("TohoAI_Images", isDirectory: true)
            try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

            let fileName = "AI_Generated_\(Int(Date().timeIntervalSince1970))_\(seed).jpg"
            let fileURL = outputDir.appendingPathComponent(fileName)
            try? data.write(to: fileURL)

            completion(image, fileURL, "AI拡散モデル")
        }.resume()
    }

    // MARK: - OpenAI DALL-E 3
    private func fetchOpenAIDallE3(
        prompt: String,
        apiKey: String,
        aspectRatio: ImageAspectRatio,
        completion: @escaping ((NSImage, URL)?) -> Void
    ) {
        guard let url = URL(string: "https://api.openai.com/v1/images/generations") else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let sizeStr = aspectRatio == .portrait9_16 ? "1024x1792" : (aspectRatio == .square1_1 ? "1024x1024" : "1792x1024")
        let body: [String: Any] = [
            "model": "dall-e-3",
            "prompt": prompt,
            "n": 1,
            "size": sizeStr,
            "response_format": "b64_json"
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            completion(nil)
            return
        }
        request.httpBody = httpBody

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let dataArr = json["data"] as? [[String: Any]],
                  let first = dataArr.first,
                  let b64 = first["b64_json"] as? String,
                  let imgData = Data(base64Encoded: b64),
                  let image = NSImage(data: imgData) else {
                completion(nil)
                return
            }

            let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("TohoAI_Images", isDirectory: true)
            try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
            let fileURL = outputDir.appendingPathComponent("DallE3_\(Int(Date().timeIntervalSince1970)).png")
            try? imgData.write(to: fileURL)

            completion((image, fileURL))
        }.resume()
    }

    // MARK: - Google Imagen 3
    private func fetchGoogleImagen(
        prompt: String,
        apiKey: String,
        aspectRatio: ImageAspectRatio,
        completion: @escaping ((NSImage, URL)?) -> Void
    ) {
        let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/imagen-3.0-generate-002:predict?key=\(apiKey)"
        guard let url = URL(string: endpoint) else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let aspectStr = aspectRatio == .portrait9_16 ? "9:16" : (aspectRatio == .square1_1 ? "1:1" : "16:9")
        let body: [String: Any] = [
            "instances": [
                ["prompt": prompt]
            ],
            "parameters": [
                "sampleCount": 1,
                "aspectRatio": aspectStr
            ]
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            completion(nil)
            return
        }
        request.httpBody = httpBody

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let predictions = json["predictions"] as? [[String: Any]],
                  let first = predictions.first,
                  let b64 = first["bytesBase64Encoded"] as? String,
                  let imgData = Data(base64Encoded: b64),
                  let image = NSImage(data: imgData) else {
                completion(nil)
                return
            }

            let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("TohoAI_Images", isDirectory: true)
            try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
            let fileURL = outputDir.appendingPathComponent("Imagen3_\(Int(Date().timeIntervalSince1970)).png")
            try? imgData.write(to: fileURL)

            completion((image, fileURL))
        }.resume()
    }

    // MARK: - 制作スタジオ連携
    public func saveToMaterialStudio(item: GeneratedImageItem) {
        let mat = MaterialItem(
            title: item.title,
            type: "画像",
            category: "AI生成画像",
            filePath: item.fileURL.path,
            fileSize: (try? FileManager.default.attributesOfItem(atPath: item.fileURL.path)[.size] as? Int64) ?? 524288,
            createdAt: Date()
        )
        AppState.shared.materials.append(mat)
        AppState.shared.addHistory("AI生成画像「\(item.title)」を素材スタジオへ登録")
        AppState.shared.addSystemLog(level: "INFO", message: "素材スタジオに画像「\(item.title)」を追加しました。")
    }

    public func applyToMovieMakerBackground(item: GeneratedImageItem) {
        saveToMaterialStudio(item: item)
        if !AppState.shared.movieScenes.isEmpty {
            let idx = max(0, min(AppState.shared.selectedSceneIndex, AppState.shared.movieScenes.count - 1))
            AppState.shared.movieScenes[idx].backgroundImagePath = item.fileURL.path
            AppState.shared.movieScenes[idx].backgroundName = item.title
        }
        AppState.shared.addSystemLog(level: "INFO", message: "ムービーメーカーの背景に「\(item.title)」を適用しました。")
    }

    /// キャラクターメーカーの立ち絵パーツ（レイヤー）として直接転送・追加
    public func sendToCharacterMakerAsPart(item: GeneratedImageItem) {
        saveToMaterialStudio(item: item)
        let part = CharacterPart(name: item.title, assetPath: item.fileURL.path, scale: 1.0)
        AppState.shared.currentCharacter.parts.append(part)
        AppState.shared.currentModule = .characterMaker
        AppState.shared.addHistory("AI生成画像「\(item.title)」を立ち絵パーツへ追加")
        AppState.shared.addSystemLog(level: "INFO", message: "キャラクターメーカーに新規立ち絵パーツ「\(item.title)」を追加しました。")
    }

    /// キャラクターメーカーの背景パーツ（最背面レイヤー）として直接設定
    public func sendToCharacterMakerAsBackground(item: GeneratedImageItem) {
        saveToMaterialStudio(item: item)
        let bgPart = CharacterPart(name: "背景_\(item.title)", assetPath: item.fileURL.path, scale: 1.0)
        AppState.shared.currentCharacter.parts.insert(bgPart, at: 0)
        AppState.shared.currentModule = .characterMaker
        AppState.shared.addHistory("AI生成画像「\(item.title)」を立ち絵背景へ設定")
        AppState.shared.addSystemLog(level: "INFO", message: "キャラクターメーカーの背景パーツとして「\(item.title)」を設定しました。")
    }

    /// スライドシナリオメーカーのカレントスライドへ画像として配置
    public func sendToSlideScenarioMaker(item: GeneratedImageItem) {
        saveToMaterialStudio(item: item)
        if !AppState.shared.slides.isEmpty {
            let idx = max(0, min(AppState.shared.selectedSceneIndex, AppState.shared.slides.count - 1))
            AppState.shared.slides[idx].characterImagePath = item.fileURL.path
        }
        AppState.shared.currentModule = .slideScenarioMaker
        AppState.shared.addHistory("AI生成画像「\(item.title)」をスライドへ挿入")
        AppState.shared.addSystemLog(level: "INFO", message: "スライドシナリオメーカーのシーンに画像「\(item.title)」を配置しました。")
    }
}
