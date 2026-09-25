import Foundation
import SwiftUI

public enum ActiveModal: String, Identifiable {
    case tour = "初回ツアー"
    case appInfo = "アプリ情報"
    case settings = "設定画面"
    case store = "ストア"
    case reboot = "再起動"
    case developer = "開発者"
    case backgroundProcess = "進捗状況確認"
    case logsAndAchievements = "ログと実績"
    case bugReport = "バグレポート"
    case historyList = "履歴一覧"
    case statusComparison = "ステータス"
    case debugScreen = "デバック画面"
    case softwareList = "ソフト一覧"
    case featureList = "機能リスト"
    case memoPad = "備考録"
    case fileInfo = "ファイル情報"
    case integrityAlert = "整合性確認"
    case trimmingPopup = "トリミング"
    case splitPopup = "分割"
    case policyCheckPopup = "点検と修正"
    case slideRecognitionPopup = "スライド認識"

    public var id: String { rawValue }
}

public struct SystemLogItem: Identifiable, Codable {
    public var id: UUID = UUID()
    public var timestamp: Date = Date()
    public var level: String // "INFO", "WARN", "ERROR", "ACHIEVEMENT"
    public var message: String
}

public struct AchievementItem: Identifiable, Codable {
    public var id: UUID = UUID()
    public var title: String
    public var description: String
    public var unlockedAt: Date?
    public var isUnlocked: Bool { unlockedAt != nil }
}

public final class AppState: ObservableObject {
    public static let shared = AppState()

    // Active software
    @Published public var currentModule: SoftwareModule = .movieMaker
    @Published public var activeModal: ActiveModal? = nil
    @Published public var isFullScreen: Bool = false

    // Tour / Setup state
    @Published public var hasCompletedTour: Bool = true // Set to true by default, toggleable

    // Playback state (cmd+p commands for MovieMaker)
    @Published public var isPlaying: Bool = false
    @Published public var currentTime: Double = 0.0
    @Published public var totalDuration: Double = 120.0
    @Published public var playbackSpeed: Double = 1.0
    @Published public var playbackVolume: Double = 1.0
    @Published public var isLooping: Bool = false
    @Published public var isDebugPlayback: Bool = false
    @Published public var showPlaybackOverlay: Bool = false
    @Published public var showRateOverlay: Bool = false
    @Published public var activeMaterialInfoKey: String? = nil // 'c', 'o', 'b', 'p'

    // Account & Authentication
    @Published public var currentAccountType: String = "NanndemoyaCloud" // "NanndemoyaCloud", "Google", "Local"
    @Published public var userName: String = "zuyasi"
    @Published public var userEmail: String = "zuyasi@nanndemoya.jp"
    @Published public var isLoggedIn: Bool = true

    // Paid Features & Licenses
    @Published public var extensionPlan: String = "300円プラン (全拡張子解放)"
    @Published public var adFreeRemainingHours: Int = 33337
    @Published public var aiPlanRemainingPrompts: Int = 10000
    @Published public var backupSyncPlanActive: Bool = true
    @Published public var unlockedExtensions: [String] = [
        "FCP非搭載機能", "PremierePro非搭載機能", "Photoshop非搭載機能",
        "PixelmatorPro非搭載機能", "Audition非搭載機能", "LogicPro非搭載機能",
        "Keynote非搭載機能", "PowerPoint非搭載機能", "リモートサポート＆独自機能"
    ]

    // Active Project Data
    @Published public var movieScenes: [MovieScene] = []
    @Published public var selectedSceneIndex: Int = 0
    @Published public var currentCharacter: CharacterModel = CharacterModel(
        name: "博麗霊夢",
        parts: [
            CharacterPart(name: "体", assetPath: "body.png"),
            CharacterPart(name: "顔輪郭", assetPath: "face.png"),
            CharacterPart(name: "目", assetPath: "eyes_normal.png"),
            CharacterPart(name: "口", assetPath: "mouth_smile.png"),
            CharacterPart(name: "髪", assetPath: "hair.png"),
            CharacterPart(name: "装飾", assetPath: "ribbon.png")
        ]
    )
    @Published public var soundClips: [SoundClip] = []
    @Published public var slides: [SlideItem] = []
    @Published public var gameCommands: [GameCommand] = []
    @Published public var materials: [MaterialItem] = []

    // History, Logs, Achievements
    @Published public var logs: [SystemLogItem] = []
    @Published public var achievements: [AchievementItem] = []
    @Published public var historyRecords: [String] = []
    @Published public var userNotes: [String] = []
    @Published public var statusMessage: String = "準備完了"

    // Settings
    @Published public var targetFpsMode: String = "バランス自動調整" // "画質優先", "パフォーマンス優先", "バランス自動調整", "カスタム"
    @Published public var uiLanguage: String = "日本語"
    @Published public var regionArea: String = "幻想郷 (日本)"
    @Published public var timeZoneString: String = "Asia/Tokyo (JST)"
    @Published public var defaultPublishScope: String = "ストア一般公開"

    private init() {
        initializeSampleData()
        initializeAchievements()
    }

    public func log(_ message: String, level: String = "INFO") {
        let item = SystemLogItem(level: level, message: message)
        logs.insert(item, at: 0)
        statusMessage = message
    }

    public func addHistory(_ action: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let entry = "[\(formatter.string(from: Date()))] \(action)"
        historyRecords.insert(entry, at: 0)
    }

    private func initializeSampleData() {
        // Initialize Sample Movie Scenes
        movieScenes = [
            MovieScene(title: "シーン 1: 霊夢と魔理沙の会話", duration: 15.0, slideTitle: "第1スライド", backgroundName: "博麗神社_境内.png", characterName: "博麗霊夢", telop: "霊夢「また異変の気配がするわね」", audioTrack: "voice_reimu_01.wav", animationName: "フェードイン"),
            MovieScene(title: "シーン 2: 異変の兆候", duration: 12.0, slideTitle: "第2スライド", backgroundName: "魔法の森_入口.png", characterName: "霧雨魔理沙", telop: "魔理沙「よし、今度こそ調査に出発だぜ！」", audioTrack: "voice_marisa_01.wav", animationName: "スライドイン左"),
            MovieScene(title: "シーン 3: 紅魔館前", duration: 18.0, slideTitle: "第3スライド", backgroundName: "紅魔館_正門.png", characterName: "十六夜咲夜", telop: "咲夜「お嬢様がお待ちかねです」", audioTrack: "voice_sakuya_01.wav", animationName: "ズームアップ")
        ]

        // Initialize Sample Sound Clips
        soundClips = [
            SoundClip(name: "東方妖恋談 (BGM)", type: "BGM", duration: 184.0, volume: 0.6),
            SoundClip(name: "スペルカード発動音 (SE)", type: "SE", duration: 2.5, volume: 0.9),
            SoundClip(name: "霊夢ボイス #01", type: "Voice", character: "博麗霊夢", text: "異変の気配がするわね", voiceSymbol: "イヘンノケハイガスルワネ", duration: 3.2, volume: 1.0)
        ]

        // Initialize Sample Slides
        slides = [
            SlideItem(slideIndex: 1, title: "第1幕：神社の静寂", telop: "霊夢「また異変の気配がするわね」", presenterNote: "BGM: 神社環境音、キャラ立ち絵は右配置", backgroundName: "博麗神社_境内.png", characterName: "博麗霊夢", detectedObjects: ["鳥居", "賽銭箱"]),
            SlideItem(slideIndex: 2, title: "第2幕：魔法の森へ", telop: "魔理沙「よし、今度こそ調査に出発だぜ！」", presenterNote: "八卦炉の光エフェクトを重ねる", backgroundName: "魔法の森_入口.png", characterName: "霧雨魔理沙", detectedObjects: ["キノコ", "大木"])
        ]

        // Initialize Sample Game Commands
        gameCommands = [
            GameCommand(sceneIndex: 1, commandType: "選択肢", promptText: "選択肢1: 魔法の森へ向かう / 選択肢2: 人里で聞き込み", targetScene: 2),
            GameCommand(sceneIndex: 2, commandType: "フラグ判定", promptText: "フラグ[魔理沙同行]がONの場合、戦闘イベント発生", targetScene: 3)
        ]

        // Initialize Sample Materials
        materials = [
            MaterialItem(title: "博麗霊夢_立ち絵通常", type: "画像", category: "キャラクター", filePath: "/動画用/キャラクター/博麗霊夢.png", fileSize: 1048576, createdAt: Date()),
            MaterialItem(title: "霧雨魔理沙_立ち絵通常", type: "画像", category: "キャラクター", filePath: "/動画用/キャラクター/霧雨魔理沙.png", fileSize: 1024000, createdAt: Date()),
            MaterialItem(title: "博麗神社_夕景背景", type: "画像", category: "背景", filePath: "/動画用/背景/神社境内_夕景.png", fileSize: 2097152, createdAt: Date()),
            MaterialItem(title: "東方惑情録_BGMパック", type: "音声", category: "BGM", filePath: "/動画用/音楽/bgm_pack.mp3", fileSize: 8388608, createdAt: Date())
        ]
    }

    private func initializeAchievements() {
        achievements = [
            AchievementItem(title: "幻想郷へようこそ", description: "Toho-Studioを初めて起動した", unlockedAt: Date()),
            AchievementItem(title: "初めてのゆっくりボイス", description: "AquesTalkで音声を合成・再生した", unlockedAt: Date()),
            AchievementItem(title: "敏腕監督", description: "ムービーメーカーでタイムラインを作成した", unlockedAt: Date()),
            AchievementItem(title: "スライド鑑定士", description: "スライド認識プログラムを精度99%以上で実行した", unlockedAt: nil),
            AchievementItem(title: "同人ゲームクリエイター", description: "ゲームメーカーで分岐コマンドを設定した", unlockedAt: nil),
            AchievementItem(title: "東方Project公認クリエイター", description: "二次創作ガイドラインに完全適合した作品を出力した", unlockedAt: nil)
        ]
    }
}
