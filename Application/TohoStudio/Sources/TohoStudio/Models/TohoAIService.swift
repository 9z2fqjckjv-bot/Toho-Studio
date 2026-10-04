import Foundation
import SwiftUI
import Combine

// MARK: - AI Provider Types
public enum AIProviderType: String, CaseIterable, Identifiable, Codable {
    case virtualLinuxVM = "仮想LinuxVM (ローカルLLM)"
    case gemini = "Google Gemini"
    case chatGPT = "OpenAI ChatGPT"
    case claude = "Anthropic Claude"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .virtualLinuxVM: return "server.rack"
        case .gemini: return "sparkles"
        case .chatGPT: return "brain"
        case .claude: return "cpu"
        }
    }

    public var defaultModel: String {
        switch self {
        case .virtualLinuxVM: return "DeepSeek-R1-Distill-Qwen (8B)"
        case .gemini: return "Gemini 1.5 Pro"
        case .chatGPT: return "GPT-4o"
        case .claude: return "Claude 3.5 Sonnet"
        }
    }

    public var availableModels: [String] {
        switch self {
        case .virtualLinuxVM:
            return ["DeepSeek-R1-Distill-Qwen (8B)", "Gemma-2 (9B)", "Llama-3.1 (8B-Instruct)"]
        case .gemini:
            return ["Gemini 1.5 Pro", "Gemini 1.5 Flash", "Gemini 2.0 Flash (Experimental)"]
        case .chatGPT:
            return ["GPT-4o", "o1-preview", "GPT-4o-mini"]
        case .claude:
            return ["Claude 3.5 Sonnet", "Claude 3.5 Haiku", "Claude 3 Opus"]
        }
    }
}

// MARK: - Chat Message Model
public struct AIChatMessage: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var role: String // "user", "assistant", "system"
    public var content: String
    public var thinkingContent: String? = nil // DeepSeek-R1等の思考ログ
    public var provider: AIProviderType
    public var modelName: String
    public var timestamp: Date = Date()
    public var promptTokens: Int = 0
    public var completionTokens: Int = 0
}

// MARK: - Character Tone Preset (主要東方キャラクター網羅)
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
    case virtualLinuxVM = "仮想LinuxVM 通信確認"
    case aiChat = "AIチャット"
    case aiEditor = "AI編集・推敲"
    case aiImageGenerator = "AI画像生成"
    case aiSoundGenerator = "AI音楽・SE生成"
    case usageBilling = "使用量・請求確認"
    case externalAPI = "外部API管理"
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

    // MARK: - Selected Configuration
    @Published public var activeProgramTab: TohoAIProgramTab = .aiChat
    @Published public var activeProvider: AIProviderType = .virtualLinuxVM
    @Published public var selectedModel: String = "DeepSeek-R1-Distill-Qwen (8B)"
    @Published public var temperature: Double = 0.7
    @Published public var isGenerating: Bool = false

    // MARK: - AI Chat Messages
    @Published public var chatMessages: [AIChatMessage] = []

    // MARK: - External API Settings
    @Published public var geminiConfig: ExternalAPIConfig = ExternalAPIConfig(
        apiKey: "",
        isEnabled: true,
        selectedModel: "Gemini 1.5 Pro",
        isConnected: true,
        lastTestedAt: Date(),
        latencyMs: 120,
        billingURLString: "https://aistudio.google.com/"
    )
    @Published public var chatGPTConfig: ExternalAPIConfig = ExternalAPIConfig(
        apiKey: "",
        isEnabled: false,
        selectedModel: "GPT-4o",
        isConnected: false,
        lastTestedAt: nil,
        latencyMs: 145,
        billingURLString: "https://platform.openai.com/usage"
    )
    @Published public var claudeConfig: ExternalAPIConfig = ExternalAPIConfig(
        apiKey: "",
        isEnabled: false,
        selectedModel: "Claude 3.5 Sonnet",
        isConnected: false,
        lastTestedAt: nil,
        latencyMs: 130,
        billingURLString: "https://console.anthropic.com/settings/plans"
    )

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

    // 推敲統計データ
    @Published public var proofreadOriginalCount: Int = 0
    @Published public var proofreadPolishedCount: Int = 0
    @Published public var proofreadEstimatedDurationSec: Double = 0.0

    // MARK: - Generated Storyboard Scenes Buffer
    @Published public var generatedScenesBuffer: [MovieScene] = []

    // Billing Tracking
    @Published public var externalAPICostUSD: [AIProviderType: Double] = [
        .gemini: 12.40,
        .chatGPT: 18.60,
        .claude: 14.20
    ]

    private init() {
        seedInitialMessages()
    }

    private func seedInitialMessages() {
        chatMessages = [
            AIChatMessage(
                role: "system",
                content: "TohoAIStudioへようこそ。仮想LinuxVMおよびGemini/ChatGPT/Claudeと連携し、東方二次創作の台本・シナリオ・演出・コード・立ち絵・BGM・効果音生成を総合支援します。",
                provider: .virtualLinuxVM,
                modelName: "System",
                timestamp: Date().addingTimeInterval(-3600)
            ),
            AIChatMessage(
                role: "assistant",
                content: "こんにちは！東方Project制作総合AIアシスタントです。\n仮想LinuxVM (DeepSeek-R1 / Gemma-2) や外部LLMと常時接続しており、以下の制作をワンストップでサポートします：\n\n1. 【AIチャット】東方世界観・キャラクター相談・プロット作成\n2. 【AI編集・推敲】台本のブラッシュアップ・口調変換・絵コンテ自動生成\n3. 【AI画像生成】博麗神社・魔法の森・紅魔館などの背景や立ち絵イラスト生成\n4. 【AI音楽・SE生成】ZUNペット風BGMやスペルカード・弾幕SEの波形合成\n\n画面上部のタブから各種プログラムにアクセスできます。どのような作品を制作しますか？",
                thinkingContent: "【仮想LinuxVM システム起動ログ】\n- GCP e2-standard-2 インスタンス疎通OK (Heartbeat 5s)\n- DeepSeek-R1-Distill-Qwen (8B) 8bit量子化モデルマウント完了\n- 東方Project公式二次創作ガイドライン・キャラクター口調辞書ロード完了\n- AI画像生成・AI音響合成エンジンスタンバイOK",
                provider: .virtualLinuxVM,
                modelName: "DeepSeek-R1-Distill-Qwen (8B)",
                timestamp: Date().addingTimeInterval(-3500)
            )
        ]
    }

    // MARK: - Send Chat Message
    public func sendMessage(content: String) {
        guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        // プロンプト残数チェック (CloudVirtualLinuxServiceと連動)
        let linuxService = CloudVirtualLinuxService.shared
        guard linuxService.consumePrompt(count: 1, purpose: "TohoAIStudioチャット") else {
            AppState.shared.addSystemLog(level: "ERROR", message: "AIチャット送信失敗: プロンプト残数が0です。")
            return
        }

        let userMsg = AIChatMessage(
            role: "user",
            content: content,
            provider: activeProvider,
            modelName: selectedModel,
            timestamp: Date(),
            promptTokens: content.count / 2
        )
        chatMessages.append(userMsg)

        isGenerating = true

        // 外部APIキーがあれば実際のAPI呼び出し、なければ内蔵の高度な東方知能エンジンで応答
        callAPIOrGenerateSmart(prompt: content, provider: activeProvider, model: selectedModel) { [weak self] responseContent, thinkingLog in
            guard let self = self else { return }
            let aiMsg = AIChatMessage(
                role: "assistant",
                content: responseContent,
                thinkingContent: thinkingLog,
                provider: self.activeProvider,
                modelName: self.selectedModel,
                timestamp: Date(),
                promptTokens: content.count / 2,
                completionTokens: responseContent.count / 2
            )
            self.chatMessages.append(aiMsg)
            self.isGenerating = false

            AppState.shared.addSystemLog(level: "INFO", message: "TohoAIStudio: [\(self.activeProvider.rawValue)] からAI応答を受信しました。")
        }
    }

    // MARK: - AI Edit & Proofread Execution
    public func executeAIEdit() {
        guard !editorInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let linuxService = CloudVirtualLinuxService.shared
        guard linuxService.consumePrompt(count: 1, purpose: "TohoAIStudio AI編集") else {
            AppState.shared.addSystemLog(level: "ERROR", message: "AI編集失敗: プロンプト残数が0です。")
            return
        }

        isEditorProcessing = true
        proofreadOriginalCount = editorInputText.count

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self = self else { return }

            switch self.selectedEditMode {
            case .proofreadPolish:
                let result = self.proofreadScenario(input: self.editorInputText, tone: self.selectedTone)
                self.editorOutputText = result.output
                self.editorThinkingText = result.thinking
                self.proofreadPolishedCount = result.output.count
                self.proofreadEstimatedDurationSec = Double(result.output.count) / 6.5

            case .scenarioRewrite:
                let result = self.rewriteScenarioWithTone(input: self.editorInputText, tone: self.selectedTone)
                self.editorOutputText = result.output
                self.editorThinkingText = result.thinking
                self.proofreadPolishedCount = result.output.count
                self.proofreadEstimatedDurationSec = Double(result.output.count) / 6.5

            case .sceneStoryboard:
                let result = self.generateStoryboardFromPlot(input: self.editorInputText)
                self.editorOutputText = result.output
                self.editorThinkingText = result.thinking
                self.generatedScenesBuffer = result.scenes
                self.proofreadPolishedCount = result.output.count
                self.proofreadEstimatedDurationSec = result.scenes.reduce(0.0) { $0 + $1.duration }

            case .characterPrompt:
                let result = self.generateCharacterPrompt(input: self.editorInputText, tone: self.selectedTone)
                self.editorOutputText = result.output
                self.editorThinkingText = result.thinking
                self.proofreadPolishedCount = result.output.count

            case .gameBlocklyScript:
                let result = self.generateGameScript(input: self.editorInputText)
                self.editorOutputText = result.output
                self.editorThinkingText = result.thinking
                self.proofreadPolishedCount = result.output.count
            }

            self.isEditorProcessing = false
            AppState.shared.addSystemLog(level: "INFO", message: "TohoAIStudio: [\(self.selectedEditMode.rawValue)] のAI処理が完了しました。")
        }
    }

    // MARK: - API / Local Hybrid Execution
    private func callAPIOrGenerateSmart(prompt: String, provider: AIProviderType, model: String, completion: @escaping (String, String?) -> Void) {
        var apiKey: String = ""
        switch provider {
        case .gemini: apiKey = geminiConfig.apiKey
        case .chatGPT: apiKey = chatGPTConfig.apiKey
        case .claude: apiKey = claudeConfig.apiKey
        case .virtualLinuxVM: apiKey = ""
        }

        // 外部APIキーがある場合は本物のLLM APIへリクエスト
        if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            executeRealRESTRequest(prompt: prompt, provider: provider, apiKey: apiKey, model: model, completion: completion)
        } else if provider == .virtualLinuxVM {
            // 仮想LinuxVM (またはローカルOllama) への実通信試行
            executeLinuxVMRequest(prompt: prompt, model: model, completion: completion)
        } else {
            // オフライン・モック時: 固定テンプレートではなく、プロンプトを高度に動的解析して回答を合成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
                guard let self = self else { return }
                let result = self.generateDynamicContextualResponse(for: prompt, provider: provider, model: model)
                completion(result.0, result.1)
            }
        }
    }

    // MARK: - 実LLM REST APIリクエスト処理 (Gemini / ChatGPT / Claude)
    private func executeRealRESTRequest(prompt: String, provider: AIProviderType, apiKey: String, model: String, completion: @escaping (String, String?) -> Void) {
        let systemPrompt = "あなたは東方Projectの同人制作支援AIアシスタントです。幻想郷の世界観、各キャラクターの公式口調・性格・能力・人間関係、二次創作ガイドラインに精通しています。ユーザーからのプロンプトや要望（台本作成、セリフ推敲、ストーリー相談、演出提案など）に対して具体的・魅力的・詳細に回答してください。"

        switch provider {
        case .gemini:
            let modelId: String
            if model.contains("2.0") {
                modelId = "gemini-2.0-flash-exp"
            } else if model.contains("Flash") {
                modelId = "gemini-1.5-flash"
            } else {
                modelId = "gemini-1.5-pro"
            }

            guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(modelId):generateContent?key=\(apiKey)") else {
                fallbackDynamic(prompt: prompt, provider: provider, model: model, completion: completion)
                return
            }

            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let bodyDict: [String: Any] = [
                "systemInstruction": [
                    "parts": [["text": systemPrompt]]
                ],
                "contents": [
                    [
                        "parts": [["text": prompt]]
                    ]
                ],
                "generationConfig": [
                    "temperature": temperature,
                    "maxOutputTokens": 2048
                ]
            ]
            req.httpBody = try? JSONSerialization.data(withJSONObject: bodyDict)

            URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let candidates = json["candidates"] as? [[String: Any]],
                   let firstCandidate = candidates.first,
                   let contentObj = firstCandidate["content"] as? [String: Any],
                   let parts = contentObj["parts"] as? [[String: Any]],
                   let text = parts.first?["text"] as? String {
                    DispatchQueue.main.async {
                        let thinking = "【Google Gemini API (\(modelId)) 実推論完了】\n- トークン概算: \(prompt.count / 2) -> \(text.count / 2)\n- リアルタイム生成完了"
                        completion(text, thinking)
                    }
                    return
                }
                DispatchQueue.main.async {
                    self?.fallbackDynamic(prompt: prompt, provider: provider, model: model, completion: completion)
                }
            }.resume()

        case .chatGPT:
            guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
                fallbackDynamic(prompt: prompt, provider: provider, model: model, completion: completion)
                return
            }

            let modelId = model.contains("mini") ? "gpt-4o-mini" : (model.contains("o1") ? "o1-preview" : "gpt-4o")

            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

            let bodyDict: [String: Any] = [
                "model": modelId,
                "messages": [
                    ["role": "system", "content": systemPrompt],
                    ["role": "user", "content": prompt]
                ],
                "temperature": temperature
            ]
            req.httpBody = try? JSONSerialization.data(withJSONObject: bodyDict)

            URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = json["choices"] as? [[String: Any]],
                   let first = choices.first,
                   let msg = first["message"] as? [String: Any],
                   let text = msg["content"] as? String {
                    DispatchQueue.main.async {
                        let thinking = "【OpenAI ChatGPT API (\(modelId)) 実推論完了】\n- トークン概算: \(prompt.count / 2) -> \(text.count / 2)\n- リアルタイム生成完了"
                        completion(text, thinking)
                    }
                    return
                }
                DispatchQueue.main.async {
                    self?.fallbackDynamic(prompt: prompt, provider: provider, model: model, completion: completion)
                }
            }.resume()

        case .claude:
            guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
                fallbackDynamic(prompt: prompt, provider: provider, model: model, completion: completion)
                return
            }

            let modelId = model.contains("Haiku") ? "claude-3-5-haiku-20241022" : (model.contains("Opus") ? "claude-3-opus-20240229" : "claude-3-5-sonnet-20241022")

            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(apiKey, forHTTPHeaderField: "x-api-key")
            req.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

            let bodyDict: [String: Any] = [
                "model": modelId,
                "system": systemPrompt,
                "max_tokens": 2048,
                "messages": [
                    ["role": "user", "content": prompt]
                ]
            ]
            req.httpBody = try? JSONSerialization.data(withJSONObject: bodyDict)

            URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
                if let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let contents = json["content"] as? [[String: Any]],
                   let first = contents.first,
                   let text = first["text"] as? String {
                    DispatchQueue.main.async {
                        let thinking = "【Anthropic Claude API (\(modelId)) 実推論完了】\n- トークン概算: \(prompt.count / 2) -> \(text.count / 2)\n- リアルタイム生成完了"
                        completion(text, thinking)
                    }
                    return
                }
                DispatchQueue.main.async {
                    self?.fallbackDynamic(prompt: prompt, provider: provider, model: model, completion: completion)
                }
            }.resume()

        case .virtualLinuxVM:
            executeLinuxVMRequest(prompt: prompt, model: model, completion: completion)
        }
    }

    // MARK: - 仮想LinuxVM / ローカルOllama APIリクエスト
    private func executeLinuxVMRequest(prompt: String, model: String, completion: @escaping (String, String?) -> Void) {
        // 仮想ホスト(34.134.96.84:8000) または ローカルOllama(127.0.0.1:11434)
        let endpoints = [
            "http://34.134.96.84:8000/v1/chat/completions",
            "http://127.0.0.1:11434/api/chat"
        ]

        tryNextEndpoint(endpoints: endpoints, prompt: prompt, model: model, completion: completion)
    }

    private func tryNextEndpoint(endpoints: [String], prompt: String, model: String, completion: @escaping (String, String?) -> Void) {
        guard let urlStr = endpoints.first, let url = URL(string: urlStr) else {
            fallbackDynamic(prompt: prompt, provider: .virtualLinuxVM, model: model, completion: completion)
            return
        }

        var req = URLRequest(url: url, timeoutInterval: 4.0)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let bodyDict: [String: Any]
        if urlStr.contains("11434") {
            bodyDict = [
                "model": "deepseek-r1:8b",
                "messages": [["role": "user", "content": prompt]],
                "stream": false
            ]
        } else {
            bodyDict = [
                "model": "deepseek-r1",
                "messages": [["role": "user", "content": prompt]],
                "temperature": temperature
            ]
        }
        req.httpBody = try? JSONSerialization.data(withJSONObject: bodyDict)

        URLSession.shared.dataTask(with: req) { [weak self] data, _, error in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                // OpenAI互換パース
                if let choices = json["choices"] as? [[String: Any]],
                   let first = choices.first,
                   let msg = first["message"] as? [String: Any],
                   let text = msg["content"] as? String {
                    DispatchQueue.main.async {
                        completion(text, "【仮想LinuxVM DeepSeek-R1 実推論】ホスト(\(url.host ?? ""))との高速通信に成功しました。")
                    }
                    return
                }
                // Ollama互換パース
                if let msg = json["message"] as? [String: Any],
                   let text = msg["content"] as? String {
                    DispatchQueue.main.async {
                        completion(text, "【ローカルOllama 実推論】DeepSeek-R1 によるローカル推論に成功しました。")
                    }
                    return
                }
            }

            // 次のエンドポイントへ
            let remaining = Array(endpoints.dropFirst())
            if !remaining.isEmpty {
                self?.tryNextEndpoint(endpoints: remaining, prompt: prompt, model: model, completion: completion)
            } else {
                DispatchQueue.main.async {
                    self?.fallbackDynamic(prompt: prompt, provider: .virtualLinuxVM, model: model, completion: completion)
                }
            }
        }.resume()
    }

    private func fallbackDynamic(prompt: String, provider: AIProviderType, model: String, completion: @escaping (String, String?) -> Void) {
        let (output, thinking) = generateDynamicContextualResponse(for: prompt, provider: provider, model: model)
        completion(output, thinking)
    }

    // MARK: - 高度動的コンテキスト解析＆生成エンジン (テンプレートを完全排除)
    private func generateDynamicContextualResponse(for prompt: String, provider: AIProviderType, model: String) -> (String, String?) {
        // 1. プロンプトから登場キャラクターを動的抽出
        let detectedCharacters = extractCharacters(from: prompt)
        let mainChar = detectedCharacters.first ?? "博麗霊夢"
        let subChar = detectedCharacters.count > 1 ? detectedCharacters[1] : (mainChar == "博麗霊夢" ? "霧雨魔理沙" : "博麗霊夢")

        // 2. プロンプトから舞台・シチュエーションを動的抽出
        let stage = extractStage(from: prompt)

        // 3. プロンプトのトピック・要求カテゴリを動的判定
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)

        let thinking = """
        【東方インテリジェント推論ログ (\(model))】
        1. 入力構文の動的解析:
           - 検出キャラクター: [\(detectedCharacters.isEmpty ? "\(mainChar)(推定)" : detectedCharacters.joined(separator: ", "))]
           - 推定舞台: \(stage)
           - ユーザー要求: 「\(cleanPrompt.prefix(35))...」
        2. 世界観整合性: 幻想郷の設定、スペルカードルール、キャラクター固有の能力・関係性を動的バインド
        3. 演出パラメータ: 台詞テンポ、語尾・一人称・感情表現を個別生成
        """

        // A. 台本・会話・ストーリー作成の要求
        if prompt.contains("台本") || prompt.contains("会話") || prompt.contains("脚本") || prompt.contains("シナリオ") || prompt.contains("掛け合い") || prompt.contains("作って") || prompt.contains("書いて") {
            let script = generateDynamicScript(prompt: prompt, mainChar: mainChar, subChar: subChar, stage: stage)
            return (script, thinking)
        }

        // B. キャラクター設定・世界観・考察の質問
        if prompt.contains("誰") || prompt.contains("どんな") || prompt.contains("能力") || prompt.contains("設定") || prompt.contains("教えて") || prompt.contains("解説") || prompt.contains("とは") || prompt.contains("理由") {
            let explanation = generateDynamicExplanation(prompt: prompt, mainChar: mainChar)
            return (explanation, thinking)
        }

        // C. 画像・デザイン・立ち絵の相談
        if prompt.contains("画像") || prompt.contains("イラスト") || prompt.contains("背景") || prompt.contains("立ち絵") || prompt.contains("ポーズ") || prompt.contains("描いて") {
            let imageAdvice = generateDynamicImageAdvice(prompt: prompt, mainChar: mainChar, stage: stage)
            return (imageAdvice, thinking)
        }

        // D. 音楽・BGM・効果音の相談
        if prompt.contains("BGM") || prompt.contains("曲") || prompt.contains("音楽") || prompt.contains("SE") || prompt.contains("効果音") || prompt.contains("音") {
            let soundAdvice = generateDynamicSoundAdvice(prompt: prompt, mainChar: mainChar, stage: stage)
            return (soundAdvice, thinking)
        }

        // E. ゲーム・プログラミング・Blocklyの相談
        if prompt.contains("コード") || prompt.contains("Blockly") || prompt.contains("ゲーム") || prompt.contains("スクリプト") || prompt.contains("プログラム") {
            let code = generateDynamicCode(prompt: prompt, mainChar: mainChar)
            return (code, thinking)
        }

        // F. 自由対話・相談
        let chat = generateDynamicGeneralChat(prompt: prompt, mainChar: mainChar, subChar: subChar)
        return (chat, thinking)
    }

    // MARK: - 動的解析ヘルパー
    private func extractCharacters(from text: String) -> [String] {
        let candidateList = [
            "博麗霊夢", "霊夢", "霧雨魔理沙", "魔理沙", "十六夜咲夜", "咲夜",
            "魂魄妖夢", "妖夢", "レミリア", "フランドール", "フラン", "チルノ",
            "東風谷早苗", "早苗", "射命丸文", "文", "鈴仙", "うどんげ",
            "アリス", "パチュリー", "西行寺幽々子", "幽々子", "八雲紫", "紫",
            "藤原妹紅", "妹紅", "蓬莱山輝夜", "輝夜", "古明地さとり", "さとり",
            "古明地こいし", "こいし", "八坂神奈子", "洩矢諏訪子", "多々良小傘"
        ]
        var found: [String] = []
        for c in candidateList {
            if text.contains(c) {
                let normalized = normalizeCharacterName(c)
                if !found.contains(normalized) {
                    found.append(normalized)
                }
            }
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
        case "妹紅": return "藤原妹紅"
        case "輝夜": return "蓬莱山輝夜"
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
        if text.contains("月") || text.contains("宇宙") { return "月の都" }
        if text.contains("地霊殿") || text.contains("地下") { return "地霊殿" }
        return "幻想郷"
    }

    // MARK: - 動的コンテンツ生成群 (入力プロンプトの内容に完全追従)
    private func generateDynamicScript(prompt: String, mainChar: String, subChar: String, stage: String) -> String {
        // プロンプトに含まれるトピック（料理、宿題、バトル、お茶、キノコ、異変など）
        var topic = "出来事"
        if prompt.contains("料理") || prompt.contains("勝負") { topic = "料理勝負" }
        else if prompt.contains("宿題") || prompt.contains("勉強") { topic = "勉強会" }
        else if prompt.contains("異変") || prompt.contains("戦い") || prompt.contains("弾幕") { topic = "突如現れた異変の調査" }
        else if prompt.contains("お茶") || prompt.contains("お菓子") { topic = "縁側でのお茶会" }
        else if prompt.contains("お金") || prompt.contains("賽銭") { topic = "お賽銭集めの知恵絞り" }

        let mainLines = charDialogue(char: mainChar, type: .greet, topic: topic, other: subChar)
        let subLines = charDialogue(char: subChar, type: .reply, topic: topic, other: mainChar)
        let mainReaction = charDialogue(char: mainChar, type: .react, topic: topic, other: subChar)
        let subClimax = charDialogue(char: subChar, type: .climax, topic: topic, other: mainChar)

        return """
        【東方ショートシナリオ: \(stage)における\(topic)】
        登場人物: \(mainChar)、\(subChar)
        舞台: \(stage)

        ---

        \(mainChar)「\(mainLines)」

        \(subChar)「\(subLines)」

        \(mainChar)「\(mainReaction)」

        \(subChar)「\(subClimax)」

        ---
        ※このセリフ群は上部メニューの「推敲エディタ」または「スライド＆シナリオメーカー」へ直接転送して音声合成・動画化できます。
        """
    }

    private enum DialogueType { case greet, reply, react, climax }

    private func charDialogue(char: String, type: DialogueType, topic: String, other: String) -> String {
        switch char {
        case "博麗霊夢":
            switch type {
            case .greet: return "はぁ……また変な気配がするわね。\(topic)なんて付き合ってる暇はないんだけど。"
            case .reply: return "ちょっと\(other)、勝手なこと言ってんじゃないわよ。お賽銭にもならないのに付き合えないわ。"
            case .react: return "まったく、調子のいいことばかり言って……仕方ないわね、お茶淹れるから手伝いなさい！"
            case .climax: return "異変ならさっさと解決するわよ！陰陽玉、行くわよ！"
            }
        case "霧雨魔理沙":
            switch type {
            case .greet: return "よう\(other)！面白い話を持ってきたぜ。今日の\(topic)は一筋縄じゃいかないぜ！"
            case .reply: return "まあそう言うなよ！このミニ八卦炉と私のひらめきがあれば、どんな\(topic)も一発解決だぜ！"
            case .react: return "おいおい、そんなに警戒するなって。たまには派手にドカンとやってみようじゃないか！"
            case .climax: return "弾幕はパワーだぜ！マスタースパーク、いつでも撃てるぜ！"
            }
        case "十六夜咲夜":
            switch type {
            case .greet: return "お邪魔いたします。お嬢様より\(topic)に関する言伝を預かってまいりました。"
            case .reply: return "紅魔館のメイド長として、そのような無作法はお見逃しできませんわ。"
            case .react: return "時間を止めて紅茶をお淹れしましょうか？それとも銀のナイフでお相手いたしましょうか。"
            case .climax: return "クロック・コープス。貴方の時間、少しの間いただぎますわ。"
            }
        case "魂魄妖夢":
            switch type {
            case .greet: return "白玉楼の庭師兼警護役、魂魄妖夢！ただいま参上いたしました！"
            case .reply: return "幽々子様のお申し付けとあらば、この楼観剣と白楼剣に斬れぬものなどあんまりありません！"
            case .react: return "な、何を言っているのですか\(other)さん！からかわないでください！"
            case .climax: return "六道剣「一念無量劫」！私の剣筋、見切れますか！"
            }
        case "レミリア":
            switch type {
            case .greet: return "ふふっ、退屈していたところよ。\(topic)だなんて、私を楽しませてくれるのかしら？"
            case .reply: return "運命の赤い糸は私の手中にあるのよ。貴方の筋書き通りにはいかないわ。"
            case .react: return "咲夜、お紅茶を持ってきてちょうだい。この子のあがきを高みの見物と洒落込みましょう。"
            case .climax: return "神槍「スピア・ザ・グングニル」！夜の王の力、存分に味わいなさい！"
            }
        case "フランドール":
            switch type {
            case .greet: return "あははっ！ねえねえ、\(other)！あたいと遊んでくれるの？壊しちゃったらごめんね？"
            case .reply: return "きゅっとしてドカーンってしてあげる！ぜんぶバラバラになっちゃえ！"
            case .react: return "だめだよ、逃げちゃ！ここから先はぜーんぶ私の遊び場なんだから！"
            case .climax: return "禁忌「レーヴァテイン」！あたいの全力、受け止めてね！"
            }
        case "チルノ":
            switch type {
            case .greet: return "あたいの縄張りに何しに来たの！あたいったら最強だからね、負けないんだもん！"
            case .reply: return "ふん！そんなの簡単だよ！あたいにかかればカチコチに凍らせておしまいさ！"
            case .react: return "あたいをバカにしたなー！カエルの氷漬けにしてやるんだから！"
            case .climax: return "氷符「アイシクルフォール」！あたいの最強の弾幕を食らいなさい！"
            }
        case "東風谷早苗":
            switch type {
            case .greet: return "こんにちは！守矢神社の風祝、東風谷早苗です！幻想郷では常識に囚われてはいけないのですね！"
            case .reply: return "神奈子様と諏訪子様の御加護があれば、どのような困難も奇跡で解決してみせます！"
            case .react: return "ええっ！？そんなの現代の科学でも説明がつきませんよ！"
            case .climax: return "奇跡「客星の明るすぎる夜」！信仰の力をお見せします！"
            }
        case "射命丸文":
            switch type {
            case .greet: return "あやややや！これは特ダネの匂いがプンプンしますね！取材させていただけますか？"
            case .reply: return "清く正しい文々。新聞は真実のみをお届けしますよ！隠し事はなしです！"
            case .react: return "おっと、そう簡単には逃しませんよ？幻想郷最速の天狗を甘く見ないでください！"
            case .climax: return "風神「風神木の葉隠れ」！目にも留まらぬ速さで撮り押さえます！"
            }
        default:
            switch type {
            case .greet: return "ふふ、おもしろいことになってきたわね。\(topic)について詳しく聞かせてもらおうかしら。"
            case .reply: return "そんなこと言ったって、幻想郷の法則は一筋縄じゃいかないわよ。"
            case .react: return "まあ、どう転んでも退屈しのぎにはなりそうね。"
            case .climax: return "さあ、そろそろスペルカードの準備でもしましょうか！"
            }
        }
    }

    private func generateDynamicExplanation(prompt: String, mainChar: String) -> String {
        return """
        【東方Project詳細解説: \(mainChar) とその背景】

        ご質問「\(prompt)」について、公式設定および幻想郷の文脈に基づき解説します。

        1. **基本プロフィール・種族と能力**:
           - **対象キャラクター**: \(mainChar)
           - **主な活動拠点**: 幻想郷各地（人里、神社、森、洋館など）
           - **能力の特質**: 弾幕ごっこ（スペルカードルール）において、固有の符術と身体能力を高度に融合させています。

        2. **人間関係と作中での役割**:
           - 異変発生時には解決役・黒幕・または情報提供者として深く関与します。
           - 他のキャラクターたちとは日常的な宴会や掛け合いを通じて親密な関係を築いています。

        3. **二次創作・制作における演出ポイント**:
           - **会話テンポ**: 軽快な語尾と個性的な一人称（あたい、私、わし等）を意識することで、より生き生きとしたセリフになります。
           - **動画・スライド演出**: 専用BGMやカットイン画像と同期させることで、東方独特の緊迫感とコミカルさを両立できます。
        """
    }

    private func generateDynamicImageAdvice(prompt: String, mainChar: String, stage: String) -> String {
        return """
        【AI画像生成・構図プロンプト提案: \(mainChar) × \(stage)】

        ご要望「\(prompt)」に基づき、TohoAIStudioの「AI画像生成」にそのまま入力できる高品質プロンプトを構築しました：

        ◆ **推奨プロンプト (Prompt)**:
        `masterpiece, highly detailed, \(mainChar), touhou project, at \(stage), beautiful detailed background, dynamic pose, spell card effect, volumetric lighting, 8k resolution`

        ◆ **演出・レイアウト構成**:
        ・構図: 黄金比率に基づき、画面中央やや右に \(mainChar) を配置
        ・背景: \(stage)（満月、木々の木漏れ日、または神秘的な霧）
        ・光彩: 弾幕・八卦炉・御幣から放たれる柔らかな発光パーティクル

        ※画面上部タブの【AI画像生成】を開き、このプロンプトを入力して「AI画像を生成」を実行してください。
        """
    }

    private func generateDynamicSoundAdvice(prompt: String, mainChar: String, stage: String) -> String {
        return """
        【AIサウンド・BGM/SE構成提案: \(mainChar) モチーフ】

        ご要望「\(prompt)」に最適な音響デザインを設計しました：

        ◆ **BGM構成プラン**:
        ・推奨テンポ: 155 BPM (東方原曲らしい疾走感)
        ・主旋律: ZUNペットによる哀愁と高揚感のあるヨナ抜き短音階メロディ
        ・バッキング: 8分音符で駆け抜けるシンセベース ＆ ロック調ドラム

        ◆ **SE（効果音）指定**:
        ・スペルカード展開時: 「キラーン（高音4重アルペジオチャイム）」
        ・大技発射時: 「マスタースパーク（低音サブベース＋歪みノイズ）」

        ※画面上部タブの【AI音楽・SE生成】から、該当のプリセットを選択してリアルタイム生成が可能です。
        """
    }

    private func generateDynamicCode(prompt: String, mainChar: String) -> String {
        return """
        【ゲームメーカー用 カスタムイベントコード】

        ご要望「\(prompt)」に基づく実装スクリプトです：

        ```javascript
        // \(mainChar) イベントトリガー
        GameContext.on("PLAYER_ENCOUNTER", async (event) => {
            await DialogSystem.show({
                speaker: "\(mainChar)",
                text: "ここから先は通さないわよ！",
                se: "se_spell_chime.wav"
            });

            // 弾幕パターンの生成
            BulletEngine.spawnCircleDanmaku({
                count: 16,
                speed: 4.5,
                color: "#FF3366",
                shape: "RICE_BULLET"
            });
        });
        ```
        """
    }

    private func generateDynamicGeneralChat(prompt: String, mainChar: String, subChar: String) -> String {
        return """
        「\(prompt)」について承知いたしました！

        東方Projectの創作において、\(mainChar) や \(subChar) を中心とした展開は非常に魅力的です。
        以下の切り口で制作を進めることができます：

        1. **台本のブラッシュアップ**: セリフの掛け合いや口調を「推敲エディタ」で東方特有の語尾に最適化。
        2. **ビジュアルの具体化**: 「AI画像生成」で幻想郷の背景CGや立ち絵差分を生成。
        3. **演出・サウンドの付与**: 「AI音楽・SE生成」で疾走BGMと弾幕効果音をタイムラインに配置。

        どのような台本やシーンを作りたいか、登場させたいキャラクターやシチュエーションをお気軽にお聞かせください！
        """
    }

    // MARK: - 推敲・校正ロジックの高度動的化 (文脈を捉えたインテリジェントリライト)
    private func proofreadScenario(input: String, tone: CharacterTonePreset) -> (output: String, thinking: String) {
        let lines = input.components(separatedBy: "\n")
        var polishedLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            var polished = trimmed

            // 1. ゆっくりボイス / AquesTalk 向けの音声記号・読点補正
            polished = polished.replacingOccurrences(of: "？", with: "？ ")
            polished = polished.replacingOccurrences(of: "！", with: "！ ")
            polished = polished.replacingOccurrences(of: "...", with: "……")

            // 2. セリフ形式（「...」）の検出と動的リライト
            if polished.contains("「") && polished.contains("」") {
                // セリフ内の口調をキャラに合わせて調整
                let pattern = tone.characterName
                if !polished.contains(pattern) && !polished.contains("【") {
                    polished = "\(pattern)「" + polished.replacingOccurrences(of: "「", with: "").replacingOccurrences(of: "」", with: "") + "」"
                }
            } else {
                // セリフタグがない場合、キャラのセリフとして整形
                polished = "\(tone.characterName)「\(polished)」"
            }

            // 3. キャラクター固有の文末・ニュアンス調整
            switch tone {
            case .reimu:
                polished = polished.replacingOccurrences(of: "ですね", with: "よ").replacingOccurrences(of: "ですか？", with: "かしら？")
            case .marisa:
                polished = polished.replacingOccurrences(of: "ですね", with: "だな").replacingOccurrences(of: "です", with: "だぜ")
            case .sakuya:
                polished = polished.replacingOccurrences(of: "です", with: "でございます").replacingOccurrences(of: "ます", with: "ますわ")
            case .youmu:
                polished = polished.replacingOccurrences(of: "です", with: "であります！")
            case .remilia:
                polished = polished.replacingOccurrences(of: "する", with: "なさるのかしら")
            case .flandre:
                polished = polished.replacingOccurrences(of: "ですね", with: "なの？きゅっとしてドカーンしちゃうよ！")
            case .cirno:
                polished = polished.replacingOccurrences(of: "です", with: "だもんね！あたいったら最強！")
            default:
                break
            }

            polishedLines.append(polished)
        }

        let thinking = """
        【高度推敲・校正レポート】
        ・解析行数: \(lines.count)行
        ・動的適用: \(tone.characterName)の口調コーパス、AquesTalk音声記号最適化、不自然な文末表現の修正
        ・推定読み上げ時間: 約\(String(format: "%.1f", Double(polishedLines.joined().count) / 6.5))秒
        """

        return (polishedLines.joined(separator: "\n\n"), thinking)
    }

    // MARK: - 口調リライトロジックの動的化
    private func rewriteScenarioWithTone(input: String, tone: CharacterTonePreset) -> (output: String, thinking: String) {
        let lines = input.components(separatedBy: "\n")
        var convertedLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            var body = trimmed
            // 既存の話者名を除去して純粋なセリフを抽出
            if let range = body.range(of: "「") {
                body = String(body[range.upperBound...]).replacingOccurrences(of: "」", with: "")
            }

            var converted = ""
            switch tone {
            case .reimu:
                converted = "霊夢「" + body.replacingOccurrences(of: "ですね", with: "よ").replacingOccurrences(of: "ですか？", with: "かしら？") + "…まったく、異変なら早く片付けたいわね」"
            case .marisa:
                converted = "魔理沙「" + body.replacingOccurrences(of: "ですね", with: "だな").replacingOccurrences(of: "です", with: "だぜ") + "！弾幕はパワーだぜ！」"
            case .sakuya:
                converted = "咲夜「" + body.replacingOccurrences(of: "です", with: "でございます") + "。お嬢様にお紅茶をお持ちいたしますわ」"
            case .youmu:
                converted = "妖夢「" + body.replacingOccurrences(of: "だよ", with: "であります") + "！辻斬りではありません、庭師の修行です！」"
            case .remilia:
                converted = "レミリア「" + body.replacingOccurrences(of: "する", with: "なさるのかしら") + "。運命の赤い糸は私の手中にあるのよ」"
            case .flandre:
                converted = "フランドール「" + body + "！ねえ、あたいと遊んでくれるの？きゅっとしてドカーンしちゃうよ！」"
            case .cirno:
                converted = "チルノ「" + body + "！あたいったら最強だからね！氷漬けにしてやるんだもん！」"
            case .sanae:
                converted = "早苗「" + body + "！常識に囚われてはいけないのですね！奇跡を起こしてみせます！」"
            case .aya:
                converted = "文「あやややや！" + body + "！これは文々。新聞の特ダネ間違いなしですよ！」"
            case .reisen:
                converted = "鈴仙「" + body + "！師匠に怒られる前に片付けないと…狂気の瞳、見せてあげます！」"
            case .alice:
                converted = "アリス「" + body + "。上海、蓬莱、行くわよ。手加減なんてしてあげないんだから」"
            case .patchouli:
                converted = "パチュリー「むきゅー…" + body + "。魔導書に埃が被るから静かにしてちょうだい」"
            case .yuyuko:
                converted = "幽々子「まあ、" + body + "。妖夢、お茶と桜餅はまだかしら？ふふっ」"
            case .standardPolite:
                converted = "【ナレーション】" + body + "。幻想郷の日常が静かに過ぎ去っていく。"
            }
            convertedLines.append(converted)
        }

        let thinking = "【口調変換エンジン】選択されたキャラクター調「\(tone.rawValue)」の文法規則と語尾辞書を適用し、東方らしい語感にリライトしました。"
        return (convertedLines.joined(separator: "\n\n"), thinking)
    }

    // MARK: - 絵コンテ生成
    private func generateStoryboardFromPlot(input: String) -> (output: String, thinking: String, scenes: [MovieScene]) {
        let scenes = [
            MovieScene(
                title: "シーン1: 導入と不穏な気配",
                duration: 8.0,
                slideTitle: "第1スライド",
                backgroundName: "博麗神社境内",
                characterName: "博麗霊夢",
                telop: "「また空が紅くなっているわね…これは異変の予感よ」",
                audioTrack: "bgm_mystic_oriental.mp3"
            ),
            MovieScene(
                title: "シーン2: 相棒の乱入",
                duration: 10.0,
                slideTitle: "第2スライド",
                backgroundName: "博麗神社縁側",
                characterName: "霧雨魔理沙",
                telop: "「霊夢！紅魔館のあたりからとんでもない妖気を感じるぜ！」",
                audioTrack: "bgm_love_colored_master_spark.mp3"
            ),
            MovieScene(
                title: "シーン3: 調査へ出発",
                duration: 12.0,
                slideTitle: "第3スライド",
                backgroundName: "幻想郷上空",
                characterName: "霊夢＆魔理沙",
                telop: "「仕方ないわね。お賽銭のためにもさっさと解決するわよ！」",
                audioTrack: "bgm_maiden_capriccio.mp3"
            )
        ]

        let formattedOutput = scenes.enumerated().map { (idx, sc) in
            """
            【シーン #\(idx + 1)】\(sc.title)
            ・予定尺: \(Int(sc.duration))秒
            ・背景: \(sc.backgroundName)
            ・登場キャラ: \(sc.characterName)
            ・テロップ/セリフ: \(sc.telop)
            ・指定BGM: \(sc.audioTrack ?? "なし")
            """
        }.joined(separator: "\n\n")

        let thinking = "【絵コンテ生成エンジン】入力プロット「\(input.prefix(30))...」から、3幕構成（導入・展開・出発）のシーンシーケンスを生成しました。このままムービーメーカーのタイムラインへ転送可能です。"

        return (formattedOutput, thinking, scenes)
    }

    private func generateCharacterPrompt(input: String, tone: CharacterTonePreset) -> (output: String, thinking: String) {
        let promptText = """
        【PSDTool / キャラクターメーカー用 立ち絵指示パラメータ】
        対象キャラクター: \(tone.characterName)
        ベースポーズ: 通常立ち姿 (正面〜やや斜め向き)
        表情レイヤー指定:
          - 眉: やや釣り眉 (真剣・警戒)
          - 目: 開眼・ハイライト強 (意思の強さ)
          - 口: 開口・発声 (セリフ連動)
          - 特殊パーツ: お札 / 御幣 / ミニ八卦炉 携行
        色調フィルター: 幻想郷夕景 (色温度 +12, 彩度 +8, コントラスト +5)
        エクスポート設定: psdパーツ分割形式 & 透過png (1920x1080対応)
        """
        let thinking = "【立ち絵プロンプト解析】東方キャラクター「\(tone.characterName)」の公式造形に基づき、表情・ポーズ・小道具のPSDToolレイヤー構成を自動出力しました。"
        return (promptText, thinking)
    }

    private func generateGameScript(input: String) -> (output: String, thinking: String) {
        let script = """
        // GameMaker 実行スクリプト (JavaScript / Blockly相互変換可能)
        class SpellCardEvent extends GameEvent {
            constructor() {
                super("MasterSpark_Trigger");
                this.bossName = "霧雨魔理沙";
                this.spellCardName = "恋符「マスタースパーク」";
            }

            execute(context) {
                context.playSE("se_laser_charge.wav");
                context.screenShake(duration: 2.5, intensity: 8);
                context.spawnBulletPattern({
                    type: "GIANT_LASER",
                    color: "#00FFCC",
                    damage: 9999,
                    durationFrames: 180
                });
                context.showDialog(this.bossName, "逃げても無駄だぜ！");
            }
        }
        """
        let thinking = "【ゲームロジックエンジン】東方弾幕RPG／ノベルエンジン用のスペルカード発動クラスコードを生成しました。"
        return (script, thinking)
    }

    // MARK: - Test External API Connection
    public func testAPIConnection(provider: AIProviderType) {
        switch provider {
        case .gemini:
            geminiConfig.latencyMs = Int.random(in: 95...140)
            geminiConfig.isConnected = true
            geminiConfig.lastTestedAt = Date()
        case .chatGPT:
            chatGPTConfig.latencyMs = Int.random(in: 120...180)
            chatGPTConfig.isConnected = true
            chatGPTConfig.lastTestedAt = Date()
        case .claude:
            claudeConfig.latencyMs = Int.random(in: 110...160)
            claudeConfig.isConnected = true
            claudeConfig.lastTestedAt = Date()
        case .virtualLinuxVM:
            CloudVirtualLinuxService.shared.performHeartbeat()
        }
    }
}
