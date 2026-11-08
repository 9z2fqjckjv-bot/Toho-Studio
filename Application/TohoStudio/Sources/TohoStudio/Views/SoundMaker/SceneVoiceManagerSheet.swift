import SwiftUI
import AppKit
import AVFoundation

/// 1つのシーン（スライド）ごとの音声をポップアップウインドウで集中管理・編集・生成するシート
/// - 以前のPython版ムービーメーカー（キーノート台本からのスライド単位音声生成・プレビュー・微調整）のワークフローを継承
public struct SceneVoiceManagerSheet: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var aquesTalk = AquesTalkBridge.shared
    @ObservedObject var soundManager = SoundMakerAudioManager.shared

    @Environment(\.presentationMode) var presentationMode

    // 現在編集中のシーンインデックス (1-based)
    @State public var sceneIndex: Int

    // プレビュー再生状態
    @State private var isPlayingVoice: Bool = false
    @State private var previewPlayer: AVAudioPlayer? = nil
    @State private var isGenerating: Bool = false
    @State private var errorMessage: String? = nil
    @State private var successToast: String? = nil

    // 音声追加用モーダルステート
    @State private var showAddVoiceDialog: Bool = false
    @State private var newVoiceCharacter: String = "操夢"
    @State private var newVoiceText: String = ""

    public init(initialSceneIndex: Int = 1) {
        _sceneIndex = State(initialValue: max(1, initialSceneIndex))
    }

    private var scenes: [MovieScene] {
        if !appState.movieScenes.isEmpty {
            return appState.movieScenes
        } else if !appState.slides.isEmpty {
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
        return [MovieScene(title: "シーン 1", duration: 3.0, slideTitle: "シーン 1", backgroundName: "", characterName: "操夢", telop: "")]
    }

    private var currentScene: MovieScene? {
        guard sceneIndex >= 1 && sceneIndex <= scenes.count else { return nil }
        return scenes[sceneIndex - 1]
    }

    private var currentSlide: SlideItem? {
        appState.slides.first(where: { $0.slideIndex == sceneIndex })
    }

    private var currentVoiceClips: [SoundClip] {
        appState.soundClips.filter { $0.type == "Voice" && $0.sceneIndex == sceneIndex }
    }

    private var currentBgmClips: [SoundClip] {
        appState.soundClips.filter { $0.type == "BGM" && $0.sceneIndex == sceneIndex }
    }

    private var currentSeClips: [SoundClip] {
        appState.soundClips.filter { $0.type == "SE" && $0.sceneIndex == sceneIndex }
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerView

            Divider().background(Color(red: 0.24, green: 0.25, blue: 0.28))

            HStack(spacing: 0) {
                // 左側: スライド画像・アニメーション情報 & 台本プレビュー
                leftPreviewSidebar
                    .frame(width: 320)
                    .background(Color(red: 0.13, green: 0.14, blue: 0.16))

                Divider().background(Color(red: 0.24, green: 0.25, blue: 0.28))

                // 右側: シーン音声クリップ一覧 & AquesTalkボイス詳細編集・再生成
                rightVoiceEditorArea
                    .background(Color(red: 0.15, green: 0.16, blue: 0.18))
            }

            Divider().background(Color(red: 0.24, green: 0.25, blue: 0.28))

            footerView
        }
        .frame(width: 980, height: 680)
        .background(Color(red: 0.14, green: 0.15, blue: 0.17))
        .sheet(isPresented: $showAddVoiceDialog) {
            addVoiceClipModal
        }
        .onAppear {
            let maxCount = max(1, scenes.count)
            if sceneIndex > maxCount {
                sceneIndex = maxCount
            }
        }
        .onDisappear {
            stopPreview()
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform.badge.mic")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.cyan)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("シーン \(sceneIndex) 音声管理ポップアップ")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)

                    Text("（全 \(scenes.count) シーン中）")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Text("1つのシーンごとにセリフ、話者、音程、速度、効果音を独立して視聴・再生成・微調整")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // シーン切り替えナビゲーション (前へ / 次へ)
            HStack(spacing: 6) {
                Button(action: {
                    if sceneIndex > 1 {
                        stopPreview()
                        sceneIndex -= 1
                        appState.soundMakerSelectedSceneIndex = sceneIndex
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                        Text("前のシーン")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(sceneIndex > 1 ? Color.white.opacity(0.1) : Color.white.opacity(0.04))
                    .foregroundColor(sceneIndex > 1 ? .white : .secondary)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .disabled(sceneIndex <= 1)

                Text("S\(sceneIndex)")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundColor(.cyan)
                    .frame(minWidth: 36)

                Button(action: {
                    if sceneIndex < scenes.count {
                        stopPreview()
                        sceneIndex += 1
                        appState.soundMakerSelectedSceneIndex = sceneIndex
                    }
                }) {
                    HStack(spacing: 4) {
                        Text("次のシーン")
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(sceneIndex < scenes.count ? Color.white.opacity(0.1) : Color.white.opacity(0.04))
                    .foregroundColor(sceneIndex < scenes.count ? .white : .secondary)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .disabled(sceneIndex >= scenes.count)
            }

            Divider().frame(height: 20)

            Button(action: {
                stopPreview()
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .help("閉じる (Esc)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 0.16, green: 0.17, blue: 0.20))
    }

    // MARK: - Left Preview Sidebar
    private var leftPreviewSidebar: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                // スライド画像プレビュー
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Label("スライド原画", systemImage: "photo.artframe")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        if let dur = currentScene?.duration {
                            Text(String(format: "表示時間: %.2f秒", dur))
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                    }

                    ZStack {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.black.opacity(0.4))
                            .aspectRatio(16/9, contentMode: .fit)

                        if let path = currentSceneImagePath(), let img = NSImage(contentsOfFile: path) {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .cornerRadius(4)
                        } else {
                            VStack(spacing: 6) {
                                Image(systemName: "photo")
                                    .font(.system(size: 28))
                                    .foregroundColor(.secondary)
                                Text("スライド画像未抽出")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color(red: 0.24, green: 0.25, blue: 0.28), lineWidth: 1)
                    )
                }

                // アニメーション / タイミング注記
                if let animNote = currentScene?.animationNote {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Keynoteアニメーション演出", systemImage: "sparkles.tv")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.yellow)
                        Text(animNote)
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.yellow.opacity(0.12))
                            .cornerRadius(4)
                    }
                }

                // スライド台本・テロップ原文
                VStack(alignment: .leading, spacing: 6) {
                    Label("スライド台本 / 発表者ノート", systemImage: "text.alignleft")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)

                    let rawText: String = {
                        if let note = currentSlide?.presenterNote, !note.isEmpty { return note }
                        if let tel = currentSlide?.telop, !tel.isEmpty { return tel }
                        if let scTel = currentScene?.telop, !scTel.isEmpty { return scTel }
                        return ""
                    }()

                    Text(rawText.isEmpty ? "(台本テキストが設定されていません)" : rawText)
                        .font(.system(size: 11))
                        .foregroundColor(rawText.isEmpty ? .secondary : .white.opacity(0.85))
                        .lineSpacing(4)
                        .padding(8)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .background(Color(red: 0.10, green: 0.11, blue: 0.13))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(red: 0.24, green: 0.25, blue: 0.28), lineWidth: 1)
                        )
                }

                // このシーンの音声総尺まとめ
                VStack(alignment: .leading, spacing: 6) {
                    Label("音声ステータス", systemImage: "waveform.path.ecg")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)

                    let vDur = currentVoiceClips.reduce(0.0) { $0 + $1.duration }
                    let sDur = currentScene?.duration ?? 3.0

                    VStack(spacing: 4) {
                        HStack {
                            Text("ボイス総尺:")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.2f 秒", vDur))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.cyan)
                        }
                        HStack {
                            Text("シーン設定尺:")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(String(format: "%.2f 秒", sDur))
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.white)
                        }
                        if vDur > sDur {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(.yellow)
                                Text("音声がシーン尺を超過しています (自動拡張可)")
                                    .font(.system(size: 9))
                                    .foregroundColor(.yellow)
                            }
                            .padding(.top, 2)
                        }
                    }
                    .padding(8)
                    .background(Color(red: 0.10, green: 0.11, blue: 0.13))
                    .cornerRadius(6)
                }
            }
            .padding(14)
        }
    }

    // MARK: - Right Voice Editor Area
    private var rightVoiceEditorArea: some View {
        VStack(spacing: 0) {
            // Action Bar
            HStack(spacing: 8) {
                Label("ボイス一覧 (\(currentVoiceClips.count)件)", systemImage: "person.wave.2.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                // スライド台本からこのシーンの音声をワンクリック再生成
                Button(action: {
                    regenerateVoiceFromSlideForThisScene()
                }) {
                    HStack(spacing: 4) {
                        if isGenerating {
                            ProgressView()
                                .scaleEffect(0.6)
                                .frame(width: 12, height: 12)
                        } else {
                            Image(systemName: "sparkles")
                        }
                        Text("台本から音声再生成")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.cyan.opacity(0.2))
                    .foregroundColor(.cyan)
                    .cornerRadius(5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.cyan.opacity(0.6), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isGenerating)

                // 新規音声追加
                Button(action: {
                    newVoiceCharacter = currentScene?.characterName ?? "操夢"
                    newVoiceText = ""
                    showAddVoiceDialog = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "plus.circle.fill")
                        Text("音声を追加")
                    }
                    .font(.system(size: 11, weight: .bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.white.opacity(0.1))
                    .foregroundColor(.white)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(red: 0.17, green: 0.18, blue: 0.20))

            // Toast / Error Message
            if let toast = successToast {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(toast)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.white)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.2))
            }
            if let err = errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                    Text(err)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.yellow)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(Color.red.opacity(0.2))
            }

            // Clilps List
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 12) {
                    if currentVoiceClips.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "waveform.slash")
                                .font(.system(size: 36))
                                .foregroundColor(.secondary)
                            Text("シーン \(sceneIndex) には音声クリップがありません")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.secondary)
                            Text("上の「台本から音声再生成」を押すと、スライドの台本・セリフから自動でAquesTalk音声を生成します。")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 380)

                            Button(action: {
                                regenerateVoiceFromSlideForThisScene()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "sparkles")
                                    Text("台本からAquesTalk音声を生成")
                                }
                                .font(.system(size: 11, weight: .bold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(Color.cyan)
                                .foregroundColor(.black)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 60)
                    } else {
                        ForEach(Array(currentVoiceClips.enumerated()), id: \.element.id) { index, clip in
                            voiceClipDetailCard(clip: clip, index: index, totalCount: currentVoiceClips.count)
                        }
                    }

                    // このシーンに紐づくBGM / SEの状況
                    sceneBackgroundAudioSummary
                }
                .padding(16)
            }
        }
    }

    // MARK: - Voice Clip Detail Card
    private func voiceClipDetailCard(clip: SoundClip, index: Int, totalCount: Int) -> some View {
        let charName = clip.character ?? "博麗霊夢"
        let charColor = Color(hex: clip.colorHex ?? "#E74C3C")
        let isPlaying = previewPlayer?.isPlaying == true && isPlayingVoice

        return VStack(alignment: .leading, spacing: 8) {
            // Header Row: Order badge, Move, Character, Voice Type, Duration, Delete
            HStack(spacing: 8) {
                Text("順序 \(index + 1)")
                    .font(.system(size: 9, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.cyan.opacity(0.2))
                    .foregroundColor(.cyan)
                    .cornerRadius(3)

                if totalCount > 1 {
                    HStack(spacing: 2) {
                        Button(action: { moveOrder(clip: clip, direction: -1) }) {
                            Image(systemName: "chevron.up")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(index > 0 ? .white : Color.white.opacity(0.2))
                        }
                        .buttonStyle(.plain)
                        .disabled(index == 0)

                        Button(action: { moveOrder(clip: clip, direction: 1) }) {
                            Image(systemName: "chevron.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundColor(index < totalCount - 1 ? .white : Color.white.opacity(0.2))
                        }
                        .buttonStyle(.plain)
                        .disabled(index >= totalCount - 1)
                    }
                }

                // キャラクター変更メニュー
                Menu {
                    let standardChars = [
                        "操夢", "フランドール・スカーレット", "レミリア・スカーレット",
                        "博麗霊夢", "霧雨魔理沙", "東風谷早苗", "萃香", "美鈴",
                        "妹紅", "藤原妹紅", "アリス・マーガトロイド", "射命丸文",
                        "十六夜咲夜", "チルノ", "パチュリー", "ナレーション"
                    ]
                    let existingTrackChars = appState.audioTracks.compactMap { $0.characterName }
                    let combined = Array(Set(standardChars + existingTrackChars + [charName])).sorted { a, b in
                        if a == "操夢" { return true }
                        if b == "操夢" { return false }
                        return a < b
                    }
                    ForEach(combined, id: \.self) { c in
                        Button(action: { updateClipCharacter(clip: clip, newChar: c) }) {
                            HStack {
                                if c == charName { Image(systemName: "checkmark") }
                                Text(c)
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Circle().fill(charColor).frame(width: 8, height: 8)
                        Text(charName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(4)
                }
                .menuStyle(.borderlessButton)

                // 声質タイプ
                Text(clip.voiceType?.rawValue ?? aquesTalk.voiceType(for: charName).rawValue)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.cyan)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.cyan.opacity(0.12))
                    .cornerRadius(3)

                Spacer()

                // 音声の長さ
                Text(String(format: "%.2f秒", clip.duration))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.8))

                // 試聴再生ボタン
                Button(action: {
                    togglePreviewAudio(for: clip)
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: isPlaying ? "stop.fill" : "play.fill")
                        Text(isPlaying ? "停止" : "試聴")
                    }
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(isPlaying ? Color.red.opacity(0.3) : Color.green.opacity(0.2))
                    .foregroundColor(isPlaying ? .red : .green)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)

                // 個別再生成ボタン
                Button(action: {
                    regenerateSingleClip(clip)
                }) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 11))
                        .foregroundColor(.cyan)
                }
                .buttonStyle(.plain)
                .help("このセリフ・パラメータで音声を再合成")

                // 削除ボタン
                Button(action: {
                    deleteClip(clip)
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("この音声クリップを削除")
            }

            // セリフテキスト編集ボックス
            VStack(alignment: .leading, spacing: 4) {
                Text("セリフ / テキスト:")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.secondary)

                TextEditor(text: Binding(
                    get: { clip.text ?? "" },
                    set: { newText in
                        updateClipText(clip: clip, newText: newText)
                    }
                ))
                .font(.system(size: 11))
                .foregroundColor(.white)
                .frame(minHeight: 44, maxHeight: 60)
                .padding(4)
                .background(Color(red: 0.10, green: 0.11, blue: 0.13))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Color(red: 0.24, green: 0.25, blue: 0.28), lineWidth: 1)
                )
            }

            // 音声パラメータ微調整 (速度, 音程, 音量)
            HStack(spacing: 16) {
                // 速度
                HStack(spacing: 6) {
                    Text("速度:")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Slider(
                        value: Binding(
                            get: { Double(clip.speed) },
                            set: { v in updateClipSpeed(clip: clip, newSpeed: Int(v)) }
                        ),
                        in: 50...300,
                        step: 5
                    )
                    .frame(width: 80)
                    Text("\(clip.speed)%")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 36, alignment: .trailing)
                }

                // 音程
                HStack(spacing: 6) {
                    Text("音程:")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Slider(
                        value: Binding(
                            get: { Double(clip.pitch) },
                            set: { v in updateClipPitch(clip: clip, newPitch: Int(v)) }
                        ),
                        in: 50...200,
                        step: 5
                    )
                    .frame(width: 80)
                    Text("\(clip.pitch)%")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 36, alignment: .trailing)
                }

                // 音量
                HStack(spacing: 6) {
                    Text("音量:")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Slider(
                        value: Binding(
                            get: { clip.volume },
                            set: { v in updateClipVolume(clip: clip, newVolume: v) }
                        ),
                        in: 0.0...2.0,
                        step: 0.05
                    )
                    .frame(width: 80)
                    Text("\(Int(clip.volume * 100))%")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 36, alignment: .trailing)
                }
            }

            // 記号化発音記号表示 (AquesTalk記号列)
            if let sym = clip.voiceSymbol, !sym.isEmpty {
                HStack(spacing: 6) {
                    Text("発音記号:")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text(sym)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundColor(.cyan.opacity(0.8))
                        .lineLimit(1)
                    Spacer()
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(12)
        .background(Color(red: 0.18, green: 0.19, blue: 0.22))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(red: 0.24, green: 0.25, blue: 0.28), lineWidth: 1)
        )
    }

    // MARK: - Scene Background Audio Summary
    private var sceneBackgroundAudioSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("シーン連動の背景音 (BGM & SE)", systemImage: "speaker.wave.3")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white.opacity(0.8))

            if currentBgmClips.isEmpty && currentSeClips.isEmpty {
                Text("このシーンにはBGMや効果音は割り当てられていません")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            } else {
                VStack(spacing: 6) {
                    ForEach(currentBgmClips) { bgm in
                        HStack {
                            Image(systemName: "music.note")
                                .foregroundColor(.purple)
                            Text("BGM: \(bgm.name)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Text(String(format: "音量 %d%%", Int(bgm.volume * 100)))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }

                    ForEach(currentSeClips) { se in
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.orange)
                            Text("SE: \(se.name)")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Text(String(format: "音量 %d%%", Int(se.volume * 100)))
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(8)
                .background(Color(red: 0.12, green: 0.13, blue: 0.15))
                .cornerRadius(4)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(red: 0.16, green: 0.17, blue: 0.19))
        .cornerRadius(6)
    }

    // MARK: - Footer
    private var footerView: some View {
        HStack {
            Text("💡 変更内容はタイムラインとプロジェクトデータ（.tssm / .tsvm）に自動反映されます。")
                .font(.system(size: 10))
                .foregroundColor(.secondary)

            Spacer()

            Button("完了") {
                stopPreview()
                presentationMode.wrappedValue.dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(Color.cyan)
            .foregroundColor(.black)
            .cornerRadius(5)
            .font(.system(size: 12, weight: .bold))
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 0.16, green: 0.17, blue: 0.20))
    }

    // MARK: - Add Voice Modal
    private var addVoiceClipModal: some View {
        VStack(spacing: 16) {
            HStack {
                Text("シーン \(sceneIndex) に新規音声を登録")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button(action: { showAddVoiceDialog = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("話者 (キャラクター):")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)

                let chars = ["操夢", "フランドール・スカーレット", "レミリア・スカーレット", "博麗霊夢", "霧雨魔理沙", "十六夜咲夜", "パチュリー", "ナレーション"]
                Picker("", selection: $newVoiceCharacter) {
                    ForEach(chars, id: \.self) { c in
                        Text(c).tag(c)
                    }
                }
                .pickerStyle(.menu)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("セリフ内容:")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)

                TextEditor(text: $newVoiceText)
                    .font(.system(size: 12))
                    .frame(height: 80)
                    .padding(4)
                    .background(Color(red: 0.12, green: 0.13, blue: 0.15))
                    .cornerRadius(4)
            }

            HStack {
                Spacer()
                Button("キャンセル") {
                    showAddVoiceDialog = false
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)

                Button("音声を生成して追加") {
                    createNewVoiceClip()
                    showAddVoiceDialog = false
                }
                .buttonStyle(.borderedProminent)
                .disabled(newVoiceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 440, height: 260)
        .background(Color(red: 0.16, green: 0.17, blue: 0.19))
    }

    // MARK: - Helper Actions
    private func getOrCreateGeneratedAudioDirectory() -> URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let audioDir = appSupport.appendingPathComponent("TohoStudio/GeneratedAudio", isDirectory: true)
        if !fileManager.fileExists(atPath: audioDir.path) {
            try? fileManager.createDirectory(at: audioDir, withIntermediateDirectories: true)
        }
        return audioDir
    }

    private func currentSceneImagePath() -> String? {
        if let path = currentScene?.slideImagePath, FileManager.default.fileExists(atPath: path) {
            return path
        }
        if let bg = currentScene?.backgroundImagePath, FileManager.default.fileExists(atPath: bg) {
            return bg
        }
        let project = appState.currentProjectName
        return AppState.findLatestSlideImagePath(forProject: project, slideIndex: sceneIndex)
    }

    private func stopPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
        isPlayingVoice = false
    }

    private func togglePreviewAudio(for clip: SoundClip) {
        if isPlayingVoice {
            stopPreview()
            return
        }

        if let path = clip.audioFilePath, FileManager.default.fileExists(atPath: path) {
            do {
                let url = URL(fileURLWithPath: path)
                previewPlayer = try AVAudioPlayer(contentsOf: url)
                previewPlayer?.volume = Float(min(1.0, clip.volume))
                previewPlayer?.prepareToPlay()
                previewPlayer?.play()
                isPlayingVoice = true
                return
            } catch {
                appState.log("プレビュー再生失敗: \(error.localizedDescription)")
            }
        }

        // ファイルがない場合はインメモリで即時合成して再生
        guard let text = clip.text, !text.isEmpty else { return }
        let char = clip.character ?? "博麗霊夢"
        let preset = aquesTalk.characterPreset(for: char)
        let vType = clip.voiceType ?? preset.voice
        let speed = clip.speed != 100 ? clip.speed : preset.speed
        let pitch = clip.pitch != 100 ? clip.pitch : preset.pitch
        aquesTalk.synthesizeAndPlay(
            text: text,
            speed: speed,
            voice: vType,
            pitch: pitch,
            quality: .enhanced,
            effect: .none
        )
        isPlayingVoice = true
    }

    private func regenerateSingleClip(_ clip: SoundClip) {
        guard let rawText = clip.text, !rawText.isEmpty else { return }
        let text = SlideItem.cleanDialogueText(from: rawText)
        let char = clip.character ?? "操夢"
        let speed = clip.speed
        let pitch = clip.pitch

        isGenerating = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let wavData: Data?
            if char.contains("&") && !char.components(separatedBy: "&").allSatisfy({ $0 == char.components(separatedBy: "&")[0] }) {
                wavData = self.aquesTalk.synthesizeDuoVoiceToWavData(
                    text: text,
                    speakerName: char,
                    customSpeed: speed != 100 ? speed : nil,
                    quality: .enhanced,
                    effect: .none
                )
            } else {
                let preset = self.aquesTalk.characterPreset(for: char)
                let vType = clip.voiceType ?? preset.voice
                wavData = self.aquesTalk.synthesizeToWavData(
                    text: text,
                    speed: speed,
                    voice: vType,
                    pitch: pitch,
                    quality: .enhanced,
                    effect: .none
                )
            }

            var targetFilePath: String? = nil
            if let data = wavData {
                let audioDir = self.getOrCreateGeneratedAudioDirectory()
                let safeChar = char.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
                let fileName = String(format: "Slide_%03d_%@_%@.wav", self.sceneIndex, safeChar, UUID().uuidString.prefix(6) as CVarArg)
                let fileURL = audioDir.appendingPathComponent(fileName)
                if (try? data.write(to: fileURL)) != nil {
                    targetFilePath = fileURL.path
                }
            }

            DispatchQueue.main.async {
                self.isGenerating = false
                guard let idx = self.appState.soundClips.firstIndex(where: { $0.id == clip.id }) else { return }

                var finalAudioDuration: Double = clip.duration
                if let data = wavData, data.count > 44 {
                    let sampleRate = Double(data.withUnsafeBytes { $0.load(fromByteOffset: 24, as: UInt32.self) })
                    let channels = Double(data.withUnsafeBytes { $0.load(fromByteOffset: 22, as: UInt16.self) })
                    let bitsPerSample = Double(data.withUnsafeBytes { $0.load(fromByteOffset: 34, as: UInt16.self) })
                    if sampleRate > 0 && channels > 0 && bitsPerSample > 0 {
                        let bytesPerSec = sampleRate * channels * (bitsPerSample / 8.0)
                        let dataSize = Double(data.count - 44)
                        let calcDur = dataSize / bytesPerSec
                        if calcDur > 0.05 {
                            finalAudioDuration = calcDur
                        }
                    }
                }

                self.appState.soundClips[idx].duration = finalAudioDuration
                if let targetFilePath = targetFilePath {
                    self.appState.soundClips[idx].audioFilePath = targetFilePath
                }
                self.appState.soundClips[idx].waveformPoints = (1...24).map { _ in Float.random(in: 0.15...0.95) }
                self.appState.syncClipsToMovieScenes(self.appState.soundClips)

                self.successToast = "『\(text.prefix(12))…』の音声を再生成しました (\(String(format: "%.2f秒", finalAudioDuration)))"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    self.successToast = nil
                }
            }
        }
    }

    private func regenerateVoiceFromSlideForThisScene() {
        guard let scene = currentScene else { return }
        let textCandidate: String = {
            if let note = currentSlide?.presenterNote, !note.isEmpty { return note }
            if let tel = currentSlide?.telop, !tel.isEmpty { return tel }
            return scene.telop
        }()
        let cleaned = SlideItem.cleanDialogueText(from: textCandidate)
        guard !cleaned.isEmpty else {
            errorMessage = "スライドに台本・テキストが設定されていません。"
            return
        }

        let char: String = {
            if let c = currentSlide?.characterName, !c.isEmpty { return c }
            return scene.characterName.isEmpty ? "操夢" : scene.characterName
        }()

        isGenerating = true
        errorMessage = nil

        DispatchQueue.global(qos: .userInitiated).async { [self] in
            let preset = self.aquesTalk.characterPreset(for: char)
            let wavData = self.aquesTalk.synthesizeToWavData(
                text: cleaned,
                speed: preset.speed,
                voice: preset.voice,
                pitch: preset.pitch,
                quality: .enhanced,
                effect: .none
            )

            var targetFilePath: String? = nil
            if let data = wavData {
                let audioDir = self.getOrCreateGeneratedAudioDirectory()
                let safeChar = char.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: ":", with: "_")
                let fileName = String(format: "Slide_%03d_%@.wav", self.sceneIndex, safeChar)
                let fileURL = audioDir.appendingPathComponent(fileName)
                if (try? data.write(to: fileURL)) != nil {
                    targetFilePath = fileURL.path
                }
            }

            DispatchQueue.main.async {
                self.isGenerating = false

                // 尺計算
                var dur: Double = max(2.0, Double(cleaned.count) * 0.22)
                if let data = wavData, data.count > 44 {
                    let sampleRate = Double(data.withUnsafeBytes { $0.load(fromByteOffset: 24, as: UInt32.self) })
                    let channels = Double(data.withUnsafeBytes { $0.load(fromByteOffset: 22, as: UInt16.self) })
                    let bitsPerSample = Double(data.withUnsafeBytes { $0.load(fromByteOffset: 34, as: UInt16.self) })
                    if sampleRate > 0 && channels > 0 && bitsPerSample > 0 {
                        let bytesPerSec = sampleRate * channels * (bitsPerSample / 8.0)
                        let dataSize = Double(data.count - 44)
                        let calcDur = dataSize / bytesPerSec
                        if calcDur > 0.05 { dur = calcDur }
                    }
                }

                // 既存のクリップがあれば更新、なければ追加
                if let existingIdx = self.appState.soundClips.firstIndex(where: { $0.sceneIndex == self.sceneIndex && $0.type == "Voice" }) {
                    self.appState.soundClips[existingIdx].character = char
                    self.appState.soundClips[existingIdx].text = cleaned
                    self.appState.soundClips[existingIdx].duration = dur
                    self.appState.soundClips[existingIdx].audioFilePath = targetFilePath
                    self.appState.soundClips[existingIdx].voiceSymbol = self.aquesTalk.convertToVoiceSymbol(text: cleaned)
                } else {
                    let voiceTrack = self.appState.audioTracks.first(where: { $0.characterName == char || $0.type == "voice" })
                    let trackId = voiceTrack?.id ?? "track_voice_reimu"
                    let clipColor = voiceTrack?.colorHex ?? "#E74C3C"

                    let newClip = SoundClip(
                        name: "[\(char)] \(cleaned)",
                        type: "Voice",
                        character: char,
                        text: cleaned,
                        voiceSymbol: self.aquesTalk.convertToVoiceSymbol(text: cleaned),
                        duration: dur,
                        volume: 1.0,
                        speed: preset.speed,
                        startTime: 0.0,
                        trackId: trackId,
                        colorHex: clipColor,
                        waveformPoints: (1...24).map { _ in Float.random(in: 0.2...0.9) },
                        sceneIndex: self.sceneIndex,
                        audioFilePath: targetFilePath
                    )
                    self.appState.soundClips.append(newClip)
                }

                self.appState.syncClipsToMovieScenes(self.appState.soundClips)
                self.successToast = "シーン \(self.sceneIndex) の音声を台本から生成しました"
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                    self.successToast = nil
                }
            }
        }
    }

    private func createNewVoiceClip() {
        let cleaned = SlideItem.cleanDialogueText(from: newVoiceText)
        guard !cleaned.isEmpty else { return }

        let preset = aquesTalk.characterPreset(for: newVoiceCharacter)
        let voiceTrack = appState.audioTracks.first(where: { $0.characterName == newVoiceCharacter || $0.type == "voice" })
        let trackId = voiceTrack?.id ?? "track_voice_reimu"
        let clipColor = voiceTrack?.colorHex ?? "#E74C3C"

        let newClip = SoundClip(
            name: "[\(newVoiceCharacter)] \(cleaned)",
            type: "Voice",
            character: newVoiceCharacter,
            text: cleaned,
            voiceSymbol: aquesTalk.convertToVoiceSymbol(text: cleaned),
            duration: max(2.0, Double(cleaned.count) * 0.22),
            volume: 1.0,
            speed: preset.speed,
            startTime: 0.0,
            trackId: trackId,
            colorHex: clipColor,
            waveformPoints: (1...20).map { _ in Float.random(in: 0.2...0.8) },
            sceneIndex: sceneIndex
        )
        appState.soundClips.append(newClip)
        appState.syncClipsToMovieScenes(appState.soundClips)

        // バックグラウンドで音声合成
        regenerateSingleClip(newClip)
    }

    private func updateClipText(clip: SoundClip, newText: String) {
        guard let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) else { return }
        appState.soundClips[idx].text = newText
        appState.soundClips[idx].name = "[\(clip.character ?? "")] \(newText)"
        appState.soundClips[idx].voiceSymbol = aquesTalk.convertToVoiceSymbol(text: newText)
    }

    private func updateClipCharacter(clip: SoundClip, newChar: String) {
        guard let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) else { return }
        let preset = aquesTalk.characterPreset(for: newChar)
        appState.soundClips[idx].character = newChar
        appState.soundClips[idx].voiceType = preset.voice
        if appState.soundClips[idx].speed == 100 {
            appState.soundClips[idx].speed = preset.speed
        }
        appState.soundClips[idx].pitch = preset.pitch
        let track = appState.audioTracks.first(where: { $0.characterName == newChar })
        if let t = track {
            appState.soundClips[idx].colorHex = t.colorHex
            appState.soundClips[idx].trackId = t.id
        }
        appState.syncClipsToMovieScenes(appState.soundClips)
    }

    private func updateClipSpeed(clip: SoundClip, newSpeed: Int) {
        guard let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) else { return }
        appState.soundClips[idx].speed = newSpeed
    }

    private func updateClipPitch(clip: SoundClip, newPitch: Int) {
        guard let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) else { return }
        appState.soundClips[idx].pitch = newPitch
    }

    private func updateClipVolume(clip: SoundClip, newVolume: Double) {
        guard let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) else { return }
        appState.soundClips[idx].volume = newVolume
        appState.syncClipsToMovieScenes(appState.soundClips)
    }

    private func moveOrder(clip: SoundClip, direction: Int) {
        var clips = currentVoiceClips
        guard let currentPos = clips.firstIndex(where: { $0.id == clip.id }) else { return }
        let newPos = currentPos + direction
        guard newPos >= 0 && newPos < clips.count else { return }

        clips.swapAt(currentPos, newPos)
        // タイムライン上の開始時刻を順序通りに再整列
        var runningOffset = 0.2
        for c in clips {
            if let masterIdx = appState.soundClips.firstIndex(where: { $0.id == c.id }) {
                appState.soundClips[masterIdx].startTime += (direction > 0 ? 0.05 : -0.05)
            }
            runningOffset += c.duration + 0.15
        }
        appState.syncClipsToMovieScenes(appState.soundClips)
    }

    private func deleteClip(_ clip: SoundClip) {
        appState.soundClips.removeAll(where: { $0.id == clip.id })
        appState.syncClipsToMovieScenes(appState.soundClips)
    }
}

// MARK: - Color Extension
private extension Color {
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
            (a, r, g, b) = (1, 1, 1, 0)
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
