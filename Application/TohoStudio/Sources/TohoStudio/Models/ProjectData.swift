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
public enum VoiceType: String, CaseIterable, Identifiable {
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
}

public struct SoundClip: Identifiable, Codable, Equatable {
    public var id: UUID = UUID()
    public var name: String
    public var type: String // "BGM", "SE", "Voice"
    public var character: String?
    public var text: String?
    public var voiceSymbol: String?
    public var duration: Double
    public var volume: Double = 1.0
    public var speed: Int = 100
}

// MARK: - Slide & Scenario Maker Models
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
