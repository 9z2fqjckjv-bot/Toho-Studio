import Foundation
import AVFoundation
import CoreMedia

// MARK: - Software Modules (内蔵ソフト)
public enum SoftwareModule: String, CaseIterable, Identifiable {
    case movieMaker = "ムービーメーカー"
    case characterMaker = "キャラクターメーカー"
    case soundMaker = "サウンドメーカー"
    case slideScenarioMaker = "スライド＆シナリオメーカー"
    case gameMaker = "ゲームメーカー"
    case materialStudio = "素材スタジオ"
    case tohoAIStudio = "TohoAIStudio"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .movieMaker: return "film"
        case .characterMaker: return "person.crop.artframe"
        case .soundMaker: return "waveform"
        case .slideScenarioMaker: return "doc.richtext"
        case .gameMaker: return "gamecontroller"
        case .materialStudio: return "folder.badge.gearshape"
        case .tohoAIStudio: return "sparkles"
        }
    }

    public var baseModel: String {
        switch self {
        case .movieMaker: return "GoogleVids"
        case .characterMaker: return "Google図形描画"
        case .soundMaker: return "AquesTalk / Audition"
        case .slideScenarioMaker: return "Googleスライド / Keynote"
        case .gameMaker: return "横長ワイドRPG / ノベルエンジン"
        case .materialStudio: return "共通基幹ストレージ＆ストア"
        case .tohoAIStudio: return "仮想LinuxVM (Google Gemma 2 / Meta Llama 3.2) + 外部API"
        }
    }

    public var description: String {
        switch self {
        case .movieMaker:
            return "スライドや音声、テロップをタイムライン上で編集し、動画を作成・出力するソフト。"
        case .characterMaker:
            return "立ち絵のパーツ分割、表情・衣装・色調の変更、自由な組み立てを行うソフト。"
        case .soundMaker:
            return "AquesTalkによるゆっくりボイス生成、BGM・効果音のミキシング・編集を行うソフト。"
        case .slideScenarioMaker:
            return "スライド作成と台本シナリオ編集、およびKeynote高精度認識プログラムを内蔵したソフト。"
        case .gameMaker:
            return "スライド・シナリオ・音声を連携させ、コマンド分岐やRPG・ノベルゲームを制作するソフト。"
        case .materialStudio:
            return "作品・素材の一元管理、クラウド同期、検索・置換・抽出フィルター、セキュリティ対策を担う中枢ソフト。"
        case .tohoAIStudio:
            return "仮想LinuxVMおよびGemini・ChatGPT・Claudeと連携し、AIチャット・AI編集・請求確認・リソース管理を行う東方制作AI中枢ソフト。"
        }
    }

    /// 仕様書記載の編集ファイル拡張子 (Slide 178, 192, 214, 228, 241, 新版仕様書)
    public var projectExtension: String {
        switch self {
        case .movieMaker: return "tsvm"
        case .characterMaker: return "tscm"
        case .soundMaker: return "tssm"
        case .slideScenarioMaker: return "tspm" // 仕様書 Slide 228: 編集ファイル拡張子: tspm
        case .gameMaker: return "tsgm"
        case .materialStudio: return "tohoproj"
        case .tohoAIStudio: return "tsai"
        }
    }
}

// MARK: - Movie Maker Models
public struct MovieScene: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var title: String
    public var duration: Double // seconds
    public var slideTitle: String
    public var backgroundName: String
    public var characterName: String
    public var telop: String
    public var audioTrack: String?
    public var animationName: String?
    public var transitionName: String?
    public var animationDuration: Double? = nil
    public var animationNote: String? = nil
    public var slideImagePath: String? = nil
    public var videoPath: String? = nil
    public var backgroundImagePath: String? = nil
    public var characterImagePath: String? = nil
    public var voiceAudioPath: String? = nil
    public var voiceCharacter: String? = nil
    public var voiceDuration: Double? = nil
    public var bgmAudioPath: String? = nil
    public var bgmName: String? = nil
    public var seAudioPath: String? = nil
    public var seName: String? = nil

    public init(
        id: UUID = UUID(),
        title: String,
        duration: Double,
        slideTitle: String,
        backgroundName: String,
        characterName: String,
        telop: String,
        audioTrack: String? = nil,
        animationName: String? = nil,
        transitionName: String? = nil,
        animationDuration: Double? = nil,
        animationNote: String? = nil,
        slideImagePath: String? = nil,
        videoPath: String? = nil,
        backgroundImagePath: String? = nil,
        characterImagePath: String? = nil,
        voiceAudioPath: String? = nil,
        voiceCharacter: String? = nil,
        voiceDuration: Double? = nil,
        bgmAudioPath: String? = nil,
        bgmName: String? = nil,
        seAudioPath: String? = nil,
        seName: String? = nil
    ) {
        self.id = id
        self.title = title
        self.duration = duration
        self.slideTitle = slideTitle
        self.backgroundName = backgroundName
        self.characterName = characterName
        self.telop = telop
        self.audioTrack = audioTrack
        self.animationName = animationName
        self.transitionName = transitionName
        self.animationDuration = animationDuration
        self.animationNote = animationNote
        self.slideImagePath = slideImagePath
        self.videoPath = videoPath
        self.backgroundImagePath = backgroundImagePath
        self.characterImagePath = characterImagePath
        self.voiceAudioPath = voiceAudioPath
        self.voiceCharacter = voiceCharacter
        self.voiceDuration = voiceDuration
        self.bgmAudioPath = bgmAudioPath
        self.bgmName = bgmName
        self.seAudioPath = seAudioPath
        self.seName = seName
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.title = try container.decode(String.self, forKey: .title)
        self.duration = try container.decode(Double.self, forKey: .duration)
        self.slideTitle = try container.decodeIfPresent(String.self, forKey: .slideTitle) ?? ""
        self.backgroundName = try container.decodeIfPresent(String.self, forKey: .backgroundName) ?? ""
        self.characterName = try container.decodeIfPresent(String.self, forKey: .characterName) ?? ""
        self.telop = try container.decodeIfPresent(String.self, forKey: .telop) ?? ""
        self.audioTrack = try container.decodeIfPresent(String.self, forKey: .audioTrack)
        self.animationName = try container.decodeIfPresent(String.self, forKey: .animationName)
        self.transitionName = try container.decodeIfPresent(String.self, forKey: .transitionName)
        self.animationDuration = try container.decodeIfPresent(Double.self, forKey: .animationDuration)
        self.animationNote = try container.decodeIfPresent(String.self, forKey: .animationNote)
        self.slideImagePath = try container.decodeIfPresent(String.self, forKey: .slideImagePath)
        self.videoPath = try container.decodeIfPresent(String.self, forKey: .videoPath)
        self.backgroundImagePath = try container.decodeIfPresent(String.self, forKey: .backgroundImagePath)
        self.characterImagePath = try container.decodeIfPresent(String.self, forKey: .characterImagePath)
        self.voiceAudioPath = try container.decodeIfPresent(String.self, forKey: .voiceAudioPath)
        self.voiceCharacter = try container.decodeIfPresent(String.self, forKey: .voiceCharacter)
        self.voiceDuration = try container.decodeIfPresent(Double.self, forKey: .voiceDuration)
        self.bgmAudioPath = try container.decodeIfPresent(String.self, forKey: .bgmAudioPath)
        self.bgmName = try container.decodeIfPresent(String.self, forKey: .bgmName)
        self.seAudioPath = try container.decodeIfPresent(String.self, forKey: .seAudioPath)
        self.seName = try container.decodeIfPresent(String.self, forKey: .seName)
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, duration, slideTitle, backgroundName, characterName, telop
        case audioTrack, animationName, transitionName, animationDuration, animationNote
        case slideImagePath, videoPath, backgroundImagePath, characterImagePath
        case voiceAudioPath, voiceCharacter, voiceDuration, bgmAudioPath, bgmName, seAudioPath, seName
    }

    /// クリーンなテロップ/セリフ（()書き表記（アニメーション）や話者タグを除外したテキスト）
    public var displayTelop: String {
        return SlideItem.cleanDialogueText(from: telop)
    }

    /// 重複した「シーン X: シーン X」などの表記を整理したクリーンな表示用タイトル
    public var displayCleanTitle: String {
        let t = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = t.components(separatedBy: ": ")
        if parts.count >= 2 {
            let p0 = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let p1 = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if p0 == p1 {
                return parts.dropFirst().joined(separator: ": ")
            }
        }
        return t
    }
}

// MARK: - Character Maker Models
public struct CharacterPart: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var name: String // "目", "口", "顔輪郭", "体", "装飾", "髪", "箒", "第3の目", "帽子", "背景", "テロップ"
    public var assetPath: String
    public var offsetX: Double = 0.0
    public var offsetY: Double = 0.0
    public var scale: Double = 1.0
    public var rotation: Double = 0.0 // 回転角度 (-180...180)
    public var opacity: Double = 1.0  // 不透明度 (0.0...1.0)
    public var colorTintHex: String = "#FFFFFF"
    public var hue: Double = 0.0       // 色相 (-180...180)
    public var saturation: Double = 1.0 // 彩度 (0.0...2.0)
    public var brightness: Double = 0.0 // 明度 (-1.0...1.0)
    public var contrast: Double = 1.0   // コントラスト (0.0...2.0)
    public var cropX: Double = 0.0      // トリミング矩形 (正規化 0...1)
    public var cropY: Double = 0.0
    public var cropW: Double = 1.0
    public var cropH: Double = 1.0
    public var isVisible: Bool = true
    public var blendMode: String = "通常" // 通常, 乗算, スクリーン, オーバーレイ
    public var filterEffects: [String] = [] // Photoshop/Pixelmator: ドロップシャドウ, 境界線, ぼかし, シャープ, セピア, モノクロ
    public var backAssetPath: String = "" // 背中側（後ろ姿）パーツ用画像パス
    public var facingMode: String = "両面" // "両面", "前面のみ", "背面のみ"

    public init(
        id: UUID = UUID(),
        name: String,
        assetPath: String,
        offsetX: Double = 0.0,
        offsetY: Double = 0.0,
        scale: Double = 1.0,
        rotation: Double = 0.0,
        opacity: Double = 1.0,
        colorTintHex: String = "#FFFFFF",
        hue: Double = 0.0,
        saturation: Double = 1.0,
        brightness: Double = 0.0,
        contrast: Double = 1.0,
        cropX: Double = 0.0,
        cropY: Double = 0.0,
        cropW: Double = 1.0,
        cropH: Double = 1.0,
        isVisible: Bool = true,
        blendMode: String = "通常",
        filterEffects: [String] = [],
        backAssetPath: String = "",
        facingMode: String = "両面"
    ) {
        self.id = id
        self.name = name
        self.assetPath = assetPath
        self.offsetX = offsetX
        self.offsetY = offsetY
        self.scale = scale
        self.rotation = rotation
        self.opacity = opacity
        self.colorTintHex = colorTintHex
        self.hue = hue
        self.saturation = saturation
        self.brightness = brightness
        self.contrast = contrast
        self.cropX = cropX
        self.cropY = cropY
        self.cropW = cropW
        self.cropH = cropH
        self.isVisible = isVisible
        self.blendMode = blendMode
        self.filterEffects = filterEffects
        self.backAssetPath = backAssetPath
        self.facingMode = facingMode
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.assetPath = try container.decode(String.self, forKey: .assetPath)
        self.offsetX = try container.decodeIfPresent(Double.self, forKey: .offsetX) ?? 0.0
        self.offsetY = try container.decodeIfPresent(Double.self, forKey: .offsetY) ?? 0.0
        self.scale = try container.decodeIfPresent(Double.self, forKey: .scale) ?? 1.0
        self.rotation = try container.decodeIfPresent(Double.self, forKey: .rotation) ?? 0.0
        self.opacity = try container.decodeIfPresent(Double.self, forKey: .opacity) ?? 1.0
        self.colorTintHex = try container.decodeIfPresent(String.self, forKey: .colorTintHex) ?? "#FFFFFF"
        self.hue = try container.decodeIfPresent(Double.self, forKey: .hue) ?? 0.0
        self.saturation = try container.decodeIfPresent(Double.self, forKey: .saturation) ?? 1.0
        self.brightness = try container.decodeIfPresent(Double.self, forKey: .brightness) ?? 0.0
        self.contrast = try container.decodeIfPresent(Double.self, forKey: .contrast) ?? 1.0
        self.cropX = try container.decodeIfPresent(Double.self, forKey: .cropX) ?? 0.0
        self.cropY = try container.decodeIfPresent(Double.self, forKey: .cropY) ?? 0.0
        self.cropW = try container.decodeIfPresent(Double.self, forKey: .cropW) ?? 1.0
        self.cropH = try container.decodeIfPresent(Double.self, forKey: .cropH) ?? 1.0
        self.isVisible = try container.decodeIfPresent(Bool.self, forKey: .isVisible) ?? true
        self.blendMode = try container.decodeIfPresent(String.self, forKey: .blendMode) ?? "通常"
        self.filterEffects = try container.decodeIfPresent([String].self, forKey: .filterEffects) ?? []
        self.backAssetPath = try container.decodeIfPresent(String.self, forKey: .backAssetPath) ?? ""
        self.facingMode = try container.decodeIfPresent(String.self, forKey: .facingMode) ?? "両面"
    }
}

public struct CharacterModel: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var name: String
    public var baseImagePath: String = ""
    public var parts: [CharacterPart]
    public var expression: String = "通常"
    public var canvasWidth: Double = 1080
    public var canvasHeight: Double = 1080
    public var backgroundColor: String = "透過市松模様"
    public var initialSnapshotData: Data? = nil // 再生成(cmd+e+p)用の初期状態スナップショット
    public var isBackView: Bool = false // 前後反転フラグ (false: 前面/正面, true: 背面/背中側)
    public var backImagePath: String = "" // 背中側専用画像パス

    public init(
        id: UUID = UUID(),
        name: String,
        baseImagePath: String = "",
        parts: [CharacterPart],
        expression: String = "通常",
        canvasWidth: Double = 1080,
        canvasHeight: Double = 1080,
        backgroundColor: String = "透過市松模様",
        initialSnapshotData: Data? = nil,
        isBackView: Bool = false,
        backImagePath: String = ""
    ) {
        self.id = id
        self.name = name
        self.baseImagePath = baseImagePath
        self.parts = parts
        self.expression = expression
        self.canvasWidth = canvasWidth
        self.canvasHeight = canvasHeight
        self.backgroundColor = backgroundColor
        self.initialSnapshotData = initialSnapshotData
        self.isBackView = isBackView
        self.backImagePath = backImagePath
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.baseImagePath = try container.decodeIfPresent(String.self, forKey: .baseImagePath) ?? ""
        self.parts = try container.decodeIfPresent([CharacterPart].self, forKey: .parts) ?? []
        self.expression = try container.decodeIfPresent(String.self, forKey: .expression) ?? "通常"
        self.canvasWidth = try container.decodeIfPresent(Double.self, forKey: .canvasWidth) ?? 1080
        self.canvasHeight = try container.decodeIfPresent(Double.self, forKey: .canvasHeight) ?? 1080
        self.backgroundColor = try container.decodeIfPresent(String.self, forKey: .backgroundColor) ?? "透過市松模様"
        self.initialSnapshotData = try container.decodeIfPresent(Data.self, forKey: .initialSnapshotData)
        self.isBackView = try container.decodeIfPresent(Bool.self, forKey: .isBackView) ?? false
        self.backImagePath = try container.decodeIfPresent(String.self, forKey: .backImagePath) ?? ""
    }
}

// MARK: - Sound Maker Models
public enum VoiceType: String, CaseIterable, Identifiable, Codable {
    case f1 = "女声1 (標準)"
    case f2 = "女声2 (高め)"
    case f3 = "女声3 (落ち着き)"
    case m1 = "男声1"
    case m2 = "男声2"
    case r1 = "ロボット"
    case imd1 = "中性"
    case jgr = "機械1 (jgr)"

    public var id: String { rawValue }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let raw = try container.decode(String.self)
        if let match = VoiceType(rawValue: raw) {
            self = match
        } else if raw == "児童" || raw == "jgr" || raw == "機械1" {
            self = .jgr
        } else if raw == "f1" || raw == "女声1" {
            self = .f1
        } else if raw == "f2" || raw == "女声2" {
            self = .f2
        } else if raw == "f3" || raw == "女声3" {
            self = .f3
        } else if raw == "m1" || raw == "男声1" {
            self = .m1
        } else if raw == "m2" || raw == "男声2" {
            self = .m2
        } else if raw == "imd1" || raw == "中性" {
            self = .imd1
        } else if raw == "r1" || raw == "ロボット" {
            self = .r1
        } else {
            self = .f1
        }
    }

    public var dylibSuffix: String {
        switch self {
        case .f1: return "f1"
        case .f2: return "f2"
        case .f3: return "f3"
        case .m1: return "m1"
        case .m2: return "m2"
        case .r1: return "r1"
        case .imd1: return "imd1"
        case .jgr: return "jgr"
        }
    }

    public var displayShortName: String {
        switch self {
        case .f1: return "女声1 (f1)"
        case .f2: return "女声2 (f2)"
        case .f3: return "女声3 (f3)"
        case .m1: return "男声1 (m1)"
        case .m2: return "男声2 (m2)"
        case .r1: return "ロボット (r1)"
        case .imd1: return "中性 (imd1)"
        case .jgr: return "機械1 (jgr)"
        }
    }
}

public struct VoiceTemplate: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var name: String
    public var characterName: String
    public var voiceType: VoiceType
    public var speed: Int // 50...200
    public var pitch: Int // 音程
    public var source: String // "コゲの日記", "独自テンプレート", "Gスカのブログ", "ゆっくりボイスメーカー", "カスタム"
    public var description: String
    public var isCustom: Bool = false
    public var baseTemplateName: String? = nil

    public init(
        id: UUID = UUID(),
        name: String,
        characterName: String,
        voiceType: VoiceType,
        speed: Int = 100,
        pitch: Int = 100,
        source: String,
        description: String = "",
        isCustom: Bool = false,
        baseTemplateName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.characterName = characterName
        self.voiceType = voiceType
        self.speed = speed
        self.pitch = pitch
        self.source = source
        self.description = description
        self.isCustom = isCustom
        self.baseTemplateName = baseTemplateName
    }
}

public enum LayoutPreset: String, CaseIterable, Identifiable {
    case standard = "標準"
    case timeline = "タイムライン重視"
    case preview = "プレビュー最大化"
    case inspector = "インスペクター重視"
    case verticalVideo = "縦長動画 (9:16)"
    case squareVideo = "正方形動画 (1:1)"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .standard: return "プレビューとタイムラインの標準均等配置 (16:9)"
        case .timeline: return "タイムライン・波形トラックを画面下部広範囲に最大化"
        case .preview: return "プレビュー映像・スライドを大画面シアター表示"
        case .inspector: return "AquesTalk音声合成・プロパティ調整パネルを拡張"
        case .verticalVideo: return "スマートフォン・ショート動画向け縦長アスペクト比 (9:16) [仕様書Slide 178]"
        case .squareVideo: return "SNS・アイコン向けスクエア正方形アスペクト比 (1:1) [仕様書Slide 178]"
        }
    }
}

public struct AudioTrack: Identifiable, Codable, Equatable {
    public var id: String
    public var name: String
    public var type: String // "movie", "voice", "se", "bgm"
    public var icon: String
    public var colorHex: String
    public var volume: Double = 0.8
    public var pan: Double = 0.0
    public var isMuted: Bool = false
    public var isSolo: Bool = false
    public var isRecordArm: Bool = false
    public var characterName: String?

    public init(
        id: String = UUID().uuidString,
        name: String,
        type: String,
        icon: String,
        colorHex: String,
        volume: Double = 0.8,
        pan: Double = 0.0,
        isMuted: Bool = false,
        isSolo: Bool = false,
        isRecordArm: Bool = false,
        characterName: String? = nil
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.icon = icon
        self.colorHex = colorHex
        self.volume = volume
        self.pan = pan
        self.isMuted = isMuted
        self.isSolo = isSolo
        self.isRecordArm = isRecordArm
        self.characterName = characterName
    }
}

public struct SoundClip: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var name: String
    public var type: String // "BGM", "SE", "Voice", "Movie"
    public var character: String?
    public var text: String?
    public var voiceSymbol: String?
    public var duration: Double
    public var volume: Double = 1.0
    public var speed: Int = 100
    public var startTime: Double = 0.0
    public var trackId: String? = nil
    public var pan: Double = 0.0
    public var colorHex: String? = nil
    public var waveformPoints: [Float]? = nil
    // シーン連携 & 複数シーン跨ぎ再生プロパティ
    public var sceneIndex: Int? = nil // 所属シーン番号 (1-based)
    public var spanStartSceneIndex: Int? = nil // 複数シーン跨ぎ開始シーン (1-based)
    public var spanEndSceneIndex: Int? = nil // 複数シーン跨ぎ終了シーン (1-based)
    public var fadeInDuration: Double = 0.0 // フェードイン秒数
    public var fadeOutDuration: Double = 0.0 // フェードアウト秒数
    public var isLooping: Bool = false // ループ再生
    public var audioFilePath: String? = nil // 生成または読み込みファイルパス
    public var voiceType: VoiceType? = nil // キャラボイス時の声種
    public var pitch: Int = 100 // 音程
    public var playbackRate: Double = 1.0 // 倍速再生レート (0.5x〜2.0x、デフォルト1.0)
    public var isReversed: Bool = false // 逆再生モード (デフォルトfalse)
    public var isCutOffOnSceneEnd: Bool = true // シーンの長さより効果音が長い場合にシーン切り替えと同時に即切り (デフォルトtrue)

    public var isSpanningScenes: Bool {
        if let s = spanStartSceneIndex, let e = spanEndSceneIndex, e > s {
            return true
        }
        return false
    }

    /// 再生速度を考慮した実効再生秒数
    public var effectiveDuration: Double {
        let rate = max(0.25, playbackRate)
        return max(0.1, duration / rate)
    }

    public init(
        id: UUID = UUID(),
        name: String,
        type: String,
        character: String? = nil,
        text: String? = nil,
        voiceSymbol: String? = nil,
        duration: Double,
        volume: Double = 1.0,
        speed: Int = 100,
        startTime: Double = 0.0,
        trackId: String? = nil,
        pan: Double = 0.0,
        colorHex: String? = nil,
        waveformPoints: [Float]? = nil,
        sceneIndex: Int? = nil,
        spanStartSceneIndex: Int? = nil,
        spanEndSceneIndex: Int? = nil,
        fadeInDuration: Double = 0.0,
        fadeOutDuration: Double = 0.0,
        isLooping: Bool = false,
        audioFilePath: String? = nil,
        voiceType: VoiceType? = nil,
        pitch: Int = 100,
        playbackRate: Double = 1.0,
        isReversed: Bool = false,
        isCutOffOnSceneEnd: Bool = true
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.character = character
        self.text = text
        self.voiceSymbol = voiceSymbol
        self.duration = duration
        self.volume = volume
        self.speed = speed
        self.startTime = startTime
        self.trackId = trackId
        self.pan = pan
        self.colorHex = colorHex
        self.waveformPoints = waveformPoints
        self.sceneIndex = sceneIndex
        self.spanStartSceneIndex = spanStartSceneIndex
        self.spanEndSceneIndex = spanEndSceneIndex
        self.fadeInDuration = fadeInDuration
        self.fadeOutDuration = fadeOutDuration
        self.isLooping = isLooping
        self.audioFilePath = audioFilePath
        self.voiceType = voiceType
        self.pitch = pitch
        self.playbackRate = playbackRate
        self.isReversed = isReversed
        self.isCutOffOnSceneEnd = isCutOffOnSceneEnd
    }

    // 後方互換性デコーダー
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        self.name = try container.decode(String.self, forKey: .name)
        self.type = try container.decode(String.self, forKey: .type)
        self.character = try container.decodeIfPresent(String.self, forKey: .character)
        self.text = try container.decodeIfPresent(String.self, forKey: .text)
        self.voiceSymbol = try container.decodeIfPresent(String.self, forKey: .voiceSymbol)
        self.duration = try container.decode(Double.self, forKey: .duration)
        self.volume = try container.decodeIfPresent(Double.self, forKey: .volume) ?? 1.0
        self.speed = try container.decodeIfPresent(Int.self, forKey: .speed) ?? 100
        self.startTime = try container.decodeIfPresent(Double.self, forKey: .startTime) ?? 0.0
        self.trackId = try container.decodeIfPresent(String.self, forKey: .trackId)
        self.pan = try container.decodeIfPresent(Double.self, forKey: .pan) ?? 0.0
        self.colorHex = try container.decodeIfPresent(String.self, forKey: .colorHex)
        self.waveformPoints = try container.decodeIfPresent([Float].self, forKey: .waveformPoints)
        self.sceneIndex = try container.decodeIfPresent(Int.self, forKey: .sceneIndex)
        self.spanStartSceneIndex = try container.decodeIfPresent(Int.self, forKey: .spanStartSceneIndex)
        self.spanEndSceneIndex = try container.decodeIfPresent(Int.self, forKey: .spanEndSceneIndex)
        self.fadeInDuration = try container.decodeIfPresent(Double.self, forKey: .fadeInDuration) ?? 0.0
        self.fadeOutDuration = try container.decodeIfPresent(Double.self, forKey: .fadeOutDuration) ?? 0.0
        self.isLooping = try container.decodeIfPresent(Bool.self, forKey: .isLooping) ?? false
        self.audioFilePath = try container.decodeIfPresent(String.self, forKey: .audioFilePath)
        self.voiceType = try container.decodeIfPresent(VoiceType.self, forKey: .voiceType)
        self.pitch = try container.decodeIfPresent(Int.self, forKey: .pitch) ?? 100
        self.playbackRate = try container.decodeIfPresent(Double.self, forKey: .playbackRate) ?? 1.0
        self.isReversed = try container.decodeIfPresent(Bool.self, forKey: .isReversed) ?? false
        self.isCutOffOnSceneEnd = try container.decodeIfPresent(Bool.self, forKey: .isCutOffOnSceneEnd) ?? (self.type == "SE")
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, type, character, text, voiceSymbol, duration, volume, speed
        case startTime, trackId, pan, colorHex, waveformPoints, sceneIndex
        case spanStartSceneIndex, spanEndSceneIndex, fadeInDuration, fadeOutDuration
        case isLooping, audioFilePath, voiceType, pitch, playbackRate, isReversed
        case isCutOffOnSceneEnd
    }
}

// MARK: - Sound Maker Project Document (完全保存・読み込み用)
public struct SoundMakerProjectDocument: Codable {
    public var version: String = "2.0"
    public var clips: [SoundClip]
    public var tracks: [AudioTrack]?
    public var scenes: [MovieScene]?
    public var totalDuration: Double?

    public init(
        version: String = "2.0",
        clips: [SoundClip],
        tracks: [AudioTrack]? = nil,
        scenes: [MovieScene]? = nil,
        totalDuration: Double? = nil
    ) {
        self.version = version
        self.clips = clips
        self.tracks = tracks
        self.scenes = scenes
        self.totalDuration = totalDuration
    }
}

// MARK: - Audio Preset Models
public struct AudioPresetItem: Identifiable, Equatable {
    public var id: String { name }
    public var name: String
    public var type: String // "BGM" or "SE"
    public var category: String // "東方原曲風", "日常・解説", "緊迫・戦闘", "システム", "演出"
    public var description: String
    public var defaultDuration: Double
    public var defaultVolume: Double
    public var isLoopable: Bool

    public init(name: String, type: String, category: String, description: String, defaultDuration: Double, defaultVolume: Double = 0.8, isLoopable: Bool = true) {
        self.name = name
        self.type = type
        self.category = category
        self.description = description
        self.defaultDuration = defaultDuration
        self.defaultVolume = defaultVolume
        self.isLoopable = isLoopable
    }
}

// MARK: - Slide & Scenario Maker Models
public struct SlideAnimationItem: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var targetObjectName: String
    public var animationKind: String // "in", "action", "out"
    public var effect: String // "バウンス", "回転", "フェードイン", "ディゾルブ", etc.
    public var duration: Double // seconds
    public var order: Int
    public var bounceCount: Int? = nil
    public var decay: Bool? = nil
    public var rotationAngle: Double? = nil
    public var rotationCount: Int? = nil
    public var rotationDirection: String? = nil
    public var speedChange: String? = nil

    public init(
        id: UUID = UUID(),
        targetObjectName: String,
        animationKind: String,
        effect: String,
        duration: Double = 3.0,
        order: Int = 1,
        bounceCount: Int? = nil,
        decay: Bool? = nil,
        rotationAngle: Double? = nil,
        rotationCount: Int? = nil,
        rotationDirection: String? = nil,
        speedChange: String? = nil
    ) {
        self.id = id
        self.targetObjectName = targetObjectName
        self.animationKind = animationKind
        self.effect = effect
        self.duration = duration
        self.order = order
        self.bounceCount = bounceCount
        self.decay = decay
        self.rotationAngle = rotationAngle
        self.rotationCount = rotationCount
        self.rotationDirection = rotationDirection
        self.speedChange = speedChange
    }
}

public struct BuildOrderItem: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var order: Int
    public var objectName: String
    public var effect: String
    public var trigger: String // "クリック時", "前のアニメーションと同時", "前のアニメーションの後"
    public var delay: Double // seconds

    public init(
        id: UUID = UUID(),
        order: Int,
        objectName: String,
        effect: String,
        trigger: String = "クリック時",
        delay: Double = 0.0
    ) {
        self.id = id
        self.order = order
        self.objectName = objectName
        self.effect = effect
        self.trigger = trigger
        self.delay = delay
    }
}

public struct SlideObjectItem: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var name: String
    public var objectType: String // "background", "character", "telop", "image", "shape", "text"
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    public var text: String?
    public var imagePath: String?
    public var characterName: String?
    public var animations: [SlideAnimationItem] = []

    public init(
        id: UUID = UUID(),
        name: String,
        objectType: String,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        text: String? = nil,
        imagePath: String? = nil,
        characterName: String? = nil,
        animations: [SlideAnimationItem] = []
    ) {
        self.id = id
        self.name = name
        self.objectType = objectType
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.text = text
        self.imagePath = imagePath
        self.characterName = characterName
        self.animations = animations
    }
}

public struct SlideItem: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var slideIndex: Int
    public var title: String
    public var telop: String
    public var presenterNote: String
    public var backgroundName: String
    public var characterName: String
    public var detectedObjects: [String] = []
    public var animationTag: String = "なし"
    public var transitionTag: String = "フェード"

    // 指示書準拠: スライド種別、表示時間、トランジション設定、アニメーション＆ビルド順
    public var slideType: String = "content" // "title", "sectionHeader", "content"
    public var duration: Double = 3.0 // 秒数 (タイトル/中扉はデフォルト3秒、アニメーション指定により可変)
    public var transitionEffect: String = "なし"
    public var transitionTrigger: String = "クリック時" // "クリック時", "自動"
    public var transitionDelay: Double = 0.0
    public var transitionDuration: Double = 1.0
    public var animations: [SlideAnimationItem] = []
    public var buildOrder: [BuildOrderItem] = []

    // 高精度レイアウト・画像連携拡張プロパティ
    public var slideWidth: Double = 1920
    public var slideHeight: Double = 1080
    public var backgroundImagePath: String? = nil
    public var backgroundX: Double = 0
    public var backgroundY: Double = 0
    public var backgroundWidth: Double = 1920
    public var backgroundHeight: Double = 1080

    public var characterImagePath: String? = nil
    public var characterX: Double? = nil
    public var characterY: Double? = nil
    public var characterWidth: Double? = nil
    public var characterHeight: Double? = nil

    public var telopX: Double? = nil
    public var telopY: Double? = nil
    public var telopWidth: Double? = nil
    public var telopHeight: Double? = nil

    public var objects: [SlideObjectItem] = []
    public var slideImagePath: String? = nil // Keynoteから抽出されたスライド画面そのものの高解像度レンダリング画像パス (1920x1080)
    public var animationVideoPath: String? = nil // アニメーションがあるスライドの記録動画パス (.m4v/.mp4)
    public var rawPresenterNote: String? = nil // ノート生データ (カッコ書き"（）,(),[]"含む元データ)

    /// UI表示用ノート（カッコ書き"（）,(),[]"および()書き表記（アニメーション）を完全に除外してUIに表示する）
    public var displayPresenterNote: String {
        return SlideItem.cleanDialogueText(from: presenterNote)
    }

    /// UI表示用テロップ（セリフ文後の()書き表記（アニメーション）や話者タグを除外してUIに表示する）
    public var displayTelop: String {
        return SlideItem.cleanDialogueText(from: telop)
    }

    /// スライド上のアニメーション指定時間（秒数）
    /// （例: "（アニメーション: 15秒）" -> 15.0, "（アニメーションに合わせる）" -> アニメーション動画尺）
    public var animationTimingDuration: Double? {
        let combined = "\(rawPresenterNote ?? "") \(presenterNote) \(telop)"
        return SlideItem.extractAnimationDuration(from: combined, slide: self)
    }

    /// スライド上のアニメーション演出表記（例: "アニメーション: 15秒", "アニメーションに合わせる"）
    public var animationTimingNote: String? {
        let combined = "\(rawPresenterNote ?? "") \(presenterNote) \(telop)"
        return SlideItem.extractAnimationNote(from: combined)
    }

    /// セリフ文およびテロップから、話者カッコ表記（例: "[霊夢]", "（魔理沙）"）および
    /// セリフ文の後や文中に付加されたアニメーション・時間・演出に関する()書き表記
    /// （例: "（アニメーション）", "(アニメーション: 15秒)", "(アニメーションに合わせる)", "（アニメ）", "（フェードイン）", "(3秒)"）
    /// を完全に除去し、クリーンなセリフテキストを返す共通ユーティリティ。
    public static func cleanDialogueText(from text: String) -> String {
        var result = text
        // 0. 迷シーン・演出ラベルの除去 (例: "今回の迷シーン１", "今回の迷シーン２", "今回の名シーン３")
        let labelPattern = "今回の(?:迷|名)?シーン\\s*\\d+"
        if let regexLabel = try? NSRegularExpression(pattern: labelPattern, options: .caseInsensitive) {
            let range = NSRange(result.startIndex..., in: result)
            result = regexLabel.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
        }

        // 1. アニメーション表記・時間指定・演出カッコ書きの除去
        // （アニメーション）、(アニメーション: 15秒)、(アニメーションに合わせる)、(アニメ)、(表示時間: 5秒)、(時間: 3秒)、(3秒)、(フェードイン)など
        let animPattern = "[（\\(\\[［][^）\\)\\]］]*(?:アニメーション|アニメ|表示時間|時間|\\d+(?:\\.\\d+)?\\s*秒|フェード|ズーム|タイプライター|スライド|アクション|イン|アウト|カット)[^）\\)\\]］]*[）\\)\\]］]"
        if let regexAnim = try? NSRegularExpression(pattern: animPattern, options: .caseInsensitive) {
            let range = NSRange(result.startIndex..., in: result)
            result = regexAnim.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
        }

        // 2. 話者指定カッコ書きの除去（例: "[魔理沙]", "（霊夢）"）
        let speakerPattern = "[（\\(\\[［][^）\\)\\]］\\s]{1,20}[）\\)\\]］]"
        if let regexSpeaker = try? NSRegularExpression(pattern: speakerPattern, options: []) {
            let range = NSRange(result.startIndex..., in: result)
            result = regexSpeaker.stringByReplacingMatches(in: result, options: [], range: range, withTemplate: "")
        }

        // 3. 行ごとの整形と余分な空白・改行のトリミング
        let lines = result.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return lines.joined(separator: "\n")
    }

    /// アニメーション・時間指定カッコ書きのみを除去する共通ユーティリティ
    public static func stripAnimationBrackets(from text: String) -> String {
        let animPattern = "[（\\(\\[［][^）\\)\\]］]*(?:アニメーション|アニメ|表示時間|時間|\\d+(?:\\.\\d+)?\\s*秒|フェード|ズーム|タイプライター|スライド|アクション|イン|アウト|カット)[^）\\)\\]］]*[）\\)\\]］]"
        guard let regex = try? NSRegularExpression(pattern: animPattern, options: .caseInsensitive) else { return text }
        let range = NSRange(text.startIndex..., in: text)
        let cleaned = regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
        let lines = cleaned.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return lines.joined(separator: "\n")
    }

    /// カッコ書き"（話者）", "(話者)", "[話者]" を文字列から除去する共通ユーティリティ（アニメーション表記も自動除去）
    public static func stripSpeakerBrackets(from text: String) -> String {
        return cleanDialogueText(from: text)
    }

    /// カッコ書き"（話者）", "(話者)", "[話者]" から話者名を抽出する（アニメーション・時間等の演出表記は除外）
    public static func extractSpeakerFromBrackets(from text: String) -> String? {
        let pattern = "[（\\(\\[［]([^）\\)\\]］\\s]{1,20})[）\\)\\]］]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let nsStr = text as NSString
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, options: [], range: range)

        let nonSpeakerKeywords = ["アニメーション", "アニメ", "表示時間", "時間", "秒", "フェード", "ズーム", "イン", "アクション", "アウト"]

        for match in matches {
            if match.numberOfRanges > 1 {
                let extracted = nsStr.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
                if !extracted.isEmpty && !nonSpeakerKeywords.contains(where: { extracted.contains($0) }) {
                    return extracted
                }
            }
        }
        return nil
    }

    /// スライドテキスト（ノートやテロップ）からアニメーション指定時間（秒数）を抽出
    /// 例:
    /// - "（アニメーション: 15秒）" -> 15.0
    /// - "[アニメーション：10秒]" -> 10.0
    /// - "（アニメーション:12.35秒）" -> 12.35
    /// - "（アニメーションに合わせる）" -> スライドのアニメーション動画またはアニメーション合計時間
    public static func extractAnimationDuration(from text: String, slide: SlideItem? = nil) -> Double? {
        // 1. "アニメーションに合わせる" 表記の判定
        let fitPattern = "[（\\(\\[［]\\s*アニメ(?:ーション)?に合わせる\\s*[）\\)\\]］]"
        if let regexFit = try? NSRegularExpression(pattern: fitPattern, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..., in: text)
            if regexFit.firstMatch(in: text, options: [], range: range) != nil {
                // アニメーション動画の実尺があれば優先
                if let s = slide, let vPath = s.animationVideoPath, FileManager.default.fileExists(atPath: vPath) {
                    let asset = AVURLAsset(url: URL(fileURLWithPath: vPath))
                    let dur = CMTimeGetSeconds(asset.duration)
                    if dur.isFinite && dur > 0.1 {
                        return dur
                    }
                }
                // アニメーション一覧の duration 合計
                if let s = slide, !s.animations.isEmpty {
                    let animTotal = s.animations.reduce(0.0) { $0 + $1.duration }
                    if animTotal > 0.1 {
                        return animTotal
                    }
                }
                // スライド自身の duration があればそれを使用
                if let s = slide, s.duration > 0.1 {
                    return s.duration
                }
                return 3.5 // デフォルト
            }
        }

        // 2. 秒数指定パターンの判定 (例: （アニメーション: 15秒）, [アニメーション：10秒], (15秒), (表示時間: 5秒))
        let secPattern = "[（\\(\\[［]\\s*(?:アニメ(?:ーション)?|表示時間|時間)?\\s*[:：]?\\s*(\\d+(?:\\.\\d+)?)\\s*秒\\s*[）\\)\\]］]"
        if let regexSec = try? NSRegularExpression(pattern: secPattern, options: .caseInsensitive) {
            let nsStr = text as NSString
            let range = NSRange(text.startIndex..., in: text)
            if let match = regexSec.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1 {
                let numStr = nsStr.substring(with: match.range(at: 1))
                if let val = Double(numStr), val > 0.0 {
                    return val
                }
            }
        }

        return nil
    }

    /// スライドテキストからアニメーションの注記テキストを抽出 (例: "アニメーション: 15秒", "アニメーションに合わせる")
    public static func extractAnimationNote(from text: String) -> String? {
        let pattern = "[（\\(\\[［]\\s*(アニメ(?:ーション)?(?:\\s*[:：]?\\s*\\d+(?:\\.\\d+)?\\s*秒|に合わせる)?|\\d+(?:\\.\\d+)?\\s*秒|表示時間\\s*[:：]\\s*\\d+(?:\\.\\d+)?\\s*秒)\\s*[）\\)\\]］]"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { return nil }
        let nsStr = text as NSString
        let range = NSRange(text.startIndex..., in: text)
        if let match = regex.firstMatch(in: text, options: [], range: range), match.numberOfRanges > 1 {
            return nsStr.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    /// セクション見出し（中扉）またはタイトルスライドかどうか（音声をスキップすべきスライド）
    public var isTitleOrSectionHeader: Bool {
        if slideType == "title" || slideType == "sectionHeader" {
            return true
        }
        // ノートまたはテロップに明確なセリフがあるか判定
        let noteRaw = rawPresenterNote ?? presenterNote
        let hasNoteSpeaker = SlideItem.extractSpeakerFromBrackets(from: noteRaw) != nil
        let cleanNote = SlideItem.cleanDialogueText(from: presenterNote)

        // スライド番号1: ノートにセリフや話者が存在する場合は通常スライドとして音声を生成する
        if slideIndex == 1 && !hasNoteSpeaker && cleanNote.isEmpty && (title.contains("タイトル") || telop.contains("東方") || telop.contains("第")) {
            return true
        }

        // エンドロール・クレジットスライドのスキップ判定
        let combined = "\(title) \(telop) \(presenterNote)".lowercased()
        if combined.contains("ご視聴ありがとうございました") || combined.contains("出典") || combined.contains("立ち絵：") || combined.contains("立ち絵:") || combined.contains("製作者：") || combined.contains("製作者:") {
            return true
        }

        // 次回予告見出しスライドのスキップ判定
        if (title.contains("次回予告") || telop.contains("次回予告")) && !hasNoteSpeaker && cleanNote.count <= 10 {
            return true
        }

        // テキスト内容からの中扉フォールバック判定
        if combined.contains("その頃") || combined.contains("一方") || combined.contains("中扉") || combined.contains("セクション見出し") {
            if !hasNoteSpeaker && cleanNote.count <= 25 {
                return true
            }
        }
        if title.contains("タイトル") || (title.contains("第") && title.contains("話") && presenterNote.isEmpty) {
            return true
        }
        return false
    }

    /// スライド種別の日本語表示名
    public var slideTypeDisplayName: String {
        if slideType == "title" || slideIndex == 1 {
            return "タイトルスライド"
        } else if slideType == "sectionHeader" || isTitleOrSectionHeader {
            return "セクション見出し"
        } else {
            return "通常スライド"
        }
    }

    public init(
        id: UUID = UUID(),
        slideIndex: Int,
        title: String,
        telop: String,
        presenterNote: String = "",
        backgroundName: String = "",
        characterName: String = "",
        detectedObjects: [String] = [],
        animationTag: String = "なし",
        transitionTag: String = "フェード",
        slideType: String = "content",
        duration: Double = 3.0,
        transitionEffect: String = "なし",
        transitionTrigger: String = "クリック時",
        transitionDelay: Double = 0.0,
        transitionDuration: Double = 1.0,
        animations: [SlideAnimationItem] = [],
        buildOrder: [BuildOrderItem] = [],
        slideWidth: Double = 1920,
        slideHeight: Double = 1080,
        backgroundImagePath: String? = nil,
        backgroundX: Double = 0,
        backgroundY: Double = 0,
        backgroundWidth: Double = 1920,
        backgroundHeight: Double = 1080,
        characterImagePath: String? = nil,
        characterX: Double? = nil,
        characterY: Double? = nil,
        characterWidth: Double? = nil,
        characterHeight: Double? = nil,
        telopX: Double? = nil,
        telopY: Double? = nil,
        telopWidth: Double? = nil,
        telopHeight: Double? = nil,
        objects: [SlideObjectItem] = [],
        slideImagePath: String? = nil,
        animationVideoPath: String? = nil,
        rawPresenterNote: String? = nil
    ) {
        self.id = id
        self.slideIndex = slideIndex
        self.title = title
        self.telop = telop
        self.presenterNote = presenterNote
        self.backgroundName = backgroundName
        self.characterName = characterName
        self.detectedObjects = detectedObjects
        self.animationTag = animationTag
        self.transitionTag = transitionTag
        self.slideType = slideType
        self.duration = duration
        self.transitionEffect = transitionEffect
        self.transitionTrigger = transitionTrigger
        self.transitionDelay = transitionDelay
        self.transitionDuration = transitionDuration
        self.animations = animations
        self.buildOrder = buildOrder
        self.slideWidth = slideWidth
        self.slideHeight = slideHeight
        self.backgroundImagePath = backgroundImagePath
        self.backgroundX = backgroundX
        self.backgroundY = backgroundY
        self.backgroundWidth = backgroundWidth
        self.backgroundHeight = backgroundHeight
        self.characterImagePath = characterImagePath
        self.characterX = characterX
        self.characterY = characterY
        self.characterWidth = characterWidth
        self.characterHeight = characterHeight
        self.telopX = telopX
        self.telopY = telopY
        self.telopWidth = telopWidth
        self.telopHeight = telopHeight
        self.objects = objects
        self.slideImagePath = slideImagePath
        self.animationVideoPath = animationVideoPath
        self.rawPresenterNote = rawPresenterNote ?? presenterNote
    }
}

// MARK: - Game Maker Models
public struct GameCommand: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var sceneIndex: Int
    public var commandType: String // "分岐", "選択肢", "プレイヤー設定", "フラグ判定", "シーン遷移", "エンディング"
    public var promptText: String
    public var targetScene: Int?
}

// MARK: - Material Studio Models
public enum MaterialType: String, CaseIterable, Identifiable {
    case image = "画像"
    case audio = "音声"
    case slide = "スライド"
    case scenario = "シナリオ"
    case game = "ゲーム"

    public var id: String { rawValue }
}

public struct MaterialItem: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var title: String
    public var type: String // "画像", "音声", "スライド", "シナリオ", "ゲーム"
    public var category: String // "キャラクター", "背景", "BGM", "SE", "台本"
    public var filePath: String
    public var fileSize: Int64
    public var createdAt: Date
    public var isCloudSynced: Bool = false
    public var rightsStatus: String = "二次創作ガイドライン準拠"
}
