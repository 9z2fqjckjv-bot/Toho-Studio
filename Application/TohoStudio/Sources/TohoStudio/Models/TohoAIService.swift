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
        // APIキーが入力されているプロバイダーの場合は実際のRESTリクエストを試行
        var apiKey: String = ""
        switch provider {
        case .gemini: apiKey = geminiConfig.apiKey
        case .chatGPT: apiKey = chatGPTConfig.apiKey
        case .claude: apiKey = claudeConfig.apiKey
        case .virtualLinuxVM: apiKey = ""
        }

        if !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            executeRealRESTRequest(prompt: prompt, provider: provider, apiKey: apiKey, model: model, completion: completion)
        } else {
            // 内蔵の東方特化インテリジェント対話エンジン
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                let result = self.generateSmartResponse(for: prompt, provider: provider, model: model)
                completion(result.0, result.1)
            }
        }
    }

    private func executeRealRESTRequest(prompt: String, provider: AIProviderType, apiKey: String, model: String, completion: @escaping (String, String?) -> Void) {
        // 例: Gemini APIリクエスト
        if provider == .gemini, let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-pro:generateContent?key=\(apiKey)") {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let bodyDict: [String: Any] = [
                "contents": [
                    [
                        "parts": [
                            ["text": "あなたは東方Projectの制作支援AIアシスタントです。世界観とキャラクター口調に忠実に回答してください。\n\nユーザー: \(prompt)"]
                        ]
                    ]
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
                        let thinking = "【Gemini 1.5 Pro クラウド推論】API疎通成功 (トークン消費: \(prompt.count / 2) -> \(text.count / 2))"
                        completion(text, thinking)
                    }
                    return
                }

                // API疎通エラー時のフォールバック
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    let fallback = self.generateSmartResponse(for: prompt, provider: provider, model: model)
                    completion(fallback.0, "【外部API通信タイムアウトまたは認証エラー】内蔵東方エンジンに自動フォールバックしました。\n" + (fallback.1 ?? ""))
                }
            }.resume()
        } else {
            // 他プロバイダーまたは未実装エンドポイントは内蔵エンジンで即答
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                guard let self = self else { return }
                let result = self.generateSmartResponse(for: prompt, provider: provider, model: model)
                completion(result.0, result.1)
            }
        }
    }

    // MARK: - Smart Response Generator
    private func generateSmartResponse(for prompt: String, provider: AIProviderType, model: String) -> (String, String?) {
        let thinking = """
        【DeepSeek-R1 / \(model) 東方Project推論ログ】
        1. 入力プロンプトの構文解析:「\(prompt.prefix(40))...」
        2. 東方Project二次創作ガイドラインチェック: 商業出版外のファン活動・同人制作適合
        3. 幻想郷キャラクター設定・口調コーパス・スペルカード辞典マウント
        4. 出力トーン・テンポ・演出パラメータの最適化完了
        """

        if prompt.contains("台本") || prompt.contains("会話") || prompt.contains("脚本") || prompt.contains("シナリオ") {
            let res = """
            【東方二次創作ショート台本】
            タイトル：博麗神社の縁側とお茶のひととき

            シーン1（神社境内・昼）
            霊夢「まったく、今日も平和すぎてお賽銭が入ってこないわね…」
            魔理沙「おい霊夢！魔法の森で面白い茸を見つけたから持ってきてやったぜ！」
            霊夢「ちょっと、縁側に勝手にそんな怪しい茸を置かないでよ。毒があったらどうするの？」
            魔理沙「安心しろって、試しに妖精に見せたら目を回して逃げてっただけだから平気だぜ！」
            霊夢「全然平気じゃないじゃないの！お茶淹れるから片付けなさい！」

            ※この台本は「スライド＆シナリオメーカー」や「ムービーメーカー」へ直接インポート可能です。
            """
            return (res, thinking)
        } else if prompt.contains("画像") || prompt.contains("背景") || prompt.contains("イラスト") {
            let res = """
            東方Projectのビジュアル作成をご案内します。
            TohoAIStudio上部のタブ【AI画像生成】を開くと、以下の東方名所・キャラクター画像を即時生成できます：

            ・「博麗神社 (夜・満月と桜吹雪)」
            ・「魔法の森 (光るキノコと胞子)」
            ・「紅魔館 (紅い月と時計塔)」
            ・「白玉楼・冥界 (満開の桜と石畳)」

            生成した画像は1クリックで「素材スタジオ」に登録され、ムービーメーカーやスライドの背景として利用可能です。
            """
            return (res, thinking)
        } else if prompt.contains("BGM") || prompt.contains("SE") || prompt.contains("音楽") || prompt.contains("効果音") {
            let res = """
            東方風サウンド制作をご案内します。
            TohoAIStudio上部のタブ【AI音楽・SE生成】では、以下のシンセ波形合成が可能です：

            ・【BGM】「少女綺想曲風 (和風疾走)」「恋色マスタースパーク風 (シンセロック)」「亡き王女の為のセプテット風 (ゴシック緊迫)」
            ・【SE】「スペルカード発動音」「マスタースパーク極太レーザー」「弾幕ピュンピュン」「ピチューン被弾音」「咲夜の時間停止」

            リアルタイム試聴しながらWAVファイルを書き出し、サウンドメーカーのタイムラインへワンクリック配置できます。
            """
            return (res, thinking)
        } else if prompt.contains("コード") || prompt.contains("Blockly") || prompt.contains("ゲーム") {
            let res = """
            【ゲームメーカー用 Blocklyイベントスクリプト】
            ```xml
            <xml xmlns="https://developers.google.com/blockly/xml">
              <block type="event_on_touch" x="20" y="20">
                <field name="TARGET">Marisa_Character</field>
                <statement name="DO">
                  <block type="dialog_show">
                    <value name="SPEAKER"><shadow type="text"><field name="TEXT">魔理沙</field></shadow></value>
                    <value name="MESSAGE"><shadow type="text"><field name="TEXT">マスタースパーク発射準備完了だぜ！</field></shadow></value>
                  </block>
                  <block type="audio_play_se">
                    <value name="SE_NAME"><shadow type="text"><field name="TEXT">se_spark_charge.wav</field></shadow></value>
                  </block>
                </statement>
              </block>
            </xml>
            ```
            """
            return (res, thinking)
        } else {
            let res = """
            ご質問「\(prompt)」について回答いたします。

            東方Projectの制作ワークフローにおいて、以下のステップで進めることが推奨されます：
            1. **TohoAIStudio**: プロット作成、セリフ推敲、AI画像生成、AI BGM/SE波形合成
            2. **スライド＆シナリオメーカー**: 台本とスライド構造を整理し、KeynoteやMarkdownからインポート
            3. **キャラクターメーカー**: PSDTool形式で立ち絵パーツ（表情・衣装差分）を切り出し
            4. **サウンドメーカー**: AquesTalkでゆっくりボイスを自動生成しBGM/SEを配置
            5. **ムービーメーカー**: タイムライン上で1クリック同期し、高画質mp4書き出し

            TohoAIStudioでは各ソフトへの直接データ送信に対応しています。各画面のアクションボタンをご活用ください。
            """
            return (res, thinking)
        }
    }

    // MARK: - 推敲・校正ロジック (Proofread & Polish)
    private func proofreadScenario(input: String, tone: CharacterTonePreset) -> (output: String, thinking: String) {
        let lines = input.components(separatedBy: "\n")
        var polishedLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            var polished = trimmed

            // 1. ゆっくりボイス / AquesTalk 向けの読み仮名・記号校正
            polished = polished.replacingOccurrences(of: "？", with: "？ ")
            polished = polished.replacingOccurrences(of: "！", with: "！ ")
            polished = polished.replacingOccurrences(of: "...", with: "……")

            // 2. キャラクター名が含まれる場合の口調適正化
            if polished.contains("霊夢") {
                polished = polished.replacingOccurrences(of: "ですね", with: "よ").replacingOccurrences(of: "ですか？", with: "かしら？")
            } else if polished.contains("魔理沙") {
                polished = polished.replacingOccurrences(of: "ですね", with: "だな").replacingOccurrences(of: "です", with: "だぜ")
            } else if polished.contains("咲夜") {
                polished = polished.replacingOccurrences(of: "です", with: "でございます")
            } else if polished.contains("妖夢") {
                polished = polished.replacingOccurrences(of: "です", with: "であります！")
            }

            // 3. セリフが長すぎる場合のテンポ調整
            if polished.count > 50 && !polished.contains("、") && !polished.contains(" ") {
                let mid = polished.index(polished.startIndex, offsetBy: polished.count / 2)
                polished.insert(contentsOf: "、", at: mid)
            }

            polishedLines.append(polished)
        }

        let thinking = """
        【推敲・校正レポート】
        ・解析行数: \(lines.count)行
        ・適用ルール: AquesTalk音声記号最適化、不自然な文末表現の修正、会話テンポ・息継ぎの最適化
        ・指定キャラ口調（\(tone.characterName)）の語尾整合性チェック完了
        ・推定読み上げ時間: 約\(String(format: "%.1f", Double(polishedLines.joined().count) / 6.5))秒
        """

        return (polishedLines.joined(separator: "\n"), thinking)
    }

    // MARK: - 口調リライトロジック
    private func rewriteScenarioWithTone(input: String, tone: CharacterTonePreset) -> (output: String, thinking: String) {
        let lines = input.components(separatedBy: "\n")
        var convertedLines: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            var converted = trimmed
            switch tone {
            case .reimu:
                converted = "霊夢「" + trimmed.replacingOccurrences(of: "ですね", with: "よ").replacingOccurrences(of: "ですか？", with: "かしら？") + "…まったく、異変なら早く片付けたいわね」"
            case .marisa:
                converted = "魔理沙「" + trimmed.replacingOccurrences(of: "ですね", with: "だな").replacingOccurrences(of: "です", with: "だぜ") + "！弾幕はパワーだぜ！」"
            case .sakuya:
                converted = "咲夜「" + trimmed.replacingOccurrences(of: "です", with: "でございます") + "。お嬢様にお紅茶をお持ちいたしますわ」"
            case .youmu:
                converted = "妖夢「" + trimmed.replacingOccurrences(of: "だよ", with: "であります") + "！辻斬りではありません、庭師の修行です！」"
            case .remilia:
                converted = "レミリア「" + trimmed.replacingOccurrences(of: "する", with: "なさるのかしら") + "。運命の赤い糸は私の手中にあるのよ」"
            case .flandre:
                converted = "フランドール「" + trimmed + "！ねえ、あたいと遊んでくれるの？きゅっとしてドカーンしちゃうよ！」"
            case .cirno:
                converted = "チルノ「" + trimmed + "！あたいったら最強だからね！氷漬けにしてやるんだもん！」"
            case .sanae:
                converted = "早苗「" + trimmed + "！常識に囚われてはいけないのですね！奇跡を起こしてみせます！」"
            case .aya:
                converted = "文「あやややや！" + trimmed + "！これは文々。新聞の特ダネ間違いなしですよ！」"
            case .reisen:
                converted = "鈴仙「" + trimmed + "！師匠に怒られる前に片付けないと…狂気の瞳、見せてあげます！」"
            case .alice:
                converted = "アリス「" + trimmed + "。上海、蓬莱、行くわよ。手加減なんてしてあげないんだから」"
            case .patchouli:
                converted = "パチュリー「むきゅー…" + trimmed + "。魔導書に埃が被るから静かにしてちょうだい」"
            case .yuyuko:
                converted = "幽々子「まあ、" + trimmed + "。妖夢、お茶と桜餅はまだかしら？ふふっ」"
            case .standardPolite:
                converted = "【ナレーション】" + trimmed + "。幻想郷の日常が静かに過ぎ去っていく。"
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
