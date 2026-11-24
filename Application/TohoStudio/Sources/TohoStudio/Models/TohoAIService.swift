import Foundation
import SwiftUI
import Combine

// MARK: - AI Provider Types (V3.0 全プロバイダ + NanndemoyaAPI 完全対応)
public enum AIProviderType: String, CaseIterable, Identifiable, Codable {
    case virtualLinuxVM = "定額プラン内蔵LLM (ゲートウェイ)"
    case nanndemoya = "Nanndemoya独自API (ライセンス)"
    case gemini = "Google Gemini"
    case chatGPT = "OpenAI ChatGPT"
    case claude = "Anthropic Claude"
    case grok = "xAI Grok"
    case mistral = "Mistral Large"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .virtualLinuxVM: return "server.rack"
        case .nanndemoya: return "key.radiowaves.forward.fill"
        case .gemini: return "sparkles"
        case .chatGPT: return "brain"
        case .claude: return "cpu"
        case .grok: return "bolt.horizontal.circle.fill"
        case .mistral: return "wind"
        }
    }

    public var consumesFlatRateQuota: Bool {
        return self == .virtualLinuxVM
    }

    public var defaultModel: String {
        switch self {
        case .virtualLinuxVM: return "Auto (東方最適ルーティング)"
        case .nanndemoya: return "Nanndemoya Auto (高品質マルチモデル)"
        case .gemini: return "Gemini 2.5 Flash"
        case .chatGPT: return "GPT-4o"
        case .claude: return "Claude 3.7 Sonnet"
        case .grok: return "Grok 3 Mini"
        case .mistral: return "Mistral Large"
        }
    }

    public var availableModels: [String] {
        switch self {
        case .virtualLinuxVM:
            return [
                "Auto (東方最適ルーティング)",
                "Qwen3 / Qwen 2.5 (高速対話)",
                "DeepSeek-R1 (思考モード・長編構成)"
            ]
        case .nanndemoya:
            return [
                "Nanndemoya Auto (高品質マルチモデル)",
                "Gemini 2.5 Flash (何でも屋中継)",
                "DeepSeek-R1 / V3 (何でも屋中継)",
                "GPT-4o (何でも屋中継)",
                "Claude 3.7 Sonnet (何でも屋中継)"
            ]
        case .gemini:
            return ["Gemini 2.5 Flash", "Gemini 2.5 Pro", "Gemini 2.0 Flash"]
        case .chatGPT:
            return ["GPT-4o", "GPT-4o-mini", "o3-mini"]
        case .claude:
            return ["Claude 3.7 Sonnet", "Claude 3.5 Haiku"]
        case .grok:
            return ["Grok 3", "Grok 3 Mini"]
        case .mistral:
            return ["Mistral Large", "Mistral Small"]
        }
    }
}

// MARK: - Chat Message Model
public struct AIChatMessage: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var role: String // "user", "assistant", "system"
    public var content: String
    public var thinkingContent: String? = nil
    public var provider: AIProviderType
    public var modelName: String
    public var timestamp: Date = Date()
    public var promptTokens: Int = 0
    public var completionTokens: Int = 0
}

// MARK: - Character Tone Preset
public enum CharacterTonePreset: String, CaseIterable, Identifiable {
    case reimu = "博麗霊夢 (「〜よ」「〜だわ」「異変を解決するわよ」)"
    case marisa = "霧雨魔理沙 (「〜ぜ」「〜なんだな」「弾幕は火力だぜ」)"
    case sakuya = "十六夜咲夜 (「〜ですわ」「お嬢様をお待ちかねです」)"
    case youmu = "魂魄妖夢 (「〜です」「斬れぬものなどあんまりない！」)"
    case remilia = "レミリア・スカーレット (「〜かしら」「運命を操ってあげる」)"
    case flandre = "フランドール (「〜遊んでくれるの？」「きゅっとしてドカーン！」)"
    case cirno = "チルノ (「あたいったら最強ね！」「〜だもんね！」)"
    case sanae = "東風谷早苗 (「〜です！」「常識に囚われてはいけないのですね！」)"
    case aya = "射命丸文 (「〜ですよ」「あやややや！」「文々。新聞のネタになります！」)"
    case reisen = "鈴仙・優曇華院 (「〜です」「狂気の赤眼」「師匠と姫様に怒られちゃう…」)"
    case alice = "アリス・マーガトロイド (「〜かしら」「人形劇を始めるわよ」「魔理沙ったら…」)"
    case patchouli = "パチュリー・ノーレッジ (「〜よ」「むきゅー」「喘息の発作が…」)"
    case yuyuko = "西行寺幽々子 (「〜かしら」「妖夢、お腹がすいたわ」「死への誘いよ」)"
    case standardPolite = "標準・丁寧語 (ナレーション・解説用)"

    public var id: String { rawValue }

    public var characterName: String {
        switch self {
        case .reimu: return "博麗霊夢"
        case .marisa: return "霧雨魔理沙"
        case .sakuya: return "十六夜咲夜"
        case .youmu: return "魂魄妖夢"
        case .remilia: return "レミリア"
        case .flandre: return "フランドール"
        case .cirno: return "チルノ"
        case .sanae: return "東風谷早苗"
        case .aya: return "射命丸文"
        case .reisen: return "鈴仙"
        case .alice: return "アリス"
        case .patchouli: return "パチュリー"
        case .yuyuko: return "西行寺幽々子"
        case .standardPolite: return "ナレーション"
        }
    }
}

// MARK: - AI Edit Mode
public enum AIEditMode: String, CaseIterable, Identifiable {
    case proofreadPolish = "シナリオ推敲・校正 (テンポ・文体・ルビ・尺推計)"
    case scenarioRewrite = "キャラ口調変換・セリフ演出"
    case sceneStoryboard = "シーン構成＆絵コンテ自動生成"
    case characterPrompt = "立ち絵パーツ・表情ポーズプロンプト生成"
    case gameBlocklyScript = "ゲームロジック＆スクリプト生成"

    public var id: String { rawValue }

    public var serverModeKey: String {
        switch self {
        case .proofreadPolish: return "proofreadPolish"
        case .scenarioRewrite: return "scenarioRewrite"
        case .sceneStoryboard: return "sceneStoryboard"
        case .characterPrompt: return "characterPrompt"
        case .gameBlocklyScript: return "gameBlocklyScript"
        }
    }

    public var iconName: String {
        switch self {
        case .proofreadPolish: return "doc.text.magnifyingglass"
        case .scenarioRewrite: return "text.bubble"
        case .sceneStoryboard: return "film.stack"
        case .characterPrompt: return "person.crop.artframe"
        case .gameBlocklyScript: return "puzzlepiece"
        }
    }
}

// MARK: - External API Config
public struct ExternalAPIConfig: Codable {
    public var apiKey: String = ""
    public var isEnabled: Bool = false
    public var selectedModel: String
    public var isConnected: Bool = false
    public var lastTestedAt: Date? = nil
    public var latencyMs: Int = 0
    public var billingURLString: String
}

// MARK: - TohoAIProgramTab Enum (8大統合スタジオ)
public enum TohoAIProgramTab: String, CaseIterable, Identifiable {
    case virtualLinuxVM = "ゲートウェイ通信確認"
    case aiChat = "AIチャット"
    case aiEditor = "AI編集・推敲"
    case aiImageGenerator = "AI画像生成"
    case aiSoundGenerator = "AI音楽・SE生成"
    case usageBilling = "プラン・使用量管理"
    case externalAPI = "外部API・Nanndemoya認証"
    case inAppBrowser = "専用ブラウザ (請求確認)"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .virtualLinuxVM: return "server.rack"
        case .aiChat: return "bubble.left.and.bubble.right.fill"
        case .aiEditor: return "wand.and.stars"
        case .aiImageGenerator: return "photo.artframe"
        case .aiSoundGenerator: return "music.note.list"
        case .usageBilling: return "creditcard.fill"
        case .externalAPI: return "network.badge.shield.half.filled"
        case .inAppBrowser: return "safari.fill"
        }
    }
}

// MARK: - TohoAIService Class
public final class TohoAIService: ObservableObject {
    public static let shared = TohoAIService()

    private static let nanndemoyaKeyStorage = "TohoAIStudio.NanndemoyaLicenseKey"
    private static let providerStorageKey = "TohoAIStudio.ActiveProvider"
    private static let selectedModelStorageKey = "TohoAIStudio.SelectedModel"
    private static func externalConfigStorageKey(for provider: AIProviderType) -> String {
        return "TohoAIStudio.ExternalConfig.\(provider.rawValue)"
    }
    private var isRestoringSettings: Bool = false
    private var discoveredGeminiModels: [String] = []
    private var discoveredClaudeModels: [String] = []

    // MARK: - Selected Configuration
    @Published public var activeProgramTab: TohoAIProgramTab = .aiChat
    @Published public var activeProvider: AIProviderType = .virtualLinuxVM {
        didSet {
            guard !isRestoringSettings else { return }
            UserDefaults.standard.set(activeProvider.rawValue, forKey: Self.providerStorageKey)
            let preferred = preferredModel(for: activeProvider)
            if activeProvider.availableModels.contains(preferred) {
                selectedModel = preferred
            } else if !activeProvider.availableModels.contains(selectedModel) {
                selectedModel = activeProvider.defaultModel
            }
        }
    }
    @Published public var selectedModel: String = "Auto (東方最適ルーティング)" {
        didSet {
            guard !isRestoringSettings else { return }
            UserDefaults.standard.set(selectedModel, forKey: Self.selectedModelStorageKey)
            syncSelectedModelToProviderConfig(model: selectedModel, provider: activeProvider)
        }
    }
    @Published public var temperature: Double = 0.7
    @Published public var isGenerating: Bool = false

    // MARK: - AI Chat Messages
    @Published public var chatMessages: [AIChatMessage] = []

    // MARK: - NanndemoyaAPI License Config (課金基盤なし・ライセンスキー方式)
    @Published public var nanndemoyaConfig: ExternalAPIConfig = ExternalAPIConfig(
        apiKey: "",
        isEnabled: false,
        selectedModel: "Nanndemoya Auto (高品質マルチモデル)",
        isConnected: false,
        lastTestedAt: nil,
        latencyMs: 0,
        billingURLString: "https://www.nanndemoya.net/top"
    ) {
        didSet {
            guard !isRestoringSettings else { return }
            UserDefaults.standard.set(nanndemoyaConfig.apiKey, forKey: Self.nanndemoyaKeyStorage)
            saveExternalConfig(nanndemoyaConfig, for: .nanndemoya)
            if activeProvider == .nanndemoya && selectedModel != nanndemoyaConfig.selectedModel {
                selectedModel = nanndemoyaConfig.selectedModel
            }
        }
    }
    @Published public var nanndemoyaLicenseInfo: NanndemoyaLicenseVerification? = nil
    @Published public var nanndemoyaStatusMessage: String = ""

    // MARK: - External API Settings
    @Published public var geminiConfig: ExternalAPIConfig = ExternalAPIConfig(
        apiKey: "",
        isEnabled: false,
        selectedModel: "Gemini 2.5 Flash",
        isConnected: false,
        lastTestedAt: nil,
        latencyMs: 0,
        billingURLString: "https://aistudio.google.com/"
    ) {
        didSet {
            guard !isRestoringSettings else { return }
            if oldValue.apiKey != geminiConfig.apiKey {
                discoveredGeminiModels = []
            }
            saveExternalConfig(geminiConfig, for: .gemini)
            if activeProvider == .gemini && selectedModel != geminiConfig.selectedModel {
                selectedModel = geminiConfig.selectedModel
            }
        }
    }
    @Published public var chatGPTConfig: ExternalAPIConfig = ExternalAPIConfig(
        apiKey: "",
        isEnabled: false,
        selectedModel: "GPT-4o",
        isConnected: false,
        lastTestedAt: nil,
        latencyMs: 0,
        billingURLString: "https://platform.openai.com/usage"
    ) {
        didSet {
            guard !isRestoringSettings else { return }
            saveExternalConfig(chatGPTConfig, for: .chatGPT)
            if activeProvider == .chatGPT && selectedModel != chatGPTConfig.selectedModel {
                selectedModel = chatGPTConfig.selectedModel
            }
        }
    }
    @Published public var claudeConfig: ExternalAPIConfig = ExternalAPIConfig(
        apiKey: "",
        isEnabled: false,
        selectedModel: "Claude 3.7 Sonnet",
        isConnected: false,
        lastTestedAt: nil,
        latencyMs: 0,
        billingURLString: "https://console.anthropic.com/settings/plans"
    ) {
        didSet {
            guard !isRestoringSettings else { return }
            if oldValue.apiKey != claudeConfig.apiKey {
                discoveredClaudeModels = []
            }
            saveExternalConfig(claudeConfig, for: .claude)
            if activeProvider == .claude && selectedModel != claudeConfig.selectedModel {
                selectedModel = claudeConfig.selectedModel
            }
        }
    }
    @Published public var grokConfig: ExternalAPIConfig = ExternalAPIConfig(
        apiKey: "",
        isEnabled: false,
        selectedModel: "Grok 3 Mini",
        isConnected: false,
        lastTestedAt: nil,
        latencyMs: 0,
        billingURLString: "https://console.x.ai/"
    ) {
        didSet {
            guard !isRestoringSettings else { return }
            saveExternalConfig(grokConfig, for: .grok)
            if activeProvider == .grok && selectedModel != grokConfig.selectedModel {
                selectedModel = grokConfig.selectedModel
            }
        }
    }
    @Published public var mistralConfig: ExternalAPIConfig = ExternalAPIConfig(
        apiKey: "",
        isEnabled: false,
        selectedModel: "Mistral Large",
        isConnected: false,
        lastTestedAt: nil,
        latencyMs: 0,
        billingURLString: "https://console.mistral.ai/billing/"
    ) {
        didSet {
            guard !isRestoringSettings else { return }
            saveExternalConfig(mistralConfig, for: .mistral)
            if activeProvider == .mistral && selectedModel != mistralConfig.selectedModel {
                selectedModel = mistralConfig.selectedModel
            }
        }
    }

    // MARK: - AI Editing & Proofreading Workspace State
    @Published public var selectedEditMode: AIEditMode = .proofreadPolish
    @Published public var selectedTone: CharacterTonePreset = .reimu
    @Published public var editorInputText: String = """
    霊夢「今日のご飯は何かしら？」
    魔理沙「森でキノコを採ってきたぜ！」
    霊夢「ちょっと、怪しいキノコを部屋に持ち込まないでよ」
    魔理沙「大丈夫だ、妖精にあげたら元気になったぜ」
    """
    @Published public var editorOutputText: String = ""
    @Published public var editorThinkingText: String = ""
    @Published public var isEditorProcessing: Bool = false

    @Published public var proofreadOriginalCount: Int = 0
    @Published public var proofreadPolishedCount: Int = 0
    @Published public var proofreadEstimatedDurationSec: Double = 0.0

    // MARK: - Generated Storyboard Scenes Buffer
    @Published public var generatedScenesBuffer: [MovieScene] = []

    // Billing Tracking (ユーザー自身の外部API概算モニター用)
    @Published public var externalAPICostUSD: [AIProviderType: Double] = [
        .gemini: 0.0,
        .chatGPT: 0.0,
        .claude: 0.0,
        .grok: 0.0,
        .mistral: 0.0
    ]

    private init() {
        isRestoringSettings = true
        nanndemoyaConfig = loadExternalConfig(for: .nanndemoya, fallback: nanndemoyaConfig)
        if nanndemoyaConfig.apiKey.isEmpty,
           let savedKey = UserDefaults.standard.string(forKey: Self.nanndemoyaKeyStorage),
           !savedKey.isEmpty {
            nanndemoyaConfig.apiKey = savedKey
            nanndemoyaConfig.isEnabled = true
        }
        geminiConfig = loadExternalConfig(for: .gemini, fallback: geminiConfig)
        chatGPTConfig = loadExternalConfig(for: .chatGPT, fallback: chatGPTConfig)
        claudeConfig = loadExternalConfig(for: .claude, fallback: claudeConfig)
        grokConfig = loadExternalConfig(for: .grok, fallback: grokConfig)
        mistralConfig = loadExternalConfig(for: .mistral, fallback: mistralConfig)

        if let savedProvRaw = UserDefaults.standard.string(forKey: Self.providerStorageKey),
           let savedProv = AIProviderType(rawValue: savedProvRaw) {
            activeProvider = savedProv
        }
        if let savedModel = UserDefaults.standard.string(forKey: Self.selectedModelStorageKey),
           activeProvider.availableModels.contains(savedModel) {
            selectedModel = savedModel
        } else {
            let pref = preferredModel(for: activeProvider)
            selectedModel = activeProvider.availableModels.contains(pref) ? pref : activeProvider.defaultModel
        }
        isRestoringSettings = false

        seedInitialMessages()
    }

    private func saveExternalConfig(_ config: ExternalAPIConfig, for provider: AIProviderType) {
        if let encoded = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(encoded, forKey: Self.externalConfigStorageKey(for: provider))
        }
    }

    private func loadExternalConfig(for provider: AIProviderType, fallback: ExternalAPIConfig) -> ExternalAPIConfig {
        guard let data = UserDefaults.standard.data(forKey: Self.externalConfigStorageKey(for: provider)),
              var decoded = try? JSONDecoder().decode(ExternalAPIConfig.self, from: data) else {
            return fallback
        }
        if decoded.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            decoded.isConnected = false
        }
        if !provider.availableModels.contains(decoded.selectedModel) {
            decoded.selectedModel = provider.defaultModel
        }
        return decoded
    }

    private func preferredModel(for provider: AIProviderType) -> String {
        switch provider {
        case .virtualLinuxVM: return provider.defaultModel
        case .nanndemoya: return nanndemoyaConfig.selectedModel
        case .gemini: return geminiConfig.selectedModel
        case .chatGPT: return chatGPTConfig.selectedModel
        case .claude: return claudeConfig.selectedModel
        case .grok: return grokConfig.selectedModel
        case .mistral: return mistralConfig.selectedModel
        }
    }

    private func syncSelectedModelToProviderConfig(model: String, provider: AIProviderType) {
        guard provider.availableModels.contains(model) else { return }
        switch provider {
        case .virtualLinuxVM: break
        case .nanndemoya:
            if nanndemoyaConfig.selectedModel != model { nanndemoyaConfig.selectedModel = model }
        case .gemini:
            if geminiConfig.selectedModel != model { geminiConfig.selectedModel = model }
        case .chatGPT:
            if chatGPTConfig.selectedModel != model { chatGPTConfig.selectedModel = model }
        case .claude:
            if claudeConfig.selectedModel != model { claudeConfig.selectedModel = model }
        case .grok:
            if grokConfig.selectedModel != model { grokConfig.selectedModel = model }
        case .mistral:
            if mistralConfig.selectedModel != model { mistralConfig.selectedModel = model }
        }
    }

    public func isProviderEnabled(_ provider: AIProviderType) -> Bool {
        switch provider {
        case .virtualLinuxVM: return true
        case .nanndemoya: return nanndemoyaConfig.isEnabled
        case .gemini: return geminiConfig.isEnabled
        case .chatGPT: return chatGPTConfig.isEnabled
        case .claude: return claudeConfig.isEnabled
        case .grok: return grokConfig.isEnabled
        case .mistral: return mistralConfig.isEnabled
        }
    }

    public func hasAnyExternalAPIEnabled() -> Bool {
        return (geminiConfig.isEnabled && !geminiConfig.apiKey.isEmpty) ||
               (chatGPTConfig.isEnabled && !chatGPTConfig.apiKey.isEmpty) ||
               (claudeConfig.isEnabled && !claudeConfig.apiKey.isEmpty) ||
               (grokConfig.isEnabled && !grokConfig.apiKey.isEmpty) ||
               (mistralConfig.isEnabled && !mistralConfig.apiKey.isEmpty) ||
               (nanndemoyaConfig.isEnabled && !nanndemoyaConfig.apiKey.isEmpty)
    }

    private func seedInitialMessages() {
        chatMessages = [
            AIChatMessage(
                role: "system",
                content: "TohoAIStudio V3.0 へようこそ。定額プラン内蔵LLMゲートウェイ、Nanndemoya独自APIライセンス、および各種外部API（Gemini / ChatGPT / Claude / Grok / Mistral）に対応しています。",
                provider: .virtualLinuxVM,
                modelName: "System",
                timestamp: Date().addingTimeInterval(-60)
            ),
            AIChatMessage(
                role: "assistant",
                content: "こんにちは！東方Project二次創作総合AIアシスタントです。\n\n・【定額プラン内蔵LLM】新料金プラン（5時間/週次/月次枠＋繰越・広告ボーナス対応）でシナリオ・口調変換・絵コンテを生成\n・【Nanndemoya独自API】「何でも屋」発行のライセンスキーを設定するだけで、定額枠を消費せずマルチLLMを利用可能\n・【外部API管理】ご自身の Gemini / ChatGPT / Claude / Grok / Mistral キーも直接連携可能\n\nどのような東方作品を制作しますか？",
                thinkingContent: "【TohoAIStudio ハイブリッド推論ルーター待機完了】\n- 東方Projectキャラクター口調・二次創作ガイドラインRAG有効\n- 構造化絵コンテJSON出力・AquesTalk読み上げ推敲対応",
                provider: .virtualLinuxVM,
                modelName: "Auto (東方最適ルーティング)",
                timestamp: Date()
            )
        ]
    }

    // MARK: - Send Chat Message
    public func sendMessage(content: String, persona: String? = nil) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let linuxService = CloudVirtualLinuxService.shared

        // 定額プラン内蔵LLM利用時のみプロンプト残数をチェック（NanndemoyaAPI・外部APIは枠消費なし）
        if activeProvider.consumesFlatRateQuota {
            guard linuxService.consumePrompt(count: 1, purpose: "TohoAIStudioチャット") else {
                let errMsg = linuxService.latestNotificationMessage ?? "プロンプト残数が0のため送信できません。"
                AppState.shared.addSystemLog(level: "ERROR", message: errMsg)
                chatMessages.append(AIChatMessage(
                    role: "system",
                    content: "⚠️ \(errMsg)（「プラン・使用量管理」からお試し広告視聴・追加パック・プラン変更、または「外部API管理」をご利用ください）",
                    provider: activeProvider,
                    modelName: "Quota Guard"
                ))
                return
            }
        }

        let userMsg = AIChatMessage(
            role: "user",
            content: trimmed,
            provider: activeProvider,
            modelName: selectedModel,
            timestamp: Date(),
            promptTokens: max(1, trimmed.count / 2)
        )
        chatMessages.append(userMsg)
        isGenerating = true

        let activeProv = activeProvider
        let activeMod = selectedModel
        let historySnapshot = Array(chatMessages.dropLast())

        callAPIOrGenerateSmart(
            prompt: trimmed,
            provider: activeProv,
            model: activeMod,
            persona: persona,
            chatHistory: historySnapshot
        ) { [weak self] responseContent, thinkingLog in
            guard let self = self else { return }
            let aiMsg = AIChatMessage(
                role: "assistant",
                content: responseContent,
                thinkingContent: thinkingLog,
                provider: activeProv,
                modelName: activeMod,
                timestamp: Date(),
                promptTokens: max(1, trimmed.count / 2),
                completionTokens: max(1, responseContent.count / 2)
            )
            self.chatMessages.append(aiMsg)
            self.isGenerating = false
            if responseContent.hasPrefix("⚠️") || responseContent.contains("オフライン応答モード") {
                AppState.shared.addSystemLog(level: "WARN", message: "TohoAIStudio: [\(activeProv.rawValue)] 応答警告 — \(responseContent.prefix(60))")
            } else {
                AppState.shared.addSystemLog(level: "INFO", message: "TohoAIStudio: [\(activeProv.rawValue)] から応答を受信しました。")
            }
        }
    }

    // MARK: - AI Edit & Proofread Execution (実LLMゲートウェイ＋構造化JSON連携)
    public func executeAIEdit() {
        let trimmedInput = editorInputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else { return }

        let linuxService = CloudVirtualLinuxService.shared
        if activeProvider.consumesFlatRateQuota {
            guard linuxService.consumePrompt(count: 1, purpose: "TohoAIStudio AI編集") else {
                editorOutputText = "⚠️ " + (linuxService.latestNotificationMessage ?? "プロンプト残数が0です。")
                AppState.shared.addSystemLog(level: "ERROR", message: "AI編集失敗: プロンプト残数が不足しています。")
                return
            }
        }

        isEditorProcessing = true
        proofreadOriginalCount = trimmedInput.count
        let mode = selectedEditMode
        let tone = selectedTone

        // ゲートウェイ経由（定額プラン or NanndemoyaAPI）の場合はサーバー側構造化編集エンジンを優先呼び出し
        if activeProvider == .virtualLinuxVM || activeProvider == .nanndemoya {
            executeGatewayEditRequest(input: trimmedInput, mode: mode, tone: tone)
        } else {
            // 外部API直接呼び出し
            let editInstruction = buildClientEditPrompt(mode: mode, input: trimmedInput, tone: tone)
            callAPIOrGenerateSmart(prompt: editInstruction, provider: activeProvider, model: selectedModel) { [weak self] text, thinking in
                guard let self = self else { return }
                self.applyEditorResult(rawText: text, thinking: thinking, serverScenes: nil, mode: mode, input: trimmedInput)
            }
        }
    }

    private func executeGatewayEditRequest(input: String, mode: AIEditMode, tone: CharacterTonePreset) {
        let linuxService = CloudVirtualLinuxService.shared
        guard let url = URL(string: "\(linuxService.serverBaseURL)/v1/chat/completions") else {
            runOfflineEditorFallback(input: input, mode: mode, tone: tone)
            return
        }

        var req = URLRequest(url: url, timeoutInterval: 240.0)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = [
            "user_id": linuxService.currentUserId,
            "account_type": AppState.shared.currentAccountType,
            "user_prompt": input,
            "model": selectedModel,
            "temperature": temperature,
            "task_type": "edit",
            "edit_mode": mode.serverModeKey,
            "tone_description": tone.rawValue
        ]
        if activeProvider == .nanndemoya {
            body["nanndemoya_license_key"] = nanndemoyaConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    let msg = CloudVirtualLinuxService.extractErrorDetail(from: data) ?? "ゲートウェイ応答エラー (HTTP \(http.statusCode))"
                    self.editorOutputText = "⚠️ \(msg)"
                    self.editorThinkingText = "サーバーエラー応答 (HTTP \(http.statusCode))"
                    self.isEditorProcessing = false
                    return
                }

                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let text = json["response"] as? String {
                    if let quotaObj = json["quota"],
                       let qData = try? JSONSerialization.data(withJSONObject: quotaObj),
                       let qDecoded = try? JSONDecoder().decode(UserQuotaStatus.self, from: qData) {
                        linuxService.applyQuotaStatus(qDecoded)
                    }
                    let engineName = json["engine"] as? String ?? self.selectedModel
                    let rawThink = json["thinking"] as? String
                    let combinedThink = rawThink != nil ? "【\(engineName)】\n\(rawThink!)" : "【\(engineName) 実LLM推論完了】"
                    let serverScenes = json["scenes"] as? [[String: Any]]
                    self.applyEditorResult(rawText: text, thinking: combinedThink, serverScenes: serverScenes, mode: mode, input: input)
                } else if let urlErr = error as? URLError, urlErr.code == .timedOut {
                    self.editorOutputText = "⚠️ ゲートウェイサーバでのLLM推論がタイムアウトしました。再度お試しいただくか、外部APIをご利用ください。"
                    self.editorThinkingText = "タイムアウト (URLError.timedOut)"
                    self.isEditorProcessing = false
                } else {
                    self.runOfflineEditorFallback(input: input, mode: mode, tone: tone)
                }
            }
        }.resume()
    }

    private func applyEditorResult(
        rawText: String,
        thinking: String?,
        serverScenes: [[String: Any]]?,
        mode: AIEditMode,
        input: String
    ) {
        if mode == .sceneStoryboard {
            let parsed = parseStoryboardScenes(serverScenes: serverScenes, rawText: rawText, fallbackInput: input)
            generatedScenesBuffer = parsed
            editorOutputText = parsed.enumerated().map { idx, sc in
                """
                【シーン #\(idx + 1)】\(sc.title)
                ・予定尺: \(Int(sc.duration))秒
                ・背景: \(sc.backgroundName)
                ・登場キャラ: \(sc.characterName)
                ・テロップ/セリフ: \(sc.telop)
                ・指定BGM: \(sc.audioTrack ?? "なし")
                """
            }.joined(separator: "\n\n")
            proofreadPolishedCount = editorOutputText.count
            proofreadEstimatedDurationSec = parsed.reduce(0.0) { $0 + $1.duration }
        } else {
            editorOutputText = rawText
            proofreadPolishedCount = rawText.count
            proofreadEstimatedDurationSec = Double(rawText.count) / 6.5
        }
        editorThinkingText = thinking ?? ""
        isEditorProcessing = false
        AppState.shared.addSystemLog(level: "INFO", message: "TohoAIStudio: [\(mode.rawValue)] のAI編集処理が完了しました。")
    }

    private func parseStoryboardScenes(serverScenes: [[String: Any]]?, rawText: String, fallbackInput: String) -> [MovieScene] {
        var dicts: [[String: Any]] = serverScenes ?? []
        if dicts.isEmpty {
            if let start = rawText.firstIndex(of: "{"),
               let end = rawText.lastIndex(of: "}") {
                let sub = String(rawText[start...end])
                if let data = sub.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let arr = obj["scenes"] as? [[String: Any]] {
                    dicts = arr
                }
            }
        }

        if !dicts.isEmpty {
            return dicts.enumerated().map { idx, d in
                MovieScene(
                    title: (d["title"] as? String) ?? "シーン\(idx + 1)",
                    duration: (d["duration"] as? Double) ?? Double((d["duration"] as? Int) ?? 8),
                    slideTitle: (d["slideTitle"] as? String) ?? "第\(idx + 1)スライド",
                    backgroundName: (d["backgroundName"] as? String) ?? "博麗神社境内",
                    characterName: (d["characterName"] as? String) ?? "博麗霊夢",
                    telop: (d["telop"] as? String) ?? "",
                    audioTrack: (d["audioTrack"] as? String) ?? "bgm_maiden_capriccio.mp3"
                )
            }
        }

        return generateStoryboardFromPlot(input: fallbackInput).scenes
    }

    private func buildClientEditPrompt(mode: AIEditMode, input: String, tone: CharacterTonePreset) -> String {
        switch mode {
        case .proofreadPolish:
            return "以下の東方Project台本を、読みやすさとゆっくりボイス(AquesTalk)の発話テンポに最適化して推敲してください（基準口調: \(tone.rawValue)）。本文のみ出力:\n\n\(input)"
        case .scenarioRewrite:
            return "以下の文章を『\(tone.rawValue)』の口調・一人称・語尾で生き生きとしたセリフに書き換えてください:\n\n\(input)"
        case .sceneStoryboard:
            return """
            以下のプロットから、3〜5シーンの絵コンテJSONのみを出力してください:
            {"scenes":[{"title":"シーン1","duration":8.0,"slideTitle":"第1スライド","backgroundName":"博麗神社","characterName":"博麗霊夢","telop":"霊夢「セリフ」","audioTrack":"bgm_maiden_capriccio.mp3"}]}

            プロット:
            \(input)
            """
        case .characterPrompt:
            return "対象キャラ『\(tone.characterName)』について、以下の要望に対するPSDTool立ち絵レイヤー指定（眉・目・口・ポーズ・小物）と英語画像生成タグを作成してください:\n\n\(input)"
        case .gameBlocklyScript:
            return "以下の要望をToho-Studioゲームメーカー用JavaScriptイベントスクリプトとして出力してください:\n\n\(input)"
        }
    }

    private func runOfflineEditorFallback(input: String, mode: AIEditMode, tone: CharacterTonePreset) {
        switch mode {
        case .proofreadPolish:
            let r = proofreadScenario(input: input, tone: tone)
            editorOutputText = r.output
            editorThinkingText = r.thinking
            proofreadPolishedCount = r.output.count
            proofreadEstimatedDurationSec = Double(r.output.count) / 6.5
        case .scenarioRewrite:
            let r = rewriteScenarioWithTone(input: input, tone: tone)
            editorOutputText = r.output
            editorThinkingText = r.thinking
            proofreadPolishedCount = r.output.count
            proofreadEstimatedDurationSec = Double(r.output.count) / 6.5
        case .sceneStoryboard:
            let r = generateStoryboardFromPlot(input: input)
            editorOutputText = r.output
            editorThinkingText = r.thinking
            generatedScenesBuffer = r.scenes
            proofreadPolishedCount = r.output.count
            proofreadEstimatedDurationSec = r.scenes.reduce(0.0) { $0 + $1.duration }
        case .characterPrompt:
            let r = generateCharacterPrompt(input: input, tone: tone)
            editorOutputText = r.output
            editorThinkingText = r.thinking
            proofreadPolishedCount = r.output.count
        case .gameBlocklyScript:
            let r = generateGameScript(input: input)
            editorOutputText = r.output
            editorThinkingText = r.thinking
            proofreadPolishedCount = r.output.count
        }
        isEditorProcessing = false
    }

    // MARK: - API / Gateway Hybrid Execution
    public func callAPIOrGenerateSmart(
        prompt: String,
        provider: AIProviderType,
        model: String,
        persona: String? = nil,
        chatHistory: [AIChatMessage] = [],
        completion: @escaping (String, String?) -> Void
    ) {
        switch provider {
        case .virtualLinuxVM:
            executeGatewayChatRequest(prompt: prompt, model: model, persona: persona, licenseKey: nil, completion: completion)
            return
        case .nanndemoya:
            let licKey = nanndemoyaConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !licKey.isEmpty else {
                completion("⚠️ Nanndemoya独自APIのライセンスキーが未設定です。「外部API・Nanndemoya認証」タブからライセンスキーを入力して認証してください。", nil)
                return
            }
            guard nanndemoyaConfig.isEnabled else {
                completion("⚠️ Nanndemoya独自APIの「ライセンスを有効化」がオフになっています。「外部API・Nanndemoya認証」タブで有効化してください。", nil)
                return
            }
            executeGatewayChatRequest(prompt: prompt, model: model, persona: persona, licenseKey: licKey, completion: completion)
            return
        case .gemini, .chatGPT, .claude, .grok, .mistral:
            let key = apiKey(for: provider).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else {
                completion("⚠️ [\(provider.rawValue)] のAPIキーが設定されていません。「外部API・Nanndemoya認証」タブでAPIキーを入力するか、エンジンを「定額プラン内蔵LLM」に切り替えてください。", nil)
                return
            }
            guard isProviderEnabled(provider) else {
                completion("⚠️ [\(provider.rawValue)] の「APIを有効化」がオフになっています。「外部API・Nanndemoya認証」タブでスイッチをオンにするか、エンジンを切り替えてください。", nil)
                return
            }
            executeRealRESTRequest(
                prompt: prompt,
                provider: provider,
                apiKey: key,
                model: model,
                persona: persona,
                chatHistory: chatHistory,
                completion: completion
            )
        }
    }

    public func apiKey(for provider: AIProviderType) -> String {
        switch provider {
        case .virtualLinuxVM: return ""
        case .nanndemoya: return nanndemoyaConfig.apiKey
        case .gemini: return geminiConfig.apiKey
        case .chatGPT: return chatGPTConfig.apiKey
        case .claude: return claudeConfig.apiKey
        case .grok: return grokConfig.apiKey
        case .mistral: return mistralConfig.apiKey
        }
    }

    // MARK: - 実LLM REST APIリクエスト処理 (Gemini / ChatGPT / Claude / Grok / Mistral)
    private func executeRealRESTRequest(
        prompt: String,
        provider: AIProviderType,
        apiKey: String,
        model: String,
        persona: String?,
        chatHistory: [AIChatMessage],
        completion: @escaping (String, String?) -> Void
    ) {
        var systemPrompt = "あなたは東方Projectの同人制作支援AIアシスタントです。幻想郷の世界観、各キャラクターの公式口調・性格・能力・人間関係、二次創作ガイドラインに精通しています。具体的・魅力的・詳細に回答してください。"
        if let p = persona, p != "東方Project総合アシスタント" {
            systemPrompt += "\n現在は『\(p)』として振る舞い、その口調で対話してください。"
        }

        let cleanTurns = sanitizeConversationHistory(chatHistory)

        switch provider {
        case .gemini:
            executeGeminiRESTRequest(
                prompt: prompt,
                systemPrompt: systemPrompt,
                apiKey: apiKey,
                selectedModel: model,
                history: cleanTurns,
                completion: completion
            )

        case .chatGPT, .grok, .mistral:
            let endpoint: String
            let candidates: [String]
            let label: String
            let low = model.lowercased()
            switch provider {
            case .chatGPT:
                endpoint = "https://api.openai.com/v1/chat/completions"
                if low.contains("o3") {
                    candidates = ["o3-mini", "gpt-4o-mini", "gpt-4o"]
                } else if low.contains("mini") {
                    candidates = ["gpt-4o-mini", "gpt-4o"]
                } else {
                    candidates = ["gpt-4o", "gpt-4o-mini"]
                }
                label = "OpenAI ChatGPT"
            case .grok:
                endpoint = "https://api.x.ai/v1/chat/completions"
                candidates = low.contains("mini") ? ["grok-3-mini", "grok-3"] : ["grok-3", "grok-3-mini"]
                label = "xAI Grok"
            default:
                endpoint = "https://api.mistral.ai/v1/chat/completions"
                candidates = low.contains("small") ? ["mistral-small-latest", "mistral-large-latest"] : ["mistral-large-latest", "mistral-small-latest"]
                label = "Mistral AI"
            }

            tryOpenAICompatibleCandidates(
                endpoint: endpoint,
                candidates: candidates,
                label: label,
                provider: provider,
                apiKey: apiKey,
                systemPrompt: systemPrompt,
                prompt: prompt,
                history: cleanTurns,
                completion: completion
            )

        case .claude:
            executeClaudeRESTRequest(
                prompt: prompt,
                systemPrompt: systemPrompt,
                apiKey: apiKey,
                selectedModel: model,
                history: cleanTurns,
                completion: completion
            )

        case .virtualLinuxVM, .nanndemoya:
            executeGatewayChatRequest(prompt: prompt, model: model, persona: persona, licenseKey: apiKey, completion: completion)
        }
    }

    private func sanitizeConversationHistory(_ raw: [AIChatMessage]) -> [(role: String, content: String)] {
        var filtered: [(role: String, content: String)] = []
        for msg in raw.suffix(10) {
            guard msg.role == "user" || msg.role == "assistant" else { continue }
            let text = msg.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            if msg.role == "assistant" {
                if text.hasPrefix("⚠️") ||
                   text.contains("現在ゲートウェイサーバへ未接続") ||
                   text.contains("こんにちは！東方Project二次創作総合AIアシスタントです。") {
                    continue
                }
            }
            if let last = filtered.last, last.role == msg.role {
                filtered[filtered.count - 1] = (role: msg.role, content: text)
            } else {
                filtered.append((role: msg.role, content: text))
            }
        }
        while let first = filtered.first, first.role != "user" {
            filtered.removeFirst()
        }
        while let last = filtered.last, last.role == "user" {
            filtered.removeLast()
        }
        return Array(filtered.suffix(6))
    }

    // MARK: - Google Gemini 動的モデル解決 & 直接推論
    private static func parseGeminiGenerateModels(from data: Data) -> [String] {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["models"] as? [[String: Any]] else {
            return []
        }
        let excludedKeywords = [
            "tts", "image", "vision", "audio", "embedding", "aqa",
            "computer-use", "robotics", "live", "thinking-exp", "learnlm", "bisheng"
        ]
        var result: [String] = []
        for item in models {
            let methods = (item["supportedGenerationMethods"] as? [String]) ?? []
            guard methods.contains("generateContent") else { continue }
            guard let rawName = item["name"] as? String else { continue }
            let modelId = rawName.hasPrefix("models/") ? String(rawName.dropFirst("models/".count)) : rawName
            let low = modelId.lowercased()
            guard low.hasPrefix("gemini-") else { continue }
            if excludedKeywords.contains(where: { low.contains($0) }) { continue }
            if !result.contains(modelId) {
                result.append(modelId)
            }
        }
        return result
    }

    private static func geminiModelPriorityScore(_ modelId: String) -> Double {
        let low = modelId.lowercased()
        var score = 0.0
        if let regex = try? NSRegularExpression(pattern: "gemini-(\\d+(?:\\.\\d+)?)"),
           let match = regex.firstMatch(in: low, range: NSRange(low.startIndex..., in: low)),
           let range = Range(match.range(at: 1), in: low),
           let ver = Double(low[range]) {
            score += ver * 100.0
        }
        if low == "gemini-flash-latest" || low == "gemini-pro-latest" {
            score += 320.0
        }
        if !low.contains("preview") && !low.contains("exp") {
            score += 15.0
        }
        if low.contains("lite") {
            score -= 20.0
        }
        return score
    }

    private static func buildGeminiModelCandidates(selectedModel: String, discovered: [String]) -> [String] {
        let low = selectedModel.lowercased()
        let wantsPro = low.contains("pro")
        let wants20 = low.contains("2.0")

        var ordered: [String] = []
        func appendUnique(_ id: String) {
            if !id.isEmpty && !ordered.contains(id) {
                ordered.append(id)
            }
        }

        if !discovered.isEmpty {
            let sorted = discovered.sorted { geminiModelPriorityScore($0) > geminiModelPriorityScore($1) }
            let proModels = sorted.filter { $0.lowercased().contains("pro") }
            let flashStandard = sorted.filter { $0.lowercased().contains("flash") && !$0.lowercased().contains("lite") }
            let flashLite = sorted.filter { $0.lowercased().contains("flash") && $0.lowercased().contains("lite") }

            if wantsPro {
                if discovered.contains("gemini-2.5-pro") { appendUnique("gemini-2.5-pro") }
                if discovered.contains("gemini-pro-latest") { appendUnique("gemini-pro-latest") }
                proModels.forEach { appendUnique($0) }
                if discovered.contains("gemini-flash-latest") { appendUnique("gemini-flash-latest") }
                flashStandard.prefix(2).forEach { appendUnique($0) }
            } else {
                if wants20 && discovered.contains("gemini-2.0-flash") {
                    appendUnique("gemini-2.0-flash")
                } else if !wants20 && discovered.contains("gemini-2.5-flash") {
                    appendUnique("gemini-2.5-flash")
                }
                if discovered.contains("gemini-flash-latest") { appendUnique("gemini-flash-latest") }
                flashStandard.forEach { appendUnique($0) }
                flashLite.forEach { appendUnique($0) }
                proModels.prefix(1).forEach { appendUnique($0) }
            }
        } else {
            if wantsPro {
                ["gemini-pro-latest", "gemini-2.5-pro", "gemini-flash-latest", "gemini-2.5-flash"].forEach { appendUnique($0) }
            } else if wants20 {
                ["gemini-2.0-flash", "gemini-flash-latest", "gemini-2.5-flash", "gemini-2.5-flash-lite"].forEach { appendUnique($0) }
            } else {
                ["gemini-flash-latest", "gemini-2.5-flash", "gemini-2.5-flash-lite", "gemini-2.0-flash"].forEach { appendUnique($0) }
            }
        }
        return Array(ordered.prefix(5))
    }

    private func executeGeminiRESTRequest(
        prompt: String,
        systemPrompt: String,
        apiKey: String,
        selectedModel: String,
        history: [(role: String, content: String)],
        completion: @escaping (String, String?) -> Void
    ) {
        let cleanKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !discoveredGeminiModels.isEmpty {
            let candidates = Self.buildGeminiModelCandidates(selectedModel: selectedModel, discovered: discoveredGeminiModels)
            tryGeminiCandidates(
                candidates: candidates,
                apiKey: cleanKey,
                systemPrompt: systemPrompt,
                prompt: prompt,
                history: history,
                lastError: nil,
                completion: completion
            )
            return
        }

        // 初回は利用可能なモデル一覧を取得してキーに適合する最新モデルを自動解決
        guard let listURL = URL(string: "https://generativelanguage.googleapis.com/v1beta/models") else {
            let fallbackCandidates = Self.buildGeminiModelCandidates(selectedModel: selectedModel, discovered: [])
            tryGeminiCandidates(candidates: fallbackCandidates, apiKey: cleanKey, systemPrompt: systemPrompt, prompt: prompt, history: history, lastError: nil, completion: completion)
            return
        }

        var listReq = URLRequest(url: listURL, timeoutInterval: 10)
        listReq.setValue(cleanKey, forHTTPHeaderField: "x-goog-api-key")
        URLSession.shared.dataTask(with: listReq) { [weak self] data, res, err in
            guard let self = self else { return }
            if let http = res as? HTTPURLResponse, (http.statusCode == 400 || http.statusCode == 401 || http.statusCode == 403) {
                let detail = Self.extractProviderAPIError(from: data, statusCode: http.statusCode, fallbackError: err)
                DispatchQueue.main.async {
                    completion("⚠️ [Google Gemini] API認証エラー (HTTP \(http.statusCode)): \(detail)", "Google Gemini API HTTP \(http.statusCode)")
                }
                return
            }

            var discovered: [String] = []
            if let data = data {
                discovered = Self.parseGeminiGenerateModels(from: data)
            }
            DispatchQueue.main.async {
                if !discovered.isEmpty {
                    self.discoveredGeminiModels = discovered
                }
                let candidates = Self.buildGeminiModelCandidates(selectedModel: selectedModel, discovered: discovered)
                self.tryGeminiCandidates(
                    candidates: candidates,
                    apiKey: cleanKey,
                    systemPrompt: systemPrompt,
                    prompt: prompt,
                    history: history,
                    lastError: nil,
                    completion: completion
                )
            }
        }.resume()
    }

    private func tryGeminiCandidates(
        candidates: [String],
        apiKey: String,
        systemPrompt: String,
        prompt: String,
        history: [(role: String, content: String)],
        lastError: String?,
        completion: @escaping (String, String?) -> Void
    ) {
        guard let modelId = candidates.first,
              let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelId):generateContent") else {
            let errMsg = lastError ?? "利用可能なGeminiモデルへの接続に失敗しました。APIキーとネットワーク接続をご確認ください。"
            DispatchQueue.main.async {
                completion("⚠️ [Google Gemini] \(errMsg)", "Google Gemini API エラー")
            }
            return
        }

        var req = URLRequest(url: url, timeoutInterval: 90)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-goog-api-key")

        var contents: [[String: Any]] = history.map { turn in
            [
                "role": turn.role == "assistant" ? "model" : "user",
                "parts": [["text": turn.content]]
            ]
        }
        contents.append([
            "role": "user",
            "parts": [["text": prompt]]
        ])

        let bodyDict: [String: Any] = [
            "system_instruction": ["parts": [["text": systemPrompt]]],
            "contents": contents,
            "generationConfig": [
                "temperature": temperature,
                "maxOutputTokens": 8192
            ]
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: bodyDict)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            if statusCode == 200,
               let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let candidatesArr = json["candidates"] as? [[String: Any]],
                   let firstCandidate = candidatesArr.first {
                    if let contentObj = firstCandidate["content"] as? [String: Any],
                       let parts = contentObj["parts"] as? [[String: Any]] {
                        var answerParts: [String] = []
                        var thoughtParts: [String] = []
                        for part in parts {
                            guard let t = part["text"] as? String else { continue }
                            if (part["thought"] as? Bool) == true {
                                thoughtParts.append(t)
                            } else {
                                answerParts.append(t)
                            }
                        }
                        let answer = answerParts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                        let fallbackThought = thoughtParts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                        let finalText = !answer.isEmpty ? answer : fallbackThought
                        if !finalText.isEmpty {
                            var thinkHeader = "【Google Gemini API (\(modelId)) 直接推論完了（定額枠消費なし）】"
                            if !thoughtParts.isEmpty && !answer.isEmpty {
                                thinkHeader += "\n" + thoughtParts.joined(separator: "\n")
                            }
                            DispatchQueue.main.async {
                                completion(finalText, thinkHeader)
                            }
                            return
                        }
                    }

                    let finishReason = (firstCandidate["finishReason"] as? String) ?? "UNKNOWN"
                    let blockDetail = "応答テキストが空でした (finishReason: \(finishReason))"
                    let next = Array(candidates.dropFirst())
                    if !next.isEmpty {
                        self?.tryGeminiCandidates(candidates: next, apiKey: apiKey, systemPrompt: systemPrompt, prompt: prompt, history: history, lastError: blockDetail, completion: completion)
                    } else {
                        DispatchQueue.main.async {
                            completion("⚠️ [Google Gemini] \(blockDetail)", "Google Gemini (\(modelId))")
                        }
                    }
                    return
                }

                if let feedback = json["promptFeedback"] as? [String: Any],
                   let blockReason = feedback["blockReason"] as? String {
                    DispatchQueue.main.async {
                        completion("⚠️ [Google Gemini] セーフティフィルタにより応答がブロックされました (reason: \(blockReason))。", "Google Gemini (\(modelId))")
                    }
                    return
                }
            }

            let errDetail = Self.extractProviderAPIError(from: data, statusCode: statusCode, fallbackError: error)
            let formattedErr = statusCode > 0 ? "APIエラー (HTTP \(statusCode) / \(modelId)): \(errDetail)" : "通信エラー (\(modelId)): \(errDetail)"

            // 認証エラー(401/403)以外は代替モデル候補へ自動フェイルオーバー
            let remaining = Array(candidates.dropFirst())
            if !remaining.isEmpty && statusCode != 401 && statusCode != 403 {
                self?.tryGeminiCandidates(
                    candidates: remaining,
                    apiKey: apiKey,
                    systemPrompt: systemPrompt,
                    prompt: prompt,
                    history: history,
                    lastError: formattedErr,
                    completion: completion
                )
            } else {
                DispatchQueue.main.async {
                    completion("⚠️ [Google Gemini] \(formattedErr)", "Google Gemini API エラー")
                }
            }
        }.resume()
    }

    // MARK: - OpenAI / xAI Grok / Mistral 共通リクエスト処理
    private func tryOpenAICompatibleCandidates(
        endpoint: String,
        candidates: [String],
        label: String,
        provider: AIProviderType,
        apiKey: String,
        systemPrompt: String,
        prompt: String,
        history: [(role: String, content: String)],
        lastError: String? = nil,
        completion: @escaping (String, String?) -> Void
    ) {
        guard let modelId = candidates.first, let url = URL(string: endpoint) else {
            let msg = lastError ?? "APIエンドポイントへの接続に失敗しました。"
            DispatchQueue.main.async {
                completion("⚠️ [\(provider.rawValue)] \(msg)", "\(label) エラー")
            }
            return
        }

        var req = URLRequest(url: url, timeoutInterval: 90)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        var messages: [[String: String]] = [["role": "system", "content": systemPrompt]]
        for turn in history {
            messages.append(["role": turn.role, "content": turn.content])
        }
        messages.append(["role": "user", "content": prompt])

        var bodyDict: [String: Any] = [
            "model": modelId,
            "messages": messages
        ]
        // o1 / o3 系推論モデルは temperature 指定非対応のため除外
        let lowModel = modelId.lowercased()
        if !lowModel.hasPrefix("o1") && !lowModel.hasPrefix("o3") && !lowModel.hasPrefix("o4") {
            bodyDict["temperature"] = temperature
        }
        req.httpBody = try? JSONSerialization.data(withJSONObject: bodyDict)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            if statusCode == 200,
               let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let choices = json["choices"] as? [[String: Any]],
               let msg = choices.first?["message"] as? [String: Any],
               let text = msg["content"] as? String,
               !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                var thinkHeader = "【\(label) (\(modelId)) 直接推論完了（定額枠消費なし）】"
                if let reasoning = msg["reasoning_content"] as? String, !reasoning.isEmpty {
                    thinkHeader += "\n\(reasoning)"
                }
                DispatchQueue.main.async {
                    completion(text, thinkHeader)
                }
                return
            }

            let errDetail = Self.extractProviderAPIError(from: data, statusCode: statusCode, fallbackError: error)
            let formattedErr = statusCode > 0 ? "APIエラー (HTTP \(statusCode) / \(modelId)): \(errDetail)" : "通信エラー: \(errDetail)"
            let remaining = Array(candidates.dropFirst())
            if !remaining.isEmpty && (statusCode == 404 || statusCode == 400) {
                self?.tryOpenAICompatibleCandidates(
                    endpoint: endpoint,
                    candidates: remaining,
                    label: label,
                    provider: provider,
                    apiKey: apiKey,
                    systemPrompt: systemPrompt,
                    prompt: prompt,
                    history: history,
                    lastError: formattedErr,
                    completion: completion
                )
            } else {
                DispatchQueue.main.async {
                    completion("⚠️ [\(provider.rawValue)] \(formattedErr)", "\(label) API エラー")
                }
            }
        }.resume()
    }

    // MARK: - Anthropic Claude 動的モデル解決 & 直接推論
    private func executeClaudeRESTRequest(
        prompt: String,
        systemPrompt: String,
        apiKey: String,
        selectedModel: String,
        history: [(role: String, content: String)],
        completion: @escaping (String, String?) -> Void
    ) {
        let wantsHaiku = selectedModel.lowercased().contains("haiku")
        var candidates: [String] = []
        if !discoveredClaudeModels.isEmpty {
            let matching = discoveredClaudeModels.filter {
                wantsHaiku ? $0.lowercased().contains("haiku") : $0.lowercased().contains("sonnet")
            }
            candidates.append(contentsOf: matching)
            candidates.append(contentsOf: discoveredClaudeModels.filter { !candidates.contains($0) })
        }
        let defaults = wantsHaiku
            ? ["claude-3-5-haiku-latest", "claude-haiku-4-5", "claude-3-7-sonnet-latest"]
            : ["claude-3-7-sonnet-latest", "claude-sonnet-4-5", "claude-3-5-haiku-latest"]
        for d in defaults where !candidates.contains(d) {
            candidates.append(d)
        }

        tryClaudeCandidates(
            candidates: Array(candidates.prefix(4)),
            apiKey: apiKey,
            systemPrompt: systemPrompt,
            prompt: prompt,
            history: history,
            didRefreshModels: !discoveredClaudeModels.isEmpty,
            lastError: nil,
            completion: completion
        )
    }

    private func tryClaudeCandidates(
        candidates: [String],
        apiKey: String,
        systemPrompt: String,
        prompt: String,
        history: [(role: String, content: String)],
        didRefreshModels: Bool,
        lastError: String?,
        completion: @escaping (String, String?) -> Void
    ) {
        guard let modelId = candidates.first,
              let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            let errMsg = lastError ?? "Anthropic APIへの接続に失敗しました。"
            DispatchQueue.main.async {
                completion("⚠️ [Anthropic Claude] \(errMsg)", "Anthropic Claude エラー")
            }
            return
        }

        var req = URLRequest(url: url, timeoutInterval: 90)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        var messages: [[String: String]] = history.map { ["role": $0.role, "content": $0.content] }
        messages.append(["role": "user", "content": prompt])

        let bodyDict: [String: Any] = [
            "model": modelId,
            "system": systemPrompt,
            "max_tokens": 4096,
            "messages": messages
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: bodyDict)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0
            if statusCode == 200,
               let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let contents = json["content"] as? [[String: Any]] {
                let texts = contents.compactMap { $0["text"] as? String }
                let combined = texts.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
                if !combined.isEmpty {
                    DispatchQueue.main.async {
                        completion(combined, "【Anthropic Claude (\(modelId)) 直接推論完了（定額枠消費なし）】")
                    }
                    return
                }
            }

            let errDetail = Self.extractProviderAPIError(from: data, statusCode: statusCode, fallbackError: error)
            let formattedErr = statusCode > 0 ? "APIエラー (HTTP \(statusCode) / \(modelId)): \(errDetail)" : "通信エラー: \(errDetail)"

            if statusCode == 404 && !didRefreshModels,
               let modelsURL = URL(string: "https://api.anthropic.com/v1/models") {
                var mReq = URLRequest(url: modelsURL, timeoutInterval: 10)
                mReq.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                mReq.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
                URLSession.shared.dataTask(with: mReq) { [weak self] mData, _, _ in
                    var ids: [String] = []
                    if let mData = mData,
                       let mJson = try? JSONSerialization.jsonObject(with: mData) as? [String: Any],
                       let dataArr = mJson["data"] as? [[String: Any]] {
                        ids = dataArr.compactMap { $0["id"] as? String }
                    }
                    DispatchQueue.main.async {
                        guard let self = self else { return }
                        if !ids.isEmpty {
                            self.discoveredClaudeModels = ids
                            self.tryClaudeCandidates(candidates: Array(ids.prefix(3)), apiKey: apiKey, systemPrompt: systemPrompt, prompt: prompt, history: history, didRefreshModels: true, lastError: formattedErr, completion: completion)
                        } else {
                            self.tryClaudeCandidates(candidates: Array(candidates.dropFirst()), apiKey: apiKey, systemPrompt: systemPrompt, prompt: prompt, history: history, didRefreshModels: true, lastError: formattedErr, completion: completion)
                        }
                    }
                }.resume()
                return
            }

            let remaining = Array(candidates.dropFirst())
            if !remaining.isEmpty && statusCode == 404 {
                self?.tryClaudeCandidates(candidates: remaining, apiKey: apiKey, systemPrompt: systemPrompt, prompt: prompt, history: history, didRefreshModels: didRefreshModels, lastError: formattedErr, completion: completion)
            } else {
                DispatchQueue.main.async {
                    completion("⚠️ [Anthropic Claude] \(formattedErr)", "Anthropic Claude API エラー")
                }
            }
        }.resume()
    }

    private static func extractProviderAPIError(from data: Data?, statusCode: Int, fallbackError: Error?) -> String {
        if let data = data {
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let errObj = json["error"] as? [String: Any],
                   let message = errObj["message"] as? String, !message.isEmpty {
                    return String(message.prefix(280))
                }
                if let errStr = json["error"] as? String, !errStr.isEmpty {
                    return String(errStr.prefix(280))
                }
                if let msg = json["message"] as? String, !msg.isEmpty {
                    return String(msg.prefix(280))
                }
                if let detail = json["detail"] as? String, !detail.isEmpty {
                    return String(detail.prefix(280))
                }
            }
            if let rawText = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !rawText.isEmpty, !rawText.hasPrefix("<") {
                return String(rawText.prefix(200))
            }
        }
        if let fallbackError = fallbackError {
            return fallbackError.localizedDescription
        }
        switch statusCode {
        case 401, 403: return "APIキーが無効、または権限がありません。"
        case 404: return "指定されたモデルが見つかりません。"
        case 429: return "APIの利用上限（レート制限または無料枠クォータ）に達しました。"
        default: return statusCode > 0 ? "HTTPステータス \(statusCode)" : "ネットワーク通信エラー"
        }
    }

    // MARK: - ゲートウェイサーバ通信 (定額プラン & NanndemoyaAPI 共通ルーター)
    private func executeGatewayChatRequest(
        prompt: String,
        model: String,
        persona: String?,
        licenseKey: String?,
        completion: @escaping (String, String?) -> Void
    ) {
        let linuxService = CloudVirtualLinuxService.shared
        let endpoints: [String]
        if let lic = licenseKey, !lic.isEmpty {
            endpoints = ["\(linuxService.serverBaseURL)/v1/chat/completions"]
        } else {
            endpoints = [
                "\(linuxService.serverBaseURL)/v1/chat/completions",
                "http://127.0.0.1:11434/api/chat"
            ]
        }
        tryNextEndpoint(endpoints: endpoints, prompt: prompt, model: model, persona: persona, licenseKey: licenseKey, gatewayFailureReason: nil, completion: completion)
    }

    private func tryNextEndpoint(
        endpoints: [String],
        prompt: String,
        model: String,
        persona: String?,
        licenseKey: String?,
        gatewayFailureReason: String?,
        completion: @escaping (String, String?) -> Void
    ) {
        guard let urlStr = endpoints.first, let url = URL(string: urlStr) else {
            if let reason = gatewayFailureReason {
                completion("⚠️ \(reason)", "ゲートウェイ通信タイムアウト / 推論エラー")
            } else {
                fallbackDynamic(prompt: prompt, provider: .virtualLinuxVM, model: model, completion: completion)
            }
            return
        }

        let isGatewayEndpoint = urlStr.contains("/v1/chat/completions")
        var req = URLRequest(url: url, timeoutInterval: isGatewayEndpoint ? 240.0 : 15.0)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if isGatewayEndpoint {
            var body: [String: Any] = [
                "user_id": CloudVirtualLinuxService.shared.currentUserId,
                "account_type": AppState.shared.currentAccountType,
                "user_prompt": prompt,
                "model": model,
                "temperature": temperature,
                "task_type": "chat"
            ]
            if let p = persona {
                body["persona"] = p
            }
            if let lic = licenseKey, !lic.isEmpty {
                body["nanndemoya_license_key"] = lic
            }
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        } else {
            // ローカル Mac ネイティブ Ollama (127.0.0.1:11434) フォールバック
            let body: [String: Any] = [
                "model": "qwen2.5:3b",
                "messages": [
                    ["role": "system", "content": "あなたは東方Projectの二次創作支援AIアシスタントです。自然な日本語で回答してください。"],
                    ["role": "user", "content": prompt]
                ],
                "stream": false
            ]
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            if let http = response as? HTTPURLResponse, isGatewayEndpoint, http.statusCode != 200 {
                let detail = CloudVirtualLinuxService.extractErrorDetail(from: data) ?? "ゲートウェイサーバエラー (HTTP \(http.statusCode))"
                DispatchQueue.main.async {
                    completion("⚠️ \(detail)", "ゲートウェイ応答 HTTP \(http.statusCode)")
                }
                return
            }

            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                if let text = json["response"] as? String {
                    DispatchQueue.main.async {
                        if let quotaObj = json["quota"],
                           let qData = try? JSONSerialization.data(withJSONObject: quotaObj),
                           let qDecoded = try? JSONDecoder().decode(UserQuotaStatus.self, from: qData) {
                            CloudVirtualLinuxService.shared.applyQuotaStatus(qDecoded)
                        } else if let rem = json["remaining_prompts"] as? Int {
                            CloudVirtualLinuxService.shared.remainingPrompts = rem
                            AppState.shared.aiPlanRemainingPrompts = rem
                        }
                        let engine = json["engine"] as? String ?? model
                        let latency = json["latency_ms"] as? Double ?? 0
                        let rawThink = json["thinking"] as? String
                        let modeNote = (licenseKey?.isEmpty == false) ? "NanndemoyaAPIライセンス中継（定額枠消費なし）" : "定額プランゲートウェイ推論"
                        let header = "【\(modeNote) | Engine: \(engine) | \(Int(latency))ms】"
                        let finalThink = rawThink != nil ? "\(header)\n\(rawThink!)" : header
                        completion(text, finalThink)
                    }
                    return
                }

                if let msg = json["message"] as? [String: Any],
                   let text = msg["content"] as? String {
                    DispatchQueue.main.async {
                        completion(text, "【Macローカル Ollama 直接推論】")
                    }
                    return
                }
            }

            var updatedReason = gatewayFailureReason
            if isGatewayEndpoint {
                if let urlErr = error as? URLError, urlErr.code == .timedOut {
                    updatedReason = "ゲートウェイサーバ (\(CloudVirtualLinuxService.shared.serverBaseURL)) でのLLM推論がタイムアウトしました。ローカルCPU推論が高負荷の可能性があります。しばらく待って再試行するか、外部APIをご利用ください。"
                } else if CloudVirtualLinuxService.shared.isConnected, let error = error {
                    updatedReason = "ゲートウェイ推論通信中にエラーが発生しました: \(error.localizedDescription)"
                }
            }

            let remaining = Array(endpoints.dropFirst())
            if !remaining.isEmpty {
                self?.tryNextEndpoint(
                    endpoints: remaining,
                    prompt: prompt,
                    model: model,
                    persona: persona,
                    licenseKey: licenseKey,
                    gatewayFailureReason: updatedReason,
                    completion: completion
                )
            } else {
                DispatchQueue.main.async {
                    if let reason = updatedReason {
                        completion("⚠️ \(reason)", "ゲートウェイ通信タイムアウト / エラー")
                    } else {
                        self?.fallbackDynamic(prompt: prompt, provider: .virtualLinuxVM, model: model, completion: completion)
                    }
                }
            }
        }.resume()
    }

    private func fallbackDynamic(prompt: String, provider: AIProviderType, model: String, completion: @escaping (String, String?) -> Void) {
        let (output, thinking) = generateDynamicContextualResponse(for: prompt, provider: provider, model: model)
        completion(output, thinking)
    }

    // MARK: - Test API / License Connection
    public func testAPIConnection(provider: AIProviderType, completion: ((Bool, String) -> Void)? = nil) {
        let start = Date()
        switch provider {
        case .virtualLinuxVM:
            CloudVirtualLinuxService.shared.checkHealth { ok in
                let msg = ok ? "ゲートウェイ接続正常 (\(CloudVirtualLinuxService.shared.latencyMs)ms)" : "ゲートウェイに接続できません"
                completion?(ok, msg)
            }
        case .nanndemoya:
            let key = nanndemoyaConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            CloudVirtualLinuxService.shared.verifyNanndemoyaLicense(licenseKey: key) { [weak self] result in
                guard let self = self else { return }
                let ms = max(1, Int(Date().timeIntervalSince(start) * 1000))
                switch result {
                case .success(let info):
                    self.nanndemoyaConfig.latencyMs = ms
                    self.nanndemoyaConfig.isConnected = true
                    self.nanndemoyaConfig.isEnabled = true
                    self.nanndemoyaConfig.lastTestedAt = Date()
                    self.nanndemoyaLicenseInfo = info
                    let msg = "認証成功: \(info.label) (累計 \(info.usage.total_requests)回利用)"
                    self.nanndemoyaStatusMessage = msg
                    completion?(true, msg)
                case .failure(let err):
                    self.nanndemoyaConfig.isConnected = false
                    self.nanndemoyaStatusMessage = err.localizedDescription
                    completion?(false, err.localizedDescription)
                }
            }
        case .gemini:
            let key = geminiConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models") else {
                geminiConfig.isConnected = false
                completion?(false, "APIキーを入力してください")
                return
            }
            var req = URLRequest(url: url, timeoutInterval: 10)
            req.setValue(key, forHTTPHeaderField: "x-goog-api-key")
            URLSession.shared.dataTask(with: req) { [weak self] data, res, err in
                let statusCode = (res as? HTTPURLResponse)?.statusCode ?? 0
                let ok = statusCode == 200
                let models = (ok && data != nil) ? Self.parseGeminiGenerateModels(from: data!) : []
                let errDetail = ok ? "" : Self.extractProviderAPIError(from: data, statusCode: statusCode, fallbackError: err)
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    self.geminiConfig.isConnected = ok
                    self.geminiConfig.latencyMs = max(1, Int(Date().timeIntervalSince(start) * 1000))
                    self.geminiConfig.lastTestedAt = Date()
                    if ok {
                        self.geminiConfig.isEnabled = true
                        if !models.isEmpty {
                            self.discoveredGeminiModels = models
                        }
                        let preferred = Self.buildGeminiModelCandidates(selectedModel: self.geminiConfig.selectedModel, discovered: models).first ?? "gemini-flash-latest"
                        completion?(true, "Google Gemini 認証成功 (推論モデル: \(preferred))")
                    } else {
                        completion?(false, "Google Gemini 認証失敗: \(errDetail)")
                    }
                }
            }.resume()
        case .chatGPT:
            testBearerModelsEndpoint(urlStr: "https://api.openai.com/v1/models", key: chatGPTConfig.apiKey, start: start) { [weak self] ok, ms, errMsg in
                self?.chatGPTConfig.isConnected = ok
                self?.chatGPTConfig.latencyMs = ms
                self?.chatGPTConfig.lastTestedAt = Date()
                if ok { self?.chatGPTConfig.isEnabled = true }
                completion?(ok, ok ? "OpenAI 認証成功" : "OpenAI 認証失敗: \(errMsg)")
            }
        case .claude:
            let key = claudeConfig.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, let url = URL(string: "https://api.anthropic.com/v1/models") else {
                claudeConfig.isConnected = false
                completion?(false, "APIキーを入力してください")
                return
            }
            var req = URLRequest(url: url, timeoutInterval: 10)
            req.setValue(key, forHTTPHeaderField: "x-api-key")
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            URLSession.shared.dataTask(with: req) { [weak self] data, res, err in
                let statusCode = (res as? HTTPURLResponse)?.statusCode ?? 0
                let ok = statusCode == 200
                var ids: [String] = []
                if ok, let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let arr = json["data"] as? [[String: Any]] {
                    ids = arr.compactMap { $0["id"] as? String }
                }
                let errDetail = ok ? "" : Self.extractProviderAPIError(from: data, statusCode: statusCode, fallbackError: err)
                DispatchQueue.main.async {
                    self?.claudeConfig.isConnected = ok
                    self?.claudeConfig.latencyMs = max(1, Int(Date().timeIntervalSince(start) * 1000))
                    self?.claudeConfig.lastTestedAt = Date()
                    if ok {
                        self?.claudeConfig.isEnabled = true
                        if !ids.isEmpty { self?.discoveredClaudeModels = ids }
                    }
                    completion?(ok, ok ? "Anthropic 認証成功" : "Anthropic 認証失敗: \(errDetail)")
                }
            }.resume()
        case .grok:
            testBearerModelsEndpoint(urlStr: "https://api.x.ai/v1/models", key: grokConfig.apiKey, start: start) { [weak self] ok, ms, errMsg in
                self?.grokConfig.isConnected = ok
                self?.grokConfig.latencyMs = ms
                self?.grokConfig.lastTestedAt = Date()
                if ok { self?.grokConfig.isEnabled = true }
                completion?(ok, ok ? "xAI Grok 認証成功" : "Grok 認証失敗: \(errMsg)")
            }
        case .mistral:
            testBearerModelsEndpoint(urlStr: "https://api.mistral.ai/v1/models", key: mistralConfig.apiKey, start: start) { [weak self] ok, ms, errMsg in
                self?.mistralConfig.isConnected = ok
                self?.mistralConfig.latencyMs = ms
                self?.mistralConfig.lastTestedAt = Date()
                if ok { self?.mistralConfig.isEnabled = true }
                completion?(ok, ok ? "Mistral AI 認証成功" : "Mistral 認証失敗: \(errMsg)")
            }
        }
    }

    private func testBearerModelsEndpoint(urlStr: String, key: String, start: Date, done: @escaping (Bool, Int, String) -> Void) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let url = URL(string: urlStr) else {
            done(false, 0, "APIキーを入力してください")
            return
        }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.setValue("Bearer \(trimmed)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: req) { data, res, err in
            let statusCode = (res as? HTTPURLResponse)?.statusCode ?? 0
            let ok = statusCode == 200
            let ms = max(1, Int(Date().timeIntervalSince(start) * 1000))
            let errDetail = ok ? "" : Self.extractProviderAPIError(from: data, statusCode: statusCode, fallbackError: err)
            DispatchQueue.main.async {
                done(ok, ms, errDetail)
            }
        }.resume()
    }

    // MARK: - オフライン時用動的コンテキストフォールバック
    private func generateDynamicContextualResponse(for prompt: String, provider: AIProviderType, model: String) -> (String, String?) {
        let detectedCharacters = extractCharacters(from: prompt)
        let mainChar = detectedCharacters.first ?? "博麗霊夢"
        let subChar = detectedCharacters.count > 1 ? detectedCharacters[1] : (mainChar == "博麗霊夢" ? "霧雨魔理沙" : "博麗霊夢")
        let stage = extractStage(from: prompt)
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)

        let thinking = """
        【オフライン内蔵フォールバック推論 (\(model))】
        - ゲートウェイ未接続のためローカル東方コンテキスト辞書で合成しました
        - 検出キャラ: [\(detectedCharacters.isEmpty ? mainChar : detectedCharacters.joined(separator: ", "))] / 舞台: \(stage)
        - 入力先頭: 「\(cleanPrompt.prefix(35))...」
        """

        if prompt.contains("台本") || prompt.contains("会話") || prompt.contains("脚本") || prompt.contains("シナリオ") || prompt.contains("掛け合い") || prompt.contains("作って") || prompt.contains("書いて") {
            return (generateDynamicScript(prompt: prompt, mainChar: mainChar, subChar: subChar, stage: stage), thinking)
        }
        if prompt.contains("画像") || prompt.contains("イラスト") || prompt.contains("背景") || prompt.contains("立ち絵") {
            return (generateDynamicImageAdvice(prompt: prompt, mainChar: mainChar, stage: stage), thinking)
        }
        if prompt.contains("BGM") || prompt.contains("曲") || prompt.contains("音楽") || prompt.contains("SE") || prompt.contains("効果音") {
            return (generateDynamicSoundAdvice(prompt: prompt, mainChar: mainChar, stage: stage), thinking)
        }
        if prompt.contains("コード") || prompt.contains("Blockly") || prompt.contains("ゲーム") || prompt.contains("スクリプト") {
            return (generateDynamicCode(prompt: prompt, mainChar: mainChar), thinking)
        }
        return (generateDynamicGeneralChat(prompt: prompt, mainChar: mainChar, subChar: subChar), thinking)
    }

    private func extractCharacters(from text: String) -> [String] {
        let candidateList = [
            "博麗霊夢", "霊夢", "霧雨魔理沙", "魔理沙", "十六夜咲夜", "咲夜",
            "魂魄妖夢", "妖夢", "レミリア", "フランドール", "フラン", "チルノ",
            "東風谷早苗", "早苗", "射命丸文", "文", "鈴仙", "うどんげ",
            "アリス", "パチュリー", "西行寺幽々子", "幽々子", "八雲紫", "紫",
            "古明地さとり", "さとり", "古明地こいし", "こいし"
        ]
        var found: [String] = []
        for c in candidateList where text.contains(c) {
            let norm = normalizeCharacterName(c)
            if !found.contains(norm) { found.append(norm) }
        }
        return found
    }

    private func normalizeCharacterName(_ name: String) -> String {
        switch name {
        case "霊夢": return "博麗霊夢"
        case "魔理沙": return "霧雨魔理沙"
        case "咲夜": return "十六夜咲夜"
        case "妖夢": return "魂魄妖夢"
        case "フラン": return "フランドール"
        case "早苗": return "東風谷早苗"
        case "文": return "射命丸文"
        case "うどんげ": return "鈴仙"
        case "幽々子": return "西行寺幽々子"
        case "紫": return "八雲紫"
        case "さとり": return "古明地さとり"
        case "こいし": return "古明地こいし"
        default: return name
        }
    }

    private func extractStage(from text: String) -> String {
        if text.contains("神社") || text.contains("縁側") { return "博麗神社" }
        if text.contains("森") || text.contains("キノコ") { return "魔法の森" }
        if text.contains("紅魔館") || text.contains("時計塔") { return "紅魔館" }
        if text.contains("冥界") || text.contains("白玉楼") { return "白玉楼" }
        if text.contains("山") || text.contains("滝") { return "妖怪の山" }
        if text.contains("地霊殿") { return "地霊殿" }
        return "幻想郷"
    }

    private func generateDynamicScript(prompt: String, mainChar: String, subChar: String, stage: String) -> String {
        var topic = "幻想郷の出来事"
        if prompt.contains("異変") || prompt.contains("弾幕") { topic = "異変の調査" }
        else if prompt.contains("お茶") || prompt.contains("お菓子") { topic = "縁側でのお茶会" }

        return """
        【東方ショートシナリオ: \(stage)における\(topic)】
        登場人物: \(mainChar)、\(subChar)

        \(mainChar)「また少し騒がしくなってきたわね。\(topic)なら手早く片付けるわよ。」
        \(subChar)「面白そうじゃないか！私も付き合うぜ！」
        """
    }

    private func generateDynamicImageAdvice(prompt: String, mainChar: String, stage: String) -> String {
        return """
        ◆ 推奨プロンプト:
        `anime style, cel shaded anime illustration, \(mainChar), touhou project, at \(stage), detailed background, volumetric lighting`
        """
    }

    private func generateDynamicSoundAdvice(prompt: String, mainChar: String, stage: String) -> String {
        return "◆ 推奨BGM構成: 155 BPM / ZUNペット主旋律＋ピアノアルペジオ（\(mainChar) モチーフ）"
    }

    private func generateDynamicCode(prompt: String, mainChar: String) -> String {
        return """
        ```javascript
        GameContext.on("PLAYER_ENCOUNTER", async () => {
            await DialogSystem.show({ speaker: "\(mainChar)", text: "ここから先は通さないわよ！" });
        });
        ```
        """
    }

    private func generateDynamicGeneralChat(prompt: String, mainChar: String, subChar: String) -> String {
        return "現在ゲートウェイサーバへ未接続のためオフライン応答モードです。「ゲートウェイ通信確認」タブから接続先（例: `http://debian.local:8095`）をご確認ください。"
    }

    private func proofreadScenario(input: String, tone: CharacterTonePreset) -> (output: String, thinking: String) {
        let lines = input.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let polished = lines.map { line -> String in
            var s = line.replacingOccurrences(of: "...", with: "……")
            if !s.contains("「") { s = "\(tone.characterName)「\(s)」" }
            return s
        }
        return (polished.joined(separator: "\n\n"), "【オフライン簡易校正】\(lines.count)行を整形しました。")
    }

    private func rewriteScenarioWithTone(input: String, tone: CharacterTonePreset) -> (output: String, thinking: String) {
        let lines = input.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let out = lines.map { "\(tone.characterName)「\($0)」" }.joined(separator: "\n\n")
        return (out, "【オフライン口調整形】\(tone.characterName) 形式へ変換しました。")
    }

    private func generateStoryboardFromPlot(input: String) -> (output: String, thinking: String, scenes: [MovieScene]) {
        let scenes = [
            MovieScene(title: "シーン1: 導入", duration: 8.0, slideTitle: "第1スライド", backgroundName: "博麗神社境内", characterName: "博麗霊夢", telop: "霊夢「また空が紅いわね…異変の予感よ」", audioTrack: "bgm_mystic_oriental.mp3"),
            MovieScene(title: "シーン2: 合流", duration: 10.0, slideTitle: "第2スライド", backgroundName: "博麗神社縁側", characterName: "霧雨魔理沙", telop: "魔理沙「霊夢！紅魔館の方から妖気を感じるぜ！」", audioTrack: "bgm_love_colored_master_spark.mp3"),
            MovieScene(title: "シーン3: 出発", duration: 10.0, slideTitle: "第3スライド", backgroundName: "幻想郷上空", characterName: "霊夢＆魔理沙", telop: "霊夢「さっさと解決しに行くわよ！」", audioTrack: "bgm_maiden_capriccio.mp3")
        ]
        let text = scenes.enumerated().map { idx, sc in
            "【シーン #\(idx + 1)】\(sc.title) (\(Int(sc.duration))秒) | \(sc.characterName) @ \(sc.backgroundName)\n\(sc.telop)"
        }.joined(separator: "\n\n")
        return (text, "【オフライン絵コンテ生成】3シーン構成を作成しました。", scenes)
    }

    private func generateCharacterPrompt(input: String, tone: CharacterTonePreset) -> (output: String, thinking: String) {
        let text = "対象キャラクター: \(tone.characterName)\n眉: 真剣 / 目: 開眼ハイライト / 口: 発声開口 / 出力: 透過PNG (1920x1080)"
        return (text, "【オフライン立ち絵指示】")
    }

    private func generateGameScript(input: String) -> (output: String, thinking: String) {
        let script = """
        // GameMaker 実行スクリプト
        GameContext.on("SPELL_TRIGGER", (ctx) => {
            ctx.playSE("se_spell_chime.wav");
            ctx.showDialog("霧雨魔理沙", "恋符『マスタースパーク』！");
        });
        """
        return (script, "【オフラインスクリプト生成】")
    }
}
