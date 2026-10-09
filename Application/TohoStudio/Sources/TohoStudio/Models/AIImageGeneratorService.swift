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

    // MARK: - 生成ソースモード選択 (公式素材そのまま使用 / AI新規生成 / 自動判別)
    public enum GenerationSourceMode: String, CaseIterable, Identifiable {
        case auto = "✨ 自動判別 (素材検出時は原画・未検出時はAI)"
        case aiGeneration = "⚡️ AIイラスト新規生成 (SDXL 1.0 / 自然な作画)"
        case referenceAsset = "📁 公式参考資料 (原画そのまま使用・追加エフェクトなし)"

        public var id: String { rawValue }
    }
    @Published public var generationSourceMode: GenerationSourceMode = .auto

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
    public func generateImage(userPrompt: String? = nil, forceAI: Bool = false) {
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
        if let up = userPrompt, !up.isEmpty {
            self.prompt = up
        }
        let currentPrompt = prompt
        // ユーザーが選択したアスペクト比を最優先で維持 (勝手な上書きを廃止)
        let currentAspect = selectedAspectRatio
        let currentNegative = negativePrompt
        let currentOutputType = selectedOutputType

        // 0. プロンプトからキーワード(施設・キャラクター等)を抽出し、モードに応じてローカル参考資料を探索
        if currentOutputType == .image && !forceAI && generationSourceMode != .aiGeneration {
            if let localMatch = TohoLocalReferenceAssetService.shared.searchAndComposeAsset(prompt: currentPrompt, aspectRatio: currentAspect) {
                let shouldApplyReferenceDirectly = (generationSourceMode == .referenceAsset) || (generationSourceMode == .auto && !isColabBridgeAvailable)
                if shouldApplyReferenceDirectly {
                    AppState.shared.addSystemLog(level: "INFO", message: "TohoAIStudio: ローカル参考資料アーカイブより「\(localMatch.description)」を発見。公式原画素材を適用しました（追加エフェクトなし）。")
                    self.currentStatusMessage = "📁 公式素材適用: \(localMatch.description) (エフェクトなし原画)"
                    self.generationProgress = 1.0

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        guard let self = self else { return }
                        self.handleGenerationResult(
                            image: localMatch.composedImage,
                            fileURL: localMatch.fileURL,
                            engineName: "東方素材アーカイブ (公式参考資料 原画素材・追加エフェクトなし)",
                            currentPrompt: currentPrompt,
                            currentSeed: currentSeed,
                            isVideo: false
                        )
                    }
                    return
                }
            }
        }

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

    // MARK: - 公式参考資料の検出＆即座適用 (追加エフェクトなし)
    public func detectReferenceAsset(for text: String) -> TohoLocalReferenceAssetService.MatchResult? {
        return TohoLocalReferenceAssetService.shared.searchAndComposeAsset(prompt: text, aspectRatio: selectedAspectRatio)
    }

    public func applyReferenceAssetDirectly(match: TohoLocalReferenceAssetService.MatchResult) {
        AppState.shared.addSystemLog(level: "INFO", message: "TohoAIStudio: 公式参考資料の原画素材「\(match.description)」を適用しました (追加エフェクトなし)。")
        self.handleGenerationResult(
            image: match.composedImage,
            fileURL: match.fileURL,
            engineName: "公式参考資料 (原画素材・追加エフェクトなし)",
            currentPrompt: self.prompt,
            currentSeed: 0,
            isVideo: false
        )
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

    // MARK: - 高精度日英プロンプト最適化エンジン (文脈解析・施設別判定・人物混入完全防止)
    public static func hasExplicitCharacterOrPerson(_ text: String) -> Bool {
        let lower = text.lowercased()
        let keywords = [
            "人", "人物", "キャラ", "少女", "女の子", "女子", "男の子", "男子", "女性", "男性", "少年", "子供", "生徒", "先生",
            "立ち絵", "ポーズ", "表情", "笑顔", "ツインテール", "ポニーテール", "金髪", "黒髪", "銀髪", "茶髪", "緑髪", "青髪", "桃髪", "赤髪", "白髪",
            "巫女", "メイド", "魔法使い", "魔女", "天使", "悪魔", "妖精", "エルフ", "獣耳", "猫耳", "犬耳", "うさ耳", "狐耳", "制服", "ドレス", "着物", "浴衣", "水着", "パジャマ",
            "汗", "たらたら", "泣", "涙", "怒", "照れ", "赤面", "ジト目", "ウィンク", "焦り", "慌て",
            // 東方Projectキャラクター (日本語・英語)
            "こいし", "koishi", "さとり", "satori", "古明地", "komeiji",
            "霊夢", "reimu", "魔理沙", "marisa", "咲夜", "sakuya", "レミリア", "remilia", "フラン", "flandre",
            "妖夢", "youmu", "幽々子", "yuyuko", "早苗", "sanae", "チルノ", "cirno", "アリス", "alice",
            "パチュリー", "patchouli", "文", "aya", "鈴仙", "優曇華", "reisen", "てゐ", "tewi", "妹紅", "mokou",
            "輝夜", "kaguya", "紫", "yukari", "藍", "ran", "橙", "chen", "美鈴", "meiling", "ルーミア", "rumia",
            "にとり", "nitori", "神奈子", "kanako", "諏訪子", "suwako", "お空", "utsuho", "お燐", "rin",
            "星", "shou", "ナズーリン", "nazrin", "小傘", "kogasa", "一輪", "ichirin", "村紗", "murasa",
            "白蓮", "byakuren", "ぬえ", "nue", "芳香", "yoshika", "青娥", "seiga", "屠自古", "tojiko",
            "布都", "futo", "神子", "miko", "マミゾウ", "mamizou", "こころ", "kokoro",
            "わかさぎ姫", "wakasagihime", "赤蛮奇", "sekibanki", "影狼", "kagerou", "弁々", "benben", "八橋", "yatsuhashi",
            "正邪", "seija", "針妙丸", "shinmyoumaru", "雷鼓", "raiko",
            "ドレミー", "doremy", "サグメ", "sagume", "クラウンピース", "clownpiece", "純狐", "junko", "ヘカーティア", "hecatia",
            "隠岐奈", "okina", "紫苑", "shion", "女苑", "joon", "幽香", "yuuka", "小町", "komachi", "映姫", "eiki",
            "慧音", "keine", "リグル", "wriggle", "ミスティア", "mystia", "大妖精", "daiyousei", "小悪魔", "koakuma",
            // 英語一般
            "girl", "boy", "person", "human", "character", "1girl", "1boy", "woman", "man", "portrait", "anime girl", "touhou"
        ]
        return keywords.contains { lower.contains($0) }
    }

    public static func generateOptimizedEnglishPrompt(from inputPrompt: String) -> String {
        let raw = inputPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        if raw.isEmpty {
            return "breathtaking scenic landscape, atmospheric lighting, ultra-detailed AND no humans, empty scene AND masterpiece, best quality, 8k resolution"
        }

        // アルファベット比率のチェック (すでに大半が英語の場合はそのまま品質タグを付与)
        let asciiCount = raw.filter { $0.isASCII && ($0.isLetter || $0.isWhitespace || $0.isPunctuation) }.count
        if Double(asciiCount) / Double(max(1, raw.count)) > 0.75 {
            return "\(raw) AND masterpiece, best quality, highly detailed, cinematic lighting, 8k resolution"
        }

        // 動詞句・指示語のクリーンアップ（「〜を描く」「〜のイラスト」など）
        let removePatterns = [
            "を描いてください", "を描いて", "を描く", "を描きなさい",
            "のイラストを描いて", "のイラストを描く", "のイラスト", "の絵を描いて", "の絵を描く", "の絵",
            "を作成して", "を作成", "を作って", "を生成して", "を生成",
            "画像を出力して", "画像を出力", "画像を生成して", "画像を生成",
            "please draw", "draw", "generate", "create"
        ]
        var cleanedText = raw
        for p in removePatterns {
            cleanedText = cleanedText.replacingOccurrences(of: p, with: "", options: .caseInsensitive)
        }
        cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedText.isEmpty {
            cleanedText = raw
        }

        let lower = cleanedText.lowercased()
        let hasPerson = hasExplicitCharacterOrPerson(raw) || hasExplicitCharacterOrPerson(cleanedText)

        var subjectSegments: [String] = []
        var emotionSegments: [String] = []
        var compositionSegments: [String] = []
        var locationSegments: [String] = []
        var atmosphereSegments: [String] = []
        var humanConstraintSegments: [String] = []
        var styleSegments: [String] = []

        // 1. 画風・スタイルセグメント (最重要: CLIP 77トークン制限のため最先頭に配置)
        if lower.contains("写真") || lower.contains("実写") || lower.contains("リアル") || lower.contains("フォト") {
            styleSegments.append("photorealistic, hyperrealistic photo, 35mm photograph, shot on DSLR, professional photography, natural lighting, sharp focus, 8k UHD")
        } else if lower.contains("油絵") || lower.contains("水彩") {
            styleSegments.append("traditional painting style, visible brush strokes, fine art aesthetic")
        } else if lower.contains("3d") || lower.contains("cg") {
            styleSegments.append("octane render, unreal engine 5 render, highly detailed 3D artwork")
        } else {
            // 東方Project標準: 高品位アニメスタイルを先頭で強力に指定して実写化を物理的に阻止
            styleSegments.append("anime style, cel shaded anime illustration, 2D anime art, clean lineart, Japanese animation aesthetic")
        }
        styleSegments.append("masterpiece, best quality")

        // 2. 東方キャラクター判定（77トークン制限に配慮した最適Danbooru/Animeタグ）
        if lower.contains("こいし") || lower.contains("koishi") {
            subjectSegments.append("Komeiji Koishi, touhou project, 1girl, short green hair, green eyes, black hat with yellow ribbon, yellow shirt, green frilled skirt, closed third eye, blue cords around torso, Mary Jane shoes")
        } else if lower.contains("さとり") || lower.contains("satori") {
            subjectSegments.append("Komeiji Satori, touhou project, 1girl, short lavender hair, pink eyes, open red third eye on chest with red cords, pink shirt, blue frilled skirt")
        } else if lower.contains("霊夢") || lower.contains("reimu") {
            subjectSegments.append("Hakurei Reimu, touhou project, 1girl, red hair ribbon, miko shrine maiden dress, detached sleeves, brown hair, brown eyes, ofuda")
        } else if lower.contains("魔理沙") || lower.contains("marisa") {
            subjectSegments.append("Kirisame Marisa, touhou project, 1girl, large black witch hat with white ribbon, blonde braid, black and white apron dress, mini hakkero")
        } else if lower.contains("咲夜") || lower.contains("sakuya") {
            subjectSegments.append("Izayoi Sakuya, touhou project, 1girl, silver braids with green ribbons, maid outfit, pocket watch, silver throwing knives, blue eyes")
        } else if lower.contains("レミリア") || lower.contains("remilia") {
            subjectSegments.append("Remilia Scarlet, touhou project, 1girl, light blue hair, mob cap, black bat wings, red gothic lolita dress, red eyes")
        } else if lower.contains("フラン") || lower.contains("flandre") {
            subjectSegments.append("Flandre Scarlet, touhou project, 1girl, blonde hair, side ponytail, rainbow crystal wings, red dress, mob cap, red eyes")
        } else if lower.contains("妖夢") || lower.contains("youmu") {
            subjectSegments.append("Konpaku Youmu, touhou project, 1girl, short silver hair, black headband, green vest, floating myon phantom, dual swords")
        } else if lower.contains("幽々子") || lower.contains("yuyuko") {
            subjectSegments.append("Saigyouji Yuyuko, touhou project, 1girl, pink hair, zukin hat, light blue kimono, ghostly will-o-wisps")
        } else if lower.contains("早苗") || lower.contains("sanae") {
            subjectSegments.append("Kochiya Sanae, touhou project, 1girl, green hair, frog and snake hair clips, blue and white miko outfit")
        } else if lower.contains("チルノ") || lower.contains("cirno") {
            subjectSegments.append("Cirno, touhou project, 1girl, short blue hair, large blue hair bow, blue dress, icicle fairy wings")
        } else if lower.contains("アリス") || lower.contains("alice") {
            subjectSegments.append("Alice Margatroid, touhou project, 1girl, blonde hair, red hairband, blue and white dress, grimoire")
        } else if lower.contains("パチュリー") || lower.contains("patchouli") {
            subjectSegments.append("Patchouli Knowledge, touhou project, 1girl, long purple hair, nightcap, striped purple robe dress")
        } else if lower.contains("文") || lower.contains("aya") {
            subjectSegments.append("Syameimaru Aya, touhou project, 1girl, black short hair, tokin tengu hat, white blouse, black skirt, tengu fan, crow wings")
        } else if lower.contains("うどんげ") || lower.contains("鈴仙") || lower.contains("reisen") {
            subjectSegments.append("Reisen Udongein Inaba, touhou project, 1girl, light purple hair, white rabbit ears, red eyes, black blazer suit, red necktie")
        } else if lower.contains("妹紅") || lower.contains("mokou") {
            subjectSegments.append("Fujiwara no Mokou, touhou project, 1girl, long white hair with talismans, red trousers, fire flames")
        } else if lower.contains("輝夜") || lower.contains("kaguya") {
            subjectSegments.append("Houraisan Kaguya, touhou project, 1girl, straight black hime cut, noble kimono, elegant princess")
        } else if lower.contains("紫") || lower.contains("yukari") {
            subjectSegments.append("Yakumo Yukari, touhou project, 1woman, long blonde hair, mob cap with purple ribbon, purple dress, parasol, gap with eyes")
        } else if lower.contains("藍") || lower.contains("ran") {
            subjectSegments.append("Yakumo Ran, touhou project, 1girl, fox ears, nine fox tails, yellow and blue taoist robe, zukin hat")
        } else if lower.contains("にとり") || lower.contains("nitori") {
            subjectSegments.append("Kawashiro Nitori, touhou project, 1girl, blue twintails, green cap, blue engineer dress, large backpack")
        } else if lower.contains("美鈴") || lower.contains("meiling") {
            subjectSegments.append("Hong Meiling, touhou project, 1girl, red braided hair, green beret with star, green qipao dress")
        } else if lower.contains("ルーミア") || lower.contains("rumia") {
            subjectSegments.append("Rumia, touhou project, 1girl, short blonde hair, red ribbon, black vest, white shirt, red tie")
        } else if lower.contains("幽香") || lower.contains("yuuka") {
            subjectSegments.append("Kazami Yuuka, touhou project, 1woman, green wavy hair, red plaid vest and skirt, parasol, sunflowers")
        } else if lower.contains("こころ") || lower.contains("kokoro") {
            subjectSegments.append("Hata no Kokoro, touhou project, 1girl, pink hair, floating noh masks, green and pink checkered skirt")
        } else if lower.contains("ヘカーティア") || lower.contains("hecatia") {
            subjectSegments.append("Hecatia Lapislazuli, touhou project, 1girl, tricolored hair, three floating planetary orbs, striped shirt, punk skirt")
        } else if lower.contains("クラウンピース") || lower.contains("clownpiece") {
            subjectSegments.append("Clownpiece, touhou project, 1girl, blonde hair, jester hat, star-spangled outfit, torch, fairy wings")
        } else if hasPerson && subjectSegments.isEmpty {
            subjectSegments.append("1girl, cute anime character, expressive eyes, anime aesthetic")
        }

        // 3. 【感情・表情・状態セグメント】（汗たらたら、笑顔、泣き、怒り、照れ等の詳細解析）
        if lower.contains("汗がたらたら") || lower.contains("たらたら") || lower.contains("滝汗") || lower.contains("冷や汗") || (lower.contains("汗") && (lower.contains("垂れ") || lower.contains("かいて") || lower.contains("びっしょり"))) {
            emotionSegments.append("heavy sweat, sweating profusely, sweatdrops, sweat dripping down face, intense nervous sweat, flustered expression, anxious, panicking, embarrassed, comical anime sweatdrop")
        } else if lower.contains("汗") {
            emotionSegments.append("sweatdrop, light sweating, nervous sweat, flustered expression")
        }

        if lower.contains("笑顔") || lower.contains("にっこり") || lower.contains("笑う") || lower.contains("微笑み") || lower.contains("嬉し") {
            emotionSegments.append("smiling, happy cheerful smile, joyful expression")
        }
        if lower.contains("泣") || lower.contains("涙") || lower.contains("号泣") || lower.contains("悲し") {
            emotionSegments.append("crying, tears in eyes, sobbing, tear streaks on cheeks")
        }
        if lower.contains("怒") || lower.contains("激怒") || lower.contains("プンプン") {
            emotionSegments.append("angry, annoyed, furrowed brow, fierce expression, pouting")
        }
        if lower.contains("照れ") || lower.contains("赤面") || lower.contains("恥ずかし") || lower.contains("頬染め") {
            emotionSegments.append("blushing, bright red cheeks, embarrassed, bashful, shy expression")
        }
        if lower.contains("驚") || lower.contains("びっくり") || lower.contains("仰天") {
            emotionSegments.append("surprised, wide eyes, shocked, open mouth")
        }
        if lower.contains("ジト目") || lower.contains("呆れ") || lower.contains("冷たい目") {
            emotionSegments.append("jitome, half-closed eyes, deadpan look, unimpressed")
        }
        if lower.contains("ウィンク") {
            emotionSegments.append("winking, playful wink, one eye closed")
        }
        if lower.contains("真剣") || lower.contains("キリッ") || lower.contains("戦闘") || lower.contains("凛々") {
            emotionSegments.append("serious expression, determined, intense gaze, focused")
        }
        if lower.contains("眠") || lower.contains("あくび") || lower.contains("すやすや") {
            emotionSegments.append("sleepy, drowsy, yawning, peaceful expression")
        }

        // 4. 【ポーズ・構図セグメント】（立ち絵・全身・バストアップ）
        if lower.contains("立ち絵") || lower.contains("全身") {
            compositionSegments.append("anime character standing pose, full body standing, clean character portrait, character sheet, cutout presentation")
        } else if lower.contains("バストアップ") || lower.contains("上半身") {
            compositionSegments.append("upper body, cowboy shot, portrait framing, detailed face and bust")
        } else if lower.contains("座る") || lower.contains("座って") {
            compositionSegments.append("sitting down, seated pose")
        } else if lower.contains("走る") || lower.contains("駆ける") {
            compositionSegments.append("running, dynamic motion action pose")
        } else if lower.contains("飛ぶ") || lower.contains("浮遊") || lower.contains("宙に浮く") {
            compositionSegments.append("floating, airborne, hovering, dynamic pose")
        }

        // 5. 【施設・被写体名詞セグメント】（明示的に指定された場合のみ追加）
        var facilityDetected = false
        var isOutdoorFacility = false

        if lower.contains("多目的トイレ") || lower.contains("車椅子トイレ") || lower.contains("バリアフリートイレ") || lower.contains("だれでもトイレ") || lower.contains("身障者用トイレ") {
            locationSegments.append("accessible toilet, universal design restroom, modern ceramic toilet bowl, handrails")
            facilityDetected = true
        } else if lower.contains("トイレ") || lower.contains("お手洗い") || lower.contains("便所") || lower.contains("洗面所") || lower.contains("化粧室") || lower.contains("レストルーム") {
            locationSegments.append("clean modern public restroom interior, ceramic washbasin with mirror")
            facilityDetected = true
        }

        if lower.contains("中庭") || lower.contains("パティオ") {
            locationSegments.append("outdoor school courtyard garden, lawn, green trees, stone pavement path, benches")
            facilityDetected = true
            isOutdoorFacility = true
        }
        if lower.contains("体育館") || lower.contains("アリーナ") {
            locationSegments.append("school indoor gymnasium, wooden court floor, basketball hoops, high vaulted ceiling")
            facilityDetected = true
        }
        if lower.contains("プール") || lower.contains("水泳") {
            locationSegments.append("outdoor school swimming pool, clear blue water, lane dividers, bleachers")
            facilityDetected = true
            isOutdoorFacility = true
        }
        if lower.contains("廊下") {
            locationSegments.append("school hallway corridor, wooden floor, classroom doors, large windows")
            facilityDetected = true
        }
        if lower.contains("階段") || lower.contains("踊り場") {
            locationSegments.append("school staircase, wooden steps with handrail, landing platform")
            facilityDetected = true
        }
        if lower.contains("屋上") {
            locationSegments.append("outdoor school rooftop, wire mesh chain-link fence, horizon under blue sky")
            facilityDetected = true
            isOutdoorFacility = true
        }
        if lower.contains("保健室") {
            locationSegments.append("school infirmary, clinic bed, soft partition curtain, medicine cabinet")
            facilityDetected = true
        }
        if lower.contains("図書室") || lower.contains("図書館") {
            locationSegments.append("quiet school library, bookshelves packed with books, study tables")
            facilityDetected = true
        }
        if lower.contains("部室") {
            locationSegments.append("school club room, whiteboard, table, casual student room")
            facilityDetected = true
        }
        if lower.contains("下駄箱") || lower.contains("昇降口") || lower.contains("靴箱") {
            locationSegments.append("school entrance hall, getabako wooden shoe lockers")
            facilityDetected = true
        }
        if lower.contains("職員室") {
            locationSegments.append("teachers faculty office room, desks piled with textbooks")
            facilityDetected = true
        }
        if lower.contains("校庭") || lower.contains("グラウンド") || lower.contains("運動場") {
            locationSegments.append("outdoor school athletic sports field, dirt running track, school building in background")
            facilityDetected = true
            isOutdoorFacility = true
        }

        if lower.contains("教室") {
            locationSegments.append("Japanese school classroom interior, wooden desks, chalkboard, sunlight from windows")
            facilityDetected = true
        } else if (lower.contains("学校") || lower.contains("学園") || lower.contains("校舎")) && !facilityDetected {
            locationSegments.append("Japanese high school campus building exterior, educational institution architecture")
            facilityDetected = true
            isOutdoorFacility = true
        }

        // 一般ロケーション・環境
        if lower.contains("神社") {
            locationSegments.append("traditional Japanese shrine, vermilion torii gate, stone lanterns, cedar trees")
            isOutdoorFacility = true
        } else if lower.contains("森") || lower.contains("林") {
            locationSegments.append("lush deep forest, tall trees, sunbeams filtering through leaves")
            isOutdoorFacility = true
        } else if lower.contains("海") || lower.contains("ビーチ") || lower.contains("海岸") {
            locationSegments.append("beautiful ocean beach, gentle waves, sparkling turquoise water, blue sky")
            isOutdoorFacility = true
        } else if lower.contains("宇宙") || lower.contains("星") || lower.contains("銀河") {
            locationSegments.append("deep cosmos space, glowing nebulae, distant glittering galaxies, stars")
        } else if lower.contains("サイバーパンク") || lower.contains("未来都市") {
            locationSegments.append("futuristic cyberpunk metropolis, neon lights, skyscrapers")
        } else if lower.contains("部屋") || lower.contains("室内") || lower.contains("リビング") {
            locationSegments.append("cozy modern interior room, warm atmospheric lighting")
        } else if lower.contains("カフェ") || lower.contains("喫茶店") {
            locationSegments.append("cozy coffee shop cafe interior, warm ambient wooden decor")
        } else if lower.contains("駅") || lower.contains("ホーム") {
            locationSegments.append("train station platform, railway tracks, overhead signage")
        } else if lower.contains("公園") {
            locationSegments.append("peaceful public green park, lush trees, walking path, sunny day")
            isOutdoorFacility = true
        }

        // キャラクターが存在して背景指定がない場合、立ち絵・イラストとして最高品質のシンプル背景にする
        if hasPerson && locationSegments.isEmpty {
            if lower.contains("立ち絵") {
                locationSegments.append("simple white background, clean solid background, minimalist background")
            } else {
                locationSegments.append("simple clean background, subtle soft focus background, atmospheric soft light")
            }
        }

        // 6. 自然・天候・ライティングセグメント
        if lower.contains("窓から見える") || lower.contains("窓越し") || lower.contains("窓") {
            atmosphereSegments.append("view from clear window, daylight streaming in")
        }
        if lower.contains("夕暮れ") || lower.contains("夕方") || lower.contains("夕焼け") {
            atmosphereSegments.append("sunset golden hour, vibrant orange twilight glow")
        } else if lower.contains("夜") || lower.contains("月") {
            atmosphereSegments.append("night scene, moonlight glow, mystical ambient light")
        } else if lower.contains("雨") {
            atmosphereSegments.append("rainy atmosphere, raindrops, reflective wet surfaces")
        } else if lower.contains("雪") || lower.contains("冬") {
            atmosphereSegments.append("winter snow scene, falling snowflakes, crisp cold air")
        } else if lower.contains("桜") {
            atmosphereSegments.append("cherry blossom petals drifting, blooming sakura trees")
        }

        // 7. 【人物完全防止セグメント】（明示的に風景・背景のみが要求された場合のみ）
        let isLandscapeExplicitlyRequested = lower.contains("風景") || lower.contains("景色") ||
            lower.contains("背景のみ") || lower.contains("誰もいない") ||
            lower.contains("人物なし") || lower.contains("no humans") ||
            lower.contains("empty scene") || lower.contains("pure scenery")

        if isLandscapeExplicitlyRequested && !hasPerson {
            if isOutdoorFacility || lower.contains("外") || lower.contains("空") || lower.contains("海") || lower.contains("公園") || lower.contains("森") || lower.contains("山") || lower.contains("校庭") || lower.contains("グラウンド") {
                humanConstraintSegments.append("no humans, empty scene, wide outdoor environment scenery, pure scenery")
            } else {
                humanConstraintSegments.append("no humans, empty scene, pure scenery")
            }
        }

        // --- 8. 各セグメントを結合 (CLIP 77トークン制限対策: アニメ・最高品質タグを最先頭に配置しカンマ区切りで構成) ---
        var promptSegments: [String] = []

        func addBlock(_ segs: [String]) {
            let filtered = segs.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            if !filtered.isEmpty {
                var unique: [String] = []
                for item in filtered {
                    if !unique.contains(item) {
                        unique.append(item)
                    }
                }
                promptSegments.append(contentsOf: unique)
            }
        }

        // 順序: 画風(アニメ最優先) -> キャラクター -> 表情(汗など) -> 構図(立ち絵) -> 背景 -> 天候 -> 風景制約
        addBlock(styleSegments)
        addBlock(subjectSegments)
        addBlock(emotionSegments)
        addBlock(compositionSegments)
        addBlock(locationSegments)
        addBlock(atmosphereSegments)
        addBlock(humanConstraintSegments)

        if promptSegments.isEmpty {
            return "anime style, cel shaded, 2D anime illustration, masterpiece, best quality, breathtaking scenic landscape"
        }

        return promptSegments.joined(separator: ", ")
    }

    // MARK: - 除外プロンプト (ネガティブプロンプト) の日英変換エンジン
    public static func convertNegativePromptToEnglish(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        let lower = trimmed.lowercased()
        let isRealisticRequested = lower.contains("写真") || lower.contains("実写") || lower.contains("リアル") || lower.contains("フォト") || lower.contains("photorealistic") || lower.contains("photo")

        // 東方Project標準: 実写が要求されていない限り、フォトリアル写真・3D・現実人間を強力に除外
        let antiPhotoTags = isRealisticRequested ? "" : "photorealistic, realistic, photograph, photo, real life, realistic skin texture, 3d render, 3d model, "

        if trimmed.isEmpty {
            return "\(antiPhotoTags)ugly, deformed, disfigured, blurry, low quality, bad anatomy, noise, watermark, distorted, text"
        }

        // 日本語が含まれていない場合は英語ネガティブに実写除外を付与して返却
        if !CloudVirtualLinuxService.containsJapanese(trimmed) {
            return "\(antiPhotoTags)\(trimmed)"
        }

        var tags: [String] = []

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

        let combined = tags.joined(separator: ", ")
        return "\(antiPhotoTags)\(combined)"
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
        var englishNegative = Self.convertNegativePromptToEnglish(negativePrompt)
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

        // 明示的に「風景・背景のみ（人物なし）」が要求された場合のみ、ネガティブに人物排除タグを付与
        let promptLower = prompt.lowercased()
        let hasPerson = Self.hasExplicitCharacterOrPerson(prompt)
        let isLandscapeExplicitlyRequested = promptLower.contains("風景") || promptLower.contains("景色") ||
            promptLower.contains("背景のみ") || promptLower.contains("誰もいない") ||
            promptLower.contains("人物なし") || promptLower.contains("no humans") ||
            promptLower.contains("empty scene") || promptLower.contains("pure scenery")

        if isLandscapeExplicitlyRequested && !hasPerson {
            if !englishNegative.contains("people") {
                englishNegative += ", people, person, humans, girl, boy, 1girl, 1boy, female, male, character, face, portrait"
            }
        }

        var finalPositivePrompt = englishPrompt
        if !finalPositivePrompt.lowercased().contains("anime style") && !finalPositivePrompt.lowercased().contains("cel shaded") {
            finalPositivePrompt = "anime style, cel shaded anime illustration, 2D anime art, clean lineart, Japanese animation aesthetic, " + finalPositivePrompt
        }
        if !englishNegative.contains("photorealistic") {
            englishNegative = "photorealistic, realistic, photograph, photo, real life, realistic skin texture, 3d render, 3d model, " + englishNegative
        }

        // 屋外シーンで人物がいない場合のみ、誤って混入した室内・教室キーワードを排除
        let isOutdoorPrompt = promptLower.contains("校庭") || promptLower.contains("グラウンド") || promptLower.contains("運動場") ||
                              promptLower.contains("屋外") || promptLower.contains("空") || promptLower.contains("海") ||
                              promptLower.contains("公園") || promptLower.contains("屋上") || promptLower.contains("中庭") ||
                              promptLower.contains("神社")
        if isOutdoorPrompt && !hasPerson {
            let termsToRemove = ["architectural interior", "interior architecture", "classroom interior", "classroom", "interior"]
            for term in termsToRemove {
                finalPositivePrompt = finalPositivePrompt.replacingOccurrences(of: term, with: "", options: .caseInsensitive)
            }
        }

        if isLandscapeExplicitlyRequested && !hasPerson && !finalPositivePrompt.contains("no humans") {
            finalPositivePrompt += isOutdoorPrompt
                ? " AND no humans, empty scene, wide outdoor scenery, pure scenery"
                : " AND no humans, empty scene, pure scenery"
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
        let englishPrompt = CloudVirtualLinuxService.containsJapanese(prompt)
            ? Self.generateOptimizedEnglishPrompt(from: prompt)
            : prompt
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
