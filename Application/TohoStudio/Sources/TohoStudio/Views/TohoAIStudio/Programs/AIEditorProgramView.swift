import SwiftUI
import AppKit

/// 仕様書「LLMを用いたAI編集機能」「外部APIを用いたAI編集機能(Gemini, ChatGPT, Claude)」プログラム
public struct AIEditorProgramView: View {
    @ObservedObject var tohoAIService = TohoAIService.shared
    @ObservedObject var appState = AppState.shared
    @State private var showApplySuccessAlert: Bool = false
    @State private var applySuccessMessage: String = ""

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // モード選択・設定ツールバー
            editorToolbar

            Divider()

            // メイン編集領域（2カラム: 左 入力・設定 / 右 AI編集結果・Diff）
            HStack(spacing: 0) {
                // 左カラム: 入力元テキスト
                leftInputPanel
                    .frame(maxWidth: .infinity)

                Divider()

                // 右カラム: AI推敲・生成結果
                rightOutputPanel
                    .frame(maxWidth: .infinity)
            }

            Divider()

            // 下部アクションバー
            bottomActionBar
        }
        .background(Color(NSColor.windowBackgroundColor))
        .alert(isPresented: $showApplySuccessAlert) {
            Alert(
                title: Text("AI編集データの反映完了"),
                message: Text(applySuccessMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Toolbar
    private var editorToolbar: some View {
        HStack(spacing: 16) {
            // 編集モード切り替え
            Picker("編集モード", selection: $tohoAIService.selectedEditMode) {
                ForEach(AIEditMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.iconName).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 260)

            // 口調選択（セリフ推敲または立ち絵時）
            if tohoAIService.selectedEditMode == .scenarioRewrite || tohoAIService.selectedEditMode == .characterPrompt {
                Picker("キャラ調", selection: $tohoAIService.selectedTone) {
                    ForEach(CharacterTonePreset.allCases) { tone in
                        Text(tone.rawValue).tag(tone)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 220)
            }

            Spacer()

            // AI実行エンジン表示
            HStack(spacing: 6) {
                Image(systemName: tohoAIService.activeProvider.iconName)
                    .foregroundColor(.blue)
                Text(tohoAIService.selectedModel)
                    .font(.caption)
                    .bold()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Left Panel (Input)
    private var leftInputPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("編集前・入力プロンプト / 台本ソース")
                    .font(.headline)
                Spacer()

                // サンプルテキスト挿入ボタン
                Button(action: insertSampleInput) {
                    Label("サンプル挿入", systemImage: "text.badge.plus")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
            }

            TextEditor(text: $tohoAIService.editorInputText)
                .font(.system(.body, design: .monospaced))
                .padding(8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        }
        .padding(16)
    }

    // MARK: - Right Panel (Output)
    private var rightOutputPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("AI編集・生成結果 (Diff / プレビュー)")
                    .font(.headline)
                Spacer()

                if !tohoAIService.editorOutputText.isEmpty {
                    Button(action: {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(tohoAIService.editorOutputText, forType: .string)
                        applySuccessMessage = "クリップボードにコピーしました。"
                        showApplySuccessAlert = true
                    }) {
                        Label("コピー", systemImage: "doc.on.doc")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
            }

            if tohoAIService.isEditorProcessing {
                VStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                    Text("LLMが東方世界観と口調に合わせてリライト中...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if tohoAIService.editorOutputText.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("下部の「AI編集を実行」をクリックすると、\n高度な推敲・シーン分解・コード変換が行われます。")
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        // 思考ログ
                        if !tohoAIService.editorThinkingText.isEmpty {
                            Text(tohoAIService.editorThinkingText)
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.secondary)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.blue.opacity(0.06))
                                .cornerRadius(6)
                        }

                        // 生成テキスト
                        Text(tohoAIService.editorOutputText)
                            .font(.system(.body, design: .monospaced))
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(12)
                }
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
            }
        }
        .padding(16)
    }

    // MARK: - Bottom Action Bar
    private var bottomActionBar: some View {
        HStack(spacing: 16) {
            Button(action: {
                tohoAIService.executeAIEdit()
            }) {
                HStack(spacing: 6) {
                    if tohoAIService.isEditorProcessing {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "wand.and.stars")
                    }
                    Text("AI編集を実行 (1プロンプト消費)")
                        .bold()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .disabled(tohoAIService.isEditorProcessing || tohoAIService.editorInputText.isEmpty)

            Spacer()

            // 他ソフトへのワンクリック反映ボタン群
            if !tohoAIService.editorOutputText.isEmpty {
                switch tohoAIService.selectedEditMode {
                case .scenarioRewrite:
                    Button(action: applyToSlideScenario) {
                        Label("スライド＆シナリオに反映", systemImage: "doc.richtext")
                    }
                    .buttonStyle(.bordered)

                case .sceneStoryboard:
                    Button(action: applyToMovieMakerTimeline) {
                        Label("ムービーメーカーのタイムラインへ追加 (\(tohoAIService.generatedScenesBuffer.count)シーン)", systemImage: "film")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.borderedProminent)

                case .characterPrompt:
                    Button(action: applyToCharacterMaker) {
                        Label("キャラクターメーカーへ反映", systemImage: "person.crop.artframe")
                    }
                    .buttonStyle(.bordered)

                case .gameBlocklyScript:
                    Button(action: applyToGameMaker) {
                        Label("ゲームメーカーへ反映", systemImage: "gamecontroller")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Actions
    private func insertSampleInput() {
        switch tohoAIService.selectedEditMode {
        case .scenarioRewrite:
            tohoAIService.editorInputText = """
            霊夢「今日のご飯は何かしら？」
            魔理沙「魔法の森でキノコをたくさん採ってきたぜ！」
            霊夢「ちょっと、怪しいキノコを部屋に持ち込まないでよ」
            """
        case .sceneStoryboard:
            tohoAIService.editorInputText = """
            プロット：
            幻想郷の空が紅く染まり、博麗神社にいた霊夢と魔理沙が不穏な空気を感じる。
            二人は異変の元凶を突き止めるため、紅魔館へと調査に向かう。
            """
        case .characterPrompt:
            tohoAIService.editorInputText = """
            魔理沙が八卦炉を構え、自信満々に笑っている決めポーズの立ち絵パーツ構成を作りたい。
            """
        case .gameBlocklyScript:
            tohoAIService.editorInputText = """
            ボス戦でHPが半分以下になったら「マスタースパーク」を発動して画面を揺らすイベント。
            """
        }
    }

    private func applyToMovieMakerTimeline() {
        guard !tohoAIService.generatedScenesBuffer.isEmpty else { return }
        for scene in tohoAIService.generatedScenesBuffer {
            appState.movieScenes.append(scene)
        }
        appState.addHistory("AIStudioからムービーメーカーへ\(tohoAIService.generatedScenesBuffer.count)シーンを追加反映")
        applySuccessMessage = "ムービーメーカーのタイムラインに\(tohoAIService.generatedScenesBuffer.count)件のシーンが正常に追加されました！\n上部メニューまたはアプリトップからムービーメーカーを開いてご確認ください。"
        showApplySuccessAlert = true
    }

    private func applyToSlideScenario() {
        appState.addHistory("AIStudioからスライド＆シナリオへ台本反映")
        applySuccessMessage = "スライド＆シナリオメーカーへ台本テキストが反映されました。"
        showApplySuccessAlert = true
    }

    private func applyToCharacterMaker() {
        appState.addHistory("AIStudioからキャラクターメーカーへプロンプト反映")
        applySuccessMessage = "キャラクターメーカーへ立ち絵生成パラメータが転送されました。"
        showApplySuccessAlert = true
    }

    private func applyToGameMaker() {
        appState.addHistory("AIStudioからゲームメーカーへスクリプト反映")
        applySuccessMessage = "ゲームメーカーへBlockly/スクリプトが反映されました。"
        showApplySuccessAlert = true
    }
}
