import SwiftUI
import AppKit

/// 仕様書「LLMとのAIチャット機能」「外部APIチャット機能(Gemini, ChatGPT, Claude)」プログラム
public struct AIChatProgramView: View {
    @ObservedObject var tohoAIService = TohoAIService.shared
    @ObservedObject var cloudLinuxService = CloudVirtualLinuxService.shared
    @ObservedObject var appState = AppState.shared

    @State private var inputText: String = ""
    @State private var showThinkingLogs: [UUID: Bool] = [:]
    @State private var showTransferNotification: String? = nil
    @State private var selectedChatPersona: String = "東方Project総合アシスタント"

    private let personaList = [
        "東方Project総合アシスタント",
        "博麗霊夢 (巫女・異変解決)",
        "霧雨魔理沙 (魔法使い・弾幕火力)",
        "十六夜咲夜 (完全で瀟洒な従者)",
        "魂魄妖夢 (半人半霊の庭師)",
        "レミリア (紅魔館の主)",
        "フランドール (狂気と無邪気)",
        "チルノ (氷の妖精・最強)",
        "東風谷早苗 (奇跡を起こす巫女)",
        "射命丸文 (文々。新聞記者)",
        "西行寺幽々子 (冥界の主)"
    ]

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // 上部ツールバー（モデル選択・プロバイダー・ペルソナ・プロンプト残数）
            chatHeaderBar

            Divider()

            // メッセージ履歴
            chatMessagesScrollView

            // クイックプロンプトプリセットバブル
            quickPromptBar

            Divider()

            // 下部メッセージ入力欄
            chatInputBar
        }
        .background(Color(NSColor.windowBackgroundColor))
        .overlay(
            VStack {
                if let notification = showTransferNotification {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(notification)
                            .font(.subheadline)
                            .bold()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(20)
                    .shadow(radius: 6)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .padding(.top, 16)
                }
                Spacer()
            }
        )
    }

    // MARK: - Header Bar
    private var chatHeaderBar: some View {
        HStack(spacing: 12) {
            // プロバイダー選択
            Picker("エンジン", selection: $tohoAIService.activeProvider) {
                ForEach(AIProviderType.allCases) { provider in
                    Label(provider.rawValue, systemImage: provider.iconName).tag(provider)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 220)

            // モデル選択
            Picker("モデル", selection: $tohoAIService.selectedModel) {
                ForEach(tohoAIService.activeProvider.availableModels, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 200)

            // キャラクターペルソナ選択
            Picker("対話相手", selection: $selectedChatPersona) {
                ForEach(personaList, id: \.self) { p in
                    Text(p).tag(p)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 220)

            Spacer()

            // プロンプト残数バッジ
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text("残プロンプト: \(cloudLinuxService.remainingPrompts) / \(cloudLinuxService.totalPromptsMonthly)")
                    .font(.caption)
                    .bold()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(8)

            // チャット履歴エクスポート
            Button(action: exportChatHistory) {
                Image(systemName: "square.and.arrow.up")
            }
            .help("チャット履歴をMarkdown形式で保存")

            // チャット履歴クリア
            Button(action: {
                tohoAIService.chatMessages.removeAll()
            }) {
                Image(systemName: "trash")
            }
            .help("チャット履歴を消去")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Message List
    private var chatMessagesScrollView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    ForEach(tohoAIService.chatMessages) { msg in
                        messageBubble(msg: msg)
                            .id(msg.id)
                    }

                    if tohoAIService.isGenerating {
                        HStack(spacing: 8) {
                            ProgressView()
                                .controlSize(.small)
                            Text("\(tohoAIService.selectedModel) が思考・生成中...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(16)
            }
            .onChange(of: tohoAIService.chatMessages.count) { _ in
                if let last = tohoAIService.chatMessages.last {
                    withAnimation {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    // MARK: - Message Bubble
    private func messageBubble(msg: AIChatMessage) -> some View {
        HStack(alignment: .top, spacing: 12) {
            if msg.role == "user" {
                Spacer()
            }

            // アイコン
            if msg.role != "user" {
                Image(systemName: msg.provider.iconName)
                    .font(.title3)
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(msg.role == "system" ? Color.gray : Color.blue)
                    .clipShape(Circle())
            }

            VStack(alignment: msg.role == "user" ? .trailing : .leading, spacing: 6) {
                // 送信者情報 & タイムスタンプ
                HStack(spacing: 6) {
                    Text(msg.role == "user" ? "あなた" : (msg.role == "system" ? "システム" : "\(selectedChatPersona) (\(msg.modelName))"))
                        .font(.caption2)
                        .bold()
                        .foregroundColor(.secondary)
                    Text(DateFormatter.localizedString(from: msg.timestamp, dateStyle: .none, timeStyle: .short))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                // 思考プロセスアコーディオン（DeepSeek-R1など）
                if let thinking = msg.thinkingContent {
                    let isExpanded = showThinkingLogs[msg.id] ?? false
                    DisclosureGroup(
                        isExpanded: Binding(
                            get: { isExpanded },
                            set: { showThinkingLogs[msg.id] = $0 }
                        )
                    ) {
                        Text(thinking)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.secondary.opacity(0.08))
                            .cornerRadius(6)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "brain.head.profile")
                                .font(.caption2)
                            Text("思考プロセス (\(isExpanded ? "閉じる" : "展開"))")
                                .font(.caption2)
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.bottom, 4)
                }

                // 本文
                Text(msg.content)
                    .font(.subheadline)
                    .textSelection(.enabled)
                    .padding(12)
                    .background(msg.role == "user" ? Color.blue : Color(NSColor.controlBackgroundColor))
                    .foregroundColor(msg.role == "user" ? .white : .primary)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.secondary.opacity(msg.role == "user" ? 0 : 0.2), lineWidth: 1)
                    )

                // アクションボタン（AI応答のみ）
                if msg.role == "assistant" {
                    HStack(spacing: 12) {
                        Button(action: {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(msg.content, forType: .string)
                            notifyUser("クリップボードにコピーしました")
                        }) {
                            Label("コピー", systemImage: "doc.on.doc")
                                .font(.caption2)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            transferToSlideScenario(text: msg.content)
                        }) {
                            Label("シナリオへ転送", systemImage: "arrow.right.doc.on.clipboard")
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            transferToEditor(text: msg.content)
                        }) {
                            Label("推敲エディタへ転送", systemImage: "wand.and.stars")
                                .font(.caption2)
                                .foregroundColor(.purple)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            transferToMaterialStudio(text: msg.content)
                        }) {
                            Label("素材スタジオに保存", systemImage: "folder.badge.plus")
                                .font(.caption2)
                                .foregroundColor(.green)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.top, 2)
                }
            }

            if msg.role == "user" {
                Image(systemName: "person.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
        }
    }

    // MARK: - Quick Prompt Presets
    private var quickPromptBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Text("プリセット:")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                presetChip(title: "博麗神社の台本作成", prompt: "博麗霊夢と霧雨魔理沙が神社の縁側でお茶を飲みながら新しい異変について話す台本を作ってください。")
                presetChip(title: "紅魔館の掛け合い", prompt: "レミリアと咲夜の優雅で少しコミカルな会話シナリオを生成してください。")
                presetChip(title: "AI画像プロンプト相談", prompt: "紅魔館の時計塔と紅い満月を背景にした美しいアニメ風の画像生成プロンプトを作成してください。")
                presetChip(title: "東方BGM構成案", prompt: "緊迫感のある東方風ラストボス戦闘曲のBGM構成（イントロ、ZUNペットサビ、ドラムビート）を提案してください。")
                presetChip(title: "スペルカードSE演出", prompt: "マスタースパーク発動時の演出構成（効果音、画面振動、セリフテロップ）を設計してください。")
                presetChip(title: "Blocklyイベント", prompt: "ゲームメーカー用のBlocklyタッチイベントとセリフ表示コードを出力してください。")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
    }

    private func presetChip(title: String, prompt: String) -> some View {
        Button(action: {
            inputText = prompt
            tohoAIService.sendMessage(content: prompt)
            inputText = ""
        }) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Chat Input Bar
    private var chatInputBar: some View {
        HStack(spacing: 12) {
            TextField("メッセージを入力（Enterで送信、東方制作の質問やスクリプト生成など）...", text: $inputText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    sendMessage()
                }

            Button(action: sendMessage) {
                HStack(spacing: 4) {
                    Image(systemName: "paperplane.fill")
                    Text("送信")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || tohoAIService.isGenerating)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        tohoAIService.sendMessage(content: text)
        inputText = ""
    }

    private func transferToSlideScenario(text: String) {
        appState.addHistory("AIStudioからスライド＆シナリオへテキスト転送: \(text.prefix(20))...")
        notifyUser("スライド＆シナリオメーカーへ転送しました")
    }

    private func transferToEditor(text: String) {
        tohoAIService.editorInputText = text
        tohoAIService.activeProgramTab = .aiEditor
        notifyUser("AI編集・推敲プログラムへ転送しました")
    }

    private func transferToMaterialStudio(text: String) {
        let mat = MaterialItem(
            title: "AI生成シナリオ_\(Int(Date().timeIntervalSince1970))",
            type: "シナリオ",
            category: "台本",
            filePath: "/Volumes/ZSSD/GitHub/repository/TohoStudio/Application/TohoAIStudio/Programs/AI_Generated.txt",
            fileSize: Int64(text.utf8.count),
            createdAt: Date()
        )
        appState.materials.append(mat)
        notifyUser("素材スタジオのデータベースに保存しました")
    }

    private func exportChatHistory() {
        var md = "# TohoAIStudio チャット履歴\n\n"
        for msg in tohoAIService.chatMessages {
            let roleName = msg.role == "user" ? "ユーザー" : (msg.role == "system" ? "システム" : "AI (\(msg.modelName))")
            md += "### [\(roleName)] - \(DateFormatter.localizedString(from: msg.timestamp, dateStyle: .short, timeStyle: .medium))\n\n"
            if let think = msg.thinkingContent {
                md += "> 思考ログ:\n> " + think.replacingOccurrences(of: "\n", with: "\n> ") + "\n\n"
            }
            md += "\(msg.content)\n\n---\n\n"
        }

        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(md, forType: .string)
        notifyUser("Markdown形式でチャット履歴をコピーしました")
    }

    private func notifyUser(_ msg: String) {
        withAnimation {
            showTransferNotification = msg
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation {
                showTransferNotification = nil
            }
        }
    }
}
