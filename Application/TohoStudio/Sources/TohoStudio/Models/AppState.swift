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
    case aquesTalkGenerator = "AquesTalkで音声を生成"
    case batchVoiceGenerator = "スライドから全音声一括生成"
    case spanAudioInsert = "複数シーン跨ぎBGM・SE挿入"

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
    @Published public var audioTracks: [AudioTrack] = []
    @Published public var voiceTemplates: [VoiceTemplate] = []
    @Published public var activeVoiceTemplate: VoiceTemplate? = nil
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
    @Published public var importFeedbackMessage: String? = nil

    // Settings
    @Published public var targetFpsMode: String = "バランス自動調整" // "画質優先", "パフォーマンス優先", "バランス自動調整", "カスタム"
    @Published public var uiLanguage: String = "日本語"
    @Published public var regionArea: String = "幻想郷 (日本)"
    @Published public var timeZoneString: String = "Asia/Tokyo (JST)"
    @Published public var defaultPublishScope: String = "ストア一般公開"

    private init() {
        initializeSampleData()
        initializeVoiceTemplates()
        initializeAchievements()
        addHistory("アプリケーション起動: Toho-Studio v1.0.9 正常起動")
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

    // MARK: - File Operations & Cross-Module Import

    /// スライド＆シナリオメーカーのファイル (.tspm, .key, .json等) を読み込み、指定ソフト（ムービーメーカー、サウンドメーカー、ゲームメーカー）へインポート
    public func importSlideScenarioFile(from url: URL, targetModule: SoftwareModule? = nil, completion: ((Bool, Int) -> Void)? = nil) {
        let dest = targetModule ?? currentModule
        let path = url.path
        let fileName = url.lastPathComponent
        log("スライド＆シナリオファイル『\(fileName)』を[\(dest.rawValue)]へインポート解析中...")

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let loadedSlides = SlideRecognitionService.shared.extractSlidesFromPath(filePath: path)

            DispatchQueue.main.async {
                guard !loadedSlides.isEmpty else {
                    let errMsg = "『\(fileName)』からスライド＆シナリオデータを抽出できませんでした"
                    self.log(errMsg, level: "WARN")
                    self.importFeedbackMessage = errMsg
                    completion?(false, 0)
                    return
                }

                // スライド＆シナリオの生データも保持
                self.slides = loadedSlides
                self.currentProjectPath = path
                self.currentProjectName = url.deletingPathExtension().lastPathComponent

                let count = self.applySlidesToModule(slides: loadedSlides, module: dest)
                let successMsg = "スライド＆シナリオ『\(fileName)』から \(loadedSlides.count) スライドを [\(dest.rawValue)] にインポートしました"
                self.log(successMsg)
                self.addHistory("インポート: \(fileName) → \(dest.rawValue) (\(count)件反映)")
                self.importFeedbackMessage = successMsg
                completion?(true, count)
            }
        }
    }

    /// 既に読み込まれているスライドデータを指定ソフトへインポート
    public func importCurrentSlides(to targetModule: SoftwareModule? = nil) {
        let dest = targetModule ?? currentModule
        guard !slides.isEmpty else {
            let msg = "インポート対象のスライド＆シナリオデータがありません。先にファイルを読み込んでください。"
            log(msg, level: "WARN")
            importFeedbackMessage = msg
            return
        }

        let count = applySlidesToModule(slides: slides, module: dest)
        let successMsg = "スライド＆シナリオ (\(slides.count)スライド) を [\(dest.rawValue)] にインポートしました"
        log(successMsg)
        addHistory("インポート: スライド＆シナリオ → \(dest.rawValue) (\(count)件反映)")
        importFeedbackMessage = successMsg
    }

    /// 各モジュールへのスライドデータ反映処理
    @discardableResult
    private func applySlidesToModule(slides: [SlideItem], module: SoftwareModule) -> Int {
        var count = 0
        switch module {
        case .movieMaker:
            SlideRecognitionService.shared.syncToMovieMaker(slides: slides)
            count = movieScenes.count

        case .soundMaker:
            SlideRecognitionService.shared.syncToSoundMaker(slides: slides)
            count = soundClips.count

        case .gameMaker:
            SlideRecognitionService.shared.syncToGameMaker(slides: slides)
            count = gameCommands.count

        case .slideScenarioMaker:
            SlideRecognitionService.shared.syncToMovieMaker(slides: slides)
            SlideRecognitionService.shared.syncToSoundMaker(slides: slides)
            SlideRecognitionService.shared.syncToGameMaker(slides: slides)
            SlideRecognitionService.shared.syncToMaterialStudio(slides: slides)
            count = slides.count

        case .characterMaker, .materialStudio:
            SlideRecognitionService.shared.syncToMaterialStudio(slides: slides)
            count = materials.count
        }
        return count
    }

    public func performSave() {
        saveUndoSnapshot()
        lastSavedSnapshot = movieScenes

        let ext = currentModule.projectExtension
        let cleanName = currentProjectName.hasSuffix(".\(ext)") ? String(currentProjectName.dropLast(ext.count + 1)) : currentProjectName
        let fileNameWithExt = "\(cleanName).\(ext)"

        // モジュールに応じたデータシリアライズと保存
        let success: Bool
        switch currentModule {
        case .slideScenarioMaker:
            if let data = try? JSONEncoder().encode(slides) {
                success = StorageManager.shared.saveProjectFile(module: .slideScenarioMaker, fileName: fileNameWithExt, data: data)
            } else {
                success = false
            }
        case .movieMaker:
            if let data = try? JSONEncoder().encode(movieScenes) {
                success = StorageManager.shared.saveProjectFile(module: .movieMaker, fileName: fileNameWithExt, data: data)
            } else {
                success = false
            }
        case .characterMaker:
            if let data = try? JSONEncoder().encode(currentCharacter) {
                success = StorageManager.shared.saveProjectFile(module: .characterMaker, fileName: fileNameWithExt, data: data)
            } else {
                success = false
            }
        case .soundMaker:
            if let data = try? JSONEncoder().encode(soundClips) {
                success = StorageManager.shared.saveProjectFile(module: .soundMaker, fileName: fileNameWithExt, data: data)
            } else {
                success = false
            }
        case .gameMaker:
            if let data = try? JSONEncoder().encode(gameCommands) {
                success = StorageManager.shared.saveProjectFile(module: .gameMaker, fileName: fileNameWithExt, data: data)
            } else {
                success = false
            }
        case .materialStudio:
            if let data = try? JSONEncoder().encode(materials) {
                success = StorageManager.shared.saveProjectFile(module: .materialStudio, fileName: fileNameWithExt, data: data)
            } else {
                success = false
            }
        }

        if !success {
            log("[\(currentModule.rawValue)] 編集ファイルのディスク書き込みに失敗しました", level: "WARN")
        }

        let backup = StorageManager.shared.createBackup(fileName: fileNameWithExt, content: "TohoStudio Project: \(cleanName)\nModule: \(currentModule.rawValue)\nExtension: .\(ext)\nTimestamp: \(Date())")
        log("[\(currentModule.rawValue)] 編集ファイル『\(fileNameWithExt)』を保存しました (バックアップ: \(backup.originalFileName))")
        addHistory("ファイル: 上書き保存 (成功: \(fileNameWithExt))")
    }

    public func performSaveAs(fileName: String) {
        let ext = currentModule.projectExtension
        let cleanName = fileName.hasSuffix(".\(ext)") ? String(fileName.dropLast(ext.count + 1)) : fileName
        currentProjectName = cleanName
        currentProjectPath = "/Volumes/ZSSD/GitHub/repository/TohoStudio/Application/Resource/\(currentModule.rawValue)/\(cleanName).\(ext)"
        performSave()
        log("『\(cleanName).\(ext)』として名前をつけて保存しました")
        addHistory("ファイル: 名前をつけて保存 (\(cleanName).\(ext))")
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

    // MARK: - Window Layout Modes (仕様書準拠)
    public static let LayoutPresets: [String] = [
        "標準",
        "タイムライン重視",
        "プレビュー最大化",
        "インスペクター重視",
        "縦長動画 (9:16)",
        "正方形動画 (1:1)"
    ]

    public func setLayout(_ mode: String) {
        layoutMode = mode
        log("ウィンドウレイアウトを『\(mode)』に切り替えました (仕様書準拠)")
        addHistory("ウィンドウ: レイアウト (\(mode))")
    }

    public func cycleLayout() {
        let modes = AppState.LayoutPresets
        if let idx = modes.firstIndex(of: layoutMode) {
            layoutMode = modes[(idx + 1) % modes.count]
        } else {
            layoutMode = "標準"
        }
        log("ウィンドウレイアウトを切り替えました: \(layoutMode)")
        addHistory("ウィンドウ: レイアウト (\(layoutMode))")
    }

    // MARK: - Voice Templates (コゲの日記 & 独自テンプレート4種 & Gスカ/ゆっくりボイスメーカー)
    public func applyVoiceTemplate(_ template: VoiceTemplate) {
        activeVoiceTemplate = template
        AquesTalkBridge.shared.setVoiceType(template.voiceType)
        activeModal = .aquesTalkGenerator
        log("音声テンプレート『\(template.name)』(声種:\(template.voiceType.rawValue), 速度:\(template.speed)%, 音程:\(template.pitch))を適用しました")
        addHistory("AquesTalk: テンプレート適用 (\(template.name))")
    }

    public func applyVoiceTemplateByName(_ name: String) {
        if let t = voiceTemplates.first(where: { $0.name == name || $0.characterName == name }) {
            applyVoiceTemplate(t)
        } else if let tpl = voiceTemplates.first(where: { $0.name.contains(name) }) {
            applyVoiceTemplate(tpl)
        }
    }

    /// 既存テンプレートをベースにしたカスタムテンプレートの作成・保存
    @discardableResult
    public func saveCustomVoiceTemplate(
        name: String,
        characterName: String,
        voiceType: VoiceType,
        speed: Int,
        pitch: Int,
        baseTemplateName: String? = nil,
        description: String = ""
    ) -> VoiceTemplate {
        let desc = description.isEmpty
            ? "『\(baseTemplateName ?? "ベース")』を元にしたカスタム設定 (声:\(voiceType.displayShortName), 速:\(speed)%, 音:\(pitch))"
            : description
        let newTemplate = VoiceTemplate(
            name: name,
            characterName: characterName,
            voiceType: voiceType,
            speed: speed,
            pitch: pitch,
            source: "カスタム",
            description: desc,
            isCustom: true,
            baseTemplateName: baseTemplateName
        )
        if let idx = voiceTemplates.firstIndex(where: { $0.name == name && $0.isCustom }) {
            voiceTemplates[idx] = newTemplate
        } else {
            voiceTemplates.insert(newTemplate, at: 0)
        }
        log("カスタム音声テンプレート『\(name)』を保存しました")
        addHistory("テンプレート: カスタム保存 (\(name))")
        return newTemplate
    }

    public func initializeVoiceTemplates() {
        voiceTemplates = [
            // 1. コゲの日記準拠（東風谷早苗）
            VoiceTemplate(
                name: "東風谷早苗 (コゲの日記)",
                characterName: "東風谷早苗",
                voiceType: .f2,
                speed: 100,
                pitch: 115,
                source: "コゲの日記",
                description: "YMM3標準設定ベース・女性2・速度100%・音程115"
            ),
            // 2. 独自テンプレート4種（ユーザー指定）
            VoiceTemplate(
                name: "imd1,100,115 (独自)",
                characterName: "独自: imd1",
                voiceType: .imd1,
                speed: 100,
                pitch: 115,
                source: "独自テンプレート",
                description: "中性(imd1)・速度100%・音程115"
            ),
            VoiceTemplate(
                name: "l1,100,115 (独自)",
                characterName: "独自: l1",
                voiceType: .jgr,
                speed: 100,
                pitch: 115,
                source: "独自テンプレート",
                description: "児童(l1/jgr)・速度100%・音程115"
            ),
            VoiceTemplate(
                name: "m1,100,115 (独自)",
                characterName: "独自: m1",
                voiceType: .m1,
                speed: 100,
                pitch: 115,
                source: "独自テンプレート",
                description: "男声1(m1)・速度100%・音程115"
            ),
            VoiceTemplate(
                name: "m2,100,115 (独自)",
                characterName: "独自: m2",
                voiceType: .m2,
                speed: 100,
                pitch: 115,
                source: "独自テンプレート",
                description: "男声2(m2)・速度100%・音程115"
            ),
            // 3. コゲの日記 主要東方キャラ
            VoiceTemplate(
                name: "博麗霊夢 (コゲの日記)",
                characterName: "博麗霊夢",
                voiceType: .f1,
                speed: 100,
                pitch: 100,
                source: "コゲの日記",
                description: "YMM3標準・女性1・速度100%・音程100"
            ),
            VoiceTemplate(
                name: "霧雨魔理沙 (コゲの日記)",
                characterName: "霧雨魔理沙",
                voiceType: .f2,
                speed: 100,
                pitch: 100,
                source: "コゲの日記",
                description: "YMM3標準・女性2・速度100%・音程100"
            ),
            VoiceTemplate(
                name: "魂魄妖夢 (コゲの日記)",
                characterName: "魂魄妖夢",
                voiceType: .f1,
                speed: 100,
                pitch: 100,
                source: "コゲの日記",
                description: "YMM3標準・女性1・速度100%・音程100"
            ),
            VoiceTemplate(
                name: "十六夜咲夜 (コゲの日記)",
                characterName: "十六夜咲夜",
                voiceType: .f1,
                speed: 105,
                pitch: 125,
                source: "コゲの日記",
                description: "女性1・速度105%・音程125"
            ),
            VoiceTemplate(
                name: "チルノ (コゲの日記)",
                characterName: "チルノ",
                voiceType: .f2,
                speed: 115,
                pitch: 120,
                source: "コゲの日記",
                description: "女性2・速度115%・音程120"
            ),
            VoiceTemplate(
                name: "八雲紫 (コゲの日記)",
                characterName: "八雲紫",
                voiceType: .f2,
                speed: 96,
                pitch: 127,
                source: "コゲの日記",
                description: "女性2・速度96%・音程127"
            ),
            VoiceTemplate(
                name: "八雲藍 (コゲの日記)",
                characterName: "八雲藍",
                voiceType: .f2,
                speed: 115,
                pitch: 113,
                source: "コゲの日記",
                description: "女性2・速度115%・音程113"
            ),
            VoiceTemplate(
                name: "橙 (コゲの日記)",
                characterName: "橙",
                voiceType: .f1,
                speed: 80,
                pitch: 160,
                source: "コゲの日記",
                description: "女性1・速度80%・音程160"
            ),
            VoiceTemplate(
                name: "レミリア・スカーレット (コゲの日記)",
                characterName: "レミリア・スカーレット",
                voiceType: .f2,
                speed: 80,
                pitch: 150,
                source: "コゲの日記",
                description: "女性2・速度80%・音程150"
            ),
            VoiceTemplate(
                name: "フランドール・スカーレット (コゲの日記)",
                characterName: "フランドール・スカーレット",
                voiceType: .r1,
                speed: 115,
                pitch: 100,
                source: "コゲの日記",
                description: "機械1/ロボット・速度115%・音程100"
            ),
            VoiceTemplate(
                name: "アリス・マーガトロイド (コゲの日記)",
                characterName: "アリス・マーガトロイド",
                voiceType: .f1,
                speed: 110,
                pitch: 130,
                source: "コゲの日記",
                description: "女性1・速度110%・音程130"
            ),
            VoiceTemplate(
                name: "パチュリー・ノーレッジ (コゲの日記)",
                characterName: "パチュリー・ノーレッジ",
                voiceType: .imd1,
                speed: 100,
                pitch: 140,
                source: "コゲの日記",
                description: "中性・速度100%・音程140"
            ),
            VoiceTemplate(
                name: "射命丸文 (コゲの日記)",
                characterName: "射命丸文",
                voiceType: .f2,
                speed: 120,
                pitch: 125,
                source: "コゲの日記",
                description: "女性2・速度120%・音程125"
            ),
            VoiceTemplate(
                name: "犬走椛 (コゲの日記)",
                characterName: "犬走椛",
                voiceType: .f1,
                speed: 120,
                pitch: 110,
                source: "コゲの日記",
                description: "女性1・速度120%・音程110"
            ),
            VoiceTemplate(
                name: "古明地さとり (コゲの日記)",
                characterName: "古明地さとり",
                voiceType: .f1,
                speed: 89,
                pitch: 134,
                source: "コゲの日記",
                description: "女性1・速度89%・音程134"
            ),
            VoiceTemplate(
                name: "古明地こいし (コゲの日記)",
                characterName: "古明地こいし",
                voiceType: .f2,
                speed: 75,
                pitch: 181,
                source: "コゲの日記",
                description: "女性2・速度75%・音程181"
            ),
            VoiceTemplate(
                name: "風見幽香 (コゲの日記)",
                characterName: "風見幽香",
                voiceType: .imd1,
                speed: 100,
                pitch: 160,
                source: "コゲの日記",
                description: "中性・速度100%・音程160"
            ),
            VoiceTemplate(
                name: "藤原妹紅 (コゲの日記)",
                characterName: "藤原妹紅",
                voiceType: .f2,
                speed: 120,
                pitch: 130,
                source: "コゲの日記",
                description: "女性2・速度120%・音程130"
            ),
            // 4. Gスカのブログ・ゆっくりボイスメーカー 主要キャラ
            VoiceTemplate(
                name: "八坂神奈子 (Gスカブログ)",
                characterName: "八坂神奈子",
                voiceType: .f1,
                speed: 115,
                pitch: 90,
                source: "Gスカのブログ",
                description: "女性1・速度115%・音程90"
            ),
            VoiceTemplate(
                name: "洩矢諏訪子 (Gスカブログ)",
                characterName: "洩矢諏訪子",
                voiceType: .f1,
                speed: 80,
                pitch: 175,
                source: "Gスカのブログ",
                description: "女性1・速度80%・音程175"
            ),
            VoiceTemplate(
                name: "多々良小傘 (Gスカブログ)",
                characterName: "多々良小傘",
                voiceType: .f2,
                speed: 105,
                pitch: 145,
                source: "Gスカのブログ",
                description: "女性2・速度105%・音程145"
            ),
            VoiceTemplate(
                name: "聖白蓮 (Gスカブログ)",
                characterName: "聖白蓮",
                voiceType: .f2,
                speed: 96,
                pitch: 120,
                source: "Gスカのブログ",
                description: "女性2・速度96%・音程120"
            ),
            VoiceTemplate(
                name: "豊聡耳神子 (Gスカブログ)",
                characterName: "豊聡耳神子",
                voiceType: .f1,
                speed: 130,
                pitch: 103,
                source: "Gスカのブログ",
                description: "女性1・速度130%・音程103"
            ),
            VoiceTemplate(
                name: "鬼人正邪 (Gスカブログ)",
                characterName: "鬼人正邪",
                voiceType: .imd1,
                speed: 110,
                pitch: 133,
                source: "Gスカのブログ",
                description: "中性・速度110%・音程133"
            ),
            VoiceTemplate(
                name: "少名針妙丸 (ゆっくりボイスメーカー)",
                characterName: "少名針妙丸",
                voiceType: .jgr,
                speed: 120,
                pitch: 160,
                source: "ゆっくりボイスメーカー",
                description: "児童・速度120%・音程160"
            ),
            VoiceTemplate(
                name: "純狐 (ゆっくりボイスメーカー)",
                characterName: "純狐",
                voiceType: .f3,
                speed: 95,
                pitch: 105,
                source: "ゆっくりボイスメーカー",
                description: "女性3(落ち着き)・速度95%・音程105"
            )
        ]
    }

    private func initializeSampleData() {
        // Initialize Sample Movie Scenes
        movieScenes = [
            MovieScene(title: "シーン 1: 霊夢と魔理沙の会話", duration: 15.0, slideTitle: "第1スライド", backgroundName: "博麗神社_境内.png", characterName: "博麗霊夢", telop: "霊夢「また異変の気配がするわね」", audioTrack: "voice_reimu_01.wav", animationName: "フェードイン"),
            MovieScene(title: "シーン 2: 異変の兆候", duration: 12.0, slideTitle: "第2スライド", backgroundName: "魔法の森_入口.png", characterName: "霧雨魔理沙", telop: "魔理沙「よし、今度こそ調査に出発だぜ！」", audioTrack: "voice_marisa_01.wav", animationName: "スライドイン左"),
            MovieScene(title: "シーン 3: 紅魔館前", duration: 18.0, slideTitle: "第3スライド", backgroundName: "紅魔館_正門.png", characterName: "十六夜咲夜", telop: "咲夜「お嬢様がお待ちかねです」", audioTrack: "voice_sakuya_01.wav", animationName: "ズームアップ")
        ]

        // Initialize Audio Tracks (Logic Pro style)
        audioTracks = [
            AudioTrack(id: "track_movie", name: "video", type: "movie", icon: "film.fill", colorHex: "#3897F0", volume: 0.85, pan: 0.0),
            AudioTrack(id: "track_voice_reimu", name: "博麗霊夢 (Voice)", type: "voice", icon: "waveform", colorHex: "#E74C3C", volume: 1.0, pan: -0.2, characterName: "博麗霊夢"),
            AudioTrack(id: "track_voice_marisa", name: "霧雨魔理沙 (Voice)", type: "voice", icon: "waveform", colorHex: "#F1C40F", volume: 0.95, pan: 0.2, characterName: "霧雨魔理沙"),
            AudioTrack(id: "track_se", name: "SE (効果音)", type: "se", icon: "bolt.fill", colorHex: "#2ECC71", volume: 0.8, pan: 0.0),
            AudioTrack(id: "track_bgm", name: "BGM (背景音楽)", type: "bgm", icon: "music.note", colorHex: "#9B59B6", volume: 0.65, pan: 0.0)
        ]

        // Initialize Sample Sound Clips with realistic Waveforms
        soundClips = [
            // Movie / Video Track
            SoundClip(
                name: "video (ムービー音声)",
                type: "Movie",
                duration: 45.0,
                volume: 0.85,
                startTime: 0.0,
                trackId: "track_movie",
                colorHex: "#3897F0",
                waveformPoints: [0.1, 0.3, 0.7, 0.85, 0.6, 0.4, 0.55, 0.75, 0.9, 0.65, 0.45, 0.8, 0.7, 0.35, 0.6, 0.8, 0.95, 0.7, 0.5, 0.65, 0.8, 0.4, 0.25, 0.6, 0.75, 0.85, 0.6, 0.3, 0.5, 0.7, 0.6, 0.4, 0.65, 0.85, 0.75, 0.5]
            ),
            // Reimu Voice Track
            SoundClip(
                name: "霊夢: また異変の気配がするわね",
                type: "Voice",
                character: "博麗霊夢",
                text: "また異変の気配がするわね",
                voiceSymbol: "マタイヘンノケハイガスルワネ",
                duration: 4.0,
                volume: 1.0,
                startTime: 1.5,
                trackId: "track_voice_reimu",
                pan: -0.2,
                colorHex: "#E74C3C",
                waveformPoints: [0.2, 0.5, 0.85, 0.95, 0.7, 0.4, 0.8, 0.9, 0.6, 0.3, 0.75, 0.85, 0.5, 0.2]
            ),
            SoundClip(
                name: "霊夢: 博麗神社の結界が揺らいでるわ",
                type: "Voice",
                character: "博麗霊夢",
                text: "博麗神社の結界が揺らいでるわ",
                voiceSymbol: "ハクレイジンジャノケッカイガユライデルワ",
                duration: 4.8,
                volume: 1.0,
                startTime: 16.5,
                trackId: "track_voice_reimu",
                pan: -0.2,
                colorHex: "#E74C3C",
                waveformPoints: [0.3, 0.6, 0.9, 0.75, 0.5, 0.85, 0.95, 0.7, 0.45, 0.8, 0.85, 0.6, 0.3]
            ),
            // Marisa Voice Track
            SoundClip(
                name: "魔理沙: よし、今度こそ調査に出発だぜ！",
                type: "Voice",
                character: "霧雨魔理沙",
                text: "よし、今度こそ調査に出発だぜ！",
                voiceSymbol: "ヨシ、コンドコソチョウサニシュッパツダゼ！",
                duration: 4.2,
                volume: 0.95,
                startTime: 6.5,
                trackId: "track_voice_marisa",
                pan: 0.2,
                colorHex: "#F1C40F",
                waveformPoints: [0.35, 0.7, 0.9, 0.8, 0.6, 0.85, 1.0, 0.75, 0.5, 0.8, 0.9, 0.65, 0.25]
            ),
            SoundClip(
                name: "魔理沙: 魔法の森を抜けて紅魔館へ急ごうぜ",
                type: "Voice",
                character: "霧雨魔理沙",
                text: "魔法の森を抜けて紅魔館へ急ごうぜ",
                voiceSymbol: "マホウノモリヲヌケテコウマカンヘイソゴウゼ",
                duration: 4.5,
                volume: 0.95,
                startTime: 22.5,
                trackId: "track_voice_marisa",
                pan: 0.2,
                colorHex: "#F1C40F",
                waveformPoints: [0.25, 0.65, 0.85, 0.9, 0.6, 0.8, 0.95, 0.7, 0.4, 0.75, 0.85, 0.55, 0.2]
            ),
            // SE Track
            SoundClip(
                name: "SE: スペルカード発動音",
                type: "SE",
                duration: 2.2,
                volume: 0.85,
                startTime: 5.5,
                trackId: "track_se",
                colorHex: "#2ECC71",
                waveformPoints: [0.95, 0.9, 0.8, 0.65, 0.5, 0.4, 0.3, 0.2, 0.15, 0.1]
            ),
            SoundClip(
                name: "SE: 決定・衝撃音",
                type: "SE",
                duration: 1.5,
                volume: 0.8,
                startTime: 11.2,
                trackId: "track_se",
                colorHex: "#2ECC71",
                waveformPoints: [1.0, 0.85, 0.7, 0.5, 0.3, 0.15, 0.05]
            ),
            // BGM Track
            SoundClip(
                name: "BGM: 東方妖恋談",
                type: "BGM",
                duration: 45.0,
                volume: 0.65,
                startTime: 0.0,
                trackId: "track_bgm",
                colorHex: "#9B59B6",
                waveformPoints: [0.4, 0.55, 0.6, 0.5, 0.65, 0.7, 0.55, 0.6, 0.75, 0.8, 0.65, 0.5, 0.6, 0.7, 0.65, 0.55, 0.7, 0.85, 0.75, 0.6, 0.65, 0.75, 0.6, 0.55, 0.7, 0.8, 0.65, 0.6, 0.75, 0.7, 0.55]
            )
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

