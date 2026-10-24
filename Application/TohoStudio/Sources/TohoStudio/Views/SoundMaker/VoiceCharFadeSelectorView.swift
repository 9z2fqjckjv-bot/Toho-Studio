import SwiftUI
import AppKit
import AVFoundation

/// キャラクターボイスのセリフテキストを基準に、1文字単位で再生開始位置（どの言葉を発言したら流れるか）およびフェードアウト開始位置を設定する専用セレクターView
public struct VoiceCharFadeSelectorView: View {
    @Binding var clip: SoundClip
    public var voiceClip: SoundClip?
    public var onUpdated: (() -> Void)? = nil

    @ObservedObject var soundManager = SoundMakerAudioManager.shared
    @ObservedObject var aquesTalk = AquesTalkBridge.shared

    // 選択編集モード: 再生開始文字 または フェードアウト開始文字
    @State private var selectionMode: SelectionMode = .startChar
    @State private var isLinkedPreviewing: Bool = false
    @State private var linkedPreviewTimer: Timer? = nil
    @State private var linkedVoicePlayer: AVAudioPlayer? = nil

    private enum SelectionMode {
        case startChar
        case fadeOutChar
    }

    public init(
        clip: Binding<SoundClip>,
        voiceClip: SoundClip?,
        onUpdated: (() -> Void)? = nil
    ) {
        self._clip = clip
        self.voiceClip = voiceClip
        self.onUpdated = onUpdated
    }

    // ボイスのセリフテキストと文字タイミングリスト
    private var dialogueText: String {
        guard let v = voiceClip else { return "" }
        if let t = v.text, !t.isEmpty { return t }
        return v.name.components(separatedBy: "] ").last ?? v.name
    }

    private var voiceDuration: Double {
        guard let v = voiceClip else { return 3.0 }
        // 実際に再生される実音声ファイルの正確な秒数を最優先（実ファイルとクリップの乖離によるズレを防止）
        if let path = v.audioFilePath, FileManager.default.fileExists(atPath: path),
           let player = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: path)), player.duration > 0.1 {
            return player.duration
        }
        return v.duration > 0.05 ? v.duration : 3.0
    }

    private var characterTimings: [CharacterTimingInfo] {
        guard !dialogueText.isEmpty else { return [] }
        return VoiceTextTimingService.calculateCharacterTimings(
            text: dialogueText,
            totalDuration: voiceDuration,
            audioFilePath: voiceClip?.audioFilePath
        )
    }

    // 有効な再生開始文字インデックス (startCharIndex または fadeInCharIndex)
    private var effectiveStartCharIdx: Int? {
        clip.startCharIndex ?? clip.fadeInCharIndex
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header & Enable Toggle
            HStack(spacing: 6) {
                Image(systemName: "text.cursor")
                    .foregroundColor(.cyan)
                    .font(.system(size: 13))

                VStack(alignment: .leading, spacing: 1) {
                    Text("ボイス文字連動再生 & フェード (1文字単位)")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                    Text("セリフに含まれる特定の言葉（文字）を発言した瞬間に流します")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("", isOn: Binding(
                    get: { clip.voiceTriggerEnabled },
                    set: { val in
                        clip.voiceTriggerEnabled = val
                        if val {
                            if clip.startCharIndex == nil {
                                clip.startCharIndex = 0
                            }
                            if let v = voiceClip {
                                clip.voiceTriggerClipId = v.id
                                updateStartTimeFromVoice(voice: v, charIdx: clip.startCharIndex ?? 0)
                            }
                        } else {
                            // 無効化時は現在の所属シーン先頭からの相対開始時間を保持
                            if let idx = AppState.shared.soundClips.firstIndex(where: { $0.id == clip.id }) {
                                AppState.shared.soundClips[idx] = clip
                            }
                            AppState.shared.syncClipsToMovieScenes(AppState.shared.soundClips)
                        }
                        onUpdated?()
                    }
                ))
                .toggleStyle(.switch)
                .controlSize(.small)
            }

            if clip.voiceTriggerEnabled {
                if let vClip = voiceClip, !dialogueText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        // 基準ボイス情報 & 同時試聴ボタン
                        HStack(spacing: 6) {
                            Text("基準ボイス:")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Text(vClip.character ?? "キャラクター")
                                .font(.caption2.bold())
                            Text("(\(String(format: "%.2fs", voiceDuration)), \(characterTimings.count)文字)")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)

                            Spacer()

                            // ボイスと同時試聴ボタン
                            Button(action: {
                                toggleVoiceLinkedPreview()
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: isLinkedPreviewing ? "stop.fill" : "play.fill")
                                    Text(isLinkedPreviewing ? "停止" : "ボイスと同時試聴")
                                }
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(isLinkedPreviewing ? Color.red : Color.green.opacity(0.85))
                                .cornerRadius(3)
                            }
                            .buttonStyle(.plain)
                            .help("ボイスの発話に合わせて、指定した言葉で音が鳴り始める動作をその場で試聴確認")
                        }

                        // モードセレクター (再生開始文字 vs フェードアウト文字)
                        HStack(spacing: 8) {
                            Button(action: { selectionMode = .startChar }) {
                                HStack(spacing: 4) {
                                    Circle().fill(Color.green).frame(width: 6, height: 6)
                                    Text("🟢 再生開始文字: \(startCharSummaryText())")
                                        .font(.caption2.bold())
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(selectionMode == .startChar ? Color.green.opacity(0.3) : Color.white.opacity(0.06))
                                .foregroundColor(selectionMode == .startChar ? .green : .secondary)
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)

                            Button(action: { selectionMode = .fadeOutChar }) {
                                HStack(spacing: 4) {
                                    Circle().fill(Color(hex: "#DDA0DD")).frame(width: 6, height: 6)
                                    Text("🟣 フェードアウト文字: \(fadeOutSummaryText())")
                                        .font(.caption2.bold())
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(selectionMode == .fadeOutChar ? Color.purple.opacity(0.35) : Color.white.opacity(0.06))
                                .foregroundColor(selectionMode == .fadeOutChar ? Color(hex: "#DDA0DD") : .secondary)
                                .cornerRadius(4)
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            // 解除ボタン
                            Button(action: {
                                if selectionMode == .startChar {
                                    clip.startCharIndex = nil
                                    clip.fadeInCharIndex = nil
                                } else {
                                    clip.fadeOutCharIndex = nil
                                }
                                if let idx = AppState.shared.soundClips.firstIndex(where: { $0.id == clip.id }) {
                                    AppState.shared.soundClips[idx] = clip
                                }
                                AppState.shared.syncClipsToMovieScenes(AppState.shared.soundClips)
                                onUpdated?()
                            }) {
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("現在の設定文字を解除")
                        }

                        // 1文字ステップ微調整
                        HStack(spacing: 8) {
                            Text("1文字微調整:")
                                .font(.system(size: 9))
                                .foregroundColor(.secondary)

                            Button(action: { stepCharIndex(by: -1) }) {
                                HStack(spacing: 2) {
                                    Image(systemName: "chevron.left")
                                    Text("前の一文字")
                                }
                                .font(.system(size: 9))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(3)
                            }
                            .buttonStyle(.plain)

                            Button(action: { stepCharIndex(by: 1) }) {
                                HStack(spacing: 2) {
                                    Text("次の一文字")
                                    Image(systemName: "chevron.right")
                                }
                                .font(.system(size: 9))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(3)
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Text("下の文字一覧から\(selectionMode == .startChar ? "【再生を開始する文字】" : "【フェードアウトを開始する文字】")をクリック")
                                .font(.system(size: 8))
                                .foregroundColor(selectionMode == .startChar ? .green : Color(hex: "#DDA0DD"))
                        }

                        // インタラクティブな1文字グリッド
                        characterChipsGridView(timings: characterTimings)

                        // 再生・フェードパラメータ
                        HStack(spacing: 12) {
                            // フェードイン秒数
                            HStack(spacing: 3) {
                                Text("立ち上がり(FI):").font(.system(size: 8.5)).foregroundColor(.secondary)
                                ForEach([0.0, 0.5, 1.0, 2.0], id: \.self) { fi in
                                    Button(action: {
                                        clip.fadeInDuration = fi
                                        onUpdated?()
                                    }) {
                                        Text(fi == 0 ? "即時" : String(format: "%.1fs", fi))
                                            .font(.system(size: 7.5, weight: abs(clip.fadeInDuration - fi) < 0.05 ? .bold : .regular))
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1.5)
                                            .background(abs(clip.fadeInDuration - fi) < 0.05 ? Color.cyan.opacity(0.35) : Color.white.opacity(0.06))
                                            .foregroundColor(abs(clip.fadeInDuration - fi) < 0.05 ? .cyan : .secondary)
                                            .cornerRadius(2)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }

                            Spacer()

                            // タイミング微調整オフセット
                            HStack(spacing: 4) {
                                Text("微調整:").font(.system(size: 8.5)).foregroundColor(.secondary)
                                Slider(
                                    value: Binding(
                                        get: { clip.voiceTriggerOffset },
                                        set: { val in
                                            clip.voiceTriggerOffset = (val * 100).rounded() / 100
                                            if let v = voiceClip, let charIdx = effectiveStartCharIdx {
                                                updateStartTimeFromVoice(voice: v, charIdx: charIdx)
                                            }
                                            onUpdated?()
                                        }
                                    ),
                                    in: -1.0...1.0,
                                    step: 0.05
                                )
                                .frame(width: 80)
                                Text(String(format: "%+.2fs", clip.voiceTriggerOffset))
                                    .font(.system(size: 8.5, design: .monospaced))
                                    .foregroundColor(clip.voiceTriggerOffset != 0 ? .orange : .secondary)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color(red: 0.12, green: 0.13, blue: 0.15))
                    .cornerRadius(6)
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 10))
                            .foregroundColor(.orange)
                        Text("このシーンには基準となるキャラクターボイス（セリフ）がありません。")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(4)
                }
            }
        }
        .padding(8)
        .background(Color(white: 0.10))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(clip.voiceTriggerEnabled ? Color.green.opacity(0.4) : Color.white.opacity(0.05), lineWidth: 1)
        )
    }

    // MARK: - Character Chips Grid View (1文字ブロック)
    private func characterChipsGridView(timings: [CharacterTimingInfo]) -> some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 4) {
                ForEach(timings) { item in
                    let isStart = effectiveStartCharIdx == item.index
                    let isFadeOut = clip.fadeOutCharIndex == item.index

                    Button(action: {
                        if selectionMode == .startChar {
                            if effectiveStartCharIdx == item.index {
                                clip.startCharIndex = nil
                                clip.fadeInCharIndex = nil
                                if let idx = AppState.shared.soundClips.firstIndex(where: { $0.id == clip.id }) {
                                    AppState.shared.soundClips[idx] = clip
                                }
                                AppState.shared.syncClipsToMovieScenes(AppState.shared.soundClips)
                            } else {
                                clip.startCharIndex = item.index
                                clip.fadeInCharIndex = item.index
                                if let voice = voiceClip {
                                    updateStartTimeFromVoice(voice: voice, charIdx: item.index)
                                }
                            }
                        } else {
                            if clip.fadeOutCharIndex == item.index {
                                clip.fadeOutCharIndex = nil
                            } else {
                                clip.fadeOutCharIndex = item.index
                            }
                        }
                        onUpdated?()
                    }) {
                        VStack(spacing: 2) {
                            // バッジマーカー (開始 / FO)
                            ZStack {
                                if isStart && isFadeOut {
                                    Text("開始/FO")
                                        .font(.system(size: 6.5, weight: .black))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 2)
                                        .background(Color.purple)
                                        .cornerRadius(2)
                                } else if isStart {
                                    Text("開始")
                                        .font(.system(size: 7, weight: .black))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 3)
                                        .background(Color.green)
                                        .cornerRadius(2)
                                } else if isFadeOut {
                                    Text("FO")
                                        .font(.system(size: 7, weight: .black))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 3)
                                        .background(Color(hex: "#9B59B6"))
                                        .cornerRadius(2)
                                } else {
                                    Text("#\(item.index + 1)")
                                        .font(.system(size: 6.5))
                                        .foregroundColor(.secondary)
                                }
                            }
                            .frame(height: 10)

                            // 文字本体
                            Text(item.characterString)
                                .font(.system(size: 13, weight: (isStart || isFadeOut) ? .bold : .regular))
                                .foregroundColor(chipTextColor(isStart: isStart, isFadeOut: isFadeOut))
                                .frame(width: 22, height: 22)
                                .background(chipBackgroundColor(isStart: isStart, isFadeOut: isFadeOut))
                                .cornerRadius(3)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(chipBorderColor(isStart: isStart, isFadeOut: isFadeOut), lineWidth: (isStart || isFadeOut) ? 1.5 : 0.5)
                                )

                            // 推定秒数表示
                            Text(String(format: "%.2fs", item.startSeconds))
                                .font(.system(size: 6.5, design: .monospaced))
                                .foregroundColor((isStart || isFadeOut) ? .white : Color(white: 0.5))
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(height: 64)
        .background(Color.black.opacity(0.25))
        .cornerRadius(4)
    }

    private func chipTextColor(isStart: Bool, isFadeOut: Bool) -> Color {
        if isStart { return .green }
        if isFadeOut { return Color(hex: "#DDA0DD") }
        return .white
    }

    private func chipBackgroundColor(isStart: Bool, isFadeOut: Bool) -> Color {
        if isStart && isFadeOut {
            return Color.purple.opacity(0.4)
        }
        if isStart {
            return Color.green.opacity(0.25)
        }
        if isFadeOut {
            return Color.purple.opacity(0.25)
        }
        return Color.white.opacity(0.05)
    }

    private func chipBorderColor(isStart: Bool, isFadeOut: Bool) -> Color {
        if isStart { return .green }
        if isFadeOut { return Color(hex: "#DDA0DD") }
        return Color.white.opacity(0.12)
    }

    // MARK: - Helpers
    private func startCharSummaryText() -> String {
        guard let idx = effectiveStartCharIdx else { return "未指定 (発話と同時)" }
        let timings = characterTimings
        if idx >= 0 && idx < timings.count {
            let item = timings[idx]
            return "「\(item.characterString)」(\(String(format: "%.2fs", item.startSeconds)))"
        }
        return "\(idx + 1)文字目"
    }

    private func fadeOutSummaryText() -> String {
        guard let idx = clip.fadeOutCharIndex else { return "未指定 (末尾)" }
        let timings = characterTimings
        if idx >= 0 && idx < timings.count {
            let item = timings[idx]
            return "「\(item.characterString)」(\(String(format: "%.2fs", item.startSeconds)))"
        }
        return "\(idx + 1)文字目"
    }

    private func updateStartTimeFromVoice(voice: SoundClip, charIdx: Int) {
        let timings = characterTimings
        if charIdx >= 0 && charIdx < timings.count {
            let timing = timings[charIdx]
            let relTime = max(0.0, timing.startSeconds + clip.voiceTriggerOffset)
            clip.sceneRelativeStartTime = relTime
            clip.startTime = voice.startTime + relTime
            if let idx = AppState.shared.soundClips.firstIndex(where: { $0.id == clip.id }) {
                AppState.shared.soundClips[idx] = clip
            }
            AppState.shared.updateClipSceneTiming(clipId: clip.id)
            AppState.shared.syncClipsToMovieScenes(AppState.shared.soundClips)
        }
    }

    private func stepCharIndex(by step: Int) {
        let maxCount = characterTimings.count
        guard maxCount > 0 else { return }

        if selectionMode == .startChar {
            let current = effectiveStartCharIdx ?? 0
            let next = max(0, min(maxCount - 1, current + step))
            clip.startCharIndex = next
            clip.fadeInCharIndex = next
            if let voice = voiceClip {
                updateStartTimeFromVoice(voice: voice, charIdx: next)
            }
        } else {
            let current = clip.fadeOutCharIndex ?? (maxCount - 1)
            let next = max(0, min(maxCount - 1, current + step))
            clip.fadeOutCharIndex = next
        }
        onUpdated?()
    }

    // MARK: - 連動試聴 (ボイス再生＋指定文字到達でBGM/SEを正確に発火)
    private func toggleVoiceLinkedPreview() {
        if isLinkedPreviewing {
            stopLinkedPreview()
            return
        }

        guard let v = voiceClip else { return }
        isLinkedPreviewing = true

        let effectiveDialogue = dialogueText
        let voiceDur = voiceDuration

        var inDelay: Double = 0.0
        if let inIdx = effectiveStartCharIdx,
           let t = VoiceTextTimingService.timingForCharacter(
            index: inIdx,
            text: effectiveDialogue,
            totalDuration: voiceDur,
            audioFilePath: v.audioFilePath
           ) {
            inDelay = max(0.0, t + clip.voiceTriggerOffset)
        }

        AppState.shared.log("🎙️ ボイス連動試聴: セリフ再生開始 (指定文字まで \(String(format: "%.2fs", inDelay)) 待機後、音声を再生)")

        // 1. ボイス再生の実行（既存音声ファイル優先で合成遅延をゼロ化）
        if let path = v.audioFilePath, FileManager.default.fileExists(atPath: path),
           let player = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: path)) {
            player.volume = 1.0
            player.play()
            linkedVoicePlayer = player

            // ボイス終了監視
            let endDelay = max(voiceDur, player.duration) + 0.3
            DispatchQueue.main.asyncAfter(deadline: .now() + endDelay) {
                if self.isLinkedPreviewing {
                    self.stopLinkedPreview()
                }
            }

            // 2. 指定文字到達タイミングで効果音を発音
            if inDelay <= 0.02 {
                soundManager.playPreview(clip: self.clip)
            } else {
                linkedPreviewTimer?.invalidate()
                linkedPreviewTimer = Timer.scheduledTimer(withTimeInterval: inDelay, repeats: false) { [weak soundManager] _ in
                    if self.isLinkedPreviewing {
                        soundManager?.playPreview(clip: self.clip)
                    }
                }
            }
        } else {
            // ファイルがまだない場合は AquesTalk で再生
            aquesTalk.synthesizeAndPlay(text: effectiveDialogue) {
                DispatchQueue.main.async {
                    self.isLinkedPreviewing = false
                }
            }
            if inDelay <= 0.02 {
                soundManager.playPreview(clip: self.clip)
            } else {
                linkedPreviewTimer?.invalidate()
                linkedPreviewTimer = Timer.scheduledTimer(withTimeInterval: inDelay, repeats: false) { [weak soundManager] _ in
                    if self.isLinkedPreviewing {
                        soundManager?.playPreview(clip: self.clip)
                    }
                }
            }
        }
    }

    private func stopLinkedPreview() {
        linkedPreviewTimer?.invalidate()
        linkedPreviewTimer = nil
        linkedVoicePlayer?.stop()
        linkedVoicePlayer = nil
        soundManager.stopPreview()
        aquesTalk.stopPlayback()
        isLinkedPreviewing = false
    }
}

// MARK: - Color Hex Helper
private extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var int: UInt64 = 0
        scanner.scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
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
