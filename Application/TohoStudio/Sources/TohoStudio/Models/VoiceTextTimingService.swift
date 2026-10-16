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

/// キャラクターボイスのセリフテキストから、1文字ごとの発話タイミングを推定・算出するサービス
/// 句読点（、。）、促音（っ）、長音（ー）、感嘆符などの発音特性を重み付けして高精度にアライメント
public enum VoiceTextTimingService {

    /// セリフテキストと総音声長から、各文字の発話推定タイミングリストを生成
    public static func calculateCharacterTimings(text: String, totalDuration: Double) -> [CharacterTimingInfo] {
        let cleaned = SlideItem.cleanDialogueText(from: text)
        let effectiveText = cleaned.isEmpty ? text : cleaned
        let characters = Array(effectiveText)
        guard !characters.isEmpty, totalDuration > 0.05 else { return [] }

        // 各文字の音韻ウェイトを算出
        var weights: [Double] = []
        for char in characters {
            let w = weight(for: char)
            weights.append(w)
        }

        let totalWeight = weights.reduce(0.0, +)
        guard totalWeight > 0.001 else { return [] }

        var result: [CharacterTimingInfo] = []
        var accumulatedTime: Double = 0.0

        for (i, char) in characters.enumerated() {
            let charDur = (weights[i] / totalWeight) * totalDuration
            let isPunc = isPunctuationCharacter(char)

            result.append(CharacterTimingInfo(
                index: i,
                character: char,
                startSeconds: (accumulatedTime * 100).rounded() / 100,
                durationSeconds: (charDur * 100).rounded() / 100,
                isPunctuation: isPunc
            ))

            accumulatedTime += charDur
        }

        return result
    }

    /// 特定の文字インデックスにおける発話開始推定秒数を取得
    public static func timingForCharacter(index: Int, text: String, totalDuration: Double) -> Double? {
        let timings = calculateCharacterTimings(text: text, totalDuration: totalDuration)
        guard index >= 0 && index < timings.count else { return nil }
        return timings[index].startSeconds
    }

    /// 秒数に最も近い文字インデックスを取得
    public static func characterIndex(forTime seconds: Double, text: String, totalDuration: Double) -> Int? {
        let timings = calculateCharacterTimings(text: text, totalDuration: totalDuration)
        guard !timings.isEmpty else { return nil }

        for item in timings {
            if seconds >= item.startSeconds && seconds <= item.endSeconds {
                return item.index
            }
        }
        if seconds < 0 { return 0 }
        return timings.last?.index
    }

    // MARK: - 音韻ウェイト計算 (自然な発音時間の推定)
    private static func weight(for char: Character) -> Double {
        switch char {
        // 促音・小文字
        case "っ", "ッ":
            return 0.55
        case "ゃ", "ゅ", "ょ", "ぁ", "ぃ", "ぅ", "ぇ", "ぉ",
             "ャ", "ュ", "ョ", "ァ", "ィ", "ゥ", "ェ", "ォ":
            return 0.45

        // 長音
        case "ー", "〜", "~":
            return 1.15

        // 句読点・ポーズ
        case "、", ",":
            return 1.40
        case "。", ".":
            return 1.80
        case "！", "!", "？", "?":
            return 1.50
        case "…", "・":
            return 1.20
        case " ", "　":
            return 0.70

        // 漢字・ひらがな・カタカナ・英数字
        default:
            return 1.00
        }
    }

    private static func isPunctuationCharacter(_ char: Character) -> Bool {
        let puncs: Set<Character> = ["、", "。", "！", "!", "？", "?", "…", "・", "，", "．", " ", "　"]
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
        public var timings: [CharacterTimingInfo]

        public init(
            sceneIndex: Int,
            text: String,
            character: String,
            duration: Double,
            sceneStartTime: Double,
            voiceClipId: UUID? = nil
        ) {
            self.sceneIndex = sceneIndex
            self.text = text
            self.character = character
            self.duration = duration > 0.05 ? duration : 3.0
            self.sceneStartTime = sceneStartTime
            self.voiceClipId = voiceClipId
            self.timings = VoiceTextTimingService.calculateCharacterTimings(text: text, totalDuration: self.duration)
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
                voiceClipId: matched.id
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
                voiceClipId: matched.id
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
                    voiceClipId: nil
                )
            }
        }

        return nil
    }
}
