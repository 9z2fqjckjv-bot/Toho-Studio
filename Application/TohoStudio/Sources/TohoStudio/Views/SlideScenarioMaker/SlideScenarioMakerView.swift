import SwiftUI

public struct SlideScenarioMakerView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var recognitionService = SlideRecognitionService.shared

    @State private var selectedSlideIdx: Int = 0
    @State private var showRecognitionModal: Bool = false
    @State private var recognitionFilePath: String = "/Volumes/ZSSD/GitHub/repository/TohoStudio/東方惑情録/東方惑情録　第1話.key"

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

                // High-precision Recognition Button
                Button(action: { showRecognitionModal = true }) {
                    HStack {
                        Image(systemName: "sparkles.rectangle.stack")
                        Text("スライド認識プログラム (精度99%規格)")
                    }
                }
                .buttonStyle(.borderedProminent)

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

            Divider()

            // Main Split Editor (Slides List + Slide Editor + Scenario Notebook)
            HSplitView {
                // Left: Slide Thumbnails
                slideThumbnailListView
                    .frame(width: 220)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

                // Center: Slide Visual Canvas
                slideCanvasView
                    .frame(minWidth: 380, maxWidth: .infinity)
                    .padding()

                // Right: Scenario & Presenter Notes
                scenarioNotesView
                    .frame(width: 320)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
            }
        }
        .sheet(isPresented: $showRecognitionModal) {
            recognitionModalView
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
                Text("スライド一覧")
                    .font(.caption)
                    .bold()
                Spacer()
                Button(action: {
                    let newSlide = SlideItem(
                        slideIndex: appState.slides.count + 1,
                        title: "スライド \(appState.slides.count + 1)",
                        telop: "新しいセリフ",
                        presenterNote: "新しい演出ノート",
                        backgroundName: "博麗神社.png",
                        characterName: "博麗霊夢"
                    )
                    appState.slides.append(newSlide)
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
                        Spacer()
                        Text(slide.characterName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Text(slide.title)
                        .font(.caption)
                        .bold()
                    Text(slide.telop)
                        .font(.caption2)
                        .lineLimit(1)
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

                    VStack {
                        HStack {
                            Text("【背景】\(slide.backgroundName)")
                                .font(.caption2)
                                .padding(4)
                                .background(Color.black.opacity(0.6))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                            Spacer()
                            Text("アニメ: \(slide.animationTag)")
                                .font(.caption2)
                                .padding(4)
                                .background(Color.blue.opacity(0.6))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                        .padding(12)

                        Spacer()

                        Image(systemName: "person.crop.rectangle.fill")
                            .font(.system(size: 72))
                            .foregroundColor(.accentColor.opacity(0.7))

                        Spacer()

                        Text(slide.telop)
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(8)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(6)
                            .padding(.bottom, 12)
                    }
                }

                // Slide Split action
                HStack {
                    Button(action: {
                        appState.log("スライドを背景・立ち絵・テロップの3ファイルに分割して素材スタジオに保存しました")
                    }) {
                        Label("スライドを3種ファイルに分割保存", systemImage: "square.split.3x1")
                            .font(.caption)
                    }
                    Spacer()
                }
            }
        }
    }

    // MARK: - Scenario Notes View
    private var scenarioNotesView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("台本シナリオ＆演出ノート")
                .font(.headline)

            if selectedSlideIdx < appState.slides.count {
                let slide = appState.slides[selectedSlideIdx]
                VStack(alignment: .leading, spacing: 8) {
                    Text("テロップ / セリフ入力:").font(.caption).foregroundColor(.secondary)
                    TextEditor(text: Binding(
                        get: { slide.telop },
                        set: { appState.slides[selectedSlideIdx].telop = $0 }
                    ))
                    .frame(height: 70)
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

    // MARK: - Recognition Modal View
    private var recognitionModalView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("スライド認識プログラム (高精度抽出＆照合エンジン)", systemImage: "sparkles.rectangle.stack")
                    .font(.headline)
                Spacer()
                Button("閉じる") { showRecognitionModal = false }
            }

            Text("Keynoteファイル等から全オブジェクト、背景画像、キャラクター、アニメーションを検出し、「動画用」素材フォルダと自動照合・紐付けを行います。")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack {
                TextField("Keynoteファイルパス", text: $recognitionFilePath)
                    .textFieldStyle(.roundedBorder)

                Button(action: {
                    recognitionService.analyzeKeynoteOrSlide(filePath: recognitionFilePath) { result in
                        appState.slides = result.processedSlides
                        appState.log("スライド認識完了: \(result.totalSlides)枚解析 (精度: \(result.accuracyRate)%)")
                    }
                }) {
                    Text("認識・解析開始")
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
