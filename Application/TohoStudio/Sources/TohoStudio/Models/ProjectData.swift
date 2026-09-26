import Foundation

// MARK: - Software Modules (内蔵ソフト)
public enum SoftwareModule: String, CaseIterable, Identifiable {
    case movieMaker = "ムービーメーカー"
    case characterMaker = "キャラクターメーカー"
    case soundMaker = "サウンドメーカー"
    case slideScenarioMaker = "スライド＆シナリオメーカー"
    case gameMaker = "ゲームメーカー"
    case materialStudio = "素材スタジオ"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .movieMaker: return "film"
        case .characterMaker: return "person.crop.artframe"
        case .soundMaker: return "waveform"
        case .slideScenarioMaker: return "doc.richtext"
        case .gameMaker: return "gamecontroller"
        case .materialStudio: return "folder.badge.gearshape"
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
        }
    }

    /// 仕様書記載の編集ファイル拡張子 (Slide 178, 192, 214, 228, 241)
    public var projectExtension: String {
        switch self {
        case .movieMaker: return "tsvm"
        case .characterMaker: return "tscm"
        case .soundMaker: return "tssm"
        case .slideScenarioMaker: return "tspm" // 仕様書 Slide 228: 編集ファイル拡張子: tspm
        case .gameMaker: return "tsgm"
        case .materialStudio: return "tohoproj"
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

    /// クリーンなテロップ/セリフ（()書き表記（アニメーション）や話者タグを除外したテキスト）
    public var displayTelop: String {
        return SlideItem.cleanDialogueText(from: telop)
    }
}

// MARK: - Character Maker Models
public struct CharacterPart: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var name: String // "目", "口", "顔輪郭", "体", "装飾", "髪"
    public var assetPath: String
    public var offsetX: Double = 0.0
    public var offsetY: Double = 0.0
    public var scale: Double = 1.0
    public var colorTintHex: String = "#FFFFFF"
    public var isVisible: Bool = true
}

public struct CharacterModel: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var name: String
    public var parts: [CharacterPart]
    public var expression: String = "通常"
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
    case jgr = "児童"

    public var id: String { rawValue }

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

    public var isSpanningScenes: Bool {
        if let s = spanStartSceneIndex, let e = spanEndSceneIndex, e > s {
            return true
        }
        return false
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
        pitch: Int = 100
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

    /// セリフ文およびテロップから、話者カッコ表記（例: "[霊夢]", "（魔理沙）"）および
    /// セリフ文の後や文中に付加されたアニメーション・時間・演出に関する()書き表記
    /// （例: "（アニメーション）", "(アニメーション: 15秒)", "(アニメーションに合わせる)", "（アニメ）", "（フェードイン）", "(3秒)"）
    /// を完全に除去し、クリーンなセリフテキストを返す共通ユーティリティ。
    public static func cleanDialogueText(from text: String) -> String {
        var result = text
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

    /// セクション見出し（中扉）またはタイトルスライドかどうか（音声をスキップすべきスライド）
    public var isTitleOrSectionHeader: Bool {
        if slideType == "title" || slideType == "sectionHeader" {
            return true
        }
        // スライド番号1はタイトルスライドとして判定
        if slideIndex == 1 {
            return true
        }
        // テキスト内容からのフォールバック判定
        let combined = "\(title) \(telop) \(presenterNote)".lowercased()
        if combined.contains("その頃") || combined.contains("一方") || combined.contains("中扉") || combined.contains("セクション見出し") {
            return true
        }
        if title.contains("タイトル") || (title.contains("第") && title.contains("話")) {
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
