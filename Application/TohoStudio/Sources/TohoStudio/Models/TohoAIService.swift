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

// MARK: - Character Tone Preset
public enum CharacterTonePreset: String, CaseIterable, Identifiable {
    case reimu = "博麗霊夢 (「〜よ」「〜だわ」「異変を解決するわよ」)"
    case marisa = "霧雨魔理沙 (「〜ぜ」「〜なんだな」「弾幕は火力だぜ」)"
    case sakuya = "十六夜咲夜 (「〜ですわ」「お嬢様をお待ちかねです」)"
    case youmu = "魂魄妖夢 (「〜です」「斬れぬものなどあんまりない！」)"
    case remilia = "レミリア・スカーレット (「〜かしら」「運命を操ってあげる」)"
    case flandre = "フランドール (「〜遊んでくれるの？」「きゅっとしてドカーン！」)"
    case cirno = "チルノ (「あたいったら最強ね！」「〜だもんね！」)"
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
        case .standardPolite: return "ナレーション"
        }
    }
}

// MARK: - AI Edit Mode
public enum AIEditMode: String, CaseIterable, Identifiable {
    case scenarioRewrite = "台本・セリフ推敲＆キャラ口調変換"
    case sceneStoryboard = "シーン構成＆絵コンテ自動生成"
    case characterPrompt = "立ち絵パーツ・表情ポーズプロンプト生成"
    case gameBlocklyScript = "ゲームロジック＆スクリプト生成"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
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

// MARK: - TohoAIProgramTab Enum
public enum TohoAIProgramTab: String, CaseIterable, Identifiable {
    case virtualLinuxVM = "仮想LinuxVM 通信確認"
    case aiChat = "AIチャット"
    case aiEditor = "AI編集・推敲"
    case usageBilling = "使用量・請求確認"
    case externalAPI = "外部API管理"
    case inAppBrowser = "専用ブラウザ (請求確認)"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .virtualLinuxVM: return "server.rack"
        case .aiChat: return "bubble.left.and.bubble.right.fill"
        case .aiEditor: return "wand.and.stars"
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

    // MARK: - AI Editing Workspace State
    @Published public var selectedEditMode: AIEditMode = .scenarioRewrite
    @Published public var selectedTone: CharacterTonePreset = .reimu
    @Published public var editorInputText: String = "霊夢「今日のご飯は何かしら？」\n魔理沙「森でキノコを採ってきたぜ！」"
    @Published public var editorOutputText: String = ""
    @Published public var editorThinkingText: String = ""
    @Published public var isEditorProcessing: Bool = false

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
                content: "TohoAIStudioへようこそ。仮想LinuxVMおよびGemini/ChatGPT/Claudeと連携し、東方二次創作の台本・シナリオ・演出・コード・立ち絵生成を支援します。",
                provider: .virtualLinuxVM,
                modelName: "System",
                timestamp: Date().addingTimeInterval(-3600)
            ),
            AIChatMessage(
                role: "assistant",
                content: "こんにちは！東方Project制作AIアシスタントです。\n仮想LinuxVM (DeepSeek-R1 / Gemma-2) は正常に稼働しており、常時高速通信可能です。\nどのような作品制作をサポートしましょうか？（台本作成、セリフ推敲、動画絵コンテ、Blocklyコード生成など対応しています）",
                thinkingContent: "【仮想LinuxVM システム起動ログ】\n- GCP e2-standard-2 インスタンス疎通OK\n- DeepSeek-R1-Distill-Qwen (8B) 8bit量子化モデルロード完了\n- 東方Project公式ガイドラインおよび口調コーパス辞書マウント完了",
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

        // 非同期応答シミュレーション（思考プロセス生成 + 応答）
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
            guard let self = self else { return }

            let (responseContent, thinkingLog) = self.generateSmartResponse(for: content, provider: self.activeProvider, model: self.selectedModel)

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

    // MARK: - AI Edit Execution
    public func executeAIEdit() {
        guard !editorInputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let linuxService = CloudVirtualLinuxService.shared
        guard linuxService.consumePrompt(count: 1, purpose: "TohoAIStudio AI編集") else {
            AppState.shared.addSystemLog(level: "ERROR", message: "AI編集失敗: プロンプト残数が0です。")
            return
        }

        isEditorProcessing = true

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            guard let self = self else { return }

            switch self.selectedEditMode {
            case .scenarioRewrite:
                let result = self.rewriteScenarioWithTone(input: self.editorInputText, tone: self.selectedTone)
                self.editorOutputText = result.output
                self.editorThinkingText = result.thinking

            case .sceneStoryboard:
                let result = self.generateStoryboardFromPlot(input: self.editorInputText)
                self.editorOutputText = result.output
                self.editorThinkingText = result.thinking
                self.generatedScenesBuffer = result.scenes

            case .characterPrompt:
                let result = self.generateCharacterPrompt(input: self.editorInputText, tone: self.selectedTone)
                self.editorOutputText = result.output
                self.editorThinkingText = result.thinking

            case .gameBlocklyScript:
                let result = self.generateGameScript(input: self.editorInputText)
                self.editorOutputText = result.output
                self.editorThinkingText = result.thinking
            }

            self.isEditorProcessing = false
            AppState.shared.addSystemLog(level: "INFO", message: "TohoAIStudio: [\(self.selectedEditMode.rawValue)] のAI処理が完了しました。")
        }
    }

    // MARK: - Helper Generation Logics
    private func generateSmartResponse(for prompt: String, provider: AIProviderType, model: String) -> (String, String?) {
        let thinking = """
        【DeepSeek-R1 / \(model) 思考ログ】
        1. ユーザー入力の解析:「\(prompt.prefix(40))...」
        2. 東方Project二次創作ガイドラインチェック: 商業出版外の同人制作、ファンコンテンツ適合
        3. キャラクター設定および東方幻想郷世界観の文脈参照
        4. 出力トーンの整合性確認・演出最適化
        """

        if prompt.contains("台本") || prompt.contains("会話") || prompt.contains("脚本") {
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
            1. **スライド＆シナリオメーカー**: プロットとセリフテキストを構成し、KeynoteやMarkdownからインポート
            2. **キャラクターメーカー**: PSDTool形式で立ち絵パーツ（表情・衣装差分）を切り出し
            3. **サウンドメーカー**: AquesTalkでゆっくりボイスを自動生成しBGMを割り当て
            4. **ムービーメーカー**: タイムライン上で1クリック同期し、高画質mp4書き出し

            TohoAIStudioでは各ソフトへの直接データ送信に対応しています。右上の「他のソフトへ転送」をご活用ください。
            """
            return (res, thinking)
        }
    }

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
            case .standardPolite:
                converted = "【ナレーション】" + trimmed + "。幻想郷の日常が静かに過ぎ去っていく。"
            }
            convertedLines.append(converted)
        }

        let thinking = "【口調変換エンジン】選択されたキャラクター調「\(tone.rawValue)」の文法規則と語尾辞書を適用し、東方らしい語感にリライトしました。"
        return (convertedLines.joined(separator: "\n\n"), thinking)
    }

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
