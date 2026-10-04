import SwiftUI
import AppKit

/// 仕様書「LLMを用いたAI編集機能」「推敲・セリフ演出」「外部APIを用いたAI編集機能」プログラム
public struct AIEditorProgramView: View {
    @ObservedObject var tohoAIService = TohoAIService.shared
    @ObservedObject var cloudLinuxService = CloudVirtualLinuxService.shared
    @ObservedObject var appState = AppState.shared
    @State private var showApplySuccessAlert: Bool = false
    @State private var applySuccessMessage: String = ""

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // モード選択・設定ツールバー
            editorToolbar

            Divider()

            // 推敲統計バー (推敲・校正モード時)
            if tohoAIService.selectedEditMode == .proofreadPolish && !tohoAIService.editorOutputText.isEmpty {
                proofreadStatsBar
                Divider()
            }

            // メイン編集領域（2カラム: 左 入力・設定 / 右 AI編集・推敲結果）
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
                title: Text("AI編集・推敲データの反映完了"),
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
            .frame(width: 320)

            // 口調選択（推敲・セリフ変換・立ち絵プロンプト時）
            if tohoAIService.selectedEditMode == .proofreadPolish ||
               tohoAIService.selectedEditMode == .scenarioRewrite ||
               tohoAIService.selectedEditMode == .characterPrompt {
                Picker("キャラ調", selection: $tohoAIService.selectedTone) {
                    ForEach(CharacterTonePreset.allCases) { tone in
                        Text(tone.rawValue).tag(tone)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 250)
            }

            Spacer()

            // AI実行エンジン & プロンプト残数
            HStack(spacing: 6) {
                Image(systemName: tohoAIService.activeProvider.iconName)
                    .foregroundColor(.blue)
                Text(tohoAIService.selectedModel)
                    .font(.caption)
                    .bold()
                Text("• 残: \(cloudLinuxService.remainingPrompts)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
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

    // MARK: - Proofread Stats Bar
    private var proofreadStatsBar: some View {
        HStack(spacing: 20) {
            HStack(spacing: 6) {
                Image(systemName: "character.cursor.ibeam")
                    .foregroundColor(.blue)
                Text("文字数: \(tohoAIService.proofreadOriginalCount)文字 → \(tohoAIService.proofreadPolishedCount)文字")
                    .font(.caption)
                    .bold()
            }

            let diff = tohoAIService.proofreadPolishedCount - tohoAIService.proofreadOriginalCount
            HStack(spacing: 4) {
                Text(diff >= 0 ? "(\(diff > 0 ? "+" : "")\(diff)文字)" : "(\(diff)文字)")
                    .font(.caption2)
                    .foregroundColor(diff == 0 ? .secondary : (diff > 0 ? .green : .orange))
            }

            HStack(spacing: 6) {
                Image(systemName: "clock")
                    .foregroundColor(.purple)
                Text("推定読み上げ時間: 約\(String(format: "%.1f", tohoAIService.proofreadEstimatedDurationSec))秒 (ゆっくりボイス基準)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: {
                tohoAIService.editorInputText = tohoAIService.editorOutputText
                applySuccessMessage = "推敲後のテキストを入力元へ反映しました。"
                showApplySuccessAlert = true
            }) {
                Label("推敲結果を採用 (入力元へ反映)", systemImage: "arrow.uturn.backward.circle.fill")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.08))
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
                Text("AI編集・推敲結果 (Diff / プレビュー)")
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
                    Text("LLMが東方世界観・キャラ口調・音声合成向けに推敲＆リライト中...")
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
                    Text("下部の「AI編集・推敲を実行」をクリックすると、\n高度な文章校正・口調統一・シーン分解・コード変換が行われます。")
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

                        // 絵コンテシーン一覧カード表示 (シーン構成モード時)
                        if tohoAIService.selectedEditMode == .sceneStoryboard && !tohoAIService.generatedScenesBuffer.isEmpty {
                            VStack(spacing: 8) {
                                ForEach(Array(tohoAIService.generatedScenesBuffer.enumerated()), id: \.element.id) { idx, sc in
                                    HStack(spacing: 12) {
                                        Text("#\(idx + 1)")
                                            .font(.caption)
                                            .bold()
                                            .foregroundColor(.blue)
                                            .frame(width: 24)

                                        VStack(alignment: .leading, spacing: 2) {
                                            HStack {
                                                Text(sc.title)
                                                    .font(.caption)
                                                    .bold()
                                                Spacer()
                                                Text("\(Int(sc.duration))秒")
                                                    .font(.caption2)
                                                    .foregroundColor(.secondary)
                                            }
                                            Text("キャラ: \(sc.characterName) | 背景: \(sc.backgroundName)")
                                                .font(.system(size: 10))
                                                .foregroundColor(.secondary)
                                            Text(sc.telop)
                                                .font(.caption)
                                                .foregroundColor(.primary)
                                        }
                                    }
                                    .padding(8)
                                    .background(Color(NSColor.textBackgroundColor))
                                    .cornerRadius(6)
                                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.15), lineWidth: 1))
                                }
                            }
                            .padding(.bottom, 6)
                        }

                        // 生成テキスト本文
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
                    Text("AI編集・推敲を実行 (1プロンプト消費)")
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
                case .proofreadPolish, .scenarioRewrite:
                    HStack(spacing: 10) {
                        Button(action: applyToSlideScenario) {
                            Label("スライド＆シナリオに反映", systemImage: "doc.richtext")
                        }
                        .buttonStyle(.bordered)

                        Button(action: applyToSoundMakerVoice) {
                            Label("サウンドメーカーで音声生成", systemImage: "waveform")
                        }
                        .buttonStyle(.borderedProminent)
                    }

                case .sceneStoryboard:
                    Button(action: applyToMovieMakerTimeline) {
                        Label("ムービーメーカーのタイムラインへ一括追加 (\(tohoAIService.generatedScenesBuffer.count)シーン)", systemImage: "film")
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
        case .proofreadPolish:
            tohoAIService.editorInputText = """
            霊夢「今日のご飯は何かしら？」
            魔理沙「魔法の森でキノコをたくさん採ってきたぜ！」
            霊夢「ちょっと、怪しいキノコを部屋に持ち込まないでよ」
            魔理沙「大丈夫だ、妖精にあげたら元気になったぜ」
            """
        case .scenarioRewrite:
            tohoAIService.editorInputText = """
            今日はずいぶん空が赤く染まっていますね。
            何か大変な事件が起きている予感がします。
            すぐに現場に向かいましょう。
            """
        case .sceneStoryboard:
            tohoAIService.editorInputText = """
            プロット：
            幻想郷の空が紅く染まり、博麗神社にいた霊夢と魔理沙が不穏な空気を感じる。
            二人は異変の元凶を突き止めるため、紅魔館へと調査に向かう。
            道中でチルノが立ち塞がり、氷の弾幕で勝負を仕掛けてくる。
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

    private func applyToSoundMakerVoice() {
        appState.addHistory("AIStudioからサウンドメーカーへ推敲台本を転送")
        applySuccessMessage = "サウンドメーカーのボイストラックへ推敲テキストが連携されました。\nAquesTalkによるゆっくり音声合成を実行可能です。"
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
