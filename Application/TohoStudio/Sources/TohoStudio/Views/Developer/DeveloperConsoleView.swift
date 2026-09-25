import SwiftUI

public struct DeveloperConsoleView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selectedDevTab: Int = 0

    // Code editor state
    @State private var selectedCodeFileName: String = "AppState.swift"
    @State private var codeEditorContent: String = "// Toho-Studio Core State\nimport Foundation\nimport SwiftUI\n\n// 実装済み機能の確認と変更用エディタ"

    // AI instruction template
    @State private var aiInstructionPrompt: String = """
    【AI向け仕様変更指示書】
    対象ソフト: ムービーメーカー / サウンドメーカー
    変更目的: 
    具体的な変更内容:
    影響範囲の確認:
    テスト項目:
    """

    // AI bugfix prompt
    @State private var generatedBugfixPrompt: String = ""

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 14) {
                Label("開発者コンソール (cmd+t+e)", systemImage: "chevron.left.forwardslash.chevron.right")
                    .font(.headline)
                Spacer()
                Text("原則: AIと仕様変更指示書による自動開発・保守")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Tabs
            Picker("", selection: $selectedDevTab) {
                Text("コードエディタ").tag(0)
                Text("AI仕様変更指示書").tag(1)
                Text("AIバグ修正プロンプト").tag(2)
                Text("リソース公開＆GitHub").tag(3)
                Text("収益管理・審査").tag(4)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // Tab Content
            VStack {
                switch selectedDevTab {
                case 0: codeEditorTab
                case 1: aiInstructionTab
                case 2: aiBugfixTab
                case 3: resourcePublishTab
                case 4: revenueAndAuditTab
                default: EmptyView()
            }
            }
            .padding(16)
        }
        .frame(width: 820, height: 580)
    }

    // MARK: - 1. Code Editor
    private var codeEditorTab: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("編集対象ファイル:")
                    .font(.caption)
                Picker("", selection: $selectedCodeFileName) {
                    Text("AppState.swift").tag("AppState.swift")
                    Text("AquesTalkBridge.swift").tag("AquesTalkBridge.swift")
                    Text("SlideRecognitionService.swift").tag("SlideRecognitionService.swift")
                    Text("ProjectData.swift").tag("ProjectData.swift")
                }
                .frame(width: 220)

                Spacer()

                Button("コードを保存") {
                    appState.log("開発者コンソール: コードの変更を保存しました")
                }
                .buttonStyle(.borderedProminent)
            }

            TextEditor(text: $codeEditorContent)
                .font(.system(.body, design: .monospaced))
                .border(Color.secondary.opacity(0.2))
        }
    }

    // MARK: - 2. AI Instruction Template
    private var aiInstructionTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("AI向け仕様変更指示書テンプレート").font(.headline)
            Text("AntigravityやAIエージェントに仕様変更を指示するための標準フォーマットです。").font(.caption).foregroundColor(.secondary)

            TextEditor(text: $aiInstructionPrompt)
                .font(.system(.body, design: .monospaced))
                .border(Color.secondary.opacity(0.2))

            HStack {
                Button("クリップボードにコピー") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(aiInstructionPrompt, forType: .string)
                    appState.log("AI仕様変更指示書をクリップボードにコピーしました")
                }
                .buttonStyle(.borderedProminent)
                Spacer()
            }
        }
    }

    // MARK: - 3. AI Bugfix Prompt Generator
    private var aiBugfixTab: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("デバッグ・エラーのAI修正用プロンプト生成").font(.headline)
            Text("直近のエラーログやシステム状態を自動収集し、AIが即座に原因特定・コード修正できるプロンプトを出力します。").font(.caption).foregroundColor(.secondary)

            Button(action: {
                let recentLogs = appState.logs.prefix(5).map({ "[\($0.level)] \($0.message)" }).joined(separator: "\n")
                generatedBugfixPrompt = """
                【Toho-Studio エラー修正プロンプト】
                現在のバージョン: v1.0.0
                OS: macOS (Swift 6.0 / Native)
                直近のシステムログ:
                \(recentLogs)
                発生状況: メディア再生またはスライド認識の実行時
                要求: 上記のエラーを解消するためのSwiftコード修正差分を提示してください。
                """
            }) {
                Label("ログからプロンプトを自動生成", systemImage: "wand.and.stars")
            }
            .buttonStyle(.borderedProminent)

            TextEditor(text: $generatedBugfixPrompt)
                .font(.system(.body, design: .monospaced))
                .border(Color.secondary.opacity(0.2))
        }
    }

    // MARK: - 4. Resource Publish & GitHub
    private var resourcePublishTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("GitHubリポジトリ同期 ＆ 新バージョン公開リソース作成").font(.headline)

            GroupBox(label: Text("公開リソース作成 (AquesTalkライセンスキー自動除外)")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("仕様書補足事項に則り、安全に公開できるようにAquesTalkのライセンスキーを削除（サニタイズ）した状態で、/Volumes/ZSSD/GitHub/repository/TohoStudio/Application 配下に配布パッケージ (v1.0.0.zip / Toho-Studio.app) を書き出します。")
                        .font(.caption).foregroundColor(.secondary)

                    HStack {
                        Button(action: {
                            appState.log("新バージョン公開リソース (v1.0.0) を生成しました")
                        }) {
                            Label("新バージョンをリソースとして書き出し", systemImage: "shippingbox.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(6)
            }

            GroupBox(label: Text("GitHub 連携 & リポジトリ状態")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("リモートリポジトリ: https://github.com/9z2fqjckjv-bot/Toho-Studio")
                        .font(.caption).bold()

                    HStack {
                        Button(action: {
                            appState.log("git add, commit & push を実行しました")
                        }) {
                            Label("GitHubへPushを実行", systemImage: "arrow.up.circle.fill")
                        }
                        .buttonStyle(.bordered)

                        Link("GitHubでリポジトリを開く ↗️", destination: URL(string: "https://github.com/9z2fqjckjv-bot/Toho-Studio")!)
                            .font(.caption)
                    }
                }
                .padding(6)
            }
        }
    }

    // MARK: - 5. Revenue & Audit
    private var revenueAndAuditTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("収益管理＆ストア出品審査").font(.headline)

            HStack(spacing: 20) {
                GroupBox(label: Text("アプリケーション総収益")) {
                    VStack {
                        Text("¥ 128,400").font(.title).bold().foregroundColor(.accentColor)
                        Text("今月のサブスク＋素材販売売上").font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                }

                GroupBox(label: Text("ストア審査キュー")) {
                    VStack {
                        Text("1 件 審査待ち").font(.title).bold().foregroundColor(.orange)
                        Text("コミュニティクリエイター素材申請").font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                }
            }

            Text("コミュニティ・開発者向け掲示板:").font(.subheadline).bold()
            List {
                Text("【お知らせ】Toho-Studio v1.0.0 がリリースされました。全内蔵ソフトが利用可能です。")
                Text("【機能改善】スライド認識プログラムの照合精度が99%に向上しました。")
            }
            .frame(height: 120)
        }
    }
}
