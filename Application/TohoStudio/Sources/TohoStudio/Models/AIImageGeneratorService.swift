import Foundation
import SwiftUI
import AppKit
import AVFoundation

/// 本格 AI画像・動画生成サービス (事前登録された外部AI API専用モデル + 東方公式参考資料連携)
public final class AIImageGeneratorService: ObservableObject {
    public static let shared = AIImageGeneratorService()

    private var isSyncingDefaults: Bool = false

    // MARK: - 画像専用プロバイダー＆モデル選択
    @Published public var imageProvider: AIMediaProviderType = .gemini {
        didSet {
            let validIds = imageProvider.models(for: .image).map(\.id)
            if !validIds.contains(imageModelId) {
                imageModelId = imageProvider.defaultModelId(for: .image)
            }
            if !isSyncingDefaults {
                TohoAIService.shared.preferredImageProvider = imageProvider
                TohoAIService.shared.preferredImageModel = imageModelId
            }
        }
    }
    @Published public var imageModelId: String = "imagen-3.0-generate-002" {
        didSet {
            if !isSyncingDefaults {
                TohoAIService.shared.preferredImageModel = imageModelId
            }
        }
    }

    // MARK: - 動画専用プロバイダー＆モデル選択
    @Published public var videoProvider: AIMediaProviderType = .gemini {
        didSet {
            let validIds = videoProvider.models(for: .video).map(\.id)
            if !validIds.contains(videoModelId) {
                videoModelId = videoProvider.defaultModelId(for: .video)
            }
            if !isSyncingDefaults {
                TohoAIService.shared.preferredVideoProvider = videoProvider
                TohoAIService.shared.preferredVideoModel = videoModelId
            }
        }
    }
    @Published public var videoModelId: String = "veo-3.0-generate-preview" {
        didSet {
            if !isSyncingDefaults {
                TohoAIService.shared.preferredVideoModel = videoModelId
            }
        }
    }

    /// API未設定時やオフライン時に公式参考資料・内蔵プロシージャル演出動画へフォールバックするか
    @Published public var allowOfflineFallback: Bool = true

    // MARK: - メディア出力種別 (静止画イラスト / AI動画)
    public enum MediaOutputType: String, CaseIterable, Identifiable {
        case image = "高精細画像 (PNG)"
        case video = "AI動画 (MP4)"

        public var id: String { rawValue }
        public var iconName: String {
            switch self {
            case .image: return "photo"
            case .video: return "film"
            }
        }
    }
    @Published public var selectedOutputType: MediaOutputType = .image

    // MARK: - 生成ソースモード選択 (公式素材そのまま使用 / 外部AI専用モデル生成 / 自動判別)
    public enum GenerationSourceMode: String, CaseIterable, Identifiable {
        case auto = "✨ 自動判別 (外部API優先・未設定時は公式参考資料)"
        case aiGeneration = "⚡️ 外部AI専用モデルで新規生成"
        case referenceAsset = "📁 公式参考資料 (原画そのまま使用・追加エフェクトなし)"

        public var id: String { rawValue }
    }
    @Published public var generationSourceMode: GenerationSourceMode = .auto

    // MARK: - 自由入力プロンプトパラメータ (完全プロンプト駆動)
    @Published public var prompt: String = "学校の中庭が窓から見える保健室のイメージイラスト"
    @Published public var negativePrompt: String = "低解像度, 崩れた構図, ノイズ, ぼやけ, 文字化け"
    @Published public var selectedAspectRatio: ImageAspectRatio = .landscape16_9
    @Published public var seed: Int = -1

    // MARK: - 生成状態
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

    public var hasConfiguredExternalImageAPI: Bool {
        return !TohoAIService.shared.configuredMediaProviders(for: .image).isEmpty
    }

    public var hasConfiguredExternalVideoAPI: Bool {
        return !TohoAIService.shared.configuredMediaProviders(for: .video).isEmpty
    }

    public var activeEngineSummary: String {
        let tohoAI = TohoAIService.shared
        if selectedOutputType == .video {
            let resolved = tohoAI.resolveActiveMediaTarget(modality: .video, selectedProvider: videoProvider, selectedModelId: videoModelId)
            if resolved.isConfiguredExternal {
                return "\(resolved.provider.rawValue) (\(resolved.provider.displayName(forModelId: resolved.modelId, modality: .video)))"
            }
            return videoProvider == .localBuiltIn ? "内蔵プロシージャル演出動画 (MP4)" : "外部動画APIキー未設定"
        } else {
            let resolved = tohoAI.resolveActiveMediaTarget(modality: .image, selectedProvider: imageProvider, selectedModelId: imageModelId)
            if resolved.isConfiguredExternal {
                return "\(resolved.provider.rawValue) (\(resolved.provider.displayName(forModelId: resolved.modelId, modality: .image)))"
            }
            return "公式参考資料 / 外部画像APIキー未設定"
        }
    }

    private init() {
        syncFromTohoAIPreferences()
    }

    public func syncFromTohoAIPreferences() {
        let tohoAI = TohoAIService.shared
        isSyncingDefaults = true
        imageProvider = tohoAI.preferredImageProvider
        imageModelId = tohoAI.preferredImageModel
        videoProvider = tohoAI.preferredVideoProvider
        videoModelId = tohoAI.preferredVideoModel
        isSyncingDefaults = false
    }

    // MARK: - 画像・動画生成実行 (事前登録された外部AI APIの専用モデルを呼び出し)
    public func generateImage(
        userPrompt: String? = nil,
        forceAI: Bool = false,
        onComplete: ((GeneratedImageItem?) -> Void)? = nil
    ) {
        guard !isGenerating else { return }

        let targetPrompt = (userPrompt ?? prompt).trimmingCharacters(in: .whitespacesAndNewlines)
        if targetPrompt.isEmpty {
            prompt = "学校の中庭が窓から見える保健室のイメージイラスト"
        } else if let up = userPrompt, !up.isEmpty {
            self.prompt = up
        }

        let currentPrompt = prompt
        let currentAspect = selectedAspectRatio
        let currentNegative = negativePrompt
        let currentOutputType = selectedOutputType
        let currentSeed = seed == -1 ? Int.random(in: 1000...99999) : seed
        let tohoAI = TohoAIService.shared

        // 0. 画像モードで「公式参考資料」が明示選択されている場合、または内蔵アーカイブプロバイダー選択時
        if currentOutputType == .image && (generationSourceMode == .referenceAsset || imageProvider == .localBuiltIn) && !forceAI {
            if let localMatch = TohoLocalReferenceAssetService.shared.searchAndComposeAsset(prompt: currentPrompt, aspectRatio: currentAspect) {
                isGenerating = true
                generationProgress = 1.0
                currentStatusMessage = "📁 公式素材適用: \(localMatch.description)"
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                    self?.handleGenerationResult(
                        image: localMatch.composedImage,
                        fileURL: localMatch.fileURL,
                        providerLabel: AIMediaProviderType.localBuiltIn.rawValue,
                        modelLabel: "公式参考資料 (原画素材)",
                        engineName: "東方素材アーカイブ (公式参考資料 原画素材)",
                        currentPrompt: currentPrompt,
                        currentSeed: currentSeed,
                        isVideo: false,
                        onComplete: onComplete
                    )
                }
                return
            } else if imageProvider == .localBuiltIn || generationSourceMode == .referenceAsset {
                currentStatusMessage = "⚠️ 該当する公式参考資料が見つかりませんでした。外部APIプロバイダーを選択するかキーワードを調整してください。"
                onComplete?(nil)
                return
            }
        }

        isGenerating = true
        generationProgress = 0.12
        currentStatusMessage = "プロンプトを解析・最適化中..."

        if currentOutputType == .video {
            // --- 動画生成フロー ---
            if videoProvider == .localBuiltIn {
                generationProgress = 0.5
                currentStatusMessage = "内蔵プロシージャル演出動画を合成中..."
                createFallbackMP4Video(prompt: currentPrompt) { [weak self] thumb, url, engine in
                    self?.handleGenerationResult(
                        image: thumb,
                        fileURL: url,
                        providerLabel: AIMediaProviderType.localBuiltIn.rawValue,
                        modelLabel: "内蔵プロシージャルMP4",
                        engineName: engine,
                        currentPrompt: currentPrompt,
                        currentSeed: currentSeed,
                        isVideo: true,
                        onComplete: onComplete
                    )
                }
                return
            }

            let resolved = tohoAI.resolveActiveMediaTarget(modality: .video, selectedProvider: videoProvider, selectedModelId: videoModelId)
            guard resolved.isConfiguredExternal else {
                if allowOfflineFallback && !forceAI {
                    currentStatusMessage = "外部動画APIキー未登録のため、内蔵プロシージャル動画を合成中..."
                    generationProgress = 0.6
                    createFallbackMP4Video(prompt: currentPrompt) { [weak self] thumb, url, engine in
                        self?.handleGenerationResult(
                            image: thumb,
                            fileURL: url,
                            providerLabel: AIMediaProviderType.localBuiltIn.rawValue,
                            modelLabel: "内蔵プロシージャルMP4",
                            engineName: "\(engine)（外部APIキー未登録フォールバック）",
                            currentPrompt: currentPrompt,
                            currentSeed: currentSeed,
                            isVideo: true,
                            onComplete: onComplete
                        )
                    }
                } else {
                    isGenerating = false
                    generationProgress = 0.0
                    currentStatusMessage = "⚠️ 動画生成用の外部APIキー（Gemini Veo / OpenAI Sora / fal.ai / Replicate / Runway / Luma）が未登録または無効です。「外部API・Nanndemoya認証」タブで登録してください。"
                    AppState.shared.addSystemLog(level: "WARN", message: currentStatusMessage)
                    onComplete?(nil)
                }
                return
            }

            if resolved.provider != videoProvider {
                isSyncingDefaults = true
                videoProvider = resolved.provider
                videoModelId = resolved.modelId
                isSyncingDefaults = false
            }

            let apiKey = tohoAI.mediaAPIKey(for: resolved.provider)
            ExternalMediaAPIClient.shared.resolveEnglishMediaPrompt(prompt: currentPrompt, modality: .video) { [weak self] englishPrompt in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.generationProgress = 0.35
                }
                ExternalMediaAPIClient.shared.generateVideo(
                    provider: resolved.provider,
                    modelId: resolved.modelId,
                    apiKey: apiKey,
                    prompt: englishPrompt,
                    negativePrompt: currentNegative,
                    aspectRatio: currentAspect,
                    statusCallback: { [weak self] msg in
                        guard let self = self else { return }
                        self.currentStatusMessage = msg
                        self.generationProgress = min(0.92, self.generationProgress + 0.06)
                    },
                    completion: { [weak self] result in
                        switch result {
                        case .success(let (thumb, fileURL, engineLabel)):
                            self?.handleGenerationResult(
                                image: thumb,
                                fileURL: fileURL,
                                providerLabel: resolved.provider.rawValue,
                                modelLabel: resolved.modelId,
                                engineName: engineLabel,
                                currentPrompt: currentPrompt,
                                currentSeed: currentSeed,
                                isVideo: true,
                                onComplete: onComplete
                            )
                        case .failure(let err):
                            self?.handleGenerationResult(
                                image: nil,
                                fileURL: nil,
                                providerLabel: resolved.provider.rawValue,
                                modelLabel: resolved.modelId,
                                engineName: err.localizedDescription,
                                currentPrompt: currentPrompt,
                                currentSeed: currentSeed,
                                isVideo: true,
                                onComplete: onComplete
                            )
                        }
                    }
                )
            }
        } else {
            // --- 画像生成フロー ---
            let resolved = tohoAI.resolveActiveMediaTarget(modality: .image, selectedProvider: imageProvider, selectedModelId: imageModelId)
            guard resolved.isConfiguredExternal else {
                // 外部画像APIキーが1つも有効でない場合、自動モードなら公式参考資料アーカイブを探索
                if !forceAI && generationSourceMode == .auto && allowOfflineFallback,
                   let localMatch = TohoLocalReferenceAssetService.shared.searchAndComposeAsset(prompt: currentPrompt, aspectRatio: currentAspect) {
                    self.handleGenerationResult(
                        image: localMatch.composedImage,
                        fileURL: localMatch.fileURL,
                        providerLabel: AIMediaProviderType.localBuiltIn.rawValue,
                        modelLabel: "公式参考資料 (原画素材)",
                        engineName: "東方素材アーカイブ (外部API未設定フォールバック)",
                        currentPrompt: currentPrompt,
                        currentSeed: currentSeed,
                        isVideo: false,
                        onComplete: onComplete
                    )
                    return
                }
                isGenerating = false
                generationProgress = 0.0
                currentStatusMessage = "⚠️ 画像生成用の外部APIキー（Gemini / OpenAI / Stability AI / fal.ai / Replicate / Grok / Luma）が未登録または無効です。「外部API・Nanndemoya認証」タブで設定してください。"
                AppState.shared.addSystemLog(level: "WARN", message: currentStatusMessage)
                onComplete?(nil)
                return
            }

            if resolved.provider != imageProvider {
                isSyncingDefaults = true
                imageProvider = resolved.provider
                imageModelId = resolved.modelId
                isSyncingDefaults = false
            }

            let apiKey = tohoAI.mediaAPIKey(for: resolved.provider)
            ExternalMediaAPIClient.shared.resolveEnglishMediaPrompt(prompt: currentPrompt, modality: .image) { [weak self] englishPrompt in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    self.generationProgress = 0.45
                }
                ExternalMediaAPIClient.shared.generateImage(
                    provider: resolved.provider,
                    modelId: resolved.modelId,
                    apiKey: apiKey,
                    prompt: englishPrompt,
                    negativePrompt: currentNegative,
                    aspectRatio: currentAspect,
                    seed: currentSeed,
                    statusCallback: { [weak self] msg in
                        self?.currentStatusMessage = msg
                    },
                    completion: { [weak self] result in
                        switch result {
                        case .success(let (img, fileURL, engineLabel)):
                            self?.handleGenerationResult(
                                image: img,
                                fileURL: fileURL,
                                providerLabel: resolved.provider.rawValue,
                                modelLabel: resolved.modelId,
                                engineName: engineLabel,
                                currentPrompt: currentPrompt,
                                currentSeed: currentSeed,
                                isVideo: false,
                                onComplete: onComplete
                            )
                        case .failure(let err):
                            self?.handleGenerationResult(
                                image: nil,
                                fileURL: nil,
                                providerLabel: resolved.provider.rawValue,
                                modelLabel: resolved.modelId,
                                engineName: err.localizedDescription,
                                currentPrompt: currentPrompt,
                                currentSeed: currentSeed,
                                isVideo: false,
                                onComplete: onComplete
                            )
                        }
                    }
                )
            }
        }
    }

    private func handleGenerationResult(
        image: NSImage?,
        fileURL: URL?,
        providerLabel: String,
        modelLabel: String,
        engineName: String,
        currentPrompt: String,
        currentSeed: Int,
        isVideo: Bool,
        onComplete: ((GeneratedImageItem?) -> Void)? = nil
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
                    providerName: providerLabel,
                    modelName: modelLabel,
                    isVideo: isVideo
                )
                self.generatedImagesHistory.insert(item, at: 0)

                let mediaKindStr = isVideo ? "AI動画" : "AI画像"
                AppState.shared.addSystemLog(level: "INFO", message: "TohoAIStudio: [\(engineName)] から\(mediaKindStr)「\(item.title)」を生成しました。")
                onComplete?(item)
            } else {
                self.generationProgress = 0.0
                if !engineName.isEmpty && engineName != "Error" {
                    self.currentStatusMessage = "⚠️ \(engineName)"
                } else {
                    self.currentStatusMessage = "⚠️ 生成に失敗しました（外部APIキーの設定・利用枠をご確認ください）"
                }
                AppState.shared.addSystemLog(level: "ERROR", message: "AIメディア生成エラー: \(engineName)")
                onComplete?(nil)
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
            providerLabel: AIMediaProviderType.localBuiltIn.rawValue,
            modelLabel: "公式参考資料 (原画素材)",
            engineName: "公式参考資料 (原画素材・追加エフェクトなし)",
            currentPrompt: self.prompt,
            currentSeed: 0,
            isVideo: false
        )
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

    // MARK: - ローカルプロシージャル演出動画 (MP4) レンダリングフォールバック
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



    // MARK: - 制作スタジオ連携
    public func saveToMaterialStudio(item: GeneratedImageItem) {
        let mat = MaterialItem(
            title: item.title,
            type: item.isVideo ? "動画" : "画像",
            category: item.isVideo ? "AI生成動画" : "AI生成画像",
            filePath: item.fileURL.path,
            fileSize: (try? FileManager.default.attributesOfItem(atPath: item.fileURL.path)[.size] as? Int64) ?? 524288,
            createdAt: Date()
        )
        AppState.shared.materials.append(mat)
        let label = item.isVideo ? "AI生成動画" : "AI生成画像"
        AppState.shared.addHistory("\(label)「\(item.title)」を素材スタジオへ登録")
        AppState.shared.addSystemLog(level: "INFO", message: "素材スタジオに\(label)「\(item.title)」を追加しました。")
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
