import Foundation
import SwiftUI
import AVFoundation

// MARK: - Batch Voice Item Model
public struct BatchVoiceItem: Identifiable, Equatable {
    public var id: UUID = UUID()
    public var slideIndex: Int
    public var slideTitle: String
    public var slideType: String = "content"
    public var characterName: String
    public var text: String
    public var selectedTemplateId: UUID? = nil
    public var templateName: String = "標準"
    public var voiceType: VoiceType
    public var speed: Int = 100
    public var pitch: Int = 100
    public var effect: AudioEffectType = .none
    public var quality: AudioQualitySetting = .enhanced
    public var isSkipped: Bool = false
    public var skipReason: String? = nil
    public var isGenerated: Bool = false
    public var generatedWavData: Data? = nil
    public var generatedWavURL: URL? = nil
    public var audioDuration: Double = 3.0
    public var waveformPoints: [Float] = []

    public var isTitleOrSectionHeader: Bool {
        return slideType == "title" || slideType == "sectionHeader" || (skipReason?.contains("タイトル") == true || skipReason?.contains("セクション") == true)
    }

    public init(
        id: UUID = UUID(),
        slideIndex: Int,
        slideTitle: String,
        slideType: String = "content",
        characterName: String,
        text: String,
        selectedTemplateId: UUID? = nil,
        templateName: String = "標準",
        voiceType: VoiceType,
        speed: Int = 100,
        pitch: Int = 100,
        effect: AudioEffectType = .none,
        quality: AudioQualitySetting = .enhanced,
        isSkipped: Bool = false,
        skipReason: String? = nil
    ) {
        self.id = id
        self.slideIndex = slideIndex
        self.slideTitle = slideTitle
        self.slideType = slideType
        self.characterName = characterName
        self.text = text
        self.selectedTemplateId = selectedTemplateId
        self.templateName = templateName
        self.voiceType = voiceType
        self.speed = speed
        self.pitch = pitch
        self.effect = effect
        self.quality = quality
        self.isSkipped = isSkipped
        self.skipReason = skipReason
    }
}

// MARK: - Speaker Template Mapping Model
public struct SpeakerTemplateMapping: Identifiable, Equatable {
    public var id: String { characterName }
    public var characterName: String
    public var templateId: UUID?
    public var templateName: String
    public var voiceType: VoiceType
    public var speed: Int
    public var pitch: Int
    public var isSkipped: Bool = false
    public var isCustomized: Bool = false

    public init(
        characterName: String,
        templateId: UUID? = nil,
        templateName: String = "標準",
        voiceType: VoiceType = .f1,
        speed: Int = 100,
        pitch: Int = 100,
        isSkipped: Bool = false,
        isCustomized: Bool = false
    ) {
        self.characterName = characterName
        self.templateId = templateId
        self.templateName = templateName
        self.voiceType = voiceType
        self.speed = speed
        self.pitch = pitch
        self.isSkipped = isSkipped
        self.isCustomized = isCustomized
    }
}

// MARK: - Slide Voice Batch Service
public final class SlideVoiceBatchService: ObservableObject {
    public static let shared = SlideVoiceBatchService()

    @Published public var isGenerating: Bool = false
    @Published public var progressCurrent: Int = 0
    @Published public var progressTotal: Int = 0
    @Published public var currentProcessingMessage: String = ""
    @Published public var lastBatchItems: [BatchVoiceItem] = []

    private init() {}

    /// スライド配列からセリフと話者を抽出して BatchVoiceItem の配列を作成
    public func extractBatchItems(
        from slides: [SlideItem],
        defaultEffect: AudioEffectType = .none,
        defaultQuality: AudioQualitySetting = .enhanced
    ) -> [BatchVoiceItem] {
        var items: [BatchVoiceItem] = []
        let appState = AppState.shared

        let charDictionary: [String: String] = [
            "霊夢": "博麗霊夢", "魔理沙": "霧雨魔理沙", "咲夜": "十六夜咲夜", "妖夢": "魂魄妖夢",
            "幽々子": "西行寺幽々子", "紫": "八雲紫", "パチュリー": "パチュリー・ノーレッジ",
            "フラン": "フランドール・スカーレット", "レミリア": "レミリア・スカーレット",
            "早苗": "東風谷早苗", "さとり": "古明地さとり", "こいし": "古明地こいし",
            "アリス": "アリス・マーガトロイド", "チルノ": "チルノ", "文": "射命丸文"
        ]

        for slide in slides {
            // 1. 話者抽出
            var speaker = slide.characterName
            if let noteBracketSpeaker = SlideItem.extractSpeakerFromBrackets(from: slide.rawPresenterNote ?? slide.presenterNote), !noteBracketSpeaker.isEmpty {
                speaker = noteBracketSpeaker
            } else if let telopBracketSpeaker = SlideItem.extractSpeakerFromBrackets(from: slide.telop), !telopBracketSpeaker.isEmpty {
                speaker = telopBracketSpeaker
            }

            if speaker.isEmpty || speaker == "ナレーション" || speaker == "なし" {
                speaker = "博麗霊夢"
            }
            if let mapped = charDictionary[speaker] {
                speaker = mapped
            }

            // 2. セリフ抽出 (ノート本文優先、なければテロップ)
            var speechText = slide.telop
            if !slide.displayPresenterNote.isEmpty && slide.displayPresenterNote != slide.title {
                speechText = slide.displayPresenterNote
            }
            speechText = SlideItem.cleanDialogueText(from: speechText).trimmingCharacters(in: .whitespacesAndNewlines)

            // 空白セリフの場合はタイトルまたはフォールバック
            if speechText.isEmpty {
                speechText = slide.title.isEmpty ? "第\(slide.slideIndex)スライド" : slide.title
            }

            // 3. 話者に対応するVoiceTemplateを検索 (完全一致または部分一致)
            let matchedTemplate = appState.voiceTemplates.first(where: {
                $0.characterName == speaker || $0.name.contains(speaker)
            })

            let voiceType: VoiceType
            let speed: Int
            let pitch: Int
            let tplId: UUID?
            let tplName: String

            if let tpl = matchedTemplate {
                voiceType = tpl.voiceType
                speed = tpl.speed
                pitch = tpl.pitch
                tplId = tpl.id
                tplName = tpl.name
            } else {
                let preset = AquesTalkBridge.shared.characterPreset(for: speaker)
                voiceType = preset.voice
                speed = preset.speed
                pitch = preset.pitch
                tplId = nil
                tplName = "\(speaker)標準 (\(preset.voice.rawValue))"
            }

            // セクション見出しとタイトルスライドは音声を必ずスキップ
            let isHeaderOrTitle = slide.isTitleOrSectionHeader
            let skipReason: String? = isHeaderOrTitle ? ((slide.slideType == "title" || slide.slideIndex == 1) ? "タイトルスライド (音声スキップ)" : "セクション見出し (音声スキップ)") : nil

            let item = BatchVoiceItem(
                slideIndex: slide.slideIndex,
                slideTitle: slide.title.isEmpty ? "スライド #\(slide.slideIndex)" : slide.title,
                slideType: slide.slideType,
                characterName: speaker,
                text: speechText,
                selectedTemplateId: tplId,
                templateName: tplName,
                voiceType: voiceType,
                speed: speed,
                pitch: pitch,
                effect: defaultEffect,
                quality: defaultQuality,
                isSkipped: isHeaderOrTitle,
                skipReason: skipReason
            )
            items.append(item)
        }

        return items
    }

    /// 特定の話者の全スライドに対してテンプレートを一括適用
    public func applyTemplateToSpeaker(
        speaker: String,
        template: VoiceTemplate,
        items: inout [BatchVoiceItem]
    ) {
        for i in 0..<items.count {
            if items[i].characterName == speaker {
                items[i].selectedTemplateId = template.id
                items[i].templateName = template.name
                items[i].voiceType = template.voiceType
                items[i].speed = template.speed
                items[i].pitch = template.pitch
            }
        }
    }

    /// スライドファイル (.tspm / .key / .json) からセリフと話者を抽出
    public func extractBatchItemsFromFile(
        url: URL,
        defaultEffect: AudioEffectType = .none,
        defaultQuality: AudioQualitySetting = .enhanced,
        completion: @escaping ([BatchVoiceItem]) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let loadedSlides = SlideRecognitionService.shared.extractSlidesFromPath(filePath: url.path)
            let items = self.extractBatchItems(from: loadedSlides, defaultEffect: defaultEffect, defaultQuality: defaultQuality)
            DispatchQueue.main.async {
                completion(items)
            }
        }
    }

    /// 全スライドの音声を一括生成 (非同期)
    public func synthesizeAll(
        items: [BatchVoiceItem],
        globalEffect: AudioEffectType? = nil,
        globalQuality: AudioQualitySetting? = nil,
        onProgress: ((Int, Int, BatchVoiceItem) -> Void)? = nil,
        completion: @escaping ([BatchVoiceItem]) -> Void
    ) {
        guard !items.isEmpty else {
            completion([])
            return
        }

        DispatchQueue.main.async {
            self.isGenerating = true
            self.progressTotal = items.count
            self.progressCurrent = 0
            self.currentProcessingMessage = "音声生成の準備中..."
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            var updatedItems = items

            // プロジェクト保存先フォルダを用意
            let audioDir = self.getAudioStorageDirectory()

            for i in 0..<updatedItems.count {
                var item = updatedItems[i]

                // スキップ対象は音声生成を行わない
                if item.isSkipped {
                    DispatchQueue.main.async {
                        self.progressCurrent = i + 1
                        self.currentProcessingMessage = "スライド \(item.slideIndex)/\(items.count): スキップ [\(item.characterName)]"
                        onProgress?(i + 1, items.count, item)
                    }
                    updatedItems[i] = item
                    continue
                }

                let effect = globalEffect ?? item.effect
                let quality = globalQuality ?? item.quality

                DispatchQueue.main.async {
                    self.progressCurrent = i + 1
                    self.currentProcessingMessage = "スライド \(item.slideIndex)/\(items.count): \(item.characterName) 「\(item.text.prefix(20))...」 を生成中"
                    onProgress?(i + 1, items.count, item)
                }

                // AquesTalkで音声を合成 (音質改善 & エフェクト適用)
                let wavData = AquesTalkBridge.shared.synthesizeToWavData(
                    text: item.text,
                    speed: item.speed,
                    voice: item.voiceType,
                    quality: quality,
                    effect: effect
                )

                if let data = wavData {
                    item.generatedWavData = data
                    item.isGenerated = true

                    // ディスクに保存
                    let safeChar = item.characterName.replacingOccurrences(of: "/", with: "_")
                    let fileName = String(format: "Slide_%03d_%@.wav", item.slideIndex, safeChar)
                    let fileURL = audioDir.appendingPathComponent(fileName)
                    try? data.write(to: fileURL)
                    item.generatedWavURL = fileURL

                    // 再生時間・波形データ推定 (WAVヘッダ情報またはサンプル数より)
                    let duration = self.estimateWavDuration(data: data)
                    item.audioDuration = max(1.5, duration)
                    item.waveformPoints = self.generateWaveformPoints(from: data, count: 24)
                } else {
                    item.audioDuration = max(2.0, Double(item.text.count) * 0.25)
                    item.waveformPoints = (0..<24).map { _ in Float.random(in: 0.2...0.8) }
                }

                item.effect = effect
                item.quality = quality
                updatedItems[i] = item

                // UI更新と軽微な間隔
                usleep(50000) // 50ms
            }

            DispatchQueue.main.async {
                self.isGenerating = false
                self.lastBatchItems = updatedItems
                let generatedCount = updatedItems.filter { $0.isGenerated && !$0.isSkipped }.count
                self.currentProcessingMessage = "全 \(items.count) 件中 \(generatedCount) スライドの音声を生成しました！"
                completion(updatedItems)
            }
        }
    }

    /// 生成した音声をサウンドメーカーのタイムライン（SoundClip）に一括配置
    public func applyToSoundMakerTimeline(items: [BatchVoiceItem]) {
        let appState = AppState.shared

        // 話者ごとのトラックがなければ自動追加
        ensureTracksExist(for: items.filter { !$0.isSkipped })

        // 既存の音声クリップ（Voice）をクリアまたは置き換え
        appState.soundClips.removeAll(where: { $0.type == "Voice" })

        // スライド情報からMovieScene一覧を同期構築（シーンごとの時間枠を正確に設定）
        var updatedScenes: [MovieScene] = []
        var currentPosition: Double = 0.0

        for item in items {
            // シーンの長さ決定: 音声がある場合は 音声長 + 0.6s、スキップの場合は 3.0s
            let sceneDuration = item.isSkipped ? 3.0 : max(2.0, item.audioDuration + 0.6)

            // MovieScene の生成/更新
            let matchedSlide = appState.slides.first(where: { $0.slideIndex == item.slideIndex })
            var rawTitle = matchedSlide?.title.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if rawTitle.isEmpty {
                rawTitle = item.slideTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            while rawTitle.hasPrefix("シーン \(item.slideIndex):") || rawTitle.hasPrefix("シーン\(item.slideIndex):") {
                let prefixLen = rawTitle.hasPrefix("シーン \(item.slideIndex):") ? ("シーン \(item.slideIndex):").count : ("シーン\(item.slideIndex):").count
                rawTitle = String(rawTitle.dropFirst(prefixLen)).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            let finalTitle: String
            if rawTitle.isEmpty || rawTitle == "シーン \(item.slideIndex)" || rawTitle == "スライド #\(item.slideIndex)" {
                finalTitle = "シーン \(item.slideIndex)"
            } else {
                finalTitle = "シーン \(item.slideIndex): \(rawTitle)"
            }

            let telopText = matchedSlide?.telop.isEmpty == false ? matchedSlide!.telop : item.text

            let scene = MovieScene(
                title: finalTitle,
                duration: sceneDuration,
                slideTitle: "スライド #\(item.slideIndex)",
                backgroundName: matchedSlide?.backgroundName ?? "神社",
                characterName: item.characterName,
                telop: telopText,
                audioTrack: item.isSkipped ? nil : "track_voice"
            )
            updatedScenes.append(scene)

            // スキップ対象でなければ音声クリップを作成して配置
            if !item.isSkipped, let track = findTrack(for: item.characterName) {
                let clipName = "[\(item.characterName)] \(item.text)"
                let phonetic = AquesTalkBridge.shared.convertToVoiceSymbol(text: item.text)

                let clip = SoundClip(
                    name: clipName,
                    type: "Voice",
                    character: item.characterName,
                    text: item.text,
                    voiceSymbol: phonetic,
                    duration: item.audioDuration,
                    volume: 1.0,
                    speed: item.speed,
                    startTime: currentPosition,
                    trackId: track.id,
                    pan: track.pan,
                    colorHex: track.colorHex,
                    waveformPoints: item.waveformPoints,
                    sceneIndex: item.slideIndex,
                    audioFilePath: item.generatedWavURL?.path,
                    voiceType: item.voiceType,
                    pitch: item.pitch
                )
                appState.soundClips.append(clip)
            }

            // 次のシーンの開始位置
            currentPosition += sceneDuration
        }

        if !updatedScenes.isEmpty {
            appState.movieScenes = updatedScenes
        }

        // BGMトラックがなければデフォルトBGMクリップも用意（未設定の場合）
        if !appState.soundClips.contains(where: { $0.type == "BGM" }) && currentPosition > 0 {
            let bgmClip = SoundClip(
                name: "BGM: 少女綺想曲 〜 Dream Battle",
                type: "BGM",
                duration: currentPosition,
                volume: 0.6,
                startTime: 0.0,
                trackId: "track_bgm",
                colorHex: "#9B59B6",
                waveformPoints: [0.5, 0.6, 0.7, 0.55, 0.8, 0.65, 0.7, 0.6, 0.75, 0.6],
                spanStartSceneIndex: 1,
                spanEndSceneIndex: items.count,
                fadeInDuration: 1.5,
                fadeOutDuration: 2.0,
                isLooping: true
            )
            appState.soundClips.append(bgmClip)
        }

        appState.log("全スライド (\(items.count) 件) の音声をシーンごとにタイムラインへ配置しました (総尺: \(String(format: "%.1f", currentPosition))秒)")
    }

    // MARK: - Helpers
    private func getAudioStorageDirectory() -> URL {
        let fileManager = FileManager.default
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let audioDir = appSupport.appendingPathComponent("TohoStudio/GeneratedAudio", isDirectory: true)
        if !fileManager.fileExists(atPath: audioDir.path) {
            try? fileManager.createDirectory(at: audioDir, withIntermediateDirectories: true)
        }
        return audioDir
    }

    private func estimateWavDuration(data: Data) -> Double {
        guard data.count > 44 else { return 2.0 }
        // 簡易サンプリングレート取得
        let sampleRate = Double(data.withUnsafeBytes { $0.load(fromByteOffset: 24, as: UInt32.self) })
        let channels = Double(data.withUnsafeBytes { $0.load(fromByteOffset: 22, as: UInt16.self) })
        let bitsPerSample = Double(data.withUnsafeBytes { $0.load(fromByteOffset: 34, as: UInt16.self) })

        if sampleRate > 0 && channels > 0 && bitsPerSample > 0 {
            let bytesPerSec = sampleRate * channels * (bitsPerSample / 8.0)
            let pcmBytes = Double(data.count - 44)
            return pcmBytes / bytesPerSec
        }
        return 2.5
    }

    private func generateWaveformPoints(from wavData: Data, count: Int) -> [Float] {
        guard wavData.count > 44 else {
            return (0..<count).map { _ in Float.random(in: 0.2...0.9) }
        }

        let pcmData = wavData.subdata(in: 44..<wavData.count)
        let sampleCount = pcmData.count / 2
        guard sampleCount > count else {
            return (0..<count).map { _ in Float.random(in: 0.2...0.9) }
        }

        var points = [Float](repeating: 0.2, count: count)
        let step = sampleCount / count

        pcmData.withUnsafeBytes { rawPtr in
            let int16Ptr = rawPtr.bindMemory(to: Int16.self)
            for i in 0..<count {
                var maxAmp: Float = 0.0
                let start = i * step
                let end = min(sampleCount, (i + 1) * step)
                for s in start..<end {
                    let amp = abs(Float(int16Ptr[s])) / 32768.0
                    if amp > maxAmp { maxAmp = amp }
                }
                points[i] = max(0.12, min(1.0, maxAmp * 1.3))
            }
        }
        return points
    }

    private func ensureTracksExist(for items: [BatchVoiceItem]) {
        let appState = AppState.shared
        let distinctCharacters = Set(items.map { $0.characterName })

        // 既存のトラック名
        let existingCharTracks = Set(appState.audioTracks.compactMap { $0.characterName })

        let colorPalette = ["#E74C3C", "#F1C40F", "#3498DB", "#2ECC71", "#9B59B6", "#E67E22", "#1ABC9C", "#E91E63"]
        var colorIdx = 0

        for char in distinctCharacters {
            if !existingCharTracks.contains(char) {
                let trackId = "track_voice_\(char.lowercased().filter { $0.isASCII && $0.isLetter })_\(UUID().uuidString.prefix(4))"
                let color = colorPalette[colorIdx % colorPalette.count]
                colorIdx += 1

                let newTrack = AudioTrack(
                    id: trackId,
                    name: "\(char) (Voice)",
                    type: "voice",
                    icon: "waveform",
                    colorHex: color,
                    volume: 1.0,
                    pan: (colorIdx % 2 == 0) ? 0.2 : -0.2,
                    characterName: char
                )
                appState.audioTracks.append(newTrack)
            }
        }
    }

    private func findTrack(for characterName: String) -> AudioTrack? {
        let appState = AppState.shared
        // キャラクター名一致
        if let match = appState.audioTracks.first(where: { $0.characterName == characterName }) {
            return match
        }
        // Voiceタイプ
        if let voiceTrack = appState.audioTracks.first(where: { $0.type == "voice" }) {
            return voiceTrack
        }
        return appState.audioTracks.first
    }
}
