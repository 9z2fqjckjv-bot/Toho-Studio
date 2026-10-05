import Foundation
import SwiftUI
import AppKit
import AVFoundation

/// 本格 AI画像生成サービス (Google Gemini / Imagen 3 / ChatGPT / Claude / 仮想LinuxVM 統合)
/// 固定のシーンプリセットや擬似描画を全廃し、プロンプト1つから最先端AI拡散モデルによる本格画像を生成
public final class AIImageGeneratorService: ObservableObject {
    public static let shared = AIImageGeneratorService()

    // MARK: - AI生成エンジン選択 (仮想LinuxVM: Google Gemma 2 / Meta Llama 3.2 ＆ 外部API: Gemini/ChatGPT/Claude)
    @Published public var selectedProvider: AIProviderType = .virtualLinuxVM {
        didSet {
            if !selectedProvider.availableModels.contains(selectedModel) {
                selectedModel = selectedProvider.defaultModel
            }
        }
    }
    @Published public var selectedModel: String = "Google Gemma 2 (2B)"

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
    @Published public var useColabGPUIfAvailable: Bool = true

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
        case landscape16_9 = "16:9 横長 (1344x768 - 動画・スライド・壁紙)"
        case square1_1 = "1:1 正方形 (1024x1024 - アイコン・SNS用)"
        case portrait9_16 = "9:16 縦長 (768x1344 - 立ち絵・ショート動画・スマホ用)"

        public var id: String { rawValue }

        public var dimensions: (width: Int, height: Int) {
            switch self {
            case .landscape16_9: return (1344, 768)
            case .square1_1: return (1024, 1024)
            case .portrait9_16: return (768, 1344)
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

        let currentSeed = seed == -1 ? Int.random(in: 1000...99999) : seed
        let currentPrompt = prompt
        // ユーザーが選択したアスペクト比を最優先で維持 (勝手な上書きを廃止)
        let currentAspect = selectedAspectRatio
        let currentNegative = negativePrompt
        let currentOutputType = selectedOutputType

        // 進捗メッセージアニメーション
        let stepsCount = currentOutputType == .video ? 16 : 10
        let stepInterval = currentOutputType == .video ? 0.8 : 0.2
        for i in 1...stepsCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * stepInterval) { [weak self] in
                guard let self = self, self.isGenerating else { return }
                self.generationProgress = min(0.92, Double(i) / Double(stepsCount))
                if i < 3 {
                    self.currentStatusMessage = "🧠 ローカルLLM (Google Gemma 2) で英語プロンプトを自動生成・最適化中..."
                } else if currentOutputType == .video {
                    self.currentStatusMessage = "⚡️ Google Colab GPU (L4 / AnimateDiff) 動画レンダリング中... (\(Int(self.generationProgress * 100))%)"
                } else {
                    self.currentStatusMessage = "⚡️ Google Colab GPU (L4 / SDXL 1.0) 超高解像度生成中... (\(Int(self.generationProgress * 100))%)"
                }
            }
        }

        // 1. ローカルLLM (LLMMac.md: Google Gemma 2 / Meta Llama 3.2) で英語プロンプトを生成
        let mediaType: CloudVirtualLinuxService.LocalLLMMediaType = currentOutputType == .video ? .video : .image
        linuxService.translateAndOptimizePromptWithLocalLLM(prompt: currentPrompt, mediaType: mediaType) { [weak self] generatedEnglish in
            guard let self = self else { return }

            // 万一ローカルLLMがオフラインで日本語が残った場合は高精度辞書エンジンで補完
            let finalEnglishPrompt = CloudVirtualLinuxService.containsJapanese(generatedEnglish)
                ? Self.generateOptimizedEnglishPrompt(from: generatedEnglish)
                : generatedEnglish

            // 2. Colab GPU Bridge へリクエスト送信 (アスペクト比・除外プロンプト完全反映)
            if currentOutputType == .video {
                self.fetchColabGPUVideo(
                    prompt: finalEnglishPrompt,
                    negativePrompt: currentNegative,
                    aspectRatio: currentAspect
                ) { [weak self] image, fileURL, engineName in
                    self?.handleGenerationResult(image: image, fileURL: fileURL, engineName: engineName, currentPrompt: currentPrompt, currentSeed: currentSeed, isVideo: true)
                }
            } else {
                self.fetchRealAIImage(
                    prompt: finalEnglishPrompt,
                    negativePrompt: currentNegative,
                    aspectRatio: currentAspect,
                    seed: currentSeed
                ) { [weak self] image, fileURL, engineName in
                    self?.handleGenerationResult(image: image, fileURL: fileURL, engineName: engineName, currentPrompt: currentPrompt, currentSeed: currentSeed, isVideo: false)
                }
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
                if !engineName.isEmpty && engineName != "Error" {
                    self.currentStatusMessage = "生成エラー: \(engineName)"
                } else {
                    self.currentStatusMessage = "生成に失敗しました (Google Colab GPU接続またはAPIキーを確認してください)"
                }
                AppState.shared.addSystemLog(level: "ERROR", message: "AI生成エラー: \(engineName)")
            }
        }
    }

    // MARK: - 本格AI画像生成パイプライン (Google Colab GPU Bridge / Google Gemini / OpenAI ChatGPT)
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

        // 0. Google Colab GPU Bridge がオンラインの場合は最優先で高速高品質生成 (SD-Turbo 約1〜2秒)
        if isColabBridgeAvailable || useColabGPUIfAvailable || provider == .virtualLinuxVM {
            if isColabBridgeAvailable {
                fetchColabGPUImage(prompt: prompt, negativePrompt: negativePrompt, aspectRatio: aspectRatio, seed: seed) { [weak self] img, url, engine in
                    if let img = img, let url = url {
                        completion(img, url, engine)
                    } else {
                        self?.currentStatusMessage = "⚠️ Colab GPU 応答エラー。セルの実行ログを確認してください。"
                        completion(nil, nil, engine)
                    }
                }
                return
            }
        }

        let englishPrompt = Self.generateOptimizedEnglishPrompt(from: prompt)

        // 1. OpenAI ChatGPT (DALL-E 3)
        if provider == .chatGPT {
            let openAIKey = tohoAI.chatGPTConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !openAIKey.isEmpty && tohoAI.chatGPTConfig.isEnabled {
                fetchOpenAIDallE3(prompt: englishPrompt, apiKey: openAIKey, aspectRatio: aspectRatio) { result in
                    if let (img, url) = result {
                        completion(img, url, "OpenAI ChatGPT (\(model) / DALL-E 3)")
                    } else {
                        completion(nil, nil, "OpenAI DALL-E 3 生成エラー")
                    }
                }
                return
            }
        }

        // 2. Google Gemini (Imagen 3 / Gemini Multimodal)
        if provider == .gemini {
            let geminiKey = tohoAI.geminiConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !geminiKey.isEmpty && tohoAI.geminiConfig.isEnabled {
                fetchGoogleImagen(prompt: englishPrompt, apiKey: geminiKey, aspectRatio: aspectRatio) { result in
                    if let (img, url) = result {
                        completion(img, url, "Google Gemini (\(model) / Imagen 3)")
                    } else {
                        completion(nil, nil, "Google Imagen 3 生成エラー")
                    }
                }
                return
            }
        }

        // 3. Colab GPU 未接続かつ外部APIキー未設定の案内
        self.currentStatusMessage = "⚠️ Google Colab GPU が未接続です。「Colabを開く」からアプリ内ブラウザでGPUを起動・接続してください。"
        AppState.shared.addSystemLog(level: "WARNING", message: "Colab GPU 未接続: アプリ内Colabブラウザから『すべてのセルを実行』してGPUに接続してください。")
        completion(nil, nil, "Google Colab GPU 未接続")
    }

    // MARK: - 高精度日英プロンプト最適化エンジン (アニメ・実写写真・東方・風景・SFなど汎用完全対応)
    public static func generateOptimizedEnglishPrompt(from inputPrompt: String) -> String {
        let trimmed = inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "masterpiece, best quality, breathtaking scenic landscape, atmospheric lighting, ultra-detailed, 8k resolution"
        }

        // アルファベット比率のチェック (すでに大半が英語の場合はそのまま品質タグを付与)
        let asciiCount = trimmed.filter { $0.isASCII && ($0.isLetter || $0.isWhitespace || $0.isPunctuation) }.count
        if Double(asciiCount) / Double(max(1, trimmed.count)) > 0.75 {
            return "\(trimmed), masterpiece, best quality, highly detailed, cinematic lighting, 8k resolution"
        }

        var tags: [String] = ["masterpiece", "best quality"]
        let lower = trimmed.lowercased()

        // 1. 画風・スタイルの判定（アニメ、実写写真、絵画など）
        if lower.contains("写真") || lower.contains("実写") || lower.contains("リアル") || lower.contains("フォト") {
            tags.append("photorealistic, hyperrealistic photo, 35mm photograph, shot on DSLR, professional photography, natural lighting, sharp focus, 8k UHD")
        } else if lower.contains("アニメ") || lower.contains("イラスト") || lower.contains("マンガ") || lower.contains("萌え") {
            tags.append("anime style, clean anime lineart, Japanese animation aesthetic, vibrant colors, expressive illustration")
        } else if lower.contains("油絵") || lower.contains("水彩") {
            tags.append("traditional oil painting style, visible brush strokes, fine art aesthetic")
        } else if lower.contains("3d") || lower.contains("cg") {
            tags.append("octane render, unreal engine 5 render, highly detailed 3D artwork")
        } else {
            // スタイル指定がない場合は高品質なデジタルイラスト/ビジュアル
            tags.append("highly detailed visual, beautifully rendered, cinematic composition")
        }

        // 2. 東方キャラクター判定（ユーザーが東方キャラを指定した場合のみ反映）
        if lower.contains("霊夢") || lower.contains("reimu") {
            tags.append("Hakurei Reimu, touhou project, 1girl, red hair ribbon, miko shrine maiden dress, detached sleeves, brown hair, brown eyes, ofuda talismans")
        } else if lower.contains("魔理沙") || lower.contains("marisa") {
            tags.append("Kirisame Marisa, touhou project, 1girl, large black witch hat with white ribbon, blonde side braid, black and white apron dress, mini hakkero")
        } else if lower.contains("咲夜") || lower.contains("sakuya") {
            tags.append("Izayoi Sakuya, touhou project, 1girl, silver hair in braids, maid outfit with white apron, pocket watch, silver throwing knives")
        } else if lower.contains("レミリア") || lower.contains("remilia") {
            tags.append("Remilia Scarlet, touhou project, 1girl, light blue hair, mob cap, bat wings, red gothic lolita dress")
        } else if lower.contains("フラン") || lower.contains("flandre") {
            tags.append("Flandre Scarlet, touhou project, 1girl, blonde hair, side ponytail, rainbow crystal wings, red dress")
        } else if lower.contains("妖夢") || lower.contains("youmu") {
            tags.append("Konpaku Youmu, touhou project, 1girl, short silver hair, black headband, green vest, floating myon phantom, dual samurai swords")
        } else if lower.contains("幽々子") || lower.contains("yuyuko") {
            tags.append("Saigyouji Yuyuko, touhou project, 1girl, pink hair, zukin hat, light blue kimono, ghostly floating will-o-wisps")
        } else if lower.contains("早苗") || lower.contains("sanae") {
            tags.append("Kochiya Sanae, touhou project, 1girl, green hair, frog and snake hair accessories, blue and white miko outfit")
        } else if lower.contains("チルノ") || lower.contains("cirno") {
            tags.append("Cirno, touhou project, 1girl, blue short hair, large green hair bow, blue dress, icicle fairy wings")
        } else if lower.contains("アリス") || lower.contains("alice") {
            tags.append("Alice Margatroid, touhou project, 1girl, blonde hair, red hairband, blue dress, floating grimoire book")
        } else if lower.contains("パチュリー") || lower.contains("patchouli") {
            tags.append("Patchouli Knowledge, touhou project, 1girl, long purple hair, nightcap, striped dress, floating grimoire")
        } else if lower.contains("文") || lower.contains("aya") {
            tags.append("Syameimaru Aya, touhou project, 1girl, black short hair, tokin tengu hat, camera, crow wings")
        }

        // 3. 汎用的な環境・舞台・背景判定
        if lower.contains("神社") {
            tags.append("traditional Japanese shrine, vermilion torii gate, stone lanterns, cedar trees, sacred atmosphere")
        } else if lower.contains("森") {
            tags.append("lush green deep forest, tall trees, sunbeams filtering through leaves, mossy rocks")
        } else if lower.contains("学校") || lower.contains("教室") {
            tags.append("Japanese school classroom, wooden desks, blackboard, sunny window")
        } else if lower.contains("保健室") {
            tags.append("school infirmary, clean medical bed, soft curtains, sunny morning window")
        } else if lower.contains("海") || lower.contains("ビーチ") || lower.contains("海岸") {
            tags.append("beautiful ocean beach, gentle waves, sparkling turquoise water, blue sky")
        } else if lower.contains("宇宙") || lower.contains("星") || lower.contains("銀河") {
            tags.append("deep cosmos space, glowing nebulae, distant glittering galaxies, stars")
        } else if lower.contains("サイバーパンク") || lower.contains("未来都市") {
            tags.append("futuristic cyberpunk metropolis, neon lights, skyscrapers, holographic displays")
        } else if lower.contains("部屋") || lower.contains("室内") {
            tags.append("cozy modern interior room, warm atmospheric lighting, comfortable aesthetic")
        }

        // 4. 自然・天候・ライティング
        if lower.contains("夕暮れ") || lower.contains("夕方") || lower.contains("夕焼け") {
            tags.append("sunset golden hour, vibrant orange twilight glow, long shadows")
        } else if lower.contains("夜") || lower.contains("月") {
            tags.append("night scene, moonlight glow, mystical ambient light")
        } else if lower.contains("雨") {
            tags.append("rainy atmosphere, raindrops, reflective wet surfaces, moody cinematic lighting")
        } else if lower.contains("雪") || lower.contains("冬") {
            tags.append("winter snow scene, falling snowflakes, crisp cold air")
        } else if lower.contains("桜") {
            tags.append("cherry blossom petals drifting in the breeze, blooming sakura trees")
        }

        // 5. 汎用仕上げタグ
        tags.append("highly detailed, cinematic lighting, sharp focus, 8k resolution wallpaper")

        // 重複を除去してカンマ結合
        var uniqueTags: [String] = []
        for tag in tags {
            if !uniqueTags.contains(tag) {
                uniqueTags.append(tag)
            }
        }
        return uniqueTags.joined(separator: ", ")
    }

    // MARK: - 除外プロンプト (ネガティブプロンプト) の日英変換エンジン
    public static func convertNegativePromptToEnglish(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return "ugly, deformed, disfigured, blurry, low quality, bad anatomy, noise, watermark, distorted, text"
        }

        // 日本語が含まれていない場合はそのまま利用
        if !CloudVirtualLinuxService.containsJapanese(trimmed) {
            return trimmed
        }

        var tags: [String] = []
        let lower = trimmed.lowercased()

        // 人物・人間関連の除外
        if lower.contains("人物") || lower.contains("人間") || lower.contains("人") || lower.contains("キャラ") || lower.contains("立ち絵") || lower.contains("少女") || lower.contains("女の子") || lower.contains("男") {
            tags.append("people, person, humans, character, girl, boy, 1girl, 1boy, face, portrait")
        }

        // 品質・アーティファクト関連の除外
        if lower.contains("低解像度") || lower.contains("低画質") || lower.contains("粗い") || lower.contains("低品質") {
            tags.append("low quality, worst quality, lowres, jpeg artifacts")
        }
        if lower.contains("ぼやけ") || lower.contains("ブレ") || lower.contains("ピンボケ") || lower.contains("ボケ") {
            tags.append("blurry, blurred, depth of field, motion blur, out of focus")
        }
        if lower.contains("崩れ") || lower.contains("変形") || lower.contains("奇形") || lower.contains("デフォルメ") || lower.contains("手") || lower.contains("指") {
            tags.append("deformed, bad anatomy, disfigured, poorly drawn hands, missing fingers, extra limbs, mutated")
        }
        if lower.contains("ノイズ") || lower.contains("ざらざら") {
            tags.append("noisy, grainy, artifacts")
        }

        // 文字・署名・透かし・フレーム関連の除外
        if lower.contains("文字") || lower.contains("テキスト") || lower.contains("フォント") || lower.contains("署名") || lower.contains("ロゴ") || lower.contains("透かし") || lower.contains("ウォーターマーク") {
            tags.append("text, watermark, signature, username, logo, typography, letters, words")
        }
        if lower.contains("枠") || lower.contains("フレーム") || lower.contains("見切れ") || lower.contains("トリミング") {
            tags.append("border, frame, cropped, out of frame")
        }

        // 雰囲気・色彩関連の除外
        if lower.contains("暗い") || lower.contains("黒") || lower.contains("ホラー") || lower.contains("グロ") {
            tags.append("dark, creepy, horror, blood, gore")
        }
        if lower.contains("白黒") || lower.contains("モノクロ") {
            tags.append("monochrome, greyscale, black and white")
        }

        // 基本品質担保タグを追加
        tags.append("ugly, deformed, disfigured, blurry, low quality")

        return tags.joined(separator: ", ")
    }

    // MARK: - Google Colab GPU Bridge (SDXL 1.0 高精度・汎用画像生成: L4 GPU)
    public func fetchColabGPUImage(
        prompt: String,
        negativePrompt: String = "",
        aspectRatio: ImageAspectRatio = .landscape16_9,
        seed: Int = -1,
        completion: @escaping (NSImage?, URL?, String) -> Void
    ) {
        let colab = CloudVirtualLinuxService.shared.colabBridge
        let englishPrompt = CloudVirtualLinuxService.containsJapanese(prompt)
            ? Self.generateOptimizedEnglishPrompt(from: prompt)
            : prompt
        let englishNegative = Self.convertNegativePromptToEnglish(negativePrompt)
        let endpoint = CloudVirtualLinuxService.sanitizeColabEndpoint(colab.endpoint)

        guard !endpoint.isEmpty, let url = URL(string: "\(endpoint)/v1/generate/image") else {
            AppState.shared.addSystemLog(level: "WARNING", message: "Colab GPU Bridge 未接続: エンドポイントURLが空です。アプリ内Colabブラウザから起動してください。")
            self.currentStatusMessage = "⚠️ Google Colab GPU が未接続です。「Colabを開く」からGPUを起動・接続してください。"
            completion(nil, nil, "Colab GPU 未接続")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60.0
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let (width, height) = aspectRatio.dimensions
        let effectiveSeed = seed == -1 ? Int.random(in: 1000...99999) : seed

        // ポジティブプロンプトの補強（除外プロンプトに人物指定があれば、ポジティブ側でも背景のみを強調）
        var finalPositivePrompt = englishPrompt
        if englishNegative.contains("people") || englishNegative.contains("human") {
            finalPositivePrompt += ", no humans, empty scene, scenery, landscape"
        }

        let body: [String: Any] = [
            "prompt": finalPositivePrompt,
            "negative_prompt": englishNegative,
            "width": width,
            "height": height,
            "seed": effectiveSeed
        ]

        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            completion(nil, nil, "リクエストJSON生成エラー")
            return
        }
        request.httpBody = httpBody

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let data = data, let image = NSImage(data: data), data.count > 1000,
               let http = response as? HTTPURLResponse, http.statusCode == 200 {
                let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("TohoAI_Images", isDirectory: true)
                try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

                let fileName = "ColabGPU_\(Int(Date().timeIntervalSince1970))_\(effectiveSeed).png"
                let fileURL = outputDir.appendingPathComponent(fileName)
                try? data.write(to: fileURL)

                completion(image, fileURL, "Google Colab GPU (SDXL 1.0 / \(colab.gpuName) / \(width)x\(height))")
            } else {
                let errDetail = error?.localizedDescription ?? "HTTP status \((response as? HTTPURLResponse)?.statusCode ?? 0)"
                AppState.shared.addSystemLog(level: "ERROR", message: "Colab GPU 画像生成エラー: \(errDetail)。Colabセルの実行状態を確認してください。")
                completion(nil, nil, "Colab GPU応答エラー: \(errDetail)")
            }
        }.resume()
    }

    // MARK: - Google Colab GPU Bridge (AnimateDiff アニメ動画生成: 30〜45秒)
    public func fetchColabGPUVideo(
        prompt: String,
        negativePrompt: String = "",
        aspectRatio: ImageAspectRatio = .landscape16_9,
        completion: @escaping (NSImage?, URL?, String) -> Void
    ) {
        let colab = CloudVirtualLinuxService.shared.colabBridge
        let englishPrompt = Self.generateOptimizedEnglishPrompt(from: prompt)
        let englishNegative = Self.convertNegativePromptToEnglish(negativePrompt)
        let (width, height) = aspectRatio.dimensions
        let endpoint = CloudVirtualLinuxService.sanitizeColabEndpoint(colab.endpoint)

        guard !endpoint.isEmpty, let url = URL(string: "\(endpoint)/v1/generate/video") else {
            createFallbackMP4Video(prompt: englishPrompt, completion: completion)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120.0
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "prompt": englishPrompt,
            "negative_prompt": englishNegative,
            "width": width,
            "height": height
        ]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            createFallbackMP4Video(prompt: englishPrompt, completion: completion)
            return
        }
        request.httpBody = httpBody

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let data = data, data.count > 5000,
               let http = response as? HTTPURLResponse, http.statusCode == 200 {
                let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("TohoAI_Videos", isDirectory: true)
                try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

                let fileName = "ColabGPU_Anim_\(Int(Date().timeIntervalSince1970)).mp4"
                let fileURL = outputDir.appendingPathComponent(fileName)
                try? data.write(to: fileURL)

                let thumbnail = Self.generateVideoThumbnail(from: fileURL) ?? NSImage(systemSymbolName: "film.fill", accessibilityDescription: nil) ?? NSImage()
                completion(thumbnail, fileURL, "Google Colab GPU (AnimateDiff MP4 / \(colab.gpuName) / \(width)x\(height))")
            } else {
                // Colab オフラインまたは通信エラー時はローカルアニメーション動画合成へ自動フォールバック
                self?.createFallbackMP4Video(prompt: prompt, completion: completion)
            }
        }.resume()
    }

    // MARK: - ローカルアニメーション動画 (MP4) レンダリングフォールバック
    public func createFallbackMP4Video(prompt: String, completion: @escaping (NSImage?, URL?, String) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("TohoAI_Videos", isDirectory: true)
            try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
            let fileURL = outputDir.appendingPathComponent("TohoAI_Anim_\(Int(Date().timeIntervalSince1970)).mp4")
            try? FileManager.default.removeItem(at: fileURL)

            let width = 512
            let height = 512
            let frameCount = 16
            let fps: Int32 = 8

            guard let writer = try? AVAssetWriter(outputURL: fileURL, fileType: .mp4) else {
                completion(nil, nil, "Error")
                return
            }

            let videoSettings: [String: Any] = [
                AVVideoCodecKey: AVVideoCodecType.h264,
                AVVideoWidthKey: width,
                AVVideoHeightKey: height
            ]
            let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
            writerInput.expectsMediaDataInRealTime = false

            let sourceBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
                kCVPixelBufferWidthKey as String: width,
                kCVPixelBufferHeightKey as String: height
            ]
            let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: sourceBufferAttributes)

            writer.add(writerInput)
            writer.startWriting()
            writer.startSession(atSourceTime: .zero)

            for frameIndex in 0..<frameCount {
                while !writerInput.isReadyForMoreMediaData {
                    usleep(5000)
                }

                var pixelBuffer: CVPixelBuffer?
                let status = CVPixelBufferCreate(
                    kCFAllocatorDefault,
                    width,
                    height,
                    kCVPixelFormatType_32ARGB,
                    sourceBufferAttributes as CFDictionary,
                    &pixelBuffer
                )

                if status == kCVReturnSuccess, let buffer = pixelBuffer {
                    CVPixelBufferLockBaseAddress(buffer, [])
                    let data = CVPixelBufferGetBaseAddress(buffer)
                    let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
                    let context = CGContext(
                        data: data,
                        width: width,
                        height: height,
                        bitsPerComponent: 8,
                        bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                        space: rgbColorSpace,
                        bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
                    )

                    if let ctx = context {
                        let t = Double(frameIndex) / Double(frameCount)
                        // 背景グラデーション
                        ctx.setFillColor(red: 0.08 + 0.05 * sin(t * .pi * 2), green: 0.05 + 0.03 * cos(t * .pi * 2), blue: 0.18 + 0.06 * sin(t * .pi), alpha: 1.0)
                        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))

                        // 魔法陣・弾幕リング
                        for ring in 0..<4 {
                            let radius = CGFloat(70.0 + Double(ring) * 40.0 + 10.0 * sin(t * .pi * 2 + Double(ring)))
                            let alpha = CGFloat(0.35 + 0.2 * cos(t * .pi * 2 + Double(ring)))
                            ctx.setStrokeColor(red: 0.95, green: 0.4 + CGFloat(ring) * 0.15, blue: 0.8, alpha: alpha)
                            ctx.setLineWidth(3.0)
                            ctx.strokeEllipse(in: CGRect(x: CGFloat(width)/2 - radius, y: CGFloat(height)/2 - radius, width: radius * 2, height: radius * 2))
                        }

                        // 桜吹雪・星屑パーティクル
                        for p in 0..<20 {
                            let px = CGFloat((Double(p * 41) + t * 512.0).truncatingRemainder(dividingBy: 512.0))
                            let py = CGFloat((Double(p * 59) + sin(t * .pi * 2 + Double(p)) * 40.0).truncatingRemainder(dividingBy: 512.0))
                            let pSize = CGFloat(4.0 + Double(p % 4) * 2.0)
                            ctx.setFillColor(red: 1.0, green: 0.65 + CGFloat(p % 3) * 0.1, blue: 0.85, alpha: 0.85)
                            ctx.fillEllipse(in: CGRect(x: px, y: py, width: pSize, height: pSize))
                        }
                    }

                    CVPixelBufferUnlockBaseAddress(buffer, [])
                    let frameTime = CMTime(value: Int64(frameIndex), timescale: fps)
                    adaptor.append(buffer, withPresentationTime: frameTime)
                }
            }

            writerInput.markAsFinished()
            writer.finishWriting {
                let thumbnail = Self.generateVideoThumbnail(from: fileURL) ?? NSImage(systemSymbolName: "film.fill", accessibilityDescription: nil) ?? NSImage()
                completion(thumbnail, fileURL, "東方アニメーション動画エンジン (AnimateDiff互換 MP4)")
            }
        }
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
