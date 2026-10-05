import SwiftUI
import AppKit
import AVFoundation

// MARK: - Logic Pro Style Colors
private struct DAWTheme {
    static let windowBackground = Color(red: 0.12, green: 0.13, blue: 0.14) // #1F2124
    static let timelineBackground = Color(red: 0.15, green: 0.16, blue: 0.17) // #26292C
    static let trackHeaderBackground = Color(red: 0.18, green: 0.19, blue: 0.21) // #2E3136
    static let trackBorder = Color(red: 0.24, green: 0.25, blue: 0.28) // #3D4047
    static let gridLine = Color.white.opacity(0.06)
    static let rulerBackground = Color(red: 0.14, green: 0.15, blue: 0.16) // #242629
    static let stripBackground = Color(red: 0.10, green: 0.11, blue: 0.12)
    static let playheadColor = Color(red: 0.22, green: 0.65, blue: 1.0) // Logic cyan
    static let meterGreen = Color(red: 0.2, green: 0.85, blue: 0.4)
    static let meterYellow = Color(red: 0.95, green: 0.8, blue: 0.2)
    static let meterRed = Color(red: 0.95, green: 0.3, blue: 0.3)
}

public struct SoundMakerView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var aquesTalk = AquesTalkBridge.shared
    @ObservedObject var soundManager = SoundMakerAudioManager.shared
    @ObservedObject var aiSoundService = AISoundGeneratorService.shared

    // AIサウンド生成ステート
    @State private var aiSoundMode: String = "bgm"
    @State private var showAIDrawer: Bool = true

    // Timeline State
    @State private var currentTime: Double = 0.0
    @State private var isPlaying: Bool = false
    @State private var playbackTimer: Timer? = nil
    @State private var zoomScale: Double = 28.0 // pixels per second
    @State private var selectedClipId: UUID? = nil
    @State private var selectedTrackId: String = "track_movie"
    @State private var showInspector: Bool = true
    @State private var showAquesTalkDrawer: Bool = false

    // Scene Selection & Editor State (シーン欄から切り替えて編集)
    @State private var selectedSceneIndex: Int = 1
    @State private var inspectorTab: String = "scene" // "scene", "region", "generator"
    @State private var showSpanAudioInsertSheet: Bool = false
    @State private var isRegeneratingVoice: Bool = false
    @State private var playingClipPreviewId: UUID? = nil

    // LCD Transport State
    @State private var tempoBPM: Int = 120
    @State private var timeSignature: String = "4/4 Cmaj"

    // AquesTalk Generator State (ゆっくりボイスメーカー準拠)
    @State private var inputSpeechText: String = "ゆっくりしていってね！"
    @State private var convertedVoiceSymbol: String = "ユックリシテイッテネ"
    @State private var speechSpeed: Int = 100
    @State private var isSynthesizing: Bool = false
    @State private var targetCharacter: String = "博麗霊夢"
    @State private var selectedEffect: AudioEffectType = .none
    @State private var selectedQuality: AudioQualitySetting = .enhanced

    // Batch Voice Generation Sheet
    @State private var showBatchVoiceGenerationSheet: Bool = false

    @State private var showHomeScreen: Bool = false
    @State private var showExportAudioSheet: Bool = false
    @State private var audioExportFormat: String = "WAV (非圧縮・最高音質)"
    @State private var audioExportScope: SoundMakerExporter.ExportScope = .masterMix
    @State private var audioExportSampleRate: Int = 44100
    @State private var audioExportBitDepth: Int = 16
    @State private var audioExportBitrate: String = "192k"
    @State private var audioExportNormalize: Bool = true
    @State private var isExportingAudio: Bool = false
    @State private var audioExportProgress: Double = 0.0
    @State private var audioExportStatusText: String = ""
    @State private var showExportAudioErrorAlert: Bool = false
    @State private var exportAudioErrorMessage: String = ""

    // Meter animation level (0.0 ... 1.0)
    @State private var currentMeterLevel: Double = 0.65

    /// 全シーン・全クリップの総尺に応じた動的タイムライン時間長
    private var totalTimelineDuration: Double {
        let scenes = activeSceneList()
        let scenesTotal = scenes.reduce(0.0) { $0 + $1.duration }
        let maxClipEnd = appState.soundClips.map { $0.startTime + $0.duration }.max() ?? 0.0
        return max(120.0, max(scenesTotal, maxClipEnd) + 15.0)
    }

    private var inspectorWidthForLayout: CGFloat {
        switch appState.layoutMode {
        case "インスペクター重視": return 400
        case "プレビュー最大化": return 380
        case "タイムライン重視": return 280
        default: return 350
        }
    }

    public init() {}

    public var body: some View {
        Group {
            if showHomeScreen {
                // 仕様書スライド 215: サウンドメーカー ホーム画面（左右にGoogle広告枠）
                SoundMakerSpecHomeView(
                    onImportMaterial: {
                        appState.currentModule = .materialStudio
                        showHomeScreen = false
                    },
                    onImportMp3: {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseFiles = true
                        panel.allowedContentTypes = [.mp3, .audio]
                        panel.message = "音声ファイル (MP3/WAV) を選択してください"
                        if panel.runModal() == .OK, let url = panel.url {
                            let asset = AVURLAsset(url: url)
                            let seconds = CMTimeGetSeconds(asset.duration)
                            let duration = (seconds.isFinite && seconds > 0.05) ? seconds : 5.0
                            let clip = SoundClip(
                                id: UUID(),
                                name: url.deletingPathExtension().lastPathComponent,
                                type: "SE",
                                duration: duration,
                                startTime: currentTime,
                                trackId: "track_se",
                                colorHex: "#33C759",
                                audioFilePath: url.path
                            )
                            appState.soundClips.append(clip)
                            showHomeScreen = false
                        }
                    },
                    onGenerateVoice: {
                        showAquesTalkDrawer = true
                        showHomeScreen = false
                    },
                    onStartEmpty: {
                        showHomeScreen = false
                    },
                    onLoadExisting: {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseFiles = true
                        panel.message = "既存のサウンドファイル (.tssm) を選択してください"
                        if panel.runModal() == .OK, let url = panel.url {
                            appState.loadSoundMakerProject(from: url)
                            showHomeScreen = false
                        }
                    }
                )
            } else {
                // 仕様書スライド 220: 編集画面（原則方針スライド246準拠: 編集画面上には一切の広告を表示しない）
                editorView
            }
        }
    }

    private var editorView: some View {
        VStack(spacing: 0) {
            // Logic Pro Style Control Bar (LCD非表示でスッキリ配置)
            dawControlBar

            Divider().background(DAWTheme.trackBorder)

            // Main Editor: Inspector (Left) + Timeline / Tracks (Right)
            HSplitView {
                if showInspector {
                    // Left Inspector & Mixer (仕様書記載のLogic Pro黒・グレー系テーマで統一)
                    dawInspectorAndMixerView
                        .frame(minWidth: 280, idealWidth: inspectorWidthForLayout, maxWidth: 450)
                        .background(DAWTheme.windowBackground)
                }

                // Center & Right: Timeline Tracks with Waveforms
                dawTimelineAreaView
                    .background(DAWTheme.timelineBackground)
            }
        }
        .background(DAWTheme.windowBackground)
        .sheet(isPresented: $showExportAudioSheet) {
            exportAudioDialog
        }
        .sheet(isPresented: $showBatchVoiceGenerationSheet) {
            BatchVoiceGenerationSheet()
        }
        .sheet(isPresented: $showSpanAudioInsertSheet) {
            SpanAudioInsertSheet(initialStartScene: selectedSceneIndex)
        }
        .alert(isPresented: $showExportAudioErrorAlert) {
            Alert(
                title: Text("音声書き出しエラー"),
                message: Text(exportAudioErrorMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            ensureDefaultTracksAndClips()
            if !appState.soundClips.isEmpty {
                let repaired = appState.resolveAndRepairAudioPaths(for: appState.soundClips)
                appState.soundClips = repaired
                appState.ensureTracksForClips(repaired)
                appState.syncClipsToMovieScenes(repaired)
            }
            if let firstClip = appState.soundClips.first {
                selectedClipId = firstClip.id
            }
            syncSelectionToLoadedProject(scenes: activeSceneList())
        }
        .onChange(of: appState.movieScenes) { newScenes in
            syncSelectionToLoadedProject(scenes: newScenes)
        }
        .onChange(of: appState.soundClips.count) { _ in
            syncSelectionToLoadedProject(scenes: activeSceneList())
        }
        .onDisappear {
            stopPlayback()
        }
    }

    // MARK: - Top Control Bar (画像指示に基づきLCD表示を削除)
    private var dawControlBar: some View {
        HStack(spacing: 12) {
            // Inspector Toggle & Title
            HStack(spacing: 10) {
                Button(action: { withAnimation(.easeInOut(duration: 0.2)) { showInspector.toggle() } }) {
                    Image(systemName: "sidebar.left")
                        .font(.system(size: 14))
                        .foregroundColor(showInspector ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help("インスペクターの表示/非表示")

                Label("サウンドメーカー", systemImage: "waveform")
                    .font(.headline)
                    .foregroundColor(.white)

                Text("DAW Studio")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.cyan)
                    .cornerRadius(4)

                Button(action: { showHomeScreen = true }) {
                    HStack(spacing: 4) {
                        Image(systemName: "house.fill")
                        Text("ホーム画面 (広告枠あり)")
                    }
                    .font(.caption2)
                }
                .buttonStyle(.bordered)
                .help("仕様書スライド215のホーム画面（Google広告枠あり）を表示します")
            }

            Spacer()

            // Transport Buttons (Rewind, Play/Pause, Stop, Record, Cycle)
            HStack(spacing: 8) {
                // Rewind to Start
                Button(action: {
                    currentTime = 0.0
                }) {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 13))
                }
                .buttonStyle(TransportButtonStyle())

                // Play / Pause
                Button(action: {
                    togglePlayback()
                }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isPlaying ? .green : .white)
                }
                .buttonStyle(TransportButtonStyle(isActive: isPlaying, activeColor: .green))

                // Stop
                Button(action: {
                    stopPlayback()
                }) {
                    Image(systemName: "square.fill")
                        .font(.system(size: 11))
                }
                .buttonStyle(TransportButtonStyle())

                // Record Arm
                Button(action: {
                    appState.log("録音待機モードが切り替えられました")
                }) {
                    Image(systemName: "circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.red)
                }
                .buttonStyle(TransportButtonStyle())

                // Loop / Cycle
                Button(action: {}) {
                    Image(systemName: "repeat")
                        .font(.system(size: 12))
                        .foregroundColor(Color(red: 0.95, green: 0.8, blue: 0.2))
                }
                .buttonStyle(TransportButtonStyle())
            }

            Spacer()

            // Zoom Controls & Import / Export
            HStack(spacing: 12) {
                // Horizontal Zoom
                HStack(spacing: 4) {
                    Image(systemName: "minus.magnifyingglass")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Slider(value: $zoomScale, in: 16...60)
                        .frame(width: 80)
                    Image(systemName: "plus.magnifyingglass")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Divider().frame(height: 18)

                // Import Slide & Scenario Menu
                Menu {
                    Button(action: { showBatchVoiceGenerationSheet = true }) {
                        Label("スライドから全音声一括生成...", systemImage: "sparkles.rectangle.stack.fill")
                    }

                    Divider()

                    Button("スライド＆シナリオファイルを選択 (.tspm / .key)...") {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseFiles = true
                        panel.canChooseDirectories = false
                        panel.message = "サウンドメーカーへインポートするスライド＆シナリオファイル (.tspm / .key) を選択してください"
                        if panel.runModal() == .OK, let url = panel.url {
                            appState.importSlideScenarioFile(from: url, targetModule: .soundMaker) { success, _ in
                                appState.log("スライドから波形トラックへ自動展開しました")
                            }
                        }
                    }
                    if !appState.slides.isEmpty {
                        Button("現在のスライド＆シナリオ (\(appState.slides.count)枚) から波形トラック生成") {
                            appState.importCurrentSlides(to: .soundMaker)
                        }
                    }
                } label: {
                    Label("スライド連携", systemImage: "arrow.down.doc")
                        .font(.caption)
                }
                .menuStyle(.borderedButton)

                // Batch Voice Generation Quick Button
                Button(action: { showBatchVoiceGenerationSheet = true }) {
                    Label("全音声一括生成", systemImage: "sparkles")
                        .font(.caption)
                        .foregroundColor(.cyan)
                }
                .buttonStyle(.bordered)
                .help("スライド＆シナリオの全セリフをゆっくりボイスで一括音声生成してタイムラインに配置")

                // ✨ AIサウンド生成 (MusicGen / SE / プロシージャル合成)
                Button(action: {
                    withAnimation {
                        showInspector = true
                        inspectorTab = "generator"
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                        Text("AIサウンド生成")
                    }
                    .font(.caption)
                    .foregroundColor(.yellow)
                }
                .buttonStyle(.bordered)
                .help("AIでBGMや効果音を作曲・生成してタイムラインに挿入します")

                // Span Audio Insert Button (複数シーン跨ぎBGM/SE挿入ポップアップ)
                Button(action: { showSpanAudioInsertSheet = true }) {
                    Label("跨ぎBGM/SE挿入...", systemImage: "arrow.triangle.merge")
                        .font(.caption)
                        .foregroundColor(Color(hex: "#DDA0DD"))
                }
                .buttonStyle(.bordered)
                .help("指定した複数のシーン区間にまたがって流れるBGMやSEをタイムラインに一括配置")

                // Export Audio
                Button(action: { showExportAudioSheet = true }) {
                    Label("書き出し", systemImage: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(Color(red: 0.16, green: 0.17, blue: 0.19))
    }



    // MARK: - LCD Display Component
    private var lcdDisplayView: some View {
        HStack(spacing: 16) {
            // Bars & Beats
            VStack(alignment: .leading, spacing: 2) {
                let bar = Int(currentTime / 2.0) + 1
                let beat = (Int(currentTime * 2.0) % 4) + 1
                let div = Int(currentTime * 8.0) % 4
                HStack(spacing: 6) {
                    Text(String(format: "%03d", bar))
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                    Text(String(format: "%d", beat))
                        .font(.system(size: 15, weight: .bold, design: .monospaced))
                    Text(String(format: "%d", div))
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                }
                .foregroundColor(.cyan)
                HStack(spacing: 16) {
                    Text("BAR").font(.system(size: 8, weight: .medium)).foregroundColor(.secondary)
                    Text("BEAT").font(.system(size: 8, weight: .medium)).foregroundColor(.secondary)
                    Text("DIV").font(.system(size: 8, weight: .medium)).foregroundColor(.secondary)
                }
            }

            Divider().frame(height: 22).background(Color.white.opacity(0.2))

            // Tempo & Time Signature
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text("\(tempoBPM)")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                    Text("KEEP")
                        .font(.system(size: 9, weight: .semibold))
                }
                .foregroundColor(.cyan)
                Text(timeSignature)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white)
            }

            Divider().frame(height: 22).background(Color.white.opacity(0.2))

            // Timecode (MM:SS.ms)
            VStack(alignment: .trailing, spacing: 2) {
                let minutes = Int(currentTime) / 60
                let seconds = Int(currentTime) % 60
                let centis = Int((currentTime.truncatingRemainder(dividingBy: 1.0)) * 100)
                Text(String(format: "%02d:%02d.%02d", minutes, seconds, centis))
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundColor(Color(red: 0.95, green: 0.8, blue: 0.2))
                Text("SMPTE TIME")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.75))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .cornerRadius(6)
    }

    // MARK: - Left Inspector & Mixer
    private var dawInspectorAndMixerView: some View {
        VStack(spacing: 0) {
            // Inspector Tab Switcher
            HStack(spacing: 4) {
                inspectorTabButton(title: "シーン編集", icon: "film.stack", tag: "scene")
                inspectorTabButton(title: "リージョン", icon: "slider.horizontal.below.rectangle", tag: "region")
                inspectorTabButton(title: "AI & 音声生成", icon: "sparkles", tag: "generator")
                inspectorTabButton(title: "ミキサー", icon: "slider.vertical.3", tag: "mixer")
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(red: 0.14, green: 0.15, blue: 0.17))

            Divider().background(DAWTheme.trackBorder)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 12) {
                    // Movie Scene Preview (プレビューは共通で上部に配置)
                    sceneMoviePreviewCard

                    if inspectorTab == "scene" {
                        // 🎬 シーン別オーディオ編集 (キャラ音声、BGM、SE)
                        sceneAudioEditorCard
                    } else if inspectorTab == "region" {
                        // 🎚️ 選択リージョン情報
                        regionInspectorCard
                        dualChannelStripView
                    } else if inspectorTab == "generator" {
                        // ✨ AI BGM & 効果音 作曲・生成
                        aiSoundGeneratorCard
                        // 🎙️ AquesTalk クイック生成
                        aquesTalkQuickGeneratorCard
                        regionInspectorCard
                    } else if inspectorTab == "mixer" {
                        // 🎛️ フルミキサーチャンネルストリップ
                        dualChannelStripView
                    }
                }
                .padding(10)
            }
        }
    }

    private func inspectorTabButton(title: String, icon: String, tag: String) -> some View {
        let isSelected = inspectorTab == tag
        return Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                inspectorTab = tag
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(title)
                    .font(.system(size: 10, weight: isSelected ? .bold : .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
            .background(isSelected ? Color.cyan.opacity(0.25) : Color.white.opacity(0.06))
            .foregroundColor(isSelected ? .cyan : .white.opacity(0.8))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isSelected ? Color.cyan.opacity(0.6) : DAWTheme.trackBorder, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Scene Audio Editor Card (シーン欄連動のキャラ音声・BGM・SE編集パネル)
    private var sceneAudioEditorCard: some View {
        let scenes = activeSceneList()
        let currentScene = (selectedSceneIndex >= 1 && selectedSceneIndex <= scenes.count) ? scenes[selectedSceneIndex - 1] : scenes.first
        let sRange = sceneTimeRange(index: max(0, min(selectedSceneIndex - 1, scenes.count - 1)))
        let sDuration = sRange.end - sRange.start
        let vClips = voiceClips(for: selectedSceneIndex)
        let bClips = bgmClips(for: selectedSceneIndex)
        let sClips = seClips(for: selectedSceneIndex)

        return VStack(alignment: .leading, spacing: 10) {
            // Scene Navigation Header
            HStack(spacing: 6) {
                // Prev Scene Button
                Button(action: {
                    if selectedSceneIndex > 1 {
                        selectScene(index: selectedSceneIndex - 1)
                    }
                }) {
                    Image(systemName: "chevron.left.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(selectedSceneIndex > 1 ? .cyan : Color.white.opacity(0.2))
                }
                .buttonStyle(.plain)
                .disabled(selectedSceneIndex <= 1)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 6) {
                        Text("シーン \(selectedSceneIndex) / \(scenes.count)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Text(String(format: "%.1fs (%.1fs〜%.1fs)", sDuration, sRange.start, sRange.end))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    if let note = currentScene?.animationNote ?? currentActiveSlide()?.animationTimingNote {
                        HStack(spacing: 4) {
                            Image(systemName: "film.stack.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.orange)
                            Text("🎬 \(note) に合わせて表示")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.orange)
                        }
                    } else if let animDur = currentScene?.animationDuration ?? currentActiveSlide()?.animationTimingDuration {
                        HStack(spacing: 4) {
                            Image(systemName: "film.stack.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.orange)
                            Text("🎬 アニメーション: \(String(format: "%.1f", animDur))秒に合わせて表示")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundColor(.orange)
                        }
                    }
                    Text(currentScene?.displayCleanTitle ?? "タイトルなし")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                // Next Scene Button
                Button(action: {
                    if selectedSceneIndex < scenes.count {
                        selectScene(index: selectedSceneIndex + 1)
                    }
                }) {
                    Image(systemName: "chevron.right.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(selectedSceneIndex < scenes.count ? .cyan : Color.white.opacity(0.2))
                }
                .buttonStyle(.plain)
                .disabled(selectedSceneIndex >= scenes.count)
            }
            .padding(8)
            .background(Color(red: 0.16, green: 0.17, blue: 0.19))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(DAWTheme.trackBorder, lineWidth: 1)
            )

            Divider().background(DAWTheme.trackBorder)

            // ① キャラクター音声セクション (Voice)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("キャラ音声 (\(vClips.count)件)", systemImage: "person.wave.2.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button(action: {
                        addVoiceClipToCurrentScene()
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: "plus.circle.fill")
                            Text("音声追加")
                        }
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.cyan)
                    }
                    .buttonStyle(.plain)
                }

                if vClips.isEmpty {
                    VStack(spacing: 4) {
                        Text("このシーンには音声がありません")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Button(action: { showBatchVoiceGenerationSheet = true }) {
                            Text("スライドから全音声一括生成...")
                                .font(.caption2)
                                .foregroundColor(.cyan)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                    .background(Color(red: 0.13, green: 0.14, blue: 0.16))
                    .cornerRadius(4)
                } else {
                    ForEach(vClips) { clip in
                        sceneVoiceClipRow(clip: clip)
                    }
                }
            }
            .padding(8)
            .background(Color(red: 0.16, green: 0.17, blue: 0.19))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(DAWTheme.trackBorder, lineWidth: 1)
            )

            // ② BGMセクション (ファイル読み込み画面で読み込む)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("BGM (\(bClips.count)件)", systemImage: "music.note")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()

                    Menu {
                        Button(action: {
                            selectAudioFileViaOpenPanel(type: "BGM")
                        }) {
                            Label("音楽ファイルを選択して配置 (.wav / .mp3 / .m4a)...", systemImage: "doc.badge.plus")
                        }

                        Button(action: {
                            showSpanAudioInsertSheet = true
                        }) {
                            Label("複数シーン跨ぎBGM設定...", systemImage: "arrow.triangle.merge")
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "folder.badge.plus")
                            Text("BGM読み込み")
                        }
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color.purple)
                    }
                    .menuStyle(.borderlessButton)
                    .help("編集ファイル読み込み時のようにファイル選択画面からBGMを読み込んでこのシーンに配置")
                }

                if bClips.isEmpty {
                    VStack(spacing: 4) {
                        Text("このシーンで再生中のBGMはありません")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Button(action: {
                            selectAudioFileViaOpenPanel(type: "BGM")
                        }) {
                            Text("ファイルからBGMを選択して読み込む...")
                                .font(.caption2)
                                .foregroundColor(Color.purple)
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.13, green: 0.14, blue: 0.16))
                    .cornerRadius(4)
                } else {
                    ForEach(bClips) { bgm in
                        sceneBgmClipRow(clip: bgm)
                    }
                }
            }
            .padding(8)
            .background(Color(red: 0.16, green: 0.17, blue: 0.19))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(DAWTheme.trackBorder, lineWidth: 1)
            )

            // ③ SE (効果音) セクション (ファイル読み込み画面で読み込む)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("効果音 / SE (\(sClips.count)件)", systemImage: "bolt.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()

                    Menu {
                        Button(action: {
                            selectAudioFileViaOpenPanel(type: "SE")
                        }) {
                            Label("効果音ファイルを選択して配置 (.wav / .mp3)...", systemImage: "doc.badge.plus")
                        }

                        Divider()

                        Button("プリセット: 決定音") { addPresetSE(name: "SE: 決定音") }
                        Button("プリセット: キャンセル音") { addPresetSE(name: "SE: キャンセル音") }
                        Button("プリセット: 打撃・衝突音") { addPresetSE(name: "SE: 打撃音") }
                        Button("プリセット: 弾幕・魔法発動") { addPresetSE(name: "SE: 弾幕魔法音") }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "folder.badge.plus")
                            Text("SE読み込み")
                        }
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(Color(red: 0.1, green: 0.8, blue: 0.3))
                    }
                    .menuStyle(.borderlessButton)
                    .help("編集ファイル読み込み時のようにファイル選択画面からSEを読み込んでこのシーンに配置")
                }

                if sClips.isEmpty {
                    VStack(spacing: 4) {
                        Text("このシーンで鳴る効果音はありません")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Button(action: {
                            selectAudioFileViaOpenPanel(type: "SE")
                        }) {
                            Text("ファイルからSEを選択して読み込む...")
                                .font(.caption2)
                                .foregroundColor(Color(red: 0.1, green: 0.8, blue: 0.3))
                        }
                        .buttonStyle(.plain)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 6)
                    .background(Color(red: 0.13, green: 0.14, blue: 0.16))
                    .cornerRadius(4)
                } else {
                    ForEach(sClips) { se in
                        sceneSeClipRow(clip: se)
                    }
                }
            }
            .padding(8)
            .background(Color(red: 0.16, green: 0.17, blue: 0.19))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(DAWTheme.trackBorder, lineWidth: 1)
            )
        }
    }

    // MARK: - Scene Voice Clip Row
    private func sceneVoiceClipRow(clip: SoundClip) -> some View {
        let isSelected = selectedClipId == clip.id
        let charName = clip.character ?? "博麗霊夢"
        let charColor = Color(hex: clip.colorHex ?? "#E74C3C")
        let isPlayingThis = playingClipPreviewId == clip.id

        return VStack(alignment: .leading, spacing: 6) {
            // Header: Character badge, VoiceType, Preview, Regenerate, Delete
            HStack(spacing: 6) {
                Circle().fill(charColor).frame(width: 8, height: 8)
                Text(charName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)

                // VoiceType Picker
                Picker("", selection: Binding(
                    get: { clip.voiceType ?? aquesTalk.voiceType(for: charName) },
                    set: { newV in
                        if let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) {
                            appState.soundClips[idx].voiceType = newV
                        }
                    }
                )) {
                    ForEach(VoiceType.allCases) { v in
                        Text(v.displayShortName).tag(v)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 90)

                Spacer()

                // Play / Stop Preview
                Button(action: {
                    togglePlayVoiceClip(clip)
                }) {
                    Image(systemName: isPlayingThis ? "stop.fill" : "play.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(isPlayingThis ? .green : .cyan)
                }
                .buttonStyle(.plain)
                .help("この音声を試聴")

                // Regenerate Voice Button (⚡️ 再生成)
                Button(action: {
                    regenerateVoiceClip(clip)
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: "bolt.fill")
                        Text("再生成")
                    }
                    .font(.system(size: 8, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15))
                    .foregroundColor(.orange)
                    .cornerRadius(3)
                }
                .buttonStyle(.plain)
                .help("現在のセリフ・声種・速度でAquesTalk音声を再生成")

                // Delete Clip
                Button(action: {
                    deleteClip(clip)
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("音声を削除")
            }

            // Dialogue Text Field (その場で直接セリフ編集可能)
            TextField(
                "セリフ",
                text: Binding(
                    get: { clip.text ?? clip.name },
                    set: { newText in
                        if let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) {
                            appState.soundClips[idx].text = newText
                            appState.soundClips[idx].name = "[\(charName)] \(newText)"
                            appState.soundClips[idx].voiceSymbol = aquesTalk.convertToVoiceSymbol(text: newText)
                        }
                    }
                )
            )
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 11))

            // Speed & Pitch & Volume Sliders
            HStack(spacing: 8) {
                // Speed (速度)
                HStack(spacing: 2) {
                    Text("速:").font(.system(size: 9)).foregroundColor(.secondary)
                    Slider(
                        value: Binding(
                            get: { Double(clip.speed) },
                            set: { val in
                                if let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) {
                                    appState.soundClips[idx].speed = Int(val)
                                }
                            }
                        ),
                        in: 50...200,
                        step: 5
                    )
                    Text("\(clip.speed)%").font(.system(size: 8, design: .monospaced)).foregroundColor(Color(hex: "#0066CC"))
                }

                // Pitch (音程) - レミリア等キャラクターの高音・低音調整
                HStack(spacing: 2) {
                    Text("高:").font(.system(size: 9)).foregroundColor(.secondary)
                    Slider(
                        value: Binding(
                            get: { Double(clip.pitch) },
                            set: { val in
                                if let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) {
                                    appState.soundClips[idx].pitch = Int(val)
                                }
                            }
                        ),
                        in: 50...200,
                        step: 5
                    )
                    Text("\(clip.pitch)%").font(.system(size: 8, design: .monospaced)).foregroundColor(.orange)
                }

                // Volume (音量)
                HStack(spacing: 2) {
                    Text("音:").font(.system(size: 9)).foregroundColor(.secondary)
                    Slider(
                        value: Binding(
                            get: { clip.volume },
                            set: { val in
                                if let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) {
                                    appState.soundClips[idx].volume = val
                                }
                            }
                        ),
                        in: 0...1.0
                    )
                    Text("\(Int(clip.volume * 100))%").font(.system(size: 8, design: .monospaced)).foregroundColor(Color(hex: "#0066CC"))
                }
            }

            // Audio File Badge (実音声ファイルの割り当て表示)
            HStack(spacing: 4) {
                if let p = clip.audioFilePath, FileManager.default.fileExists(atPath: p) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 8))
                    Text("音声: \((p as NSString).lastPathComponent)")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.primary)
                        .lineLimit(1)
                } else {
                    Image(systemName: "waveform")
                        .foregroundColor(.orange)
                        .font(.system(size: 8))
                    Text("AquesTalk音声記号 (自動発音)")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(String(format: "%.2fs", clip.duration))
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.cyan)
            }
            .padding(.top, 2)
        }
        .padding(6)
        .background(isSelected ? Color.cyan.opacity(0.18) : Color(red: 0.13, green: 0.14, blue: 0.16))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? Color.cyan : DAWTheme.trackBorder, lineWidth: 1)
        )
        .onTapGesture {
            selectedClipId = clip.id
        }
    }

    // MARK: - Scene BGM Clip Row
    private func sceneBgmClipRow(clip: SoundClip) -> some View {
        let isSpanning = clip.isSpanningScenes
        let isSelected = selectedClipId == clip.id
        let isPlayingThis = soundManager.currentlyPlayingClipId == clip.id && soundManager.isPreviewPlaying

        return VStack(alignment: .leading, spacing: 6) {
            // Header: Play Button, Icon, Title, Spanning Badge, Delete
            HStack(spacing: 6) {
                // Play / Stop Button (試聴プレビュー)
                Button(action: {
                    soundManager.togglePreview(clip: clip)
                }) {
                    Image(systemName: isPlayingThis ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(isPlayingThis ? .purple : Color.purple.opacity(0.85))
                }
                .buttonStyle(.plain)
                .help(isPlayingThis ? "再生を停止" : "このBGMを倍速・逆再生設定で試聴再生")

                Image(systemName: "music.note")
                    .font(.system(size: 11))
                    .foregroundColor(.purple)

                Text(clip.name)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                // Spanning badge
                if isSpanning, let start = clip.spanStartSceneIndex, let end = clip.spanEndSceneIndex {
                    Text("★ S\(start)〜S\(end) 跨ぎ")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.15))
                        .foregroundColor(.purple)
                        .cornerRadius(3)
                }

                // Delete Button
                Button(action: {
                    deleteClip(clip)
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            // Controls: 倍速再生セレクター & 逆再生トグル & ループ
            HStack(spacing: 6) {
                // 倍速再生セレクター (Playback Speed Menu)
                Menu {
                    ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                        Button(action: {
                            if let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) {
                                appState.soundClips[idx].playbackRate = rate
                                if isPlayingThis {
                                    soundManager.playPreview(clip: appState.soundClips[idx])
                                }
                            }
                        }) {
                            HStack {
                                Text(String(format: "%.2fx %@", rate, rate == 1.0 ? "(標準)" : ""))
                                if clip.playbackRate == rate {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "gauge.with.needle")
                        Text(String(format: "%.2fx", clip.playbackRate))
                    }
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(clip.playbackRate != 1.0 ? Color.purple.opacity(0.25) : Color.white.opacity(0.06))
                    .foregroundColor(clip.playbackRate != 1.0 ? Color(hex: "#DDA0DD") : .white)
                    .cornerRadius(3)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("BGMの再生速度（倍速）を変更")

                // 逆再生トグルボタン (Reverse Playback Toggle)
                Button(action: {
                    if let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) {
                        appState.soundClips[idx].isReversed.toggle()
                        if isPlayingThis {
                            soundManager.playPreview(clip: appState.soundClips[idx])
                        }
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.uturn.backward")
                        Text(clip.isReversed ? "逆再生 ON" : "逆再生")
                    }
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(clip.isReversed ? Color.orange.opacity(0.25) : Color.white.opacity(0.06))
                    .foregroundColor(clip.isReversed ? .orange : .secondary)
                    .cornerRadius(3)
                }
                .buttonStyle(.plain)
                .help(clip.isReversed ? "逆再生中（クリックで通常再生に戻す）" : "BGMを逆再生（リバース）する")

                // ループ再生トグル
                Button(action: {
                    if let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) {
                        appState.soundClips[idx].isLooping.toggle()
                    }
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: "repeat")
                        if clip.isLooping {
                            Text("LOOP").font(.system(size: 8, weight: .bold))
                        }
                    }
                    .font(.system(size: 9))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(clip.isLooping ? Color.purple.opacity(0.25) : Color.white.opacity(0.06))
                    .foregroundColor(clip.isLooping ? .purple : .secondary)
                    .cornerRadius(3)
                }
                .buttonStyle(.plain)

                Spacer()
            }

            // Volume Slider & Fades
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    Text("音量:").font(.system(size: 9)).foregroundColor(.secondary)
                    Slider(
                        value: Binding(
                            get: { clip.volume },
                            set: { val in
                                if let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) {
                                    appState.soundClips[idx].volume = val
                                }
                            }
                        ),
                        in: 0...1.0
                    )
                    Text("\(Int(clip.volume * 100))%").font(.system(size: 8, design: .monospaced)).foregroundColor(.cyan)
                }

                if clip.fadeInDuration > 0 || clip.fadeOutDuration > 0 {
                    HStack(spacing: 4) {
                        Text("FI:\(clip.fadeInDuration, specifier: "%.1f")s").font(.system(size: 8)).foregroundColor(.secondary)
                        Text("FO:\(clip.fadeOutDuration, specifier: "%.1f")s").font(.system(size: 8)).foregroundColor(.secondary)
                    }
                }
            }

            // BGM File Badge
            HStack(spacing: 4) {
                if let p = clip.audioFilePath, FileManager.default.fileExists(atPath: p) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 8))
                    Text("BGM音源: \((p as NSString).lastPathComponent)")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.purple)
                        .lineLimit(1)
                } else {
                    Image(systemName: "music.note")
                        .foregroundColor(.orange)
                        .font(.system(size: 8))
                    Text("プリセットBGM音源")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(String(format: "%.1fs", clip.duration))
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 2)
        }
        .padding(6)
        .background(isSelected ? Color.purple.opacity(0.20) : Color(red: 0.13, green: 0.14, blue: 0.16))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? Color.purple : DAWTheme.trackBorder, lineWidth: 1)
        )
        .onTapGesture {
            selectedClipId = clip.id
        }
    }

    // MARK: - Scene SE Clip Row
    private func sceneSeClipRow(clip: SoundClip) -> some View {
        let isSelected = selectedClipId == clip.id
        let isPlayingThis = soundManager.currentlyPlayingClipId == clip.id && soundManager.isPreviewPlaying
        let sRange = sceneTimeRange(index: max(0, selectedSceneIndex - 1))
        let sceneDuration = max(0.1, sRange.end - sRange.start)
        let isExceedingScene = clip.effectiveDuration > (sceneDuration + 0.05)

        return VStack(alignment: .leading, spacing: 6) {
            // Header: Preview Button, Icon, Title, Duration, Exceeding Warning, Delete
            HStack(spacing: 6) {
                // Preview Play Button (SoundMakerAudioManager で本物のSE音を流す: 即切りシミュレート付き)
                Button(action: {
                    soundManager.togglePreview(clip: clip, sceneDuration: sceneDuration)
                }) {
                    Image(systemName: isPlayingThis ? "stop.circle.fill" : "play.circle.fill")
                        .font(.system(size: 15))
                        .foregroundColor(isPlayingThis ? .green : Color(red: 0.1, green: 0.8, blue: 0.3))
                }
                .buttonStyle(.plain)
                .help(isPlayingThis ? "再生を停止" : "この効果音を倍速・逆再生・フェード・即切り設定で試聴再生")

                Image(systemName: "bolt.fill")
                    .font(.system(size: 10))
                    .foregroundColor(Color(red: 0.1, green: 0.8, blue: 0.3))

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(clip.name)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)

                        if clip.isCutOffOnSceneEnd {
                            HStack(spacing: 2) {
                                Image(systemName: "scissors")
                                    .font(.system(size: 7))
                                Text("即切り")
                                    .font(.system(size: 7, weight: .bold))
                            }
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.cyan.opacity(0.25))
                            .foregroundColor(.cyan)
                            .cornerRadius(3)
                        }
                    }

                    HStack(spacing: 4) {
                        Text(String(format: "実効長: %.2fs", clip.effectiveDuration))
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)

                        if isExceedingScene {
                            Text("(シーン: \(String(format: "%.1f", sceneDuration))s)")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundColor(.orange)
                        }
                    }
                }

                Spacer()

                // Delete
                Button(action: {
                    deleteClip(clip)
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("この効果音を削除")
            }

            // シーン長超過警告バッジ & 即切り案内
            if isExceedingScene {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.orange)
                    Text("効果音の長さがシーン長を超過しています")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.orange)
                    Spacer()
                    Text(clip.isCutOffOnSceneEnd ? "✂️ シーン切替時に即切り" : "⚠️ 次シーンへ鳴り継続")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(clip.isCutOffOnSceneEnd ? .cyan : .orange)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.orange.opacity(0.12))
                .cornerRadius(3)
            }

            // Controls 1: 即切りトグル & フェードイン (FI) & フェードアウト (FO)
            HStack(spacing: 6) {
                // シーン終了時 即切りトグルボタン
                Button(action: {
                    if let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) {
                        appState.soundClips[idx].isCutOffOnSceneEnd.toggle()
                        let newState = appState.soundClips[idx].isCutOffOnSceneEnd
                        appState.log("SE『\(clip.name)』のシーン切替時即切りを \(newState ? "有効 (ON)" : "無効 (OFF)") に設定しました")
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: clip.isCutOffOnSceneEnd ? "scissors" : "scissors.badge.ellipsis")
                            .font(.system(size: 8))
                        Text(clip.isCutOffOnSceneEnd ? "即切り: ON" : "即切り: OFF")
                            .font(.system(size: 8, weight: .bold))
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(clip.isCutOffOnSceneEnd ? Color.cyan.opacity(0.25) : Color.white.opacity(0.06))
                    .foregroundColor(clip.isCutOffOnSceneEnd ? .cyan : .secondary)
                    .cornerRadius(3)
                }
                .buttonStyle(.plain)
                .help("シーンの長さより効果音が長い場合に、シーン切り替えと同時に即座に再生を停止（即切り）します")

                // フェードイン (FI) 設定メニュー
                Menu {
                    ForEach([0.0, 0.1, 0.2, 0.5, 1.0, 1.5, 2.0], id: \.self) { fi in
                        Button(action: {
                            if let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) {
                                appState.soundClips[idx].fadeInDuration = fi
                                appState.log("SE『\(clip.name)』のフェードイン時間を \(String(format: "%.1f", fi))秒に設定しました")
                            }
                        }) {
                            HStack {
                                Text(fi == 0.0 ? "フェードインなし (0.0s)" : String(format: "%.1f 秒", fi))
                                if abs(clip.fadeInDuration - fi) < 0.01 {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 7))
                        Text("FI: \(clip.fadeInDuration, specifier: "%.1f")s")
                    }
                    .font(.system(size: 8, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(clip.fadeInDuration > 0 ? Color.cyan.opacity(0.25) : Color.white.opacity(0.06))
                    .foregroundColor(clip.fadeInDuration > 0 ? .cyan : .secondary)
                    .cornerRadius(3)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("効果音のフェードイン秒数を設定（シーン跨ぎSEと同様に設定可能）")

                // フェードアウト (FO) 設定メニュー
                Menu {
                    ForEach([0.0, 0.1, 0.2, 0.5, 1.0, 1.5, 2.0, 3.0], id: \.self) { fo in
                        Button(action: {
                            if let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) {
                                appState.soundClips[idx].fadeOutDuration = fo
                                appState.log("SE『\(clip.name)』のフェードアウト時間を \(String(format: "%.1f", fo))秒に設定しました")
                            }
                        }) {
                            HStack {
                                Text(fo == 0.0 ? "フェードアウトなし (0.0s)" : String(format: "%.1f 秒", fo))
                                if abs(clip.fadeOutDuration - fo) < 0.01 {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "chart.line.downtrend.xyaxis")
                            .font(.system(size: 7))
                        Text("FO: \(clip.fadeOutDuration, specifier: "%.1f")s")
                    }
                    .font(.system(size: 8, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(clip.fadeOutDuration > 0 ? Color.purple.opacity(0.25) : Color.white.opacity(0.06))
                    .foregroundColor(clip.fadeOutDuration > 0 ? Color(hex: "#DDA0DD") : .secondary)
                    .cornerRadius(3)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("効果音のフェードアウト秒数を設定（シーン跨ぎSEと同様に設定可能）")

                Spacer()
            }

            // Controls 2: 倍速再生セレクター & 逆再生トグル & 音量スライダー
            HStack(spacing: 6) {
                // 倍速再生セレクター
                Menu {
                    ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                        Button(action: {
                            if let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) {
                                appState.soundClips[idx].playbackRate = rate
                                if isPlayingThis {
                                    soundManager.playPreview(clip: appState.soundClips[idx], sceneDuration: sceneDuration)
                                }
                            }
                        }) {
                            HStack {
                                Text(String(format: "%.2fx %@", rate, rate == 1.0 ? "(標準)" : ""))
                                if clip.playbackRate == rate {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 2) {
                        Image(systemName: "gauge.with.needle")
                        Text(String(format: "%.2fx", clip.playbackRate))
                    }
                    .font(.system(size: 8, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(clip.playbackRate != 1.0 ? Color.green.opacity(0.25) : Color.white.opacity(0.06))
                    .foregroundColor(clip.playbackRate != 1.0 ? Color(red: 0.1, green: 0.8, blue: 0.3) : .white)
                    .cornerRadius(3)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .help("SEの再生速度（倍速）を変更")

                // 逆再生トグル
                Button(action: {
                    if let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) {
                        appState.soundClips[idx].isReversed.toggle()
                        if isPlayingThis {
                            soundManager.playPreview(clip: appState.soundClips[idx], sceneDuration: sceneDuration)
                        }
                    }
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: "arrow.uturn.backward")
                        Text(clip.isReversed ? "逆再生 ON" : "逆再生")
                    }
                    .font(.system(size: 8, weight: .bold))
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(clip.isReversed ? Color.orange.opacity(0.25) : Color.white.opacity(0.06))
                    .foregroundColor(clip.isReversed ? .orange : .secondary)
                    .cornerRadius(3)
                }
                .buttonStyle(.plain)
                .help(clip.isReversed ? "逆再生中（クリックで通常再生に戻す）" : "効果音を逆再生（リバース効果音）にする")

                Spacer()

                // Volume mini slider
                HStack(spacing: 2) {
                    Text("音量:").font(.system(size: 8)).foregroundColor(.secondary)
                    Slider(
                        value: Binding(
                            get: { clip.volume },
                            set: { val in
                                if let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) {
                                    appState.soundClips[idx].volume = val
                                }
                            }
                        ),
                        in: 0...1.0
                    )
                    .frame(width: 45)
                    Text("\(Int(clip.volume * 100))%").font(.system(size: 7, design: .monospaced)).foregroundColor(.cyan)
                }
            }

            // SE File Badge
            HStack(spacing: 4) {
                if let p = clip.audioFilePath, FileManager.default.fileExists(atPath: p) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 8))
                    Text("効果音: \((p as NSString).lastPathComponent)")
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(Color(red: 0.1, green: 0.8, blue: 0.3))
                        .lineLimit(1)
                } else {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 8))
                    Text("プリセットSE音源")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text(String(format: "%.2fs", clip.duration))
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 2)
        }
        .padding(6)
        .background(isSelected ? Color.green.opacity(0.20) : Color(red: 0.13, green: 0.14, blue: 0.16))
        .cornerRadius(4)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? Color(red: 0.1, green: 0.8, blue: 0.3) : DAWTheme.trackBorder, lineWidth: 1)
        )
        .onTapGesture {
            selectedClipId = clip.id
        }
    }

    // MARK: - Scene Movie Preview Card (アニメーション付きムービープレビュー)
    private var sceneMoviePreviewCard: some View {
        let activeScene = currentActiveScene()
        let activeSlide = currentActiveSlide()

        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label("ムービープレビュー", systemImage: "film")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)

                if isPlaying {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 6, height: 6)
                        Text("再生中")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.15))
                    .cornerRadius(3)
                }

                Spacer()

                if let scene = activeScene {
                    Text("S\(sceneIndex(for: scene)): 16:9 HD")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundColor(.cyan)
                } else {
                    Text("16:9 HD")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(red: 0.12, green: 0.13, blue: 0.15))
                    .aspectRatio(16/9, contentMode: .fit)

                // 1. Keynote Native Recorded Movie Player
                if let videoPath = activeSlide?.animationVideoPath, FileManager.default.fileExists(atPath: videoPath) {
                    SlideVideoPlayerView(videoPath: videoPath)
                        .id(videoPath)
                        .aspectRatio(16/9, contentMode: .fit)
                        .cornerRadius(6)
                        .clipped()
                } else if let slidePath = activeSlide?.slideImagePath,
                          let slideImg = resolveImage(path: slidePath, name: nil, subfolder: nil) {
                    // 2. High-Resolution Slide Image (Keynote Native) with animated breathing & ambient glow
                    TimelineView(.animation) { timeline in
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        let pulse = isPlaying ? (sin(time * 2.5) * 0.02 + 1.01) : 1.0

                        ZStack {
                            Image(nsImage: slideImg)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .scaleEffect(pulse)

                            if isPlaying {
                                LinearGradient(
                                    colors: [Color.cyan.opacity(0.06), Color.clear, Color.purple.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .blendMode(.screen)
                            }
                        }
                    }
                    .cornerRadius(6)
                    .clipped()
                } else {
                    // 3. Layer Render (Background + Character + Motion animation)
                    let bgImg = resolveImage(path: activeSlide?.backgroundImagePath, name: activeSlide?.backgroundName ?? activeScene?.backgroundName, subfolder: "背景")
                    let charImg = resolveImage(path: activeSlide?.characterImagePath, name: activeSlide?.characterName ?? activeScene?.characterName, subfolder: "立ち絵")

                    TimelineView(.animation) { timeline in
                        let time = timeline.date.timeIntervalSinceReferenceDate
                        let charBounce = isPlaying ? sin(time * 6.0) * 3.5 : sin(time * 1.8) * 1.2

                        ZStack {
                            // Background
                            if let bg = bgImg {
                                Image(nsImage: bg)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipped()
                            } else {
                                LinearGradient(
                                    colors: [Color(red: 0.18, green: 0.19, blue: 0.22), Color(red: 0.10, green: 0.11, blue: 0.13)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            }

                            // Character with breathing/lip-sync bounce
                            if let ch = charImg {
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Image(nsImage: ch)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(maxHeight: 110)
                                            .offset(y: charBounce)
                                            .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
                                        Spacer()
                                    }
                                }
                            } else {
                                VStack(spacing: 4) {
                                    Image(systemName: "film.stack.fill")
                                        .font(.system(size: 24))
                                        .foregroundColor(Color.cyan.opacity(0.85))
                                        .rotationEffect(.degrees(isPlaying ? (time * 60).truncatingRemainder(dividingBy: 360) : 0))
                                    if let scene = activeScene {
                                        Text(scene.title)
                                            .font(.system(size: 11, weight: .bold))
                                            .foregroundColor(.white)
                                    }
                                }
                            }
                        }
                    }
                    .cornerRadius(6)
                    .clipped()
                }

                // Subtitle Overlay (テロップ字幕)
                if let scene = activeScene, !scene.telop.isEmpty {
                    VStack {
                        Spacer()
                        Text(scene.displayTelop.isEmpty ? scene.telop : scene.displayTelop)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.75))
                            .cornerRadius(4)
                            .padding(.horizontal, 6)
                            .padding(.bottom, 6)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isPlaying ? Color.blue : Color.gray.opacity(0.25), lineWidth: 1)
            )
        }
        .padding(8)
        .background(Color(red: 0.16, green: 0.17, blue: 0.19))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(DAWTheme.trackBorder, lineWidth: 1)
        )
    }

    // MARK: - Region Inspector Card
    private var regionInspectorCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("リージョン情報", systemImage: "slider.horizontal.below.rectangle")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                if let clip = selectedClip() {
                    Text(clip.type)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(colorForType(clip.type).opacity(0.25))
                        .foregroundColor(colorForType(clip.type))
                        .cornerRadius(3)
                }
            }

            if let clip = selectedClip() {
                VStack(spacing: 6) {
                    HStack {
                        Text("名前:").font(.caption2).foregroundColor(Color(white: 0.7))
                        Spacer()
                        Text(clip.name).font(.caption2).bold().foregroundColor(.white).lineLimit(1)
                    }
                    HStack {
                        Text("開始位置:").font(.caption2).foregroundColor(Color(white: 0.7))
                        Spacer()
                        Text(String(format: "%.2f s", clip.startTime)).font(.caption2).foregroundColor(.white)
                    }
                    HStack {
                        Text("長さ:").font(.caption2).foregroundColor(Color(white: 0.7))
                        Spacer()
                        Text(String(format: "%.2f s", clip.duration)).font(.caption2).foregroundColor(.white)
                    }
                    if let text = clip.text, !text.isEmpty {
                        HStack(alignment: .top) {
                            Text("セリフ:").font(.caption2).foregroundColor(Color(white: 0.7))
                            Spacer()
                            Text(text)
                                .font(.caption2)
                                .foregroundColor(.cyan)
                                .lineLimit(2)
                                .multilineTextAlignment(.trailing)
                        }
                    }

                    Divider().background(DAWTheme.trackBorder).padding(.vertical, 2)

                    // BGM / SE / 音声 再生コントロール
                    let isPlayingThis = soundManager.currentlyPlayingClipId == clip.id && soundManager.isPreviewPlaying
                    HStack {
                        Button(action: {
                            soundManager.togglePreview(clip: clip)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: isPlayingThis ? "stop.fill" : "play.fill")
                                Text(isPlayingThis ? "停止" : "試聴再生")
                            }
                            .font(.caption2.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(isPlayingThis ? Color.red : Color.cyan.opacity(0.8))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)

                        Spacer()

                        // 逆再生トグル
                        Button(action: {
                            if let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) {
                                appState.soundClips[idx].isReversed.toggle()
                                if isPlayingThis {
                                    soundManager.playPreview(clip: appState.soundClips[idx])
                                }
                            }
                        }) {
                            HStack(spacing: 2) {
                                Image(systemName: "arrow.uturn.backward")
                                Text(clip.isReversed ? "逆再生 ON" : "逆再生")
                            }
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(clip.isReversed ? Color.orange.opacity(0.3) : Color.white.opacity(0.08))
                            .foregroundColor(clip.isReversed ? .orange : Color(white: 0.8))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }

                    // 倍速再生スライダー & プリセット
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("再生速度 (倍速):").font(.caption2).foregroundColor(Color(white: 0.7))
                            Spacer()
                            Text(String(format: "%.2fx", clip.playbackRate))
                                .font(.caption2.bold())
                                .foregroundColor(clip.playbackRate != 1.0 ? .cyan : .white)
                        }

                        HStack(spacing: 4) {
                            ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                                Button(action: {
                                    if let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) {
                                        appState.soundClips[idx].playbackRate = rate
                                        if isPlayingThis {
                                            soundManager.playPreview(clip: appState.soundClips[idx])
                                        }
                                    }
                                }) {
                                    Text(String(format: "%.2f", rate))
                                        .font(.system(size: 8, weight: .bold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 2)
                                        .background(clip.playbackRate == rate ? Color.cyan.opacity(0.3) : Color.white.opacity(0.08))
                                        .foregroundColor(clip.playbackRate == rate ? .cyan : .white)
                                        .cornerRadius(2)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // 音量スライダー
                    HStack {
                        Text("音量:").font(.caption2).foregroundColor(Color(white: 0.7))
                        Slider(
                            value: Binding(
                                get: { clip.volume },
                                set: { val in
                                    if let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) {
                                        appState.soundClips[idx].volume = val
                                    }
                                }
                            ),
                            in: 0...1.0
                        )
                        Text("\(Int(clip.volume * 100))%").font(.caption2.monospaced()).foregroundColor(.cyan)
                    }

                    // フェードイン (FI) スライダー
                    HStack {
                        Text("フェードイン:").font(.caption2).foregroundColor(Color(white: 0.7))
                        Slider(
                            value: Binding(
                                get: { clip.fadeInDuration },
                                set: { val in
                                    if let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) {
                                        appState.soundClips[idx].fadeInDuration = (val * 10).rounded() / 10
                                    }
                                }
                            ),
                            in: 0...3.0,
                            step: 0.1
                        )
                        Text(String(format: "%.1fs", clip.fadeInDuration)).font(.caption2.monospaced()).foregroundColor(.cyan)
                    }

                    // フェードアウト (FO) スライダー
                    HStack {
                        Text("フェードアウト:").font(.caption2).foregroundColor(Color(white: 0.7))
                        Slider(
                            value: Binding(
                                get: { clip.fadeOutDuration },
                                set: { val in
                                    if let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) {
                                        appState.soundClips[idx].fadeOutDuration = (val * 10).rounded() / 10
                                    }
                                }
                            ),
                            in: 0...3.0,
                            step: 0.1
                        )
                        Text(String(format: "%.1fs", clip.fadeOutDuration)).font(.caption2.monospaced()).foregroundColor(Color(hex: "#DDA0DD"))
                    }

                    // SEクリップ専用: シーン切替時即切りトグル
                    if clip.type == "SE" {
                        Divider().background(DAWTheme.trackBorder).padding(.vertical, 2)

                        Toggle(isOn: Binding(
                            get: { clip.isCutOffOnSceneEnd },
                            set: { val in
                                if let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) {
                                    appState.soundClips[idx].isCutOffOnSceneEnd = val
                                }
                            }
                        )) {
                            HStack(spacing: 4) {
                                Image(systemName: "scissors")
                                    .foregroundColor(.cyan)
                                Text("シーン切替時に即切り")
                                    .font(.caption2.bold())
                                    .foregroundColor(.white)
                            }
                        }
                        .toggleStyle(.switch)
                        .help("シーンの長さより効果音が長い場合に、シーン終了時刻で即座に再生を停止します")

                        // シーン超過判定表示
                        let scenes = activeSceneList()
                        let sIdx = clip.sceneIndex ?? selectedSceneIndex
                        if sIdx >= 1 && sIdx <= scenes.count {
                            let sDur = scenes[sIdx - 1].duration
                            if clip.effectiveDuration > sDur {
                                HStack(spacing: 3) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(.orange)
                                    Text("SE長(\(String(format: "%.1f", clip.effectiveDuration))s) > シーン長(\(String(format: "%.1f", sDur))s)")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.orange)
                                    Spacer()
                                    Text(clip.isCutOffOnSceneEnd ? "✂️ 即切り有効" : "⚠️ 跨いで継続")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(clip.isCutOffOnSceneEnd ? .cyan : .orange)
                                }
                                .padding(4)
                                .background(Color.orange.opacity(0.12))
                                .cornerRadius(3)
                            }
                        }
                    }
                }
            } else {
                Text("リージョンを選択すると詳細が表示されます")
                    .font(.caption2)
                    .foregroundColor(Color(white: 0.6))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 4)
            }
        }
        .padding(8)
        .background(Color(red: 0.16, green: 0.17, blue: 0.19))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(DAWTheme.trackBorder, lineWidth: 1)
        )
    }

    // MARK: - AI Sound Generator Card (MusicGen / SE / プロシージャルシンセ)
    private var aiSoundGeneratorCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            DisclosureGroup(
                isExpanded: $showAIDrawer,
                content: {
                    VStack(alignment: .leading, spacing: 8) {
                        // AI Engine Badge
                        HStack {
                            Circle()
                                .fill(aiSoundService.isColabBridgeAvailable ? Color.green : Color.blue)
                                .frame(width: 6, height: 6)
                            Text(aiSoundService.isColabBridgeAvailable ? "⚡️ Colab L4/T4 GPU (MusicGen/SE)" : "東方・日常プロシージャル合成")
                                .font(.system(size: 10))
                                .foregroundColor(Color(white: 0.8))
                            Spacer()
                        }

                        // モードセレクター
                        Picker("", selection: $aiSoundMode) {
                            Text("🎵 AI BGM 作曲").tag("bgm")
                            Text("⚡️ AI 効果音 (SE)").tag("se")
                        }
                        .pickerStyle(.segmented)

                        if aiSoundMode == "bgm" {
                            // クイックサジェスト
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 4) {
                                    Button("東方戦闘") { aiSoundService.bgmPrompt = "東方風 激しい戦闘曲 140bpm 弾幕バトル" }.buttonStyle(.bordered).font(.system(size: 9))
                                    Button("博麗神社") { aiSoundService.bgmPrompt = "東方・博麗神社 少女綺想曲風 巫女の日常と疾走" }.buttonStyle(.bordered).font(.system(size: 9))
                                    Button("魔法の森") { aiSoundService.bgmPrompt = "東方・魔法の森 恋色マスタースパーク風 シンセロック" }.buttonStyle(.bordered).font(.system(size: 9))
                                    Button("街角カフェ") { aiSoundService.bgmPrompt = "街角カフェ アコースティックギターとピアノのBGM" }.buttonStyle(.bordered).font(.system(size: 9))
                                    Button("深夜Lo-Fi") { aiSoundService.bgmPrompt = "深夜のデスク Lo-Fi チルビート 穏やかな作業用" }.buttonStyle(.bordered).font(.system(size: 9))
                                }
                            }

                            // プロンプト入力
                            TextField("BGMの情景・スタイルを入力", text: $aiSoundService.bgmPrompt)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)

                            // 尺とBPM
                            HStack {
                                Text("尺: \(Int(aiSoundService.bgmDurationSeconds))秒")
                                    .font(.system(size: 10))
                                    .foregroundColor(Color(white: 0.7))
                                Slider(value: $aiSoundService.bgmDurationSeconds, in: 5...30, step: 1)
                            }

                            // アクション
                            HStack(spacing: 6) {
                                Button(action: {
                                    aiSoundService.togglePlayBGM()
                                }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: aiSoundService.isBGMPlaying ? "stop.fill" : "play.fill")
                                        Text(aiSoundService.isBGMPlaying ? "停止" : "試聴")
                                    }
                                    .font(.caption2)
                                }
                                .buttonStyle(.bordered)
                                .disabled(aiSoundService.generatedBGMURL == nil)

                                Button(action: {
                                    aiSoundService.generateBGM()
                                }) {
                                    HStack(spacing: 4) {
                                        if aiSoundService.isBGMGenerating {
                                            ProgressView().controlSize(.small)
                                        } else {
                                            Image(systemName: "sparkles")
                                        }
                                        Text(aiSoundService.isBGMGenerating ? "作曲中..." : "AI BGM 作曲")
                                            .font(.caption2)
                                            .bold()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(aiSoundService.isBGMGenerating)

                                if let item = aiSoundService.soundHistory.first(where: { $0.type == "BGM" }) {
                                    Button(action: {
                                        aiSoundService.insertToSoundMaker(item: item, trackType: "bgm")
                                    }) {
                                        HStack(spacing: 3) {
                                            Image(systemName: "plus.circle.fill")
                                            Text("タイムライン配置")
                                        }
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        } else {
                            // SE モード
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 4) {
                                    Button("スペルカード") { aiSoundService.sePrompt = "スペルカード発動 レーザービーム 衝撃波 効果音" }.buttonStyle(.bordered).font(.system(size: 9))
                                    Button("打撃・爆発") { aiSoundService.sePrompt = "重い打撃と爆発音 ドカーン" }.buttonStyle(.bordered).font(.system(size: 9))
                                    Button("決定チャイム") { aiSoundService.sePrompt = "ゲームの決定音 ピロリン クリアなチャイム" }.buttonStyle(.bordered).font(.system(size: 9))
                                    Button("スマホ通知") { aiSoundService.sePrompt = "スマホのチャット着信音 ポロンと鳴るクリアな通知音" }.buttonStyle(.bordered).font(.system(size: 9))
                                    Button("光・魔法") { aiSoundService.sePrompt = "キラキラ光る魔法効果音 シャラララン" }.buttonStyle(.bordered).font(.system(size: 9))
                                }
                            }

                            // プロンプト入力
                            TextField("効果音の情景を入力", text: $aiSoundService.sePrompt)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)

                            // アクション
                            HStack(spacing: 6) {
                                Button(action: {
                                    aiSoundService.togglePlaySE()
                                }) {
                                    HStack(spacing: 3) {
                                        Image(systemName: aiSoundService.isSEPlaying ? "stop.fill" : "play.fill")
                                        Text(aiSoundService.isSEPlaying ? "停止" : "試聴")
                                    }
                                    .font(.caption2)
                                }
                                .buttonStyle(.bordered)
                                .disabled(aiSoundService.generatedSEURL == nil)

                                Button(action: {
                                    aiSoundService.generateSE()
                                }) {
                                    HStack(spacing: 4) {
                                        if aiSoundService.isSEGenerating {
                                            ProgressView().controlSize(.small)
                                        } else {
                                            Image(systemName: "bolt.fill")
                                        }
                                        Text(aiSoundService.isSEGenerating ? "生成中..." : "AI SE 生成")
                                            .font(.caption2)
                                            .bold()
                                    }
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(aiSoundService.isSEGenerating)

                                if let item = aiSoundService.soundHistory.first(where: { $0.type == "SE" }) {
                                    Button(action: {
                                        aiSoundService.insertToSoundMaker(item: item, trackType: "se")
                                    }) {
                                        HStack(spacing: 3) {
                                            Image(systemName: "plus.circle.fill")
                                            Text("タイムライン配置")
                                        }
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                    .padding(8)
                    .background(Color(red: 0.12, green: 0.13, blue: 0.15))
                    .cornerRadius(4)
                },
                label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles")
                            .foregroundColor(.yellow)
                        Text("✨ AI BGM & 効果音 作曲・生成")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                    }
                }
            )
        }
        .padding(8)
        .background(Color(red: 0.16, green: 0.17, blue: 0.19))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(DAWTheme.trackBorder, lineWidth: 1)
        )
    }

    // MARK: - AquesTalk Quick Generator Card
    private var aquesTalkQuickGeneratorCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            DisclosureGroup(
                isExpanded: $showAquesTalkDrawer,
                content: {
                    VStack(alignment: .leading, spacing: 8) {
                        // Character / Voice Type Picker
                        HStack {
                            Text("キャラ:").font(.caption2).foregroundColor(Color(white: 0.7))
                            Picker("", selection: $targetCharacter) {
                                Text("博麗霊夢").tag("博麗霊夢")
                                Text("霧雨魔理沙").tag("霧雨魔理沙")
                                Text("十六夜咲夜").tag("十六夜咲夜")
                                Text("魂魄妖夢").tag("魂魄妖夢")
                            }
                            .pickerStyle(.menu)
                            .frame(maxWidth: .infinity)
                        }

                        // Input Text
                        TextField("セリフを入力", text: $inputSpeechText)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                            .onChange(of: inputSpeechText) { newVal in
                                convertedVoiceSymbol = aquesTalk.convertToVoiceSymbol(text: newVal)
                            }

                        // ゆっくりボイスメーカー準拠: 音質改善 & 効果設定
                        VStack(spacing: 6) {
                            HStack {
                                Text("音質改善:").font(.caption2).foregroundColor(Color(white: 0.7))
                                Picker("", selection: $selectedQuality) {
                                    ForEach(AudioQualitySetting.allCases) { q in
                                        Text(q.displayName).tag(q)
                                    }
                                }
                                .pickerStyle(.menu)
                            }

                            HStack {
                                Text("効果指定:").font(.caption2).foregroundColor(Color(white: 0.7))
                                Picker("", selection: $selectedEffect) {
                                    ForEach(AudioEffectType.allCases) { eff in
                                        Text(eff.displayName).tag(eff)
                                    }
                                }
                                .pickerStyle(.menu)
                            }
                        }
                        .padding(6)
                        .background(Color(red: 0.12, green: 0.13, blue: 0.15))
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(DAWTheme.trackBorder, lineWidth: 1)
                        )

                        // Actions: Preview & Place on Timeline
                        HStack(spacing: 8) {
                            Button(action: {
                                isSynthesizing = true
                                let vType = aquesTalk.voiceType(for: targetCharacter)
                                aquesTalk.synthesizeAndPlay(
                                    text: SlideItem.cleanDialogueText(from: inputSpeechText),
                                    speed: speechSpeed,
                                    voice: vType,
                                    quality: selectedQuality,
                                    effect: selectedEffect
                                ) {
                                    isSynthesizing = false
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: isSynthesizing ? "waveform.badge.magnifyingglass" : "play.circle")
                                    Text("試聴")
                                }
                                .font(.caption2)
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.bordered)

                            Button(action: {
                                addVoiceClipToTimeline()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus.rectangle.fill")
                                    Text("波形配置")
                                }
                                .font(.caption2)
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        Divider().background(DAWTheme.trackBorder)

                        // 全スライド一括生成ボタン
                        Button(action: {
                            showBatchVoiceGenerationSheet = true
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles.rectangle.stack.fill")
                                Text("スライド全音声一括生成...")
                            }
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.cyan)
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 6)
                },
                label: {
                    Label("AquesTalk ゆっくりボイス配置", systemImage: "character.bubble")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                }
            )
        }
        .padding(8)
        .background(Color(red: 0.16, green: 0.17, blue: 0.19))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(DAWTheme.trackBorder, lineWidth: 1)
        )
    }

    // MARK: - Dual Channel Strip (Track & Master Stereo Out)
    private var dualChannelStripView: some View {
        HStack(spacing: 12) {
            // Selected Track Channel Strip
            channelStripColumn(
                title: selectedTrack()?.name ?? "Track 1",
                isMaster: false,
                volume: Binding(
                    get: { selectedTrack()?.volume ?? 0.8 },
                    set: { val in
                        if let idx = appState.audioTracks.firstIndex(where: { $0.id == selectedTrackId }) {
                            appState.audioTracks[idx].volume = val
                        }
                    }
                ),
                pan: Binding(
                    get: { selectedTrack()?.pan ?? 0.0 },
                    set: { val in
                        if let idx = appState.audioTracks.firstIndex(where: { $0.id == selectedTrackId }) {
                            appState.audioTracks[idx].pan = val
                        }
                    }
                )
            )

            Divider().background(DAWTheme.trackBorder)

            // Master Stereo Out Strip
            channelStripColumn(
                title: "Stereo Out",
                isMaster: true,
                volume: .constant(0.9),
                pan: .constant(0.0)
            )
        }
        .padding(10)
        .background(Color(red: 0.16, green: 0.17, blue: 0.19))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(DAWTheme.trackBorder, lineWidth: 1)
        )
    }

    private func channelStripColumn(title: String, isMaster: Bool, volume: Binding<Double>, pan: Binding<Double>) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)

            // Pan Knob
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(Color(red: 0.22, green: 0.24, blue: 0.27))
                        .frame(width: 28, height: 28)
                        .overlay(Circle().stroke(DAWTheme.trackBorder, lineWidth: 1))
                    Rectangle()
                        .fill(Color.cyan)
                        .frame(width: 2, height: 10)
                        .offset(y: -6)
                        .rotationEffect(.degrees(pan.wrappedValue * 90.0))
                }
                Text(String(format: "%+.1f", pan.wrappedValue))
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.secondary)
            }

            // Fader + dB Level Meter
            HStack(spacing: 6) {
                // dB Scale Numbers
                VStack(spacing: 12) {
                    Text("+6").font(.system(size: 7))
                    Text("0").font(.system(size: 7))
                    Text("-6").font(.system(size: 7))
                    Text("-12").font(.system(size: 7))
                    Text("-24").font(.system(size: 7))
                    Text("-48").font(.system(size: 7))
                }
                .foregroundColor(.secondary)

                // Fader Slider
                Slider(value: volume, in: 0...1.0)
                    .frame(height: 120)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 24, height: 120)

                // Peak Level Meter
                VStack(spacing: 1) {
                    ForEach(0..<20, id: \.self) { seg in
                        let segLevel = Double(19 - seg) / 20.0
                        let isActive = isPlaying && (currentMeterLevel * volume.wrappedValue >= segLevel)
                        Rectangle()
                            .fill(meterColor(for: segLevel, isActive: isActive))
                            .frame(width: 8, height: 5)
                    }
                }
                .background(Color.black.opacity(0.6))
                .cornerRadius(2)
            }
            .frame(height: 125)

            // Mute / Solo Buttons
            HStack(spacing: 4) {
                if !isMaster {
                    Button(action: {
                        if let idx = appState.audioTracks.firstIndex(where: { $0.id == selectedTrackId }) {
                            appState.audioTracks[idx].isMuted.toggle()
                        }
                    }) {
                        Text("M")
                            .font(.system(size: 9, weight: .bold))
                            .frame(width: 20, height: 16)
                            .background(selectedTrack()?.isMuted == true ? Color.orange : Color.secondary.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(3)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        if let idx = appState.audioTracks.firstIndex(where: { $0.id == selectedTrackId }) {
                            appState.audioTracks[idx].isSolo.toggle()
                        }
                    }) {
                        Text("S")
                            .font(.system(size: 9, weight: .bold))
                            .frame(width: 20, height: 16)
                            .background(selectedTrack()?.isSolo == true ? Color.yellow : Color.secondary.opacity(0.3))
                            .foregroundColor(selectedTrack()?.isSolo == true ? .black : .white)
                            .cornerRadius(3)
                    }
                    .buttonStyle(.plain)
                } else {
                    Text("Bnc")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.3))
                        .foregroundColor(.cyan)
                        .cornerRadius(3)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func meterColor(for level: Double, isActive: Bool) -> Color {
        guard isActive else { return Color.white.opacity(0.08) }
        if level > 0.85 { return DAWTheme.meterRed }
        if level > 0.65 { return DAWTheme.meterYellow }
        return DAWTheme.meterGreen
    }

    // MARK: - Main Timeline Area View (ルーラー・シーン分割・トラック波形の完全同期スクロール)
    private var dawTimelineAreaView: some View {
        ScrollViewReader { timelineProxy in
            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                let totalWidth = max(900, CGFloat(totalTimelineDuration) * CGFloat(zoomScale))

                HStack(alignment: .top, spacing: 0) {
                    // Left Fixed Header Column (Width: 210)
                    VStack(alignment: .leading, spacing: 0) {
                        // 1. Ruler Header Spacer
                        Rectangle()
                            .fill(DAWTheme.rulerBackground)
                            .frame(width: 210, height: 26)
                            .overlay(
                                HStack {
                                    Text("トラック / シーン")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 12)
                                    Spacer()
                                }
                            )

                        Divider().background(DAWTheme.trackBorder)

                        // 2. Movie Scene Thumbnails Header
                        Rectangle()
                            .fill(DAWTheme.stripBackground)
                            .frame(width: 210, height: 38)
                            .overlay(
                                HStack(spacing: 6) {
                                    Image(systemName: "film")
                                        .font(.system(size: 11))
                                        .foregroundColor(.cyan)
                                    Text("シーン分割 (Scenes)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                    Spacer()
                                }
                                .padding(.leading, 12)
                            )

                        Divider().background(DAWTheme.trackBorder)

                        // 3. Audio Tracks Headers
                        VStack(spacing: 0) {
                            ForEach(appState.audioTracks) { track in
                                trackHeaderView(track: track)
                                    .frame(width: 210, height: 68)
                                    .background(selectedTrackId == track.id ? DAWTheme.trackHeaderBackground.opacity(1.3) : DAWTheme.trackHeaderBackground)
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        selectedTrackId = track.id
                                    }
                                Divider().background(DAWTheme.trackBorder)
                            }

                            // Bottom Add Track Bar Header Spacer
                            Rectangle()
                                .fill(DAWTheme.windowBackground)
                                .frame(width: 210, height: 36)
                        }
                    }
                    .frame(width: 210)

                    Divider().background(DAWTheme.trackBorder)

                    // Right Main Timeline Body (Shared Horizontal Scale & Coordinates)
                    ZStack(alignment: .topLeading) {
                        // Background Grid Lines across full width
                        timelineGridLinesView
                            .frame(width: totalWidth)

                        // Selected Scene Highlight Overlay across full tracks (選択シーンの区間ハイライト)
                        selectedSceneHighlightBackground

                        VStack(alignment: .leading, spacing: 0) {
                            // 1. Ruler Scale Measures (同期ルーラー)
                            rulerScaleContentView(width: totalWidth)
                                .frame(width: totalWidth, height: 26)

                            Divider().background(DAWTheme.trackBorder)

                            // 2. Movie Scene Thumbnails Strip (シーン分割レーン: 絶対座標配置)
                            sceneThumbnailsLaneView(proxy: timelineProxy, width: totalWidth)
                                .frame(width: totalWidth, height: 38)

                            Divider().background(DAWTheme.trackBorder)

                            // 3. Waveform Track Lanes
                            VStack(spacing: 0) {
                                ForEach(appState.audioTracks) { track in
                                    trackLaneContentView(track: track, width: totalWidth)
                                        .frame(width: totalWidth, height: 68)
                                    Divider().background(DAWTheme.trackBorder)
                                }

                                // Bottom Action Bar Content
                                addTrackBottomBarContent(width: totalWidth)
                                    .frame(width: totalWidth, height: 36)
                            }
                        }

                        // Playhead Vertical Line across all tracks
                        playheadVerticalLineView
                    }
                    .frame(width: totalWidth)
                }
            }
            .onChange(of: selectedSceneIndex) { newIndex in
                withAnimation(.easeInOut(duration: 0.3)) {
                    timelineProxy.scrollTo("scene_anchor_\(newIndex)", anchor: .center)
                }
            }
        }
    }

    // MARK: - Selected Scene Highlight Background
    private var selectedSceneHighlightBackground: some View {
        let scenes = activeSceneList()
        let sIdx = max(0, min(selectedSceneIndex - 1, scenes.count - 1))
        let (sStart, sEnd) = sceneTimeRange(index: sIdx)
        let startX = CGFloat(sStart) * CGFloat(zoomScale)
        let sWidth = max(2.0, CGFloat(sEnd - sStart) * CGFloat(zoomScale))

        return Rectangle()
            .fill(Color.cyan.opacity(0.08))
            .overlay(
                Rectangle()
                    .stroke(Color.cyan.opacity(0.35), lineWidth: 1.5)
            )
            .frame(width: sWidth)
            .offset(x: startX)
            .allowsHitTesting(false)
    }

    // MARK: - Ruler Scale Content (秒数・タイムコードが正確に視認できるルーラー)
    private func rulerScaleContentView(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            ForEach(0..<Int(totalTimelineDuration / 2.0), id: \.self) { bar in
                let seconds = bar * 2
                let isMajor = (seconds % 10 == 0) // 10秒ごとにタイムコード表示
                let timeString = String(format: "%02d:%02d", seconds / 60, seconds % 60)

                HStack(alignment: .top, spacing: 0) {
                    if isMajor {
                        Text(timeString)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.leading, 3)
                            .padding(.top, 3)
                    } else {
                        // 2秒ごとの小目盛り
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(Color.white.opacity(0.25))
                                .frame(width: 1, height: 6)
                                .padding(.leading, 2)
                                .padding(.top, 2)
                            Spacer()
                        }
                    }
                    Spacer()
                }
                .frame(width: CGFloat(zoomScale * 2.0), height: 26)
                .overlay(
                    Rectangle()
                        .stroke(DAWTheme.trackBorder.opacity(isMajor ? 0.6 : 0.25), lineWidth: 0.5)
                )
            }
        }
        .frame(width: width, alignment: .leading)
        .background(DAWTheme.rulerBackground)
    }

    // MARK: - Scene Strip Lane (シーン分割トラック: 音声クリップ・ルーラーと絶対座標で完全一致)
    private func sceneThumbnailsLaneView(proxy: ScrollViewProxy, width: CGFloat) -> some View {
        let scenes = activeSceneList()

        return HStack(spacing: 0) {
            ForEach(Array(scenes.enumerated()), id: \.element.id) { index, scene in
                let sNum = index + 1
                let itemWidth = max(2.0, CGFloat(scene.duration) * CGFloat(zoomScale))

                sceneStripItemView(scene: scene, index: index, width: itemWidth, proxy: proxy)
                    .frame(width: itemWidth, height: 32)
                    .clipped()
                    .id("scene_anchor_\(sNum)")
            }
            Spacer(minLength: 0)
        }
        .frame(width: width, height: 38, alignment: .leading)
        .background(DAWTheme.stripBackground)
    }

    private func sceneStripItemView(scene: MovieScene, index: Int, width: CGFloat, proxy: ScrollViewProxy? = nil) -> some View {
        let sNum = index + 1
        let isSelected = selectedSceneIndex == sNum
        let cleanTitle = scene.displayCleanTitle
        // 重複を除去したタイトル (例: "シーン 46: タイトル" -> "タイトル")
        let shortTitle: String = {
            if cleanTitle.hasPrefix("シーン \(sNum): ") {
                return String(cleanTitle.dropFirst("シーン \(sNum): ".count)).trimmingCharacters(in: .whitespacesAndNewlines)
            } else if cleanTitle == "シーン \(sNum)" || cleanTitle == "スライド #\(sNum)" {
                return ""
            }
            return cleanTitle
        }()

        let hasAnimation = scene.animationDuration != nil || scene.animationNote != nil

        return Button(action: {
            selectScene(index: sNum, proxy: proxy)
        }) {
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(
                        isSelected ?
                            LinearGradient(
                                colors: [Color.cyan.opacity(0.85), Color.blue.opacity(0.75)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            (hasAnimation ?
                                LinearGradient(
                                    colors: [Color.purple.opacity(0.60), Color.blue.opacity(0.40)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ) :
                                LinearGradient(
                                    colors: [Color.blue.opacity(0.40), Color.purple.opacity(0.30)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                    )

                HStack(spacing: 3) {
                    if width >= 55 {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : (hasAnimation ? "film.stack.fill" : "film"))
                            .font(.system(size: 8))
                            .foregroundColor(isSelected ? .white : (hasAnimation ? .yellow : .cyan))
                    }

                    VStack(alignment: .leading, spacing: 1) {
                        if width >= 85 && !shortTitle.isEmpty {
                            Text("S\(sNum): \(shortTitle)")
                                .font(.system(size: 9, weight: isSelected ? .black : .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        } else {
                            Text("S\(sNum)")
                                .font(.system(size: 9, weight: isSelected ? .black : .bold))
                                .foregroundColor(.white)
                                .lineLimit(1)
                        }

                        if width >= 40 {
                            HStack(spacing: 2) {
                                if hasAnimation {
                                    Text("🎬")
                                        .font(.system(size: 6))
                                }
                                Text(String(format: "%.1fs", scene.duration))
                                    .font(.system(size: 7.5, design: .monospaced))
                                    .foregroundColor(hasAnimation ? .yellow : .white.opacity(isSelected ? 0.95 : 0.7))
                                    .lineLimit(1)
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 3)
            }
            .frame(width: max(2, width), height: 32)
            .clipped()
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(isSelected ? Color.cyan : (hasAnimation ? Color.yellow.opacity(0.5) : Color.cyan.opacity(0.3)), lineWidth: isSelected ? 2.5 : 1)
            )
            .shadow(color: isSelected ? Color.cyan.opacity(0.7) : Color.clear, radius: isSelected ? 3 : 0)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Track Waveform Lane View
    private func trackLaneContentView(track: AudioTrack, width: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            // Background Track Lane
            Rectangle()
                .fill(DAWTheme.timelineBackground)
                .frame(width: width, height: 68)

            // Clips on this Track
            let clipsOnTrack = appState.soundClips.filter { $0.trackId == track.id }
            ForEach(clipsOnTrack) { clip in
                clipWaveformRegionView(clip: clip, track: track)
            }
        }
        .frame(width: width, height: 68)
        .contentShape(Rectangle())
        .onTapGesture { location in
            let clickedSeconds = Double(location.x) / zoomScale
            currentTime = max(0, min(totalTimelineDuration, clickedSeconds))
            if isPlaying {
                soundManager.startTimelinePlayback(from: currentTime, clips: appState.soundClips, scenes: activeSceneList())
            }
        }
    }

    // MARK: - Track Header View
    private func trackHeaderView(track: AudioTrack) -> some View {
        let trackIndex = (appState.audioTracks.firstIndex(where: { $0.id == track.id }) ?? 0) + 1
        let isSelected = selectedTrackId == track.id

        return HStack(spacing: 8) {
            // Track Number & Color Accent Indicator
            HStack(spacing: 4) {
                Rectangle()
                    .fill(Color(hex: track.colorHex))
                    .frame(width: 4, height: 50)
                    .cornerRadius(2)

                Text("\(trackIndex)")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(.secondary)
                    .frame(width: 14)
            }

            // Track Icon & Info
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: track.icon)
                        .font(.system(size: 12))
                        .foregroundColor(Color(hex: track.colorHex))

                    Text(track.name)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(isSelected ? .white : .white.opacity(0.85))
                        .lineLimit(1)
                }

                // Volume slider & Pan Knob inside header
                HStack(spacing: 6) {
                    // Mute / Solo / Rec buttons
                    HStack(spacing: 3) {
                        trackStateButton(title: "M", isActive: track.isMuted, activeColor: .orange) {
                            if let idx = appState.audioTracks.firstIndex(where: { $0.id == track.id }) {
                                appState.audioTracks[idx].isMuted.toggle()
                            }
                        }
                        trackStateButton(title: "S", isActive: track.isSolo, activeColor: .yellow) {
                            if let idx = appState.audioTracks.firstIndex(where: { $0.id == track.id }) {
                                appState.audioTracks[idx].isSolo.toggle()
                            }
                        }
                        trackStateButton(title: "R", isActive: track.isRecordArm, activeColor: .red) {
                            if let idx = appState.audioTracks.firstIndex(where: { $0.id == track.id }) {
                                appState.audioTracks[idx].isRecordArm.toggle()
                            }
                        }
                    }

                    // Mini Volume Slider
                    Slider(
                        value: Binding(
                            get: { track.volume },
                            set: { val in
                                if let idx = appState.audioTracks.firstIndex(where: { $0.id == track.id }) {
                                    appState.audioTracks[idx].volume = val
                                }
                            }
                        ),
                        in: 0...1.0
                    )
                    .frame(width: 50)
                }
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .overlay(
            isSelected ?
                RoundedRectangle(cornerRadius: 0)
                    .stroke(Color.cyan.opacity(0.6), lineWidth: 1)
                : nil
        )
    }

    private func trackStateButton(title: String, isActive: Bool, activeColor: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 8, weight: .bold))
                .frame(width: 16, height: 16)
                .background(isActive ? activeColor : Color.white.opacity(0.1))
                .foregroundColor(isActive ? (activeColor == .yellow ? .black : .white) : .secondary)
                .cornerRadius(2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Waveform Region View (波の形で表示する機能)
    private func clipWaveformRegionView(clip: SoundClip, track: AudioTrack) -> some View {
        let clipX = CGFloat(clip.startTime) * CGFloat(zoomScale)
        let clipWidth = max(35, CGFloat(clip.duration) * CGFloat(zoomScale))
        let isSelected = selectedClipId == clip.id
        let clipColor = Color(hex: clip.colorHex ?? track.colorHex)
        let isSpanning = clip.isSpanningScenes

        // シーン長超過 & 即切りカットオフ判定
        let scenes = activeSceneList()
        var sceneEndOffsetInClip: CGFloat? = nil
        var isCutOffApplicable = false
        if clip.type == "SE", let sIdx = clip.sceneIndex, sIdx >= 1 && sIdx <= scenes.count {
            let sRange = sceneTimeRange(index: sIdx - 1)
            let sceneEndT = sRange.end
            if (clip.startTime + clip.effectiveDuration) > sceneEndT {
                isCutOffApplicable = true
                let cutSeconds = max(0, sceneEndT - clip.startTime)
                sceneEndOffsetInClip = CGFloat(cutSeconds) * CGFloat(zoomScale)
            }
        }

        return ZStack(alignment: .topLeading) {
            // Region Box Background
            RoundedRectangle(cornerRadius: 4)
                .fill(isSpanning ? Color.purple.opacity(0.35) : clipColor.opacity(0.25))

            // Upper Title Ribbon
            VStack(spacing: 0) {
                HStack(spacing: 3) {
                    Image(systemName: isSpanning ? "arrow.triangle.merge" : "waveform")
                        .font(.system(size: 8))

                    // シーン跨ぎバッジ または 所属シーンバッジ
                    if isSpanning, let start = clip.spanStartSceneIndex, let end = clip.spanEndSceneIndex {
                        Text("★ S\(start)〜S\(end) 跨ぎ")
                            .font(.system(size: 7, weight: .bold))
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Color.white.opacity(0.25))
                            .cornerRadius(2)
                    } else if let sIdx = clip.sceneIndex {
                        Text("S\(sIdx)")
                            .font(.system(size: 7, weight: .bold))
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Color.black.opacity(0.35))
                            .cornerRadius(2)
                    }

                    // SE 即切りバッジ
                    if clip.type == "SE" && clip.isCutOffOnSceneEnd {
                        HStack(spacing: 1) {
                            Image(systemName: "scissors").font(.system(size: 6))
                            Text("即切").font(.system(size: 6.5, weight: .bold))
                        }
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.cyan.opacity(0.40))
                        .foregroundColor(.white)
                        .cornerRadius(2)
                    }

                    Text(clip.name)
                        .font(.system(size: 9, weight: .bold))
                        .lineLimit(1)

                    // 倍速バッジ
                    if clip.playbackRate != 1.0 {
                        Text(String(format: "%.2fx", clip.playbackRate))
                            .font(.system(size: 7, weight: .bold))
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Color.cyan.opacity(0.35))
                            .foregroundColor(.cyan)
                            .cornerRadius(2)
                    }

                    // フェードバッジ
                    if clip.fadeInDuration > 0 || clip.fadeOutDuration > 0 {
                        HStack(spacing: 2) {
                            if clip.fadeInDuration > 0 {
                                Text("FI:\(clip.fadeInDuration, specifier: "%.1f")s")
                            }
                            if clip.fadeOutDuration > 0 {
                                Text("FO:\(clip.fadeOutDuration, specifier: "%.1f")s")
                            }
                        }
                        .font(.system(size: 6.5, weight: .bold))
                        .padding(.horizontal, 3)
                        .padding(.vertical, 1)
                        .background(Color.purple.opacity(0.35))
                        .foregroundColor(Color(hex: "#DDA0DD"))
                        .cornerRadius(2)
                    }

                    // 逆再生バッジ
                    if clip.isReversed {
                        Text("◀ REV")
                            .font(.system(size: 7, weight: .bold))
                            .padding(.horizontal, 3)
                            .padding(.vertical, 1)
                            .background(Color.orange.opacity(0.45))
                            .foregroundColor(.orange)
                            .cornerRadius(2)
                    }

                    Spacer()

                    Text(String(format: "%.1fs", clip.duration))
                        .font(.system(size: 8))
                        .opacity(0.8)
                }
                .foregroundColor(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(isSpanning ? Color.purple.opacity(0.85) : clipColor.opacity(0.75))

                // Realistic Audio Waveform Shape (波の形 / 逆再生時は反転)
                let basePoints = clip.waveformPoints ?? sampleWaveform(for: clip.name)
                let renderPoints = clip.isReversed ? Array(basePoints.reversed()) : basePoints
                WaveformDisplayShape(points: renderPoints)
                    .fill(isSpanning ? Color(hex: "#DDA0DD") : clipColor)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 3)
            }

            // シーン切り替え時の即切り境界ライン (カットライン)
            if isCutOffApplicable, let cutX = sceneEndOffsetInClip, cutX > 0, cutX < clipWidth {
                if clip.isCutOffOnSceneEnd {
                    // 即切り有効時の赤いカット境界線 & ハサミマーク
                    ZStack(alignment: .topTrailing) {
                        Rectangle()
                            .fill(Color.black.opacity(0.50))
                            .frame(width: max(0, clipWidth - cutX), height: 58)
                            .offset(x: cutX)

                        VStack(spacing: 2) {
                            Image(systemName: "scissors")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(.cyan)
                                .background(Color.black.opacity(0.7))
                                .clipShape(Circle())
                            Rectangle()
                                .fill(Color.cyan)
                                .frame(width: 1.5, height: 44)
                        }
                        .offset(x: cutX - 4, y: 2)
                    }
                    .allowsHitTesting(false)
                } else {
                    // 即切りOFF時の警告境界線
                    Rectangle()
                        .stroke(Color.orange.opacity(0.6), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .frame(width: 1, height: 58)
                        .offset(x: cutX)
                        .allowsHitTesting(false)
                }
            }
        }
        .frame(width: clipWidth, height: 58)
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(isSelected ? Color.white : (isSpanning ? Color(hex: "#DDA0DD") : clipColor), lineWidth: isSelected ? 2 : 1)
        )
        .offset(x: clipX, y: 5)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedClipId = clip.id
            selectedTrackId = track.id
            if let sIdx = clip.sceneIndex ?? clip.spanStartSceneIndex {
                selectScene(index: sIdx)
            }
        }
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    let deltaSeconds = Double(gesture.translation.width) / zoomScale
                    if let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) {
                        let newStart = max(0, clip.startTime + deltaSeconds)
                        appState.soundClips[idx].startTime = newStart
                    }
                }
        )
        .contextMenu {
            Button(action: {
                let sIdx = clip.sceneIndex ?? selectedSceneIndex
                let scenes = activeSceneList()
                let sDur = (sIdx >= 1 && sIdx <= scenes.count) ? scenes[sIdx - 1].duration : nil
                soundManager.togglePreview(clip: clip, sceneDuration: sDur)
            }) {
                Label(soundManager.currentlyPlayingClipId == clip.id && soundManager.isPreviewPlaying ? "停止" : "試聴再生", systemImage: soundManager.currentlyPlayingClipId == clip.id && soundManager.isPreviewPlaying ? "stop.circle" : "play.circle")
            }

            if clip.type == "SE" {
                Divider()

                Button(action: {
                    if let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) {
                        appState.soundClips[idx].isCutOffOnSceneEnd.toggle()
                    }
                }) {
                    Label(
                        clip.isCutOffOnSceneEnd ? "シーン切替時の即切り: ON (クリックでOFF)" : "シーン切替時の即切り: OFF (クリックでON)",
                        systemImage: clip.isCutOffOnSceneEnd ? "scissors" : "scissors.badge.ellipsis"
                    )
                }

                Menu("フェードイン (FI) 設定") {
                    ForEach([0.0, 0.1, 0.2, 0.5, 1.0, 1.5, 2.0], id: \.self) { fi in
                        Button(action: {
                            if let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) {
                                appState.soundClips[idx].fadeInDuration = fi
                            }
                        }) {
                            Text(fi == 0.0 ? "なし (0.0s)" : String(format: "%.1f 秒", fi))
                        }
                    }
                }

                Menu("フェードアウト (FO) 設定") {
                    ForEach([0.0, 0.1, 0.2, 0.5, 1.0, 1.5, 2.0, 3.0], id: \.self) { fo in
                        Button(action: {
                            if let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) {
                                appState.soundClips[idx].fadeOutDuration = fo
                            }
                        }) {
                            Text(fo == 0.0 ? "なし (0.0s)" : String(format: "%.1f 秒", fo))
                        }
                    }
                }
            }

            Divider()
            Button(role: .destructive, action: {
                deleteClip(clip)
            }) {
                Label("このクリップを削除", systemImage: "trash")
            }
        }
    }

    // MARK: - Playhead & Grid Lines
    private var timelineGridLinesView: some View {
        HStack(spacing: 0) {
            ForEach(0..<Int(totalTimelineDuration), id: \.self) { sec in
                Rectangle()
                    .fill(DAWTheme.gridLine)
                    .frame(width: 1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(width: CGFloat(zoomScale))
            }
        }
    }

    private var playheadVerticalLineView: some View {
        let playheadX = CGFloat(currentTime) * CGFloat(zoomScale)
        return ZStack(alignment: .top) {
            // Top Triangle Marker
            Path { path in
                path.move(to: CGPoint(x: playheadX - 6, y: 0))
                path.addLine(to: CGPoint(x: playheadX + 6, y: 0))
                path.addLine(to: CGPoint(x: playheadX, y: 10))
                path.closeSubpath()
            }
            .fill(DAWTheme.playheadColor)

            // Vertical Line down
            Rectangle()
                .fill(DAWTheme.playheadColor)
                .frame(width: 1.5)
                .offset(x: playheadX - 0.75)
        }
    }

    // MARK: - Bottom Add Track Action Bar Content (ファイル画面から読み込み可能)
    private func addTrackBottomBarContent(width: CGFloat) -> some View {
        HStack(spacing: 12) {
            Button(action: {
                let newTrack = AudioTrack(
                    name: "Track \(appState.audioTracks.count + 1)",
                    type: "voice",
                    icon: "waveform",
                    colorHex: "#00CEC9",
                    characterName: "東方キャラクター"
                )
                appState.audioTracks.append(newTrack)
            }) {
                Label("トラックを追加", systemImage: "plus")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .padding(.leading, 14)

            Button(action: {
                addVoiceClipToTimeline()
            }) {
                Label("ボイス配置", systemImage: "person.wave.2")
                    .font(.caption)
            }
            .buttonStyle(.plain)

            // ファイル画面からSEを読み込む
            Button(action: {
                selectAudioFileViaOpenPanel(type: "SE")
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "folder.badge.plus")
                    Text("SEファイル読み込み...")
                }
                .font(.caption)
                .foregroundColor(.green)
            }
            .buttonStyle(.plain)
            .help("効果音ファイルをファイル選択画面から読み込んでタイムラインに配置")

            // ファイル画面からBGMを読み込む
            Button(action: {
                selectAudioFileViaOpenPanel(type: "BGM")
            }) {
                HStack(spacing: 3) {
                    Image(systemName: "folder.badge.plus")
                    Text("BGMファイル読み込み...")
                }
                .font(.caption)
                .foregroundColor(Color(hex: "#DDA0DD"))
            }
            .buttonStyle(.plain)
            .help("音楽ファイルをファイル選択画面から読み込んでタイムラインに配置")

            Spacer()
        }
        .padding(.vertical, 8)
        .frame(width: width, alignment: .leading)
        .background(DAWTheme.windowBackground)
    }

    // MARK: - Playback Timer Logic
    private func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        isPlaying = true
        soundManager.startTimelinePlayback(from: currentTime, clips: appState.soundClips, scenes: activeSceneList())
        playbackTimer?.invalidate()
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            currentTime += 0.05
            if currentTime >= totalTimelineDuration {
                currentTime = 0.0
            }
            soundManager.updateTimelinePlayback(currentTime: currentTime, clips: appState.soundClips, scenes: activeSceneList())
            // Animate meter
            currentMeterLevel = Double.random(in: 0.4...0.95)
        }
    }

    private func stopPlayback() {
        isPlaying = false
        soundManager.stopTimelinePlayback()
        playbackTimer?.invalidate()
        playbackTimer = nil
        currentMeterLevel = 0.0
    }

    // MARK: - Scene Navigation & Helper Methods (2つの青枠連動)
    private func syncSelectionToLoadedProject(scenes: [MovieScene]) {
        guard !scenes.isEmpty else { return }

        // 現在選択中のシーンが有効範囲内なら、勝手にジャンプさせない
        if selectedSceneIndex >= 1 && selectedSceneIndex <= scenes.count {
            return
        }

        // 読み込まれたクリップに所属シーン情報があれば、最初のクリップのシーン番号に自動選択
        let validClips = appState.soundClips.filter { $0.sceneIndex != nil }
        let targetIndex: Int
        if let minSceneIdx = validClips.compactMap({ $0.sceneIndex }).min(),
           minSceneIdx >= 1 && minSceneIdx <= scenes.count {
            targetIndex = minSceneIdx
        } else {
            targetIndex = 1
        }

        selectScene(index: targetIndex)
    }

    private func selectScene(index: Int, proxy: ScrollViewProxy? = nil) {
        let scenes = activeSceneList()
        guard index >= 1 && index <= scenes.count else { return }
        selectedSceneIndex = index
        seekToScene(index: index - 1)

        // タイムラインをそのシーン位置へスクロール
        if let p = proxy {
            withAnimation(.easeInOut(duration: 0.3)) {
                p.scrollTo("scene_anchor_\(index)", anchor: .center)
            }
        }

        // そのシーンに音声クリップがあれば選択クリップを連動
        let clips = voiceClips(for: index)
        if let first = clips.first {
            selectedClipId = first.id
        }
    }

    // MARK: - Audio File Import via OpenPanel (編集ファイル読み込み時のようなファイル画面)
    private func selectAudioFileViaOpenPanel(type: String) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.message = "シーン \(selectedSceneIndex) に配置する\(type)ファイル (.wav, .mp3, .m4a, .aiff, .ogg, .flac) を選択してください"
        panel.prompt = "タイムラインに読み込み"

        if panel.runModal() == .OK {
            let urls = panel.urls
            for (offset, url) in urls.enumerated() {
                let fileName = url.deletingPathExtension().lastPathComponent
                let ext = url.pathExtension.uppercased()

                // 音声の長さと波形を精密取得
                var audioDuration: Double = (type == "BGM") ? 30.0 : 1.2
                if let player = try? AVAudioPlayer(contentsOf: url) {
                    audioDuration = max(0.4, player.duration)
                }

                let sRange = sceneTimeRange(index: max(0, selectedSceneIndex - 1))
                let clipStartTime = sRange.start + (Double(offset) * 0.4)

                let trackId: String
                let trackColor: String
                if type == "BGM" {
                    trackId = appState.audioTracks.first(where: { $0.type == "bgm" })?.id ?? "track_bgm"
                    trackColor = "#9B59B6"
                } else {
                    trackId = appState.audioTracks.first(where: { $0.type == "se" })?.id ?? "track_se"
                    trackColor = "#2ECC71"
                }

                let waveCount = max(16, min(48, Int(audioDuration * 4)))
                let newClip = SoundClip(
                    name: "\(type): \(fileName)",
                    type: type,
                    duration: audioDuration,
                    volume: (type == "BGM") ? 0.65 : 0.85,
                    startTime: clipStartTime,
                    trackId: trackId,
                    colorHex: trackColor,
                    waveformPoints: generateRandomWaveform(count: waveCount),
                    sceneIndex: selectedSceneIndex,
                    audioFilePath: url.path
                )
                appState.soundClips.append(newClip)
                selectedClipId = newClip.id
                appState.log("シーン \(selectedSceneIndex) に\(type)「\(fileName) (\(ext))」を読み込み配置しました (長さ: \(String(format: "%.2f", audioDuration))秒)")
            }
        }
    }

    private func addPresetSE(name: String) {
        let sRange = sceneTimeRange(index: max(0, selectedSceneIndex - 1))
        let seClip = SoundClip(
            name: name,
            type: "SE",
            duration: 0.8,
            volume: 0.85,
            startTime: sRange.start + 0.1,
            trackId: "track_se",
            colorHex: "#2ECC71",
            waveformPoints: [0.9, 0.7, 0.4, 0.2, 0.05],
            sceneIndex: selectedSceneIndex
        )
        appState.soundClips.append(seClip)
        selectedClipId = seClip.id
        appState.log("シーン \(selectedSceneIndex) に\(name)を追加しました")
    }

    private func seekToScene(index: Int) {
        let scenes = activeSceneList()
        guard index >= 0 && index < scenes.count else { return }
        var acc: Double = 0.0
        for i in 0..<index {
            acc += scenes[i].duration
        }
        currentTime = min(totalTimelineDuration, acc)
    }

    private func sceneTimeRange(index: Int) -> (start: Double, end: Double) {
        let scenes = activeSceneList()
        guard index >= 0 && index < scenes.count else { return (0, 0) }
        var acc: Double = 0.0
        for i in 0..<index {
            acc += scenes[i].duration
        }
        let dur = scenes[index].duration
        return (acc, acc + dur)
    }

    // 特定のシーンに属する音声クリップ (Voice)
    private func voiceClips(for sceneIdx: Int) -> [SoundClip] {
        let scenes = activeSceneList()
        guard sceneIdx >= 1 && sceneIdx <= scenes.count else { return [] }
        let (sStart, sEnd) = sceneTimeRange(index: sceneIdx - 1)

        return appState.soundClips.filter { clip in
            if clip.type != "Voice" { return false }
            if let cIdx = clip.sceneIndex {
                return cIdx == sceneIdx
            }
            // sceneIndex 未設定の場合は時間帯で判定
            let clipMid = clip.startTime + (clip.duration * 0.5)
            return clipMid >= sStart && clipMid < sEnd
        }
    }

    /// クリップを削除し、タイムラインおよびムービーメーカーのシーン情報（BGM/SE/ボイス）と即時完全同期
    private func deleteClip(_ clip: SoundClip) {
        if soundManager.currentlyPlayingClipId == clip.id {
            soundManager.stopPreview()
        }
        appState.soundClips.removeAll(where: { $0.id == clip.id })
        if selectedClipId == clip.id {
            selectedClipId = nil
        }
        // ムービーメーカー側のシーン音声情報（BGM/SE/ボイス）と即時完全同期
        appState.syncClipsToMovieScenes(appState.soundClips)
    }

    // 特定のシーンに属する、またはそのシーンをカバーしているBGM
    private func bgmClips(for sceneIdx: Int) -> [SoundClip] {
        let scenes = activeSceneList()
        guard sceneIdx >= 1 && sceneIdx <= scenes.count else { return [] }
        let (sStart, sEnd) = sceneTimeRange(index: sceneIdx - 1)

        return appState.soundClips.filter { clip in
            if clip.type != "BGM" { return false }
            // 複数シーン跨ぎの場合
            if let start = clip.spanStartSceneIndex, let end = clip.spanEndSceneIndex {
                return sceneIdx >= start && sceneIdx <= end
            }
            if let cIdx = clip.sceneIndex, cIdx == sceneIdx {
                return true
            }
            // 時間重複判定
            let clipStart = clip.startTime
            let clipEnd = clip.startTime + clip.duration
            return (clipStart < sEnd && clipEnd > sStart)
        }
    }

    // 特定のシーンに属する、またはそのシーンをカバーしているSE
    private func seClips(for sceneIdx: Int) -> [SoundClip] {
        let scenes = activeSceneList()
        guard sceneIdx >= 1 && sceneIdx <= scenes.count else { return [] }
        let (sStart, sEnd) = sceneTimeRange(index: sceneIdx - 1)

        return appState.soundClips.filter { clip in
            if clip.type != "SE" { return false }
            if let start = clip.spanStartSceneIndex, let end = clip.spanEndSceneIndex {
                return sceneIdx >= start && sceneIdx <= end
            }
            if let cIdx = clip.sceneIndex, cIdx == sceneIdx {
                return true
            }
            let clipMid = clip.startTime + (clip.duration * 0.5)
            return clipMid >= sStart && clipMid < sEnd
        }
    }

    // 音声クリップの試聴プレビュー再生
    private func togglePlayVoiceClip(_ clip: SoundClip) {
        if playingClipPreviewId == clip.id {
            playingClipPreviewId = nil
            return
        }

        playingClipPreviewId = clip.id
        let text = clip.text ?? clip.name
        let char = clip.character ?? "博麗霊夢"
        let vType = clip.voiceType ?? aquesTalk.voiceType(for: char)
        let effectivePitch = clip.pitch != 100 ? clip.pitch : aquesTalk.characterPreset(for: char).pitch

        aquesTalk.synthesizeAndPlay(
            text: text,
            speed: clip.speed,
            voice: vType,
            pitch: effectivePitch,
            quality: selectedQuality,
            effect: selectedEffect
        ) {
            DispatchQueue.main.async {
                if self.playingClipPreviewId == clip.id {
                    self.playingClipPreviewId = nil
                }
            }
        }
    }

    // ⚡️ この音声を現在のパラメータで再生成
    private func regenerateVoiceClip(_ clip: SoundClip) {
        guard let rawText = clip.text, !rawText.isEmpty else { return }
        let text = SlideItem.cleanDialogueText(from: rawText)
        guard !text.isEmpty else { return }
        let char = clip.character ?? targetCharacter
        let vType = clip.voiceType ?? aquesTalk.voiceType(for: char)
        let speed = clip.speed
        let effectivePitch = clip.pitch != 100 ? clip.pitch : aquesTalk.characterPreset(for: char).pitch

        isRegeneratingVoice = true
        appState.log("シーン \(selectedSceneIndex) の音声『\(text)』を再生成中 (音程: \(effectivePitch)%)...")

        DispatchQueue.global(qos: .userInitiated).async {
            let wavData = self.aquesTalk.synthesizeToWavData(
                text: text,
                speed: speed,
                voice: vType,
                pitch: effectivePitch,
                quality: self.selectedQuality,
                effect: self.selectedEffect
            )

            // 音声ファイル保存先を決定・更新
            var targetFilePath: String? = clip.audioFilePath
            if let data = wavData {
                let audioDir = URL(fileURLWithPath: "/Volumes/ZSSD/GitHub/repository/TohoStudio/Application/Resource/GeneratedAudio")
                try? FileManager.default.createDirectory(at: audioDir, withIntermediateDirectories: true)
                let sIdx = clip.sceneIndex ?? self.selectedSceneIndex
                let safeChar = char.replacingOccurrences(of: "/", with: "_")
                let fileURL = audioDir.appendingPathComponent(String(format: "Slide_%03d_%@.wav", sIdx, safeChar))
                if (try? data.write(to: fileURL)) != nil {
                    targetFilePath = fileURL.path
                }
            }

            DispatchQueue.main.async {
                self.isRegeneratingVoice = false
                guard let idx = self.appState.soundClips.firstIndex(where: { $0.id == clip.id }) else { return }

                if let data = wavData, data.count > 44 {
                    let sampleRate = Double(data.withUnsafeBytes { $0.load(fromByteOffset: 24, as: UInt32.self) })
                    let pcmBytes = Double(data.count - 44)
                    let newDur = max(1.2, pcmBytes / (max(8000.0, sampleRate) * 2.0))

                    self.appState.soundClips[idx].duration = newDur
                    self.appState.soundClips[idx].waveformPoints = self.generateRandomWaveform(count: 24)
                }

                self.appState.soundClips[idx].text = text
                self.appState.soundClips[idx].voiceSymbol = self.aquesTalk.convertToVoiceSymbol(text: text)
                self.appState.soundClips[idx].voiceType = vType
                self.appState.soundClips[idx].speed = speed
                self.appState.soundClips[idx].pitch = effectivePitch
                if let path = targetFilePath {
                    self.appState.soundClips[idx].audioFilePath = path
                }

                // ムービーメーカーのシーン情報（voiceAudioPath）とも即時同期
                self.appState.syncClipsToMovieScenes(self.appState.soundClips)

                self.appState.log("シーン \(self.selectedSceneIndex) の音声『\(text)』を再生成しました (音程: \(effectivePitch)%, 長さ: \(String(format: "%.2f", self.appState.soundClips[idx].duration))秒)")
            }
        }
    }

    // 現在選択中のシーンに新規音声クリップを追加
    private func addVoiceClipToCurrentScene() {
        let sRange = sceneTimeRange(index: max(0, selectedSceneIndex - 1))
        let scenes = activeSceneList()
        let activeScene = (selectedSceneIndex >= 1 && selectedSceneIndex <= scenes.count) ? scenes[selectedSceneIndex - 1] : nil
        let sceneTelop = activeScene?.telop ?? ""
        let cleanedTelop = SlideItem.cleanDialogueText(from: sceneTelop)
        let sampleText = cleanedTelop.isEmpty ? "シーン\(selectedSceneIndex)のセリフです。" : cleanedTelop

        let sceneChar = activeScene?.characterName
        let effectiveChar = (sceneChar != nil && !sceneChar!.isEmpty && sceneChar != "ナレーション") ? sceneChar! : targetCharacter

        let voiceTrack = appState.audioTracks.first(where: { $0.characterName == effectiveChar || $0.type == "voice" })
        let trackId = voiceTrack?.id ?? "track_voice_reimu"
        let clipColor = voiceTrack?.colorHex ?? "#E74C3C"

        let preset = aquesTalk.characterPreset(for: effectiveChar)
        let vType = preset.voice
        let effectiveSpeed = speechSpeed != 100 ? speechSpeed : preset.speed
        let effectivePitch = preset.pitch

        let newClip = SoundClip(
            name: "[\(effectiveChar)] \(sampleText)",
            type: "Voice",
            character: effectiveChar,
            text: sampleText,
            voiceSymbol: aquesTalk.convertToVoiceSymbol(text: sampleText),
            duration: max(2.0, Double(sampleText.count) * 0.22),
            volume: 1.0,
            speed: effectiveSpeed,
            startTime: sRange.start + 0.2,
            trackId: trackId,
            pan: 0.0,
            colorHex: clipColor,
            waveformPoints: generateRandomWaveform(count: 20),
            sceneIndex: selectedSceneIndex,
            voiceType: vType,
            pitch: effectivePitch
        )
        appState.soundClips.append(newClip)
        selectedClipId = newClip.id
        appState.syncClipsToMovieScenes(appState.soundClips)
        appState.log("シーン \(selectedSceneIndex) に新規音声『\(sampleText)』を追加しました (音程: \(effectivePitch)%)")
    }

    // 現在選択中のシーンに効果音を追加
    private func addSEToCurrentScene() {
        let sRange = sceneTimeRange(index: max(0, selectedSceneIndex - 1))
        let seClip = SoundClip(
            name: "SE: 決定音",
            type: "SE",
            duration: 0.8,
            volume: 0.85,
            startTime: sRange.start + 0.1,
            trackId: "track_se",
            colorHex: "#2ECC71",
            waveformPoints: [0.9, 0.7, 0.4, 0.2, 0.05],
            sceneIndex: selectedSceneIndex
        )
        appState.soundClips.append(seClip)
        selectedClipId = seClip.id
        appState.log("シーン \(selectedSceneIndex) にSEを追加しました")
    }

    // MARK: - Helpers
    private func selectedClip() -> SoundClip? {
        guard let id = selectedClipId else { return nil }
        return appState.soundClips.first(where: { $0.id == id })
    }

    private func selectedTrack() -> AudioTrack? {
        return appState.audioTracks.first(where: { $0.id == selectedTrackId })
    }

    private func activeSceneList() -> [MovieScene] {
        if !appState.movieScenes.isEmpty {
            return appState.movieScenes
        }
        if !appState.slides.isEmpty {
            return appState.slides.map { s in
                MovieScene(
                    title: s.title.isEmpty ? "スライド #\(s.slideIndex)" : s.title,
                    duration: max(2.5, s.duration),
                    slideTitle: "スライド #\(s.slideIndex)",
                    backgroundName: s.backgroundName,
                    characterName: s.characterName,
                    telop: SlideItem.cleanDialogueText(from: s.telop)
                )
            }
        }
        return [
            MovieScene(title: "シーン 1: 霊夢と魔理沙の会話", duration: 15.0, slideTitle: "第1幕", backgroundName: "神社", characterName: "博麗霊夢", telop: "また異変の気配がするわね"),
            MovieScene(title: "シーン 2: 異変の兆候", duration: 12.0, slideTitle: "第2幕", backgroundName: "魔法の森", characterName: "霧雨魔理沙", telop: "よし、調査に出発だぜ！"),
            MovieScene(title: "シーン 3: 紅魔館前", duration: 18.0, slideTitle: "第3幕", backgroundName: "紅魔館", characterName: "十六夜咲夜", telop: "お嬢様がお待ちかねです")
        ]
    }

    private func currentActiveScene() -> MovieScene? {
        let scenes = activeSceneList()
        guard !scenes.isEmpty else { return nil }

        // 再生中(isPlaying == true)の場合はタイムライン再生ヘッド位置のシーンを追従
        if isPlaying {
            var acc: Double = 0.0
            for s in scenes {
                if currentTime >= acc && currentTime < (acc + s.duration) {
                    return s
                }
                acc += s.duration
            }
        }

        // 停止中は選択中のシーン(selectedSceneIndex)を優先表示
        if selectedSceneIndex >= 1 && selectedSceneIndex <= scenes.count {
            return scenes[selectedSceneIndex - 1]
        }
        return scenes.first
    }

    private func currentActiveSlide() -> SlideItem? {
        let scenes = activeSceneList()
        guard !scenes.isEmpty else { return nil }

        let targetIndex: Int
        if isPlaying {
            var acc: Double = 0.0
            var found = 1
            for (idx, s) in scenes.enumerated() {
                if currentTime >= acc && currentTime < (acc + s.duration) {
                    found = idx + 1
                    break
                }
                acc += s.duration
            }
            targetIndex = found
        } else {
            targetIndex = selectedSceneIndex
        }

        if targetIndex >= 1 && targetIndex <= appState.slides.count {
            return appState.slides[targetIndex - 1]
        }
        return appState.slides.first
    }

    private func sceneIndex(for scene: MovieScene) -> Int {
        let scenes = activeSceneList()
        if let idx = scenes.firstIndex(where: { $0.id == scene.id }) {
            return idx + 1
        }
        return selectedSceneIndex
    }

    private func resolveImage(path: String?, name: String?, subfolder: String?) -> NSImage? {
        let fm = FileManager.default

        if let directPath = path, !directPath.isEmpty, fm.fileExists(atPath: directPath) {
            return NSImage(contentsOfFile: directPath)
        }

        guard let targetName = name, !targetName.isEmpty else { return nil }

        let cleanName = targetName.replacingOccurrences(of: ".png", with: "")
            .replacingOccurrences(of: ".jpg", with: "")
            .replacingOccurrences(of: ".jpeg", with: "")

        let cacheBase = "/Volumes/ZSSD/GitHub/repository/TohoStudio/.cache/keynote_extracted"
        if let enumerator = fm.enumerator(atPath: cacheBase) {
            for case let file as String in enumerator {
                if file.contains(targetName) || file.contains(cleanName) {
                    let fullPath = (cacheBase as NSString).appendingPathComponent(file)
                    if let img = NSImage(contentsOfFile: fullPath) {
                        return img
                    }
                }
            }
        }

        let slidesCacheBase = "/Volumes/ZSSD/GitHub/repository/TohoStudio/.cache/keynote_slides"
        if let enumerator = fm.enumerator(atPath: slidesCacheBase) {
            for case let file as String in enumerator {
                if file.contains(targetName) || file.contains(cleanName) {
                    let fullPath = (slidesCacheBase as NSString).appendingPathComponent(file)
                    if let img = NSImage(contentsOfFile: fullPath) {
                        return img
                    }
                }
            }
        }

        let repoBase = "/Volumes/ZSSD/GitHub/repository/TohoStudio/動画用"
        let searchFolder = subfolder != nil ? (repoBase as NSString).appendingPathComponent(subfolder!) : repoBase
        if fm.fileExists(atPath: searchFolder), let enumerator = fm.enumerator(atPath: searchFolder) {
            for case let file as String in enumerator {
                if file.contains(targetName) || file.contains(cleanName) {
                    let fullPath = (searchFolder as NSString).appendingPathComponent(file)
                    if let img = NSImage(contentsOfFile: fullPath) {
                        return img
                    }
                }
            }
        }

        return nil
    }

    private func colorForType(_ type: String) -> Color {
        switch type {
        case "Movie": return Color(hex: "#3897F0")
        case "Voice": return Color(hex: "#E74C3C")
        case "SE": return Color(hex: "#2ECC71")
        case "BGM": return Color(hex: "#9B59B6")
        default: return .cyan
        }
    }

    private func addVoiceClipToTimeline() {
        let voiceTrack = appState.audioTracks.first(where: { $0.characterName == targetCharacter || $0.type == "voice" })
        let trackId = voiceTrack?.id ?? "track_voice_reimu"
        let clipColor = voiceTrack?.colorHex ?? "#E74C3C"

        let vType = aquesTalk.voiceType(for: targetCharacter)
        let cleanedSpeech = SlideItem.cleanDialogueText(from: inputSpeechText)
        let targetSpeech = cleanedSpeech.isEmpty ? inputSpeechText : cleanedSpeech

        let wavData = aquesTalk.synthesizeToWavData(
            text: targetSpeech,
            speed: speechSpeed,
            voice: vType,
            quality: selectedQuality,
            effect: selectedEffect
        )

        let duration: Double
        let waveform: [Float]
        if let data = wavData, data.count > 44 {
            let sampleRate = Double(data.withUnsafeBytes { $0.load(fromByteOffset: 24, as: UInt32.self) })
            let pcmBytes = Double(data.count - 44)
            duration = max(1.5, pcmBytes / (max(8000.0, sampleRate) * 2.0))
            waveform = generateRandomWaveform(count: 24)
        } else {
            duration = max(2.0, Double(targetSpeech.count) * 0.25)
            waveform = generateRandomWaveform(count: 20)
        }

        let newClip = SoundClip(
            name: "\(targetCharacter): \(targetSpeech)",
            type: "Voice",
            character: targetCharacter,
            text: targetSpeech,
            voiceSymbol: aquesTalk.convertToVoiceSymbol(text: targetSpeech),
            duration: duration,
            volume: 1.0,
            speed: speechSpeed,
            startTime: currentTime,
            trackId: trackId,
            colorHex: clipColor,
            waveformPoints: waveform,
            sceneIndex: selectedSceneIndex,
            voiceType: vType
        )
        appState.soundClips.append(newClip)
        selectedClipId = newClip.id
        let effStr = selectedEffect == .echo ? " (エコー付加)" : ""
        let qualStr = selectedQuality.isEnabled ? " (高音質44.1kHz)" : " (原音8kHz)"
        appState.log("タイムライン \(String(format: "%.1fs", currentTime)) にボイス波形クリップを配置しました\(qualStr)\(effStr)")
    }

    private func ensureDefaultTracksAndClips() {
        if appState.audioTracks.isEmpty {
            appState.audioTracks = [
                AudioTrack(id: "track_movie", name: "video", type: "movie", icon: "film.fill", colorHex: "#3897F0", volume: 0.85, pan: 0.0),
                AudioTrack(id: "track_voice_reimu", name: "博麗霊夢 (Voice)", type: "voice", icon: "waveform", colorHex: "#E74C3C", volume: 1.0, pan: -0.2, characterName: "博麗霊夢"),
                AudioTrack(id: "track_voice_marisa", name: "霧雨魔理沙 (Voice)", type: "voice", icon: "waveform", colorHex: "#F1C40F", volume: 0.95, pan: 0.2, characterName: "霧雨魔理沙"),
                AudioTrack(id: "track_se", name: "SE (効果音)", type: "se", icon: "bolt.fill", colorHex: "#2ECC71", volume: 0.8, pan: 0.0),
                AudioTrack(id: "track_bgm", name: "BGM (背景音楽)", type: "bgm", icon: "music.note", colorHex: "#9B59B6", volume: 0.65, pan: 0.0)
            ]
        }
        ensureTracksForExistingClips()
    }

    /// クリップ内に存在するすべてのトラックをスキャンし、未登録のトラックがあれば自動追加して復元
    private func ensureTracksForExistingClips() {
        var existingTrackIds = Set(appState.audioTracks.map { $0.id })

        if !existingTrackIds.contains("track_movie") {
            appState.audioTracks.insert(AudioTrack(id: "track_movie", name: "video", type: "movie", icon: "film.fill", colorHex: "#3897F0", volume: 0.85, pan: 0.0), at: 0)
            existingTrackIds.insert("track_movie")
        }
        if !existingTrackIds.contains("track_se") {
            appState.audioTracks.append(AudioTrack(id: "track_se", name: "SE (効果音)", type: "se", icon: "bolt.fill", colorHex: "#2ECC71", volume: 0.8, pan: 0.0))
            existingTrackIds.insert("track_se")
        }
        if !existingTrackIds.contains("track_bgm") {
            appState.audioTracks.append(AudioTrack(id: "track_bgm", name: "BGM (背景音楽)", type: "bgm", icon: "music.note", colorHex: "#9B59B6", volume: 0.65, pan: 0.0))
            existingTrackIds.insert("track_bgm")
        }

        for clip in appState.soundClips {
            guard let tid = clip.trackId, !tid.isEmpty, !existingTrackIds.contains(tid) else { continue }
            let charName = clip.character ?? clip.name
            let color = clip.colorHex ?? (charName.contains("霊夢") ? "#E74C3C" : (charName.contains("魔理沙") ? "#F1C40F" : "#00CEC9"))
            let icon = (clip.type == "SE") ? "bolt.fill" : ((clip.type == "BGM") ? "music.note" : "waveform")
            let typeName = clip.type.lowercased()
            let trackName = charName.isEmpty ? "トラック (\(clip.type))" : "\(charName) (\(clip.type))"

            let newTrack = AudioTrack(
                id: tid,
                name: trackName,
                type: typeName,
                icon: icon,
                colorHex: color,
                volume: clip.volume > 0 ? clip.volume : 1.0,
                pan: clip.pan,
                characterName: clip.character
            )

            if let seIdx = appState.audioTracks.firstIndex(where: { $0.id == "track_se" || $0.type == "se" }) {
                appState.audioTracks.insert(newTrack, at: seIdx)
            } else {
                appState.audioTracks.append(newTrack)
            }
            existingTrackIds.insert(tid)
        }
    }

    private func sampleWaveform(for name: String) -> [Float] {
        return [0.2, 0.4, 0.7, 0.9, 0.75, 0.5, 0.8, 0.95, 0.6, 0.3, 0.7, 0.85, 0.5, 0.2]
    }

    private func generateRandomWaveform(count: Int) -> [Float] {
        return (0..<count).map { _ in Float.random(in: 0.15...0.95) }
    }

    // MARK: - Export Dialog
    private var exportAudioDialog: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "square.and.arrow.up.circle.fill")
                    .font(.system(size: 26))
                    .foregroundColor(.cyan)
                VStack(alignment: .leading, spacing: 2) {
                    Text("サウンドメーカー 音声書き出し (Export Audio)")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("タイムラインの音声トラック・クリップを高品質オーディオまたはDAWセッション形式でエクスポートします。")
                        .font(.caption2)
                        .foregroundColor(Color(white: 0.7))
                }
                Spacer()
            }
            .padding(.bottom, 2)

            // Timeline Summary Status Box
            HStack(spacing: 12) {
                summaryBadge(
                    icon: "waveform",
                    title: "総クリップ数",
                    value: "\(appState.soundClips.count) 個",
                    color: .cyan
                )
                summaryBadge(
                    icon: "slider.horizontal.3",
                    title: "アクティブトラック",
                    value: "\(appState.audioTracks.count) トラック",
                    color: .green
                )
                summaryBadge(
                    icon: "clock.fill",
                    title: "タイムライン長",
                    value: formatExportDuration(totalTimelineDuration),
                    color: .purple
                )
            }
            .padding(10)
            .background(Color.white.opacity(0.04))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.08), lineWidth: 1))

            // Export Format & Scope Options
            GroupBox(label: Label("出力フォーマット設定", systemImage: "gearshape.fill").foregroundColor(.white).font(.caption)) {
                VStack(alignment: .leading, spacing: 12) {
                    // Format Picker
                    HStack {
                        Text("書き出し形式:")
                            .font(.caption)
                            .foregroundColor(Color(white: 0.8))
                            .frame(width: 120, alignment: .leading)
                        Picker("", selection: $audioExportFormat) {
                            Text("WAV (非圧縮・最高音質)").tag("WAV (非圧縮・最高音質)")
                            Text("MP3 (192kbps - 軽量)").tag("MP3 (192kbps - 軽量)")
                            Text("M4A (AAC - Mac標準)").tag("M4A (AAC - Mac標準)")
                            Text("AIFF (リニアPCM)").tag("AIFF (リニアPCM)")
                            Text("LOGICX (Logic Proプロジェクト)").tag("LOGICX (Logic Proプロジェクト)")
                            Text("SESX (Auditionセッション)").tag("SESX (Auditionセッション)")
                            Text("ZIP (全トラック・ステム一括アーカイブ)").tag("ZIP (全トラック・ステム一括アーカイブ)")
                        }
                        .pickerStyle(.menu)
                    }

                    // Scope Picker
                    HStack {
                        Text("書き出し範囲:")
                            .font(.caption)
                            .foregroundColor(Color(white: 0.8))
                            .frame(width: 120, alignment: .leading)
                        Picker("", selection: $audioExportScope) {
                            ForEach(SoundMakerExporter.ExportScope.allCases) { scope in
                                Text(scope.rawValue).tag(scope)
                            }
                        }
                        .pickerStyle(.menu)
                        .disabled(audioExportFormat.contains("LOGICX") || audioExportFormat.contains("SESX") || audioExportFormat.contains("ZIP"))
                    }

                    // Format-specific settings
                    if audioExportFormat.contains("WAV") || audioExportFormat.contains("AIFF") {
                        HStack {
                            Text("サンプリングレート:")
                                .font(.caption)
                                .foregroundColor(Color(white: 0.8))
                                .frame(width: 120, alignment: .leading)
                            Picker("", selection: $audioExportSampleRate) {
                                Text("44.1 kHz (CD音質・標準)").tag(44100)
                                Text("48.0 kHz (映像・放送標準)").tag(48000)
                            }
                            .pickerStyle(.menu)
                        }

                        HStack {
                            Text("ビット深度:")
                                .font(.caption)
                                .foregroundColor(Color(white: 0.8))
                                .frame(width: 120, alignment: .leading)
                            Picker("", selection: $audioExportBitDepth) {
                                Text("16-bit PCM (標準)").tag(16)
                                Text("24-bit PCM (スタジオ高音質)").tag(24)
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    if audioExportFormat.contains("MP3") || audioExportFormat.contains("M4A") {
                        HStack {
                            Text("音声ビットレート:")
                                .font(.caption)
                                .foregroundColor(Color(white: 0.8))
                                .frame(width: 120, alignment: .leading)
                            Picker("", selection: $audioExportBitrate) {
                                Text("320 kbps (最高音質)").tag("320k")
                                Text("192 kbps (標準・推奨)").tag("192k")
                                Text("128 kbps (軽量・Web用)").tag("128k")
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    // Normalization
                    Toggle("トゥルーピーク・ノーマライズ (-0.45 dBFS 音割れ防止 & 音圧最適化)", isOn: $audioExportNormalize)
                        .font(.caption)
                        .foregroundColor(Color(white: 0.9))
                }
                .padding(8)
            }

            // Progress Bar & Status (when exporting)
            if isExportingAudio {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(audioExportStatusText.isEmpty ? "書き出し処理中..." : audioExportStatusText)
                            .font(.caption)
                            .foregroundColor(.cyan)
                        Spacer()
                        Text("\(Int(audioExportProgress * 100))%")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.white)
                    }
                    ProgressView(value: audioExportProgress, total: 1.0)
                        .progressViewStyle(.linear)
                }
                .padding(10)
                .background(Color.black.opacity(0.3))
                .cornerRadius(6)
            }

            // Footer
            HStack {
                if isExportingAudio {
                    Button("中止") {
                        SoundMakerExporter.cancelExport()
                    }
                    .foregroundColor(.red)
                } else {
                    Button("キャンセル") {
                        showExportAudioSheet = false
                    }
                    .foregroundColor(Color(white: 0.8))
                }

                Spacer()

                Button("書き出し先を選択して開始...") {
                    startAudioExportProcess()
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExportingAudio || appState.soundClips.isEmpty)
            }
        }
        .padding(24)
        .frame(width: 520)
        .background(DAWTheme.windowBackground)
        .foregroundColor(.white)
    }

    private func formatExportDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    private func summaryBadge(icon: String, title: String, value: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func startAudioExportProcess() {
        let fmt = audioExportFormat.uppercased()
        let ext: String = {
            if fmt.contains("WAV") { return "wav" }
            if fmt.contains("MP3") { return "mp3" }
            if fmt.contains("M4A") { return "m4a" }
            if fmt.contains("AIFF") { return "aiff" }
            if fmt.contains("LOGICX") { return "logicx" }
            if fmt.contains("SESX") { return "sesx" }
            if fmt.contains("ZIP") || audioExportScope == .trackStems || audioExportScope == .individualClips { return "zip" }
            return "wav"
        }()

        let panel = NSSavePanel()
        panel.title = "音声ファイルの書き出し先を指定"
        panel.nameFieldStringValue = "\(appState.currentProjectName)_audio.\(ext)"
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let targetURL = panel.url {
            let options = SoundMakerExporter.ExportOptions(
                format: audioExportFormat,
                scope: audioExportScope,
                sampleRate: audioExportSampleRate,
                bitDepth: audioExportBitDepth,
                audioBitrate: audioExportBitrate,
                normalize: audioExportNormalize,
                includeEffects: true
            )

            isExportingAudio = true
            audioExportProgress = 0.0
            audioExportStatusText = "書き出しの準備中..."

            Task {
                do {
                    // 最新の音声ファイルパスを自動検証・修復
                    let clipsToExport = self.appState.resolveAndRepairAudioPaths(for: self.appState.soundClips)
                    let tracksToExport = self.appState.audioTracks
                    let scenesToExport = self.appState.movieScenes

                    try await SoundMakerExporter.export(
                        clips: clipsToExport,
                        tracks: tracksToExport,
                        scenes: scenesToExport,
                        outputURL: targetURL,
                        options: options
                    ) { progress, status in
                        self.audioExportProgress = progress
                        self.audioExportStatusText = status
                    }

                    await MainActor.run {
                        self.isExportingAudio = false
                        self.showExportAudioSheet = false
                        self.appState.log("音声書き出し完了: \(targetURL.lastPathComponent) (\(self.audioExportFormat))")
                        self.appState.addHistory("ファイル: 音声書き出し完了 (\(targetURL.lastPathComponent))")
                        NSWorkspace.shared.activateFileViewerSelecting([targetURL])
                    }
                } catch {
                    await MainActor.run {
                        self.isExportingAudio = false
                        if case SoundMakerExporter.ExportError.cancelled = error {
                            self.appState.log("音声書き出しがキャンセルされました", level: "WARN")
                        } else {
                            self.exportAudioErrorMessage = error.localizedDescription
                            self.showExportAudioErrorAlert = true
                            self.appState.log("音声書き出し失敗: \(error.localizedDescription)", level: "ERROR")
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Waveform Display Shape (上下対称のリアルなオーディオ波形)
public struct WaveformDisplayShape: Shape {
    public var points: [Float]

    public func path(in rect: CGRect) -> Path {
        var path = Path()
        guard !points.isEmpty else { return path }

        let midY = rect.midY
        let stepX = rect.width / CGFloat(max(1, points.count))

        // Upper Waveform Curve
        path.move(to: CGPoint(x: 0, y: midY))
        for (i, p) in points.enumerated() {
            let x = CGFloat(i) * stepX + (stepX * 0.5)
            let amp = CGFloat(p) * (rect.height * 0.45)
            let y = midY - amp
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.addLine(to: CGPoint(x: rect.width, y: midY))

        // Lower Waveform Curve (Symmetric)
        for (i, p) in points.enumerated().reversed() {
            let x = CGFloat(i) * stepX + (stepX * 0.5)
            let amp = CGFloat(p) * (rect.height * 0.45)
            let y = midY + amp
            path.addLine(to: CGPoint(x: x, y: y))
        }
        path.closeSubpath()

        return path
    }
}

// MARK: - Transport Button Style
private struct TransportButtonStyle: ButtonStyle {
    var isActive: Bool = false
    var activeColor: Color = .cyan

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 28, height: 26)
            .background(isActive ? activeColor.opacity(0.2) : Color.white.opacity(configuration.isPressed ? 0.15 : 0.08))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(isActive ? activeColor : Color.white.opacity(0.12), lineWidth: 1)
            )
            .cornerRadius(4)
    }
}

// MARK: - Color Hex Extension
private extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var int: UInt64 = 0
        scanner.scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
