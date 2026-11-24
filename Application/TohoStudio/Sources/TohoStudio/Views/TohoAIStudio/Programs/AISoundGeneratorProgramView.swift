import SwiftUI
import AppKit

/// 仕様書「AI BGM & SE 生成機能」プログラム (外部AI API専用モデル直結 ＆ 内蔵シンセフォールバック統合版)
public struct AISoundGeneratorProgramView: View {
    @ObservedObject var soundService = AISoundGeneratorService.shared
    @ObservedObject var tohoAIService = TohoAIService.shared
    @ObservedObject var appState = AppState.shared

    @State private var activeTab: SoundGeneratorMode = .bgm
    @State private var showSuccessAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var showScoreViewer: Bool = false
    @State private var scoreViewerAudioURL: URL? = nil

    public enum SoundGeneratorMode: String, CaseIterable, Identifiable {
        case bgm = "BGM生成 (専用音楽モデル)"
        case se = "効果音 (SE) 生成 (専用SEモデル)"

        public var id: String { rawValue }

        public var iconName: String {
            switch self {
            case .bgm: return "music.note"
            case .se: return "waveform"
            }
        }
    }

    public init() {}

    private var activeModality: AIMediaModality {
        activeTab == .bgm ? .bgm : .se
    }

    private var currentProviderBinding: Binding<AIMediaProviderType> {
        activeTab == .bgm ? $soundService.bgmProvider : $soundService.seProvider
    }

    private var currentModelBinding: Binding<String> {
        activeTab == .bgm ? $soundService.bgmModelId : $soundService.seModelId
    }

    public var body: some View {
        VStack(spacing: 0) {
            modeSegmentBar

            Divider()

            HStack(spacing: 0) {
                leftSettingsPanel
                    .frame(width: 400)

                Divider()

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
        .sheet(isPresented: $showScoreViewer) {
            ScoreViewerSheetView(initialAudioURL: scoreViewerAudioURL)
        }
    }

    // MARK: - Mode Segment Bar (外部AIプロバイダー ＆ 専用BGM/SEモデル選択バー)
    private var modeSegmentBar: some View {
        let currentProvider = currentProviderBinding.wrappedValue
        let availableModels = currentProvider.models(for: activeModality)

        return VStack(spacing: 8) {
            HStack(spacing: 12) {
                Picker("プロバイダー", selection: currentProviderBinding) {
                    ForEach(AIMediaProviderType.providers(for: activeModality)) { provider in
                        let prefix = (provider != .localBuiltIn && tohoAIService.isMediaProviderConfigured(provider)) ? "✓ " : ""
                        Label("\(prefix)\(provider.rawValue)", systemImage: provider.iconName).tag(provider)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 240)

                Picker("専用モデル", selection: currentModelBinding) {
                    ForEach(availableModels) { spec in
                        Text(spec.displayName).tag(spec.id)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 270)

                providerStatusBadge(for: currentProvider)

                Spacer()

                Button(action: {
                    tohoAIService.activeProgramTab = .externalAPI
                }) {
                    Label("APIキー管理", systemImage: "key.fill")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }

            HStack {
                Picker("", selection: $activeTab) {
                    ForEach(SoundGeneratorMode.allCases) { mode in
                        Label(mode.rawValue, systemImage: mode.iconName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 460)

                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func providerStatusBadge(for provider: AIMediaProviderType) -> some View {
        let isLocal = provider == .localBuiltIn
        let isReady = tohoAIService.isMediaProviderConfigured(provider)
        let configuredAlts = tohoAIService.configuredMediaProviders(for: activeModality)

        let badgeColor: Color
        let labelText: String
        if isLocal {
            badgeColor = .blue
            labelText = "内蔵シンセ波形合成 (APIキー不要)"
        } else if isReady {
            badgeColor = .green
            labelText = "APIキー有効・定額枠消費なし"
        } else if let alt = configuredAlts.first {
            badgeColor = .teal
            labelText = "未登録（実行時に \(alt.rawValue) へ自動切替）"
        } else {
            badgeColor = .orange
            labelText = "APIキー未登録（「APIキー管理」で設定）"
        }

        return HStack(spacing: 5) {
            Circle()
                .fill(badgeColor)
                .frame(width: 7, height: 7)
            Text(labelText)
                .font(.caption2)
                .bold()
                .foregroundColor(badgeColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.1))
        .cornerRadius(6)
    }

    // MARK: - Left Settings Panel
    private var leftSettingsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                externalAudioModelCard

                if activeTab == .bgm {
                    bgmSettingsSection
                } else {
                    seSettingsSection
                }

                Divider()

                generateButtonSection

                Spacer()
            }
            .padding(16)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - External Audio Model Card
    private var externalAudioModelCard: some View {
        let configuredList = tohoAIService.configuredMediaProviders(for: activeModality)
        let currentProv = currentProviderBinding.wrappedValue
        let currentModName = currentProv.displayName(forModelId: currentModelBinding.wrappedValue, modality: activeModality)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "waveform.badge.magnifyingglass")
                    .foregroundColor(.purple)
                Text(activeTab == .bgm ? "BGM作曲 外部AI専用モデル設定" : "効果音(SE) 外部AI専用モデル設定")
                    .font(.caption)
                    .bold()
                Spacer()
                Text("登録済API: \(configuredList.count)社")
                    .font(.caption2)
                    .bold()
                    .foregroundColor(configuredList.isEmpty ? .orange : .green)
            }

            Text("選択中: \(currentProv.rawValue) / \(currentModName)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)

            Toggle("API未登録・通信失敗時は内蔵シンセ波形合成へ自動フォールバック", isOn: $soundService.allowSynthFallback)
                .font(.caption2)

            if configuredList.isEmpty && currentProv != .localBuiltIn {
                Button(action: {
                    tohoAIService.activeProgramTab = .externalAPI
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("ElevenLabs / Stability / fal.ai / Replicate キーを登録...")
                            .font(.caption2)
                            .bold()
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.purple))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color.purple.opacity(0.07))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.purple.opacity(0.25), lineWidth: 1))
    }

    // MARK: - BGM Settings
    private var bgmSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("AI BGM プロンプト生成")
                    .font(.headline)
                Text("情景・楽器・テンポ・雰囲気を記述して外部専用モデル（ElevenLabs Music / Stable Audio 2.0 / MusicGen / Ace-Step）で作曲")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("BGMプロンプト (自由記述):")
                    .font(.caption)
                    .bold()

                TextEditor(text: $soundService.bgmPrompt)
                    .font(.system(.body, design: .default))
                    .frame(height: 115)
                    .padding(6)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))

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

            // 生成秒数スライダー
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("生成するBGMの長さ (尺):")
                        .font(.caption)
                        .bold()
                    Spacer()
                    Text("\(Int(soundService.bgmDurationSeconds)) 秒")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.blue)
                }
                Slider(value: $soundService.bgmDurationSeconds, in: 5...60, step: 1)
            }

            let inferred = soundService.analyzeBGMPrompt(soundService.bgmPrompt)
            VStack(alignment: .leading, spacing: 4) {
                Text("音響特徴・シンセフォールバック推論:")
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

    // MARK: - SE Settings
    private var seSettingsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("AI 効果音(SE) プロンプト生成")
                    .font(.headline)
                Text("欲しい効果音を記述して外部専用モデル（ElevenLabs Sound Effects / Stable Audio 2.0 / MMAudio v2 / AudioLDM 2）で生成")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("SEプロンプト (自由記述):")
                    .font(.caption)
                    .bold()

                TextEditor(text: $soundService.sePrompt)
                    .font(.system(.body, design: .default))
                    .frame(height: 115)
                    .padding(6)
                    .background(Color(NSColor.textBackgroundColor))
                    .cornerRadius(6)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        soundTagButton("スマホのチャット着信音、クリアな通知ベル", isBGM: false)
                        soundTagButton("キラキラ光る魔法効果音 シャラララン", isBGM: false)
                        soundTagButton("一眼レフカメラのシャッター音", isBGM: false)
                        soundTagButton("銃声・ピストル発砲音 バキューン", isBGM: false)
                        soundTagButton("雨と水滴のポチャン音", isBGM: false)
                        soundTagButton("激しい雷鳴と落雷バリバリ", isBGM: false)
                        soundTagButton("ジャンプ音 ピョン", isBGM: false)
                        soundTagButton("コイン獲得チャリン音", isBGM: false)
                        soundTagButton("PCキーボードの高速タイピング打鍵音", isBGM: false)
                        soundTagButton("格闘ゲームの重いパンチ打撃音", isBGM: false)
                        soundTagButton("大爆発と轟音クラッシュ", isBGM: false)
                        soundTagButton("クイズの正解チャイム (ピンポン♪)", isBGM: false)
                        soundTagButton("東方スペルカード展開の煌めくチャイム", isBGM: false)
                    }
                }
            }

            // SE生成秒数スライダー
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("生成する効果音(SE)の長さ:")
                        .font(.caption)
                        .bold()
                    Spacer()
                    Text(String(format: "%.1f 秒", soundService.seDurationSeconds))
                        .font(.caption)
                        .bold()
                        .foregroundColor(.purple)
                }
                Slider(value: $soundService.seDurationSeconds, in: 0.5...15.0, step: 0.5)
            }

            let inferred = soundService.analyzeSEPrompt(soundService.sePrompt)
            VStack(alignment: .leading, spacing: 4) {
                Text("音響特徴・シンセフォールバック推論:")
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
                let inferred = soundService.analyzeSEPrompt(text)
                soundService.seDurationSeconds = max(0.5, min(15.0, inferred.duration))
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
        let currentProv = currentProviderBinding.wrappedValue
        let modelTitle = currentProv.displayName(forModelId: currentModelBinding.wrappedValue, modality: activeModality)

        return VStack(spacing: 8) {
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
                        Text("専用モデルで音響生成中...")
                            .bold()
                    } else {
                        Image(systemName: activeTab == .bgm ? "music.quarternote.3" : "waveform.badge.plus")
                            .foregroundColor(.cyan)
                        Text(activeTab == .bgm
                             ? "BGMを生成 (\(modelTitle))"
                             : "効果音(SE)を生成 (\(modelTitle))")
                            .bold()
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                colors: activeTab == .bgm
                                    ? [Color.teal, Color.indigo]
                                    : [Color.purple, Color.indigo],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
            }
            .buttonStyle(.plain)
            .disabled(soundService.isBGMGenerating || soundService.isSEGenerating)
        }
    }

    // MARK: - Right Playback & History Panel
    private var rightPlaybackPanel: some View {
        VStack(spacing: 0) {
            // ステータスバー
            HStack(spacing: 8) {
                Circle()
                    .fill((soundService.isBGMGenerating || soundService.isSEGenerating) ? Color.orange : (soundService.currentStatusMessage.hasPrefix("⚠️") ? Color.red : Color.green))
                    .frame(width: 8, height: 8)
                Text(soundService.currentStatusMessage)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))

            Divider()

            VStack(spacing: 16) {
                Spacer()

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
                            scoreViewerAudioURL = latest.fileURL
                            showScoreViewer = true
                        }) {
                            Label("五線譜PDF楽譜化", systemImage: "music.quarternote.3")
                                .font(.caption)
                                .bold()
                        }
                        .buttonStyle(.borderedProminent)

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

                Button(action: {
                    scoreViewerAudioURL = nil
                    showScoreViewer = true
                }) {
                    Label("楽譜ビューアを開く", systemImage: "music.quarternote.3")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
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
                                scoreViewerAudioURL = item.fileURL
                                showScoreViewer = true
                            }) {
                                Image(systemName: "music.quarternote.3")
                                    .font(.title3)
                                    .foregroundColor(.purple)
                            }
                            .buttonStyle(.plain)
                            .help("この音声をBasic Pitchで自動採譜し五線譜PDFを生成")

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
