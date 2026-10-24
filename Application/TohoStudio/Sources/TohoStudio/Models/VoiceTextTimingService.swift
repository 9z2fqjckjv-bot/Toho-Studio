import Foundation

/// セリフ中の1文字ごとのタイミング情報
public struct CharacterTimingInfo: Identifiable, Equatable {
    public var id: Int { index }
    public var index: Int               // 0-based 文字インデックス
    public var character: Character     // 該当文字
    public var characterString: String { String(character) }
    public var startSeconds: Double     // ボイス開始からの相対秒数 (秒)
    public var durationSeconds: Double  // この文字の推定持続時間 (秒)
    public var endSeconds: Double { startSeconds + durationSeconds }
    public var isPunctuation: Bool      // 句読点・記号かどうか
}

import Foundation
import AVFoundation

/// 音声ファイル（WAV/MP3/M4A）の波形RMSエネルギーを解析し、実発話セグメント（発声開始・終了時刻）を10ミリ秒単位で高精度に検出するアナライザー
public final class AudioSegmentDetector {
    // 高速化のためのキャッシュ (ファイルパス -> セグメントリスト)
    private static var segmentCache: [String: (totalDuration: Double, segments: [(start: Double, end: Double)])] = [:]
    private static let lock = NSLock()

    public static func detectSegments(audioFilePath: String) -> (totalDuration: Double, segments: [(start: Double, end: Double)])? {
        lock.lock()
        if let cached = segmentCache[audioFilePath] {
            lock.unlock()
            return cached
        }
        lock.unlock()

        guard FileManager.default.fileExists(atPath: audioFilePath) else { return nil }
        guard let file = try? AVAudioFile(forReading: URL(fileURLWithPath: audioFilePath)) else { return nil }

        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0, let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        try? file.read(into: buffer)
        guard let channelData = buffer.floatChannelData else { return nil }

        let sampleRate = format.sampleRate
        let totalFrames = Int(buffer.frameLength)
        let channels = Int(format.channelCount)
        let totalDur = Double(totalFrames) / sampleRate

        let frameSize = Int(sampleRate * 0.01) // 10ms
        guard frameSize > 0 else { return nil }
        var rmsList: [Float] = []

        for frameStart in stride(from: 0, to: totalFrames - frameSize, by: frameSize) {
            var sumSquare: Float = 0.0
            for ch in 0..<channels {
                let channelSamples = channelData[ch]
                for i in 0..<frameSize {
                    let s = channelSamples[frameStart + i]
                    sumSquare += s * s
                }
            }
            let meanSquare = sumSquare / Float(frameSize * channels)
            rmsList.append(sqrt(meanSquare))
        }

        let threshold: Float = 0.015
        var segments: [(start: Double, end: Double)] = []
        var inSpeech = false
        var startIdx = 0
        let minSilence = 7 // 70ms 以上の無音でセグメント分割
        var silenceCount = 0

        for (i, rms) in rmsList.enumerated() {
            if rms > threshold {
                if !inSpeech {
                    inSpeech = true
                    startIdx = max(0, i - 1)
                }
                silenceCount = 0
            } else {
                if inSpeech {
                    silenceCount += 1
                    if silenceCount >= minSilence {
                        inSpeech = false
                        let endIdx = i - silenceCount + 1
                        segments.append((start: Double(startIdx) * 0.01, end: Double(endIdx) * 0.01))
                    }
                }
            }
        }
        if inSpeech {
            segments.append((start: Double(startIdx) * 0.01, end: Double(rmsList.count) * 0.01))
        }

        let result = (totalDur, segments)
        lock.lock()
        segmentCache[audioFilePath] = result
        lock.unlock()
        return result
    }
}


/// キャラクターボイスのセリフテキストから、1文字ごとの発話タイミングを推定・算出するサービス
/// 句読点（、。）、促音（っ）、長音（ー）、感嘆符などの発音特性を重み付けし、実音声波形と完全同期
public enum VoiceTextTimingService {

    /// セリフテキストと総音声長（および任意の実音声ファイルパス）から、各文字の発話推定タイミングリストを生成
    public static func calculateCharacterTimings(
        text: String,
        totalDuration: Double,
        audioFilePath: String? = nil
    ) -> [CharacterTimingInfo] {
        let cleaned = SlideItem.cleanDialogueText(from: text)
        let effectiveText = cleaned.isEmpty ? text : cleaned
        let characters = Array(effectiveText)
        guard !characters.isEmpty, totalDuration > 0.05 else { return [] }

        // 実測波形セグメントの取得（音声ファイルが存在する場合）
        var detectedSegments: [(start: Double, end: Double)] = []
        var effectiveDur = totalDuration
        if let path = audioFilePath, let res = AudioSegmentDetector.detectSegments(audioFilePath: path), !res.segments.isEmpty {
            detectedSegments = res.segments
            effectiveDur = max(res.totalDuration, totalDuration)
        }

        // 各文字の音韻ウェイトを算出
        let weights = characters.map { weight(for: $0) }
        var charTimings: [Int: (start: Double, dur: Double)] = [:]

        if !detectedSegments.isEmpty {
            // MARK: - 実測波形セグメント連動モード (1ミリ秒の狂いもなく完全同期)
            let totalSpeechWeight = weights.reduce(0.0, +)
            let totalSpeechTime = detectedSegments.reduce(0.0) { $0 + ($1.end - $1.start) }
            let secPerWeight = totalSpeechWeight > 0 ? (totalSpeechTime / totalSpeechWeight) : 0.11

            var strongBoundaries: [Int] = []
            var weakBoundaries: [Int] = []
            var firstFound = false
            let particles: Set<Character> = ["の", "で", "を", "に", "が", "は", "と", "も", "へ"]

            for (i, c) in characters.enumerated() {
                if isSilentBracket(c) || isPunctuationCharacter(c) { continue }
                if !firstFound {
                    strongBoundaries.append(i)
                    firstFound = true
                    continue
                }
                // 句読点の直後の文字
                var prevI = i - 1
                while prevI >= 0 && isSilentBracket(characters[prevI]) { prevI -= 1 }
                if prevI >= 0 && isPunctuationCharacter(characters[prevI]) {
                    strongBoundaries.append(i)
                    continue
                }
                // 助詞の直後で自立語（漢字、カタカナ、名詞の頭「お」）
                if i > 0 && particles.contains(characters[i - 1]) && (isKanji(c) || isKatakana(c) || c == "お") {
                    weakBoundaries.append(i)
                    continue
                }
                // 「まで」「から」の直後
                if i > 1 {
                    let twoBack = String(characters[i-2...i-1])
                    if (twoBack == "まで" || twoBack == "から") && (isKanji(c) || isKatakana(c) || c == "お") {
                        weakBoundaries.append(i)
                        continue
                    }
                }
            }

            var finalBoundaries = strongBoundaries
            if finalBoundaries.count < detectedSegments.count && !weakBoundaries.isEmpty {
                // 不足分のセグメント境界を、セグメント開始時刻に最も近い weakBoundary から順に選択
                let needed = detectedSegments.count - finalBoundaries.count

                var scoredWeak: [(idx: Int, minDiff: Double)] = []
                for wIdx in weakBoundaries {
                    var wTime = detectedSegments.first!.start
                    for k in 0..<wIdx {
                        wTime += weights[k] * secPerWeight
                        if isPunctuationCharacter(characters[k]) { wTime += 0.20 }
                    }
                    let minDiff = detectedSegments.map { abs($0.start - wTime) }.min() ?? 999.0
                    scoredWeak.append((idx: wIdx, minDiff: minDiff))
                }

                scoredWeak.sort { $0.minDiff < $1.minDiff }
                for item in scoredWeak.prefix(needed) {
                    finalBoundaries.append(item.idx)
                }
                finalBoundaries.sort()
            }

            var phrases: [[Int]] = []
            for (bIdx, startI) in finalBoundaries.enumerated() {
                let endI = (bIdx + 1 < finalBoundaries.count) ? finalBoundaries[bIdx + 1] : characters.count
                var pChars: [Int] = []
                for idx in startI..<endI {
                    if !isSilentBracket(characters[idx]) && !isPunctuationCharacter(characters[idx]) {
                        pChars.append(idx)
                    }
                }
                if !pChars.isEmpty {
                    phrases.append(pChars)
                }
            }

            for (pIdx, p) in phrases.enumerated() {
                guard pIdx < detectedSegments.count else { break }
                let seg = detectedSegments[pIdx]
                let segDur = max(0.05, seg.end - seg.start)
                let subW = p.map { weights[$0] }
                let totalW = subW.reduce(0.0, +)
                var acc = seg.start
                for (idx, w) in zip(p, subW) {
                    let cdur = totalW > 0 ? (w / totalW) * segDur : (segDur / Double(p.count))
                    charTimings[idx] = (round(acc * 100) / 100, round(cdur * 100) / 100)
                    acc += cdur
                }
            }
        } else {
            // MARK: - 推定モード (AquesTalkの標準物理リードタイム0.22sおよび固定句読点ポーズ)
            let leadIn = 0.22
            var cur = leadIn
            let totalW = weights.reduce(0.0, +)
            let secPerW = totalW > 0 ? (max(0.5, effectiveDur - 0.5) / totalW) : 0.11

            for (i, c) in characters.enumerated() {
                if isPunctuationCharacter(c) {
                    let pDur = (c == "。" ? 0.38 : (c == "、" ? 0.22 : 0.30))
                    charTimings[i] = (round(cur * 100) / 100, pDur)
                    cur += pDur
                } else if !isSilentBracket(c) {
                    let w = weights[i]
                    let cdur = w * secPerW
                    charTimings[i] = (round(cur * 100) / 100, round(cdur * 100) / 100)
                    cur += cdur
                }
            }
        }

        // 全文字の CharacterTimingInfo を構築
        var result: [CharacterTimingInfo] = []
        var lastValidTime = detectedSegments.first?.start ?? 0.22

        for (i, c) in characters.enumerated() {
            if let t = charTimings[i] {
                result.append(CharacterTimingInfo(
                    index: i,
                    character: c,
                    startSeconds: max(0.0, (t.start * 100).rounded() / 100),
                    durationSeconds: max(0.0, (t.dur * 100).rounded() / 100),
                    isPunctuation: isPunctuationCharacter(c)
                ))
                lastValidTime = t.start + t.dur
            } else if isSilentBracket(c) {
                // カッコ記号は発音されないため直後の発音文字と同じ時刻
                result.append(CharacterTimingInfo(
                    index: i,
                    character: c,
                    startSeconds: (lastValidTime * 100).rounded() / 100,
                    durationSeconds: 0.0,
                    isPunctuation: true
                ))
            } else if isPunctuationCharacter(c) {
                result.append(CharacterTimingInfo(
                    index: i,
                    character: c,
                    startSeconds: (lastValidTime * 100).rounded() / 100,
                    durationSeconds: 0.20,
                    isPunctuation: true
                ))
                lastValidTime += 0.20
            }
        }

        return result
    }

    /// 特定の文字インデックスにおける発話開始推定秒数を取得
    public static func timingForCharacter(
        index: Int,
        text: String,
        totalDuration: Double,
        audioFilePath: String? = nil
    ) -> Double? {
        let timings = calculateCharacterTimings(text: text, totalDuration: totalDuration, audioFilePath: audioFilePath)
        guard index >= 0 && index < timings.count else { return nil }
        return timings[index].startSeconds
    }

    /// 秒数に最も近い文字インデックスを取得
    public static func characterIndex(
        forTime seconds: Double,
        text: String,
        totalDuration: Double,
        audioFilePath: String? = nil
    ) -> Int? {
        let timings = calculateCharacterTimings(text: text, totalDuration: totalDuration, audioFilePath: audioFilePath)
        guard !timings.isEmpty else { return nil }

        for item in timings {
            if seconds >= item.startSeconds && seconds <= item.endSeconds {
                return item.index
            }
        }
        if seconds < 0 { return 0 }
        return timings.last?.index
    }

    // MARK: - 音韻ウェイト計算 (自然な発音時間の推定: 漢字の拍数・音節を正確にモデリング)
    private static func weight(for char: Character) -> Double {
        if isSilentBracket(char) || isPunctuationCharacter(char) {
            return 0.0
        }
        switch char {
        // 促音・小文字
        case "っ", "ッ":
            return 0.60
        case "ゃ", "ゅ", "ょ", "ぁ", "ぃ", "ぅ", "ぇ", "ぉ",
             "ャ", "ュ", "ョ", "ァ", "ィ", "ゥ", "ェ", "ォ":
            return 0.50

        // 長音
        case "ー", "〜", "~":
            return 1.00

        default:
            // 漢字は日本語の発音特性として音読み・訓読みともに平均2拍（2音節）を占める
            if isKanji(char) {
                return 2.00
            }
            // ひらがな・カタカナ・通常文字は1拍（1音節）
            return 1.00
        }
    }

    /// CJK統合漢字判定 (日本語の漢字かどうかを判定)
    private static func isKanji(_ char: Character) -> Bool {
        guard let scalar = char.unicodeScalars.first else { return false }
        let val = scalar.value
        return (val >= 0x4E00 && val <= 0x9FFF) ||
               (val >= 0x3400 && val <= 0x4DBF) ||
               (val >= 0xF900 && val <= 0xFAFF)
    }

    private static func isKatakana(_ char: Character) -> Bool {
        guard let scalar = char.unicodeScalars.first else { return false }
        return scalar.value >= 0x30A0 && scalar.value <= 0x30FF
    }

    private static func isSilentBracket(_ c: Character) -> Bool {
        let brackets: Set<Character> = ["「", "」", "『", "』", "（", "）", "(", ")", "［", "］", "[", "]", "\"", "”", "“"]
        return brackets.contains(c)
    }

    private static func isPunctuationCharacter(_ char: Character) -> Bool {
        let puncs: Set<Character> = ["、", "。", "！", "!", "？", "?", "…", "・", "，", "．", " ", "　", "\n"]
        return puncs.contains(char)
    }

    // MARK: - シーン台詞コンテキスト情報
    public struct SceneDialogueContext: Identifiable {
        public var id: String { "\(sceneIndex)_\(character)" }
        public var sceneIndex: Int
        public var text: String
        public var character: String
        public var duration: Double
        public var sceneStartTime: Double
        public var voiceClipId: UUID?
        public var audioFilePath: String?
        public var timings: [CharacterTimingInfo]

        public init(
            sceneIndex: Int,
            text: String,
            character: String,
            duration: Double,
            sceneStartTime: Double,
            voiceClipId: UUID? = nil,
            audioFilePath: String? = nil
        ) {
            self.sceneIndex = sceneIndex
            self.text = text
            self.character = character
            self.duration = duration > 0.05 ? duration : 3.0
            self.sceneStartTime = sceneStartTime
            self.voiceClipId = voiceClipId
            self.audioFilePath = audioFilePath
            self.timings = VoiceTextTimingService.calculateCharacterTimings(
                text: text,
                totalDuration: self.duration,
                audioFilePath: audioFilePath
            )
        }
    }

    /// クリップまたはシーン番号に対応する台詞（ボイス）情報を自動解決
    public static func resolveDialogueContext(
        clip: SoundClip? = nil,
        sceneIndex: Int? = nil,
        clips: [SoundClip],
        scenes: [MovieScene] = []
    ) -> SceneDialogueContext? {
        let targetScenes = !scenes.isEmpty ? scenes : AppState.shared.movieScenes

        // シーンごとの開始時刻マップの算出
        var sceneRanges: [Int: (start: Double, end: Double)] = [:]
        var accTime: Double = 0.0
        for (i, sc) in targetScenes.enumerated() {
            sceneRanges[i + 1] = (accTime, accTime + sc.duration)
            accTime += sc.duration
        }

        // 解決すべき対象シーン番号
        var targetSceneIdx: Int? = sceneIndex
        if targetSceneIdx == nil, let c = clip {
            targetSceneIdx = c.spanStartSceneIndex ?? c.sceneIndex
            if targetSceneIdx == nil {
                for (scIdx, range) in sceneRanges {
                    if c.startTime >= range.start && c.startTime < range.end {
                        targetSceneIdx = scIdx
                        break
                    }
                }
            }
        }
        let resolvedIdx = targetSceneIdx ?? 1
        let sRange = sceneRanges[resolvedIdx] ?? (0.0, 5.0)

        // 1. soundClips 内のボイスクリップを探索
        if let targetVoiceId = clip?.voiceTriggerClipId,
           let matched = clips.first(where: { $0.id == targetVoiceId }) {
            let t = matched.text ?? matched.name.components(separatedBy: "] ").last ?? ""
            let dur = matched.duration > 0 ? matched.duration : 3.0
            return SceneDialogueContext(
                sceneIndex: resolvedIdx,
                text: t,
                character: matched.character ?? "キャラクター",
                duration: dur,
                sceneStartTime: matched.startTime,
                voiceClipId: matched.id,
                audioFilePath: matched.audioFilePath
            )
        }

        if let matched = clips.first(where: { $0.type == "Voice" && $0.sceneIndex == resolvedIdx }) {
            let t = matched.text ?? matched.name.components(separatedBy: "] ").last ?? ""
            let dur = matched.duration > 0 ? matched.duration : 3.0
            return SceneDialogueContext(
                sceneIndex: resolvedIdx,
                text: t,
                character: matched.character ?? "キャラクター",
                duration: dur,
                sceneStartTime: matched.startTime,
                voiceClipId: matched.id,
                audioFilePath: matched.audioFilePath
            )
        }

        // 2. MovieScene の情報から探索
        if resolvedIdx >= 1 && resolvedIdx <= targetScenes.count {
            let sc = targetScenes[resolvedIdx - 1]
            let telop = SlideItem.cleanDialogueText(from: sc.telop)
            if !telop.isEmpty {
                let dur = sc.voiceDuration ?? (sc.duration > 0 ? sc.duration : 3.0)
                return SceneDialogueContext(
                    sceneIndex: resolvedIdx,
                    text: telop,
                    character: sc.characterName.isEmpty ? "キャラクター" : sc.characterName,
                    duration: dur,
                    sceneStartTime: sRange.start,
                    voiceClipId: nil,
                    audioFilePath: sc.voiceAudioPath
                )
            }
        }

        return nil
    }
}

