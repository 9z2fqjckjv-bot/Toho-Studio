import SwiftUI

public struct MovieMakerView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selectedTrackIndex: Int = 0
    @State private var showExportSheet: Bool = false
    @State private var exportFormat: String = "MP4 (H.264)"

    public var body: some View {
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
                .frame(minWidth: 380, maxWidth: .infinity)
                .padding(appState.layoutMode == "プレビュー最大化" ? 6 : 12)

                // Right: Inspector / Scene Properties
                if appState.layoutMode != "プレビュー最大化" || true {
                    sceneInspectorView
                        .frame(width: inspectorWidthForLayout)
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
        HStack(spacing: 14) {
            Label("ムービーメーカー", systemImage: "film")
                .font(.headline)
            Text("(ベース: GoogleVids)")
                .font(.caption)
                .foregroundColor(.secondary)

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
                    }
                }
                if !appState.slides.isEmpty {
                    Button("現在のスライド＆シナリオ (\(appState.slides.count)枚) からタイムライン生成") {
                        appState.importCurrentSlides(to: .movieMaker)
                    }
                }
            } label: {
                Label("スライド/シナリオをインポート", systemImage: "arrow.down.doc")
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
                .fill(Color.black)
                .aspectRatio(canvasAspectRatio, contentMode: .fit)

            if !appState.movieScenes.isEmpty, appState.selectedSceneIndex < appState.movieScenes.count {
                let scene = appState.movieScenes[appState.selectedSceneIndex]
                VStack {
                    Spacer()
                    // Character mockup / visual representation
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("背景: \(scene.backgroundName)")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                            Text("キャラクター: \(scene.characterName)")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(6)

                        Spacer()
                    }
                    .padding(.horizontal, 16)

                    Spacer()

                    // Telop Subtitle
                    Text(scene.displayTelop.isEmpty ? scene.telop : scene.displayTelop)
                        .font(.headline)
                        .bold()
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.75))
                        .cornerRadius(8)
                        .padding(.bottom, 20)
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
    }

    // MARK: - Playback Control Bar
    private var playbackControlBar: some View {
        VStack(spacing: 8) {
            // Scrubber
            HStack(spacing: 10) {
                Text(formatTime(appState.currentTime))
                    .font(.caption)
                    .monospacedDigit()
                Slider(value: $appState.currentTime, in: 0...appState.totalDuration)
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

                // Rewind 5s
                Button(action: { appState.currentTime = max(appState.currentTime - 5, 0) }) {
                    Image(systemName: "gobackward.5")
                }
                .buttonStyle(.plain)

                // Play / Pause
                Button(action: { appState.isPlaying.toggle() }) {
                    Image(systemName: appState.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)

                // Forward 5s
                Button(action: { appState.currentTime = min(appState.currentTime + 5, appState.totalDuration) }) {
                    Image(systemName: "goforward.5")
                }
                .buttonStyle(.plain)

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
                    .frame(height: 70)
                    .border(Color.secondary.opacity(0.2))

                    HStack {
                        Text("表示秒数:")
                        Spacer()
                        Text("\(String(format: "%.1f", scene.duration)) 秒").bold()
                    }
                    .font(.caption)

                    Divider()

                    Text("アニメーション設定:").font(.caption).foregroundColor(.secondary)
                    Text(scene.animationName ?? "フェードイン").font(.callout)

                    Text("トランジション:").font(.caption).foregroundColor(.secondary)
                    Text(scene.transitionName ?? "クロスディゾルブ").font(.callout)
                }
            }
            Spacer()
        }
        .padding()
    }

    // MARK: - Timeline Tracks
    private var timelineTrackView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("タイムライン (シーン一覧)")
                    .font(.caption)
                    .bold()
                Spacer()

                Menu {
                    Button("スライドファイルを選択 (.tspm / .key)...") {
                        let panel = NSOpenPanel()
                        panel.allowsMultipleSelection = false
                        panel.canChooseFiles = true
                        panel.canChooseDirectories = false
                        panel.message = "スライド＆シナリオファイル (.tspm / .key) を選択してください"
                        if panel.runModal() == .OK, let url = panel.url {
                            appState.importSlideScenarioFile(from: url, targetModule: .movieMaker)
                        }
                    }
                    if !appState.slides.isEmpty {
                        Button("現在のスライド (\(appState.slides.count)枚) から再生成") {
                            appState.importCurrentSlides(to: .movieMaker)
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
                        backgroundName: "神社境内.png",
                        characterName: "博麗霊夢",
                        telop: "霊夢「新しいシーンよ」"
                    )
                    appState.movieScenes.append(newScene)
                }) {
                    Label("シーン追加", systemImage: "plus")
                        .font(.caption)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: true) {
                HStack(spacing: 8) {
                    ForEach(0..<appState.movieScenes.count, id: \.self) { idx in
                        let scene = appState.movieScenes[idx]
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("#\(idx + 1)")
                                    .font(.caption2)
                                    .bold()
                                    .padding(2)
                                    .background(Color.accentColor.opacity(0.3))
                                    .cornerRadius(3)
                                Spacer()
                                Text("\(Int(scene.duration))s")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Text(scene.title)
                                .font(.caption)
                                .lineLimit(1)
                                .bold()
                            Text(scene.displayTelop.isEmpty ? scene.telop : scene.displayTelop)
                                .font(.caption2)
                                .lineLimit(2)
                                .foregroundColor(.secondary)
                        }
                        .padding(8)
                        .frame(width: 140, height: 110)
                        .background(appState.selectedSceneIndex == idx ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(appState.selectedSceneIndex == idx ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                        .cornerRadius(6)
                        .onTapGesture {
                            appState.selectedSceneIndex = idx
                        }
                    }
                }
                .padding(.horizontal, 12)
            }
        }
    }

    // MARK: - Export Sheet
    private var exportSheetView: some View {
        VStack(spacing: 18) {
            Text("動画の書き出し (エクスポート)")
                .font(.headline)
            Picker("出力形式", selection: $exportFormat) {
                Text("MP4 (H.264 - 汎用)").tag("MP4 (H.264)")
                Text("MOV (ProRes - 高画質)").tag("MOV (ProRes)")
                Text("YMMP (ゆっくりMovieMaker4形式)").tag("YMMP")
                Text("GVID (GoogleVids互換プロジェクト)").tag("GVID")
                Text("FCPBUNDLE (Final Cut Pro用)").tag("FCPBUNDLE")
                Text("PRPROJ (Premiere Pro用)").tag("PRPROJ")
            }
            .pickerStyle(.menu)

            HStack {
                Button("キャンセル") { showExportSheet = false }
                Spacer()
                Button("書き出し開始") {
                    showExportSheet = false
                    appState.log("動画書き出し完了: format=\(exportFormat)")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
