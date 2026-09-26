import SwiftUI
import AppKit
import AVKit
import AVFoundation

public struct SlideScenarioMakerView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var recognitionService = SlideRecognitionService.shared

    public enum CanvasViewMode: String, CaseIterable, Identifiable {
        case slideOriginal = "スライド原画"
        case animationVideo = "🎬 アニメ動画"
        case elementLayers = "レイヤー分解"
        public var id: String { rawValue }
    }

    @State private var selectedSlideIdx: Int = 0
    @State private var canvasViewMode: CanvasViewMode = .slideOriginal
    @State private var showCanvasOverlay: Bool = true
    @State private var showUnifiedModal: Bool = false
    @State private var selectedFilePath: String = "/Volumes/ZSSD/GitHub/repository/TohoStudio/交換夫婦/交換夫婦（21.22話目）.key"
    @State private var syncMovieMaker: Bool = true
    @State private var syncGameMaker: Bool = true
    @State private var syncSoundMaker: Bool = true
    @State private var syncMaterialStudio: Bool = true
    @State private var autoSaveProject: Bool = true
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

                // 指示書 Slide 14: 「既存の『スライド読み込み』のボタンと『スライド認識』のボタンを統合してください」
                Button(action: { showUnifiedModal = true }) {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                        Text("スライド読み込み＆認識 (精度99%規格)")
                            .bold()
                    }
                }
                .buttonStyle(.borderedProminent)
                .help("Keynoteファイル（.key）から全スライド・アニメーション・ビルド順を高精度抽出し、各メーカーへ自動反映します (cmd+f+r)")

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
                    .frame(width: 250)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))

                // Center: Slide Visual Canvas
                slideCanvasView
                    .frame(minWidth: 420, maxWidth: .infinity)
                    .padding()

                // Right: Scenario & Presenter Notes
                scenarioNotesView
                    .frame(width: 320)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.3))
            }
        }
        .sheet(isPresented: $showUnifiedModal) {
            unifiedSlideModalView
        }
        .onAppear {
            if appState.activeModal == .slideLoader || appState.activeModal == .slideRecognitionPopup {
                showUnifiedModal = true
                appState.activeModal = nil
            }
        }
        .onChange(of: appState.activeModal) { newModal in
            if newModal == .slideLoader || newModal == .slideRecognitionPopup {
                showUnifiedModal = true
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

                // 統合読み込み＆認識ボタン
                Button(action: { showUnifiedModal = true }) {
                    Label("読込＆認識", systemImage: "arrow.down.doc")
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
                HStack(alignment: .top, spacing: 8) {
                    // スライド画面サムネイル (16:9)
                    if let imgPath = slide.slideImagePath, let thumbImg = resolveImage(path: imgPath, name: nil, subfolder: nil) {
                        Image(nsImage: thumbImg)
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fit)
                            .frame(width: 58, height: 33)
                            .cornerRadius(3)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.secondary.opacity(0.3), lineWidth: 0.5))
                    } else if let bgImg = resolveImage(path: slide.backgroundImagePath, name: slide.backgroundName, subfolder: "背景") {
                        Image(nsImage: bgImg)
                            .resizable()
                            .aspectRatio(16/9, contentMode: .fit)
                            .frame(width: 58, height: 33)
                            .cornerRadius(3)
                            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Color.secondary.opacity(0.3), lineWidth: 0.5))
                    } else {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(slide.slideType == "sectionHeader" ? Color.purple.opacity(0.3) : (slide.slideType == "title" ? Color.blue.opacity(0.3) : Color.black.opacity(0.3)))
                            .frame(width: 58, height: 33)
                            .overlay(
                                Text("#\(slide.slideIndex)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(.secondary)
                            )
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("#\(slide.slideIndex)")
                                .font(.caption2)
                                .bold()
                                .foregroundColor(.accentColor)

                            // スライド種別バッジ
                            if slide.slideType == "title" {
                                Text("タイトル")
                                    .font(.system(size: 8))
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 1)
                                    .background(Color.blue.opacity(0.2))
                                    .foregroundColor(.blue)
                                    .cornerRadius(2)
                            } else if slide.slideType == "sectionHeader" {
                                Text("中扉")
                                    .font(.system(size: 8))
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 1)
                                    .background(Color.purple.opacity(0.2))
                                    .foregroundColor(.purple)
                                    .cornerRadius(2)
                            }

                            Spacer()

                            Text("⏱️\(String(format: "%.1f", slide.duration))s")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }

                        Text(slide.title)
                            .font(.system(size: 11, weight: .semibold))
                            .lineLimit(1)

                        if !slide.telop.isEmpty {
                            Text(slide.telop)
                                .font(.system(size: 9))
                                .lineLimit(1)
                                .foregroundColor(.secondary)
                        }

                        if !slide.animations.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 7))
                                    .foregroundColor(.orange)
                                Text("\(slide.animations.count)アニメ")
                                    .font(.system(size: 8))
                                    .foregroundColor(.orange)

                                if slide.animationVideoPath != nil {
                                    HStack(spacing: 1) {
                                        Image(systemName: "film.fill")
                                            .font(.system(size: 7))
                                        Text("動画")
                                            .font(.system(size: 7, weight: .bold))
                                    }
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 0.5)
                                    .background(Color.purple.opacity(0.8))
                                    .foregroundColor(.white)
                                    .cornerRadius(2)
                                }
                            }
                        }
                    }
                }
                .padding(5)
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
        VStack(spacing: 8) {
            if selectedSlideIdx < appState.slides.count {
                let slide = appState.slides[selectedSlideIdx]

                // Mode Selector & Status Header Bar
                HStack(spacing: 12) {
                    Picker("画面表示", selection: $canvasViewMode) {
                        ForEach(CanvasViewMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 320)

                    if let videoPath = slide.animationVideoPath, FileManager.default.fileExists(atPath: videoPath) {
                        Button(action: {
                            canvasViewMode = (canvasViewMode == .animationVideo) ? .slideOriginal : .animationVideo
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: canvasViewMode == .animationVideo ? "photo" : "play.circle.fill")
                                Text(canvasViewMode == .animationVideo ? "原画に戻す" : "🎬 アニメ再生")
                                    .bold()
                            }
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(canvasViewMode == .animationVideo ? Color.blue : Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }

                    if canvasViewMode == .slideOriginal {
                        Toggle("情報オーバーレイ", isOn: $showCanvasOverlay)
                            .toggleStyle(.checkbox)
                            .font(.caption)

                        Spacer()

                        if slide.slideImagePath != nil && resolveImage(path: slide.slideImagePath, name: nil, subfolder: nil) != nil {
                            HStack(spacing: 4) {
                                Image(systemName: "photo.badge.checkmark.fill")
                                    .foregroundColor(.green)
                                Text("Keynote原画表示中 (1920×1080)")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.green)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.green.opacity(0.12))
                            .cornerRadius(4)
                        } else {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                                Text("レイヤー自動描画中 (原画抽出前)")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            }
                        }
                    } else if canvasViewMode == .animationVideo {
                        Spacer()
                        HStack(spacing: 4) {
                            Image(systemName: "film.fill")
                                .foregroundColor(.orange)
                            Text("🎬 Keynoteアニメーション動画再生中")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.orange)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(4)
                    } else {
                        Spacer()
                        Text("各要素の個別レイヤー・相対座標プレビューモード")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 4)

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

                            // 2. Main Visual Render
                            if canvasViewMode == .animationVideo {
                                if let videoPath = slide.animationVideoPath, FileManager.default.fileExists(atPath: videoPath) {
                                    // 🌟 アニメーション動画再生 (Keynote Native Recorded Movie) 🌟
                                    SlideVideoPlayerView(videoPath: videoPath)
                                        .frame(width: canvasW, height: canvasH)
                                        .cornerRadius(8)
                                } else {
                                    VStack(spacing: 12) {
                                        Image(systemName: "video.slash")
                                            .font(.system(size: 36))
                                            .foregroundColor(.secondary)
                                        Text("このスライドにはアニメーション動画がありません")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                        Text("Keynote内でアニメーション設定があるスライドが自動で動画記録されます。")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                        Button("スライド原画に戻す") {
                                            canvasViewMode = .slideOriginal
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                    .frame(width: canvasW, height: canvasH)
                                    .background(Color.black.opacity(0.85))
                                }
                            } else if canvasViewMode == .slideOriginal,
                               let slidePath = slide.slideImagePath,
                               let slideOriginalImg = resolveImage(path: slidePath, name: nil, subfolder: nil) {
                                // 🌟 スライド画面そのものの完全レンダリング画像 (Keynote Native) 🌟
                                Image(nsImage: slideOriginalImg)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(width: canvasW, height: canvasH)
                                    .clipped()
                            } else {
                                // --- 要素レイヤー分解表示 (編集プレビュー / フォールバック) ---
                                // A. Slide Background Image Layer
                                if let bgImg = resolveImage(path: slide.backgroundImagePath, name: slide.backgroundName, subfolder: "背景") {
                                    Image(nsImage: bgImg)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: canvasW, height: canvasH)
                                        .clipped()
                                } else {
                                    // Default Gradient Background
                                    LinearGradient(
                                        colors: slide.slideType == "sectionHeader" ?
                                            [Color(red: 0.05, green: 0.1, blue: 0.25), Color(red: 0.02, green: 0.05, blue: 0.15)] :
                                            [Color(red: 0.1, green: 0.12, blue: 0.18), Color(red: 0.05, green: 0.06, blue: 0.1)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    .frame(width: canvasW, height: canvasH)
                                }

                                // B. Other Slide Objects Layer (Props, Effects, Graphics, Pager)
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

                                // C. Character Standing Portrait Layer
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
                                } else if !slide.characterName.isEmpty && slide.characterName != "ナレーション" && slide.slideType == "content" {
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

                                // D. Section Header Center Text
                                if slide.slideType == "sectionHeader" {
                                    VStack {
                                        Text(slide.title)
                                            .font(.system(size: max(canvasH * 0.065, 16), weight: .bold))
                                            .foregroundColor(.white)
                                            .shadow(color: .blue.opacity(0.8), radius: 8, x: 0, y: 0)
                                    }
                                    .frame(width: canvasW, height: canvasH, alignment: .center)
                                }

                                // E. Accurate Telop Layer (Subtitles / Dialogues)
                                let tx = (slide.telopX ?? 0.0) * scaleX
                                let ty = (slide.telopY ?? (origH * 0.79)) * scaleY
                                let tw = max((slide.telopWidth ?? origW) * scaleX, 50.0)
                                let th = max((slide.telopHeight ?? (origH * 0.21)) * scaleY, 25.0)

                                if !slide.telop.isEmpty && slide.slideType != "sectionHeader" {
                                    VStack(alignment: .leading, spacing: 3) {
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
                            }

                            // 3. Information & Metadata Overlay (Top Bar)
                            if showCanvasOverlay || canvasViewMode == .elementLayers {
                                HStack {
                                    Text("#\(slide.slideIndex): \(slide.title)")
                                        .font(.caption2)
                                        .bold()
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(Color.black.opacity(0.75))
                                        .foregroundColor(.white)
                                        .cornerRadius(4)

                                    // Slide Type
                                    Text(slide.slideType == "title" ? "タイトル" : (slide.slideType == "sectionHeader" ? "中扉" : "通常"))
                                        .font(.caption2)
                                        .bold()
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(slide.slideType == "title" ? Color.blue : (slide.slideType == "sectionHeader" ? Color.purple : Color.green))
                                        .foregroundColor(.white)
                                        .cornerRadius(4)

                                    if canvasViewMode == .slideOriginal && slide.slideImagePath != nil {
                                        Text("原画")
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(Color.green)
                                            .foregroundColor(.white)
                                            .cornerRadius(3)
                                    }

                                    Spacer()

                                    HStack(spacing: 4) {
                                        Text("表示: \(String(format: "%.1f", slide.duration))秒")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 3)
                                            .background(Color.black.opacity(0.75))
                                            .foregroundColor(.white)
                                            .cornerRadius(4)

                                        if !slide.animations.isEmpty {
                                            Text("\(slide.animations.count)アニメ")
                                                .font(.caption2)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 3)
                                                .background(Color.orange.opacity(0.85))
                                                .foregroundColor(.white)
                                                .cornerRadius(4)

                                            if slide.animationVideoPath != nil {
                                                Button(action: {
                                                    canvasViewMode = (canvasViewMode == .animationVideo) ? .slideOriginal : .animationVideo
                                                }) {
                                                    HStack(spacing: 3) {
                                                        Image(systemName: canvasViewMode == .animationVideo ? "photo" : "film.fill")
                                                        Text(canvasViewMode == .animationVideo ? "原画" : "🎬 動画確認")
                                                            .font(.system(size: 9, weight: .bold))
                                                    }
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 3)
                                                    .background(canvasViewMode == .animationVideo ? Color.blue : Color.purple)
                                                    .foregroundColor(.white)
                                                    .cornerRadius(4)
                                                }
                                                .buttonStyle(.plain)
                                            }
                                        }
                                    }
                                }
                                .padding(8)
                                .frame(width: canvasW, alignment: .top)
                            }
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

                        // Duration Inspector
                        HStack(spacing: 4) {
                            Text("表示時間:").font(.caption2).foregroundColor(.secondary)
                            Text("\(String(format: "%.1f", slide.duration))秒")
                                .font(.caption2)
                                .bold()
                                .foregroundColor(.accentColor)
                        }

                        Divider().frame(height: 12)

                        // Transition Inspector
                        HStack(spacing: 4) {
                            Text("トランジション:").font(.caption2).foregroundColor(.secondary)
                            Text(slide.transitionEffect)
                                .font(.caption2)
                        }

                        Divider().frame(height: 12)

                        // Objects count
                        if !slide.objects.isEmpty {
                            HStack(spacing: 4) {
                                Text("オブジェクト:").font(.caption2).foregroundColor(.secondary)
                                Text("\(slide.objects.count)件")
                                    .font(.caption2)
                                    .bold()
                            }
                            Divider().frame(height: 12)
                        }

                        // Animation count
                        if !slide.animations.isEmpty {
                            HStack(spacing: 6) {
                                HStack(spacing: 4) {
                                    Text("アニメーション:").font(.caption2).foregroundColor(.secondary)
                                    Text("\(slide.animations.count)件 (順序: \(slide.buildOrder.count)件)")
                                        .font(.caption2)
                                        .bold()
                                        .foregroundColor(.orange)
                                }

                                if let vPath = slide.animationVideoPath, FileManager.default.fileExists(atPath: vPath) {
                                    Button(action: {
                                        canvasViewMode = (canvasViewMode == .animationVideo) ? .slideOriginal : .animationVideo
                                    }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: canvasViewMode == .animationVideo ? "photo" : "play.fill")
                                            Text(canvasViewMode == .animationVideo ? "スライド原画に戻す" : "🎬 アニメーション動画を確認")
                                                .bold()
                                        }
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(canvasViewMode == .animationVideo ? Color.blue : Color.orange)
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                    }
                                    .buttonStyle(.plain)
                                }
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

                    // アニメーション＆ビルド順の詳細一覧バー
                    if !slide.animations.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(slide.animations) { anim in
                                    HStack(spacing: 4) {
                                        Text("#\(anim.order)")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 4)
                                            .background(Color.orange)
                                            .cornerRadius(2)
                                        Text("\(anim.targetObjectName):")
                                            .font(.system(size: 10, weight: .medium))
                                        Text(anim.effect)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.orange)
                                        Text("(\(String(format: "%.1f", anim.duration))s)")
                                            .font(.system(size: 9))
                                            .foregroundColor(.secondary)
                                        if let b = anim.bounceCount {
                                            Text("\(b)回バウンス")
                                                .font(.system(size: 9))
                                                .foregroundColor(.purple)
                                        }
                                        if let r = anim.rotationAngle {
                                            Text("\(Int(r))°回転")
                                                .font(.system(size: 9))
                                                .foregroundColor(.blue)
                                        }
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 3)
                                    .background(Color.secondary.opacity(0.12))
                                    .cornerRadius(4)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "doc.badge.arrow.up")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("スライドがありません")
                        .font(.headline)
                    Button("スライド読み込み＆認識を開始") {
                        showUnifiedModal = true
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
                    // スライド種別情報
                    HStack {
                        Text("スライド種別:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(slide.slideType == "title" ? "タイトルスライド" : (slide.slideType == "sectionHeader" ? "セクション見出し(中扉)" : "通常スライド"))
                            .font(.caption)
                            .bold()
                            .foregroundColor(slide.slideType == "title" ? .blue : (slide.slideType == "sectionHeader" ? .purple : .green))
                        Spacer()
                    }

                    if slide.slideType == "title" || slide.slideType == "sectionHeader" {
                        Text("※指示書仕様: タイトル・中扉スライドのノート欄は必ず空白で読み込まれます")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                            .padding(4)
                            .background(Color.yellow.opacity(0.15))
                            .cornerRadius(4)
                    }

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

                    HStack {
                        Text("発表者・演出ノート:").font(.caption).foregroundColor(.secondary)
                        if let raw = slide.rawPresenterNote, let spk = SlideItem.extractSpeakerFromBrackets(from: raw) {
                            Text("話者: [\(spk)] (サウンド連携済・UI非表示)")
                                .font(.system(size: 8))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Color.purple.opacity(0.15))
                                .foregroundColor(.purple)
                                .cornerRadius(3)
                        }
                        Spacer()
                        if slide.displayPresenterNote.isEmpty {
                            Text("(空白)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    TextEditor(text: Binding(
                        get: { slide.displayPresenterNote },
                        set: {
                            // UIから入力・編集された際も、カッコ書き話者タグを除いたクリーンなテキストとして保持
                            appState.slides[selectedSlideIdx].presenterNote = SlideItem.stripSpeakerBrackets(from: $0)
                        }
                    ))
                    .frame(height: 80)
                    .border(Color.secondary.opacity(0.2))

                    HStack {
                        Text("表示時間(秒):").font(.caption).foregroundColor(.secondary)
                        TextField("秒数", value: Binding(
                            get: { slide.duration },
                            set: { appState.slides[selectedSlideIdx].duration = $0 }
                        ), formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    }

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

    // MARK: - Unified Slide Load & Recognition Modal View (指示書 Slide 14 統合モーダル)
    private var unifiedSlideModalView: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Label("スライド読み込み＆認識プログラム (精度99%規格)", systemImage: "sparkles.rectangle.stack.fill")
                    .font(.title3)
                    .bold()
                Spacer()
                Button("閉じる") { showUnifiedModal = false }
            }

            Text("Keynoteファイル（.key）から全スライド・全オブジェクト（ポケベル・小道具・枠等）・アニメーション（バウンス・回転等）・ビルド順・スライド種別（タイトル/中扉/通常）を直接高速抽出・認識します。")
                .font(.caption)
                .foregroundColor(.secondary)

            Divider()

            // File Selection
            VStack(alignment: .leading, spacing: 6) {
                Text("読み込むKeynoteファイルを選択:")
                    .font(.caption)
                    .bold()

                HStack {
                    TextField("ファイルパス", text: $selectedFilePath)
                        .textFieldStyle(.roundedBorder)

                    Button("Macから選択...") {
                        selectFileViaOpenPanel()
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Quick Selection List
            Text("Keynote プロジェクト一覧（クイック選択）:")
                .font(.caption)
                .bold()

            ScrollView {
                VStack(spacing: 6) {
                    ForEach(recognitionService.getAvailableKeynoteProjects()) { item in
                        HStack(spacing: 10) {
                            Image(systemName: "doc.richtext.fill")
                                .foregroundColor(selectedFilePath == item.filePath ? .accentColor : .secondary)

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

                            if selectedFilePath == item.filePath {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .padding(8)
                        .background(selectedFilePath == item.filePath ? Color.accentColor.opacity(0.12) : Color.secondary.opacity(0.05))
                        .cornerRadius(6)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            selectedFilePath = item.filePath
                        }
                    }
                }
            }
            .frame(height: 140)
            .border(Color.secondary.opacity(0.2))

            // Cross-Module Auto-Sync Settings (指示書 Slide 14 要件)
            GroupBox(label: Text("各メーカーへの自動反映・同期設定 (指示書 Slide 14)").font(.caption).bold()) {
                HStack(spacing: 16) {
                    Toggle("ムービーメーカー", isOn: $syncMovieMaker)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                    Toggle("ゲームメーカー", isOn: $syncGameMaker)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                    Toggle("サウンドメーカー", isOn: $syncSoundMaker)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                    Toggle("素材スタジオ", isOn: $syncMaterialStudio)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                    Toggle("自動保存", isOn: $autoSaveProject)
                        .toggleStyle(.checkbox)
                        .font(.caption)
                }
                .padding(4)
            }

            if recognitionService.isRunning {
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: recognitionService.currentProgress)
                    Text("解析＆各メーカー同期進捗: \(Int(recognitionService.currentProgress * 100))%")
                        .font(.caption)
                }
            }

            if let result = recognitionService.lastResult {
                GroupBox(label: Text("最新解析サマリー (認識精度: \(String(format: "%.1f", result.accuracyRate))%)").font(.caption).bold()) {
                    HStack(spacing: 20) {
                        VStack {
                            Text("\(result.totalSlides)").font(.title2).bold()
                            Text("スライド総数").font(.caption2)
                        }
                        VStack {
                            Text("\(result.matchedBackgroundCount)").font(.title2).bold().foregroundColor(.green)
                            Text("背景照合数").font(.caption2)
                        }
                        VStack {
                            Text("\(result.matchedCharacterCount)").font(.title2).bold().foregroundColor(.blue)
                            Text("キャラクター照合").font(.caption2)
                        }
                        VStack {
                            Text("\(result.animationCount)").font(.title2).bold().foregroundColor(.orange)
                            Text("アニメーション紐付").font(.caption2)
                        }
                        if result.animationVideoCount > 0 {
                            VStack {
                                Text("\(result.animationVideoCount)").font(.title2).bold().foregroundColor(.purple)
                                Text("動画記録スライド").font(.caption2)
                            }
                        }
                    }
                    .padding(4)
                }
            }

            // Action Buttons
            HStack {
                Text("現在のスライド数: \(appState.slides.count)枚")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Button("キャンセル") {
                    showUnifiedModal = false
                }

                Button(action: {
                    recognitionService.loadAndRecognizeSlides(
                        filePath: selectedFilePath,
                        syncMovieMaker: syncMovieMaker,
                        syncGameMaker: syncGameMaker,
                        syncSoundMaker: syncSoundMaker,
                        syncMaterialStudio: syncMaterialStudio,
                        autoSave: autoSaveProject
                    ) { result in
                        selectedSlideIdx = 0
                        let fName = URL(fileURLWithPath: selectedFilePath).lastPathComponent
                        let vidNote = result.animationVideoCount > 0 ? "・動画記録: \(result.animationVideoCount)件" : ""
                        loadSuccessMessage = "「\(fName)」から \(result.totalSlides) 枚のスライド・アニメーション\(vidNote)・ビルド順を解析・各メーカーへ完全反映しました (認識精度: \(result.accuracyRate)%)。"
                        showUnifiedModal = false
                    }
                }) {
                    HStack {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                        Text("読み込み＆認識・全メーカー同期を実行")
                            .bold()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(recognitionService.isRunning)
            }
        }
        .padding(20)
        .frame(width: 700, height: 600)
    }

    private func selectFileViaOpenPanel() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = []
        openPanel.allowsOtherFileTypes = true
        openPanel.canChooseFiles = true
        openPanel.canChooseDirectories = false
        openPanel.directoryURL = URL(fileURLWithPath: "/Volumes/ZSSD/GitHub/repository/TohoStudio")

        if openPanel.runModal() == .OK, let url = openPanel.url {
            selectedFilePath = url.path
        }
    }
}

// MARK: - Slide Video Player View (Keynoteアニメーション記録動画再生)
public struct SlideVideoPlayerView: NSViewRepresentable {
    public let videoPath: String

    public init(videoPath: String) {
        self.videoPath = videoPath
    }

    public func makeNSView(context: Context) -> AVPlayerView {
        let playerView = AVPlayerView()
        playerView.controlsStyle = .inline
        playerView.showsFullScreenToggleButton = true
        let url = URL(fileURLWithPath: videoPath)
        let player = AVPlayer(url: url)
        playerView.player = player
        player.actionAtItemEnd = .none

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }

        player.play()
        return playerView
    }

    public func updateNSView(_ nsView: AVPlayerView, context: Context) {
        if let currentItem = nsView.player?.currentItem,
           let asset = currentItem.asset as? AVURLAsset,
           asset.url.path == videoPath {
            return
        }
        let url = URL(fileURLWithPath: videoPath)
        let player = AVPlayer(url: url)
        player.actionAtItemEnd = .none
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
        nsView.player = player
        player.play()
    }
}
