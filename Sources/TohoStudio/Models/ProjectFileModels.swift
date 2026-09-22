import Foundation
import SwiftUI
import AppKit
import AVFoundation

// MARK: - 0. スライド上のオブジェクト（テキスト・図形など）
public struct SlideObjectData: Codable, Identifiable {
    public var id: UUID
    public var type: String // "text", "shape", "image"
    public var text: String?
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var animation: String?
    
    public init(id: UUID = UUID(), type: String = "shape", text: String? = nil, x: Double = 0, y: Double = 0, width: Double = 0, height: Double = 0, animation: String? = nil) {
        self.id = id
        self.type = type
        self.text = text
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.animation = animation
    }
}

// MARK: - 1. ムービーメーカー用プロジェクトデータ (.tsvm / .ymmp)
public struct MovieSceneItemData: Codable, Identifiable {
    public var id: UUID
    public var title: String
    public var duration: Double
    public var imagePath: String?
    public var scriptText: String?
    public var speakerCharacter: String?
    public var animationMeta: String?
    public var animationDuration: Double?
    public var audioPath: String?
    public var audioDuration: Double?
    public var audioFileName: String?
    
    // 8段階順序レイヤー対応
    public var backgroundImagePath: String?       // 1. 背景画像
    public var backgroundAnimation: String?       // 2. 背景画像のアニメーション
    public var characterImagePath: String?        // 3. キャラクター画像 ("/Volumes/ZSSD/動画用")
    public var characterAnimation: String?        // 4. キャラクター画像のアニメーション
    public var objectsData: [SlideObjectData]?    // 5. オブジェクト（テキストや図形など）
    public var objectAnimation: String?           // 6. オブジェクトのアニメーション
    public var telopText: String?                 // 7. テロップとノートにあるテキスト
    public var slideTransitionEffect: String?     // 8. スライドトランジション（効果名）
    public var slideTransitionDuration: Double?   // 8. スライドトランジション（秒数）
    
    enum CodingKeys: String, CodingKey {
        case id, title, duration, imagePath, scriptText, speakerCharacter, animationMeta, animationDuration, audioPath, audioDuration, audioFileName
        case backgroundImagePath, backgroundAnimation, characterImagePath, characterAnimation, objectsData, objectAnimation, telopText, slideTransitionEffect, slideTransitionDuration
    }
    
    public init(id: UUID = UUID(),
                title: String,
                duration: Double,
                imagePath: String? = nil,
                scriptText: String? = nil,
                speakerCharacter: String? = nil,
                animationMeta: String? = nil,
                animationDuration: Double? = nil,
                audioPath: String? = nil,
                audioDuration: Double? = nil,
                audioFileName: String? = nil,
                backgroundImagePath: String? = nil,
                backgroundAnimation: String? = nil,
                characterImagePath: String? = nil,
                characterAnimation: String? = nil,
                objectsData: [SlideObjectData]? = nil,
                objectAnimation: String? = nil,
                telopText: String? = nil,
                slideTransitionEffect: String? = nil,
                slideTransitionDuration: Double? = nil) {
        self.id = id
        self.title = title
        self.duration = duration
        self.imagePath = imagePath
        self.scriptText = scriptText
        self.speakerCharacter = speakerCharacter
        self.animationMeta = animationMeta
        self.animationDuration = animationDuration
        self.audioPath = audioPath
        self.audioDuration = audioDuration
        self.audioFileName = audioFileName
        self.backgroundImagePath = backgroundImagePath
        self.backgroundAnimation = backgroundAnimation
        self.characterImagePath = characterImagePath
        self.characterAnimation = characterAnimation
        self.objectsData = objectsData
        self.objectAnimation = objectAnimation
        self.telopText = telopText
        self.slideTransitionEffect = slideTransitionEffect
        self.slideTransitionDuration = slideTransitionDuration
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "スライド"
        duration = try c.decodeIfPresent(Double.self, forKey: .duration) ?? 10.0
        imagePath = try c.decodeIfPresent(String.self, forKey: .imagePath)
        scriptText = try c.decodeIfPresent(String.self, forKey: .scriptText)
        speakerCharacter = try c.decodeIfPresent(String.self, forKey: .speakerCharacter)
        animationMeta = try c.decodeIfPresent(String.self, forKey: .animationMeta)
        let decodedAnimDur = try c.decodeIfPresent(Double.self, forKey: .animationDuration)
        if let decodedAnimDur = decodedAnimDur {
            animationDuration = decodedAnimDur
        } else if let meta = animationMeta {
            animationDuration = FileFormatParser.extractDurationFromMeta(meta)
        } else {
            animationDuration = nil
        }
        audioPath = try c.decodeIfPresent(String.self, forKey: .audioPath)
        audioDuration = try c.decodeIfPresent(Double.self, forKey: .audioDuration)
        audioFileName = try c.decodeIfPresent(String.self, forKey: .audioFileName)
        
        backgroundImagePath = try c.decodeIfPresent(String.self, forKey: .backgroundImagePath)
        backgroundAnimation = try c.decodeIfPresent(String.self, forKey: .backgroundAnimation)
        characterImagePath = try c.decodeIfPresent(String.self, forKey: .characterImagePath)
        characterAnimation = try c.decodeIfPresent(String.self, forKey: .characterAnimation)
        objectsData = try c.decodeIfPresent([SlideObjectData].self, forKey: .objectsData)
        objectAnimation = try c.decodeIfPresent(String.self, forKey: .objectAnimation)
        telopText = try c.decodeIfPresent(String.self, forKey: .telopText)
        slideTransitionEffect = try c.decodeIfPresent(String.self, forKey: .slideTransitionEffect)
        slideTransitionDuration = try c.decodeIfPresent(Double.self, forKey: .slideTransitionDuration)
    }
}

// MARK: - 1.2 ムービーメーカー用分離音声トラックデータ
public struct MovieAudioItemData: Codable, Identifiable {
    public var id: UUID
    public var name: String
    public var audioPath: String
    public var audioFileName: String
    public var duration: Double
    public var startTime: Double
    public var targetSceneIndex: Int?
    public var targetSceneId: UUID?
    public var volume: Double
    public var playbackRate: Double
    public var speakerCharacter: String?
    public var isMuted: Bool
    
    /// トラック種類: "voice"（セリフ音声）, "bgm"（背景音楽）, "se"（効果音）
    public var trackType: String
    /// 逆再生フラグ (デフォルト: false)
    public var isReversed: Bool
    /// ループ再生フラグ (デフォルト: false)
    public var loops: Bool
    /// 開始シーンインデックス（0始まり、未設定時はtargetSceneIndexと一致）
    public var startSceneIndex: Int?
    /// 終了シーンインデックス（0始まり、未設定時はstartSceneIndexまたはtargetSceneIndexと一致）
    public var endSceneIndex: Int?
    
    enum CodingKeys: String, CodingKey {
        case id, name, audioPath, audioFileName, duration, startTime
        case targetSceneIndex, targetSceneId, volume, playbackRate, speakerCharacter, isMuted
        case trackType, isReversed, loops, startSceneIndex, endSceneIndex
    }
    
    public init(
        id: UUID = UUID(),
        name: String,
        audioPath: String,
        audioFileName: String,
        duration: Double,
        startTime: Double = 0.0,
        targetSceneIndex: Int? = nil,
        targetSceneId: UUID? = nil,
        volume: Double = 1.0,
        playbackRate: Double = 1.0,
        speakerCharacter: String? = nil,
        isMuted: Bool = false,
        trackType: String = "voice",
        isReversed: Bool = false,
        loops: Bool = false,
        startSceneIndex: Int? = nil,
        endSceneIndex: Int? = nil
    ) {
        self.id = id
        self.name = name
        self.audioPath = audioPath
        self.audioFileName = audioFileName
        self.duration = duration
        self.startTime = startTime
        self.targetSceneIndex = targetSceneIndex
        self.targetSceneId = targetSceneId
        self.volume = volume
        self.playbackRate = playbackRate
        self.speakerCharacter = speakerCharacter
        self.isMuted = isMuted
        self.trackType = trackType
        self.isReversed = isReversed
        self.loops = loops
        self.startSceneIndex = startSceneIndex ?? targetSceneIndex
        self.endSceneIndex = endSceneIndex ?? startSceneIndex ?? targetSceneIndex
    }
    
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        audioPath = try c.decode(String.self, forKey: .audioPath)
        audioFileName = try c.decode(String.self, forKey: .audioFileName)
        duration = try c.decode(Double.self, forKey: .duration)
        startTime = try c.decodeIfPresent(Double.self, forKey: .startTime) ?? 0.0
        targetSceneIndex = try c.decodeIfPresent(Int.self, forKey: .targetSceneIndex)
        targetSceneId = try c.decodeIfPresent(UUID.self, forKey: .targetSceneId)
        volume = try c.decodeIfPresent(Double.self, forKey: .volume) ?? 1.0
        playbackRate = try c.decodeIfPresent(Double.self, forKey: .playbackRate) ?? 1.0
        speakerCharacter = try c.decodeIfPresent(String.self, forKey: .speakerCharacter)
        isMuted = try c.decodeIfPresent(Bool.self, forKey: .isMuted) ?? false
        trackType = try c.decodeIfPresent(String.self, forKey: .trackType) ?? "voice"
        isReversed = try c.decodeIfPresent(Bool.self, forKey: .isReversed) ?? false
        loops = try c.decodeIfPresent(Bool.self, forKey: .loops) ?? false
        startSceneIndex = try c.decodeIfPresent(Int.self, forKey: .startSceneIndex) ?? targetSceneIndex
        endSceneIndex = try c.decodeIfPresent(Int.self, forKey: .endSceneIndex) ?? startSceneIndex ?? targetSceneIndex
    }
}

public struct MovieProjectData: Codable {
    public var projectName: String
    public var duration: Double
    public var scenes: [String]
    public var fps: Double
    public var resolution: String
    public var notes: String?
    public var scenesData: [MovieSceneItemData]?
    public var audioItems: [MovieAudioItemData]?
    /// 関連付けられたサウンドメーカープロジェクト名（例: "交換夫婦（21.22話目）叡智シーンのみ.tssm"）
    public var soundProjectName: String?
    
    public init(projectName: String = "新規プロジェクト.tsvm",
                duration: Double = 120.0,
                scenes: [String] = ["第1幕: 神社のお茶会", "第2幕: 魔理沙の急報", "第3幕: 異変の幕開け", "第4幕: エンディング"],
                fps: Double = 60.0,
                resolution: String = "1920x1080",
                notes: String? = nil,
                scenesData: [MovieSceneItemData]? = nil,
                audioItems: [MovieAudioItemData]? = nil,
                soundProjectName: String? = nil) {
        self.projectName = projectName
        self.duration = duration
        self.scenes = scenes
        self.fps = fps
        self.resolution = resolution
        self.notes = notes
        self.scenesData = scenesData
        self.audioItems = audioItems
        self.soundProjectName = soundProjectName
    }
}


// MARK: - 2. キャラクターメーカー用プロジェクトデータ (.tscm)
public struct CharacterProjectData: Codable {
    public var projectName: String
    public var character: String
    public var eye: String
    public var mouth: String
    public var eyebrow: String
    public var hasSweat: Bool
    public var zoomScale: Double
    public var telopText: String
    public var backgroundType: String
    public var imagePath: String?
    
    public init(projectName: String = "博麗霊夢_立ち絵プロジェクト.tscm",
                character: String = "博麗霊夢",
                eye: String = "普通",
                mouth: String = "笑顔",
                eyebrow: String = "標準",
                hasSweat: Bool = false,
                zoomScale: Double = 1.0,
                telopText: String = "ゆっくりしていってね！",
                backgroundType: String = "博麗神社(昼)",
                imagePath: String? = nil) {
        self.projectName = projectName
        self.character = character
        self.eye = eye
        self.mouth = mouth
        self.eyebrow = eyebrow
        self.hasSweat = hasSweat
        self.zoomScale = zoomScale
        self.telopText = telopText
        self.backgroundType = backgroundType
        self.imagePath = imagePath
    }
}

// MARK: - 3. サウンドメーカー用プロジェクトデータ (.tssm)
public struct SoundProjectData: Codable {
    public var projectName: String
    public var speechInputText: String
    public var phoneticSymbolText: String
    public var conversionMode: String
    public var selectedVoiceCharacter: String
    public var speedRate: Double
    public var pitchRate: Double
    public var volume: Double
    public var customDialect: String
    public var customTone: String
    public var audioFileName: String?
    
    // スライド別セリフ音声データ（保存用）
    public struct SavedSlideSpeech: Codable {
        public var slideIndex: Int
        public var title: String
        public var speaker: String
        public var scriptText: String
        public var phoneticText: String
        public var speed: Int
        public var pitch: Int
        public var durationSeconds: Double
        /// 生成済みWAV音声バイナリ（Base64エンコードしてJSON保存）
        public var wavData: Data?
        /// AquesTalkボイスタイプ（rawValue文字列）
        public var voiceTypeRaw: String?
        
        public init(slideIndex: Int, title: String, speaker: String, scriptText: String, phoneticText: String, speed: Int, pitch: Int, durationSeconds: Double, wavData: Data? = nil, voiceTypeRaw: String? = nil) {
            self.slideIndex = slideIndex
            self.title = title
            self.speaker = speaker
            self.scriptText = scriptText
            self.phoneticText = phoneticText
            self.speed = speed
            self.pitch = pitch
            self.durationSeconds = durationSeconds
            self.wavData = wavData
            self.voiceTypeRaw = voiceTypeRaw
        }
    }
    // シーン（スライド）別BGM・効果音設定
    // startScene〜endScene の範囲にまたがって流れる音源を表す
    public struct SceneAudioItem: Codable, Identifiable {
        public var id: UUID
        /// 表示名（例: "オープニングBGM", "場面転換SE"）
        public var name: String
        /// "bgm" または "se"
        public var trackType: String
        /// 音源ファイルパス（nil の場合は未割り当て）
        public var audioFilePath: String?
        /// 音量 (0.0 〜 1.0)
        public var volume: Double
        /// 開始シーン番号（slideIndex 対応、1始まり）
        public var startScene: Int
        /// 終了シーン番号（startScene と同値なら1シーンのみ）
        public var endScene: Int
        /// ループ再生
        public var loops: Bool
        /// 再生速度 (0.25 〜 3.0, デフォルト: 1.0)
        public var speedRate: Double? = 1.0
        /// 逆再生フラグ (デフォルト: false)
        public var isReversed: Bool? = false
        
        public init(
            id: UUID = UUID(),
            name: String,
            trackType: String = "bgm",
            audioFilePath: String? = nil,
            volume: Double = 0.7,
            startScene: Int = 1,
            endScene: Int = 1,
            loops: Bool = false,
            speedRate: Double = 1.0,
            isReversed: Bool = false
        ) {
            self.id = id
            self.name = name
            self.trackType = trackType
            self.audioFilePath = audioFilePath
            self.volume = volume
            self.startScene = startScene
            self.endScene = endScene
            self.loops = loops
            self.speedRate = speedRate
            self.isReversed = isReversed
        }
    }
    
    // マルチトラック音声スロット（複数音同時割り当て用）
    public struct SoundTrackData: Codable, Identifiable {
        public var id: UUID
        public var name: String
        public var trackType: String // "voice", "bgm", "se"
        public var speaker: String
        public var text: String
        public var phoneticText: String
        public var audioFilePath: String?
        public var volume: Double
        public var speedRate: Double          // 再生速度 (0.25x - 3.0x)
        public var pitchRate: Double          // 音程 (0.5x - 2.0x)
        public var isReversed: Bool           // 逆再生
        public var enableEcho: Bool           // エコー効果
        public var echoDelayMs: Double        // エコー遅延 (ms)
        public var echoFeedback: Double       // エコーフィードバック
        public var enableQualityFilter: Bool  // 音質改善フィルタ
        public var isMuted: Bool              // ミュート
        public var isSolo: Bool               // ソロ
        public var accent: Int                // アクセント (0-200)
        public var lmd: Int                   // 声質 (0-200)
        
        public init(
            id: UUID = UUID(),
            name: String,
            trackType: String = "voice",
            speaker: String = "博麗霊夢",
            text: String = "",
            phoneticText: String = "",
            audioFilePath: String? = nil,
            volume: Double = 0.8,
            speedRate: Double = 1.0,
            pitchRate: Double = 1.0,
            isReversed: Bool = false,
            enableEcho: Bool = false,
            echoDelayMs: Double = 180,
            echoFeedback: Double = 0.35,
            enableQualityFilter: Bool = false,
            isMuted: Bool = false,
            isSolo: Bool = false,
            accent: Int = 100,
            lmd: Int = 100
        ) {
            self.id = id
            self.name = name
            self.trackType = trackType
            self.speaker = speaker
            self.text = text
            self.phoneticText = phoneticText
            self.audioFilePath = audioFilePath
            self.volume = volume
            self.speedRate = speedRate
            self.pitchRate = pitchRate
            self.isReversed = isReversed
            self.enableEcho = enableEcho
            self.echoDelayMs = echoDelayMs
            self.echoFeedback = echoFeedback
            self.enableQualityFilter = enableQualityFilter
            self.isMuted = isMuted
            self.isSolo = isSolo
            self.accent = accent
            self.lmd = lmd
        }
    }
    
    public var slideSpeeches: [SavedSlideSpeech]?
    public var tracks: [SoundTrackData]?
    /// シーン別BGM・効果音設定（スライド単位でBGM/SEを割り当て、スパン指定も可能）
    public var sceneAudioItems: [SceneAudioItem]?
    
    public init(projectName: String = "第30話セリフ音声一式.tssm",
                speechInputText: String = "ゆっくりしていってね！東方スタジオのサウンドメーカーです。",
                phoneticSymbolText: String = "ユックリ'シテイッテ'ネ",
                conversionMode: String = "通常変換",
                selectedVoiceCharacter: String = "博麗霊夢",
                speedRate: Double = 1.0,
                pitchRate: Double = 1.0,
                volume: Double = 0.8,
                customDialect: String = "標準語（東京式）",
                customTone: String = "落ち着いた",
                audioFileName: String? = nil,
                slideSpeeches: [SavedSlideSpeech]? = nil,
                tracks: [SoundTrackData]? = nil,
                sceneAudioItems: [SceneAudioItem]? = nil) {
        self.projectName = projectName
        self.speechInputText = speechInputText
        self.phoneticSymbolText = phoneticSymbolText
        self.conversionMode = conversionMode
        self.selectedVoiceCharacter = selectedVoiceCharacter
        self.speedRate = speedRate
        self.pitchRate = pitchRate
        self.volume = volume
        self.customDialect = customDialect
        self.customTone = customTone
        self.audioFileName = audioFileName
        self.slideSpeeches = slideSpeeches
        self.tracks = tracks
        self.sceneAudioItems = sceneAudioItems
    }
}

// MARK: - 4. スライド＆シナリオメーカー用プロジェクトデータ (.tspm)
public struct SlideItemData: Codable, Identifiable {
    public var id: UUID
    public var title: String
    public var noteScript: String
    public var imagePath: String?
    
    // Keynoteノート メタ情報
    public var speakerCharacter: String?  // 先頭の () 内のキャラ名 (例: "操夢", "レミリア", "フラン")
    public var pureScriptText: String?    // 本文セリフ・台本テキスト
    public var animationMeta: String?     // 末尾の () 内の記述 (例: "アニメーション: 15秒")
    public var animationDuration: Double? // アニメーション秒数 (例: 15.0)
    
    // 8段階順序レイヤー対応
    public var backgroundImagePath: String?       // 1. 背景画像
    public var backgroundAnimation: String?       // 2. 背景画像のアニメーション
    public var characterImagePath: String?        // 3. キャラクター画像 ("/Volumes/ZSSD/動画用")
    public var characterAnimation: String?        // 4. キャラクター画像のアニメーション
    public var objectsData: [SlideObjectData]?    // 5. オブジェクト（テキストや図形など）
    public var objectAnimation: String?           // 6. オブジェクトのアニメーション
    public var telopText: String?                 // 7. テロップとノートにあるテキスト
    public var slideTransitionEffect: String?     // 8. スライドトランジション（効果名）
    public var slideTransitionDuration: Double?   // 8. スライドトランジション（秒数）
    
    enum CodingKeys: String, CodingKey {
        case id, title, noteScript, imagePath, speakerCharacter, pureScriptText, animationMeta, animationDuration
        case backgroundImagePath, backgroundAnimation, characterImagePath, characterAnimation, objectsData, objectAnimation, telopText, slideTransitionEffect, slideTransitionDuration
        // 代替キー対応
        case script, notes, text, image, image_path
    }
    
    public init(
        id: UUID = UUID(),
        title: String,
        noteScript: String,
        imagePath: String? = nil,
        speakerCharacter: String? = nil,
        pureScriptText: String? = nil,
        animationMeta: String? = nil,
        animationDuration: Double? = nil,
        backgroundImagePath: String? = nil,
        backgroundAnimation: String? = nil,
        characterImagePath: String? = nil,
        characterAnimation: String? = nil,
        objectsData: [SlideObjectData]? = nil,
        objectAnimation: String? = nil,
        telopText: String? = nil,
        slideTransitionEffect: String? = nil,
        slideTransitionDuration: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.noteScript = noteScript
        self.imagePath = imagePath
        self.speakerCharacter = speakerCharacter
        self.pureScriptText = pureScriptText
        self.animationMeta = animationMeta
        self.animationDuration = animationDuration
        self.backgroundImagePath = backgroundImagePath
        self.backgroundAnimation = backgroundAnimation
        self.characterImagePath = characterImagePath
        self.characterAnimation = characterAnimation
        self.objectsData = objectsData
        self.objectAnimation = objectAnimation
        self.telopText = telopText
        self.slideTransitionEffect = slideTransitionEffect
        self.slideTransitionDuration = slideTransitionDuration
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // idのデコード: UUID型、文字列からのUUID変換、または新規自動割り当て
        if let uuid = try? container.decode(UUID.self, forKey: .id) {
            self.id = uuid
        } else if let idStr = try? container.decode(String.self, forKey: .id), let uuid = UUID(uuidString: idStr) {
            self.id = uuid
        } else {
            self.id = UUID()
        }
        
        // タイトル
        self.title = (try? container.decode(String.self, forKey: .title)) ?? "スライド"
        
        // 台本・ノートテキスト（noteScript, script, notes, textの順で探索）
        var script = (try? container.decode(String.self, forKey: .noteScript)) ?? ""
        if script.isEmpty {
            if let alt = try? container.decode(String.self, forKey: .script), !alt.isEmpty {
                script = alt
            } else if let alt = try? container.decode(String.self, forKey: .notes), !alt.isEmpty {
                script = alt
            } else if let alt = try? container.decode(String.self, forKey: .text), !alt.isEmpty {
                script = alt
            }
        }
        self.noteScript = script
        
        // 画像パス
        var imgPath = try? container.decodeIfPresent(String.self, forKey: .imagePath)
        if imgPath == nil {
            imgPath = (try? container.decodeIfPresent(String.self, forKey: .image)) ?? (try? container.decodeIfPresent(String.self, forKey: .image_path))
        }
        self.imagePath = imgPath
        
        // キャラクター名
        var speaker = try? container.decodeIfPresent(String.self, forKey: .speakerCharacter)
        // 本文セリフ
        var pureScript = try? container.decodeIfPresent(String.self, forKey: .pureScriptText)
        // アニメーションメタ
        var animMeta = try? container.decodeIfPresent(String.self, forKey: .animationMeta)
        
        // アニメーション秒数: Double, Int, または "15秒", "15.0" 等の文字列から安全に変換
        var animDur: Double? = nil
        if let d = try? container.decodeIfPresent(Double.self, forKey: .animationDuration) {
            animDur = d
        } else if let i = try? container.decodeIfPresent(Int.self, forKey: .animationDuration) {
            animDur = Double(i)
        } else if let s = try? container.decodeIfPresent(String.self, forKey: .animationDuration) {
            animDur = Double(s) ?? FileFormatParser.extractDurationFromMeta(s)
        }
        
        // 8層レイヤー情報のデコード
        backgroundImagePath = try? container.decodeIfPresent(String.self, forKey: .backgroundImagePath)
        backgroundAnimation = try? container.decodeIfPresent(String.self, forKey: .backgroundAnimation)
        characterImagePath = try? container.decodeIfPresent(String.self, forKey: .characterImagePath)
        characterAnimation = try? container.decodeIfPresent(String.self, forKey: .characterAnimation)
        objectsData = try? container.decodeIfPresent([SlideObjectData].self, forKey: .objectsData)
        objectAnimation = try? container.decodeIfPresent(String.self, forKey: .objectAnimation)
        telopText = try? container.decodeIfPresent(String.self, forKey: .telopText)
        slideTransitionEffect = try? container.decodeIfPresent(String.self, forKey: .slideTransitionEffect)
        slideTransitionDuration = try? container.decodeIfPresent(Double.self, forKey: .slideTransitionDuration)
        
        // noteScript からメタ情報を自動抽出・補完
        if !self.noteScript.isEmpty {
            let parsed = FileFormatParser.parseNoteMeta(note: self.noteScript)
            if (speaker == nil || speaker?.isEmpty == true) && parsed.speaker != nil {
                speaker = parsed.speaker
            }
            if (pureScript == nil || pureScript?.isEmpty == true) {
                pureScript = parsed.body.isEmpty ? self.noteScript : parsed.body
            }
            if (animMeta == nil || animMeta?.isEmpty == true) && parsed.animMeta != nil {
                animMeta = parsed.animMeta
            }
            if animDur == nil {
                animDur = parsed.duration ?? (animMeta.flatMap { FileFormatParser.extractDurationFromMeta($0) })
            }
        }
        
        self.speakerCharacter = speaker
        self.pureScriptText = pureScript
        self.animationMeta = animMeta
        self.animationDuration = animDur
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(noteScript, forKey: .noteScript)
        try container.encodeIfPresent(imagePath, forKey: .imagePath)
        try container.encodeIfPresent(speakerCharacter, forKey: .speakerCharacter)
        try container.encodeIfPresent(pureScriptText, forKey: .pureScriptText)
        try container.encodeIfPresent(animationMeta, forKey: .animationMeta)
        try container.encodeIfPresent(animationDuration, forKey: .animationDuration)
        try container.encodeIfPresent(backgroundImagePath, forKey: .backgroundImagePath)
        try container.encodeIfPresent(backgroundAnimation, forKey: .backgroundAnimation)
        try container.encodeIfPresent(characterImagePath, forKey: .characterImagePath)
        try container.encodeIfPresent(characterAnimation, forKey: .characterAnimation)
        try container.encodeIfPresent(objectsData, forKey: .objectsData)
        try container.encodeIfPresent(objectAnimation, forKey: .objectAnimation)
        try container.encodeIfPresent(telopText, forKey: .telopText)
        try container.encodeIfPresent(slideTransitionEffect, forKey: .slideTransitionEffect)
        try container.encodeIfPresent(slideTransitionDuration, forKey: .slideTransitionDuration)
    }
}

public struct SlideScenarioProjectData: Codable {
    public var projectName: String
    public var slides: [SlideItemData]
    
    enum CodingKeys: String, CodingKey {
        case projectName, slides, items
    }
    
    public init(projectName: String = "解説スライド台本.tspm",
                slides: [SlideItemData] = []) {
        self.projectName = projectName
        self.slides = slides
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(projectName, forKey: .projectName)
        try container.encode(slides, forKey: .slides)
    }
    
    public init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            self.projectName = (try? container.decode(String.self, forKey: .projectName)) ?? "解説スライド台本.tspm"
            if let sl = try? container.decode([SlideItemData].self, forKey: .slides) {
                self.slides = sl
            } else if let sl = try? container.decode([SlideItemData].self, forKey: .items) {
                self.slides = sl
            } else {
                self.slides = []
            }
            return
        }
        
        // 配列直指定形式 [SlideItemData]
        if let singleContainer = try? decoder.singleValueContainer(),
           let sl = try? singleContainer.decode([SlideItemData].self) {
            self.projectName = "解説スライド台本.tspm"
            self.slides = sl
            return
        }
        
        throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Invalid SlideScenarioProjectData"))
    }
    
    /// JSONデータから安全にスライドプロジェクトを復元する高信頼ローダー
    public static func loadProject(from data: Data) -> SlideScenarioProjectData? {
        if let project = try? JSONDecoder().decode(SlideScenarioProjectData.self, from: data), !project.slides.isEmpty {
            return project
        }
        if let slides = try? JSONDecoder().decode([SlideItemData].self, from: data), !slides.isEmpty {
            return SlideScenarioProjectData(projectName: "解説スライド台本.tspm", slides: slides)
        }
        // JSONSerialization 経由のフォールバック探索
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let name = (json["projectName"] as? String) ?? (json["title"] as? String) ?? "解説スライド台本.tspm"
            let slideListObj = (json["slides"] as? [[String: Any]]) ?? (json["items"] as? [[String: Any]]) ?? []
            if !slideListObj.isEmpty,
               let subData = try? JSONSerialization.data(withJSONObject: slideListObj),
               let slides = try? JSONDecoder().decode([SlideItemData].self, from: subData), !slides.isEmpty {
                return SlideScenarioProjectData(projectName: name, slides: slides)
            }
        }
        return nil
    }
}

// MARK: - インポート進捗情報
public struct ImportProgressInfo: Sendable {
    public var current: Int
    public var total: Int
    public var progress: Double // 0.0 ... 1.0
    public var elapsedTime: TimeInterval
    public var remainingTime: TimeInterval
    public var totalEstimatedTime: TimeInterval
    public var statusText: String
    
    public init(
        current: Int = 0,
        total: Int = 0,
        progress: Double = 0.0,
        elapsedTime: TimeInterval = 0.0,
        remainingTime: TimeInterval = 0.0,
        totalEstimatedTime: TimeInterval = 0.0,
        statusText: String = ""
    ) {
        self.current = current
        self.total = total
        self.progress = progress
        self.elapsedTime = elapsedTime
        self.remainingTime = remainingTime
        self.totalEstimatedTime = totalEstimatedTime
        self.statusText = statusText
    }
}

// MARK: - 5. ゲームメーカー用プロジェクトデータ
public struct GameSceneData: Codable, Identifiable {
    public var id: UUID
    public var sceneName: String
    public var character: String
    public var dialogue: String
    public var background: String
    public var bgm: String
    public var danmakuType: String
    
    public init(id: UUID = UUID(),
                sceneName: String,
                character: String,
                dialogue: String,
                background: String,
                bgm: String,
                danmakuType: String) {
        self.id = id
        self.sceneName = sceneName
        self.character = character
        self.dialogue = dialogue
        self.background = background
        self.bgm = bgm
        self.danmakuType = danmakuType
    }
}

public struct GameProjectData: Codable {
    public var projectName: String
    public var scriptText: String
    public var scenes: [GameSceneData]
    public var targetPlatform: String
    
    public init(projectName: String = "東方弾幕ゲーム.tspm",
                scriptText: String = "",
                scenes: [GameSceneData] = [],
                targetPlatform: String = "素材スタジオ") {
        self.projectName = projectName
        self.scriptText = scriptText
        self.scenes = scenes
        self.targetPlatform = targetPlatform
    }
}

// MARK: - 共通ファイルパーサーユーティリティ
public enum FileFormatParser {
    
    /// アニメーションメタ文字列（例: "アニメーション: 15秒", "アニメーション:12.35s"）から秒数を抽出
    public static func extractDurationFromMeta(_ metaStr: String) -> Double? {
        if let secMatch = metaStr.range(of: "([0-9]+(?:\\.[0-9]+)?)\\s*(?:秒|s|sec)?", options: .regularExpression) {
            let matched = String(metaStr[secMatch])
            let numStr = matched
                .replacingOccurrences(of: "秒", with: "")
                .replacingOccurrences(of: "sec", with: "", options: .caseInsensitive)
                .replacingOccurrences(of: "s", with: "", options: .caseInsensitive)
                .trimmingCharacters(in: .whitespaces)
            return Double(numStr)
        }
        return nil
    }
    
    public static func parseNoteMeta(note: String) -> (speaker: String?, body: String, animMeta: String?, duration: Double?) {
        var text = note.trimmingCharacters(in: .whitespacesAndNewlines)
        var speaker: String? = nil
        var animMetaArray: [String] = []
        var maxDuration: Double? = nil
        
        let pattern = "[(（【\\[]([^)）】\\]]+)[)）】\\]]"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
            let matches = regex.matches(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count))
            for match in matches.reversed() {
                if let range = Range(match.range(at: 1), in: text) {
                    let inner = String(text[range]).trimmingCharacters(in: .whitespaces)
                    
                    let animKeywords = ["アニメ", "ズーム", "zoom", "フェード", "fade", "スライド", "slide", "パン", "pan", "移動", "拡大", "縮小", "イン", "アウト"]
                    let hasAnimKeyword = animKeywords.contains(where: { inner.lowercased().contains($0) })
                    
                    if hasAnimKeyword {
                        animMetaArray.insert(inner, at: 0)
                        if let dur = extractDurationFromMeta(inner) {
                            maxDuration = max(maxDuration ?? 0, dur)
                        }
                    } else if speaker == nil {
                        // アニメーションキーワードが含まれない場合は話者とみなす
                        speaker = inner
                    }
                    
                    // マッチしたタグ部分をテキストから削除
                    if let fullRange = Range(match.range(at: 0), in: text) {
                        text.removeSubrange(fullRange)
                    }
                }
            }
        }
        
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let animMeta = animMetaArray.isEmpty ? nil : animMetaArray.joined(separator: ", ")
        
        return (speaker, text, animMeta, maxDuration)
    }
    
    /// テキストまたはMarkdownからスライド構成とノート台本を抽出
    public static func parseTextOrMarkdownToSlides(content: String, defaultTitle: String) -> [SlideItemData] {
        let lines = content.components(separatedBy: .newlines)
        var result: [SlideItemData] = []
        var currentTitle: String? = nil
        var currentBody: [String] = []
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("#") {
                // 新しいスライド見出し
                if let title = currentTitle {
                    result.append(SlideItemData(title: title, noteScript: currentBody.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)))
                    currentBody.removeAll()
                }
                let heading = trimmed.replacingOccurrences(of: "^#+\\s*", with: "", options: .regularExpression)
                currentTitle = heading.isEmpty ? "スライド\(result.count + 1)" : heading
            } else if trimmed.hasPrefix("---") || trimmed.hasPrefix("===") {
                // 水平線区切り
                if let title = currentTitle {
                    result.append(SlideItemData(title: title, noteScript: currentBody.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)))
                    currentTitle = nil
                    currentBody.removeAll()
                }
            } else {
                if currentTitle == nil && !trimmed.isEmpty {
                    currentTitle = trimmed
                } else {
                    currentBody.append(line)
                }
            }
        }
        
        if let title = currentTitle {
            result.append(SlideItemData(title: title, noteScript: currentBody.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        
        if result.isEmpty {
            // パースできなかった場合は全体を1つのスライドに
            result.append(SlideItemData(title: defaultTitle, noteScript: content))
        }
        
        return result
    }
    
    /// CSVからスライド構成とノート台本を抽出 (カラム1: タイトル, カラム2: 台本)
    public static func parseCSVToSlides(content: String) -> [SlideItemData] {
        let lines = content.components(separatedBy: .newlines)
        var result: [SlideItemData] = []
        
        for (index, line) in lines.enumerated() {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            let cols = trimmed.components(separatedBy: ",")
            if cols.count >= 2 {
                let title = cols[0].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
                let script = cols[1...].joined(separator: ",").trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\"", with: "")
                result.append(SlideItemData(title: title.isEmpty ? "スライド\(index + 1)" : title, noteScript: script))
            } else {
                result.append(SlideItemData(title: "スライド\(index + 1): " + cols[0], noteScript: cols[0]))
            }
        }
        return result.isEmpty ? [SlideItemData(title: "スライド1", noteScript: content)] : result
    }
    
    /// スライドや台本からセリフ行（「キャラ名: セリフ」等）を抽出
    public static func extractDialogue(from text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var extracted: [String] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let meta = parseNoteMeta(note: trimmed)
            if let spk = meta.speaker, !meta.body.isEmpty {
                extracted.append("\(spk): \(meta.body)")
            } else if trimmed.contains(":") || trimmed.contains("：") || trimmed.contains("「") {
                extracted.append(trimmed)
            }
        }
        if extracted.isEmpty {
            return text
        }
        return extracted.joined(separator: "\n")
    }
    
    /// YMM4 (.ymmp) または JSON タイムラインからシーンを抽出
    public static func parseYmmpScenes(content: String) -> (scenes: [String], duration: Double) {
        // YMM4はJSON形式。TimelineやItemsを持つ。
        guard let data = content.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (["シーン1: ゆっくり導入", "シーン2: 本編解説", "シーン3: まとめ"], 120.0)
        }
        
        var foundScenes: [String] = []
        var maxTime: Double = 60.0
        
        // Timeline or Items探索
        if let timeline = json["Timeline"] as? [String: Any],
           let items = timeline["Items"] as? [[String: Any]] {
            for (idx, item) in items.prefix(8).enumerated() {
                let text = (item["Text"] as? String) ?? (item["Name"] as? String) ?? "アイテム\(idx + 1)"
                foundScenes.append("シーン\(idx + 1): \(text.prefix(15))")
                if let length = item["Length"] as? Double {
                    maxTime += length / 60.0 // フレームから秒への概算
                }
            }
        } else if let items = json["items"] as? [[String: Any]] {
            for (idx, item) in items.prefix(8).enumerated() {
                let text = (item["text"] as? String) ?? "シーン\(idx + 1)"
                foundScenes.append("シーン\(idx + 1): \(text.prefix(15))")
            }
        }
        
        if foundScenes.isEmpty {
            foundScenes = ["シーン1: YMM4インポート", "シーン2: キャラクター掛け合い", "シーン3: エンディング"]
        }
        
        return (foundScenes, max(maxTime, 60.0))
    }
    
    /// Keynote (.key) ファイルからスライド一覧、ノート台本、およびスライドレンダリング画像を抽出
    public static func parseKeynoteToSlides(
        fileURL: URL,
        exportImages: Bool = true,
        onProgress: ((ImportProgressInfo) -> Void)? = nil
    ) -> [SlideItemData] {
        let startTime = Date()
        let path = fileURL.path
        let escapedPath = path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        
        let tempExportDir = FileManager.default.temporaryDirectory.appendingPathComponent("TohoStudio_Keynote_\(UUID().uuidString)")
        if exportImages {
            try? FileManager.default.createDirectory(at: tempExportDir, withIntermediateDirectories: true)
        }
        
        onProgress?(ImportProgressInfo(
            current: 0,
            total: 0,
            progress: 0.05,
            elapsedTime: 0,
            remainingTime: 0,
            totalEstimatedTime: 0,
            statusText: "Keynoteを開き、スライド構成・台本を解析中..."
        ))
        
        let jxaScript = """
        var Keynote = Application("com.apple.Keynote");
        var doc = Keynote.open(Path("\(escapedPath)"));
        var slides = doc.slides();
        var count = slides.length;
        var slideDataList = [];
        var maxSlides = Math.min(count, 300);
        for (var i = 0; i < maxSlides; i++) {
            var s = slides[i];
            
            // 1 & 3: 画像名一覧（背景画像・キャラクター画像判定用）
            // 同時に画像オブジェクトのIDも収集してビルドアニメーションと照合できるようにする
            var imgNames = [];
            var imgIdToName = {};  // objectId -> fileName のマッピング
            try {
                var ims = s.images();
                for (var j = 0; j < ims.length; j++) {
                    try {
                        var fn = ims[j].fileName();
                        if (fn) {
                            imgNames.push(fn);
                            // objectId で引くことができる場合はマッピングを保持
                            try {
                                var oid = ims[j].id();
                                if (oid) imgIdToName[String(oid)] = fn;
                            } catch(e) {}
                        }
                    } catch(e) {}
                }
            } catch(e) {}
            
            // 4: 画像に紐付くビルド＋アクション（バウンス等）を取得
            // Keynoteの buildItems() には Build In/Out と Action が混在する。
            // Action（強調・バウンス）を優先し、duration / bounceCount も拾う。
            var imageBuilds = {};
            var textBuilds = [];
            try {
                var builds = s.buildItems();
                for (var b = 0; b < builds.length; b++) {
                    try {
                        var bld = builds[b];
                        var bProps = {};
                        try { bProps = bld.properties(); } catch(e) { bProps = {}; }
                        var effect = "";
                        var duration = 0.0;
                        var delay = 0.0;
                        var buildType = "";
                        var bounceCount = 0;
                        try { effect = String(bProps.buildEffect || bProps.transitionEffect || bProps.effect || ""); } catch(e) {}
                        try { duration = Number(bProps.duration || bProps.buildDuration || 0.0); } catch(e) {}
                        try { delay = Number(bProps.delay || bProps.buildDelay || 0.0); } catch(e) {}
                        try { buildType = String(bProps.buildType || bProps.type || bProps.actionType || ""); } catch(e) {}
                        try { if (!effect) effect = String(bld.buildEffect()); } catch(e) {}
                        try { if (!duration) duration = Number(bld.duration()); } catch(e) {}
                        try { if (!delay) delay = Number(bld.delay()); } catch(e) {}
                        try { if (!buildType) buildType = String(bld.buildType()); } catch(e) {}
                        try {
                            var bc = bProps.bounceCount || bProps.numberOfBounces || bProps.bounces || bProps.repeatCount;
                            if (bc) bounceCount = Number(bc);
                        } catch(e) {}
                        var blob = (String(effect) + " " + String(buildType)).toLowerCase();
                        var isAction = /action|アクション|emphasis|bounce|バウンス|呼吸/.test(blob)
                            || (duration >= 3.0 && /move|opacity|scale|rotate|pulse|jiggle|wiggle/.test(blob));
                        if (!effect && isAction) effect = "バウンス";
                        try {
                            var target = bld.object();
                            var targetFn = null;
                            try { targetFn = target.fileName(); } catch(e) {}
                            if (targetFn && imgNames.indexOf(targetFn) >= 0) {
                                if (!bounceCount && duration > 0.5 && (/bounce|バウンス/.test(blob) || isAction)) {
                                    bounceCount = Math.max(1, Math.round(duration * 1.73));
                                }
                                var score = duration + (isAction ? 1000 : 0) + (/bounce|バウンス/.test(blob) ? 500 : 0);
                                var prev = imageBuilds[targetFn];
                                if (!prev || score >= (prev.score || 0)) {
                                    imageBuilds[targetFn] = {
                                        effect: effect || (isAction ? "バウンス" : "アニメーション"),
                                        duration: duration,
                                        delay: delay,
                                        buildType: buildType,
                                        isAction: !!isAction,
                                        bounceCount: bounceCount,
                                        score: score
                                    };
                                }
                            } else {
                                // テキスト／図形向けビルド
                                var ttxt = "";
                                try { ttxt = String(target.objectText() || ""); } catch(e) {}
                                if (ttxt || !targetFn) {
                                    textBuilds.push({
                                        effect: effect || "",
                                        duration: duration,
                                        delay: delay,
                                        buildType: buildType,
                                        isAction: !!isAction,
                                        text: ttxt.substring(0, 40)
                                    });
                                }
                            }
                        } catch(e) {}
                    } catch(e) {}
                }
            } catch(e) {}
            
            // 5: オブジェクト（テキストや図形など）
            var tItems = s.textItems();
            var title = "";
            var allTexts = [];
            for (var j = 0; j < tItems.length; j++) {
                try {
                    var t = tItems[j].objectText();
                    if (t) {
                        var trimmed = t.trim();
                        if (trimmed.length > 0) {
                            allTexts.push(trimmed);
                            if (title.length === 0) {
                                title = trimmed.replace(/\\r?\\n/g, " ");
                            }
                        }
                    }
                } catch(e) {}
            }
            
            // 7: 発表者ノート（テロップと台本）
            var notes = "";
            try {
                notes = s.presenterNotes() || "";
            } catch(e) {}
            
            var script = notes.trim();
            if (script.length === 0 && allTexts.length > 1) {
                script = allTexts.slice(1).join("\\n");
            } else if (script.length === 0 && allTexts.length === 1) {
                script = allTexts[0];
            }
            
            // 8: スライドトランジション（スライドそのものに紐づくアニメーション）
            var trEffect = "";
            var trDuration = 1.0;
            try {
                var tr = s.transitionProperties();
                if (tr) {
                    trEffect = tr.transitionEffect || "";
                    trDuration = tr.transitionDuration || 1.0;
                }
            } catch(e) {}
            
            var displayTitle = title ? ("スライド " + (i + 1) + ": " + (title.length > 30 ? title.substring(0, 30) + "..." : title)) : ("スライド " + (i + 1));
            slideDataList.push({
                title: displayTitle,
                notes: script,
                images: imgNames,
                imageBuilds: imageBuilds,
                textBuilds: textBuilds,
                texts: allTexts,
                trEffect: trEffect,
                trDuration: trDuration
            });
        }
        doc.close({saving: "no"});
        JSON.stringify(slideDataList);
        """
        
        var parsedSlidesRaw: [[String: Any]] = []
        let proc = Process()
        proc.launchPath = "/usr/bin/osascript"
        proc.arguments = ["-l", "JavaScript", "-e", jxaScript]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]], !jsonArray.isEmpty {
                parsedSlidesRaw = jsonArray
            }
        } catch {
            // JXA失敗時
        }
        
        let totalCount = parsedSlidesRaw.count
        let jxaElapsed = Date().timeIntervalSince(startTime)
        let initialEstimatedSeconds = Double(max(totalCount, 5)) * 0.08 + 1.5
        
        onProgress?(ImportProgressInfo(
            current: 0,
            total: totalCount,
            progress: 0.10,
            elapsedTime: jxaElapsed,
            remainingTime: initialEstimatedSeconds,
            totalEstimatedTime: jxaElapsed + initialEstimatedSeconds,
            statusText: "スライド構成と発表者ノートの解析完了 (全\(totalCount)枚)"
        ))
        
        // スライド画像のエクスポート（AppleScript経由）
        var exportedImages: [String] = []
        if exportImages && totalCount > 0 {
            let exportScript = """
            tell application id "com.apple.Keynote"
                with timeout of 60 seconds
                    set doc to open POSIX file "\(escapedPath)"
                    try
                        export doc to POSIX file "\(tempExportDir.path)" as slide images with properties {image format:JPEG}
                    end try
                    close doc saving no
                end timeout
            end tell
            """
            let exportProc = Process()
            exportProc.launchPath = "/usr/bin/osascript"
            exportProc.arguments = ["-e", exportScript]
            let errPipe = Pipe()
            exportProc.standardError = errPipe
            if let _ = try? exportProc.run() {
                var loopCount = 0
                // 画像エクスポート中の進捗監視（ファイル数のポーリング）
                while exportProc.isRunning && loopCount < 240 { // 最大60秒
                    Thread.sleep(forTimeInterval: 0.25)
                    loopCount += 1
                    let files = (try? FileManager.default.contentsOfDirectory(atPath: tempExportDir.path)) ?? []
                    let currentCount = files.filter { $0.hasSuffix(".jpeg") || $0.hasSuffix(".jpg") || $0.hasSuffix(".png") }.count
                    let elapsed = Date().timeIntervalSince(startTime)
                    
                    let ratio = totalCount > 0 ? Double(currentCount) / Double(totalCount) : 0.0
                    let progressVal = min(0.96, 0.10 + 0.86 * ratio)
                    
                    var remainingTime: TimeInterval = 0
                    var totalEst: TimeInterval = elapsed
                    if currentCount > 0 {
                        let secPerSlide = elapsed / Double(currentCount)
                        let remSlides = max(0, totalCount - currentCount)
                        remainingTime = secPerSlide * Double(remSlides)
                        totalEst = elapsed + remainingTime
                    } else {
                        remainingTime = max(1.0, Double(totalCount) * 0.08)
                        totalEst = elapsed + remainingTime
                    }
                    
                    onProgress?(ImportProgressInfo(
                        current: currentCount,
                        total: totalCount,
                        progress: progressVal,
                        elapsedTime: elapsed,
                        remainingTime: remainingTime,
                        totalEstimatedTime: totalEst,
                        statusText: "高精細スライド画像を出力中... (\(currentCount) / \(totalCount) 枚)"
                    ))
                }
                exportProc.waitUntilExit()
                
                if let files = try? FileManager.default.contentsOfDirectory(atPath: tempExportDir.path) {
                    let jpegs = files.filter { $0.hasSuffix(".jpeg") || $0.hasSuffix(".jpg") || $0.hasSuffix(".png") }
                        .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
                    exportedImages = jpegs.map { tempExportDir.appendingPathComponent($0).path }
                }
            }
            
            // エクスポート画像が取れなかった場合、Keynote内の preview.jpg を第1スライド用としてフォールバック展開
            if exportedImages.isEmpty {
                let unzipProc = Process()
                unzipProc.launchPath = "/usr/bin/unzip"
                unzipProc.arguments = ["-p", fileURL.path, "preview.jpg"]
                let previewPipe = Pipe()
                unzipProc.standardOutput = previewPipe
                unzipProc.standardError = Pipe()
                if let _ = try? unzipProc.run() {
                    let previewData = previewPipe.fileHandleForReading.readDataToEndOfFile()
                    unzipProc.waitUntilExit()
                    if !previewData.isEmpty {
                        let previewFile = tempExportDir.appendingPathComponent("preview_cover.jpg")
                        try? previewData.write(to: previewFile)
                        exportedImages.append(previewFile.path)
                    }
                }
            }
        }
        
        let finalElapsed = Date().timeIntervalSince(startTime)
        onProgress?(ImportProgressInfo(
            current: totalCount,
            total: totalCount,
            progress: 1.0,
            elapsedTime: finalElapsed,
            remainingTime: 0,
            totalEstimatedTime: finalElapsed,
            statusText: "展開完了 (全\(totalCount)枚のスライド・画像をインポート)"
        ))
        
        // 8段階順序のレイヤー情報構築と動画用フォルダとの照合
        if !parsedSlidesRaw.isEmpty {
            var result: [SlideItemData] = []
            let resolver = VideoAssetResolver.shared
            
            for (idx, item) in parsedSlidesRaw.enumerated() {
                let title = (item["title"] as? String) ?? "スライド \(idx + 1)"
                let rawNotes = (item["notes"] as? String) ?? ""
                let imgList = (item["images"] as? [String]) ?? []
                // imageBuilds: JXAが収集した「画像ファイル名 -> { effect, duration, delay }」のマッピング
                let imageBuilds = (item["imageBuilds"] as? [String: [String: Any]]) ?? [:]
                let texts = (item["texts"] as? [String]) ?? []
                let trEffect = (item["trEffect"] as? String) ?? "no transition effect"
                let trDuration = (item["trDuration"] as? Double) ?? 1.0
                let exportedImgPath = idx < exportedImages.count ? exportedImages[idx] : nil
                
                // ノートはテロップ/台本の解析にのみ使用（アニメ推測には使わない）
                let meta = parseNoteMeta(note: rawNotes)
                
                // 1. 背景画像判定 & 素材照合
                // キャラクター画像と判定された画像名も後でbuildItemsと照合するために記録する
                var bgResolvedPath: String? = nil
                var charResolvedPath: String? = nil
                var charImageName: String? = nil   // キャラクター画像の元ファイル名（buildItems照合用）
                
                // 画像リストを背景候補とキャラクター候補に分類
                for imgName in imgList {
                    let lower = imgName.lowercased()
                    let isLikelyBg = lower.contains("茶の間") || lower.contains("背景") || lower.contains(".pxd") || lower.contains("部屋") || lower.contains("空") || lower.contains("室内") || lower.contains("bg")
                    
                    if isLikelyBg && bgResolvedPath == nil {
                        bgResolvedPath = resolver.resolveBackgroundImage(named: imgName)
                    } else if charResolvedPath == nil {
                        charResolvedPath = resolver.resolveCharacterImage(named: imgName, speaker: meta.speaker)
                        if charResolvedPath != nil {
                            charImageName = imgName   // 照合に使ったキャラクター画像名を保持
                        }
                    } else if bgResolvedPath == nil {
                        bgResolvedPath = resolver.resolveBackgroundImage(named: imgName)
                    }
                }
                
                // 背景画像が未解決の場合、エクスポートされた統合スライド画像を背景としてフォールバック
                if bgResolvedPath == nil {
                    bgResolvedPath = exportedImgPath
                }
                
                let textBuilds = (item["textBuilds"] as? [[String: Any]]) ?? []
                
                // 2. 背景アニメ: Keynoteに背景向け効果があるときだけ（無ければ静止）
                let bgAnim: String? = {
                    for imgName in imgList {
                        let lower = imgName.lowercased()
                        let isLikelyBg = lower.contains("茶の間") || lower.contains("背景") || lower.contains(".pxd") || lower.contains("部屋") || lower.contains("空") || lower.contains("室内") || lower.contains("bg")
                        guard isLikelyBg, let info = imageBuilds[imgName] else { continue }
                        let effect = (info["effect"] as? String) ?? ""
                        let isAction = (info["isAction"] as? Bool) ?? false
                        // 背景にバウンスは稀。Ken Burns / ズーム / パンのみ採用
                        let blob = (effect + " " + String(describing: info["buildType"] ?? "")).lowercased()
                        if blob.contains("ken") || blob.contains("ズーム") || blob.contains("zoom") || blob.contains("パン") || blob.contains("pan") || blob.contains("ドリフト") {
                            let dur = (info["duration"] as? Double) ?? 0
                            if dur > 0 { return "\(effect.isEmpty ? "Ken Burns" : effect) (\(String(format: "%.1f", dur))秒)" }
                            return effect.isEmpty ? "ゆっくりズームイン（Ken Burns）" : effect
                        }
                        if !isAction && !effect.isEmpty { return effect }
                    }
                    return nil
                }()
                
                // 4. キャラクター: Action（バウンス等）を優先して characterAnimation に載せる
                // ノート推測は使わない。アクションが無ければ nil（無理にデフォルトバウンスしない）
                let charAnim: String? = {
                    // キャラ候補: 解決済み名 → 非背景画像で action があるもの
                    var candidates: [(String, [String: Any])] = []
                    if let charName = charImageName, let info = imageBuilds[charName] {
                        candidates.append((charName, info))
                    }
                    for (fn, info) in imageBuilds {
                        let lower = fn.lowercased()
                        let isLikelyBg = lower.contains("茶の間") || lower.contains("背景") || lower.contains(".pxd") || lower.contains("部屋") || lower.contains("空") || lower.contains("室内") || lower.contains("bg")
                        if isLikelyBg { continue }
                        if charImageName == fn { continue }
                        candidates.append((fn, info))
                    }
                    // Action / バウンス / 長尺を優先
                    candidates.sort { a, b in
                        let sa = (a.1["score"] as? Double) ?? (((a.1["isAction"] as? Bool) == true ? 1000.0 : 0.0) + ((a.1["duration"] as? Double) ?? 0))
                        let sb = (b.1["score"] as? Double) ?? (((b.1["isAction"] as? Bool) == true ? 1000.0 : 0.0) + ((b.1["duration"] as? Double) ?? 0))
                        return sa > sb
                    }
                    guard let best = candidates.first else { return nil }
                    let info = best.1
                    var effect = (info["effect"] as? String) ?? ""
                    let duration = (info["duration"] as? Double) ?? 0.0
                    let delay = (info["delay"] as? Double) ?? 0.0
                    let isAction = (info["isAction"] as? Bool) ?? false
                    var bounceCount = 0
                    if let bc = info["bounceCount"] as? Int { bounceCount = bc }
                    else if let bc = info["bounceCount"] as? Double { bounceCount = Int(bc) }
                    let blob = (effect + " " + String(describing: info["buildType"] ?? "")).lowercased()
                    let looksBounce = blob.contains("bounce") || blob.contains("バウンス") || blob.contains("呼吸") || blob.contains("揺れ") || isAction
                    if looksBounce && effect.isEmpty { effect = "バウンス" }
                    if looksBounce && bounceCount <= 0 && duration > 0.5 {
                        bounceCount = max(1, Int((duration * 1.73).rounded()))
                    }
                    if !looksBounce && effect.isEmpty && duration <= 0 { return nil }
                    let effectLabel = effect.isEmpty ? (looksBounce ? "バウンス" : "アニメーション") : effect
                    var parts: [String] = []
                    if duration > 0 { parts.append(String(format: "%.1f秒", duration)) }
                    if bounceCount > 0 { parts.append("\(bounceCount)回") }
                    if delay > 0 { parts.append(String(format: "遅延%.1f秒", delay)) }
                    if parts.isEmpty { return effectLabel }
                    return "\(effectLabel) (\(parts.joined(separator: ", ")))"
                }()
                
                // キャラ画像が未解決でも、バウンス付き画像名があれば再解決を試みる
                if charResolvedPath == nil, let charAnim, charAnim.contains("バウンス") || charAnim.lowercased().contains("bounce") {
                    for (fn, info) in imageBuilds {
                        let isAction = (info["isAction"] as? Bool) ?? false
                        let effect = ((info["effect"] as? String) ?? "").lowercased()
                        if isAction || effect.contains("bounce") || effect.contains("バウンス") {
                            if let resolved = resolver.resolveCharacterImage(named: fn, speaker: meta.speaker) {
                                charResolvedPath = resolved
                                charImageName = fn
                                break
                            }
                        }
                    }
                }
                
                // 5. オブジェクト（テキストや図形など）— オブジェクト向けビルドがあるときだけ animation を付与
                var slideObjects: [SlideObjectData] = []
                let firstTextBuildEffect: String? = {
                    for tb in textBuilds {
                        let eff = (tb["effect"] as? String) ?? ""
                        if !eff.isEmpty { return eff }
                    }
                    return nil
                }()
                for (tIdx, t) in texts.enumerated() {
                    slideObjects.append(SlideObjectData(
                        type: "text",
                        text: t,
                        x: 100,
                        y: Double(200 + tIdx * 120),
                        width: 1720,
                        height: 100,
                        animation: firstTextBuildEffect
                    ))
                }
                
                // 6. オブジェクトのアニメーション（テキストビルドがあるときだけ）
                let objAnim: String? = firstTextBuildEffect
                
                // 7. テロップとノートにあるテキスト
                let formattedScript: String
                if let spk = meta.speaker, !meta.body.isEmpty {
                    formattedScript = "\(spk): \(meta.body)"
                } else if !rawNotes.isEmpty {
                    formattedScript = rawNotes
                } else {
                    formattedScript = "霊夢: 「スライド \(idx + 1) の解説セリフを入力してください。」"
                }
                
                let telopText = meta.body.isEmpty ? rawNotes : meta.body
                
                // 8. スライドトランジション
                let transitionMeta = trEffect.isEmpty || trEffect == "no transition effect" ? nil : trEffect
                
                result.append(SlideItemData(
                    title: title,
                    noteScript: formattedScript,
                    imagePath: exportedImgPath ?? bgResolvedPath,
                    speakerCharacter: meta.speaker,
                    pureScriptText: telopText,
                    // animationMeta = ノート由来のスライドレベルアニメーション指定（なければnil）
                    // ★ charAnim は絶対に入れない → parseRecipes が .slide ターゲットで誤適用するため
                    animationMeta: meta.animMeta,
                    animationDuration: {
                        // Action / キャラビルドの duration を優先
                        var bestDur: Double = 0
                        for (_, info) in imageBuilds {
                            let dur = (info["duration"] as? Double) ?? 0
                            let isAction = (info["isAction"] as? Bool) ?? false
                            if isAction && dur > bestDur { bestDur = dur }
                        }
                        if bestDur > 0 { return bestDur }
                        if let charName = charImageName,
                           let buildInfo = imageBuilds[charName],
                           let dur = buildInfo["duration"] as? Double, dur > 0 {
                            return dur
                        }
                        if let charAnim, let d = SlideAnimationKit.extractDurationSeconds(from: charAnim) {
                            return d
                        }
                        return SlideAnimationKit.estimateDuration(
                            meta: meta.animMeta,
                            noteDuration: meta.duration,
                            buildCount: SlideAnimationKit.parseRecipes(from: meta.animMeta).count
                        )
                    }(),
                    backgroundImagePath: bgResolvedPath,
                    backgroundAnimation: bgAnim,
                    characterImagePath: charResolvedPath,
                    characterAnimation: charAnim,  // キャラクター専用（Step1のみで使用）
                    objectsData: slideObjects.isEmpty ? nil : slideObjects,
                    objectAnimation: objAnim,
                    telopText: telopText,
                    slideTransitionEffect: transitionMeta,
                    slideTransitionDuration: trDuration
                ))
            }
            return result
        }
        
        // フォールバック: zipinfo でスライド数やコンテンツから概算復元
        return fallbackExtractKeynote(fileURL: fileURL)
    }
    
    private static func fallbackExtractKeynote(fileURL: URL) -> [SlideItemData] {
        let fileName = fileURL.deletingPathExtension().lastPathComponent
        // mdls または zipinfo によるスライド数推定
        let proc = Process()
        proc.launchPath = "/usr/bin/zipinfo"
        proc.arguments = ["-1", fileURL.path]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        
        var slideCount = 10
        if let _ = try? proc.run() {
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let str = String(data: data, encoding: .utf8) {
                let lines = str.components(separatedBy: .newlines)
                let tiles = lines.filter { $0.contains("Tile-") }
                if !tiles.isEmpty {
                    slideCount = max(5, tiles.count)
                }
            }
        }
        
        var fallbackList: [SlideItemData] = []
        for i in 1...min(slideCount, 50) {
            fallbackList.append(SlideItemData(
                title: "\(fileName) - スライド \(i)",
                noteScript: "霊夢: 「\(fileName) のスライド \(i) の台本です。」\n魔理沙: 「ここに詳しい解説を記述しようぜ！」"
            ))
        }
        return fallbackList
    }
    
    /// KeynoteのUI操作（GUIスクリプティング）を利用して、アニメーションとノートを強制的に読み取る
    /// ※実行にはアクセシビリティ権限が必要です
    public static func parseKeynoteWithGUIScripting(
        fileURL: URL,
        onProgress: ((ImportProgressInfo) -> Void)? = nil
    ) -> [SlideItemData] {
        let startTime = Date()
        let path = fileURL.path
        let escapedPath = path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        
        onProgress?(ImportProgressInfo(
            current: 0,
            total: 0,
            progress: 0.1,
            elapsedTime: 0,
            remainingTime: 0,
            totalEstimatedTime: 0,
            statusText: "KeynoteをGUI経由で操作してアニメーション情報を抽出中..."
        ))
        
        let jxaScript = """
        function run() {
            var Keynote = Application("com.apple.Keynote");
            var doc = Keynote.open(Path("\(escapedPath)"));
            var slides = doc.slides();
            var count = slides.length;
            var maxSlides = Math.min(count, 300);
            
            var SystemEvents = Application("System Events");
            var proc = SystemEvents.processes.byName("Keynote");
            var frontWin = null;
            try { frontWin = proc.windows[0]; } catch(e) {}
            if (!frontWin) return JSON.stringify([]);
            
            try {
                proc.menuBars[0].menuBarItems.byName("表示").menus[0].menuItems.byName("インスペクタ").menus[0].menuItems.byName("アニメーション").click();
            } catch(e) {}
            delay(0.5);
            
            try {
                var btns = frontWin.buttons;
                for (var i = 0; i < btns.length; i++) {
                    if (btns[i].title() === "ビルドの順番" || btns[i].description() === "ビルドの順番") {
                        btns[i].click();
                        break;
                    }
                }
            } catch(e) {}
            delay(0.5);
            
            var results = [];
            for (var i = 0; i < maxSlides; i++) {
                doc.currentSlide = slides[i];
                delay(0.3);
                
                var buildWin = null;
                try { buildWin = proc.windows.byName("ビルドの順番"); } catch(e) {}
                
                var builds = [];
                if (buildWin) {
                    try {
                        var tables = buildWin.scrollAreas[0].tables;
                        if (tables.length > 0) {
                            var rows = tables[0].rows;
                            for (var r = 0; r < rows.length; r++) {
                                var uiEls = rows[r].uiElements;
                                var rowStr = "";
                                for (var u = 0; u < uiEls.length; u++) {
                                    try {
                                        var val = uiEls[u].value();
                                        var title = uiEls[u].title();
                                        if (val && typeof val === 'string') rowStr += val + " ";
                                        else if (title && typeof title === 'string') rowStr += title + " ";
                                    } catch(e) {}
                                }
                                builds.push(rowStr.trim());
                            }
                        }
                    } catch(e) {}
                }
                
                var notes = "";
                try { notes = slides[i].presenterNotes() || ""; } catch(e) {}
                
                var tItems = slides[i].textItems();
                var allTexts = [];
                for (var j = 0; j < tItems.length; j++) {
                    try {
                        var t = tItems[j].objectText();
                        if (t && t.trim().length > 0) allTexts.push(t.trim());
                    } catch(e) {}
                }
                
                results.push({
                    title: "スライド " + (i + 1),
                    notes: notes,
                    builds: builds,
                    texts: allTexts
                });
            }
            return JSON.stringify(results);
        }
        """
        
        var parsedResults: [[String: Any]] = []
        let proc = Process()
        proc.launchPath = "/usr/bin/osascript"
        proc.arguments = ["-l", "JavaScript", "-e", jxaScript]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        
        do {
            try proc.run()
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let jsonArray = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]], !jsonArray.isEmpty {
                parsedResults = jsonArray
            }
        } catch {
            print("AppleScript execution failed: \\(error)")
        }
        
        let totalCount = parsedResults.count
        var result: [SlideItemData] = []
        
        for (idx, p) in parsedResults.enumerated() {
            let note = (p["notes"] as? String) ?? ""
            let builds = (p["builds"] as? [String]) ?? []
            
            let meta = parseNoteMeta(note: note)
            
            var combinedAnimMeta = meta.animMeta ?? ""
            for build in builds {
                if !build.isEmpty {
                    if combinedAnimMeta.isEmpty {
                        combinedAnimMeta = build
                    } else {
                        combinedAnimMeta += ", " + build
                    }
                }
            }
            
            let script = meta.body.isEmpty ? note : meta.body
            
            let estimatedAnimDur = SlideAnimationKit.estimateDuration(
                meta: combinedAnimMeta.isEmpty ? nil : combinedAnimMeta,
                noteDuration: meta.duration,
                buildCount: builds.count
            )
            let item = SlideItemData(
                title: (p["title"] as? String) ?? "スライド \(idx + 1)",
                noteScript: script,
                imagePath: nil,
                speakerCharacter: meta.speaker,
                pureScriptText: script,
                animationMeta: combinedAnimMeta.isEmpty ? nil : combinedAnimMeta,
                animationDuration: estimatedAnimDur
            )
            result.append(item)
        }
        
        onProgress?(ImportProgressInfo(
            current: totalCount,
            total: totalCount,
            progress: 1.0,
            elapsedTime: Date().timeIntervalSince(startTime),
            remainingTime: 0,
            totalEstimatedTime: Date().timeIntervalSince(startTime),
            statusText: "アニメーション情報抽出完了 (全\(totalCount)枚)"
        ))
        
        return result
    }
    
    /// PowerPoint (.pptx) ファイルからスライド一覧を抽出
    public static func parsePowerPointToSlides(
        fileURL: URL,
        onProgress: ((ImportProgressInfo) -> Void)? = nil
    ) -> [SlideItemData] {
        let startTime = Date()
        onProgress?(ImportProgressInfo(
            current: 0,
            total: 0,
            progress: 0.1,
            elapsedTime: 0,
            remainingTime: 0.5,
            totalEstimatedTime: 0.5,
            statusText: "PowerPoint構造を解析中..."
        ))
        
        let fileName = fileURL.deletingPathExtension().lastPathComponent
        let proc = Process()
        proc.launchPath = "/usr/bin/zipinfo"
        proc.arguments = ["-1", fileURL.path]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.standardError = Pipe()
        
        var slideCount = 5
        if let _ = try? proc.run() {
            proc.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let str = String(data: data, encoding: .utf8) {
                let lines = str.components(separatedBy: .newlines)
                let pptSlides = lines.filter { $0.contains("ppt/slides/slide") && $0.hasSuffix(".xml") }
                if !pptSlides.isEmpty {
                    slideCount = pptSlides.count
                }
            }
        }
        
        var result: [SlideItemData] = []
        for i in 1...slideCount {
            result.append(SlideItemData(
                title: "\(fileName) - スライド \(i)",
                noteScript: "霊夢: 「PowerPointから読み込んだスライド \(i) です。」\n魔理沙: 「ゆっくりしていってね！」"
            ))
        }
        
        let elapsed = Date().timeIntervalSince(startTime)
        onProgress?(ImportProgressInfo(
            current: slideCount,
            total: slideCount,
            progress: 1.0,
            elapsedTime: elapsed,
            remainingTime: 0,
            totalEstimatedTime: elapsed,
            statusText: "インポート完了 (全\(slideCount)枚)"
        ))
        
        return result
    }
}


// MARK: - スライドアニメーション共通（走査メタ → プレビュー／書き出し）
public enum SlideAnimationKit {
    public enum Kind: String, Equatable {
        case zoomIn
        case zoomOut
        case fadeIn
        case slideInRight
        case slideUp
        case panRight
        case panLeft
        case kenBurns
        case bounce
    }
    
    public enum Target: String {
        case slide
        case character
        case object
    }
    
    public struct Recipe: Equatable {
        public var kind: Kind
        public var target: Target
        public var raw: String
        public var bounceCount: Int
        
        public init(kind: Kind, target: Target = .slide, raw: String = "", bounceCount: Int = 25) {
            self.kind = kind
            self.target = target
            self.raw = raw
            self.bounceCount = bounceCount
        }
    }
    
    /// Keynoteビルド順／ノート括弧メタをカンマ・読点で分割してレシピ化
    public static func parseRecipes(from meta: String?) -> [Recipe] {
        guard let meta = meta?.trimmingCharacters(in: .whitespacesAndNewlines), !meta.isEmpty else {
            return []
        }
        let parts = meta.components(separatedBy: CharacterSet(charactersIn: ",、\n"))
        var recipes: [Recipe] = []
        for part in parts {
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }
            recipes.append(classify(token: trimmed))
        }
        return recipes
    }
    
    /// スライド映像に焼く主効果（キャラ／テロップ指定は除外し、無ければ kenBurns または bounce）
    public static func primarySlideRecipe(from meta: String?, forceWhenAnimated: Bool) -> Recipe? {
        let recipes = parseRecipes(from: meta)
        if let slide = recipes.first(where: { $0.target == .slide }) {
            return slide
        }
        if let bounce = recipes.first(where: { $0.kind == .bounce }) {
            return bounce
        }
        if let first = recipes.first {
            return first
        }
        // ターゲット未指定のビルド文字列は slide 扱い済み。オブジェクトのみの場合は全体 kenBurns。
        if forceWhenAnimated {
            return Recipe(kind: .kenBurns, target: .slide, raw: meta ?? "")
        }
        return nil
    }
    
    public static func classify(token: String) -> Recipe {
        let lower = token.lowercased()
        var target: Target = .slide
        var anim = lower
        var parsedBounceCount = 25
        
        // "25回" / "26回" などの回数指定をパース
        if let match = token.range(of: "([0-9]+)\\s*回", options: .regularExpression) {
            let numStr = token[match].replacingOccurrences(of: "回", with: "").trimmingCharacters(in: .whitespaces)
            if let c = Int(numStr), c > 0 {
                parsedBounceCount = c
            }
        }
        // 回数が無く秒数だけあるバウンスは Keynote 既定ペース（約1.73回/秒）で推定
        if parsedBounceCount == 25, let dur = extractDurationSeconds(from: token), dur > 0.5 {
            let looksBounce = token.lowercased().contains("bounce") || token.contains("バウンス") || token.contains("呼吸") || token.contains("揺れ")
            if looksBounce {
                parsedBounceCount = max(1, Int((dur * 1.73).rounded()))
            }
        }
        
        if lower.contains(":") || lower.contains("：") {
            let seps = CharacterSet(charactersIn: ":：")
            let bits = lower.components(separatedBy: seps)
            if bits.count >= 2 {
                let t = bits[0].trimmingCharacters(in: .whitespaces)
                anim = bits[1].trimmingCharacters(in: .whitespaces)
                if t.contains("キャラ") || t.contains("立ち絵") {
                    target = .character
                } else if t.contains("テロップ") || t.contains("字幕") || t.contains("オブジェクト") || t.contains("テキスト") {
                    target = .object
                } else if t.contains("スライド") || t.contains("背景") || t.contains("全体") {
                    target = .slide
                } else {
                    // 「対象:効果」で対象が不明ならオブジェクト寄りだが、単一ビルドはスライドへ
                    target = .object
                }
            }
        }
        
        let kind: Kind
        if anim.contains("バウンス") || anim.contains("bounce") || anim.contains("揺れ") || anim.contains("振動") || anim.contains("ピストン") || lower.contains("バウンス") || lower.contains("bounce") {
            kind = .bounce
        } else if anim.contains("縮小") || anim.contains("ズームアウト") || anim.contains("zoom out") || anim.contains("scale down") {
            kind = .zoomOut
        } else if anim.contains("ズーム") || anim.contains("zoom") || anim.contains("拡大") || anim.contains("スケール") || anim.contains("scale") {
            kind = .zoomIn
        } else if anim.contains("フェード") || anim.contains("fade") || anim.contains("ディゾルブ") || anim.contains("dissolve") || anim.contains("出現") || anim.contains("消滅") || anim.contains("溶ける") {
            kind = .fadeIn
        } else if anim.contains("スライドアップ") || anim.contains("slideup") || anim.contains("上から") || anim.contains("下へ") {
            kind = .slideUp
        } else if anim.contains("スライドイン") || anim.contains("slidein") || anim.contains("ビルドイン") || anim.contains("入場") || anim.contains("右から") {
            kind = .slideInRight
        } else if anim.contains("左移動") || anim.contains("左へ") || anim.contains("左パン") {
            kind = .panLeft
        } else if anim.contains("パン") || anim.contains("pan") || anim.contains("右移動") || anim.contains("移動") || anim.contains("ドリフト") {
            kind = .panRight
        } else if lower.contains("アニメーション") && (anim.contains("秒") || lower.contains("秒")) {
            // 「アニメーション: 15秒」など、時間のみ指定されたKeynoteアクションはバウンスとして解釈
            kind = .bounce
        } else {
            // Keynoteの「ビルドの順番」行など未知ラベル → 既定 Ken Burns
            kind = .kenBurns
        }
        return Recipe(kind: kind, target: target, raw: token, bounceCount: parsedBounceCount)
    }
    

    /// トークンから秒数を抽出（例: "バウンス (15.0秒, 26回)" → 15.0）
    public static func extractDurationSeconds(from token: String) -> Double? {
        if let match = token.range(of: "([0-9]+(?:\\.[0-9]+)?)\\s*秒", options: .regularExpression) {
            let numStr = token[match].replacingOccurrences(of: "秒", with: "").trimmingCharacters(in: .whitespaces)
            if let d = Double(numStr), d > 0 { return d }
        }
        if let match = token.range(of: "([0-9]+(?:\\.[0-9]+)?)\\s*s\\b", options: [.regularExpression, .caseInsensitive]) {
            let raw = String(token[match])
            let numStr = raw.lowercased().replacingOccurrences(of: "s", with: "").trimmingCharacters(in: .whitespaces)
            if let d = Double(numStr), d > 0 { return d }
        }
        return nil
    }
    
    /// Keynote アクション・バウンスの周波数（Hz）。回数÷継続時間。
    public static func bounceFrequencyHz(recipe: Recipe, durationHint: Double? = nil) -> Double {
        let count = Double(max(1, recipe.bounceCount > 0 ? recipe.bounceCount : 25))
        let dur = durationHint ?? extractDurationSeconds(from: recipe.raw) ?? (count / 1.73)
        return max(0.4, min(4.0, count / max(dur, 0.25)))
    }
    
    /// ビルド数とノート記載からアニメ尺を推定（未記載時のフォールバック）
    public static func estimateDuration(meta: String?, noteDuration: Double?, buildCount: Int) -> Double? {
        if let d = noteDuration, d > 0.05 { return d }
        if let meta, let d = FileFormatParser.extractDurationFromMeta(meta), d > 0.05 {
            return d
        }
        if buildCount > 0 {
            // 1ビルドあたり約0.6秒、最低3秒・最大30秒
            return min(30.0, max(3.0, Double(buildCount) * 0.6 + 1.5))
        }
        if let meta, !meta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return 5.0
        }
        return nil
    }
    
    /// ffmpeg 用の映像フィルタ（scale/pad 済み前提ではなく、内部で scale+効果まで組む）
    public static func ffmpegVideoFilter(
        recipe: Recipe?,
        width: Int,
        height: Int,
        fps: Int,
        frames: Int
    ) -> String {
        let scaled = "scale=\(width):\(height):force_original_aspect_ratio=decrease,pad=\(width):\(height):(ow-iw)/2:(oh-ih)/2,setsar=1"
        let denom = max(frames - 1, 1)
        let d = frames
        let s = "\(width)x\(height)"
        guard let recipe else {
            return "\(scaled),fps=\(fps),format=yuv420p"
        }
        switch recipe.kind {
        case .zoomIn:
            let zp = "zoompan=z='min(1.12,1.0+0.12*on/\(denom))':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=\(d):s=\(s):fps=\(fps)"
            return "\(scaled),\(zp),format=yuv420p"
        case .zoomOut:
            let zp = "zoompan=z='if(eq(on,0),1.12,max(1.0,1.12-0.12*on/\(denom)))':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=\(d):s=\(s):fps=\(fps)"
            return "\(scaled),\(zp),format=yuv420p"
        case .fadeIn:
            let fadeSec = max(0.15, min(1.5, Double(frames) / Double(max(fps, 1)) * 0.35))
            return "\(scaled),fps=\(fps),fade=t=in:st=0:d=\(String(format: "%.3f", fadeSec)),format=yuv420p"
        case .slideInRight:
            // 右からスライドイン相当: クロップ位置を左へ移動
            let zp = "zoompan=z='1':x='iw*(1-on/\(denom))':y='0':d=\(d):s=\(s):fps=\(fps)"
            return "\(scaled),\(zp),format=yuv420p"
        case .slideUp:
            let zp = "zoompan=z='1':x='0':y='ih*(1-on/\(denom))':d=\(d):s=\(s):fps=\(fps)"
            return "\(scaled),\(zp),format=yuv420p"
        case .panRight:
            let zp = "zoompan=z='1.1':x='iw/10*(on/\(denom))':y='ih/2-(ih/zoom/2)':d=\(d):s=\(s):fps=\(fps)"
            return "\(scaled),\(zp),format=yuv420p"
        case .panLeft:
            let zp = "zoompan=z='1.1':x='iw/10*(1-on/\(denom))':y='ih/2-(ih/zoom/2)':d=\(d):s=\(s):fps=\(fps)"
            return "\(scaled),\(zp),format=yuv420p"
        case .kenBurns:
            let zp = "zoompan=z='min(1.06,1.0+0.06*on/\(denom))':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)-4*on/\(denom)':d=\(d):s=\(s):fps=\(fps)"
            return "\(scaled),\(zp),format=yuv420p"
        case .bounce:
            let cycles = Double(recipe.bounceCount > 0 ? recipe.bounceCount : 25)
            let zp = "zoompan=z='1.04':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)+14*sin(on/\(denom)*\(cycles)*2*PI)':d=\(d):s=\(s):fps=\(fps)"
            // スライド全体ではなくテロップ枠（下部22%）を静止オーバーレイして、キャラクターのみ動かす
            return "split=2[base][over];[base]\(scaled),\(zp)[bounced];[over]\(scaled),crop=iw:ih*0.22:0:ih*0.78[telop];[bounced][telop]overlay=0:H*0.78,format=yuv420p"
        }
    }
}

// MARK: - 音声ファイル自動判定・一括割り当てユーティリティ
public enum SlideAudioMatcher {
    
    /// 指定フォルダ内の全音声ファイル（.wav, .mp3, .m4a, .aiff, .aac）を再帰的または直下から取得
    public static func scanAudioFolder(folderURL: URL) -> [URL] {
        let validExtensions = ["wav", "mp3", "m4a", "aiff", "aif", "aac", "caf", "flac"]
        var results: [URL] = []
        let fileManager = FileManager.default
        
        let enumerator = fileManager.enumerator(
            at: folderURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )
        
        while let fileURL = enumerator?.nextObject() as? URL {
            let ext = fileURL.pathExtension.lowercased()
            if validExtensions.contains(ext) {
                results.append(fileURL)
            }
        }
        
        // ファイル名順（自然順）にソート
        return results.sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }
    
    /// 音声ファイル名からスライド番号（1始まり）および関連情報を抽出
    /// 例: "スライド002_操夢_スライド 2.wav" -> 2
    /// 例: "スライド019_操夢_スライド 19: ※察しのいい人にはPCが見えます。.wav" -> 19
    /// 例: "スライド3.wav" -> 3
    /// 例: "第4幕_霊夢.wav" -> 4
    public static func extractSlideIndex(from rawFileName: String) -> Int? {
        // macOSのファイル名は濁点が分解（NFD）されていることがあるため、NFC（合成済み）に正規化
        let fileName = rawFileName.deletingPathExtension.precomposedStringWithCanonicalMapping
        
        // パターン1: 先頭またはアンダースコア直後の「スライド」+ 数字
        // 例: "スライド002", "スライド 2", "スライド2"
        if let match = fileName.range(of: "(?:^|[_\\-\\s])(?:スライド|slide)\\s*([0-9]{1,4})", options: [.regularExpression, .caseInsensitive]) {
            let matchedStr = String(fileName[match])
            if let numRange = matchedStr.range(of: "[0-9]{1,4}", options: .regularExpression),
               let num = Int(matchedStr[numRange]) {
                return num
            }
        }
        
        // パターン2: 「第X幕」
        if let match = fileName.range(of: "第\\s*([0-9]{1,4})\\s*幕", options: .regularExpression) {
            let matchedStr = String(fileName[match])
            if let numRange = matchedStr.range(of: "[0-9]{1,4}", options: .regularExpression),
               let num = Int(matchedStr[numRange]) {
                return num
            }
        }
        
        // パターン3: 先頭の数字 (例: "002_操夢.wav")
        if let match = fileName.range(of: "^([0-9]{1,4})(?:[_\\-\\s]|$)", options: .regularExpression) {
            let matchedStr = String(fileName[match])
            if let numRange = matchedStr.range(of: "[0-9]{1,4}", options: .regularExpression),
               let num = Int(matchedStr[numRange]) {
                return num
            }
        }
        
        // パターン4: ファイル名内の「スライド」の直後の数字（末尾側も含めて探す）
        if let match = fileName.range(of: "(?:スライド|slide)\\s*([0-9]{1,4})", options: [.regularExpression, .caseInsensitive]) {
            let matchedStr = String(fileName[match])
            if let numRange = matchedStr.range(of: "[0-9]{1,4}", options: .regularExpression),
               let num = Int(matchedStr[numRange]) {
                return num
            }
        }
        
        return nil
    }
    
    /// 音声ファイルの実際の再生時間（秒数）を取得
    public static func getAudioDuration(url: URL) -> Double? {
        if let player = try? AVAudioPlayer(contentsOf: url) {
            let seconds = player.duration
            if seconds.isFinite && seconds > 0.05 {
                return seconds
            }
        }
        return nil
    }
    
    /// 音声ファイル群をシーン（スライド）一覧に一括割り当て
    public static func matchAudioFilesToScenes(
        audioFiles: [URL],
        scenes: [MovieSceneItemData],
        syncSceneDuration: Bool = true
    ) -> (updatedScenes: [MovieSceneItemData], matchedCount: Int, totalAudioSeconds: Double) {
        var updated = scenes
        var matchedCount = 0
        var totalAudioSeconds: Double = 0.0
        
        for audioURL in audioFiles {
            let rawName = audioURL.deletingPathExtension().lastPathComponent
            let normalizedName = rawName.precomposedStringWithCanonicalMapping
            let slideIndexOpt = extractSlideIndex(from: rawName)
            
            var targetIndex: Int? = nil
            
            // 1. スライド番号で直接マッチ
            if let idx = slideIndexOpt, idx >= 1, idx <= scenes.count {
                targetIndex = idx - 1
            } else {
                // 2. タイトル文字列の部分一致・完全一致
                for (i, sc) in updated.enumerated() {
                    let normalizedSceneTitle = sc.title.precomposedStringWithCanonicalMapping
                    // スライド名そのままが含まれているか
                    if normalizedName.contains(normalizedSceneTitle) || normalizedSceneTitle.contains(normalizedName) {
                        targetIndex = i
                        break
                    }
                    // アンダースコア分割のパーツをチェック
                    let parts = normalizedName.components(separatedBy: "_").map { $0.trimmingCharacters(in: .whitespaces) }
                    if parts.contains(where: { !$0.isEmpty && normalizedSceneTitle.contains($0) }) {
                        targetIndex = i
                        break
                    }
                }
            }
            
            if let targetIdx = targetIndex, updated.indices.contains(targetIdx) {
                let dur = getAudioDuration(url: audioURL) ?? 10.0
                updated[targetIdx].audioPath = audioURL.path
                updated[targetIdx].audioFileName = audioURL.lastPathComponent
                updated[targetIdx].audioDuration = dur
                totalAudioSeconds += dur
                matchedCount += 1
                
                if syncSceneDuration {
                    // アニメーション時間が設定されているシーンは、アニメーション秒数を最優先で保護
                    let animDur = updated[targetIdx].animationDuration ?? (updated[targetIdx].animationMeta.flatMap { FileFormatParser.extractDurationFromMeta($0) } ?? 0.0)
                    let baseDur = max(updated[targetIdx].duration, animDur)
                    // 音声がアニメーションよりも長い場合は音声完了まで延長、そうでなければアニメーション時間を確実に保持
                    let newDur = max(baseDur, dur + 0.3)
                    updated[targetIdx].duration = round(newDur * 100) / 100.0
                    if updated[targetIdx].animationDuration == nil && animDur > 0 {
                        updated[targetIdx].animationDuration = animDur
                    }
                }
            }
        }
        
        return (updated, matchedCount, totalAudioSeconds)
    }
    
    /// 既存のシーン一覧から割り当て済み音声を独立した MovieAudioItemData 群として分離抽出
    public static func extractAudioItemsFromScenes(scenes: [MovieSceneItemData]) -> [MovieAudioItemData] {
        var items: [MovieAudioItemData] = []
        var currentTime: Double = 0.0
        
        for (idx, scene) in scenes.enumerated() {
            if let path = scene.audioPath, !path.isEmpty {
                let fileName = scene.audioFileName ?? (path as NSString).lastPathComponent
                let duration = scene.audioDuration ?? 10.0
                let item = MovieAudioItemData(
                    name: "音声\(idx + 1): \(fileName)",
                    audioPath: path,
                    audioFileName: fileName,
                    duration: duration,
                    startTime: currentTime,
                    targetSceneIndex: idx,
                    targetSceneId: scene.id,
                    volume: 1.0,
                    speakerCharacter: scene.speakerCharacter,
                    isMuted: false
                )
                items.append(item)
            }
            currentTime += scene.duration
        }
        return items
    }
    
    /// 音声ファイル群から独立した MovieAudioItemData 一覧を生成し、シーンへの割り当て・開始時間を計算
    public static func createAudioItemsFromFiles(
        audioFiles: [URL],
        scenes: [MovieSceneItemData],
        syncSceneDuration: Bool = true
    ) -> (audioItems: [MovieAudioItemData], updatedScenes: [MovieSceneItemData], matchedCount: Int, totalAudioSeconds: Double) {
        let (updatedScenes, matchedCount, totalAudioSeconds) = matchAudioFilesToScenes(
            audioFiles: audioFiles,
            scenes: scenes,
            syncSceneDuration: syncSceneDuration
        )
        
        var audioItems: [MovieAudioItemData] = []
        // 各シーンの開始時間を事前計算
        var sceneStartTimes: [Double] = []
        var acc: Double = 0.0
        for sc in updatedScenes {
            sceneStartTimes.append(acc)
            acc += sc.duration
        }
        
        for audioURL in audioFiles {
            let rawName = audioURL.deletingPathExtension().lastPathComponent
            let normalizedName = rawName.precomposedStringWithCanonicalMapping
            let slideIndexOpt = extractSlideIndex(from: rawName)
            
            var targetIndex: Int? = nil
            if let idx = slideIndexOpt, idx >= 1, idx <= updatedScenes.count {
                targetIndex = idx - 1
            } else {
                for (i, sc) in updatedScenes.enumerated() {
                    let normalizedSceneTitle = sc.title.precomposedStringWithCanonicalMapping
                    if normalizedName.contains(normalizedSceneTitle) || normalizedSceneTitle.contains(normalizedName) {
                        targetIndex = i
                        break
                    }
                    let parts = normalizedName.components(separatedBy: "_").map { $0.trimmingCharacters(in: .whitespaces) }
                    if parts.contains(where: { !$0.isEmpty && normalizedSceneTitle.contains($0) }) {
                        targetIndex = i
                        break
                    }
                }
            }
            
            let dur = getAudioDuration(url: audioURL) ?? 10.0
            let startT: Double
            let spk: String?
            let targetId: UUID?
            if let tIdx = targetIndex, updatedScenes.indices.contains(tIdx) {
                startT = sceneStartTimes[tIdx]
                spk = updatedScenes[tIdx].speakerCharacter
                targetId = updatedScenes[tIdx].id
            } else {
                startT = 0.0
                spk = nil
                targetId = nil
            }
            
            let item = MovieAudioItemData(
                name: audioURL.lastPathComponent,
                audioPath: audioURL.path,
                audioFileName: audioURL.lastPathComponent,
                duration: dur,
                startTime: startT,
                targetSceneIndex: targetIndex,
                targetSceneId: targetId,
                volume: 1.0,
                speakerCharacter: spk,
                isMuted: false
            )
            audioItems.append(item)
        }
        
        return (audioItems, updatedScenes, matchedCount, totalAudioSeconds)
    }
}

// MARK: - スライド画像自動解決・復元ユーティリティ
public enum SlideImageResolver {
    
    /// スライドの画像パスを検証し、見つからない場合は同名tspmまたはKeynoteから自動復元
    public static func resolveSlideImages(
        scenes: [MovieSceneItemData],
        projectName: String,
        projectURL: URL?
    ) -> [MovieSceneItemData] {
        var updated = scenes
        let fileManager = FileManager.default
        
        // すべての画像が実在するか確認
        var missingIndices: [Int] = []
        for (i, sc) in updated.enumerated() {
            if let path = sc.imagePath, fileManager.fileExists(atPath: path) {
                continue
            }
            missingIndices.append(i)
        }
        
        if missingIndices.isEmpty {
            return updated
        }
        
        // 1. 同名の .tspm から画像パスを検索
        let baseName = projectName
            .replacingOccurrences(of: "\\.[a-zA-Z0-9]+$", with: "", options: .regularExpression)
            .precomposedStringWithCanonicalMapping
        
        let slideScenarioDir = ProjectStorageManager.shared.folderURL(for: .slideScenario)
        var possibleTspmURLs: [URL] = [
            slideScenarioDir.appendingPathComponent("\(baseName).tspm"),
            slideScenarioDir.appendingPathComponent("\(baseName).json")
        ]
        if let pURL = projectURL {
            possibleTspmURLs.append(pURL.deletingPathExtension().appendingPathExtension("tspm"))
        }
        
        var foundSlides: [SlideItemData] = []
        for tspmURL in possibleTspmURLs {
            if fileManager.fileExists(atPath: tspmURL.path),
               let data = try? Data(contentsOf: tspmURL),
               let project = try? JSONDecoder().decode(SlideScenarioProjectData.self, from: data) {
                foundSlides = project.slides
                break
            }
        }
        
        // もし同名で完全一致がなければ、部分一致する .tspm を探す
        if foundSlides.isEmpty {
            if let files = try? fileManager.contentsOfDirectory(atPath: slideScenarioDir.path) {
                for f in files where f.hasSuffix(".tspm") {
                    let normalized = f.precomposedStringWithCanonicalMapping
                    if normalized.contains(baseName) || baseName.contains(normalized.replacingOccurrences(of: ".tspm", with: "")) {
                        let tspmURL = slideScenarioDir.appendingPathComponent(f)
                        if let data = try? Data(contentsOf: tspmURL),
                           let project = try? JSONDecoder().decode(SlideScenarioProjectData.self, from: data) {
                            foundSlides = project.slides
                            break
                        }
                    }
                }
            }
        }
        
        // .tspm から画像パス・セリフを補完
        if !foundSlides.isEmpty {
            for idx in missingIndices {
                if foundSlides.indices.contains(idx) {
                    let slide = foundSlides[idx]
                    if let img = slide.imagePath, fileManager.fileExists(atPath: img) {
                        updated[idx].imagePath = img
                    }
                    if updated[idx].scriptText == nil || updated[idx].scriptText?.isEmpty == true {
                        updated[idx].scriptText = slide.pureScriptText ?? slide.noteScript
                    }
                    if updated[idx].speakerCharacter == nil {
                        updated[idx].speakerCharacter = slide.speakerCharacter
                    }
                    if updated[idx].animationMeta == nil {
                        updated[idx].animationMeta = slide.animationMeta
                    }
                    if updated[idx].animationDuration == nil {
                        updated[idx].animationDuration = slide.animationDuration ?? (slide.animationMeta.flatMap { FileFormatParser.extractDurationFromMeta($0) })
                    }
                    if let animDur = updated[idx].animationDuration, animDur > 0 {
                        updated[idx].duration = max(updated[idx].duration, animDur)
                    }
                }
            }
        }
        
        // それでも画像が見つからないシーンがあるか再チェック
        let stillMissing = updated.indices.filter { idx in
            guard let path = updated[idx].imagePath else { return true }
            return !fileManager.fileExists(atPath: path)
        }
        
        if stillMissing.isEmpty {
            return updated
        }
        
        // 2. Keynote (.key) ファイルから画像を自動再エクスポートして復元
        if let keyURL = findKeynoteFile(baseName: baseName) {
            let cacheDir = slideScenarioDir.appendingPathComponent(".slide_cache/\(baseName)")
            try? fileManager.createDirectory(at: cacheDir, withIntermediateDirectories: true)
            
            // JXA/AppleScriptで画像を出力
            let exportedImages = exportKeynoteSlideImages(keyURL: keyURL, exportDir: cacheDir)
            if !exportedImages.isEmpty {
                for idx in updated.indices {
                    if exportedImages.indices.contains(idx) {
                        updated[idx].imagePath = exportedImages[idx]
                    }
                }
            }
        }
        
        return updated
    }
    
    /// Keynoteファイルを探索（Projects配下、およびiCloud Keynote Documents内）
    public static func findKeynoteFile(baseName: String) -> URL? {
        let fileManager = FileManager.default
        let normalizedBase = baseName.precomposedStringWithCanonicalMapping
        
        // 候補パス
        var searchRoots: [URL] = [
            ProjectStorageManager.shared.folderURL(for: .slideScenario),
            ProjectStorageManager.shared.folderURL(for: .movie),
            ProjectStorageManager.shared.projectsRootURL
        ]
        
        // iCloud Keynoteフォルダ
        let icloudKeynote = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~Keynote/Documents", isDirectory: true)
        if fileManager.fileExists(atPath: icloudKeynote.path) {
            searchRoots.append(icloudKeynote)
        }
        
        for root in searchRoots {
            if let enumerator = fileManager.enumerator(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
                while let url = enumerator.nextObject() as? URL {
                    if url.pathExtension.lowercased() == "key" {
                        let name = url.deletingPathExtension().lastPathComponent.precomposedStringWithCanonicalMapping
                        if name == normalizedBase || name.contains(normalizedBase) || normalizedBase.contains(name) {
                            return url
                        }
                    }
                }
            }
        }
        return nil
    }
    
    /// Keynoteからスライド画像をキャッシュディレクトリにエクスポート
    private static func exportKeynoteSlideImages(keyURL: URL, exportDir: URL) -> [String] {
        let path = keyURL.path
        let escapedPath = path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let exportScript = """
        tell application id "com.apple.Keynote"
            with timeout of 60 seconds
                set doc to open POSIX file "\(escapedPath)"
                try
                    export doc to POSIX file "\(exportDir.path)" as slide images with properties {image format:JPEG}
                end try
                close doc saving no
            end timeout
        end tell
        """
        let proc = Process()
        proc.launchPath = "/usr/bin/osascript"
        proc.arguments = ["-e", exportScript]
        proc.standardError = Pipe()
        try? proc.run()
        proc.waitUntilExit()
        
        if let files = try? FileManager.default.contentsOfDirectory(atPath: exportDir.path) {
            let jpegs = files.filter { $0.hasSuffix(".jpeg") || $0.hasSuffix(".jpg") || $0.hasSuffix(".png") }
                .sorted { $0.localizedStandardCompare($1) == .orderedAscending }
            return jpegs.map { exportDir.appendingPathComponent($0).path }
        }
        return []
    }
}

private extension String {
    var deletingPathExtension: String {
        return (self as NSString).deletingPathExtension
    }
}
