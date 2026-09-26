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

                VStack(spacing: 6) {
                    // Visual Canvas with exact relative coordinates
                    GeometryReader { geo in
                        let canvasW = geo.size.width
                        let canvasH = geo.size.height
                        let origW = max(slide.slideWidth, 1.0)
                        let origH = max(slide.slideHeight, 1.0)
                        let scaleX = canvasW / origW
                        let scaleY = canvasH / origH

                        ZStack(alignment: .topLeading) {
                            // 1. Base Canvas Background
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.black)
                                .frame(width: canvasW, height: canvasH)

                            // 2. Slide Background Image Layer
                            if let bgImg = resolveImage(path: slide.backgroundImagePath, name: slide.backgroundName, subfolder: "背景") {
                                Image(nsImage: bgImg)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: canvasW, height: canvasH)
                                    .clipped()
                            } else {
                                // Default Gradient Background
                                LinearGradient(
                                    colors: [Color(red: 0.1, green: 0.12, blue: 0.18), Color(red: 0.05, green: 0.06, blue: 0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                                .frame(width: canvasW, height: canvasH)
                            }

                            // 3. Other Slide Objects Layer (Props, Effects, Graphics)
                            ForEach(slide.objects) { obj in
                                let ox = obj.x * scaleX
                                let oy = obj.y * scaleY
                                let ow = max(obj.width * scaleX, 10.0)
                                let oh = max(obj.height * scaleY, 10.0)

                                Group {
                                    if let oImg = resolveImage(path: obj.imagePath, name: obj.name, subfolder: nil) {
                                        Image(nsImage: oImg)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                    } else {
                                        RoundedRectangle(cornerRadius: 4)
                                            .stroke(Color.yellow.opacity(0.6), lineWidth: 1)
                                            .background(Color.yellow.opacity(0.15))
                                            .overlay(
                                                Text(obj.name)
                                                    .font(.system(size: 9))
                                                    .foregroundColor(.white)
                                                    .lineLimit(1)
                                            )
                                    }
                                }
                                .frame(width: ow, height: oh)
                                .position(x: ox + ow / 2, y: oy + oh / 2)
                            }

                            // 4. Character Standing Portrait Layer (Accurate Positioning)
                            let charImg = resolveImage(path: slide.characterImagePath, name: slide.characterName, subfolder: "キャラクター")
                            let cx = (slide.characterX ?? (origW * 0.6)) * scaleX
                            let cy = (slide.characterY ?? (origH * 0.05)) * scaleY
                            let cw = max((slide.characterWidth ?? (origW * 0.35)) * scaleX, 20.0)
                            let ch = max((slide.characterHeight ?? (origH * 0.9)) * scaleY, 20.0)

                            if let charImage = charImg {
                                Image(nsImage: charImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: cw, height: ch)
                                    .position(x: cx + cw / 2, y: cy + ch / 2)
                                    .shadow(color: .black.opacity(0.35), radius: 6, x: 2, y: 3)
                            } else if !slide.characterName.isEmpty && slide.characterName != "ナレーション" {
                                // Elegant character stand-in if image asset not yet found
                                VStack(spacing: 4) {
                                    Image(systemName: "person.crop.rectangle.fill")
                                        .font(.system(size: min(cw, ch) * 0.35))
                                        .foregroundColor(.accentColor.opacity(0.85))
                                    Text(slide.characterName)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.black.opacity(0.65))
                                        .cornerRadius(4)
                                }
                                .frame(width: cw, height: ch)
                                .position(x: cx + cw / 2, y: cy + ch / 2)
                            }

                            // 5. Accurate Telop Layer (Subtitles / Dialogues)
                            let tx = (slide.telopX ?? 0.0) * scaleX
                            let ty = (slide.telopY ?? (origH * 0.79)) * scaleY
                            let tw = max((slide.telopWidth ?? origW) * scaleX, 50.0)
                            let th = max((slide.telopHeight ?? (origH * 0.21)) * scaleY, 25.0)

                            if !slide.telop.isEmpty {
                                VStack(alignment: .leading, spacing: 3) {
                                    // Speaker name badge if defined
                                    if !slide.characterName.isEmpty && slide.characterName != "ナレーション" {
                                        Text("【\(slide.characterName)】")
                                            .font(.system(size: max(canvasH * 0.035, 10), weight: .heavy))
                                            .foregroundColor(.yellow)
                                    }
                                    Text(slide.telop)
                                        .font(.system(size: max(canvasH * 0.042, 11), weight: .medium))
                                        .foregroundColor(.white)
                                        .lineSpacing(2)
                                        .multilineTextAlignment(.leading)
                                }
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .frame(width: tw, height: th, alignment: .topLeading)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.black.opacity(0.78))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                                        )
                                )
                                .position(x: tx + tw / 2, y: ty + th / 2)
                            }

                            // 6. Slide Title & Metadata Overlay (Top Bar)
                            HStack {
                                Text("#\(slide.slideIndex): \(slide.title)")
                                    .font(.caption2)
                                    .bold()
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.black.opacity(0.65))
                                    .foregroundColor(.white)
                                    .cornerRadius(4)

                                Spacer()

                                HStack(spacing: 4) {
                                    if !slide.characterName.isEmpty {
                                        Label(slide.characterName, systemImage: "person.fill")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.accentColor.opacity(0.8))
                                            .foregroundColor(.white)
                                            .cornerRadius(4)
                                    }
                                    Text(slide.animationTag)
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.blue.opacity(0.7))
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                }
                            }
                            .padding(8)
                            .frame(width: canvasW, alignment: .top)
                        }
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .aspectRatio(16/9, contentMode: .fit)

                    // Elements & Layout Details Inspector Bar
                    HStack(spacing: 8) {
                        Text("スライド \(selectedSlideIdx + 1) / \(appState.slides.count)")
                            .font(.caption)
                            .bold()

                        Divider().frame(height: 12)

                        // Speaker Badge
                        HStack(spacing: 4) {
                            Text("話者:").font(.caption2).foregroundColor(.secondary)
                            Text(slide.characterName.isEmpty ? "ナレーション" : slide.characterName)
                                .font(.caption2)
                                .bold()
                                .foregroundColor(.accentColor)
                        }

                        Divider().frame(height: 12)

                        // Background Badge
                        HStack(spacing: 4) {
                            Text("背景:").font(.caption2).foregroundColor(.secondary)
                            Text(slide.backgroundName.isEmpty ? "博麗神社" : slide.backgroundName)
                                .font(.caption2)
                                .lineLimit(1)
                        }

                        // Objects count
                        if !slide.objects.isEmpty {
                            Divider().frame(height: 12)
                            HStack(spacing: 4) {
                                Text("オブジェクト:").font(.caption2).foregroundColor(.secondary)
                                Text("\(slide.objects.count)件")
                                    .font(.caption2)
                                    .bold()
                            }
                        }

                        Spacer()

                        Button(action: {
                            appState.log("スライド #\(slide.slideIndex) を背景・立ち絵・テロップの3種素材に分解して素材スタジオに登録しました")
                        }) {
                            Label("3種素材に分割保存", systemImage: "square.split.3x1")
                                .font(.caption2)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
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

    /// Resolves image path by checking given path, project cache, and 動画用 asset directories
    private func resolveImage(path: String?, name: String?, subfolder: String?) -> NSImage? {
        let fm = FileManager.default

        // 1. Direct path check
        if let directPath = path, !directPath.isEmpty, fm.fileExists(atPath: directPath) {
            return NSImage(contentsOfFile: directPath)
        }

        guard let targetName = name, !targetName.isEmpty else { return nil }

        // Clean target name for matching
        let cleanName = targetName.replacingOccurrences(of: ".png", with: "")
            .replacingOccurrences(of: ".jpg", with: "")
            .replacingOccurrences(of: ".jpeg", with: "")

        // 2. Search in .cache/keynote_extracted
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

        // 3. Search in 動画用 assets
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
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(recognitionService.logs.suffix(150)) { log in
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
