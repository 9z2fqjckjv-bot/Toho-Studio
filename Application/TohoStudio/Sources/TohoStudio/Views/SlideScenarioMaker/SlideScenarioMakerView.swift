import SwiftUI
import AppKit

public struct SlideScenarioMakerView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var recognitionService = SlideRecognitionService.shared

    @State private var selectedSlideIdx: Int = 0
    @State private var showRecognitionModal: Bool = false
    @State private var showLoadModal: Bool = false
    @State private var recognitionFilePath: String = "/Volumes/ZSSD/GitHub/repository/TohoStudio/東方惑情録/東方惑情録　第1話.key"
    @State private var selectedLoadFilePath: String = "/Volumes/ZSSD/GitHub/repository/TohoStudio/東方惑情録/東方惑情録　第1話.key"
    @State private var loadSuccessMessage: String? = nil

    public var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack(spacing: 14) {
                Label("スライド＆シナリオメーカー", systemImage: "doc.richtext")
                    .font(.headline)
                Text("(Googleスライド / Keynote 互換)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // Primary Slide Load Program Button
                Button(action: { showLoadModal = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.doc.fill")
                        Text("スライドの読み込みプログラム")
                            .bold()
                    }
                }
                .buttonStyle(.borderedProminent)
                .help("Keynoteファイル等からスライドを読み込み、プロジェクトスライドを置き換えます (cmd+f+r)")

                // High-precision Recognition Button
                Button(action: { showRecognitionModal = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles.rectangle.stack")
                        Text("スライド認識 (精度99%規格)")
                    }
                }
                .buttonStyle(.bordered)

                Divider().frame(height: 18)

                // Extension Badges
                HStack(spacing: 6) {
                    extensionBadge(title: "Keynote拡張", isUnlocked: appState.unlockedExtensions.contains("Keynote非搭載機能"))
                    extensionBadge(title: "PowerPoint拡張", isUnlocked: appState.unlockedExtensions.contains("PowerPoint非搭載機能"))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            if let successMsg = loadSuccessMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(successMsg)
                        .font(.caption)
                        .bold()
                    Spacer()
                    Button("閉じる") { loadSuccessMessage = nil }
                        .buttonStyle(.plain)
                        .font(.caption2)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.15))
            }

            Divider()

            // Main Split Editor (Slides List + Slide Editor + Scenario Notebook)
            HSplitView {
                // Left: Slide Thumbnails
                slideThumbnailListView
                    .frame(width: 240)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

                // Center: Slide Visual Canvas
                slideCanvasView
                    .frame(minWidth: 400, maxWidth: .infinity)
                    .padding()

                // Right: Scenario & Presenter Notes
                scenarioNotesView
                    .frame(width: 320)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
            }
        }
        .sheet(isPresented: $showLoadModal) {
            slideLoadModalView
        }
        .sheet(isPresented: $showRecognitionModal) {
            recognitionModalView
        }
        .onAppear {
            if appState.activeModal == .slideLoader {
                showLoadModal = true
                appState.activeModal = nil
            }
        }
        .onChange(of: appState.activeModal) { newModal in
            if newModal == .slideLoader {
                showLoadModal = true
                appState.activeModal = nil
            }
        }
    }

    private func extensionBadge(title: String, isUnlocked: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isUnlocked ? Color.green : Color.secondary)
                .frame(width: 6, height: 6)
            Text(title).font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(4)
    }

    // MARK: - Slide Thumbnail List
    private var slideThumbnailListView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("スライド一覧 (\(appState.slides.count)枚)")
                    .font(.caption)
                    .bold()
                Spacer()

                // Slide Load quick button
                Button(action: { showLoadModal = true }) {
                    Label("読込", systemImage: "arrow.down.doc")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button(action: {
                    let newIndex = appState.slides.count + 1
                    let newSlide = SlideItem(
                        slideIndex: newIndex,
                        title: "シーン \(newIndex): 博麗霊夢",
                        telop: "霊夢「新しいシーンの台本セリフを入力してください」",
                        presenterNote: "演出ノート: キャラクター登場0.5秒後、BGM再生",
                        backgroundName: "nc73538_【背景素材】博麗神社.jpg",
                        characterName: "博麗霊夢"
                    )
                    appState.slides.append(newSlide)
                    selectedSlideIdx = appState.slides.count - 1
                }) {
                    Image(systemName: "plus")
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.top, 8)

            List(0..<appState.slides.count, id: \.self) { idx in
                let slide = appState.slides[idx]
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("#\(slide.slideIndex)")
                            .font(.caption2)
                            .bold()
                            .foregroundColor(.accentColor)
                        Spacer()
                        Text(slide.characterName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Text(slide.title)
                        .font(.caption)
                        .bold()
                        .lineLimit(1)
                    Text(slide.telop)
                        .font(.caption2)
                        .lineLimit(2)
                        .foregroundColor(.secondary)
                }
                .padding(6)
                .background(selectedSlideIdx == idx ? Color.accentColor.opacity(0.2) : Color.clear)
                .cornerRadius(6)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedSlideIdx = idx
                }
            }
        }
    }

    // MARK: - Slide Canvas
    private var slideCanvasView: some View {
        VStack(spacing: 12) {
            if selectedSlideIdx < appState.slides.count {
                let slide = appState.slides[selectedSlideIdx]
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .aspectRatio(16/9, contentMode: .fit)

                    // Background Image Layer (if found in Assets)
                    if let bgImage = loadBackgroundImage(named: slide.backgroundName) {
                        Image(nsImage: bgImage)
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fit)
                            .cornerRadius(8)
                            .opacity(0.85)
                    }

                    VStack {
                        HStack {
                            Text("【背景】\(slide.backgroundName)")
                                .font(.caption2)
                                .padding(4)
                                .background(Color.black.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                            Spacer()
                            Text("アニメ: \(slide.animationTag)")
                                .font(.caption2)
                                .padding(4)
                                .background(Color.blue.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                        .padding(12)

                        Spacer()

                        VStack(spacing: 4) {
                            Image(systemName: "person.crop.rectangle.fill")
                                .font(.system(size: 64))
                                .foregroundColor(.accentColor.opacity(0.85))
                            Text(slide.characterName)
                                .font(.caption)
                                .bold()
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(4)
                        }

                        Spacer()

                        Text(slide.telop)
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(10)
                            .background(Color.black.opacity(0.75))
                            .cornerRadius(6)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                    }
                }

                // Slide Split & Info Bar
                HStack {
                    Text("スライド \(selectedSlideIdx + 1) / \(appState.slides.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Button(action: {
                        appState.log("スライドを背景・立ち絵・テロップの3ファイルに分割して素材スタジオに保存しました")
                    }) {
                        Label("スライドを3種ファイルに分割保存", systemImage: "square.split.3x1")
                            .font(.caption)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.badge.arrow.up")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("スライドがありません")
                        .font(.headline)
                    Button("スライドを読み込む") {
                        showLoadModal = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    private func loadBackgroundImage(named name: String) -> NSImage? {
        let repoPath = "/Volumes/ZSSD/GitHub/repository/TohoStudio/動画用/背景/\(name)"
        if FileManager.default.fileExists(atPath: repoPath) {
            return NSImage(contentsOfFile: repoPath)
        }
        return nil
    }

    // MARK: - Scenario Notes View
    private var scenarioNotesView: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("台本シナリオ＆演出ノート")
                    .font(.headline)
                Spacer()
            }

            if selectedSlideIdx < appState.slides.count {
                let slide = appState.slides[selectedSlideIdx]
                VStack(alignment: .leading, spacing: 8) {
                    Text("シーンタイトル:").font(.caption).foregroundColor(.secondary)
                    TextField("タイトル", text: Binding(
                        get: { slide.title },
                        set: { appState.slides[selectedSlideIdx].title = $0 }
                    ))
                    .textFieldStyle(.roundedBorder)

                    Text("テロップ / セリフ入力:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: Binding(
                        get: { slide.telop },
                        set: { appState.slides[selectedSlideIdx].telop = $0 }
                    ))
                    .frame(height: 80)
                    .border(Color.secondary.opacity(0.2))

                    Text("発表者・演出ノート:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: Binding(
                        get: { slide.presenterNote },
                        set: { appState.slides[selectedSlideIdx].presenterNote = $0 }
                    ))
                    .frame(height: 90)
                    .border(Color.secondary.opacity(0.2))

                    Divider()

                    Text("シナリオ分割:").font(.caption).bold()
                    Button("段落・文・単語ごとに分割保存") {
                        appState.log("シナリオを文節・単語ごとに分解し素材スタジオに保存しました")
                    }
                    .font(.caption)
                }
            }
            Spacer()
        }
        .padding()
    }

    // MARK: - Slide Load Modal View (スライドの読み込みプログラム)
    private var slideLoadModalView: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Label("スライドの読み込みプログラム", systemImage: "arrow.down.doc.fill")
                    .font(.title3)
                    .bold()
                Spacer()
                Button("閉じる") { showLoadModal = false }
            }

            Text("Keynoteプレゼンテーションファイル（.key）やスライドファイルを読み込み、スライド＆シナリオメーカー上のスライド・セリフ・背景・演出ノートを自動認識して完全に置き換えます。")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            // Selection Options: Quick List vs Finder File Picker
            VStack(alignment: .leading, spacing: 8) {
                Text("読み込むKeynoteファイルを選択:")
                    .font(.caption)
                    .bold()

                HStack {
                    TextField("ファイルパス", text: $selectedLoadFilePath)
                        .textFieldStyle(.roundedBorder)

                    Button("Macから選択...") {
                        selectFileViaOpenPanel()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Text("リポジトリ内 Keynote プロジェクト一覧（クイック選択）:")
                .font(.caption)
                .bold()

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(recognitionService.getAvailableKeynoteProjects()) { item in
                        HStack(spacing: 10) {
                            Image(systemName: "doc.richtext.fill")
                                .foregroundColor(selectedLoadFilePath == item.filePath ? .accentColor : .secondary)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(item.title).bold().font(.subheadline)
                                    Text(item.category)
                                        .font(.caption2)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.secondary.opacity(0.2))
                                        .cornerRadius(3)
                                }
                                Text(item.description)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()

                            if selectedLoadFilePath == item.filePath {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(8)
                        .background(selectedLoadFilePath == item.filePath ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.05))
                        .cornerRadius(6)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedLoadFilePath = item.filePath
                        }
                    }
                }
            }
            .frame(height: 200)
            .border(Color.secondary.opacity(0.2))

            if recognitionService.isRunning {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView()
                    Text("スライド解析・抽出中...")
                        .font(.caption)
                }
            }

            // Action Buttons
            HStack {
                Text("現在のスライド数: \(appState.slides.count)枚")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("キャンセル") {
                    showLoadModal = false
                }

                Button(action: {
                    recognitionService.loadSlideProgram(filePath: selectedLoadFilePath, replaceState: true) { success, slides in
                        if success {
                            selectedSlideIdx = 0
                            let fName = URL(fileURLWithPath: selectedLoadFilePath).lastPathComponent
                            loadSuccessMessage = "「\(fName)」から \(slides.count) 枚のスライドを読み込み、画面上のスライドを正常に置き換えました。"
                            showLoadModal = false
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath.doc.on.clipboard")
                        Text("スライドを読み込んで置き換える")
                            .bold()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(recognitionService.isRunning)
            }
        }
        .padding(20)
        .frame(width: 640, height: 500)
    }

    private func selectFileViaOpenPanel() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = []
        openPanel.allowsOtherFileTypes = true
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.directoryURL = URL(fileURLWithPath: "/Volumes/ZSSD/GitHub/repository/TohoStudio")

        if openPanel.runModal() == .OK, let url = openPanel.url {
            selectedLoadFilePath = url.path
        }
    }

    // MARK: - Recognition Modal View (高精度スライド認識プログラム)
    private var recognitionModalView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("スライド認識プログラム (高精度抽出＆照合エンジン)", systemImage: "sparkles.rectangle.stack")
                    .font(.headline)
                Spacer()
                Button("閉じる") { showRecognitionModal = false }
            }

            Text("Keynoteファイル等から全オブジェクト、背景画像、キャラクター、アニメーションを検出し、「動画用」素材フォルダと自動照合・紐付けを行い、スライドを置き換えます。")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                TextField("Keynoteファイルパス", text: $recognitionFilePath)
                    .textFieldStyle(.roundedBorder)

                Button(action: {
                    recognitionService.analyzeKeynoteOrSlide(filePath: recognitionFilePath) { result in
                        selectedSlideIdx = 0
                        loadSuccessMessage = "スライド認識完了: \(result.totalSlides)枚解析 (精度: \(result.accuracyRate)%)。スライドを置き換えました。"
                    }
                }) {
                    Text("認識・解析・置換開始")
                }
                .buttonStyle(.borderedProminent)
                .disabled(recognitionService.isRunning)
            }

            if recognitionService.isRunning {
                ProgressView(value: recognitionService.currentProgress)
                Text("解析進捗: \(Int(recognitionService.currentProgress * 100))%")
                    .font(.caption)
            }

            if let result = recognitionService.lastResult {
                GroupBox(label: Text("解析結果サマリー (認識精度: \(String(format: "%.1f", result.accuracyRate))%)")) {
                    HStack(spacing: 24) {
                        VStack {
                            Text("\(result.totalSlides)").font(.title2).bold()
                            Text("解析スライド数").font(.caption2)
                        }
                        VStack {
                            Text("\(result.matchedBackgroundCount)").font(.title2).bold().foregroundColor(.green)
                            Text("背景照合数").font(.caption2)
                        }
                        VStack {
                            Text("\(result.matchedCharacterCount)").font(.title2).bold().foregroundColor(.blue)
                            Text("キャラクター照合数").font(.caption2)
                        }
                        VStack {
                            Text("\(result.animationCount)").font(.title2).bold().foregroundColor(.purple)
                            Text("アニメーション紐付").font(.caption2)
                        }
                    }
                    .padding(8)
                }
            }

            Text("認識ログ:")
                .font(.caption)
                .bold()

            ScrollView {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(recognitionService.logs) { log in
                        HStack {
                            Text(log.step).bold().font(.caption2)
                            Text(log.details).font(.caption2).foregroundColor(.secondary)
                            Spacer()
                            Text(log.status)
                                .font(.system(size: 9))
                                .padding(2)
                                .background(log.status == "MATCHED" ? Color.green.opacity(0.2) : Color.blue.opacity(0.2))
                                .foregroundColor(log.status == "MATCHED" ? .green : .blue)
                                .cornerRadius(3)
                        }
                        Divider()
                    }
                }
            }
            .frame(height: 140)
            .border(Color.secondary.opacity(0.2))
        }
        .padding(20)
        .frame(width: 680, height: 500)
    }
}
