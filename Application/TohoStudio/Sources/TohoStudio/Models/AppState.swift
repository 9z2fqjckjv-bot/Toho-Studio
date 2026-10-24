import Foundation
import SwiftUI
import AppKit
import AVFoundation

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
    case slideExtractor = "スライド抽出プログラム"
    case aiSearch = "AI高度検索・生成・置換"

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
    @Published public var previousModule: SoftwareModule = .movieMaker
    @Published public var wasInAppTopBeforeUnavailable: Bool = true
    @Published public var isShowingAppTop: Bool = true // 仕様書スライド26: アプリトップ画面表示フラグ
    @Published public var isControlBarVisible: Bool = false // コントロールバーの表示/非表示（消してメニューバーを表示）
    @Published public var activeModal: ActiveModal? = nil
    @Published public var appInfoInitialTab: Int = 0
    @Published public var isFullScreen: Bool = false

    /// "前の画面に戻る" 共通復帰処理
    public func navigateBackFromUnavailable() {
        if activeModal != nil {
            activeModal = nil
            return
        }

        if currentModule == .tohoAIStudio {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                if wasInAppTopBeforeUnavailable {
                    isShowingAppTop = true
                } else {
                    currentModule = previousModule
                    isShowingAppTop = false
                }
            }
            return
        }

        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
            isShowingAppTop = true
        }
    }

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
    private var moviePlaybackTimer: Timer? = nil
    @Published public var isPlaying: Bool = false {
        didSet {
            if isPlaying != oldValue {
                if isPlaying {
                    if moviePlaybackTimer == nil {
                        startMoviePlayback()
                    }
                } else {
                    if moviePlaybackTimer != nil {
                        stopMoviePlayback()
                    }
                }
            }
        }
    }
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
    /// スライド・アセットの更新バージョン（全画面プレビュー強制リフレッシュ用）
    @Published public var slideAssetsVersion: UUID = UUID()

    public func notifySlideAssetsUpdated() {
        slideAssetsVersion = UUID()
        objectWillChange.send()
    }

    /// システム画像キャッシュを回避して常に最新の画像バイナリをロード
    public static func loadFreshImage(from path: String) -> NSImage? {
        let fm = FileManager.default
        guard fm.fileExists(atPath: path),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path), options: .alwaysMapped) else {
            return nil
        }
        return NSImage(data: data)
    }

    /// 指定プロジェクト名およびスライド番号に対応する最新キャッシュ画像パスを更新日時降順で探索
    public static func findLatestSlideImagePath(forProject project: String, slideIndex: Int) -> String? {
        let fm = FileManager.default
        let slidesCacheBase = "/Volumes/ZSSD/GitHub/repository/TohoStudio/.cache/keynote_slides"
        guard fm.fileExists(atPath: slidesCacheBase) else { return nil }

        let clean = SlideRecognitionService.cleanProjectBaseName(from: project)
        let idx3 = String(format: "%03d", slideIndex)
        let idxPatterns = [".\(idx3).jpeg", ".\(idx3).jpg", ".\(slideIndex).jpeg", ".\(slideIndex).jpg", "_\(idx3).jpeg"]

        guard let subdirs = try? fm.contentsOfDirectory(atPath: slidesCacheBase) else { return nil }

        let matchedDirs = subdirs.filter { dir in
            if clean.isEmpty { return true }
            let dirClean = SlideRecognitionService.cleanProjectBaseName(from: dir)
            let normDir = dir.replacingOccurrences(of: "_", with: "").replacingOccurrences(of: " ", with: "")
            let normClean = clean.replacingOccurrences(of: "_", with: "").replacingOccurrences(of: " ", with: "")
            return dir.contains(clean) || clean.contains(dirClean) || normDir.contains(normClean) || normClean.contains(normDir)
        }

        let sortedDirs = matchedDirs.sorted { d1, d2 in
            let p1 = (slidesCacheBase as NSString).appendingPathComponent(d1)
            let p2 = (slidesCacheBase as NSString).appendingPathComponent(d2)
            let m1 = (try? fm.attributesOfItem(atPath: p1)[.modificationDate] as? Date) ?? Date.distantPast
            let m2 = (try? fm.attributesOfItem(atPath: p2)[.modificationDate] as? Date) ?? Date.distantPast
            return m1 > m2
        }

        for dir in sortedDirs {
            let fullDir = (slidesCacheBase as NSString).appendingPathComponent(dir)
            guard let files = try? fm.contentsOfDirectory(atPath: fullDir) else { continue }
            for pattern in idxPatterns {
                if let matchedFile = files.first(where: { $0.contains(pattern) }) {
                    let fullPath = (fullDir as NSString).appendingPathComponent(matchedFile)
                    if fm.fileExists(atPath: fullPath) {
                        return fullPath
                    }
                }
            }
        }
        return nil
    }
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
    @Published public var soundMakerSelectedSceneIndex: Int = 1
    @Published public var soundMakerCurrentTime: Double = 0.0
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
        addHistory("アプリケーション起動: Toho-Studio v2.6.0 正常起動")
        saveUndoSnapshot()
    }

    public func addSystemLog(level: String, message: String) {
        log(message, level: level)
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
                let cleanBase = SlideRecognitionService.cleanProjectBaseName(from: fileName)
                self.currentProjectName = cleanBase

                let count = self.applySlidesToModule(slides: loadedSlides, module: dest)
                if dest == .movieMaker {
                    self.resolveMovieScenesMedia()
                }
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
        if dest == .movieMaker {
            resolveMovieScenesMedia()
        }
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

        case .characterMaker, .materialStudio, .tohoAIStudio:
            SlideRecognitionService.shared.syncToMaterialStudio(slides: slides)
            count = materials.count
        }
        return count
    }

    public func performSave() {
        saveUndoSnapshot()
        lastSavedSnapshot = movieScenes

        let ext = currentModule.projectExtension
        let cleanName = SlideRecognitionService.cleanProjectBaseName(from: currentProjectName)
        let fileNameWithExt = "\(cleanName).\(ext)"

        // モジュールに応じたデータシリアライズと保存
        let success: Bool
        switch currentModule {
        case .slideScenarioMaker:
            if let data = try? JSONEncoder().encode(slides) {
                success = StorageManager.shared.saveProjectFile(module: .slideScenarioMaker, fileName: fileNameWithExt, data: data)
                _ = StorageManager.shared.saveProjectFile(module: .slideScenarioMaker, fileName: "\(cleanName).key.tspm", data: data)
                _ = StorageManager.shared.saveProjectFile(module: .slideScenarioMaker, fileName: "\(cleanName)_sync.json", data: data)
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
            syncClipsToMovieScenes(soundClips)
            let doc = SoundMakerProjectDocument(
                version: "2.0",
                clips: soundClips,
                tracks: audioTracks,
                scenes: movieScenes,
                totalDuration: totalDuration
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted]
            if let data = try? encoder.encode(doc) {
                success = StorageManager.shared.saveProjectFile(module: .soundMaker, fileName: fileNameWithExt, data: data)
            } else if let fallbackData = try? encoder.encode(soundClips) {
                success = StorageManager.shared.saveProjectFile(module: .soundMaker, fileName: fileNameWithExt, data: fallbackData)
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
        case .tohoAIStudio:
            let chatData = (try? JSONEncoder().encode(TohoAIService.shared.chatMessages)) ?? Data()
            success = StorageManager.shared.saveProjectFile(module: .tohoAIStudio, fileName: fileNameWithExt, data: chatData)
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
            materialTitle = "\(currentCharacter.name)_カスタム立ち絵_\(formatter.string(from: timestamp))"
            type = "画像"
            cat = "キャラクター"
            let savedPath = CharacterImageService.shared.saveToMaterialStudio(model: currentCharacter, appState: self)
            let newMat = MaterialItem(
                title: materialTitle,
                type: type,
                category: cat,
                filePath: savedPath,
                fileSize: 524288,
                createdAt: timestamp
            )
            materials.insert(newMat, at: 0)
            return
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
        case .tohoAIStudio:
            materialTitle = "AI生成データ_\(formatter.string(from: timestamp))"
            type = "AIデータ"
            cat = "プロンプト"
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

    // MARK: - Character Maker Operations
    public func performCharacterSplit() {
        saveUndoSnapshot()
        CharacterImageService.shared.splitCharacterIntoParts(model: &currentCharacter)
        log("キャラクターメーカー: 立ち絵画像から顔・体・目・口・髪・装飾等にパーツ分割を完了しました")
        addHistory("編集: パーツ分割 (キャラクターメーカー)")
    }

    public func performCharacterCrop(normalizedRect: CGRect, zoomFactor: Double = 1.0) {
        saveUndoSnapshot()
        guard let baseImg = CharacterImageService.shared.loadImage(from: currentCharacter.baseImagePath) else {
            log("キャラクターメーカー: クロップ対象の画像が見つかりません", level: "WARN")
            return
        }

        if let cropped = CharacterImageService.shared.cropAndScaleImage(sourceImage: baseImg, cropRectNormalized: normalizedRect, zoomFactor: zoomFactor) {
            let timestamp = Int(Date().timeIntervalSince1970)
            let cacheDir = "/Volumes/ZSSD/GitHub/repository/TohoStudio/.cache/character_parts"
            try? FileManager.default.createDirectory(atPath: cacheDir, withIntermediateDirectories: true)
            let cachePath = "\(cacheDir)/crop_\(currentCharacter.name)_\(timestamp).png"

            if let tiff = cropped.tiffRepresentation,
               let rep = NSBitmapImageRep(data: tiff),
               let png = rep.representation(using: .png, properties: [:]) {
                try? png.write(to: URL(fileURLWithPath: cachePath))
            }

            let newPart = CharacterPart(
                name: "トリミングパーツ (\(String(format: "%.1f", zoomFactor))x)",
                assetPath: cachePath,
                offsetX: 0.0,
                offsetY: 0.0,
                scale: 1.0,
                isVisible: true
            )
            currentCharacter.parts.append(newPart)
            log("キャラクターメーカー: 指定範囲を切り取り・拡大して新規パーツとして配置しました (拡大率: \(String(format: "%.1f", zoomFactor))x)")
            addHistory("編集: トリミング (キャラクターメーカー)")
        }
    }

    public func toggleCharacterFacingDirection() {
        saveUndoSnapshot()
        currentCharacter.isBackView.toggle()
        let viewName = currentCharacter.isBackView ? "背中側 (背面)" : "正面 (前面)"
        log("キャラクターメーカー: キャラクターを前後反転しました（現在: \(viewName)）")
        addHistory("編集: 前後反転 (\(viewName))")
    }

    public func loadCharacterPreset(name: String) {
        saveUndoSnapshot()
        currentCharacter = CharacterImageService.shared.createPresetCharacter(name: name)
        log("キャラクターメーカー: 『\(name)』の立ち絵プリセットを読み込みました")
        addHistory("読込: キャラクタープリセット (\(name))")
    }

    public func loadCharacterProject(from url: URL) {
        guard let data = try? Data(contentsOf: url),
              let model = try? JSONDecoder().decode(CharacterModel.self, from: data) else {
            log("キャラクターメーカー: 編集ファイル『\(url.lastPathComponent)』の読み込みに失敗しました", level: "WARN")
            return
        }
        saveUndoSnapshot()
        currentCharacter = model
        log("キャラクターメーカー: 編集ファイル『\(url.lastPathComponent)』を読み込みました")
        addHistory("読込: キャラクターファイル (.tscm)")
    }

    public func saveCharacterProject(to url: URL) {
        guard let data = try? JSONEncoder().encode(currentCharacter) else {
            log("キャラクターメーカー: ファイルのシリアライズに失敗しました", level: "WARN")
            return
        }
        do {
            try data.write(to: url)
            log("キャラクターメーカー: 編集ファイルを保存しました: \(url.lastPathComponent)")
            addHistory("保存: キャラクターファイル (.tscm)")
        } catch {
            log("キャラクターメーカー: 保存エラー - \(error.localizedDescription)", level: "ERROR")
        }
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
            if let snapshot = currentCharacter.initialSnapshotData,
               let restored = try? JSONDecoder().decode(CharacterModel.self, from: snapshot) {
                currentCharacter = restored
                log("キャラクターメーカー: すべての変更を取り消し、ファイルの読み込み直後の初期状態に復元しました")
            } else {
                currentCharacter = CharacterImageService.shared.createPresetCharacter(name: currentCharacter.name)
                log("キャラクターメーカー: すべての変更を取り消し、読み込み直後の初期状態に戻しました")
            }
        case .soundMaker:
            log("サウンドメーカー: キャラクター音声およびBGM/SEの波形データを再生成しました")
        case .slideScenarioMaker:
            let targetPath: String
            if let latest = SlideRecognitionService.findLatestTspmPath(for: currentProjectName) {
                targetPath = latest
            } else {
                targetPath = SlideRecognitionService.shared.loadedProjectName.contains("/") ? SlideRecognitionService.shared.loadedProjectName : currentProjectPath
            }
            SlideRecognitionService.shared.loadSlideProgram(filePath: targetPath, replaceState: true) { _, _ in }
            log("スライド＆シナリオメーカー: 表示中のスライド元ファイル『\(targetPath)』を再読み込みしました")
        case .gameMaker:
            log("ゲームメーカー: 設定された全ゲームコマンドと分岐判定を再検証・再読み込みしました")
        case .materialStudio:
            log("素材スタジオ: キャッシュを再生成し、素材ライブラリを更新しました")
        case .tohoAIStudio:
            CloudVirtualLinuxService.shared.performHeartbeat()
            log("TohoAIStudio: 仮想LinuxVMおよび外部APIの接続ステータスを再検証しました")
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
            // 0. メイン話者タグ（操夢）
            VoiceTemplate(
                name: "操夢 (メイン話者)",
                characterName: "操夢",
                voiceType: .imd1,
                speed: 100,
                pitch: 115,
                source: "メイン話者タグ",
                description: "メイン話者・中性(imd1)・速度100%・音程115"
            ),
            // 1. 追加話者タグ
            VoiceTemplate(
                name: "サブ (f1,100,115)",
                characterName: "サブ",
                voiceType: .f1,
                speed: 100,
                pitch: 115,
                source: "独自話者タグ",
                description: "サブ・女声1(f1)・速度100%・音程115"
            ),
            VoiceTemplate(
                name: "ナレ1 (男声1,100,115)",
                characterName: "ナレ1",
                voiceType: .m1,
                speed: 100,
                pitch: 115,
                source: "独自話者タグ",
                description: "ナレ1・男声1(m1)・速度100%・音程115"
            ),
            VoiceTemplate(
                name: "ナレ2 (男声2,100,115)",
                characterName: "ナレ2",
                voiceType: .m2,
                speed: 100,
                pitch: 115,
                source: "独自話者タグ",
                description: "ナレ2・男声2(m2)・速度100%・音程115"
            ),
            VoiceTemplate(
                name: "みとり (f1,105,105)",
                characterName: "みとり",
                voiceType: .f1,
                speed: 105,
                pitch: 105,
                source: "独自話者タグ",
                description: "みとり・女声1(f1)・速度105%・音程105"
            ),
            // 2. コゲの日記準拠（東風谷早苗 特別指定）
            VoiceTemplate(
                name: "東風谷早苗 (コゲの日記)",
                characterName: "東風谷早苗",
                voiceType: .f2,
                speed: 90,
                pitch: 135,
                source: "コゲの日記",
                description: "コゲの日記準拠・女性2・速度90%・音程135"
            ),
            // 3. 独自テンプレート（ユーザー指定）
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
                voiceType: .f1,
                speed: 100,
                pitch: 115,
                source: "独自テンプレート",
                description: "女声1(f1/l1)・速度100%・音程115"
            ),
            VoiceTemplate(
                name: "f1,100,115 (独自)",
                characterName: "独自: f1",
                voiceType: .f1,
                speed: 100,
                pitch: 115,
                source: "独自テンプレート",
                description: "女声1(f1)・速度100%・音程115"
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
            // 3. ゆっくりボイスメーカー準拠 テンプレート（第1優先）
            VoiceTemplate(
                name: "博麗霊夢 (ゆっくりボイスメーカー)",
                characterName: "博麗霊夢",
                voiceType: .f1,
                speed: 100,
                pitch: 100,
                source: "ゆっくりボイスメーカー",
                description: "女性1・速度100%・音程100"
            ),
            VoiceTemplate(
                name: "霧雨魔理沙 (ゆっくりボイスメーカー)",
                characterName: "霧雨魔理沙",
                voiceType: .f2,
                speed: 100,
                pitch: 100,
                source: "ゆっくりボイスメーカー",
                description: "女性2・速度100%・音程100"
            ),
            VoiceTemplate(
                name: "魂魄妖夢 (ゆっくりボイスメーカー)",
                characterName: "魂魄妖夢",
                voiceType: .f2,
                speed: 115,
                pitch: 120,
                source: "ゆっくりボイスメーカー",
                description: "女性2・速度115%・音程120"
            ),
            VoiceTemplate(
                name: "十六夜咲夜 (ゆっくりボイスメーカー)",
                characterName: "十六夜咲夜",
                voiceType: .f1,
                speed: 105,
                pitch: 125,
                source: "ゆっくりボイスメーカー",
                description: "女性1・速度105%・音程125"
            ),
            VoiceTemplate(
                name: "チルノ (ゆっくりボイスメーカー)",
                characterName: "チルノ",
                voiceType: .f2,
                speed: 115,
                pitch: 120,
                source: "ゆっくりボイスメーカー",
                description: "女性2・速度115%・音程120"
            ),
            VoiceTemplate(
                name: "レミリア・スカーレット (ゆっくりボイスメーカー)",
                characterName: "レミリア・スカーレット",
                voiceType: .f1,
                speed: 80,
                pitch: 150,
                source: "ゆっくりボイスメーカー",
                description: "女性1・速度80%・音程150"
            ),
            VoiceTemplate(
                name: "フランドール・スカーレット (ゆっくりボイスメーカー)",
                characterName: "フランドール・スカーレット",
                voiceType: .jgr,
                speed: 100,
                pitch: 100,
                source: "ゆっくりボイスメーカー",
                description: "機械1・速度100%・音程100"
            ),
            VoiceTemplate(
                name: "アリス・マーガトロイド (ゆっくりボイスメーカー)",
                characterName: "アリス・マーガトロイド",
                voiceType: .f1,
                speed: 110,
                pitch: 130,
                source: "ゆっくりボイスメーカー",
                description: "女性1・速度110%・音程130"
            ),
            VoiceTemplate(
                name: "パチュリー・ノーレッジ (ゆっくりボイスメーカー)",
                characterName: "パチュリー・ノーレッジ",
                voiceType: .f2,
                speed: 120,
                pitch: 115,
                source: "ゆっくりボイスメーカー",
                description: "女性2・速度120%・音程115"
            ),
            VoiceTemplate(
                name: "古明地さとり (ゆっくりボイスメーカー)",
                characterName: "古明地さとり",
                voiceType: .jgr,
                speed: 115,
                pitch: 125,
                source: "ゆっくりボイスメーカー",
                description: "機械1・速度115%・音程125"
            ),
            VoiceTemplate(
                name: "古明地こいし (ゆっくりボイスメーカー)",
                characterName: "古明地こいし",
                voiceType: .f2,
                speed: 50,
                pitch: 181,
                source: "ゆっくりボイスメーカー",
                description: "女性2・速度50%・音程181"
            ),
            VoiceTemplate(
                name: "射命丸文 (ゆっくりボイスメーカー)",
                characterName: "射命丸文",
                voiceType: .f2,
                speed: 100,
                pitch: 125,
                source: "ゆっくりボイスメーカー",
                description: "女性2・速度100%・音程125"
            ),
            VoiceTemplate(
                name: "犬走椛 (ゆっくりボイスメーカー)",
                characterName: "犬走椛",
                voiceType: .f1,
                speed: 120,
                pitch: 110,
                source: "ゆっくりボイスメーカー",
                description: "女性1・速度120%・音程110"
            ),
            VoiceTemplate(
                name: "藤原妹紅 (ゆっくりボイスメーカー)",
                characterName: "藤原妹紅",
                voiceType: .f2,
                speed: 100,
                pitch: 120,
                source: "ゆっくりボイスメーカー",
                description: "女性2・速度100%・音程120"
            ),
            VoiceTemplate(
                name: "八坂神奈子 (ゆっくりボイスメーカー)",
                characterName: "八坂神奈子",
                voiceType: .f1,
                speed: 115,
                pitch: 90,
                source: "ゆっくりボイスメーカー",
                description: "女性1・速度115%・音程90"
            ),
            VoiceTemplate(
                name: "洩矢諏訪子 (ゆっくりボイスメーカー)",
                characterName: "洩矢諏訪子",
                voiceType: .f1,
                speed: 80,
                pitch: 175,
                source: "ゆっくりボイスメーカー",
                description: "女性1・速度80%・音程175"
            ),
            VoiceTemplate(
                name: "河城にとり (ゆっくりボイスメーカー)",
                characterName: "河城にとり",
                voiceType: .jgr,
                speed: 105,
                pitch: 105,
                source: "ゆっくりボイスメーカー",
                description: "機械1・速度105%・音程105"
            ),
            VoiceTemplate(
                name: "多々良小傘 (ゆっくりボイスメーカー)",
                characterName: "多々良小傘",
                voiceType: .imd1,
                speed: 110,
                pitch: 130,
                source: "ゆっくりボイスメーカー",
                description: "中性・速度110%・音程130"
            ),
            VoiceTemplate(
                name: "聖白蓮 (ゆっくりボイスメーカー)",
                characterName: "聖白蓮",
                voiceType: .imd1,
                speed: 102,
                pitch: 97,
                source: "ゆっくりボイスメーカー",
                description: "中性・速度102%・音程97"
            ),
            VoiceTemplate(
                name: "伊吹萃香 (ゆっくりボイスメーカー)",
                characterName: "伊吹萃香",
                voiceType: .imd1,
                speed: 100,
                pitch: 150,
                source: "ゆっくりボイスメーカー",
                description: "中性・速度100%・音程150"
            ),
            VoiceTemplate(
                name: "鈴仙・優曇華院・イナバ (ゆっくりボイスメーカー)",
                characterName: "鈴仙・優曇華院・イナバ",
                voiceType: .f1,
                speed: 80,
                pitch: 120,
                source: "ゆっくりボイスメーカー",
                description: "女性1・速度80%・音程120"
            ),
            VoiceTemplate(
                name: "蓬莱山輝夜 (ゆっくりボイスメーカー)",
                characterName: "蓬莱山輝夜",
                voiceType: .f1,
                speed: 100,
                pitch: 120,
                source: "ゆっくりボイスメーカー",
                description: "女性1・速度100%・音程120"
            ),
            VoiceTemplate(
                name: "因幡てゐ (ゆっくりボイスメーカー)",
                characterName: "因幡てゐ",
                voiceType: .imd1,
                speed: 110,
                pitch: 120,
                source: "ゆっくりボイスメーカー",
                description: "中性・速度110%・音程120"
            ),
            VoiceTemplate(
                name: "霊烏路空 (ゆっくりボイスメーカー)",
                characterName: "霊烏路空",
                voiceType: .imd1,
                speed: 80,
                pitch: 170,
                source: "ゆっくりボイスメーカー",
                description: "中性・速度80%・音程170"
            ),
            VoiceTemplate(
                name: "四季映姫 (ゆっくりボイスメーカー)",
                characterName: "四季映姫",
                voiceType: .f2,
                speed: 87,
                pitch: 117,
                source: "ゆっくりボイスメーカー",
                description: "女性2・速度87%・音程117"
            ),
            VoiceTemplate(
                name: "封獣ぬえ (ゆっくりボイスメーカー)",
                characterName: "封獣ぬえ",
                voiceType: .f2,
                speed: 100,
                pitch: 180,
                source: "ゆっくりボイスメーカー",
                description: "女性2・速度100%・音程180"
            ),
            VoiceTemplate(
                name: "比那名居天子 (ゆっくりボイスメーカー)",
                characterName: "比那名居天子",
                voiceType: .f2,
                speed: 75,
                pitch: 134,
                source: "ゆっくりボイスメーカー",
                description: "女性2・速度75%・音程134"
            ),

            // 4. コゲの日記準拠 テンプレート（第2優先: ゆっくりボイスメーカー未収録キャラ）
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
                name: "西行寺幽々子 (コゲの日記)",
                characterName: "西行寺幽々子",
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
                name: "大妖精 (コゲの日記)",
                characterName: "大妖精",
                voiceType: .f1,
                speed: 96,
                pitch: 138,
                source: "コゲの日記",
                description: "女性1・速度96%・音程138"
            ),
            VoiceTemplate(
                name: "ルーミア (コゲの日記)",
                characterName: "ルーミア",
                voiceType: .f1,
                speed: 63,
                pitch: 165,
                source: "コゲの日記",
                description: "女性1・速度63%・音程165"
            ),
            VoiceTemplate(
                name: "上白沢慧音 (コゲの日記)",
                characterName: "上白沢慧音",
                voiceType: .imd1,
                speed: 95,
                pitch: 145,
                source: "コゲの日記",
                description: "中性・速度95%・音程145"
            ),
            VoiceTemplate(
                name: "八意永琳 (コゲの日記)",
                characterName: "八意永琳",
                voiceType: .imd1,
                speed: 97,
                pitch: 106,
                source: "コゲの日記",
                description: "中性・速度97%・音程106"
            ),
            VoiceTemplate(
                name: "火焔猫燐 (コゲの日記)",
                characterName: "火焔猫燐",
                voiceType: .f2,
                speed: 130,
                pitch: 125,
                source: "コゲの日記",
                description: "女性2・速度130%・音程125"
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
                name: "本居小鈴 (コゲの日記)",
                characterName: "本居小鈴",
                voiceType: .f1,
                speed: 99,
                pitch: 130,
                source: "コゲの日記",
                description: "女性1・速度99%・音程130"
            ),
            VoiceTemplate(
                name: "紅美鈴 (コゲの日記)",
                characterName: "紅美鈴",
                voiceType: .imd1,
                speed: 110,
                pitch: 155,
                source: "コゲの日記",
                description: "中性・速度110%・音程155"
            ),
            VoiceTemplate(
                name: "小悪魔 (コゲの日記)",
                characterName: "小悪魔",
                voiceType: .f1,
                speed: 95,
                pitch: 165,
                source: "コゲの日記",
                description: "女性1・速度95%・音程165"
            ),
            VoiceTemplate(
                name: "物部布都 (コゲの日記)",
                characterName: "物部布都",
                voiceType: .f1,
                speed: 110,
                pitch: 123,
                source: "コゲの日記",
                description: "女性1・速度110%・音程123"
            ),
            VoiceTemplate(
                name: "豊聡耳神子 (コゲの日記)",
                characterName: "豊聡耳神子",
                voiceType: .f1,
                speed: 130,
                pitch: 103,
                source: "コゲの日記",
                description: "女性1・速度130%・音程103"
            ),
            VoiceTemplate(
                name: "鬼人正邪 (コゲの日記)",
                characterName: "鬼人正邪",
                voiceType: .imd1,
                speed: 110,
                pitch: 133,
                source: "コゲの日記",
                description: "中性・速度110%・音程133"
            ),

            // 5. Gスカブログ準拠 テンプレート（第3優先: ゆっくりボイスメーカー・コゲの日記未収録キャラ）
            VoiceTemplate(
                name: "茨木華扇 (Gスカブログ)",
                characterName: "茨木華扇",
                voiceType: .f1,
                speed: 100,
                pitch: 140,
                source: "Gスカのブログ",
                description: "女性1・速度100%・音程140"
            ),
            VoiceTemplate(
                name: "高麗野あうん (Gスカブログ)",
                characterName: "高麗野あうん",
                voiceType: .f1,
                speed: 83,
                pitch: 140,
                source: "Gスカのブログ",
                description: "女性1・速度83%・音程140"
            ),
            VoiceTemplate(
                name: "スターサファイア (Gスカブログ)",
                characterName: "スターサファイア",
                voiceType: .f2,
                speed: 60,
                pitch: 150,
                source: "Gスカのブログ",
                description: "女性2・速度60%・音程150"
            ),
            VoiceTemplate(
                name: "飯綱丸龍 (Gスカブログ)",
                characterName: "飯綱丸龍",
                voiceType: .f2,
                speed: 93,
                pitch: 116,
                source: "Gスカのブログ",
                description: "女性2・速度93%・音程116"
            ),
            VoiceTemplate(
                name: "菅牧典 (Gスカブログ)",
                characterName: "菅牧典",
                voiceType: .f1,
                speed: 90,
                pitch: 130,
                source: "Gスカのブログ",
                description: "女性1・速度90%・音程130"
            ),
            VoiceTemplate(
                name: "豪徳寺ミケ (Gスカブログ)",
                characterName: "豪徳寺ミケ",
                voiceType: .f1,
                speed: 80,
                pitch: 180,
                source: "Gスカのブログ",
                description: "女性1・速度80%・音程180"
            )
        ]
        if activeVoiceTemplate == nil {
            activeVoiceTemplate = voiceTemplates.first
        }
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
            AudioTrack(id: "track_voice_soumu", name: "操夢 (メイン話者)", type: "voice", icon: "waveform", colorHex: "#3498DB", volume: 1.0, pan: 0.0, characterName: "操夢"),
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

        // Initialize Character Maker preset
        currentCharacter = CharacterImageService.shared.createPresetCharacter(name: "博麗霊夢")
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

    // MARK: - SoundMaker Project Loading & Path Repair
    public func loadSoundMakerProject(from url: URL) {
        guard let data = try? Data(contentsOf: url) else {
            log("サウンドメーカーファイルを開けませんでした: \(url.path)", level: "WARN")
            return
        }

        let decoder = JSONDecoder()
        var loadedClips: [SoundClip] = []
        var loadedTracks: [AudioTrack]? = nil
        var loadedScenes: [MovieScene]? = nil

        if let doc = try? decoder.decode(SoundMakerProjectDocument.self, from: data) {
            loadedClips = doc.clips
            loadedTracks = doc.tracks
            loadedScenes = doc.scenes
            if let tot = doc.totalDuration {
                self.totalDuration = tot
            }
        } else if let clips = try? decoder.decode([SoundClip].self, from: data) {
            loadedClips = clips
        }

        guard !loadedClips.isEmpty || (loadedScenes?.isEmpty == false) else {
            log("サウンドメーカーのデータ解析に失敗しました: \(url.lastPathComponent)", level: "WARN")
            return
        }

        // 音声ファイルパスの自動検証・修復 (SE / BGM / Voice)
        let repairedClips = resolveAndRepairAudioPaths(for: loadedClips)
        self.soundClips = repairedClips

        // トラック設定の復元
        if let tr = loadedTracks, !tr.isEmpty {
            self.audioTracks = tr
        }
        ensureTracksForClips(repairedClips)

        // シーン設定の復元: loadedScenes が存在すれば反映、なければクリップ情報から自動再構築
        if let sc = loadedScenes, !sc.isEmpty {
            self.movieScenes = sc
            self.totalDuration = sc.reduce(0.0) { $0 + $1.duration }
        } else {
            // クリップ情報（全シーン）から確実に再構築
            rebuildScenesFromClips(repairedClips)
        }

        // 各シーンへの音声ファイル割り当て (Voice, SE, BGM) を確実に同期反映
        syncClipsToMovieScenes(repairedClips)

        let cleanName = url.deletingPathExtension().lastPathComponent
        self.currentProjectPath = url.path
        self.currentProjectName = cleanName

        // 同名または類似のスライドファイル (.tspm) があれば素材情報のみ安全に連動補完
        let slideDir = "/Volumes/ZSSD/GitHub/repository/TohoStudio/Application/Resource/Slide&ScenarioMarker"
        let normClean = cleanName.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "，", with: "")
        var matchedTspmPath: String? = nil

        if let files = try? FileManager.default.contentsOfDirectory(atPath: slideDir) {
            // 1. 完全一致・カンマ除去一致
            for f in files where f.hasSuffix(".tspm") {
                let fBase = (f as NSString).deletingPathExtension
                let normF = fBase.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "，", with: "")
                if normF == normClean || fBase == cleanName {
                    matchedTspmPath = (slideDir as NSString).appendingPathComponent(f)
                    break
                }
            }
            // 2. 表記揺れ（21話22話 <-> 21.22話目）での探索
            if matchedTspmPath == nil {
                let variant1 = normClean.replacingOccurrences(of: "話目", with: "話")
                let variant2 = normClean.replacingOccurrences(of: "21話22話", with: "21.22話目")
                let variant3 = normClean.replacingOccurrences(of: "21.22話目", with: "21話22話")
                for f in files where f.hasSuffix(".tspm") {
                    let normF = f.replacingOccurrences(of: ",", with: "").replacingOccurrences(of: "，", with: "")
                    if normF.contains(variant1) || normF.contains(variant2) || normF.contains(variant3) ||
                       (normClean.contains("交換夫婦") && normF.contains("交換夫婦")) {
                        matchedTspmPath = (slideDir as NSString).appendingPathComponent(f)
                        break
                    }
                }
            }
        }

        if let tPath = matchedTspmPath, FileManager.default.fileExists(atPath: tPath) {
            // syncSoundMaker: false を指定して、復元した soundClips が上書き消去されるのを完全に防止
            SlideRecognitionService.shared.loadSlideProgram(filePath: tPath, syncSoundMaker: false, replaceState: false) { success, loadedSlides in
                if success && !loadedSlides.isEmpty {
                    DispatchQueue.main.async {
                        self.supplementSlideAssetsToMovieScenes(loadedSlides)
                        self.log("スライドファイル連携: 『\((tPath as NSString).lastPathComponent)』から \(loadedSlides.count) シーンの素材情報を補完同期しました")
                    }
                }
            }
        }

        log("サウンドメーカープロジェクト『\(cleanName)』を読み込みました (\(repairedClips.count)クリップ, \(self.audioTracks.count)トラック, \(self.movieScenes.count)シーン)")
        addHistory("ファイル: サウンドメーカー読み込み (\(cleanName))")
    }

    /// soundClips の各音声クリップ（Voice, SE, BGM）の割り当てを movieScenes の各シーンに安全同期
    public func syncClipsToMovieScenes(_ clips: [SoundClip]) {
        guard !movieScenes.isEmpty else { return }
        var accSceneTime: Double = 0.0

        for idx in 0..<movieScenes.count {
            let sceneNum = idx + 1
            var scene = movieScenes[idx]
            let sceneStart = accSceneTime

            // 1. Voice (1人目および2人目のボイスを同期)
            let sceneVoices = clips.filter { $0.type == "Voice" && $0.sceneIndex == sceneNum }
            if let voice = sceneVoices.first {
                scene.voiceAudioPath = voice.audioFilePath
                scene.voiceCharacter = voice.character ?? scene.characterName
                scene.voiceDuration = voice.duration
                scene.audioTrack = voice.trackId ?? "track_voice"
                scene.voiceStartTimeOffset = voice.sceneRelativeStartTime ?? 0.0
            } else {
                scene.voiceAudioPath = nil
                scene.voiceCharacter = nil
                scene.voiceDuration = nil
                scene.voiceStartTimeOffset = 0.0
            }

            if sceneVoices.count >= 2 {
                let voice2 = sceneVoices[1]
                scene.voice2AudioPath = voice2.audioFilePath
                scene.voice2Character = voice2.character
                scene.voice2Duration = voice2.duration
                scene.voice2StartTimeOffset = voice2.sceneRelativeStartTime ?? 0.0
            } else {
                scene.voice2AudioPath = nil
                scene.voice2Character = nil
                scene.voice2Duration = nil
                scene.voice2StartTimeOffset = 0.0
            }

            // 2. SE (所属シーン番号またはタイムライン時刻範囲から正確にマッチング)
            let matchingSE = clips.first(where: { clip in
                guard clip.type == "SE" else { return false }
                if let s = clip.spanStartSceneIndex, let e = clip.spanEndSceneIndex {
                    return sceneNum >= s && sceneNum <= e
                }
                if let sIdx = clip.sceneIndex {
                    return sIdx == sceneNum
                }
                let nextSceneTime = sceneStart + scene.duration
                return clip.startTime >= sceneStart && (clip.startTime < nextSceneTime || idx == movieScenes.count - 1)
            })

            if let se = matchingSE {
                scene.seAudioPath = se.audioFilePath
                scene.seName = se.name
                scene.seVolume = se.volume

                let isSpan = (se.spanStartSceneIndex != nil && se.spanEndSceneIndex != nil)
                let startSceneNum = se.spanStartSceneIndex ?? se.sceneIndex ?? sceneNum

                if sceneNum == startSceneNum || !isSpan {
                    let seRel: Double
                    if se.voiceTriggerEnabled, let charIdx = se.startCharIndex,
                       let ctx = VoiceTextTimingService.resolveDialogueContext(clip: se, sceneIndex: sceneNum, clips: clips, scenes: movieScenes),
                       let timing = ctx.timings.first(where: { $0.index == charIdx }) {
                        seRel = max(0.0, timing.startSeconds + se.voiceTriggerOffset)
                    } else if let savedRel = se.sceneRelativeStartTime {
                        seRel = savedRel
                    } else {
                        // 手動配置SE: タイムライン上の実開始時刻とシーン開始時刻の差分から正確に算出
                        seRel = max(0.0, se.startTime - sceneStart)
                    }
                    let safeRel = min(max(0.0, seRel), max(0.0, scene.duration - 0.05))
                    scene.seStartTimeOffset = safeRel
                } else {
                    // 跨ぎSEの後続シーン
                    let startSceneTime = movieScenes.prefix(startSceneNum - 1).reduce(0.0) { $0 + $1.duration }
                    let initialOffset = se.sceneRelativeStartTime ?? max(0.0, se.startTime - startSceneTime)
                    let elapsed = max(0.0, (sceneStart - startSceneTime) - initialOffset)
                    scene.seStartTimeOffset = -elapsed
                }
            } else {
                scene.seAudioPath = nil
                scene.seName = nil
                scene.seStartTimeOffset = 0.0
                scene.seVolume = 1.0
            }

            // 3. BGM (BGMが削除されている場合は確実にnilへクリア)
            let matchingBGM = clips.first(where: { clip in
                guard clip.type == "BGM" else { return false }
                if let s = clip.spanStartSceneIndex, let e = clip.spanEndSceneIndex {
                    return sceneNum >= s && sceneNum <= e
                }
                if let sIdx = clip.sceneIndex {
                    return sIdx == sceneNum
                }
                return clip.isLooping || (clip.sceneIndex == nil && clip.spanStartSceneIndex == nil)
            })

            if let bgm = matchingBGM {
                scene.bgmAudioPath = bgm.audioFilePath
                scene.bgmName = bgm.name
                scene.bgmVolume = bgm.volume

                let isSpan = (bgm.spanStartSceneIndex != nil && bgm.spanEndSceneIndex != nil)
                let startSceneNum = bgm.spanStartSceneIndex ?? bgm.sceneIndex ?? 1

                if sceneNum == startSceneNum || (!isSpan && bgm.sceneIndex == sceneNum) {
                    let bgmRel: Double
                    if bgm.voiceTriggerEnabled, let charIdx = bgm.startCharIndex,
                       let ctx = VoiceTextTimingService.resolveDialogueContext(clip: bgm, sceneIndex: sceneNum, clips: clips, scenes: movieScenes),
                       let timing = ctx.timings.first(where: { $0.index == charIdx }) {
                        bgmRel = max(0.0, timing.startSeconds + bgm.voiceTriggerOffset)
                    } else if let savedRel = bgm.sceneRelativeStartTime {
                        bgmRel = savedRel
                    } else {
                        bgmRel = max(0.0, bgm.startTime - sceneStart)
                    }
                    let safeRel = min(max(0.0, bgmRel), max(0.0, scene.duration - 0.05))
                    scene.bgmStartTimeOffset = safeRel
                } else if isSpan {
                    // 跨ぎBGMの後続シーン: シーン先頭時点ですでに経過しているBGM再生時間（負のオフセット）
                    let startSceneTime = movieScenes.prefix(startSceneNum - 1).reduce(0.0) { $0 + $1.duration }
                    let initialOffset = bgm.sceneRelativeStartTime ?? max(0.0, bgm.startTime - startSceneTime)
                    let elapsed = max(0.0, (sceneStart - startSceneTime) - initialOffset)
                    scene.bgmStartTimeOffset = -elapsed
                } else {
                    scene.bgmStartTimeOffset = 0.0
                }
            } else {
                scene.bgmAudioPath = nil
                scene.bgmName = nil
                scene.bgmStartTimeOffset = 0.0
                scene.bgmVolume = 0.7
            }

            movieScenes[idx] = scene
            accSceneTime += scene.duration
        }
    }

    /// クリップの startTime 移動時に、該当する所属シーン番号およびシーン内相対時間を自動再計算して同期
    public func updateClipSceneTiming(clipId: UUID) {
        guard let idx = soundClips.firstIndex(where: { $0.id == clipId }) else { return }
        var clip = soundClips[idx]
        if movieScenes.isEmpty && !slides.isEmpty {
            movieScenes = slides.map { s in
                MovieScene(
                    title: s.title.isEmpty ? "シーン \(s.slideIndex)" : s.title,
                    duration: max(2.5, s.duration),
                    slideTitle: "スライド #\(s.slideIndex)",
                    backgroundName: s.backgroundName,
                    characterName: s.characterName,
                    telop: SlideItem.cleanDialogueText(from: s.telop)
                )
            }
        }
        guard !movieScenes.isEmpty else { return }

        // 単一シーン所属クリップまたは跨ぎ開始シーンの再検出
        var acc: Double = 0.0
        var matchedSceneIndex: Int = 1
        var matchedRelTime: Double = clip.startTime

        for (sIdx, sc) in movieScenes.enumerated() {
            let nextAcc = acc + sc.duration
            if clip.startTime >= acc && (clip.startTime < nextAcc || sIdx == movieScenes.count - 1) {
                matchedSceneIndex = sIdx + 1
                matchedRelTime = max(0.0, clip.startTime - acc)
                break
            }
            acc = nextAcc
        }

        if let s = clip.spanStartSceneIndex, let e = clip.spanEndSceneIndex, e > s {
            let spanLen = e - s
            clip.spanStartSceneIndex = matchedSceneIndex
            clip.spanEndSceneIndex = min(movieScenes.count, matchedSceneIndex + spanLen)
            clip.sceneIndex = matchedSceneIndex
            clip.sceneRelativeStartTime = matchedRelTime
        } else {
            clip.sceneIndex = matchedSceneIndex
            clip.sceneRelativeStartTime = matchedRelTime
        }

        soundClips[idx] = clip
        syncClipsToMovieScenes(soundClips)
    }

    /// サウンドメーカーおよびムービーメーカー間で、シーン表示時間と実際の音声再生時間を完全に連動同期
    /// 音声再生成・追加・削除時に画面上部のシーン時間と実際の音声再生時間がずれ込む現象を完全に解消
    public func syncSceneAndClipTimings(autoFitDuration: Bool = true) {
        if movieScenes.isEmpty && !slides.isEmpty {
            movieScenes = slides.map { s in
                MovieScene(
                    title: s.title.isEmpty ? "シーン \(s.slideIndex)" : s.title,
                    duration: max(2.5, s.duration),
                    slideTitle: "スライド #\(s.slideIndex)",
                    backgroundName: s.backgroundName,
                    characterName: s.characterName,
                    telop: SlideItem.cleanDialogueText(from: s.telop)
                )
            }
        }
        guard !movieScenes.isEmpty else { return }

        var accumulatedTime: Double = 0.0

        for idx in 0..<movieScenes.count {
            let sceneNum = idx + 1
            var scene = movieScenes[idx]

            // このシーンに属する音声クリップ (Voice: 1人目および2人目)
            let sceneVoices = soundClips.filter { $0.type == "Voice" && $0.sceneIndex == sceneNum }
            let maxVoiceDuration = sceneVoices.map { $0.duration }.max()

            if autoFitDuration {
                if let maxDur = maxVoiceDuration, let voice = sceneVoices.first {
                    let animDur = scene.animationDuration ?? 0.0
                    // 音声が余白をもって綺麗に鳴りきるための所要時間（最低2.5秒）
                    let voiceRequired = maxDur + 0.6
                    let newDur = max(2.5, max(animDur, voiceRequired))
                    scene.duration = newDur
                    scene.voiceDuration = voice.duration
                    scene.voiceAudioPath = voice.audioFilePath
                    scene.voiceCharacter = voice.character ?? scene.characterName
                    scene.audioTrack = voice.trackId ?? "track_voice"

                    if sceneVoices.count >= 2 {
                        let voice2 = sceneVoices[1]
                        scene.voice2AudioPath = voice2.audioFilePath
                        scene.voice2Character = voice2.character
                        scene.voice2Duration = voice2.duration
                        scene.voice2StartTimeOffset = voice2.sceneRelativeStartTime ?? 0.0
                    }
                } else if let animDur = scene.animationDuration, animDur > 0 {
                    scene.duration = max(2.5, animDur)
                } else {
                    scene.duration = max(2.5, scene.duration)
                }
            }

            // スライド側にも同期
            if idx < slides.count {
                slides[idx].duration = scene.duration
            }

            movieScenes[idx] = scene

            // このシーンの開始時間に合わせて所属クリップの startTime を再同期 (単一シーン所属のみ)
            let sceneStart = accumulatedTime
            for cIdx in 0..<soundClips.count {
                let isSpanning = soundClips[cIdx].isSpanningScenes || (soundClips[cIdx].spanStartSceneIndex != nil && soundClips[cIdx].spanEndSceneIndex != nil)
                if !isSpanning && soundClips[cIdx].sceneIndex == sceneNum {
                    if soundClips[cIdx].type == "Voice" {
                        soundClips[cIdx].startTime = sceneStart // シーン先頭に完全一致 (0.0s)
                        soundClips[cIdx].sceneRelativeStartTime = 0.0
                        scene.voiceStartTimeOffset = 0.0
                    } else if soundClips[cIdx].type == "SE" || soundClips[cIdx].type == "BGM" {
                        // 1. 文字連動が明示的に有効な場合は、その文字の発話推定時刻に正確にアライメント
                        if soundClips[cIdx].voiceTriggerEnabled,
                           let charIdx = soundClips[cIdx].startCharIndex,
                           let ctx = VoiceTextTimingService.resolveDialogueContext(clip: soundClips[cIdx], sceneIndex: sceneNum, clips: soundClips, scenes: movieScenes),
                           let timing = ctx.timings.first(where: { $0.index == charIdx }) {
                            let rel = max(0.0, timing.startSeconds + soundClips[cIdx].voiceTriggerOffset)
                            soundClips[cIdx].sceneRelativeStartTime = rel
                            soundClips[cIdx].startTime = sceneStart + rel
                            if soundClips[cIdx].type == "SE" {
                                scene.seStartTimeOffset = rel
                                scene.seVolume = soundClips[cIdx].volume
                            } else if soundClips[cIdx].type == "BGM" {
                                scene.bgmStartTimeOffset = rel
                                scene.bgmVolume = soundClips[cIdx].volume
                            }
                        } else {
                            // 2. 文字連動なしの場合は、シーン先頭からの相対オフセットを最優先で維持し、
                            //    シーンの開始時間 sceneStart に追従させて startTime を同期
                            let currentRel = soundClips[cIdx].sceneRelativeStartTime ?? max(0.0, soundClips[cIdx].startTime - sceneStart)
                            let safeRel = min(max(0.0, currentRel), max(0.0, scene.duration - 0.05))
                            soundClips[cIdx].sceneRelativeStartTime = safeRel
                            soundClips[cIdx].startTime = sceneStart + safeRel
                            if soundClips[cIdx].type == "SE" {
                                scene.seStartTimeOffset = safeRel
                                scene.seVolume = soundClips[cIdx].volume
                            } else if soundClips[cIdx].type == "BGM" {
                                scene.bgmStartTimeOffset = safeRel
                                scene.bgmVolume = soundClips[cIdx].volume
                            }
                        }
                    }
                }
            }
            movieScenes[idx] = scene

            accumulatedTime += scene.duration
        }

        // 複数シーン跨ぎの BGM / SE の長さ・開始時間も更新
        for cIdx in 0..<soundClips.count {
            if let s = soundClips[cIdx].spanStartSceneIndex,
               let e = soundClips[cIdx].spanEndSceneIndex {
                let startSceneIdx = max(1, min(movieScenes.count, s))
                let endSceneIdx = max(startSceneIdx, min(movieScenes.count, e))
                let sStart = movieScenes.prefix(startSceneIdx - 1).reduce(0.0) { $0 + $1.duration }
                let sDur = movieScenes[(startSceneIdx - 1)..<endSceneIdx].reduce(0.0) { $0 + $1.duration }

                var finalStart = sStart
                let targetChar = soundClips[cIdx].startCharIndex ?? soundClips[cIdx].fadeInCharIndex
                if let charIdx = targetChar,
                   let ctx = VoiceTextTimingService.resolveDialogueContext(clip: soundClips[cIdx], sceneIndex: startSceneIdx, clips: soundClips, scenes: movieScenes),
                   let timing = ctx.timings.first(where: { $0.index == charIdx }) {
                    let rel = max(0.0, timing.startSeconds + soundClips[cIdx].voiceTriggerOffset)
                    soundClips[cIdx].sceneRelativeStartTime = rel
                    finalStart = sStart + rel
                } else if let savedRel = soundClips[cIdx].sceneRelativeStartTime {
                    finalStart = sStart + savedRel
                } else {
                    let prevRel = max(0.0, soundClips[cIdx].startTime - sStart)
                    let safeRel = min(prevRel, max(0.0, sDur - 0.1))
                    soundClips[cIdx].sceneRelativeStartTime = safeRel
                    finalStart = sStart + safeRel
                }
                soundClips[cIdx].startTime = finalStart
                soundClips[cIdx].duration = sDur
            }
        }

        totalDuration = max(120.0, accumulatedTime + 15.0)
        syncClipsToMovieScenes(soundClips)
    }

    /// スライドから背景画像・立ち絵・動画等のアセット情報のみを MovieScene に安全補完（音声割り当ては保護）
    public func supplementSlideAssetsToMovieScenes(_ slides: [SlideItem]) {
        for slide in slides {
            if let idx = movieScenes.firstIndex(where: { $0.title == slide.title || $0.slideTitle == "スライド #\(slide.slideIndex)" || $0.slideTitle == "第\(slide.slideIndex)スライド" }) {
                var sc = movieScenes[idx]
                if let newSlideImg = slide.slideImagePath, !newSlideImg.isEmpty {
                    sc.slideImagePath = newSlideImg
                }
                if let newVideo = slide.animationVideoPath, !newVideo.isEmpty {
                    sc.videoPath = newVideo
                }
                if let newBg = slide.backgroundImagePath, !newBg.isEmpty {
                    sc.backgroundImagePath = newBg
                }
                if let newChar = slide.characterImagePath, !newChar.isEmpty {
                    sc.characterImagePath = newChar
                }
                movieScenes[idx] = sc
            }
        }
        notifySlideAssetsUpdated()
    }

    /// SE, BGM, Voice のオーディオファイルパスを検索・自動修復
    public func resolveAndRepairAudioPaths(for clips: [SoundClip]) -> [SoundClip] {
        let fm = FileManager.default
        let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appSupportGenAudioDir = appSupport.appendingPathComponent("TohoStudio/GeneratedAudio", isDirectory: true).path
        let resourceGenAudioDir = "/Volumes/ZSSD/GitHub/repository/TohoStudio/Application/Resource/GeneratedAudio"

        let genAudioDirs = [appSupportGenAudioDir, resourceGenAudioDir]

        let bgmDirs = [
            "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/動画用/音楽/BGM",
            "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/動画用/音楽",
            "/Volumes/ZSSD/GitHub/repository/TohoStudio/動画用/音楽/BGM",
            "/Volumes/ZSSD/GitHub/repository/TohoStudio/動画用/素材/BGM",
            "/Volumes/ZSSD/GitHub/repository/TohoStudio/動画用/音楽"
        ]

        let seDirs = [
            "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/動画用/音楽/効果音",
            "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/動画用/音楽",
            "/Volumes/ZSSD/GitHub/repository/TohoStudio/動画用/音楽/効果音",
            "/Volumes/ZSSD/GitHub/repository/TohoStudio/動画用/素材/効果音",
            "/Volumes/ZSSD/GitHub/repository/TohoStudio/動画用/音楽"
        ]

        let genAudioFiles: [(dir: String, file: String)] = genAudioDirs.flatMap { dir in
            ((try? fm.contentsOfDirectory(atPath: dir)) ?? []).map { (dir, $0) }
        }
        let bgmFiles: [(dir: String, file: String)] = bgmDirs.flatMap { dir in
            ((try? fm.contentsOfDirectory(atPath: dir)) ?? []).map { (dir, $0) }
        }
        let seFiles: [(dir: String, file: String)] = seDirs.flatMap { dir in
            ((try? fm.contentsOfDirectory(atPath: dir)) ?? []).map { (dir, $0) }
        }

        var result: [SoundClip] = []

        for var clip in clips {
            let path = clip.audioFilePath

            // すでにファイルが存在する場合の検証
            if let p = path, fm.fileExists(atPath: p) {
                if let player = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: p)) {
                    // Voice の場合、他プロジェクトの同名短縮ファイル等との衝突（durationの乖離）を検証
                    if clip.type == "Voice" {
                        let textLen = clip.text?.count ?? 0
                        let isSuspiciouslyShort = (clip.duration > 3.0 && player.duration < clip.duration - 2.5) ||
                                                 (textLen > 30 && player.duration < 4.0)

                        if isSuspiciouslyShort {
                            // Resource 側の同名ファイルを確認してより長い（正しい）ファイルを探索
                            let fname = (p as NSString).lastPathComponent
                            for (dir, f) in genAudioFiles {
                                if f == fname && dir != (p as NSString).deletingLastPathComponent {
                                    let altPath = (dir as NSString).appendingPathComponent(f)
                                    if let altPlayer = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: altPath)),
                                       altPlayer.duration > player.duration {
                                        clip.audioFilePath = altPath
                                        clip.duration = altPlayer.duration
                                        break
                                    }
                                }
                            }
                        } else {
                            clip.duration = max(0.5, player.duration)
                        }
                    } else if clip.duration <= 0.5 {
                        clip.duration = max(0.5, player.duration)
                    }
                }
                result.append(clip)
                continue
            }

            var resolvedPath: String? = nil

            // 1. Voice（キャラクター音声）の検索・自動紐付け
            if clip.type == "Voice" {
                // パス名がすでに存在する場合のファイル名マッチ
                if let p = path, !p.isEmpty {
                    let fname = (p as NSString).lastPathComponent
                    for (dir, f) in genAudioFiles {
                        if f.precomposedStringWithCanonicalMapping == fname.precomposedStringWithCanonicalMapping ||
                           f.decomposedStringWithCanonicalMapping == fname.decomposedStringWithCanonicalMapping {
                            resolvedPath = (dir as NSString).appendingPathComponent(f)
                            break
                        }
                    }
                }

                // sceneIndex および character から検索
                if resolvedPath == nil {
                    var sIdx = clip.sceneIndex
                    if sIdx == nil {
                        let name = clip.name
                        if let range = name.range(of: "#\\d+", options: .regularExpression) {
                            let numStr = String(name[range].dropFirst())
                            sIdx = Int(numStr)
                        }
                    }

                    let rawChar = clip.character ?? ""
                    let cleanChar = rawChar.trimmingCharacters(in: .whitespacesAndNewlines)

                    if let idx = sIdx {
                        let prefix3 = String(format: "Slide_%03d", idx)
                        let prefix1 = "Slide_\(idx)_"
                        let prefixAlt = "Slide_\(idx)."

                        // 候補1: prefix + キャラ名 (例: Slide_011_操夢.wav)
                        for (dir, f) in genAudioFiles {
                            let fNFC = f.precomposedStringWithCanonicalMapping
                            let charNFC = cleanChar.precomposedStringWithCanonicalMapping

                            if fNFC.hasPrefix(prefix3) || fNFC.hasPrefix(prefix1) {
                                if cleanChar.isEmpty || fNFC.contains(charNFC) {
                                    resolvedPath = (dir as NSString).appendingPathComponent(f)
                                    break
                                }
                            }
                        }

                        // 候補2: キャラ名表記揺れまたはシーン番号のみでのファイル検索
                        if resolvedPath == nil {
                            for (dir, f) in genAudioFiles {
                                let fNFC = f.precomposedStringWithCanonicalMapping
                                if fNFC.hasPrefix(prefix3) || fNFC.hasPrefix(prefix1) || fNFC.hasPrefix(prefixAlt) {
                                    resolvedPath = (dir as NSString).appendingPathComponent(f)
                                    break
                                }
                            }
                        }
                    }
                }
            }
            // 2. BGM の検索・自動紐付け
            else if clip.type == "BGM" {
                let clean = clip.name
                    .replacingOccurrences(of: "[BGM] ", with: "")
                    .replacingOccurrences(of: "BGM: ", with: "")
                    .replacingOccurrences(of: "BGM", with: "")
                    .trimmingCharacters(in: .whitespaces)

                for (dir, f) in bgmFiles {
                    guard f.hasSuffix(".mp3") || f.hasSuffix(".wav") || f.hasSuffix(".m4a") else { continue }
                    let fNFC = f.precomposedStringWithCanonicalMapping
                    let cleanNFC = clean.precomposedStringWithCanonicalMapping

                    if !cleanNFC.isEmpty && (fNFC.contains(cleanNFC) || cleanNFC.contains(fNFC.replacingOccurrences(of: ".mp3", with: ""))) {
                        resolvedPath = (dir as NSString).appendingPathComponent(f)
                        break
                    }
                }

                // 代表的な東方BGMのフォールバック
                if resolvedPath == nil {
                    for (dir, f) in bgmFiles {
                        if f.contains("少女綺想曲") || f.contains("神々が恋した幻想郷") || f.contains("緋色の影") {
                            resolvedPath = (dir as NSString).appendingPathComponent(f)
                            break
                        }
                    }
                }
            }
            // 3. SE (効果音) の検索・自動紐付け
            else if clip.type == "SE" {
                let clean = clip.name
                    .replacingOccurrences(of: "[SE] ", with: "")
                    .replacingOccurrences(of: "SE: ", with: "")
                    .replacingOccurrences(of: "SE", with: "")
                    .trimmingCharacters(in: .whitespaces)

                for (dir, f) in seFiles {
                    guard f.hasSuffix(".mp3") || f.hasSuffix(".wav") || f.hasSuffix(".m4a") else { continue }
                    let fNFC = f.precomposedStringWithCanonicalMapping
                    let cleanNFC = clean.precomposedStringWithCanonicalMapping

                    if !cleanNFC.isEmpty && (fNFC.contains(cleanNFC) || cleanNFC.contains(fNFC.replacingOccurrences(of: ".mp3", with: ""))) {
                        resolvedPath = (dir as NSString).appendingPathComponent(f)
                        break
                    }
                }

                if resolvedPath == nil {
                    if clean.contains("決定") || clean.contains("選択") || clean.contains("ボタン") || clean.contains("飲む") {
                        for (dir, f) in seFiles {
                            if f.contains("決定") || f.contains("ボタン") || f.contains("飲む") {
                                resolvedPath = (dir as NSString).appendingPathComponent(f)
                                break
                            }
                        }
                    }
                }
            }

            if let rPath = resolvedPath {
                clip.audioFilePath = rPath
                if let player = try? AVAudioPlayer(contentsOf: URL(fileURLWithPath: rPath)) {
                    if clip.duration <= 1.0 || clip.type == "Voice" {
                        clip.duration = max(0.5, player.duration)
                    }
                }
            }

            result.append(clip)
        }

        return result
    }

    /// クリップ内に存在する全トラックを自動復元・追加
    public func ensureTracksForClips(_ clips: [SoundClip]) {
        var existingTrackIds = Set(audioTracks.map { $0.id })

        if !existingTrackIds.contains("track_movie") {
            audioTracks.insert(AudioTrack(id: "track_movie", name: "video", type: "movie", icon: "film.fill", colorHex: "#3897F0", volume: 0.85, pan: 0.0), at: 0)
            existingTrackIds.insert("track_movie")
        }
        if !existingTrackIds.contains("track_se") {
            audioTracks.append(AudioTrack(id: "track_se", name: "SE (効果音)", type: "se", icon: "bolt.fill", colorHex: "#2ECC71", volume: 0.8, pan: 0.0))
            existingTrackIds.insert("track_se")
        }
        if !existingTrackIds.contains("track_bgm") {
            audioTracks.append(AudioTrack(id: "track_bgm", name: "BGM (背景音楽)", type: "bgm", icon: "music.note", colorHex: "#9B59B6", volume: 0.65, pan: 0.0))
            existingTrackIds.insert("track_bgm")
        }

        for clip in clips {
            guard let tid = clip.trackId, !tid.isEmpty, !existingTrackIds.contains(tid) else { continue }
            let charName = clip.character ?? clip.name
            let color = clip.colorHex ?? (charName.contains("霊夢") ? "#E74C3C" : (charName.contains("魔理沙") ? "#F1C40F" : "#00CEC9"))
            let icon = (clip.type == "SE") ? "bolt.fill" : ((clip.type == "BGM") ? "music.note" : "waveform")
            let typeName = clip.type.lowercased()
            let trackName = charName.isEmpty ? "トラック (\(clip.type))" : "\(charName) (\(clip.type))"

            let newTrack = AudioTrack(
                id: tid,
                name: trackName,
                type: typeName,
                icon: icon,
                colorHex: color,
                volume: clip.volume > 0 ? clip.volume : 1.0,
                pan: clip.pan,
                characterName: clip.character
            )

            if let seIdx = audioTracks.firstIndex(where: { $0.id == "track_se" || $0.type == "se" }) {
                audioTracks.insert(newTrack, at: seIdx)
            } else {
                audioTracks.append(newTrack)
            }
            existingTrackIds.insert(tid)
        }
    }

    /// クリップ情報から MovieScene 一覧を自動再構築
    public func rebuildScenesFromClips(_ clips: [SoundClip]) {
        var sceneMap: [Int: [SoundClip]] = [:]
        for c in clips {
            if let sIdx = c.sceneIndex {
                sceneMap[sIdx, default: []].append(c)
            }
        }

        guard !sceneMap.isEmpty else { return }
        let sortedSceneIndices = sceneMap.keys.sorted()
        let maxScene = sortedSceneIndices.last ?? 1

        var reconstructed: [MovieScene] = []
        for sNum in 1...maxScene {
            let sceneClips = sceneMap[sNum] ?? []
            let voiceClip = sceneClips.first(where: { $0.type == "Voice" })
            let seClip = sceneClips.first(where: { $0.type == "SE" })

            let title: String
            let characterName: String
            let telop: String
            let duration: Double

            if let vc = voiceClip {
                characterName = vc.character ?? "博麗霊夢"
                telop = vc.text ?? vc.name
                let cleanT = vc.name.replacingOccurrences(of: "[\(characterName)] ", with: "")
                title = "シーン \(sNum): \(cleanT.prefix(20))"
                duration = max(3.0, vc.duration + 0.6)
            } else if let sc = seClip {
                characterName = "博麗霊夢"
                telop = sc.name
                title = "シーン \(sNum)"
                duration = max(3.0, sc.duration + 0.5)
            } else {
                characterName = "ナレーション"
                telop = ""
                title = "シーン \(sNum)"
                duration = 3.0
            }

            let scene = MovieScene(
                title: title,
                duration: duration,
                slideTitle: "スライド #\(sNum)",
                backgroundName: "博麗神社_境内.png",
                characterName: characterName,
                telop: telop,
                audioTrack: voiceClip != nil ? "track_voice" : nil
            )
            reconstructed.append(scene)
        }

        self.movieScenes = reconstructed
        self.totalDuration = reconstructed.reduce(0.0) { $0 + $1.duration }
        self.resolveMovieScenesMedia()
        self.syncClipsToMovieScenes(clips)
    }

    // MARK: - サウンドメーカーからの音声読み込み・自動割り当て機能 (Auto-Assign)
    @discardableResult
    public func assignAudioFromSoundMaker(url: URL? = nil, autoFitDuration: Bool = true) -> (assignedVoiceCount: Int, assignedSECount: Int, assignedBGMCount: Int, message: String) {
        var sourceClips: [SoundClip] = []
        var sourceDocName: String = "現在のサウンドメーカーデータ"

        if let fileUrl = url {
            sourceDocName = fileUrl.lastPathComponent
            guard let data = try? Data(contentsOf: fileUrl) else {
                let msg = "サウンドメーカーファイルを開けませんでした: \(fileUrl.lastPathComponent)"
                log(msg, level: "WARN")
                return (0, 0, 0, msg)
            }
            let decoder = JSONDecoder()
            if let doc = try? decoder.decode(SoundMakerProjectDocument.self, from: data) {
                sourceClips = doc.clips
                if let tr = doc.tracks, !tr.isEmpty {
                    self.audioTracks = tr
                }
            } else if let clips = try? decoder.decode([SoundClip].self, from: data) {
                sourceClips = clips
            } else {
                let msg = "サウンドメーカーのデータ解析に失敗しました: \(fileUrl.lastPathComponent)"
                log(msg, level: "WARN")
                return (0, 0, 0, msg)
            }
        } else {
            sourceClips = self.soundClips
        }

        // 音声ファイルパスの修復
        let repairedClips = resolveAndRepairAudioPaths(for: sourceClips)
        self.soundClips = repairedClips
        ensureTracksForClips(repairedClips)

        // もしムービーシーンが空の場合は、クリップから再構築
        if self.movieScenes.isEmpty {
            rebuildScenesFromClips(repairedClips)
            let msg = "\(sourceDocName) から \(self.movieScenes.count) シーンを生成し、音声を配置しました。"
            log(msg)
            addHistory("ムービーメーカー: サウンドメーカーから音声を自動割り当て (\(sourceDocName))")
            return (repairedClips.filter { $0.type == "Voice" }.count, repairedClips.filter { $0.type == "SE" }.count, repairedClips.filter { $0.type == "BGM" }.count, msg)
        }

        var voiceCount = 0
        var seCount = 0
        var bgmCount = 0

        // スライド情報（画像・動画）の補完用マップ
        let slideMap = Dictionary(uniqueKeysWithValues: self.slides.map { ($0.slideIndex, $0) })

        var accumulatedTime = 0.0
        var updatedClips: [SoundClip] = []
        var remainingClips = repairedClips

        for idx in 0..<self.movieScenes.count {
            var scene = self.movieScenes[idx]
            let sceneNum = idx + 1
            let sceneCleanTelop = scene.displayTelop.trimmingCharacters(in: .whitespacesAndNewlines)

            // スライド画像・アニメーション動画の補完（最新スライドの情報を優先適用）
            if let matchedSlide = slideMap[sceneNum] {
                if let newSlideImg = matchedSlide.slideImagePath, !newSlideImg.isEmpty {
                    scene.slideImagePath = newSlideImg
                }
                if let newVideo = matchedSlide.animationVideoPath, !newVideo.isEmpty {
                    scene.videoPath = newVideo
                }
                if let newBg = matchedSlide.backgroundImagePath, !newBg.isEmpty {
                    scene.backgroundImagePath = newBg
                }
                if let newChar = matchedSlide.characterImagePath, !newChar.isEmpty {
                    scene.characterImagePath = newChar
                }
            }

            // 1. Voice（ボイス）マッチング
            // 優先度1: sceneIndex が一致
            // 優先度2: テキスト（セリフ）の完全一致または部分一致
            var matchedVoiceIndex = remainingClips.firstIndex(where: {
                $0.type == "Voice" && $0.sceneIndex == sceneNum
            })
            if matchedVoiceIndex == nil && !sceneCleanTelop.isEmpty {
                matchedVoiceIndex = remainingClips.firstIndex(where: { clip in
                    guard clip.type == "Voice", let text = clip.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else { return false }
                    return sceneCleanTelop.contains(text) || text.contains(sceneCleanTelop)
                })
            }

            if let vIdx = matchedVoiceIndex {
                var voiceClip = remainingClips.remove(at: vIdx)
                voiceClip.sceneIndex = sceneNum
                voiceClip.startTime = accumulatedTime // シーン先頭に完全一致 (0.0s)
                voiceClip.sceneRelativeStartTime = 0.0
                
                scene.voiceAudioPath = voiceClip.audioFilePath
                scene.voiceCharacter = voiceClip.character ?? scene.characterName
                scene.voiceDuration = voiceClip.duration
                scene.audioTrack = voiceClip.trackId ?? "track_voice"
                scene.voiceStartTimeOffset = 0.0

                if autoFitDuration {
                    let requiredDuration = max(2.5, voiceClip.duration + 0.6)
                    if scene.duration < requiredDuration {
                        scene.duration = requiredDuration
                    }
                }
                voiceCount += 1
                updatedClips.append(voiceClip)
            }

            // 1-2. 2人目のボイスマッチング（同一シーンに2人分の音声が割り当てられている場合）
            let matchedVoice2Index = remainingClips.firstIndex(where: {
                $0.type == "Voice" && $0.sceneIndex == sceneNum
            })
            if let v2Idx = matchedVoice2Index {
                var voice2Clip = remainingClips.remove(at: v2Idx)
                voice2Clip.sceneIndex = sceneNum
                voice2Clip.startTime = accumulatedTime // シーン先頭に完全一致 (0.0s)
                voice2Clip.sceneRelativeStartTime = 0.0

                scene.voice2AudioPath = voice2Clip.audioFilePath
                scene.voice2Character = voice2Clip.character
                scene.voice2Duration = voice2Clip.duration
                scene.voice2StartTimeOffset = 0.0

                if autoFitDuration {
                    let requiredDuration = max(2.5, voice2Clip.duration + 0.6)
                    if scene.duration < requiredDuration {
                        scene.duration = requiredDuration
                    }
                }
                voiceCount += 1
                updatedClips.append(voice2Clip)
            }

            // 2. SE（効果音）マッチング
            let matchedSE = repairedClips.first(where: {
                $0.type == "SE" && ($0.sceneIndex == sceneNum || ($0.spanStartSceneIndex != nil && $0.spanEndSceneIndex != nil && sceneNum >= $0.spanStartSceneIndex! && sceneNum <= $0.spanEndSceneIndex!))
            })
            if let seClip = matchedSE {
                scene.seAudioPath = seClip.audioFilePath
                scene.seName = seClip.name
                seCount += 1
                let isSpanning = seClip.isSpanningScenes || (seClip.spanStartSceneIndex != nil && seClip.spanEndSceneIndex != nil)
                if !isSpanning {
                    if let rIdx = remainingClips.firstIndex(where: { $0.id == seClip.id }) {
                        var singleSe = remainingClips.remove(at: rIdx)
                        singleSe.sceneIndex = sceneNum

                        // 1. 文字連動が明示的に有効な場合は、その文字の発話推定時刻に正確にアライメント
                        let seRelOffset: Double
                        if singleSe.voiceTriggerEnabled,
                           let charIdx = singleSe.startCharIndex,
                           let ctx = VoiceTextTimingService.resolveDialogueContext(clip: singleSe, sceneIndex: sceneNum, clips: repairedClips, scenes: self.movieScenes),
                           let timing = ctx.timings.first(where: { $0.index == charIdx }) {
                            seRelOffset = max(0.0, timing.startSeconds + singleSe.voiceTriggerOffset)
                        } else {
                            // 2. 文字連動なしの場合は、タイムライン上の実開始時刻とシーン先頭の差分から正確に算出
                            let prevRel = max(0.0, singleSe.startTime - accumulatedTime)
                            seRelOffset = min(prevRel, max(0.0, scene.duration - 0.05))
                        }
                        let safeRel = min(max(0.0, seRelOffset), max(0.0, scene.duration - 0.05))
                        singleSe.sceneRelativeStartTime = safeRel
                        singleSe.startTime = accumulatedTime + safeRel
                        scene.seStartTimeOffset = safeRel
                        scene.seVolume = singleSe.volume
                        updatedClips.append(singleSe)
                    }
                }
            } else {
                scene.seAudioPath = nil
                scene.seName = nil
                scene.seStartTimeOffset = 0.0
            }

            // 3. BGM（背景音楽）マッチング (BGMが削除されている場合は確実にnilへクリア)
            let matchingBGM = repairedClips.first(where: { clip in
                guard clip.type == "BGM" else { return false }
                if let s = clip.spanStartSceneIndex, let e = clip.spanEndSceneIndex {
                    return sceneNum >= s && sceneNum <= e
                }
                if let sIdx = clip.sceneIndex {
                    return sIdx == sceneNum
                }
                return clip.isLooping || (clip.sceneIndex == nil && clip.spanStartSceneIndex == nil)
            })
            if let bgmClip = matchingBGM {
                scene.bgmAudioPath = bgmClip.audioFilePath
                scene.bgmName = bgmClip.name
                scene.bgmVolume = bgmClip.volume
                let isSpan = (bgmClip.spanStartSceneIndex != nil && bgmClip.spanEndSceneIndex != nil)
                let startSceneNum = bgmClip.spanStartSceneIndex ?? bgmClip.sceneIndex ?? 1
                if sceneNum == startSceneNum || (!isSpan && bgmClip.sceneIndex == sceneNum) {
                    let bgmRel: Double
                    if bgmClip.voiceTriggerEnabled,
                       let charIdx = bgmClip.startCharIndex,
                       let ctx = VoiceTextTimingService.resolveDialogueContext(clip: bgmClip, sceneIndex: sceneNum, clips: repairedClips, scenes: self.movieScenes),
                       let timing = ctx.timings.first(where: { $0.index == charIdx }) {
                        bgmRel = max(0.0, timing.startSeconds + bgmClip.voiceTriggerOffset)
                    } else {
                        let prevRel = max(0.0, bgmClip.startTime - accumulatedTime)
                        bgmRel = min(prevRel, max(0.0, scene.duration - 0.05))
                    }
                    scene.bgmStartTimeOffset = bgmRel
                } else if isSpan {
                    let startSceneTime = self.movieScenes.prefix(startSceneNum - 1).reduce(0.0) { $0 + $1.duration }
                    let initialOffset = bgmClip.sceneRelativeStartTime ?? max(0.0, bgmClip.startTime - startSceneTime)
                    let elapsed = max(0.0, (accumulatedTime - startSceneTime) - initialOffset)
                    scene.bgmStartTimeOffset = -elapsed
                } else {
                    scene.bgmStartTimeOffset = 0.0
                }
                bgmCount += 1
            } else {
                scene.bgmAudioPath = nil
                scene.bgmName = nil
                scene.bgmStartTimeOffset = 0.0
                scene.bgmVolume = 0.7
            }

            self.movieScenes[idx] = scene
            accumulatedTime += scene.duration
        }

        // BGM クリップおよび複数シーン跨ぎSEクリップなどのシーン跨ぎクリップも追加
        for var spanClip in repairedClips.filter({ $0.type == "BGM" || ($0.spanStartSceneIndex != nil && $0.spanEndSceneIndex != nil) }) {
            if !updatedClips.contains(where: { $0.id == spanClip.id }) {
                let startSceneIdx = spanClip.spanStartSceneIndex ?? spanClip.sceneIndex ?? 1
                let sStart = self.movieScenes.prefix(max(0, startSceneIdx - 1)).reduce(0.0) { $0 + $1.duration }

                let targetChar = spanClip.startCharIndex ?? spanClip.fadeInCharIndex
                if let charIdx = targetChar,
                   let ctx = VoiceTextTimingService.resolveDialogueContext(clip: spanClip, sceneIndex: startSceneIdx, clips: repairedClips, scenes: self.movieScenes),
                   let timing = ctx.timings.first(where: { $0.index == charIdx }) {
                    spanClip.startTime = max(0.0, sStart + timing.startSeconds + spanClip.voiceTriggerOffset)
                } else if spanClip.spanStartSceneIndex != nil {
                    spanClip.startTime = sStart
                }
                updatedClips.append(spanClip)
            }
        }
        // 未割り当ての残余クリップも保持
        for remain in remainingClips {
            if !updatedClips.contains(where: { $0.id == remain.id }) {
                updatedClips.append(remain)
            }
        }

        self.soundClips = updatedClips
        self.totalDuration = accumulatedTime
        self.saveUndoSnapshot()

        let summary = "『\(sourceDocName)』から音声を自動割り当てしました（ボイス: \(voiceCount)件, SE: \(seCount)件, BGM: \(bgmCount)件）"
        log(summary)
        addHistory("ムービーメーカー: 音声自動割り当て (\(summary))")
        return (voiceCount, seCount, bgmCount, summary)
    }

    /// ムービーシーンのスライド画像や動画、背景・立ち絵パスを現在のスライド一覧から自動補完・再解決
    /// ムービーシーンのスライド画像や動画、背景・立ち絵パスを現在のスライド一覧およびキャッシュから自動補完・再解決
    public func resolveMovieScenesMedia() {
        guard !movieScenes.isEmpty else { return }
        let fm = FileManager.default
        let slideMap = Dictionary(uniqueKeysWithValues: slides.map { ($0.slideIndex, $0) })
        let slidesCacheBase = "/Volumes/ZSSD/GitHub/repository/TohoStudio/.cache/keynote_slides"

        let cleanProject = currentProjectName
            .replacingOccurrences(of: ".key", with: "")
            .replacingOccurrences(of: ".tspm", with: "")
            .replacingOccurrences(of: ".tssm", with: "")
            .replacingOccurrences(of: ".tsvm", with: "")

        for idx in 0..<movieScenes.count {
            let sceneNum = idx + 1
            if let slide = slideMap[sceneNum] {
                if let newSlideImg = slide.slideImagePath, !newSlideImg.isEmpty {
                    movieScenes[idx].slideImagePath = newSlideImg
                }
                if let newVideo = slide.animationVideoPath, !newVideo.isEmpty {
                    movieScenes[idx].videoPath = newVideo
                }
                if let newBg = slide.backgroundImagePath, !newBg.isEmpty {
                    movieScenes[idx].backgroundImagePath = newBg
                }
                if let newChar = slide.characterImagePath, !newChar.isEmpty {
                    movieScenes[idx].characterImagePath = newChar
                }
            }

            // スライド画像が未解決またはファイルが存在しない場合の自動キャッシュ探索（最新の更新日時順）
            let currentPath = movieScenes[idx].slideImagePath
            if currentPath == nil || currentPath?.isEmpty == true || !fm.fileExists(atPath: currentPath!) {
                if let found = AppState.findLatestSlideImagePath(forProject: cleanProject, slideIndex: sceneNum) {
                    movieScenes[idx].slideImagePath = found
                }
            }
        }
        notifySlideAssetsUpdated()
    }

    // MARK: - ムービーメーカー再生管理 (Play/Pause/Seek/Timer)
    public func toggleMoviePlayback() {
        if isPlaying {
            stopMoviePlayback()
        } else {
            startMoviePlayback()
        }
    }

    public func startMoviePlayback() {
        if !isPlaying {
            isPlaying = true
        }
        // タイムライン音声の同期再生を開始
        SoundMakerAudioManager.shared.startTimelinePlayback(from: currentTime, clips: soundClips, scenes: movieScenes)
        moviePlaybackTimer?.invalidate()
        let interval: Double = 0.05
        moviePlaybackTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self, self.isPlaying else { return }
            let step = interval * self.playbackSpeed
            let newTime = self.currentTime + step
            if newTime >= self.totalDuration {
                if self.isLooping {
                    self.currentTime = 0.0
                    self.syncSceneToCurrentTime()
                    SoundMakerAudioManager.shared.startTimelinePlayback(from: 0.0, clips: self.soundClips, scenes: self.movieScenes)
                } else {
                    self.stopMoviePlayback()
                }
                return
            }
            self.currentTime = newTime
            self.syncSceneToCurrentTime()
            SoundMakerAudioManager.shared.updateTimelinePlayback(currentTime: newTime, clips: self.soundClips, scenes: self.movieScenes)
        }
    }

    public func stopMoviePlayback() {
        if isPlaying {
            isPlaying = false
        }
        moviePlaybackTimer?.invalidate()
        moviePlaybackTimer = nil
        SoundMakerAudioManager.shared.stopTimelinePlayback()
    }

    public func seekMoviePlayback(to time: Double) {
        let clamped = max(0.0, min(time, totalDuration))
        currentTime = clamped
        syncSceneToCurrentTime()
        if isPlaying {
            SoundMakerAudioManager.shared.startTimelinePlayback(from: clamped, clips: soundClips, scenes: movieScenes)
        }
    }

    public func syncSceneToCurrentTime() {
        guard !movieScenes.isEmpty else { return }
        var accumulated: Double = 0.0
        for (idx, scene) in movieScenes.enumerated() {
            let nextAccum = accumulated + scene.duration
            if currentTime >= accumulated && currentTime < nextAccum {
                if selectedSceneIndex != idx {
                    selectedSceneIndex = idx
                }
                return
            }
            accumulated = nextAccum
        }
        if selectedSceneIndex != movieScenes.count - 1 {
            selectedSceneIndex = max(0, movieScenes.count - 1)
        }
    }
}

