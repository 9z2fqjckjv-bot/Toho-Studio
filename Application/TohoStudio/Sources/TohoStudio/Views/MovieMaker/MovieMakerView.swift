import SwiftUI
import AVFoundation

public struct MovieMakerView: View {
    @ObservedObject var appState = AppState.shared
    @State private var showHomeScreen: Bool = false
    @State private var isLoadingSpec: Bool = false
    @State private var specLoadingStatus: String = "スライドと音声ファイルを読み込み中…"
    @State private var selectedTrackIndex: Int = 0
    @State private var showExportSheet: Bool = false
    @State private var exportFormat: String = "MP4 (H.264)"
    @State private var autoFitDurationWithVoice: Bool = true
    @State private var showAssignAlert: Bool = false
    @State private var lastAssignSummary: String = ""
    @State private var isExporting: Bool = false
    @State private var exportProgress: Double = 0.0
    @State private var exportStatusText: String = ""
    @State private var exportErrorMessage: String? = nil
    @State private var showExportErrorAlert: Bool = false
    @State private var exportResolution: String = "1920x1080 (Full HD)"
    @State private var includeBurnedSubtitles: Bool = true
    @State private var exportSrtSubtitles: Bool = true

    public init() {}

    public var body: some View {
        Group {
            if showHomeScreen {
                // 仕様書スライド 179: ホーム画面（左右にGoogle広告枠）
                MovieMakerSpecHomeView(
                    onStartEmpty: {
                        showHomeScreen = false
                    },
                    onImportSlideScenario: {
                        isLoadingSpec = true
                        specLoadingStatus = "スライド＆シナリオメーカーから読み込み中…"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            appState.importCurrentSlides(to: .movieMaker)
                            appState.resolveMovieScenesMedia()
                            isLoadingSpec = false
                            showHomeScreen = false
                        }
                    },
                    onImportYmmp: {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseFiles = true
                        panel.message = "ゆっくりムービーメーカー (ymmp) または動画プロジェクトを選択してください"
                        if panel.runModal() == .OK, let url = panel.url {
                            isLoadingSpec = true
                            specLoadingStatus = "プロジェクトを解析中…"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                appState.importSlideScenarioFile(from: url, targetModule: .movieMaker)
                                appState.resolveMovieScenesMedia()
                                isLoadingSpec = false
                                showHomeScreen = false
                            }
                        }
                    },
                    onLoadExisting: {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseFiles = true
                        panel.message = "既存の動画編集ファイル (.tsvm / .key) を選択してください"
                        if panel.runModal() == .OK, let url = panel.url {
                            isLoadingSpec = true
                            specLoadingStatus = "既存ファイルを展開中…"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                                appState.currentProjectPath = url.path
                                appState.importSlideScenarioFile(from: url, targetModule: .movieMaker)
                                appState.resolveMovieScenesMedia()
                                isLoadingSpec = false
                                showHomeScreen = false
                            }
                        }
                    }
                )
            } else if isLoadingSpec {
                // 仕様書スライド 180: 読込画面（左右にGoogle広告枠）
                SpecLoadingScreenWithAds(statusMessage: specLoadingStatus) {
                    isLoadingSpec = false
                    showHomeScreen = true
                }
            } else {
                // 仕様書スライド 181: 編集画面（原則方針スライド246準拠: 編集画面上には一切の広告を表示しない）
                editorContentView
            }
        }
    }

    private var editorContentView: some View {
        VStack(spacing: 0) {
            // Top Toolbar & Extension Badges
            movieMakerTopBar

            Divider()

            // Main Editor Area (Preview + Timeline) - 仕様書準拠動的レイアウト
            HSplitView {
                // Left: Preview & Scene Info
                VStack(spacing: 12) {
                    previewCanvas
                    playbackControlBar
                }
                .frame(minWidth: 420, maxWidth: .infinity)
                .padding(appState.layoutMode == "プレビュー最大化" ? 6 : 12)

                // Right: Inspector / Scene Properties
                if appState.layoutMode != "プレビュー最大化" {
                    sceneInspectorView
                        .frame(minWidth: 260, idealWidth: inspectorWidthForLayout, maxWidth: 420)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                }
            }

            Divider()

            // Bottom Timeline Tracks
            timelineTrackView
                .frame(height: timelineHeightForLayout)
                .background(Color(NSColor.windowBackgroundColor))
        }
        .sheet(isPresented: $showExportSheet) {
            exportSheetView
        }
        .alert(isPresented: $showAssignAlert) {
            Alert(
                title: Text("音声の自動割り当て完了"),
                message: Text(lastAssignSummary),
                dismissButton: .default(Text("OK"))
            )
        }
        .alert(isPresented: $showExportErrorAlert) {
            Alert(
                title: Text("書き出しエラー"),
                message: Text(exportErrorMessage ?? "不明なエラーが発生しました。"),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            // サウンドメーカーのクリップ割り当て（BGM・SE・ボイス）の最新状態を同期
            appState.syncClipsToMovieScenes(appState.soundClips)
            // スライド情報からメディア（画像・動画）を自動解決
            appState.resolveMovieScenesMedia()
        }
    }

    private var timelineHeightForLayout: CGFloat {
        switch appState.layoutMode {
        case "タイムライン重視": return 340
        case "プレビュー最大化": return 120
        case "縦長動画 (9:16)": return 160
        case "正方形動画 (1:1)": return 180
        default: return 200
        }
    }

    private var inspectorWidthForLayout: CGFloat {
        switch appState.layoutMode {
        case "インスペクター重視": return 380
        case "プレビュー最大化": return 220
        case "タイムライン重視": return 240
        default: return 280
        }
    }

    private var canvasAspectRatio: CGFloat {
        switch appState.layoutMode {
        case "縦長動画 (9:16)": return 9.0 / 16.0
        case "正方形動画 (1:1)": return 1.0
        default: return 16.0 / 9.0
        }
    }

    // MARK: - Top Toolbar
    private var movieMakerTopBar: some View {
        HStack(spacing: 12) {
            Label("ムービーメーカー", systemImage: "film")
                .font(.headline)
            Text("(ベース: GoogleVids)")
                .font(.caption)
                .foregroundColor(.secondary)

            Button(action: { showHomeScreen = true }) {
                HStack(spacing: 4) {
                    Image(systemName: "house.fill")
                    Text("ホーム画面 (広告枠あり)")
                }
                .font(.caption)
            }
            .buttonStyle(.bordered)
            .help("仕様書スライド179のホーム画面（Google広告枠あり）を表示します")

            Spacer()

            // App Extensions Status
            HStack(spacing: 6) {
                extensionBadge(title: "FCP Pro機能", isUnlocked: appState.unlockedExtensions.contains("FCP非搭載機能"))
                extensionBadge(title: "Premiere Pro機能", isUnlocked: appState.unlockedExtensions.contains("PremierePro非搭載機能"))
                extensionBadge(title: "リモート独自機能", isUnlocked: appState.unlockedExtensions.contains("リモートサポート＆独自機能"))
            }

            Divider().frame(height: 18)

            // スライド＆シナリオメーカーからのインポートボタン
            Menu {
                Button("スライド＆シナリオファイルを選択 (.tspm / .key)...") {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = false
                    panel.message = "ムービーメーカーへインポートするスライド＆シナリオファイル (.tspm / .key) を選択してください"
                    if panel.runModal() == .OK, let url = panel.url {
                        appState.importSlideScenarioFile(from: url, targetModule: .movieMaker)
                        appState.resolveMovieScenesMedia()
                    }
                }
                if !appState.slides.isEmpty {
                    Button("現在のスライド＆シナリオ (\(appState.slides.count)枚) からタイムライン生成") {
                        appState.importCurrentSlides(to: .movieMaker)
                        appState.resolveMovieScenesMedia()
                    }
                }
            } label: {
                Label("スライド/シナリオをインポート", systemImage: "arrow.down.doc")
            }
            .menuStyle(.borderedButton)

            // サウンドメーカーからの音声読み込み・自動割り当てメニュー
            Menu {
                Button("サウンドメーカーファイルを選択 (.tssm)...") {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = false
                    panel.message = "音声を自動割り当てするサウンドメーカーファイル (.tssm) を選択してください"
                    if panel.runModal() == .OK, let url = panel.url {
                        let res = appState.assignAudioFromSoundMaker(url: url, autoFitDuration: autoFitDurationWithVoice)
                        lastAssignSummary = res.message
                        showAssignAlert = true
                    }
                }

                if !appState.soundClips.isEmpty {
                    Button("現在のサウンドメーカー音声 (\(appState.soundClips.count)件) を自動割り当て") {
                        let res = appState.assignAudioFromSoundMaker(url: nil, autoFitDuration: autoFitDurationWithVoice)
                        lastAssignSummary = res.message
                        showAssignAlert = true
                    }
                }

                Divider()

                Toggle("音声長さに合わせてシーン秒数を自動調整", isOn: $autoFitDurationWithVoice)
            } label: {
                Label("サウンド音声を自動割り当て", systemImage: "waveform.badge.plus")
            }
            .menuStyle(.borderedButton)

            Button(action: { showExportSheet = true }) {
                Label("動画を書き出し", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func extensionBadge(title: String, isUnlocked: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isUnlocked ? Color.green : Color.secondary)
                .frame(width: 6, height: 6)
            Text(title)
                .font(.caption2)
                .foregroundColor(isUnlocked ? .primary : .secondary)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(4)
    }

    // MARK: - Preview Canvas
    private var previewCanvas: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.08))

            if !appState.movieScenes.isEmpty, appState.selectedSceneIndex < appState.movieScenes.count {
                let scene = appState.movieScenes[appState.selectedSceneIndex]
                let media = resolveSceneMedia(scene: scene, index: appState.selectedSceneIndex)

                // 1. 動画再生 (Keynoteアニメーション記録動画または動画ファイル)
                if let vPath = media.videoPath, FileManager.default.fileExists(atPath: vPath) {
                    SlideVideoPlayerView(videoPath: vPath)
                        .id(vPath)
                        .aspectRatio(canvasAspectRatio, contentMode: .fit)
                        .cornerRadius(8)
                        .clipped()
                } else if let slideImage = media.slideImage {
                    // 2. 高解像度スライド画像 (Keynote Native)
                    MovieSlideImageView(slideImage: slideImage, isPlaying: appState.isPlaying, aspectRatio: canvasAspectRatio)
                        .cornerRadius(8)
                        .clipped()
                } else {
                    // 3. レイヤー合成 (背景 + キャラクター立ち絵 + アニメーション)
                    MovieLayerCompositeView(
                        bgImage: media.bgImage,
                        charImage: media.charImage,
                        isPlaying: appState.isPlaying,
                        aspectRatio: canvasAspectRatio,
                        title: scene.title
                    )
                    .cornerRadius(8)
                    .clipped()
                }

                // オーバーレイ情報: シーン番号、情報バッジ
                VStack {
                    HStack {
                        HStack(spacing: 6) {
                            Text("SCENE #\(appState.selectedSceneIndex + 1)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.75))
                                .foregroundColor(.cyan)
                                .cornerRadius(4)

                            if media.videoPath != nil {
                                Label("動画プレビュー", systemImage: "video.fill")
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.blue.opacity(0.85))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            } else if media.slideImage != nil {
                                Label("スライド高解像度", systemImage: "doc.richtext")
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.green.opacity(0.85))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }

                            if let vName = scene.voiceCharacter ?? (scene.voiceAudioPath != nil ? "ボイス割当済" : nil) {
                                Label("🎙️ \(vName)", systemImage: "waveform")
                                    .font(.system(size: 10, weight: .medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.orange.opacity(0.85))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                            }
                        }
                        Spacer()

                        // 解像度＆速度表示
                        Text("\(String(format: "%.1f", appState.playbackSpeed))x | 1920x1080")
                            .font(.system(size: 10, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white.opacity(0.8))
                            .cornerRadius(4)
                    }
                    .padding(10)

                    Spacer()

                    // クリーンなテロップ字幕 (YouTube / ゆっくり解説風)
                    let telopText = scene.displayTelop.isEmpty ? scene.telop : scene.displayTelop
                    if !telopText.isEmpty {
                        VStack(spacing: 4) {
                            if !scene.characterName.isEmpty {
                                HStack {
                                    Text(scene.characterName)
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(.yellow)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color.black.opacity(0.8))
                                        .cornerRadius(4)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                            }

                            Text(telopText)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.black.opacity(0.82))
                                        .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
                                )
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                        }
                    }
                }
            } else {
                // シーンが空の場合の初期ガイダンス画面
                VStack(spacing: 12) {
                    Image(systemName: "film")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)
                    Text("シーンが登録されていません")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("上部の「スライド/シナリオをインポート」または「サウンド音声を自動割り当て」を実行してください")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Debug Playback Overlay (cmd+p+shift+d)
            if appState.isDebugPlayback {
                VStack(alignment: .leading) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("【デバッグ再生モード】").bold().foregroundColor(.yellow)
                            Text("FPS: 60.0 | ビットレート: 14.8 Mbps | レンダラ: Metal")
                            Text("アクティブオブジェクト: 4 | レイヤー深度: 3")
                        }
                        .font(.system(size: 10, design: .monospaced))
                        .padding(6)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(4)
                        Spacer()
                    }
                    Spacer()
                }
                .padding(8)
            }

            // Material Info Overlay (cmd+p+特定キー)
            if let key = appState.activeMaterialInfoKey {
                VStack {
                    Spacer()
                    Text("素材情報表示 [\(key)]: キャラクター座標 (X: 120, Y: 450), 拡大率 1.0")
                        .font(.caption)
                        .padding(6)
                        .background(Color.blue.opacity(0.85))
                        .foregroundColor(.white)
                        .cornerRadius(6)
                        .padding(.bottom, 60)
                }
            }

            // Rate Overlay (cmd+p+r)
            if appState.showRateOverlay {
                VStack {
                    HStack {
                        Spacer()
                        Text("再生速度: \(String(format: "%.1f", appState.playbackSpeed))x")
                            .font(.caption)
                            .bold()
                            .padding(6)
                            .background(Color.purple.opacity(0.8))
                            .foregroundColor(.white)
                            .cornerRadius(6)
                    }
                    Spacer()
                }
                .padding(8)
            }
        }
        .aspectRatio(canvasAspectRatio, contentMode: .fit)
        .cornerRadius(8)
        .clipped()
        .shadow(color: Color.black.opacity(0.35), radius: 6, x: 0, y: 3)
    }

    // MARK: - Playback Control Bar
    private var playbackControlBar: some View {
        VStack(spacing: 8) {
            // Scrubber
            HStack(spacing: 10) {
                Text(formatTime(appState.currentTime))
                    .font(.caption)
                    .monospacedDigit()
                Slider(
                    value: Binding(
                        get: { appState.currentTime },
                        set: { appState.seekMoviePlayback(to: $0) }
                    ),
                    in: 0...max(appState.totalDuration, 1.0)
                )
                Text(formatTime(appState.totalDuration))
                    .font(.caption)
                    .monospacedDigit()
            }

            // Buttons
            HStack(spacing: 16) {
                // Loop
                Button(action: { appState.isLooping.toggle() }) {
                    Image(systemName: appState.isLooping ? "repeat.1" : "repeat")
                        .foregroundColor(appState.isLooping ? .accentColor : .secondary)
                }
                .buttonStyle(.plain)
                .help(appState.isLooping ? "ループ再生ON" : "ループ再生OFF")

                // 最初から
                Button(action: { appState.seekMoviePlayback(to: 0.0) }) {
                    Image(systemName: "backward.end.fill")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("タイムラインの先頭へ")

                // Rewind 5s
                Button(action: { appState.seekMoviePlayback(to: max(appState.currentTime - 5.0, 0.0)) }) {
                    Image(systemName: "gobackward.5")
                }
                .buttonStyle(.plain)
                .help("5秒巻き戻し")

                // Play / Pause
                Button(action: { appState.toggleMoviePlayback() }) {
                    Image(systemName: appState.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help(appState.isPlaying ? "一時停止 (Space)" : "再生 (Space)")

                // Forward 5s
                Button(action: { appState.seekMoviePlayback(to: min(appState.currentTime + 5.0, appState.totalDuration)) }) {
                    Image(systemName: "goforward.5")
                }
                .buttonStyle(.plain)
                .help("5秒早送り")

                // Speed Selector
                Menu {
                    Button("0.5x") { appState.playbackSpeed = 0.5 }
                    Button("1.0x (標準)") { appState.playbackSpeed = 1.0 }
                    Button("1.5x") { appState.playbackSpeed = 1.5 }
                    Button("2.0x") { appState.playbackSpeed = 2.0 }
                    Button("4.0x") { appState.playbackSpeed = 4.0 }
                } label: {
                    Text("\(String(format: "%.1f", appState.playbackSpeed))x")
                        .font(.caption)
                }

                Spacer()

                // Volume
                HStack(spacing: 6) {
                    Image(systemName: appState.playbackVolume == 0 ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.caption)
                    Slider(value: $appState.playbackVolume, in: 0...1.0)
                        .frame(width: 80)
                }
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Scene Inspector
    private var sceneInspectorView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("シーン設定インスペクター")
                    .font(.headline)

                if appState.selectedSceneIndex < appState.movieScenes.count {
                    let scene = appState.movieScenes[appState.selectedSceneIndex]
                    VStack(alignment: .leading, spacing: 8) {
                        Text("シーンタイトル:").font(.caption).foregroundColor(.secondary)
                        TextField("タイトル", text: Binding(
                            get: { scene.title },
                            set: { appState.movieScenes[appState.selectedSceneIndex].title = $0 }
                        ))
                        .textFieldStyle(.roundedBorder)

                        Text("テロップ / セリフ:").font(.caption).foregroundColor(.secondary)
                        TextEditor(text: Binding(
                            get: { scene.displayTelop.isEmpty ? scene.telop : scene.displayTelop },
                            set: { appState.movieScenes[appState.selectedSceneIndex].telop = SlideItem.cleanDialogueText(from: $0) }
                        ))
                        .frame(height: 60)
                        .border(Color.secondary.opacity(0.2))

                        HStack {
                            Text("表示秒数:")
                            Spacer()
                            Text("\(String(format: "%.1f", scene.duration)) 秒").bold()
                        }
                        .font(.caption)

                        Divider()

                        // MARK: - 割り当て音声セクション
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label("割り当て音声", systemImage: "waveform")
                                    .font(.caption).bold()
                                Spacer()
                                Button("音声を選択...") {
                                    let panel = NSOpenPanel()
                                    panel.canChooseFiles = true
                                    panel.canChooseDirectories = false
                                    panel.message = "このシーンに割り当てる音声ファイル (.wav, .mp3, .aiff) を選択してください"
                                    if panel.runModal() == .OK, let url = panel.url {
                                        appState.movieScenes[appState.selectedSceneIndex].voiceAudioPath = url.path
                                        appState.movieScenes[appState.selectedSceneIndex].voiceCharacter = scene.characterName
                                    }
                                }
                                .font(.caption2)
                            }

                            if let vPath = scene.voiceAudioPath, FileManager.default.fileExists(atPath: vPath) {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack {
                                        Image(systemName: "person.wave.2.fill")
                                            .foregroundColor(.orange)
                                        Text(scene.voiceCharacter ?? "ボイス")
                                            .font(.caption).bold()
                                        Spacer()
                                        if let d = scene.voiceDuration {
                                            Text("\(String(format: "%.1f", d))秒")
                                                .font(.caption2).foregroundColor(.secondary)
                                        }
                                        // 試聴ボタン
                                        Button(action: {
                                            let clip = SoundClip(name: (vPath as NSString).lastPathComponent, type: "Voice", duration: scene.voiceDuration ?? scene.duration, audioFilePath: vPath)
                                            SoundMakerAudioManager.shared.togglePreview(clip: clip)
                                        }) {
                                            Image(systemName: SoundMakerAudioManager.shared.isPreviewPlaying && SoundMakerAudioManager.shared.currentlyPlayingClipId == nil ? "stop.circle.fill" : "play.circle.fill")
                                                .foregroundColor(.orange)
                                        }
                                        .buttonStyle(.plain)
                                        .help("この音声を試聴")
                                    }
                                    Text((vPath as NSString).lastPathComponent)
                                        .font(.system(size: 9.5))
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                .padding(6)
                                .background(Color.orange.opacity(0.12))
                                .cornerRadius(6)
                            } else {
                                HStack {
                                    Text("ボイス: 未割り当て")
                                        .font(.caption2).foregroundColor(.secondary)
                                    Spacer()
                                }
                                .padding(6)
                                .background(Color.secondary.opacity(0.08))
                                .cornerRadius(6)
                            }

                            if let seName = scene.seName {
                                HStack {
                                    Image(systemName: "bolt.fill").foregroundColor(.green)
                                    Text("SE: \(seName)").font(.caption2).lineLimit(1)
                                    Spacer()
                                }
                                .padding(4)
                                .background(Color.green.opacity(0.1))
                                .cornerRadius(4)
                            }

                            if let bgmName = scene.bgmName {
                                HStack {
                                    Image(systemName: "music.note").foregroundColor(.purple)
                                    Text("BGM: \(bgmName)").font(.caption2).lineLimit(1)
                                    Spacer()
                                }
                                .padding(4)
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(4)
                            }
                        }

                        Divider()

                        Text("アニメーション設定:").font(.caption).foregroundColor(.secondary)
                        Text((scene.animationName?.isEmpty == false && scene.animationName != "なし") ? scene.animationName! : "なし").font(.callout)

                        Text("トランジション:").font(.caption).foregroundColor(.secondary)
                        Text(scene.transitionName ?? "クロスディゾルブ").font(.callout)

                        Divider()

                        // MARK: - メディア素材設定
                        VStack(alignment: .leading, spacing: 4) {
                            Text("素材情報:").font(.caption).foregroundColor(.secondary)
                            HStack {
                                Text("背景: \(scene.backgroundName)")
                                    .font(.caption2).foregroundColor(.secondary)
                                Spacer()
                            }
                            HStack {
                                Text("立ち絵: \(scene.characterName)")
                                    .font(.caption2).foregroundColor(.secondary)
                                Spacer()
                            }
                        }
                    }
                }
                Spacer()
            }
            .padding()
        }
    }

    // MARK: - Timeline Tracks
    private var timelineTrackView: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("タイムライン (全 \(appState.movieScenes.count) シーン / \(formatTime(appState.totalDuration)))")
                    .font(.caption)
                    .bold()
                Spacer()

                Menu {
                    Button("サウンドメーカーファイルを選択 (.tssm)...") {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseFiles = true
                        panel.canChooseDirectories = false
                        panel.message = "音声を自動割り当てするサウンドメーカーファイル (.tssm) を選択してください"
                        if panel.runModal() == .OK, let url = panel.url {
                            let res = appState.assignAudioFromSoundMaker(url: url, autoFitDuration: autoFitDurationWithVoice)
                            lastAssignSummary = res.message
                            showAssignAlert = true
                        }
                    }
                    if !appState.soundClips.isEmpty {
                        Button("現在のサウンドメーカー音声 (\(appState.soundClips.count)件) を自動割り当て") {
                            let res = appState.assignAudioFromSoundMaker(url: nil, autoFitDuration: autoFitDurationWithVoice)
                            lastAssignSummary = res.message
                            showAssignAlert = true
                        }
                    }
                } label: {
                    Label("サウンドから自動割り当て", systemImage: "waveform.badge.plus")
                        .font(.caption)
                }

                Menu {
                    Button("スライドファイルを選択 (.tspm / .key)...") {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseFiles = true
                        panel.canChooseDirectories = false
                        panel.message = "スライド＆シナリオファイル (.tspm / .key) を選択してください"
                        if panel.runModal() == .OK, let url = panel.url {
                            appState.importSlideScenarioFile(from: url, targetModule: .movieMaker)
                            appState.resolveMovieScenesMedia()
                        }
                    }
                    if !appState.slides.isEmpty {
                        Button("現在のスライド (\(appState.slides.count)枚) から再生成") {
                            appState.importCurrentSlides(to: .movieMaker)
                            appState.resolveMovieScenesMedia()
                        }
                    }
                } label: {
                    Label("スライドからインポート", systemImage: "arrow.down.doc")
                        .font(.caption)
                }

                Button(action: {
                    let newScene = MovieScene(
                        title: "シーン \(appState.movieScenes.count + 1)",
                        duration: 10.0,
                        slideTitle: "スライド \(appState.movieScenes.count + 1)",
                        backgroundName: "博麗神社_境内.png",
                        characterName: "博麗霊夢",
                        telop: "霊夢「新しいシーンよ」"
                    )
                    appState.movieScenes.append(newScene)
                    appState.totalDuration = appState.movieScenes.reduce(0.0) { $0 + $1.duration }
                }) {
                    Label("シーン追加", systemImage: "plus")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)

            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 8) {
                    ForEach(0..<appState.movieScenes.count, id: \.self) { idx in
                        let scene = appState.movieScenes[idx]
                        let isSelected = appState.selectedSceneIndex == idx

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("#\(idx + 1)")
                                    .font(.caption2)
                                    .bold()
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.3))
                                    .foregroundColor(isSelected ? .white : .primary)
                                    .cornerRadius(3)
                                Spacer()
                                Text(String(format: "%.1fs", scene.duration))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }

                            Text(scene.title)
                                .font(.caption)
                                .lineLimit(1)
                                .bold()

                            Text(scene.displayTelop.isEmpty ? scene.telop : scene.displayTelop)
                                .font(.system(size: 9))
                                .lineLimit(2)
                                .foregroundColor(.secondary)

                            Spacer()

                            // 音声割り当てバッジ
                            HStack(spacing: 4) {
                                if let vc = scene.voiceCharacter ?? (scene.voiceAudioPath != nil ? "ボイス" : nil) {
                                    HStack(spacing: 2) {
                                        Image(systemName: "waveform")
                                        Text(vc)
                                    }
                                    .font(.system(size: 8.5, weight: .bold))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.orange.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(3)
                                }
                                if scene.seName != nil {
                                    Image(systemName: "bolt.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(.green)
                                }
                                if scene.videoPath != nil {
                                    Image(systemName: "video.fill")
                                        .font(.system(size: 8))
                                        .foregroundColor(.blue)
                                }
                                Spacer()
                            }
                        }
                        .padding(8)
                        .frame(width: 150, height: 110)
                        .background(isSelected ? Color.accentColor.opacity(0.18) : Color(NSColor.controlBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                        )
                        .cornerRadius(6)
                        .onTapGesture {
                            appState.selectedSceneIndex = idx
                            // シーン開始時刻へ再生ヘッドをシーク
                            let seekTime = appState.movieScenes.prefix(idx).reduce(0.0) { $0 + $1.duration }
                            appState.seekMoviePlayback(to: seekTime)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
        }
    }

    // MARK: - Media Resolution Helpers
    private func resolveSceneMedia(scene: MovieScene, index: Int) -> (videoPath: String?, slideImage: NSImage?, bgImage: NSImage?, charImage: NSImage?) {
        let fm = FileManager.default
        var videoPath = scene.videoPath
        var slideImg: NSImage? = nil

        // 1. スライド連動フォールバック (もしシーン内にパスがなければ appState.slides から参照)
        let slideIndex = index + 1
        let matchedSlide = appState.slides.first(where: { $0.slideIndex == slideIndex })

        if videoPath == nil || videoPath?.isEmpty == true || !fm.fileExists(atPath: videoPath!) {
            if let v = matchedSlide?.animationVideoPath, fm.fileExists(atPath: v) {
                videoPath = v
            }
        }

        // 2. スライド画像の解決
        let sPath = scene.slideImagePath ?? matchedSlide?.slideImagePath
        if let sp = sPath, fm.fileExists(atPath: sp) {
            slideImg = NSImage(contentsOfFile: sp)
        }

        // 3. 背景画像の解決
        let bgPath = scene.backgroundImagePath ?? matchedSlide?.backgroundImagePath
        let bgName = !scene.backgroundName.isEmpty ? scene.backgroundName : matchedSlide?.backgroundName
        let bgImg = resolveImage(path: bgPath, name: bgName, subfolder: "背景")

        // 4. キャラクター画像の解決
        let charPath = scene.characterImagePath ?? matchedSlide?.characterImagePath
        let charName = !scene.characterName.isEmpty ? scene.characterName : matchedSlide?.characterName
        let charImg = resolveImage(path: charPath, name: charName, subfolder: "立ち絵")

        return (videoPath, slideImg, bgImg, charImg)
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

        let cacheBases = [
            "/Volumes/ZSSD/GitHub/repository/TohoStudio/.cache/keynote_extracted",
            "/Volumes/ZSSD/GitHub/repository/TohoStudio/.cache/keynote_slides",
            "/Volumes/ZSSD/GitHub/repository/TohoStudio/動画用"
        ]

        for base in cacheBases {
            let searchDir = (subfolder != nil && base.hasSuffix("動画用")) ? (base as NSString).appendingPathComponent(subfolder!) : base
            guard fm.fileExists(atPath: searchDir) else { continue }
            if let enumerator = fm.enumerator(atPath: searchDir) {
                for case let file as String in enumerator {
                    if file.contains(targetName) || file.contains(cleanName) {
                        let fullPath = (searchDir as NSString).appendingPathComponent(file)
                        if let img = NSImage(contentsOfFile: fullPath) {
                            return img
                        }
                    }
                }
            }
        }

        return nil
    }

    // MARK: - Export Sheet
    private var exportSheetView: some View {
        VStack(spacing: 18) {
            HStack {
                Image(systemName: "film.fill")
                    .font(.title2)
                    .foregroundColor(.accentColor)
                Text("動画・プロジェクトの書き出し (エクスポート)")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 14) {
                Picker("出力形式:", selection: $exportFormat) {
                    Text("MP4 (H.264 - 汎用高画質)").tag("MP4 (H.264)")
                    Text("MOV (Apple ProRes 422 - 編集用最高画質)").tag("MOV (ProRes)")
                    Text("YMMP (ゆっくりMovieMaker4互換)").tag("YMMP")
                    Text("GVID (GoogleVids互換プロジェクト)").tag("GVID")
                    Text("FCPBUNDLE (Final Cut Pro用)").tag("FCPBUNDLE")
                    Text("PRPROJ (Premiere Pro用)").tag("PRPROJ")
                }
                .disabled(isExporting)

                let isVideo = exportFormat.contains("MP4") || exportFormat.contains("MOV") || exportFormat.contains("ProRes") || exportFormat.contains("H.264")
                if isVideo {
                    Picker("解像度:", selection: $exportResolution) {
                        Text("1920x1080 (Full HD 16:9)").tag("1920x1080 (Full HD)")
                        Text("3840x2160 (4K UHD 16:9)").tag("3840x2160 (4K UHD)")
                        Text("1280x720 (HD 16:9)").tag("1280x720 (HD)")
                        Text("1080x1920 (縦長動画 9:16 Shorts/TikTok)").tag("1080x1920 (縦長 9:16)")
                        Text("1080x1080 (正方形 1:1)").tag("1080x1080 (正方形 1:1)")
                    }
                    .disabled(isExporting)

                    // 字幕・テロップ設定
                    VStack(alignment: .leading, spacing: 8) {
                        Text("字幕・テロップ設定:")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.secondary)

                        Toggle("映像内に字幕（テロップ）を焼き込む", isOn: $includeBurnedSubtitles)
                            .disabled(isExporting)

                        Toggle("YouTube / ニコ動用 字幕ファイル (.srt) を同時書き出し", isOn: $exportSrtSubtitles)
                            .disabled(isExporting)

                        Text("※ YouTube・ニコニコ動画の字幕登録機能を利用する場合は、SRTファイルをアップロードできます。字幕焼き込みをOFFにすると文字のないクリーン映像になります。")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
                    .cornerRadius(8)

                    HStack(spacing: 8) {
                        Image(systemName: "info.circle")
                            .foregroundColor(.secondary)
                        Text("全 \(appState.movieScenes.count) シーン (合計 \(formatTime(appState.totalDuration))) をレンダリングして1本の動画に結合します。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "doc.text")
                            .foregroundColor(.secondary)
                        Text("タイムライン情報（シーン・テロップ・音声割当・画像）を外部アプリ用プロジェクト形式で書き出します。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                if isExporting {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: exportProgress, total: 1.0)
                        HStack {
                            Text(exportStatusText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(exportProgress * 100))%")
                                .font(.caption.monospacedDigit())
                                .bold()
                        }
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, 4)

            HStack {
                if isExporting {
                    Button("キャンセル (中止)") {
                        MovieExporter.cancelExport()
                        isExporting = false
                        exportStatusText = "キャンセルされました"
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                } else {
                    Button("閉じる") {
                        showExportSheet = false
                    }
                    Spacer()
                    Button("書き出し先を選択して開始...") {
                        startExportProcess()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding(24)
        .frame(width: 480)
    }

    private func startExportProcess() {
        let isVideo = exportFormat.contains("MP4") || exportFormat.contains("MOV") || exportFormat.contains("ProRes") || exportFormat.contains("H.264")
        let isProRes = exportFormat.contains("ProRes") || exportFormat.contains("MOV")
        let ext: String = {
            if isVideo {
                return isProRes ? "mov" : "mp4"
            } else if exportFormat.contains("YMMP") {
                return "ymmp"
            } else {
                return "json"
            }
        }()

        let panel = NSSavePanel()
        panel.title = "書き出し先の指定"
        panel.nameFieldStringValue = "\(appState.currentProjectName).\(ext)"
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let targetURL = panel.url {
            let (w, h): (Int, Int) = {
                if exportResolution.contains("4K") { return (3840, 2160) }
                if exportResolution.contains("720") { return (1280, 720) }
                if exportResolution.contains("縦長") { return (1080, 1920) }
                if exportResolution.contains("正方形") { return (1080, 1080) }
                return (1920, 1080)
            }()

            let options = MovieExporter.ExportOptions(
                format: exportFormat,
                width: w,
                height: h,
                fps: 30,
                videoBitrate: exportResolution.contains("4K") ? "16M" : "8M",
                audioBitrate: "192k",
                includeBurnedSubtitles: includeBurnedSubtitles,
                exportSrtFile: exportSrtSubtitles
            )

            isExporting = true
            exportProgress = 0.0
            exportStatusText = "書き出しの準備中..."

            Task {
                do {
                    // 最新のメディアパスを解決
                    appState.resolveMovieScenesMedia()
                    let scenesToExport = appState.movieScenes

                    try await MovieExporter.export(
                        scenes: scenesToExport,
                        outputURL: targetURL,
                        options: options
                    ) { progress, status in
                        self.exportProgress = progress
                        self.exportStatusText = status
                    }

                    await MainActor.run {
                        self.isExporting = false
                        self.showExportSheet = false
                        let srtNote = self.exportSrtSubtitles ? " (+SRT字幕)" : ""
                        self.appState.log("動画書き出し完了: \(targetURL.lastPathComponent)\(srtNote)")
                        self.appState.addHistory("ファイル: 動画書き出し完了 (\(targetURL.lastPathComponent)\(srtNote))")
                        NSWorkspace.shared.activateFileViewerSelecting([targetURL])
                    }
                } catch {
                    await MainActor.run {
                        self.isExporting = false
                        if case MovieExporter.ExportError.cancelled = error {
                            self.appState.log("書き出しがキャンセルされました", level: "WARN")
                        } else {
                            self.exportErrorMessage = error.localizedDescription
                            self.showExportErrorAlert = true
                            self.appState.log("書き出し失敗: \(error.localizedDescription)", level: "ERROR")
                        }
                    }
                }
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - Subviews for Movie Preview
public struct MovieSlideImageView: View {
    public let slideImage: NSImage
    public let isPlaying: Bool
    public let aspectRatio: CGFloat

    public init(slideImage: NSImage, isPlaying: Bool, aspectRatio: CGFloat) {
        self.slideImage = slideImage
        self.isPlaying = isPlaying
        self.aspectRatio = aspectRatio
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            slideContent(time: timeline.date.timeIntervalSinceReferenceDate)
        }
    }

    @ViewBuilder
    private func slideContent(time: Double) -> some View {
        let pulse = isPlaying ? (sin(time * 2.5) * 0.015 + 1.0) : 1.0
        ZStack {
            Image(nsImage: slideImage)
                .resizable()
                .aspectRatio(aspectRatio, contentMode: .fit)
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
}

public struct MovieLayerCompositeView: View {
    public let bgImage: NSImage?
    public let charImage: NSImage?
    public let isPlaying: Bool
    public let aspectRatio: CGFloat
    public let title: String

    public init(bgImage: NSImage?, charImage: NSImage?, isPlaying: Bool, aspectRatio: CGFloat, title: String) {
        self.bgImage = bgImage
        self.charImage = charImage
        self.isPlaying = isPlaying
        self.aspectRatio = aspectRatio
        self.title = title
    }

    public var body: some View {
        TimelineView(.animation) { timeline in
            layerContent(time: timeline.date.timeIntervalSinceReferenceDate)
        }
    }

    @ViewBuilder
    private func layerContent(time: Double) -> some View {
        let charBounce = isPlaying ? sin(time * 6.0) * 4.0 : sin(time * 1.8) * 1.0
        ZStack {
            // 背景
            if let bg = bgImage {
                Image(nsImage: bg)
                    .resizable()
                    .aspectRatio(aspectRatio, contentMode: .fill)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [Color(hex: "#1e272e"), Color(hex: "#2f3640"), Color(hex: "#1a1e24")],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            // キャラクター立ち絵
            if let ch = charImage {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(nsImage: ch)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 280)
                            .offset(y: charBounce)
                            .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                        Spacer()
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "film.stack.fill")
                        .font(.system(size: 36))
                        .foregroundColor(Color.accentColor.opacity(0.8))
                        .rotationEffect(.degrees(isPlaying ? (time * 45).truncatingRemainder(dividingBy: 360) : 0))
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.white.opacity(0.85))
                }
            }
        }
        .aspectRatio(aspectRatio, contentMode: .fit)
        .clipped()
    }
}

fileprivate extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
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
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

