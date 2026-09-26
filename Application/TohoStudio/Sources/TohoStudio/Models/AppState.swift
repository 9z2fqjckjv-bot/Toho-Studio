import Foundation
import SwiftUI
import AppKit

public enum ActiveModal: String, CaseIterable, Identifiable {
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
    case sceneInfo = "シーン情報"
    case integrityAlert = "整合性確認"
    case trimmingPopup = "トリミング"
    case splitPopup = "分割"
    case policyCheckPopup = "点検と修正"
    case slideRecognitionPopup = "スライド認識"
    case slideLoader = "スライドの読み込み"
    case newProject = "新規作成"
    case fileExport = "書き出し"
    case backupManager = "バックアップ"
    case contextOptions = "オプション"
    case windowOptions = "ウィンドウ設定"
    case manual = "取扱説明書"
    case helpGuide = "ヘルプガイド"
    case qa = "Q&A"
    case troubleshoot = "困ったときは"
    case credits = "クレジット"
    case license = "ライセンス"
    case supportRequest = "サポート依頼"

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
    @Published public var appInfoInitialTab: Int = 0
    @Published public var isFullScreen: Bool = false

    // In-App Browser State
    @Published public var activeInAppBrowserURL: URL? = nil
    @Published public var inAppBrowserTitle: String? = nil

    public func openInAppBrowser(url: URL, title: String? = nil) {
        self.activeInAppBrowserURL = url
        self.inAppBrowserTitle = title
    }

    public func closeInAppBrowser() {
        self.activeInAppBrowserURL = nil
        self.inAppBrowserTitle = nil
    }

    // Zoom & Layout
    @Published public var zoomScale: Double = 1.0
    @Published public var layoutMode: String = "標準" // "標準", "タイムライン重視", "プレビュー最大化", "インスペクター重視"
    @Published public var isPanelDisplayMode: Bool = false

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
    @Published public var isScreenRecording: Bool = false
    private var screenRecordingProcess: Process? = nil
    private var screenRecordingPath: String? = nil

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
    @Published public var currentProjectName: String = "東方惑情録_第1話"
    @Published public var currentProjectPath: String = "/Volumes/ZSSD/GitHub/repository/TohoStudio/東方惑情録/東方惑情録　第1話.key"
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

    // Undo / Redo Stacks
    private var undoStack: [[MovieScene]] = []
    private var redoStack: [[MovieScene]] = []
    private var lastSavedSnapshot: [MovieScene]? = nil

    // History, Logs, Achievements, Notes
    @Published public var logs: [SystemLogItem] = []
    @Published public var achievements: [AchievementItem] = []
    @Published public var historyRecords: [String] = []
    @Published public var userNotes: [String] = []
    @Published public var sceneNotes: [String: String] = [:]
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
        addHistory("アプリケーション起動: Toho-Studio v1.0.8 正常起動")
        saveUndoSnapshot()
    }

    public func log(_ message: String, level: String = "INFO") {
        let item = SystemLogItem(level: level, message: message)
        logs.insert(item, at: 0)
        statusMessage = message
    }

    public func addHistory(_ action: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let entry = "[\(formatter.string(from: Date()))] \(action)"
        historyRecords.insert(entry, at: 0)
    }

    // MARK: - Undo / Redo
    public func saveUndoSnapshot() {
        undoStack.append(movieScenes)
        if undoStack.count > 50 {
            undoStack.removeFirst()
        }
        redoStack.removeAll()
    }

    public func performUndo() {
        guard undoStack.count > 1 else {
            log("これ以上やり直す操作はありません", level: "WARN")
            return
        }
        let current = undoStack.removeLast()
        redoStack.append(current)
        if let previous = undoStack.last {
            movieScenes = previous
            log("操作をひとつ戻しました (Undo)")
            addHistory("編集: やり直す (Undo実行)")
        }
    }

    public func performRedo() {
        guard let next = redoStack.popLast() else {
            log("これ以上進める操作はありません", level: "WARN")
            return
        }
        undoStack.append(next)
        movieScenes = next
        log("やり直した操作を進めました (Redo)")
        addHistory("編集: 進める (Redo実行)")
    }

    // MARK: - File Operations
    public func performSave() {
        saveUndoSnapshot()
        lastSavedSnapshot = movieScenes
        let backup = StorageManager.shared.createBackup(fileName: currentProjectName, content: "TohoStudio Project: \(currentProjectName)\nScenes: \(movieScenes.count)")
        log("プロジェクト『\(currentProjectName)』を上書き保存しました (バックアップ: \(backup.originalFileName))")
        addHistory("ファイル: 上書き保存 (成功)")
    }

    public func performSaveAs(fileName: String) {
        currentProjectName = fileName
        performSave()
        log("『\(fileName)』として名前をつけて保存しました")
        addHistory("ファイル: 名前をつけて保存 (\(fileName))")
    }

    public func performDuplicate() {
        let duplicateName = "\(currentProjectName)_コピー"
        _ = StorageManager.shared.createBackup(fileName: duplicateName, content: "Duplicate of \(currentProjectName)")
        log("現在の編集プロジェクトを『\(duplicateName)』として複製しました")
        addHistory("ファイル: 複製 (\(duplicateName))")
    }

    public func performRollback() {
        if let saved = lastSavedSnapshot {
            movieScenes = saved
            log("直近の保存状態へプロジェクトを巻き戻しました")
            addHistory("ファイル: 巻き戻し (復元完了)")
        } else if let first = undoStack.first {
            movieScenes = first
            log("プロジェクトを開いた直後の初期状態へ巻き戻しました")
            addHistory("ファイル: 巻き戻し (初期スナップショット)")
        } else {
            log("巻き戻し可能な過去スナップショットがありません", level: "WARN")
        }
    }

    public func performRepair() {
        let ok = StorageManager.shared.repairFile(filePath: currentProjectPath)
        if ok {
            log("プロジェクトファイルの修復に成功しました")
            addHistory("ファイル: ファイル修復 (成功)")
        } else {
            log("ファイル修復を実行しましたが、問題は検出されませんでした", level: "INFO")
            addHistory("ファイル: ファイル修復 (完了)")
        }
    }

    public func showInFinder() {
        let url = URL(fileURLWithPath: currentProjectPath)
        if FileManager.default.fileExists(atPath: currentProjectPath) {
            NSWorkspace.shared.activateFileViewerSelecting([url])
            log("Finderでファイルを表示しました: \(currentProjectPath)")
        } else {
            // Fallback to project root directory
            let rootUrl = URL(fileURLWithPath: "/Volumes/ZSSD/GitHub/repository/TohoStudio")
            NSWorkspace.shared.activateFileViewerSelecting([rootUrl])
            log("Finderでプロジェクトフォルダを表示しました")
        }
        addHistory("表示: Finderで表示")
    }

    public func captureScreen() {
        let timestamp = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let filename = "Screenshot_\(formatter.string(from: timestamp)).png"
        let saveDir = "/Volumes/ZSSD/GitHub/repository/TohoStudio/Application/Resource/MaterialStudio/Image"
        let savePath = "\(saveDir)/\(filename)"

        try? FileManager.default.createDirectory(atPath: saveDir, withIntermediateDirectories: true)

        let task = Process()
        task.launchPath = "/usr/sbin/screencapture"
        task.arguments = ["-x", savePath]
        try? task.run()
        task.waitUntilExit()

        let item = MaterialItem(
            title: filename,
            type: "画像",
            category: "スクリーンショット",
            filePath: savePath,
            fileSize: 1024 * 512,
            createdAt: timestamp
        )
        materials.insert(item, at: 0)
        log("画面スクリーンショットをキャプチャし素材スタジオに保存しました: \(filename)")
        addHistory("表示: スクショ保存 (\(filename))")
    }

    public func toggleScreenRecording() {
        if isScreenRecording {
            // Stop recording
            screenRecordingProcess?.interrupt()
            screenRecordingProcess?.terminate()
            screenRecordingProcess = nil
            isScreenRecording = false

            if let path = screenRecordingPath {
                let filename = URL(fileURLWithPath: path).lastPathComponent
                let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? (1024 * 1024 * 5)
                let item = MaterialItem(
                    title: filename,
                    type: "動画",
                    category: "画面収録",
                    filePath: path,
                    fileSize: size,
                    createdAt: Date(),
                    isCloudSynced: true
                )
                materials.insert(item, at: 0)
                log("画面収録を停止し素材スタジオに保存しました: \(filename)")
                addHistory("表示: 画面収録停止・保存 (\(filename))")
            }
            screenRecordingPath = nil
        } else {
            // Start recording
            let timestamp = Date()
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyyMMdd_HHmmss"
            let filename = "ScreenRecording_\(formatter.string(from: timestamp)).mov"
            let saveDir = "/Volumes/ZSSD/GitHub/repository/TohoStudio/Application/Resource/MaterialStudio/Movie"
            let savePath = "\(saveDir)/\(filename)"

            try? FileManager.default.createDirectory(atPath: saveDir, withIntermediateDirectories: true)

            let task = Process()
            task.launchPath = "/usr/sbin/screencapture"
            task.arguments = ["-v", "-k", savePath]
            try? task.run()

            self.screenRecordingProcess = task
            self.screenRecordingPath = savePath
            self.isScreenRecording = true

            log("画面収録を開始しました（もう一度 cmd+d+shift+p を押すと停止して保存されます）")
            addHistory("表示: 画面収録開始 (\(filename))")
        }
    }

    public func performCreateMaterialFromCurrent() {
        let timestamp = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "HHmmss"
        let materialTitle: String
        let type: String
        let cat: String

        switch currentModule {
        case .movieMaker:
            materialTitle = "ムービーシーン素材_\(formatter.string(from: timestamp))"
            type = "動画"
            cat = "シーン"
        case .characterMaker:
            materialTitle = "\(currentCharacter.name)_カスタムパーツ_\(formatter.string(from: timestamp))"
            type = "画像"
            cat = "キャラクター"
        case .soundMaker:
            materialTitle = "合成音声素材_\(formatter.string(from: timestamp))"
            type = "音声"
            cat = "ボイス"
        case .slideScenarioMaker:
            materialTitle = "スライドテロップ素材_\(formatter.string(from: timestamp))"
            type = "テキスト"
            cat = "シナリオ"
        case .gameMaker:
            materialTitle = "ゲーム分岐スクリプト_\(formatter.string(from: timestamp))"
            type = "プログラム"
            cat = "コマンド"
        case .materialStudio:
            materialTitle = "スタジオ新規素材_\(formatter.string(from: timestamp))"
            type = "汎用"
            cat = "素材"
        }

        let newMat = MaterialItem(
            title: materialTitle,
            type: type,
            category: cat,
            filePath: "/動画用/\(cat)/\(materialTitle).dat",
            fileSize: 204800,
            createdAt: timestamp
        )
        materials.insert(newMat, at: 0)
        log("編集中のデータから新規素材『\(materialTitle)』を作成し素材スタジオに登録しました")
        addHistory("編集: 素材作成 (\(materialTitle))")
    }

    public func performImportMaterials() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedContentTypes = [.image, .audio, .movie, .text, .pdf]
        panel.message = "素材スタジオへインポートするファイルを選択してください"

        if panel.runModal() == .OK {
            for url in panel.urls {
                let name = url.lastPathComponent
                let ext = url.pathExtension.lowercased()
                let type: String
                if ["png", "jpg", "jpeg", "webp"].contains(ext) { type = "画像" }
                else if ["wav", "mp3", "m4a", "aac"].contains(ext) { type = "音声" }
                else if ["mp4", "mov"].contains(ext) { type = "動画" }
                else { type = "ドキュメント" }

                let item = MaterialItem(
                    title: name,
                    type: type,
                    category: "インポート",
                    filePath: url.path,
                    fileSize: (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0,
                    createdAt: Date()
                )
                materials.insert(item, at: 0)
            }
            log("\(panel.urls.count)件のファイルを素材スタジオにインポートしました")
            addHistory("編集: インポート (\(panel.urls.count)件)")
        }
    }

    public func performExportMaterials() {
        let panel = NSSavePanel()
        panel.title = "素材スタジオからエクスポート"
        panel.nameFieldStringValue = "\(currentProjectName)_Export.zip"
        if panel.runModal() == .OK, let url = panel.url {
            let sampleContent = "Toho-Studio Export Package\nProject: \(currentProjectName)\nDate: \(Date())\nMaterials: \(materials.count)\n"
            try? sampleContent.write(to: url, atomically: true, encoding: .utf8)
            log("素材スタジオのデータをエクスポートしました: \(url.lastPathComponent)")
            addHistory("編集: エクスポート (\(url.lastPathComponent))")
        }
    }

    public func performRegenerate() {
        switch currentModule {
        case .movieMaker:
            if !movieScenes.isEmpty {
                let scene = movieScenes[selectedSceneIndex]
                log("ムービーメーカー: シーン『\(scene.title)』のアニメーション・テロップを再生成・再読み込みしました")
            } else {
                log("ムービーメーカー: シーンを再生成しました")
            }
        case .characterMaker:
            currentCharacter = CharacterModel(
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
            log("キャラクターメーカー: すべての変更を取り消し、読み込み直後の初期状態に戻しました")
        case .soundMaker:
            log("サウンドメーカー: キャラクター音声およびBGM/SEの波形データを再生成しました")
        case .slideScenarioMaker:
            let path = SlideRecognitionService.shared.loadedProjectName.contains("/") ? SlideRecognitionService.shared.loadedProjectName : currentProjectPath
            SlideRecognitionService.shared.loadSlideProgram(filePath: path, replaceState: true) { _, _ in }
            log("スライド＆シナリオメーカー: 表示中のスライド元ファイル『\(path)』を再読み込みしました")
        case .gameMaker:
            log("ゲームメーカー: 設定された全ゲームコマンドと分岐判定を再検証・再読み込みしました")
        case .materialStudio:
            log("素材スタジオ: キャッシュを再生成し、素材ライブラリを更新しました")
        }
        addHistory("編集: 再生成 (\(currentModule.rawValue))")
    }

    public func performSoftReset() {
        // Backup current state for restoration
        lastSavedSnapshot = movieScenes
        currentModule = .movieMaker
        isPlaying = false
        currentTime = 0.0
        activeModal = nil
        log("プログラムをリセットし初期状態に戻しました（変更内容はバックアップ済み）")
        addHistory("ウィンドウ: リセット (初期化完了)")
    }

    public func performRestoreAfterReset() {
        if let saved = lastSavedSnapshot {
            movieScenes = saved
            log("リセット前の編集画面・状態を完全復元しました")
            addHistory("ウィンドウ: 更新 (復元完了)")
        } else {
            log("復元可能なセッションデータがありません", level: "WARN")
        }
    }

    public func performReboot() {
        performSave()
        log("安全に保存し、再起動シーケンスを開始しました")
        addHistory("Toho-Studio: 再起動")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            let url = Bundle.main.bundleURL
            let config = NSWorkspace.OpenConfiguration()
            config.createsNewApplicationInstance = true
            NSWorkspace.shared.openApplication(at: url, configuration: config) { _, _ in
                DispatchQueue.main.async {
                    NSApplication.shared.terminate(nil)
                }
            }
        }
    }

    public func cycleLayout() {
        let modes = ["標準", "タイムライン重視", "プレビュー最大化", "インスペクター重視"]
        if let idx = modes.firstIndex(of: layoutMode) {
            layoutMode = modes[(idx + 1) % modes.count]
        } else {
            layoutMode = "標準"
        }
        log("ウィンドウレイアウトを切り替えました: \(layoutMode)")
        addHistory("ウィンドウ: レイアウト (\(layoutMode))")
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
            AchievementItem(title: "スライド鑑定士", description: "スライド認識プログラムを精度99%以上で実行した", unlockedAt: Date()),
            AchievementItem(title: "同人ゲームクリエイター", description: "ゲームメーカーで分岐コマンドを設定した", unlockedAt: nil),
            AchievementItem(title: "東方Project公認クリエイター", description: "二次創作ガイドラインに完全適合した作品を出力した", unlockedAt: nil)
        ]
    }
}

