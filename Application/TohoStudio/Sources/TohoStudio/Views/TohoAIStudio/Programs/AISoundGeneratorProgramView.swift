import SwiftUI
import AppKit

/// 仕様書「AI BGM & SE 生成機能」プログラム
/// 現代社会・日常・映画劇伴・一般ゲームUI・東方Project両対応 プロシージャル波形合成エンジン
public struct AISoundGeneratorProgramView: View {
    @ObservedObject var soundService = AISoundGeneratorService.shared
    @ObservedObject var tohoAIService = TohoAIService.shared
    @ObservedObject var cloudLinuxService = CloudVirtualLinuxService.shared
    @ObservedObject var appState = AppState.shared

    @State private var activeTab: SoundGeneratorMode = .bgm
    @State private var showSuccessAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var showColabBrowser: Bool = false

    public enum SoundGeneratorMode: String, CaseIterable, Identifiable {
        case bgm = "BGM生成 (プロンプト入力)"
        case se = "効果音 (SE) 生成 (プロンプト入力)"

        public var id: String { rawValue }

        public var iconName: String {
            switch self {
            case .bgm: return "music.note"
            case .se: return "waveform"
            }
        }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // 上部モード切り替えタブバー
            modeSegmentBar

            Divider()

            // メインコンテンツ領域 (2カラム: 左 パラメータ設定 / 右 試聴・ビジュアライザ・履歴)
            HStack(spacing: 0) {
                // 左カラム: 設定パネル
                leftSettingsPanel
                    .frame(width: 400)

                Divider()

                // 右カラム: 試聴・波形・制作連携パネル
                rightPlaybackPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .alert(isPresented: $showSuccessAlert) {
            Alert(
                title: Text("音響データ転送完了"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showColabBrowser) {
            ColabGPUInAppBrowserView(isPresented: $showColabBrowser)
        }
    }

    // MARK: - Mode Segment Bar (AIチャットと同様のエンジン・モデル選択バー統合)
    private var modeSegmentBar: some View {
        VStack(spacing: 8) {
            // 上段: エンジン・モデル選択バー (AIチャットと同様)
            HStack(spacing: 12) {
                // プロバイダー選択
                Picker("エンジン", selection: $soundService.selectedProvider) {
                    ForEach(AIProviderType.allCases) { provider in
                        Label(provider.rawValue, systemImage: provider.iconName).tag(provider)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 220)

                // モデル選択
                Picker("モデル", selection: $soundService.selectedModel) {
                    ForEach(soundService.selectedProvider.availableModels, id: \.self) { model in
                        Text(model).tag(model)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 200)

                // 接続ステータスバッジ
                apiStatusBadge(for: soundService.selectedProvider)

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
            }

            // 下段: モード切り替え (BGM / SE)
            HStack {
                Picker("", selection: $activeTab) {
                    ForEach(SoundGeneratorMode.allCases) { mode in
                        Label(mode.rawValue, systemImage: mode.iconName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 440)

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func apiStatusBadge(for provider: AIProviderType) -> some View {
        let isConfigured: Bool
        let labelText: String

        switch provider {
        case .chatGPT:
            isConfigured = !tohoAIService.chatGPTConfig.apiKey.isEmpty
            labelText = isConfigured ? "OpenAI連携中" : "ChatGPT音響推論"
        case .gemini:
            isConfigured = !tohoAIService.geminiConfig.apiKey.isEmpty
            labelText = isConfigured ? "Gemini連携中" : "Gemini音響推論"
        case .claude:
            isConfigured = !tohoAIService.claudeConfig.apiKey.isEmpty
            labelText = isConfigured ? "Claude連携中" : "Claude音響推論"
        case .virtualLinuxVM:
            if cloudLinuxService.colabBridge.isOnline && !cloudLinuxService.colabBridge.endpoint.isEmpty {
                isConfigured = true
                labelText = "⚡️ Colab GPU ブリッジ (MusicGen/SE / \(cloudLinuxService.colabBridge.gpuName))"
            } else {
                isConfigured = (cloudLinuxService.connectionStatus == .connected || cloudLinuxService.connectionStatus == .lowLatency)
                labelText = isConfigured ? "仮想LinuxVM (ローカルLLM/シンセ波形合成)" : "スタンドアロン音響合成"
            }
        }

        return HStack(spacing: 4) {
            Circle()
                .fill(isConfigured ? Color.green : Color.blue)
                .frame(width: 7, height: 7)
            Text(labelText)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)
    }

    // MARK: - Left Settings Panel
    private var leftSettingsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // Google Colab GPU Bridge 設定・状態カード
                colabBridgeCard

                if activeTab == .bgm {
                    bgmSettingsSection
                } else {
                    seSettingsSection
                }

                Divider()

                // 生成実行ボタン
                generateButtonSection

                Spacer()
            }
            .padding(16)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - BGM Settings (プロンプト駆動)
    private var bgmSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("AI BGM プロンプト生成")
                    .font(.headline)
                Text("情景・楽器・テンポ・雰囲気を自由に記述してリアルタイム作曲")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("BGMプロンプト (自由記述):")
                    .font(.caption)
                    .bold()

                TextEditor(text: $soundService.bgmPrompt)
                    .font(.system(.body, design: .default))
                    .frame(height: 120)
                    .padding(6)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))

                // クイック入力サジェストタグ
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        soundTagButton("雨の日の静かなカフェ、アコギとピアノ", isBGM: true)
                        soundTagButton("サイバーパンクの夜、疾走シンセBGM", isBGM: true)
                        soundTagButton("深夜のデスク作業、Lo-Fiチルビート", isBGM: true)
                        soundTagButton("映画のような壮大なバトル劇伴オーケストラ", isBGM: true)
                        soundTagButton("東方風の軽快なメロディ、ZUNペットとロックドラム", isBGM: true)
                        soundTagButton("EDMフェス、高揚感のあるダンスビート", isBGM: true)
                    }
                }
            }

            // プロンプトから推論される音響特徴のリアルタイムプレビュー
            let inferred = soundService.analyzeBGMPrompt(soundService.bgmPrompt)
            VStack(alignment: .leading, spacing: 4) {
                Text("AI推論プレビュー:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(inferred.summary)
                    .font(.caption)
                    .foregroundColor(.blue)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.08))
                    .cornerRadius(6)
            }
        }
    }

    // MARK: - SE Settings (プロンプト駆動)
    private var seSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("AI 効果音(SE) プロンプト生成")
                    .font(.headline)
                Text("欲しい音（通知音、打撃、爆発、環境音等）を自由に記述して波形合成")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("SEプロンプト (自由記述):")
                    .font(.caption)
                    .bold()

                TextEditor(text: $soundService.sePrompt)
                    .font(.system(.body, design: .default))
                    .frame(height: 120)
                    .padding(6)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))

                // クイック入力サジェストタグ
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        soundTagButton("スマホのチャット着信音、クリアな通知ベル", isBGM: false)
                        soundTagButton("一眼レフカメラのシャッター音", isBGM: false)
                        soundTagButton("PCキーボードの高速タイピング打鍵音", isBGM: false)
                        soundTagButton("格闘ゲームの重いパンチ打撃音", isBGM: false)
                        soundTagButton("大爆発と轟音クラッシュ", isBGM: false)
                        soundTagButton("クイズの正解チャイム (ピンポン♪)", isBGM: false)
                        soundTagButton("東方スペルカード展開の煌めくチャイム", isBGM: false)
                    }
                }
            }

            // プロンプトから推論される音響特徴のリアルタイムプレビュー
            let inferred = soundService.analyzeSEPrompt(soundService.sePrompt)
            VStack(alignment: .leading, spacing: 4) {
                Text("AI推論プレビュー:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(inferred.summary)
                    .font(.caption)
                    .foregroundColor(.purple)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.purple.opacity(0.08))
                    .cornerRadius(6)
            }
        }
    }

    // MARK: - Tag Button Helper
    private func soundTagButton(_ text: String, isBGM: Bool) -> some View {
        Button(action: {
            if isBGM {
                soundService.bgmPrompt = text
            } else {
                soundService.sePrompt = text
            }
        }) {
            Text(text)
                .font(.system(size: 10))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(isBGM ? Color.blue.opacity(0.12) : Color.purple.opacity(0.12))
                .foregroundColor(isBGM ? .blue : .purple)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Generate Button Section
    private var generateButtonSection: some View {
        VStack(spacing: 8) {
            Button(action: {
                if activeTab == .bgm {
                    soundService.generateBGM()
                } else {
                    soundService.generateSE()
                }
            }) {
                HStack(spacing: 8) {
                    if (activeTab == .bgm && soundService.isBGMGenerating) ||
                       (activeTab == .se && soundService.isSEGenerating) {
                        ProgressView().controlSize(.small)
                        Text("音響生成中...")
                    } else {
                        Image(systemName: "waveform.badge.plus")
                        Text(activeTab == .bgm ? "AI BGMを生成 (1プロンプト)" : "AI SEを生成 (1プロンプト)")
                            .bold()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(soundService.isBGMGenerating || soundService.isSEGenerating)

            // Colab GPU 直接起動ボタン
            Button(action: {
                soundService.useColabGPUIfAvailable = true
                if activeTab == .bgm {
                    soundService.generateBGM()
                } else {
                    soundService.generateSE()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.yellow)
                    Text("⚡️ Colab GPU を動かして生成 (\(activeTab == .bgm ? "MusicGen" : "AudioGen"))")
                        .font(.caption)
                        .bold()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
            .disabled(soundService.isBGMGenerating || soundService.isSEGenerating)
        }
    }

    // MARK: - Colab GPU Bridge Control Card
    private var colabBridgeCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "bolt.badge.automatic.fill")
                    .foregroundColor(.yellow)
                Text("Google Colab GPU Bridge")
                    .font(.caption)
                    .bold()
                Spacer()
                HStack(spacing: 4) {
                    Circle()
                        .fill(cloudLinuxService.colabBridge.isOnline ? Color.green : Color.orange)
                        .frame(width: 7, height: 7)
                    Text(cloudLinuxService.colabBridge.isOnline ? "オンライン" : "未接続/待機中")
                        .font(.caption2)
                        .bold()
                        .foregroundColor(cloudLinuxService.colabBridge.isOnline ? .green : .orange)
                }
            }

            Text("NVIDIA L4/T4 (16-24GB VRAM): MusicGen(本格BGM作曲) ＆ AudioGen(効果音生成)")
                .font(.caption2)
                .foregroundColor(.secondary)

            // アプリ内Colab起動 ＆ 自動検出トリガーボタン
            Button(action: {
                showColabBrowser = true
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles.tv.fill")
                        .font(.caption)
                    Text(cloudLinuxService.colabBridge.isOnline ? "アプリ内Colabブラウザを表示 (接続中)" : "🌸 アプリ内Colabで起動 ＆ GPU自動接続")
                        .font(.caption)
                        .bold()
                    Spacer()
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(cloudLinuxService.colabBridge.isOnline ? Color.green : Color.blue)
                )
            }
            .buttonStyle(.plain)
            .help("アプリ内WebKitブラウザでColabを開き、セル実行後にURLを全自動挿入します")

            // エンドポイント入力欄
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Colab 一時URL (trycloudflare.com):")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    if cloudLinuxService.colabBridge.isOnline {
                        Text("自動挿入・接続済み")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.green)
                    }
                }
                HStack {
                    TextField("https://xxxx.trycloudflare.com", text: $cloudLinuxService.colabBridge.endpoint)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)

                    Button(action: {
                        cloudLinuxService.testColabBridgeConnection { success, message in
                            alertMessage = message
                            showSuccessAlert = true
                        }
                    }) {
                        Label("接続テスト", systemImage: "arrow.triangle.2.circlepath")
                            .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                }
            }

            HStack(spacing: 8) {
                Toggle("Colab GPU を優先使用", isOn: $soundService.useColabGPUIfAvailable)
                    .font(.caption)

                Spacer()

                if let url = URL(string: cloudLinuxService.colabBridge.notebookUrl) {
                    Button(action: {
                        NSWorkspace.shared.open(url)
                    }) {
                        Label("外部Safariで開く", systemImage: "safari")
                            .font(.caption2)
                    }
                    .buttonStyle(.link)
                }
            }
        }
        .padding(10)
        .background(Color.yellow.opacity(0.08))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.yellow.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Right Playback & History Panel
    private var rightPlaybackPanel: some View {
        VStack(spacing: 0) {
            // 現在選択中のサウンド再生プレイヤー
            VStack(spacing: 16) {
                Spacer()

                // 波形ビジュアライザーアニメーション
                HStack(spacing: 6) {
                    ForEach(0..<24) { i in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(
                                colors: [Color.blue, Color.purple, Color.cyan],
                                startPoint: .bottom,
                                endPoint: .top
                            ))
                            .frame(width: 8, height: visualizerBarHeight(index: i))
                            .animation(.easeInOut(duration: 0.15), value: soundService.isBGMPlaying || soundService.isSEPlaying)
                    }
                }
                .frame(height: 110)
                .padding(.horizontal)

                // 試聴コントロールバー
                HStack(spacing: 16) {
                    if activeTab == .bgm {
                        Button(action: {
                            soundService.togglePlayBGM()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: soundService.isBGMPlaying ? "stop.fill" : "play.fill")
                                Text(soundService.isBGMPlaying ? "停止" : "BGMをループ試聴")
                                    .bold()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(soundService.generatedBGMURL == nil)
                    } else {
                        Button(action: {
                            soundService.togglePlaySE()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: soundService.isSEPlaying ? "speaker.wave.3.fill" : "play.fill")
                                Text(soundService.isSEPlaying ? "再生中..." : "SEを試聴再生")
                                    .bold()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(soundService.generatedSEURL == nil)
                    }
                }

                // 制作スタジオ連携ボタン群
                if let latest = soundService.soundHistory.first {
                    HStack(spacing: 8) {
                        Button(action: {
                            soundService.insertToSoundMaker(item: latest, trackType: latest.type == "BGM" ? "bgm" : "se")
                            alertMessage = "『\(latest.name)』をサウンドメーカーの\(latest.type == "BGM" ? "BGM" : "SE")トラックへ挿入しました！"
                            showSuccessAlert = true
                        }) {
                            Label("SoundMakerの\(latest.type)トラックへ挿入", systemImage: "timeline.selection")
                                .font(.caption)
                                .bold()
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: {
                            soundService.sendToMovieMaker(item: latest)
                            alertMessage = "『\(latest.name)』をムービーメーカーのオーディオトラックに設定しました！"
                            showSuccessAlert = true
                        }) {
                            Label("ムービーメーカーへ適用", systemImage: "film")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)

                        Button(action: {
                            soundService.saveToMaterialStudio(item: latest)
                            alertMessage = "『\(latest.name)』を素材スタジオに登録しました！"
                            showSuccessAlert = true
                        }) {
                            Label("素材スタジオ保存", systemImage: "folder.badge.plus")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)

                        Button(action: {
                            NSWorkspace.shared.activateFileViewerSelecting([latest.fileURL])
                        }) {
                            Label("Finder", systemImage: "arrow.up.right.square")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 4)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.1))

            Divider()

            // 下部: サウンド生成履歴
            bottomSoundHistoryList
        }
    }

    // MARK: - Bottom Sound History List
    private var bottomSoundHistoryList: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("生成済みサウンド履歴 (\(soundService.soundHistory.count)件):")
                    .font(.caption2)
                    .bold()
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(soundService.soundHistory) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.type == "BGM" ? "music.note" : "waveform")
                                .foregroundColor(item.type == "BGM" ? .blue : .purple)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(item.name)
                                        .font(.caption)
                                        .bold()
                                    Text("[\(item.type)]")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Text(item.detailDescription)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(String(format: "%.1fs", item.duration))
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Button(action: {
                                if item.type == "BGM" {
                                    soundService.generatedBGMURL = item.fileURL
                                    soundService.togglePlayBGM()
                                } else {
                                    soundService.generatedSEURL = item.fileURL
                                    soundService.togglePlaySE()
                                }
                            }) {
                                Image(systemName: "play.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                soundService.applyToSoundMaker(item: item)
                                alertMessage = "『\(item.name)』をサウンドメーカーへ配置しました！"
                                showSuccessAlert = true
                            }) {
                                Image(systemName: "arrow.right.circle")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("サウンドメーカーのタイムラインへ配置")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .frame(height: 160)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func visualizerBarHeight(index: Int) -> CGFloat {
        if soundService.isBGMPlaying || soundService.isSEPlaying {
            return CGFloat.random(in: 15...90)
        } else {
            return CGFloat(20 + (index % 6) * 8)
        }
    }
}
