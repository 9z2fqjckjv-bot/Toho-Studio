import SwiftUI
import AppKit
import AVFoundation
import UniformTypeIdentifiers

// MARK: - ムービーメーカー (仕様書 P.152 - P.165)
// ベースソフト: GoogleVids
// 拡張子: .tsvm (読込/書出: mp4, ymmp, gvid)
// アプリ拡張: FinalCutPro, PremierPro
struct MovieMakerView: View {
    @EnvironmentObject var state: StudioState
    
    enum ScreenMode {
        case home           // P.154 ホーム画面
        case loading        // P.155 読込画面
        case editor         // P.156-P.164 編集画面
        case export         // P.165 書き出し画面
    }
    
    @State private var screenMode: ScreenMode = .home
    @State private var editorLayout: Int = 2 // デフォルト レイアウト2 (素材一覧・プレビュー・タイムライン)
    @State private var loadingMessage: String = "ファイルを読み込み中…"
    @State private var loadingProgress: Double = 0.45
    @State private var currentFileName: String = "東方操夢録_第30話.tsvm"
    @State private var currentFileURL: URL? = nil
    
    // シーン構造体（スライド画像・テロップ字幕・8段階レイヤー）
    struct MovieSceneData: Identifiable {
        let id: UUID
        var title: String
        var duration: Double
        var imagePath: String?
        var scriptText: String?
        var speakerCharacter: String?
        var animationMeta: String?
        var animationDuration: Double?
        var audioPath: String?
        var audioDuration: Double?
        var audioFileName: String?
        
        // 8段階順序レイヤー対応
        var backgroundImagePath: String?       // 1. 背景画像
        var backgroundAnimation: String?       // 2. 背景画像のアニメーション
        var characterImagePath: String?        // 3. キャラクター画像 ("/Volumes/ZSSD/動画用")
        var characterAnimation: String?        // 4. キャラクター画像のアニメーション
        var objectsData: [SlideObjectData]?    // 5. オブジェクト（テキストや図形など）
        var objectAnimation: String?           // 6. オブジェクトのアニメーション
        var telopText: String?                 // 7. テロップとノートにあるテキスト
        var slideTransitionEffect: String?     // 8. スライドトランジション（効果名）
        var slideTransitionDuration: Double?   // 8. スライドトランジション（秒数）
        
        init(id: UUID = UUID(),
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
        
        init(item: MovieSceneItemData) {
            self.id = item.id
            self.title = item.title
            self.duration = item.duration
            self.imagePath = item.imagePath
            self.scriptText = item.scriptText
            self.speakerCharacter = item.speakerCharacter
            // animationMeta サニタイズ: キャラクター専用アニメーション文字列がスライド全体に誤適用されないよう除去
            // characterAnimation はcharacterAnimationプロパティに格納されており、animationMetaには不要
            let rawMeta = item.animationMeta
            let charOnlyPrefixes = ["キャラクター呼吸", "キャラクター", "バウンス (", "bounce (", "アニメーション ("]
            let isCharOnlyMeta = rawMeta.map { m in
                charOnlyPrefixes.contains(where: { m.hasPrefix($0) }) ||
                m == "キャラクター呼吸・動的バウンス"
            } ?? false
            self.animationMeta = isCharOnlyMeta ? nil : rawMeta
            self.animationDuration = item.animationDuration ?? (item.animationMeta.flatMap { FileFormatParser.extractDurationFromMeta($0) })
            self.audioPath = item.audioPath
            self.audioDuration = item.audioDuration
            self.audioFileName = item.audioFileName
            self.backgroundImagePath = item.backgroundImagePath
            self.backgroundAnimation = item.backgroundAnimation
            self.characterImagePath = item.characterImagePath
            self.characterAnimation = item.characterAnimation
            self.objectsData = item.objectsData
            self.objectAnimation = item.objectAnimation
            self.telopText = item.telopText
            self.slideTransitionEffect = item.slideTransitionEffect
            self.slideTransitionDuration = item.slideTransitionDuration
        }
        
        func toItemData() -> MovieSceneItemData {
            MovieSceneItemData(
                id: id,
                title: title,
                duration: duration,
                imagePath: imagePath,
                scriptText: scriptText,
                speakerCharacter: speakerCharacter,
                animationMeta: animationMeta,
                animationDuration: animationDuration,
                audioPath: audioPath,
                audioDuration: audioDuration,
                audioFileName: audioFileName,
                backgroundImagePath: backgroundImagePath,
                backgroundAnimation: backgroundAnimation,
                characterImagePath: characterImagePath,
                characterAnimation: characterAnimation,
                objectsData: objectsData,
                objectAnimation: objectAnimation,
                telopText: telopText,
                slideTransitionEffect: slideTransitionEffect,
                slideTransitionDuration: slideTransitionDuration
            )
        }
    }
    
    // 分離された音声トラックデータ構造体
    struct MovieAudioData: Identifiable {
        let id: UUID
        var name: String
        var audioPath: String
        var audioFileName: String
        var duration: Double
        var startTime: Double
        var targetSceneIndex: Int?
        var targetSceneId: UUID?
        var volume: Double
        /// 再生速度（0.25 ... 4.0）。1.0 が等速。
        var playbackRate: Double
        var speakerCharacter: String?
        var isMuted: Bool
        
        /// トラック種類: "voice"（セリフ音声）, "bgm"（背景音楽）, "se"（効果音）
        var trackType: String
        /// 逆再生フラグ
        var isReversed: Bool
        /// ループ再生フラグ
        var loops: Bool
        /// 開始シーンインデックス（0始まり）
        var startSceneIndex: Int?
        /// 終了シーンインデックス（0始まり）
        var endSceneIndex: Int?
        
        var isBGM: Bool { trackType.lowercased() == "bgm" }
        var isSE: Bool { trackType.lowercased() == "se" }
        var isVoice: Bool { trackType.lowercased() == "voice" || (!isBGM && !isSE) }
        
        /// 速度反映後の実再生尺
        var effectivePlaybackDuration: Double {
            let rate = max(0.25, min(4.0, playbackRate == 0 ? 1.0 : playbackRate))
            return duration / rate
        }
        
        init(id: UUID = UUID(),
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
             endSceneIndex: Int? = nil) {
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
        
        init(item: MovieAudioItemData) {
            self.id = item.id
            self.name = item.name
            self.audioPath = item.audioPath
            self.audioFileName = item.audioFileName
            self.duration = item.duration
            self.startTime = item.startTime
            self.targetSceneIndex = item.targetSceneIndex
            self.targetSceneId = item.targetSceneId
            self.volume = item.volume
            self.playbackRate = item.playbackRate
            self.speakerCharacter = item.speakerCharacter
            self.isMuted = item.isMuted
            self.trackType = item.trackType
            self.isReversed = item.isReversed
            self.loops = item.loops
            self.startSceneIndex = item.startSceneIndex ?? item.targetSceneIndex
            self.endSceneIndex = item.endSceneIndex ?? item.startSceneIndex ?? item.targetSceneIndex
        }
        
        func toItemData() -> MovieAudioItemData {
            MovieAudioItemData(
                id: id,
                name: name,
                audioPath: audioPath,
                audioFileName: audioFileName,
                duration: duration,
                startTime: startTime,
                targetSceneIndex: targetSceneIndex,
                targetSceneId: targetSceneId,
                volume: volume,
                playbackRate: playbackRate,
                speakerCharacter: speakerCharacter,
                isMuted: isMuted,
                trackType: trackType,
                isReversed: isReversed,
                loops: loops,
                startSceneIndex: startSceneIndex,
                endSceneIndex: endSceneIndex
            )
        }
    }
    
    // 分離管理タブ切り替え
    enum ManagementTab: String, CaseIterable, Identifiable {
        case visualScenes = "既存シーン (画像・テロップ)"
        case audioFiles = "音声ファイル"
        case timelineTracks = "二段トラック"
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .visualScenes: return "photo.on.rectangle.angled"
            case .audioFiles: return "waveform"
            case .timelineTracks: return "slider.horizontal.below.rectangle"
            }
        }
    }
    
    // タイムライン・再生
    @State private var isPlaying: Bool = false
    @State private var currentTime: Double = 14.5
    @State private var duration: Double = 120.0
    @State private var scenes: [String] = ["第1幕: 神社のお茶会", "第2幕: 魔理沙の急報", "第3幕: 異変の幕開け", "第4幕: エンディング"]
    @State private var movieScenes: [MovieSceneData] = []
    @State private var audioItems: [MovieAudioData] = []
    @State private var selectedSceneIndex: Int = 0
    @State private var selectedAudioIndex: Int = 0
    @State private var managementTab: ManagementTab = .visualScenes
    
    // 音声再生（セリフ用単体プレイヤー ＋ シーン別BGM/効果音プレイヤー群）
    @State private var audioPlayer: AVAudioPlayer? = nil
    @State private var bgmSePlayers: [UUID: AVAudioPlayer] = [:]
    @State private var playingAudioSceneIndex: Int? = nil
    @State private var playingAudioItemIndex: Int? = nil
    @State private var lastPlayedSceneIndexDuringPlayback: Int? = nil
    @State private var singleScenePreviewIndex: Int? = nil
    @State private var singleScenePreviewEndTime: Double? = nil
    private let playbackTimer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
    /// TimelineView / Date 駆動用: 再生開始壁時計と、その時点のメディア時刻
    @State private var playbackAnchorDate: Date? = nil
    @State private var playbackAnchorMediaTime: Double = 0
    
    // 音声フィルタ・連携情報
    @State private var audioFilterCategory: String = "すべて"
    @State private var associatedSoundProjectName: String? = nil
    
    // 書き出し用
    @State private var exportDestination: String = "リポジトリ (Projects/Movie)"
    @State private var exportFormat: String = "mp4"
    @State private var exportFileName: String = "東方操夢録_第30話_完成版"
    @State private var exportQuality: String = "1080p 60fps (高画質)"
    @State private var isExporting: Bool = false
    @State private var exportProgress: Double = 0.0
    
    var body: some View {
        VStack(spacing: 0) {
            // 仕様書共通ヘッダーバー (P.154, P.155, P.156等)
            StudioHeaderBar(
                appTitle: "Toho-Studio-VideoMaker",
                mode: {
                    switch screenMode {
                    case .home:
                        return .home(screenTitle: "ホーム画面")
                    case .loading:
                        return .loading(screenTitle: "読込画面")
                    case .editor:
                        return .editor(layoutNumber: editorLayout, editorName: "ムービーメーカー")
                    case .export:
                        return .simple(title: "書き出し画面")
                    }
                }(),
                maxLayouts: 9,
                onLayoutChange: { newLayout in
                    editorLayout = newLayout
                },
                onGuideTapped: {
                    state.showingGuideSheet = true
                },
                onProcessTapped: {
                    state.showingProcessSheet = true
                }
            )
            
            // 画面モード別ビュー切り替え
            switch screenMode {
            case .home:
                homeView
            case .loading:
                loadingView
            case .editor:
                editorMainView
            case .export:
                exportView
            }
        }
        .onReceive(playbackTimer) { _ in
            guard isPlaying && screenMode == .editor else { return }
            // Date アンカーから currentTime を同期（TimelineView が毎フレーム見た目を更新）
            if let anchor = playbackAnchorDate {
                currentTime = playbackAnchorMediaTime + Date().timeIntervalSince(anchor)
            } else {
                currentTime += 0.1
            }
            
            // 個別シーンプレビューの終了判定
            if let endTime = singleScenePreviewEndTime, currentTime >= endTime {
                stopPlaybackClock()
                singleScenePreviewIndex = nil
                singleScenePreviewEndTime = nil
                stopAudio()
                lastPlayedSceneIndexDuringPlayback = nil
                return
            }
            
            if currentTime >= duration {
                currentTime = 0.0
                stopPlaybackClock()
                singleScenePreviewIndex = nil
                singleScenePreviewEndTime = nil
                stopAudio()
                lastPlayedSceneIndexDuringPlayback = nil
                return
            }
            let curIdx = activeSceneIndex
            if curIdx != lastPlayedSceneIndexDuringPlayback {
                lastPlayedSceneIndexDuringPlayback = curIdx
                playSceneAudios(sceneIndex: curIdx)
            }
        }
        .onAppear {
            state.onSaveCurrentEditor = { [self] in
                self.saveProject(asNew: false)
            }
            state.onSaveAsCurrentEditor = { [self] in
                self.saveProject(asNew: true)
            }
            
            // スライド＆シナリオメーカーからの転送データがあれば自動適用
            if let pending = state.pendingExportedSlides, !pending.isEmpty {
                let sourceTitle = state.pendingExportSourceTitle ?? "スライドエクスポート"
                self.applySlidesToMovie(slides: pending, sourceName: sourceTitle)
                self.screenMode = .editor
                state.pendingExportedSlides = nil
                state.pendingExportSourceTitle = nil
            }
        }
        .onChange(of: state.pendingExportedSlides?.count) { _ in
            if let pending = state.pendingExportedSlides, !pending.isEmpty {
                let sourceTitle = state.pendingExportSourceTitle ?? "スライドエクスポート"
                self.applySlidesToMovie(slides: pending, sourceName: sourceTitle)
                self.screenMode = .editor
                state.pendingExportedSlides = nil
                state.pendingExportSourceTitle = nil
            }
        }
        .onDisappear {
            stopAudio()
            state.onSaveCurrentEditor = nil
            state.onSaveAsCurrentEditor = nil
        }
    }
    
    // MARK: - 1. ホーム画面 (仕様書 P.154: 左右広告枠、中央選択肢)
    private var homeView: some View {
        HStack(spacing: 0) {
            // 左側 広告枠 (仕様書 P.154)
            VStack {
                Spacer()
                Text("広 告 枠")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.6))
                    .tracking(6)
                Spacer()
            }
            .frame(width: 140)
            .background(Color.black.opacity(0.85))
            .overlay(Rectangle().stroke(Color.secondary.opacity(0.2), lineWidth: 1))
            
            // 中央操作エリア
            VStack(spacing: 20) {
                Spacer().frame(height: 8)
                
                Text("いずれかを選択")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                    .padding(.top, 8)
                
                VStack(spacing: 12) {
                    homeActionCard(
                        title: "サウンドメーカーから読み込み（.tssm）",
                        desc: "サウンドメーカーの編集ファイル（.tssm）からBGM・効果音・音量・再生速度・逆再生などの全音声を取り込みます。",
                        icon: "waveform.badge.plus"
                    ) {
                        loadTssmFile()
                    }
                    
                    homeActionCard(
                        title: "スライド＆シナリオメーカーから読み込み",
                        desc: "スライド＆シナリオメーカーの編集ファイルを読み込み、動画を作成します。",
                        icon: "doc.richtext"
                    ) {
                        loadSlideScenarioFile()
                    }
                    
                    homeActionCard(
                        title: "YMMV4を直接読み込み",
                        desc: "ゆっくりムービーメーカー（ymmp）の編集ファイルから動画を作成します。",
                        icon: "film.stack"
                    ) {
                        loadYmmpFile()
                    }
                    
                    homeActionCard(
                        title: "空のファイルを作成",
                        desc: "タイムラインに何も入れずに、編集ファイルを１から作成します。",
                        icon: "doc.badge.plus"
                    ) {
                        currentFileName = "新規プロジェクト.tsvm"
                        scenes = ["第1幕: 新規シーン"]
                        duration = 60.0
                        screenMode = .editor
                    }
                    
                    homeActionCard(
                        title: "既存ファイルの読み込み",
                        desc: "既存のファイル（tsvm）を読み込みます。",
                        icon: "folder"
                    ) {
                        loadExistingTsvmFile()
                    }
                    
                    homeActionCard(
                        title: "アプリ拡張を購入",
                        desc: "設定＞有料機能＞アプリ拡張＞ムービーメーカーの項目に飛びます。",
                        icon: "cart"
                    ) {
                        state.primarySelection = .settings
                        state.settingsSelection = .paidFeatures
                    }
                }
                .frame(maxWidth: 580)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
            
            // 右側 広告枠 (仕様書 P.154)
            VStack {
                Spacer()
                Text("広 告 枠")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.6))
                    .tracking(6)
                Spacer()
            }
            .frame(width: 140)
            .background(Color.black.opacity(0.85))
            .overlay(Rectangle().stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        }
    }
    
    // MARK: - 2. 読込画面 (仕様書 P.155: 左右広告枠、読み込み中、Escでキャンセル)
    private var loadingView: some View {
        HStack(spacing: 0) {
            // 左側 広告枠 (仕様書 P.155)
            VStack {
                Spacer()
                Text("広 告 枠")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.6))
                    .tracking(6)
                Spacer()
            }
            .frame(width: 140)
            .background(Color.black.opacity(0.85))
            .overlay(Rectangle().stroke(Color.secondary.opacity(0.2), lineWidth: 1))
            
            // 中央読込エリア
            VStack(spacing: 24) {
                Spacer()
                
                Text("読み込み中…")
                    .font(.system(size: 22, weight: .bold))
                
                Text("（\(loadingMessage)）")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                
                ProgressView(value: loadingProgress)
                    .progressViewStyle(.linear)
                    .frame(width: 360)
                
                Button("Escでキャンセル") {
                    screenMode = .home
                }
                .keyboardShortcut(.escape, modifiers: [])
                .buttonStyle(.bordered)
                .controlSize(.large)
                
                Text("異常検知時（エラー時）には、すぐに内容をポップアップで表示→ホーム画面に移動")
                    .font(.caption2)
                    .foregroundColor(.secondary.opacity(0.7))
                    .padding(.top, 16)
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
            
            // 右側 広告枠 (仕様書 P.155)
            VStack {
                Spacer()
                Text("広 告 枠")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.secondary.opacity(0.6))
                    .tracking(6)
                Spacer()
            }
            .frame(width: 140)
            .background(Color.black.opacity(0.85))
            .overlay(Rectangle().stroke(Color.secondary.opacity(0.2), lineWidth: 1))
        }
    }
    
    // MARK: - 3. 編集画面 (仕様書 P.156 - P.164: レイアウト1〜9)
    private var editorMainView: some View {
        VStack(spacing: 0) {
            // ムービーメーカー用ツールバー (仕様書 P.156)
            HStack(spacing: 10) {
                // ホームへ戻る
                Button(action: { screenMode = .home }) {
                    Label("ホーム", systemImage: "chevron.backward")
                }
                .buttonStyle(.bordered)
                
                // ファイル読込
                Button(action: { openFileInEditor() }) {
                    Label("読込", systemImage: "folder")
                }
                .buttonStyle(.bordered)
                
                // プロジェクト保存ボタン（Projectsフォルダ対応）
                Menu {
                    Button(action: { saveProject(asNew: false) }) {
                        Label("上書き保存 (⌘S)", systemImage: "square.and.arrow.down")
                    }
                    Button(action: { saveProject(asNew: true) }) {
                        Label("名前を付けて保存… (Projectsフォルダ)", systemImage: "square.and.arrow.down.on.square")
                    }
                } label: {
                    Label("保存", systemImage: "square.and.arrow.down")
                } primaryAction: {
                    saveProject(asNew: false)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("s", modifiers: [.command])
                .help("ムービープロジェクトをリポジトリのProjectsフォルダに保存 (⌘S)")
                
                // 作成済み音声フォルダ一括割り当てボタン
                Button(action: { batchAssignAudioFolder() }) {
                    Label("音声フォルダ一括割当", systemImage: "waveform.badge.plus")
                }
                .buttonStyle(.bordered)
                .help("サウンドメーカー等で作成した音声フォルダを選択し、ファイル名から同一スライドへ一括割り当てします")
                
                // スライド＆シナリオ・Keynote読み込みボタン
                Menu {
                    Button(action: { loadSlideScenarioFile() }) {
                        Label("スライド読込 (.tspm / .key)", systemImage: "doc.richtext")
                    }
                    Button(action: { loadKeynoteWithGUI() }) {
                        Label("Keynote (GUIアニメ抽出)", systemImage: "magicmac")
                    }
                } label: {
                    Label("スライド読込", systemImage: "doc.richtext")
                }
                .buttonStyle(.bordered)
                .help("スライド＆シナリオメーカーのプロジェクト（.tspm）またはKeynoteから全シーン・画像・台本を直接取り込みます")
                
                // サウンドメーカー(.tssm)プロジェクト読み込みボタン
                Button(action: { loadTssmFile() }) {
                    Label("サウンド読込 (.tssm)", systemImage: "music.note.list")
                }
                .buttonStyle(.bordered)
                .help("サウンドメーカープロジェクト（.tssm）からBGM・効果音・音量・再生速度・逆再生などの全音声を取り込みます")
                
                Divider().frame(height: 18)
                
                // レイアウト切替セレクター (レイアウト1〜9)
                Picker("レイアウト", selection: $editorLayout) {
                    Text("L1: 拡張スロット(PR/FCP)").tag(1)
                    Text("L2: 素材・プレビュー").tag(2)
                    Text("L3: アプリ内ブラウザ").tag(3)
                    Text("L4: 素材スタジオ").tag(4)
                    Text("L5: スライド＆台本").tag(5)
                    Text("L6: ストア").tag(6)
                    Text("L7: 履歴＆ステータス").tag(7)
                    Text("L8: 有料機能一覧").tag(8)
                    Text("L9: バージョン復元").tag(9)
                }
                .frame(width: 200)
                
                Divider().frame(height: 18)
                
                // 再生コントロール
                Button(action: {
                    if isPlaying {
                        stopPlaybackClock()
                        singleScenePreviewIndex = nil
                        singleScenePreviewEndTime = nil
                        stopAudio()
                        lastPlayedSceneIndexDuringPlayback = nil
                    } else {
                        singleScenePreviewIndex = nil
                        singleScenePreviewEndTime = nil
                        let curIdx = activeSceneIndex
                        lastPlayedSceneIndexDuringPlayback = curIdx
                        if let matchingAudio = audioItems.first(where: { $0.targetSceneIndex == curIdx && !$0.isMuted }) {
                            playAudio(path: matchingAudio.audioPath, volume: matchingAudio.volume, playbackRate: matchingAudio.playbackRate)
                        } else if movieScenes.indices.contains(curIdx), let path = movieScenes[curIdx].audioPath {
                            playAudio(path: path)
                        }
                        beginPlaybackClock()
                    }
                }) {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                }
                .buttonStyle(.borderedProminent)
                
                Button(action: {
                    currentTime = 0.0
                    stopAudio()
                }) {
                    Image(systemName: "backward.end.fill")
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                // バックグラウンドプロセス表示
                HStack(spacing: 6) {
                    ProgressView().controlSize(.small)
                    Text("BGP: レンダリング待機中")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(6)
                
                // ガイド
                Button(action: { state.openHelpGuide() }) {
                    Label("ガイド", systemImage: "questionmark.circle")
                }
                .buttonStyle(.bordered)
                
                // 書き出し画面へ
                Button(action: {
                    syncExportFileNameFromEditingFile()
                    screenMode = .export
                }) {
                    Label("書き出し…", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.04))
            
            Divider()
            
            // レイアウト別メイン作業エリア
            Group {
                switch editorLayout {
                case 1:
                    layout1View // PR & FCP拡張
                case 2:
                    layout2View // 素材一覧・情報・スタジオ移動
                case 3:
                    layout3View // アプリ内ブラウザ
                case 4:
                    layout4View // 素材スタジオ
                case 5:
                    layout5View // スライド＆シナリオメーカー連携
                case 6:
                    layout6View // ストア
                case 7:
                    layout7View // 履歴とステータス
                case 8:
                    layout8View // 有料機能一覧
                case 9:
                    layout9View // 以前のバージョンとの比較
                default:
                    layout2View
                }
            }
            
            Divider()
            
            // 下部タイムラインエリア (仕様書 P.156: 再生時間/全体時間、タイムライン)
            timelineBottomBar
        }
    }
    
    // レイアウト1: PremierPro & FinalCutPro拡張スロット (P.156)
    private var layout1View: some View {
        HSplitView {
            videoPreviewBox
            VStack(spacing: 16) {
                Text("アプリ拡張連携スロット (P.156)")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 10) {
                    Text("・Adobe Premiere Pro連携スロット: 接続待機中")
                    Text("・Apple Final Cut Pro連携スロット: 接続待機中")
                    Text("※アプリ拡張購入でXML/FCPXML双方向シームレス同期が有効になります。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(8)
                
                Spacer()
            }
            .padding()
            .frame(minWidth: 260)
        }
    }
    
    // レイアウト2: 素材一覧・素材情報・素材スタジオへ移動 (P.157)
    private var layout2View: some View {
        HSplitView {
            videoPreviewBox
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("素材一覧 (P.157)")
                        .font(.headline)
                    Spacer()
                    Button("素材スタジオへ移動") {
                        state.primarySelection = .materialStudio
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                
                List {
                    Section("登録素材") {
                        ForEach(state.materialAssets.prefix(5)) { item in
                            HStack {
                                Image(systemName: item.iconName)
                                    .foregroundColor(.accentColor)
                                VStack(alignment: .leading) {
                                    Text(item.name).font(.caption).fontWeight(.medium)
                                    Text("\(item.category) • \(String(format: "%.1fMB", item.sizeMB))")
                                        .font(.caption2).foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                }
                .listStyle(.inset)
                
                // 素材情報
                VStack(alignment: .leading, spacing: 4) {
                    Text("素材情報: 博麗霊夢_通常立ち絵")
                        .font(.caption).fontWeight(.bold)
                    Text("解像度: 2048x2048 / 透過PNG / 適合確認済み")
                        .font(.caption2).foregroundColor(.secondary)
                }
                .padding(8)
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(6)
            }
            .padding()
            .frame(minWidth: 280)
        }
    }
    
    // レイアウト3: アプリ内ブラウザ (P.158)
    private var layout3View: some View {
        HSplitView {
            videoPreviewBox
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("アプリ内ブラウザ (P.158)")
                        .font(.headline)
                    Spacer()
                    Button("何でも屋を開く") { state.openNanndemoyaSite() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }
                
                Text("URL: https://www.nanndemoya.net")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                ZStack {
                    Color.secondary.opacity(0.06).cornerRadius(8)
                    VStack(spacing: 8) {
                        Image(systemName: "globe")
                            .font(.largeTitle)
                            .foregroundColor(.accentColor)
                        Text("東方Project素材・サポート・ガイド閲覧中")
                            .font(.caption)
                    }
                }
            }
            .padding()
            .frame(minWidth: 280)
        }
    }
    
    // レイアウト4: 素材スタジオ (P.159)
    private var layout4View: some View {
        MaterialStudioView()
    }
    
    // レイアウト5: スライド＆シナリオメーカー連携 (P.160) - 画像・テロップと音声の分離管理
    private var layout5View: some View {
        HSplitView {
            videoPreviewBox
            
            VStack(alignment: .leading, spacing: 10) {
                // 上部管理タブ切り替え (Picker)
                Picker("管理対象", selection: $managementTab) {
                    ForEach(ManagementTab.allCases) { tab in
                        Label(tab.rawValue, systemImage: tab.icon).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 2)
                
                // タブ別コンテンツ
                switch managementTab {
                case .visualScenes:
                    visualScenesManagementView
                case .audioFiles:
                    audioFilesManagementView
                case .timelineTracks:
                    timelineTracksManagementView
                }
            }
            .padding()
            .frame(minWidth: 380)
        }
    }
    
    // MARK: - 既存シーン（画像・テロップ）管理ビュー
    private var visualScenesManagementView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("既存シーン（画像・テロップ）")
                        .font(.headline)
                    Text("全\(movieScenes.count)シーン / 合計 \(String(format: "%02d:%02d", Int(duration)/60, Int(duration)%60))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { addSingleScene() }) {
                    Label("シーン追加", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            Text("画像クリックで差し替え、テロップ（字幕）は直接インライン編集可能")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            List {
                ForEach(movieScenes.indices, id: \.self) { idx in
                    let sc = movieScenes[idx]
                    VStack(alignment: .leading, spacing: 8) {
                        // 1. ヘッダー行: シーン番号、タイトル編集、表示秒数、削除
                        HStack(spacing: 8) {
                            Text("第\(idx + 1)幕:")
                                .font(.callout)
                                .fontWeight(.bold)
                                .foregroundColor(.accentColor)
                            
                            TextField("シーン名", text: Binding(
                                get: { movieScenes[idx].title },
                                set: { movieScenes[idx].title = $0; updateSceneNames() }
                            ))
                            .textFieldStyle(.roundedBorder)
                            .font(.callout)
                            
                            HStack(spacing: 2) {
                                TextField("秒数", value: Binding(
                                    get: { movieScenes[idx].duration },
                                    set: { val in
                                        movieScenes[idx].duration = max(0.5, val)
                                        recalculateTotalDuration()
                                    }
                                ), format: .number)
                                .frame(width: 50)
                                .textFieldStyle(.roundedBorder)
                                .monospacedDigit()
                                Text("秒")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            // 個別シーンプレビュー再生ボタン
                            let isCurPlaying = isPlaying && (singleScenePreviewIndex == idx || (singleScenePreviewIndex == nil && activeSceneIndex == idx))
                            Button(action: {
                                if isPlaying && singleScenePreviewIndex == idx {
                                    stopPlaybackClock()
                                    singleScenePreviewIndex = nil
                                    singleScenePreviewEndTime = nil
                                    stopAudio()
                                } else {
                                    playScenePreview(index: idx)
                                }
                            }) {
                                HStack(spacing: 3) {
                                    Image(systemName: isCurPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    Text(isCurPlaying ? "停止" : "再生")
                                }
                                .font(.caption2)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .help("このシーンをアニメーション演出・音声付きでプレビュー再生します")
                            
                            Button(action: { removeScene(at: idx) }) {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(.red.opacity(0.8))
                            }
                            .buttonStyle(.plain)
                            .help("このシーンを削除")
                        }
                        
                        // 2. メイン行: 画像サムネイル + テロップ編集
                        HStack(alignment: .top, spacing: 10) {
                            // 画像サムネイル（クリックで画像変更）
                            Button(action: { changeSceneImage(index: idx) }) {
                                ZStack {
                                    if let imgPath = sc.imagePath, let nsImage = NSImage(contentsOfFile: imgPath) {
                                        Image(nsImage: nsImage)
                                            .resizable()
                                            .aspectRatio(16/9, contentMode: .fill)
                                            .frame(width: 72, height: 40)
                                            .cornerRadius(4)
                                            .clipped()
                                    } else {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.secondary.opacity(0.15))
                                            .frame(width: 72, height: 40)
                                            .overlay(
                                                VStack(spacing: 2) {
                                                    Image(systemName: "photo.badge.plus")
                                                        .font(.system(size: 14))
                                                    Text("画像選択")
                                                        .font(.system(size: 8))
                                                }
                                                .foregroundColor(.secondary)
                                            )
                                    }
                                }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(selectedSceneIndex == idx ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .help("クリックしてこのシーンのスライド画像を変更")
                            
                            // テロップ編集エリア
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text("話者:")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    TextField("話者名 (例: 霊夢, 操夢)", text: Binding(
                                        get: { movieScenes[idx].speakerCharacter ?? "" },
                                        set: { movieScenes[idx].speakerCharacter = $0.isEmpty ? nil : $0 }
                                    ))
                                    .textFieldStyle(.roundedBorder)
                                    .frame(maxWidth: 140)
                                    
                                    if let meta = sc.animationMeta, !meta.isEmpty {
                                        HStack(spacing: 3) {
                                            Image(systemName: "film.fill")
                                            Text(meta)
                                                .fontWeight(.bold)
                                        }
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.purple.opacity(0.15))
                                        .foregroundColor(.purple)
                                        .cornerRadius(4)
                                        .lineLimit(1)
                                    }
                                }
                                
                                // テロップ本文（直接編集可能・アニメーションメタ自動抽出連動）
                                TextField("テロップ・セリフ字幕テキストを入力…", text: Binding(
                                    get: { movieScenes[idx].scriptText ?? "" },
                                    set: { newText in
                                        movieScenes[idx].scriptText = newText
                                        let parsed = FileFormatParser.parseNoteMeta(note: newText)
                                        if let spk = parsed.speaker, movieScenes[idx].speakerCharacter == nil {
                                            movieScenes[idx].speakerCharacter = spk
                                        }
                                        if let aMeta = parsed.animMeta {
                                            movieScenes[idx].animationMeta = aMeta
                                        }
                                        if let aDur = parsed.duration {
                                            movieScenes[idx].animationDuration = aDur
                                            movieScenes[idx].duration = max(movieScenes[idx].duration, aDur)
                                            recalculateTotalDuration()
                                            updateSceneNames()
                                        }
                                    }
                                ), axis: .vertical)
                                .lineLimit(2...4)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                            }
                        }
                        
                        // 3. 音声連携ステータスバー
                        HStack(spacing: 6) {
                            if let matchingAudio = audioItems.first(where: { $0.targetSceneIndex == idx }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "waveform")
                                        .font(.system(size: 9))
                                    Text("音声: \(matchingAudio.audioFileName)")
                                        .font(.system(size: 10, design: .monospaced))
                                        .lineLimit(1)
                                }
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.12))
                                .cornerRadius(4)
                                
                                Button("音声管理で確認") {
                                    if let aIdx = audioItems.firstIndex(where: { $0.targetSceneIndex == idx }) {
                                        selectedAudioIndex = aIdx
                                    }
                                    managementTab = .audioFiles
                                }
                                .buttonStyle(.plain)
                                .font(.caption2)
                                .foregroundColor(.accentColor)
                                
                                Spacer()
                                
                                Button(action: {
                                    // 紐付け解除
                                    if let aIdx = audioItems.firstIndex(where: { $0.targetSceneIndex == idx }) {
                                        audioItems[aIdx].targetSceneIndex = nil
                                        movieScenes[idx].audioPath = nil
                                        movieScenes[idx].audioFileName = nil
                                        updateSceneNames()
                                    }
                                }) {
                                    Image(systemName: "link.badge.minus")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                .buttonStyle(.plain)
                                .help("音声の紐付けを解除")
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "waveform.slash")
                                        .font(.system(size: 9))
                                    Text("音声未割当")
                                        .font(.system(size: 10))
                                }
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.08))
                                .cornerRadius(4)
                                
                                Spacer()
                                
                                Button("音声を指定…") {
                                    assignSingleAudio(index: idx)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                            }
                        }
                    }
                    .padding(8)
                    .background(selectedSceneIndex == idx ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.04))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(selectedSceneIndex == idx ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
                    .onTapGesture {
                        selectedSceneIndex = idx
                    }
                }
            }
            .listStyle(.inset)
        }
    }
    
    // MARK: - 分離音声ファイル管理ビュー
    private var audioFilesManagementView: some View {
        let totalSec = audioItems.reduce(0.0) { $0 + $1.duration }
        let filteredIndices: [Int] = audioItems.indices.filter { idx in
            let it = audioItems[idx]
            switch audioFilterCategory {
            case "🎙️セリフ": return it.isVoice
            case "🎵BGM": return it.isBGM
            case "⚡効果音": return it.isSE
            default: return true
            }
        }
        
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("音声・BGM・効果音管理")
                            .font(.headline)
                        if let soundName = associatedSoundProjectName {
                            Text("連携: \(soundName)")
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.purple.opacity(0.15))
                                .foregroundColor(.purple)
                                .cornerRadius(4)
                        }
                    }
                    Text("全\(audioItems.count)件 (🎙️セリフ: \(audioItems.filter { $0.isVoice }.count) / 🎵BGM: \(audioItems.filter { $0.isBGM }.count) / ⚡SE: \(audioItems.filter { $0.isSE }.count)) / 合計 \(String(format: "%.1f", totalSec))秒")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                // サウンドメーカー(.tssm)一括読込
                Button(action: { loadTssmFile() }) {
                    Label("サウンド読込 (.tssm)", systemImage: "music.note.list")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .help("サウンドメーカープロジェクト（.tssm）からBGM・効果音・音量・再生速度・逆再生などの全音声を取り込みます")
                
                // フォルダ一括割当
                Button(action: { batchAssignAudioFolder() }) {
                    Label("フォルダ一括割当", systemImage: "folder.badge.gearshape")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                // 単一追加
                Button(action: { addSingleAudioFile() }) {
                    Label("音声追加", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            HStack(spacing: 12) {
                // 種別カテゴリフィルタ
                Picker("絞り込み", selection: $audioFilterCategory) {
                    Text("すべて (\(audioItems.count))").tag("すべて")
                    Text("🎙️セリフ (\(audioItems.filter { $0.isVoice }.count))").tag("🎙️セリフ")
                    Text("🎵BGM (\(audioItems.filter { $0.isBGM }.count))").tag("🎵BGM")
                    Text("⚡効果音 (\(audioItems.filter { $0.isSE }.count))").tag("⚡効果音")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 340)
                
                Button(action: { realignAudioItemsToScenes() }) {
                    Label("シーン番号で自動再整列", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                
                Spacer()
                
                Text("音量・速度・逆再生・BGM/SEスパンを個別管理可能")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            if audioItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "waveform.circle")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("音声・BGM・効果音がまだ登録されていません")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    HStack(spacing: 12) {
                        Button("サウンドメーカー（.tssm）を読み込む") {
                            loadTssmFile()
                        }
                        .buttonStyle(.borderedProminent)
                        Button("音声フォルダを選択して一括割当") {
                            batchAssignAudioFolder()
                        }
                        .buttonStyle(.bordered)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                List {
                    ForEach(filteredIndices, id: \.self) { aIdx in
                        let item = audioItems[aIdx]
                        VStack(alignment: .leading, spacing: 6) {
                            // 1. 上段: 種別バッジ、ファイル名、逆再生バッジ、再生時間、削除
                            HStack(spacing: 6) {
                                // 種別アイコン＆バッジ
                                Menu {
                                    Button("🎙️ セリフ音声に設定") {
                                        audioItems[aIdx].trackType = "voice"
                                    }
                                    Button("🎵 BGMに設定") {
                                        audioItems[aIdx].trackType = "bgm"
                                    }
                                    Button("⚡ 効果音(SE)に設定") {
                                        audioItems[aIdx].trackType = "se"
                                    }
                                } label: {
                                    HStack(spacing: 2) {
                                        Image(systemName: item.isVoice ? "waveform" : (item.isBGM ? "music.note" : "bolt.fill"))
                                        Text(item.isVoice ? "セリフ" : (item.isBGM ? "BGM" : "効果音"))
                                    }
                                    .font(.system(size: 9, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(item.isVoice ? Color.green.opacity(0.2) : (item.isBGM ? Color.purple.opacity(0.2) : Color.orange.opacity(0.2)))
                                    .foregroundColor(item.isVoice ? .green : (item.isBGM ? .purple : .orange))
                                    .cornerRadius(4)
                                }
                                .menuStyle(.borderlessButton)
                                .frame(width: 65)
                                
                                Text(item.audioFileName)
                                    .font(.callout)
                                    .fontWeight(.bold)
                                    .lineLimit(1)
                                
                                if item.isReversed {
                                    Text("⏪ 逆再生")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.red.opacity(0.2))
                                        .foregroundColor(.red)
                                        .cornerRadius(3)
                                }
                                
                                if item.loops {
                                    Text("🔁 ループ")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Color.blue.opacity(0.2))
                                        .foregroundColor(.blue)
                                        .cornerRadius(3)
                                }
                                
                                Spacer()
                                
                                Text("\(String(format: "%.1f", item.duration))秒")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .monospacedDigit()
                                
                                Button(action: { removeAudioItem(at: aIdx) }) {
                                    Image(systemName: "trash")
                                        .font(.caption)
                                        .foregroundColor(.red.opacity(0.8))
                                }
                                .buttonStyle(.plain)
                                .help("この音声ファイルをリストから削除")
                            }
                            
                            // 2. 中段: 割当シーン選択 & 開始時間
                            HStack(spacing: 8) {
                                if item.isVoice {
                                    Text("割当先シーン:")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    Picker("", selection: Binding(
                                        get: { audioItems[aIdx].targetSceneIndex ?? -1 },
                                        set: { newSceneIdx in
                                            audioItems[aIdx].targetSceneIndex = newSceneIdx == -1 ? nil : newSceneIdx
                                            audioItems[aIdx].startSceneIndex = newSceneIdx == -1 ? nil : newSceneIdx
                                            audioItems[aIdx].endSceneIndex = newSceneIdx == -1 ? nil : newSceneIdx
                                            syncAudioToScene(audioIndex: aIdx)
                                        }
                                    )) {
                                        Text("未割当 (独立配置)").tag(-1)
                                        ForEach(movieScenes.indices, id: \.self) { sIdx in
                                            Text("第\(sIdx + 1)幕: \(movieScenes[sIdx].title)").tag(sIdx)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(maxWidth: 180)
                                } else {
                                    // BGMまたは効果音: スパン（開始シーン 〜 終了シーン）指定
                                    Text("適用シーン範囲:")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    Picker("開始", selection: Binding(
                                        get: { audioItems[aIdx].startSceneIndex ?? audioItems[aIdx].targetSceneIndex ?? 0 },
                                        set: { newStart in
                                            audioItems[aIdx].startSceneIndex = newStart
                                            if (audioItems[aIdx].endSceneIndex ?? newStart) < newStart {
                                                audioItems[aIdx].endSceneIndex = newStart
                                            }
                                            audioItems[aIdx].targetSceneIndex = newStart
                                            syncAudioToScene(audioIndex: aIdx)
                                        }
                                    )) {
                                        ForEach(movieScenes.indices, id: \.self) { sIdx in
                                            Text("第\(sIdx + 1)幕").tag(sIdx)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(maxWidth: 100)
                                    
                                    Text("〜")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    
                                    Picker("終了", selection: Binding(
                                        get: { audioItems[aIdx].endSceneIndex ?? audioItems[aIdx].startSceneIndex ?? audioItems[aIdx].targetSceneIndex ?? 0 },
                                        set: { newEnd in
                                            let s = audioItems[aIdx].startSceneIndex ?? 0
                                            audioItems[aIdx].endSceneIndex = max(s, newEnd)
                                        }
                                    )) {
                                        ForEach(movieScenes.indices, id: \.self) { sIdx in
                                            Text("第\(sIdx + 1)幕").tag(sIdx)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(maxWidth: 100)
                                }
                                
                                if let spk = item.speakerCharacter, !spk.isEmpty {
                                    Text("【\(spk)】")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                            }
                            
                            // 3. 下段: 音量、速度、逆再生トグル、ループトグル、試聴
                            HStack(spacing: 12) {
                                // 試聴ボタン（逆再生設定も反映）
                                Button(action: {
                                    togglePlayAudioItem(index: aIdx)
                                }) {
                                    HStack(spacing: 4) {
                                        Image(systemName: playingAudioItemIndex == aIdx ? "stop.circle.fill" : "play.circle.fill")
                                        Text(playingAudioItemIndex == aIdx ? "停止" : "試聴")
                                    }
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                                
                                // ミュートボタン
                                Button(action: {
                                    audioItems[aIdx].isMuted.toggle()
                                    if audioItems[aIdx].isMuted {
                                        if playingAudioItemIndex == aIdx { stopAudio() }
                                        audioPlayer?.volume = 0
                                    } else if playingAudioItemIndex == aIdx {
                                        audioPlayer?.volume = Float(audioItems[aIdx].volume)
                                    }
                                    recalculateTotalDuration()
                                }) {
                                    Image(systemName: audioItems[aIdx].isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                        .foregroundColor(audioItems[aIdx].isMuted ? .red : .primary)
                                        .font(.caption)
                                }
                                .buttonStyle(.plain)
                                .help(audioItems[aIdx].isMuted ? "ミュート解除" : "ミュート")
                                
                                // 逆再生トグル
                                Button(action: {
                                    audioItems[aIdx].isReversed.toggle()
                                    if playingAudioItemIndex == aIdx {
                                        stopAudio()
                                    }
                                }) {
                                    HStack(spacing: 2) {
                                        Image(systemName: audioItems[aIdx].isReversed ? "arrow.counterclockwise.circle.fill" : "arrow.counterclockwise.circle")
                                        Text("逆再生")
                                    }
                                    .font(.system(size: 9))
                                    .foregroundColor(audioItems[aIdx].isReversed ? .red : .secondary)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                                .help("音声を逆再生（リバース）します")
                                
                                // ループ再生トグル
                                Button(action: {
                                    audioItems[aIdx].loops.toggle()
                                }) {
                                    HStack(spacing: 2) {
                                        Image(systemName: audioItems[aIdx].loops ? "repeat.circle.fill" : "repeat.circle")
                                        Text("ループ")
                                    }
                                    .font(.system(size: 9))
                                    .foregroundColor(audioItems[aIdx].loops ? .blue : .secondary)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.mini)
                                .help("シーン範囲内でループ再生します")
                                
                                // 音量スライダー
                                HStack(spacing: 4) {
                                    Text("音量")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                    Slider(value: Binding(
                                        get: { audioItems[aIdx].volume },
                                        set: { newVol in
                                            audioItems[aIdx].volume = newVol
                                            if playingAudioItemIndex == aIdx || playingAudioSceneIndex == audioItems[aIdx].targetSceneIndex {
                                                audioPlayer?.volume = Float(max(0.0, min(1.0, newVol)))
                                            }
                                        }
                                    ), in: 0...1)
                                    .frame(width: 70)
                                    Text("\(Int(audioItems[aIdx].volume * 100))%")
                                        .font(.system(size: 9))
                                        .monospacedDigit()
                                        .foregroundColor(.secondary)
                                }

                                // 速度スライダー (0.25x 〜 3.0x)
                                HStack(spacing: 4) {
                                    Text("速度")
                                        .font(.system(size: 9))
                                        .foregroundColor(.secondary)
                                    Slider(value: Binding(
                                        get: { audioItems[aIdx].playbackRate },
                                        set: { newRate in
                                            audioItems[aIdx].playbackRate = max(0.25, min(3.0, newRate))
                                            syncAudioToScene(audioIndex: aIdx)
                                        }
                                    ), in: 0.25...3.0, step: 0.05)
                                    .frame(width: 70)
                                    Text(String(format: "%.2fx", audioItems[aIdx].playbackRate))
                                        .font(.system(size: 9))
                                        .monospacedDigit()
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                        }
                        .padding(8)
                        .background(selectedAudioIndex == aIdx ? Color.accentColor.opacity(0.08) : Color.secondary.opacity(0.04))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(selectedAudioIndex == aIdx ? Color.accentColor.opacity(0.5) : Color.clear, lineWidth: 1)
                        )
                        .onTapGesture {
                            selectedAudioIndex = aIdx
                        }
                    }
                }
                .listStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - 二段トラック管理ビュー（映像トラック＋音声トラック）
    private var timelineTracksManagementView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("二段トラックタイムライン詳細 (P.160)")
                    .font(.headline)
                Spacer()
                Text("現在の再生位置: \(String(format: "%.1f秒", currentTime))")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.accentColor)
            }
            
            Text("上段: 既存シーン（画像・テロップ） / 下段: 音声ファイル。クリックでその時間へシーク")
                .font(.caption2)
                .foregroundColor(.secondary)
            
            ScrollView(.horizontal, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 6) {
                    // 上段: 映像トラック（画像＋テロップ）
                    HStack(spacing: 0) {
                        Text("映像")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 36)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 2) {
                            ForEach(movieScenes.indices, id: \.self) { idx in
                                let sc = movieScenes[idx]
                                let blockWidth = max(70.0, sc.duration * 8.0)
                                Button(action: {
                                    seekToScene(index: idx)
                                }) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text("第\(idx + 1)幕")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.white)
                                            Spacer()
                                            Text("\(String(format: "%.1f", sc.duration))s")
                                                .font(.system(size: 8))
                                                .foregroundColor(.white.opacity(0.8))
                                        }
                                        if let txt = sc.scriptText, !txt.isEmpty {
                                            Text(txt)
                                                .font(.system(size: 8))
                                                .foregroundColor(.white.opacity(0.9))
                                                .lineLimit(1)
                                        }
                                    }
                                    .padding(4)
                                    .frame(width: blockWidth, height: 42, alignment: .topLeading)
                                    .background(selectedSceneIndex == idx ? Color.accentColor : Color.blue.opacity(0.75))
                                    .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    
                    // 下段: 音声トラック（音声ファイル / BGM / 効果音）
                    HStack(spacing: 0) {
                        Text("音声")
                            .font(.system(size: 10, weight: .bold))
                            .frame(width: 36)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 2) {
                            ForEach(audioItems.indices, id: \.self) { aIdx in
                                let item = audioItems[aIdx]
                                let blockWidth = max(65.0, item.duration * 8.0)
                                let trackBgColor: Color = {
                                    if item.isMuted { return Color.gray.opacity(0.6) }
                                    if item.isBGM { return selectedAudioIndex == aIdx ? Color.purple : Color.purple.opacity(0.75) }
                                    if item.isSE { return selectedAudioIndex == aIdx ? Color.orange : Color.orange.opacity(0.8) }
                                    return selectedAudioIndex == aIdx ? Color.green : Color.green.opacity(0.75)
                                }()
                                
                                Button(action: {
                                    currentTime = item.startTime
                                    selectedAudioIndex = aIdx
                                }) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 3) {
                                            Image(systemName: item.isBGM ? "music.note" : (item.isSE ? "bolt.fill" : "waveform"))
                                                .font(.system(size: 8))
                                            Text(item.audioFileName)
                                                .font(.system(size: 8, weight: .medium))
                                                .lineLimit(1)
                                            Spacer()
                                            if item.isReversed {
                                                Text("⏪")
                                                    .font(.system(size: 7))
                                            }
                                        }
                                        HStack {
                                            Text("\(String(format: "%.1f", item.duration))s")
                                                .font(.system(size: 7))
                                                .foregroundColor(.white.opacity(0.8))
                                            if abs(item.playbackRate - 1.0) > 0.05 {
                                                Text("\(String(format: "%.1fx", item.playbackRate))")
                                                    .font(.system(size: 7, weight: .bold))
                                                    .foregroundColor(.yellow)
                                            }
                                            Spacer()
                                        }
                                    }
                                    .padding(4)
                                    .frame(width: blockWidth, height: 36, alignment: .topLeading)
                                    .background(trackBgColor)
                                    .foregroundColor(.white)
                                    .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.06))
                .cornerRadius(6)
            }
            .frame(maxHeight: 120)
            
            Spacer()
        }
    }
    
    // レイアウト6: ストア (P.161)
    private var layout6View: some View {
        StoreDetailView(selection: .newAndRecommended)
    }
    
    // レイアウト7: 編集ファイルの履歴とステータス (P.162)
    private var layout7View: some View {
        HSplitView {
            videoPreviewBox
            VStack(alignment: .leading, spacing: 10) {
                Text("編集ファイルの履歴とステータス (P.162)")
                    .font(.headline)
                List(state.editHistoryList, id: \.self) { hist in
                    Text(hist).font(.caption)
                }
            }
            .padding()
            .frame(minWidth: 260)
        }
    }
    
    // レイアウト8: 有料機能のアプリ拡張で追加した機能一覧 (P.163)
    private var layout8View: some View {
        VStack(spacing: 16) {
            Text("有料機能のアプリ拡張で追加した機能一覧 (P.163)")
                .font(.headline)
            Text("（FinalCutPro & PremierPro & 独自機能）")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Adobe Premiere Pro 連携").fontWeight(.bold)
                    Text("タイムライン・マーカー・テロップ完全同期")
                        .font(.caption).foregroundColor(.secondary)
                }
                .padding().frame(maxWidth: .infinity).background(Color.secondary.opacity(0.08)).cornerRadius(8)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Final Cut Pro 連携").fontWeight(.bold)
                    Text("FCPXMLエクスポート・Apple ProResレンダリング")
                        .font(.caption).foregroundColor(.secondary)
                }
                .padding().frame(maxWidth: .infinity).background(Color.secondary.opacity(0.08)).cornerRadius(8)
            }
            .padding(.horizontal)
            Spacer()
        }
        .padding()
    }
    
    // レイアウト9: 以前のバージョンとの比較と復元 (P.164)
    private var layout9View: some View {
        HSplitView {
            VStack {
                Text("以前のバージョン (P.164)")
                    .font(.subheadline).fontWeight(.bold)
                Color.black.opacity(0.7).cornerRadius(8)
                    .overlay(Text("自動保存 Ver. 2026/09/21 14:00").foregroundColor(.white))
                Button("以前の版に復元") {
                    state.notify(title: "バージョン復元", message: "指定された以前の版に復元しました。")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            VStack {
                Text("編集中のバージョン (P.164)")
                    .font(.subheadline).fontWeight(.bold)
                Color.black.cornerRadius(8)
                    .overlay(Text("最新編集版").foregroundColor(.white))
                Button("最新版に更新") {
                    state.notify(title: "最新版同期", message: "最新の編集状態を保持しました。")
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
    }
    

    /// シーンに紐づく音声（ミュート含む）
    private func audioItem(forSceneIndex index: Int) -> MovieAudioData? {
        audioItems.first(where: { $0.targetSceneIndex == index })
    }
    
    /// プレビュー／書き出し共通の有効シーン尺（設定尺・アニメ尺・速度反映後の音声尺の最大）
    private func effectiveSceneDuration(at index: Int) -> Double {
        guard movieScenes.indices.contains(index) else { return 0.5 }
        let sc = movieScenes[index]
        var dur = max(0.5, sc.duration)
        if let anim = sc.animationDuration, anim > 0 {
            dur = max(dur, anim)
        }
        if let audio = audioItem(forSceneIndex: index), !audio.isMuted {
            dur = max(dur, audio.effectivePlaybackDuration)
        } else if let ad = sc.audioDuration, ad > 0 {
            dur = max(dur, ad)
        }
        return dur
    }
    
    private func sceneStartTime(at index: Int) -> Double {
        guard index > 0 else { return 0 }
        var acc = 0.0
        for i in 0..<min(index, movieScenes.count) {
            acc += effectiveSceneDuration(at: i)
        }
        return acc
    }
    
    private func syncExportFileNameFromEditingFile() {
        let base = currentFileName.replacingOccurrences(of: "\.[a-zA-Z0-9]+$", with: "", options: .regularExpression)
        if !base.isEmpty {
            exportFileName = base
        }
    }
    
    private func beginPlaybackClock() {
        playbackAnchorMediaTime = currentTime
        playbackAnchorDate = Date()
        isPlaying = true
    }
    
    private func stopPlaybackClock() {
        if let anchor = playbackAnchorDate {
            currentTime = playbackAnchorMediaTime + Date().timeIntervalSince(anchor)
        }
        playbackAnchorDate = nil
        isPlaying = false
    }
    
    private func playbackMediaTime(at date: Date) -> Double {
        if isPlaying, let anchor = playbackAnchorDate {
            return max(0.0, playbackAnchorMediaTime + date.timeIntervalSince(anchor))
        }
        return currentTime
    }
    
    private func sceneIndex(atMediaTime t: Double) -> Int {
        if movieScenes.isEmpty { return 0 }
        var accumulated: Double = 0.0
        for idx in movieScenes.indices {
            accumulated += effectiveSceneDuration(at: idx)
            if t <= accumulated { return idx }
        }
        return movieScenes.count - 1
    }
    
    private func sceneHasAnimation(_ sc: MovieSceneData) -> Bool {
        if let meta = sc.animationMeta, !meta.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        if let charAnim = sc.characterAnimation, !charAnim.isEmpty { return true }
        if let bgAnim = sc.backgroundAnimation, !bgAnim.isEmpty { return true }
        if let objAnim = sc.objectAnimation, !objAnim.isEmpty { return true }
        if let effect = sc.slideTransitionEffect,
           !effect.isEmpty,
           effect != "no transition effect",
           effect.lowercased() != "none" {
            return true
        }
        if !SlideAnimationKit.parseRecipes(from: sc.animationMeta).isEmpty { return true }
        return false
    }
    
    // 現在のプレビュー対象シーンのインデックス
    private var activeSceneIndex: Int {
        if movieScenes.isEmpty { return 0 }
        if isPlaying {
            var accumulated: Double = 0.0
            for idx in movieScenes.indices {
                accumulated += effectiveSceneDuration(at: idx)
                if currentTime <= accumulated {
                    return idx
                }
            }
            return movieScenes.count - 1
        } else {
            if movieScenes.indices.contains(selectedSceneIndex) {
                return selectedSceneIndex
            }
            return 0
        }
    }
    
    // 現在のプレビュー対象シーン（再生中ならcurrentTimeに対応、停止中ならselectedSceneIndex）
    private var activeSceneData: MovieSceneData? {
        if movieScenes.isEmpty { return nil }
        let idx = activeSceneIndex
        if movieScenes.indices.contains(idx) {
            return movieScenes[idx]
        }
        return movieScenes.first
    }
    
    // 現在のシーンの開始時刻
    private var currentSceneStartTime: Double {
        sceneStartTime(at: activeSceneIndex)
    }
    
    // 現在のシーン内での経過秒数
    private var currentSceneElapsed: Double {
        let start = currentSceneStartTime
        return max(0.0, currentTime - start)
    }
    
    // 現在のシーンの進行割合 (0.0 ... 1.0)
    private var currentSceneProgress: Double {
        let dur = effectiveSceneDuration(at: activeSceneIndex)
        guard dur > 0.05 else { return 0.0 }
        return min(1.0, max(0.0, currentSceneElapsed / dur))
    }
    
    // 現在のシーンがアニメーションを含むか
    private var isCurrentSceneAnimated: Bool {
        guard let sc = activeSceneData else { return false }
        return sceneHasAnimation(sc)
    }
    
    // プレビュー共通枠 (8段階順序レイヤー描画: 背景→背景アニメ→キャラ→キャラアニメ→オブジェクト→オブジェクトアニメ→テロップ/ノート→トランジション)
    // プレビュー共通枠 (8段階順序レイヤー描画: 背景→背景アニメ→キャラ→キャラアニメ→オブジェクト→オブジェクトアニメ→テロップ/ノート→トランジション)
    // TimelineView(.animation) で Date 駆動の毎フレーム更新（0.1s Timer だけに依存しない）
    private var videoPreviewBox: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: !isPlaying)) { context in
            let mediaTime = playbackMediaTime(at: context.date)
            let sceneIdx = isPlaying ? sceneIndex(atMediaTime: mediaTime) : activeSceneIndex
            let activeScene: MovieSceneData? = movieScenes.indices.contains(sceneIdx) ? movieScenes[sceneIdx] : activeSceneData
            let sceneStart = sceneStartTime(at: sceneIdx)
            let sceneDur = max(0.05, effectiveSceneDuration(at: sceneIdx))
            let sceneElapsed = max(0.0, mediaTime - sceneStart)
            let p = isPlaying ? min(1.0, sceneElapsed / sceneDur) : 0.0
            let wallElapsed = isPlaying ? sceneElapsed : 0.0
            let isAnim = activeScene.map { sceneHasAnimation($0) } ?? false
            let states = getAnimationStates(
                activeScene: activeScene,
                isAnim: isAnim,
                isPlaying: isPlaying,
                p: p,
                wallElapsed: wallElapsed
            )
            
            ZStack {
                Color.black.cornerRadius(8)
                
                if let activeScene = activeScene {
                    // 1-2. 背景 + 背景アニメ
                    let bgPath = activeScene.backgroundImagePath ?? activeScene.imagePath
                    if let bgPath = bgPath, let bgImg = NSImage(contentsOfFile: bgPath) {
                        Image(nsImage: bgImg)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .scaleEffect(states.slideScale)
                            .offset(x: states.slideOffsetX, y: states.slideOffsetY)
                            .opacity(states.slideOpacity)
                            .cornerRadius(6)
                    } else {
                        Rectangle()
                            .fill(LinearGradient(colors: [Color(white: 0.15), Color(white: 0.08)], startPoint: .top, endPoint: .bottom))
                            .aspectRatio(16/9, contentMode: .fit)
                            .cornerRadius(6)
                    }
                    
                    // 3-4. キャラクター + キャラアニメ（char* のみ）
                    if let charPath = activeScene.characterImagePath, let charImg = NSImage(contentsOfFile: charPath) {
                        GeometryReader { geo in
                            Image(nsImage: charImg)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: geo.size.height * 0.88)
                                .scaleEffect(states.charScale)
                                .offset(x: states.charOffsetX, y: states.charOffsetY + geo.size.height * 0.06)
                                .opacity(states.charOpacity)
                                .shadow(color: .black.opacity(0.4), radius: 6, x: 0, y: 3)
                                .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
                        }
                        .aspectRatio(16/9, contentMode: .fit)
                    } else if let charAnimStr = activeScene.characterAnimation,
                              !charAnimStr.isEmpty,
                              (charAnimStr.contains("バウンス") || charAnimStr.lowercased().contains("bounce") || charAnimStr.contains("呼吸")),
                              let path = activeScene.imagePath ?? activeScene.backgroundImagePath,
                              let nsImage = NSImage(contentsOfFile: path) {
                        // キャラ素材未解決でも Keynote 書き出し画像の中央下をキャラ代理として char* を適用
                        GeometryReader { geo in
                            Image(nsImage: nsImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: geo.size.height * 0.88)
                                .scaleEffect(states.charScale)
                                .offset(x: states.charOffsetX, y: states.charOffsetY + geo.size.height * 0.02)
                                .opacity(states.charOpacity)
                                .mask(
                                    RoundedRectangle(cornerRadius: 8)
                                        .frame(width: geo.size.width * 0.42, height: geo.size.height * 0.72)
                                        .position(x: geo.size.width * 0.50, y: geo.size.height * 0.52)
                                )
                                .frame(width: geo.size.width, height: geo.size.height, alignment: .bottom)
                        }
                        .aspectRatio(16/9, contentMode: .fit)
                    } else if let spk = activeScene.speakerCharacter, !spk.isEmpty {
                        VStack {
                            Spacer()
                            HStack {
                                Image(systemName: "person.crop.rectangle.stack.fill")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 120, height: 160)
                                    .foregroundColor(.white.opacity(0.8))
                                    .shadow(color: .black, radius: 4, x: 0, y: 2)
                                    .overlay(
                                        Text(spk)
                                            .font(.caption).bold()
                                            .foregroundColor(.black)
                                            .padding(4)
                                            .background(Color.white.opacity(0.8))
                                            .cornerRadius(4)
                                            .offset(y: 60)
                                    )
                                    .scaleEffect(states.charScale)
                                    .offset(x: states.charOffsetX - 100, y: states.charOffsetY)
                                    .opacity(states.charOpacity)
                                Spacer()
                            }
                            .padding(.leading, 60)
                            .padding(.bottom, 20)
                        }
                    }
                    
                    // 5-6. オブジェクト + オブジェクトアニメ（obj* のみ。char には触らない）
                    if let objs = activeScene.objectsData, !objs.isEmpty {
                        GeometryReader { geo in
                            ForEach(objs) { obj in
                                if let txt = obj.text, !txt.isEmpty {
                                    Text(txt)
                                        .font(.system(size: max(11, geo.size.width * 0.024), weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .background(Color.black.opacity(0.65))
                                        .cornerRadius(6)
                                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.white.opacity(0.3), lineWidth: 1))
                                        .scaleEffect(states.objScale)
                                        .offset(x: states.objOffsetX, y: states.objOffsetY)
                                        .opacity(states.objOpacity)
                                        .position(
                                            x: min(geo.size.width * 0.9, max(geo.size.width * 0.1, geo.size.width * (obj.x / 1920.0))),
                                            y: min(geo.size.height * 0.75, max(geo.size.height * 0.15, geo.size.height * (obj.y / 1080.0)))
                                        )
                                }
                            }
                        }
                        .aspectRatio(16/9, contentMode: .fit)
                    }
                    
                    // 7. テロップ / ノート（オブジェクト系レシピのみ影響）
                    let telop = activeScene.telopText ?? activeScene.scriptText
                    if let telop = telop, !telop.isEmpty {
                        VStack {
                            Spacer()
                            HStack(spacing: 8) {
                                if let spk = activeScene.speakerCharacter, !spk.isEmpty {
                                    Text(spk)
                                        .font(.system(size: 13, weight: .bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue.opacity(0.85))
                                        .foregroundColor(.white)
                                        .cornerRadius(4)
                                }
                                Text(telop)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    colors: [Color.black.opacity(0.88), Color.black.opacity(0.70)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .cornerRadius(6)
                            .scaleEffect(states.objScale)
                            .offset(x: states.objOffsetX, y: states.objOffsetY)
                            .opacity(states.objOpacity)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                        }
                        .aspectRatio(16/9, contentMode: .fit)
                    }
                    
                    // 8. スライドトランジション（効果名があるときだけ。なしなら無理にフェードしない）
                    if let effectRaw = activeScene.slideTransitionEffect {
                        let effect = effectRaw.trimmingCharacters(in: .whitespacesAndNewlines)
                        let effectLower = effect.lowercased()
                        let isNone = effect.isEmpty
                            || effect == "no transition effect"
                            || effectLower == "none"
                            || effect.contains("なし")
                            || effect.contains("無し")
                            || effectLower.contains("no transition")
                        if !isNone, isPlaying {
                            let trDur = max(0.15, min(2.0, activeScene.slideTransitionDuration ?? 0.8))
                            if sceneElapsed < trDur {
                                let trProgress = min(1.0, sceneElapsed / trDur)
                                let t = CGFloat(trProgress)
                                if effectLower.contains("push") || effect.contains("プッシュ") || effectLower.contains("slide") || effect.contains("スライド") {
                                    // 押し出し相当: 黒帯ではなくコンテンツ側オフセットは slide* で表現しづらいのでフェード併用
                                    Color.black.opacity(Double(1.0 - t))
                                        .aspectRatio(16/9, contentMode: .fit)
                                        .offset(x: (1.0 - t) * -40)
                                } else if effectLower.contains("wipe") || effect.contains("ワイプ") {
                                    Color.black
                                        .aspectRatio(16/9, contentMode: .fit)
                                        .mask(
                                            Rectangle()
                                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                                .scaleEffect(x: max(0.001, 1.0 - t), anchor: .trailing)
                                        )
                                } else {
                                    // fade / dissolve / その他
                                    Color.black.opacity(Double(1.0 - t))
                                        .aspectRatio(16/9, contentMode: .fit)
                                }
                            }
                        }
                    }
                    
                    // 動画オーバーレイ情報（緑デバッグバッジは削除済み）
                    VStack(spacing: 6) {
                        HStack(spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: "film.fill")
                                Text(activeScene.title)
                            }
                            .font(.system(size: 11, weight: .bold))
                            .padding(.horizontal, 8).padding(.vertical, 4)
                            .background(Color.black.opacity(0.7))
                            .foregroundColor(.white)
                            .cornerRadius(4)
                            
                            if let meta = activeScene.animationMeta, !meta.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: isPlaying ? "film.circle.fill" : "film.fill")
                                        .foregroundColor(isPlaying ? .yellow : .purple)
                                    Text("🎬 \(meta)")
                                        .fontWeight(.bold)
                                    if isPlaying {
                                        Text(String(format: "(%04.1fs / %04.1fs)", sceneElapsed, sceneDur))
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundColor(.white.opacity(0.9))
                                    }
                                }
                                .font(.system(size: 10, weight: .semibold))
                                .padding(.horizontal, 7).padding(.vertical, 3)
                                .background(Color.black.opacity(0.7))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                            }
                            
                            Spacer()
                            
                            Text("1920x1080 60fps")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .padding(.horizontal, 6).padding(.vertical, 3)
                                .background(Color.accentColor.opacity(0.85))
                                .foregroundColor(.white)
                                .cornerRadius(4)
                        }
                        Spacer()
                    }
                    .padding(12)
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "film")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.6))
                        Text("プレビュー: \(scenes.indices.contains(selectedSceneIndex) ? scenes[selectedSceneIndex] : currentFileName)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
            }
        }
    }

    
    // 下部タイムラインバー（二段トラック連動）
    private var timelineBottomBar: some View {
        VStack(spacing: 4) {
            // ステータス表示
            HStack(spacing: 8) {
                Text(String(format: "%02d:%02d / %02d:%02d", Int(currentTime)/60, Int(currentTime)%60, Int(duration)/60, Int(duration)%60))
                    .font(.caption2)
                    .monospacedDigit()
                
                Divider().frame(height: 12)
                
                if movieScenes.indices.contains(activeSceneIndex) {
                    let activeSc = movieScenes[activeSceneIndex]
                    HStack(spacing: 4) {
                        Image(systemName: "film")
                            .font(.system(size: 9))
                        Text("現在: 第\(activeSceneIndex + 1)幕 \(activeSc.title)")
                            .font(.caption2)
                            .lineLimit(1)
                    }
                    .foregroundColor(.primary)
                }
                
                if let matchingAudio = audioItems.first(where: { $0.targetSceneIndex == activeSceneIndex }) {
                    HStack(spacing: 4) {
                        Image(systemName: "waveform")
                            .font(.system(size: 9))
                        Text(matchingAudio.audioFileName)
                            .font(.system(size: 10, design: .monospaced))
                            .lineLimit(1)
                    }
                    .foregroundColor(.green)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(3)
                }
                
                Spacer()
                
                Text("タイムライン (二段トラック分離表示)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            // 二段ミニトラック表示 (上段: 映像シーン / 下段: 音声トラック)
            VStack(spacing: 2) {
                // 上段: 映像トラック
                GeometryReader { geo in
                    let totalWidth = geo.size.width
                    HStack(spacing: 1) {
                        ForEach(movieScenes.indices, id: \.self) { idx in
                            let sc = movieScenes[idx]
                            let wRatio = duration > 0 ? (sc.duration / duration) : (1.0 / Double(max(1, movieScenes.count)))
                            let width = max(4.0, totalWidth * CGFloat(wRatio) - 1.0)
                            Rectangle()
                                .fill(activeSceneIndex == idx ? Color.accentColor : Color.blue.opacity(0.55))
                                .frame(width: width, height: 6)
                                .cornerRadius(1)
                                .onTapGesture {
                                    seekToScene(index: idx)
                                }
                        }
                    }
                }
                .frame(height: 6)
                
                // 下段: 音声トラック
                GeometryReader { geo in
                    let totalWidth = geo.size.width
                    HStack(spacing: 1) {
                        if audioItems.isEmpty {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.15))
                                .frame(height: 5)
                                .cornerRadius(1)
                        } else {
                            ForEach(audioItems.indices, id: \.self) { aIdx in
                                let item = audioItems[aIdx]
                                let wRatio = duration > 0 ? (item.duration / duration) : (1.0 / Double(max(1, audioItems.count)))
                                let width = max(4.0, totalWidth * CGFloat(wRatio) - 1.0)
                                Rectangle()
                                    .fill(item.isMuted ? Color.gray.opacity(0.5) : (selectedAudioIndex == aIdx ? Color.green : Color.green.opacity(0.65)))
                                    .frame(width: width, height: 5)
                                    .cornerRadius(1)
                                    .onTapGesture {
                                        currentTime = item.startTime
                                        selectedAudioIndex = aIdx
                                    }
                            }
                        }
                    }
                }
                .frame(height: 5)
            }
            .padding(.horizontal)
            
            Slider(value: $currentTime, in: 0...duration)
                .padding(.horizontal)
                .padding(.bottom, 6)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    // MARK: - 4. 書き出し画面 (仕様書 P.165)
    private var exportView: some View {
        VStack(spacing: 24) {
            HStack {
                Button(action: { screenMode = .editor }) {
                    Label("エディタに戻る", systemImage: "chevron.backward")
                }
                .buttonStyle(.bordered)
                Spacer()
                Text("編集ファイルを書き出し… (P.165)")
                    .font(.headline)
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            
            VStack(alignment: .leading, spacing: 18) {
                // 保存先
                VStack(alignment: .leading, spacing: 6) {
                    Text("書き出し先を選択 (P.165)").font(.subheadline).fontWeight(.bold)
                    Picker("保存先", selection: $exportDestination) {
                        Text("ローカルストレージ").tag("ローカルストレージ")
                        Text("素材スタジオ").tag("素材スタジオ")
                        Text("NanndemoyaCloud").tag("NanndemoyaCloud")
                    }
                    .pickerStyle(.segmented)
                }
                
                // 形式
                VStack(alignment: .leading, spacing: 6) {
                    Text("対応拡張子 (P.153)").font(.subheadline).fontWeight(.bold)
                    Picker("拡張子", selection: $exportFormat) {
                        Text("mp4 (標準)").tag("mp4")
                        Text("ymmp (ゆっくりムービーメーカー4互換)").tag("ymmp")
                        Text("gvid (GoogleVids / アプリ拡張対応)").tag("gvid")
                    }
                    .pickerStyle(.segmented)
                }
                
                // ファイル名
                VStack(alignment: .leading, spacing: 6) {
                    Text("ファイル名").font(.subheadline).fontWeight(.bold)
                    TextField("ファイル名", text: $exportFileName)
                        .textFieldStyle(.roundedBorder)
                }
                
                // 有料機能: 詳細設定
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "sparkles").foregroundColor(.yellow)
                        Text("書き出しの詳細設定（有料機能）- FinalCutPro & PremierPro準拠").font(.caption).fontWeight(.bold)
                    }
                    Text("FinalCutProやPremierPro準拠の書き出し設定で書き出しできます。画質・ビットレート・ProResコーデック等の最適化におすすめ。")
                        .font(.caption2).foregroundColor(.secondary)
                    
                    Picker("画質設定", selection: $exportQuality) {
                        Text("1080p 60fps (高画質)").tag("1080p 60fps (高画質)")
                        Text("4K 60fps (最高画質)").tag("4K 60fps (最高画質)")
                        Text("Apple ProRes 422 (業務用)").tag("Apple ProRes 422 (業務用)")
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.08))
                .cornerRadius(8)
                
                Button(action: executeExport) {
                    HStack {
                        Spacer()
                        Label(isExporting ? "書き出し中…" : "書き出しを実行する", systemImage: "square.and.arrow.up.fill")
                            .font(.headline)
                        Spacer()
                    }
                    .padding()
                }
                .disabled(isExporting)
                .buttonStyle(.borderedProminent)
            }
            .frame(maxWidth: 500)
            
            Spacer()
        }
            .onAppear {
            syncExportFileNameFromEditingFile()
        }
    }
    
    private func startLoading(msg: String) {
        loadingMessage = msg
        loadingProgress = 0.2
        screenMode = .loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            loadingProgress = 1.0
            screenMode = .editor
        }
    }
    
    // MARK: - 音声再生・試聴ヘルパー
    private func playAudio(path: String, volume: Double = 1.0, playbackRate: Double = 1.0, isReversed: Bool = false, loops: Bool = false) {
        guard FileManager.default.fileExists(atPath: path) else { return }
        let url = URL(fileURLWithPath: path)
        do {
            audioPlayer?.stop()
            let p: AVAudioPlayer
            if isReversed {
                if let revData = AudioProcessingUtility.reverseAudio(from: url) {
                    p = try AVAudioPlayer(data: revData)
                } else {
                    p = try AVAudioPlayer(contentsOf: url)
                }
            } else {
                p = try AVAudioPlayer(contentsOf: url)
            }
            p.enableRate = true
            let rate = Float(max(0.25, min(4.0, playbackRate == 0 ? 1.0 : playbackRate)))
            p.rate = rate
            p.volume = Float(max(0.0, min(1.0, volume)))
            p.numberOfLoops = loops ? -1 : 0
            p.prepareToPlay()
            p.play()
            audioPlayer = p
        } catch {
            print("Audio playback error: \(error)")
        }
    }
    
    private func stopAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
        for (_, p) in bgmSePlayers {
            p.stop()
        }
        bgmSePlayers.removeAll()
        playingAudioSceneIndex = nil
        playingAudioItemIndex = nil
    }
    
    /// シーン番号に対応するセリフ音声＋該当シーン範囲内（startSceneIndex...endSceneIndex）のBGM/SEをすべて同時再生する
    private func playSceneAudios(sceneIndex: Int) {
        stopAudio()
        guard movieScenes.indices.contains(sceneIndex) else { return }
        
        // 1. セリフ音声の再生
        if let matchingVoice = audioItems.first(where: {
            ($0.targetSceneIndex == sceneIndex || $0.startSceneIndex == sceneIndex) && $0.isVoice && !$0.isMuted
        }) {
            playAudio(
                path: matchingVoice.audioPath,
                volume: matchingVoice.volume,
                playbackRate: matchingVoice.playbackRate,
                isReversed: matchingVoice.isReversed,
                loops: matchingVoice.loops
            )
        } else if let path = movieScenes[sceneIndex].audioPath, FileManager.default.fileExists(atPath: path) {
            if let matchingItem = audioItems.first(where: { $0.audioPath == path || $0.targetSceneIndex == sceneIndex }) {
                playAudio(
                    path: path,
                    volume: matchingItem.volume,
                    playbackRate: matchingItem.playbackRate,
                    isReversed: matchingItem.isReversed,
                    loops: matchingItem.loops
                )
            } else {
                playAudio(path: path)
            }
        }
        
        // 2. 該当シーンで有効なBGMおよび効果音をすべて同時再生
        let activeBgmSe = audioItems.filter { item in
            guard !item.isVoice && !item.isMuted else { return false }
            let s = item.startSceneIndex ?? item.targetSceneIndex ?? -1
            let e = item.endSceneIndex ?? s
            return s <= sceneIndex && sceneIndex <= e
        }
        
        for item in activeBgmSe {
            guard FileManager.default.fileExists(atPath: item.audioPath) else { continue }
            let url = URL(fileURLWithPath: item.audioPath)
            let p: AVAudioPlayer?
            if item.isReversed {
                if let revData = AudioProcessingUtility.reverseAudio(from: url) {
                    p = try? AVAudioPlayer(data: revData)
                } else {
                    p = try? AVAudioPlayer(contentsOf: url)
                }
            } else {
                p = try? AVAudioPlayer(contentsOf: url)
            }
            if let p {
                p.enableRate = true
                p.rate = Float(max(0.25, min(4.0, item.playbackRate == 0 ? 1.0 : item.playbackRate)))
                p.volume = Float(max(0.0, min(1.0, item.volume)))
                p.numberOfLoops = item.loops ? -1 : 0
                p.prepareToPlay()
                p.play()
                bgmSePlayers[item.id] = p
            }
        }
    }
    
    private func togglePlaySceneAudio(index: Int) {
        if playingAudioSceneIndex == index {
            stopAudio()
            return
        }
        guard movieScenes.indices.contains(index) else { return }
        stopAudio()
        playingAudioSceneIndex = index
        playSceneAudios(sceneIndex: index)
    }
    
    private func togglePlayAudioItem(index: Int) {
        if playingAudioItemIndex == index {
            stopAudio()
            return
        }
        guard audioItems.indices.contains(index) else { return }
        stopAudio()
        playingAudioItemIndex = index
        let item = audioItems[index]
        playAudio(
            path: item.audioPath,
            volume: item.volume,
            playbackRate: item.playbackRate,
            isReversed: item.isReversed,
            loops: item.loops
        )
    }
    
    // MARK: - シーン（画像・テロップ）操作ヘルパー
    private func playScenePreview(index: Int) {
        guard movieScenes.indices.contains(index) else { return }
        stopAudio()
        
        var acc = 0.0
        for i in 0..<index {
            acc += effectiveSceneDuration(at: i)
        }
        currentTime = min(duration, acc)
        selectedSceneIndex = index
        let sceneDur = effectiveSceneDuration(at: index)
        
        singleScenePreviewIndex = index
        singleScenePreviewEndTime = acc + sceneDur
        lastPlayedSceneIndexDuringPlayback = index
        
        playSceneAudios(sceneIndex: index)
        beginPlaybackClock()
    }
    
    private func seekToScene(index: Int) {
        guard movieScenes.indices.contains(index) else { return }
        selectedSceneIndex = index
        var acc = 0.0
        for i in 0..<index {
            acc += effectiveSceneDuration(at: i)
        }
        currentTime = min(duration, acc)
        stopAudio()
    }
    
    private func addSingleScene() {
        let newIdx = movieScenes.count + 1
        let newScene = MovieSceneData(
            title: "新規スライド \(newIdx)",
            duration: 10.0,
            scriptText: "霊夢: 「ここにセリフやテロップを入力してください。」"
        )
        movieScenes.append(newScene)
        updateSceneNames()
        recalculateTotalDuration()
        state.notify(title: "シーン追加", message: "「第\(newIdx)幕」を追加しました。")
    }
    
    private func removeScene(at index: Int) {
        guard movieScenes.indices.contains(index) else { return }
        let removedTitle = movieScenes[index].title
        movieScenes.remove(at: index)
        // 割り当てられていた音声のtargetSceneIndexを再調整
        for i in audioItems.indices {
            if let tIdx = audioItems[i].targetSceneIndex {
                if tIdx == index {
                    audioItems[i].targetSceneIndex = nil
                } else if tIdx > index {
                    audioItems[i].targetSceneIndex = tIdx - 1
                }
            }
        }
        if selectedSceneIndex >= movieScenes.count {
            selectedSceneIndex = max(0, movieScenes.count - 1)
        }
        updateSceneNames()
        recalculateTotalDuration()
        state.notify(title: "シーン削除", message: "「\(removedTitle)」を削除しました。")
    }
    
    private func changeSceneImage(index: Int) {
        guard movieScenes.indices.contains(index) else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .png, .jpeg]
        panel.allowsMultipleSelection = false
        panel.message = "第\(index + 1)幕（\(movieScenes[index].title)）のスライド画像を選択してください"
        if panel.runModal() == .OK, let url = panel.url {
            movieScenes[index].imagePath = url.path
            state.notify(title: "画像更新", message: "第\(index + 1)幕の画像を「\(url.lastPathComponent)」に変更しました。")
        }
    }
    
    // MARK: - 音声ファイル管理ヘルパー
    private func addSingleAudioFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio, .wav, .mp3, .mpeg4Audio]
        panel.directoryURL = ProjectStorageManager.shared.folderURL(for: .sound)
        panel.message = "追加する音声ファイルを選択してください"
        if panel.runModal() == .OK, let url = panel.url {
            let dur = SlideAudioMatcher.getAudioDuration(url: url) ?? 10.0
            let slideIdx = SlideAudioMatcher.extractSlideIndex(from: url.lastPathComponent)
            var targetIdx: Int? = nil
            var startT: Double = 0.0
            if let sIdx = slideIdx, sIdx >= 1, sIdx <= movieScenes.count {
                targetIdx = sIdx - 1
                startT = getSceneStartTime(sceneIndex: sIdx - 1)
            }
            let newAudio = MovieAudioData(
                name: url.lastPathComponent,
                audioPath: url.path,
                audioFileName: url.lastPathComponent,
                duration: dur,
                startTime: startT,
                targetSceneIndex: targetIdx,
                targetSceneId: targetIdx != nil ? movieScenes[targetIdx!].id : nil,
                volume: 1.0,
                speakerCharacter: targetIdx != nil ? movieScenes[targetIdx!].speakerCharacter : nil,
                isMuted: false
            )
            audioItems.append(newAudio)
            if let tIdx = targetIdx {
                movieScenes[tIdx].audioPath = url.path
                movieScenes[tIdx].audioFileName = url.lastPathComponent
                movieScenes[tIdx].audioDuration = dur
                updateSceneNames()
            }
            state.notify(title: "音声追加完了", message: "音声ファイル「\(url.lastPathComponent)」を追加しました。")
        }
    }
    
    private func removeAudioItem(at index: Int) {
        guard audioItems.indices.contains(index) else { return }
        let removed = audioItems[index]
        audioItems.remove(at: index)
        if let sIdx = removed.targetSceneIndex, movieScenes.indices.contains(sIdx) {
            movieScenes[sIdx].audioPath = nil
            movieScenes[sIdx].audioFileName = nil
            movieScenes[sIdx].audioDuration = nil
            updateSceneNames()
        }
        if selectedAudioIndex >= audioItems.count {
            selectedAudioIndex = max(0, audioItems.count - 1)
        }
        state.notify(title: "音声削除", message: "「\(removed.audioFileName)」をリストから削除しました。")
    }
    
    private func realignAudioItemsToScenes() {
        var count = 0
        for i in audioItems.indices {
            let rawName = audioItems[i].audioFileName
            if let sNum = SlideAudioMatcher.extractSlideIndex(from: rawName), sNum >= 1, sNum <= movieScenes.count {
                let targetIdx = sNum - 1
                audioItems[i].targetSceneIndex = targetIdx
                audioItems[i].targetSceneId = movieScenes[targetIdx].id
                audioItems[i].startTime = getSceneStartTime(sceneIndex: targetIdx)
                movieScenes[targetIdx].audioPath = audioItems[i].audioPath
                movieScenes[targetIdx].audioFileName = audioItems[i].audioFileName
                movieScenes[targetIdx].audioDuration = audioItems[i].duration
                count += 1
            }
        }
        updateSceneNames()
        state.notify(title: "自動再整列完了", message: "\(count)個の音声ファイルをスライド番号に従って再整列しました。")
    }
    
    private func syncAudioToScene(audioIndex: Int) {
        guard audioItems.indices.contains(audioIndex) else { return }
        let audio = audioItems[audioIndex]
        if let sIdx = audio.targetSceneIndex, movieScenes.indices.contains(sIdx) {
            audioItems[audioIndex].startTime = getSceneStartTime(sceneIndex: sIdx)
            audioItems[audioIndex].targetSceneId = movieScenes[sIdx].id
            movieScenes[sIdx].audioPath = audio.audioPath
            movieScenes[sIdx].audioFileName = audio.audioFileName
            movieScenes[sIdx].audioDuration = audio.duration
            if !audio.isMuted {
                movieScenes[sIdx].duration = max(movieScenes[sIdx].duration, audio.effectivePlaybackDuration)
            }
        }
        updateSceneNames()
        recalculateTotalDuration()
    }
    
        private func getSceneStartTime(sceneIndex: Int) -> Double {
        sceneStartTime(at: sceneIndex)
    }
    
    private func updateSceneNames() {
        self.scenes = self.movieScenes.enumerated().map { idx, sc in
            var text = "第\(idx + 1)幕: \(sc.title)"
            if let meta = sc.animationMeta, !meta.isEmpty {
                text += " (🎬 \(meta))"
            } else {
                text += " (🎬 \(String(format: "%.1f", sc.duration))秒)"
            }
            if sc.audioPath != nil || audioItems.contains(where: { $0.targetSceneIndex == idx }) {
                text += " 🎵"
            }
            return text
        }
    }
    
    private func recalculateTotalDuration() {
        var newDur = 0.0
        for i in movieScenes.indices {
            newDur += effectiveSceneDuration(at: i)
        }
        self.duration = max(10.0, newDur)
    }
    
    // MARK: - 作成済み音声フォルダ一括割り当て（ファイル名で同一スライドを自動判定・分離音声トラック生成）
    private func batchAssignAudioFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = ProjectStorageManager.shared.folderURL(for: .sound)
        panel.message = "スライドに割り当てる音声ファイル（WAV等）が格納されたフォルダを選択してください"
        panel.prompt = "フォルダを選択して一括割当"
        
        if panel.runModal() == .OK, let folderURL = panel.url {
            let audioFiles = SlideAudioMatcher.scanAudioFolder(folderURL: folderURL)
            if audioFiles.isEmpty {
                state.notify(
                    title: "音声ファイルなし",
                    message: "選択されたフォルダ「\(folderURL.lastPathComponent)」内に対応する音声ファイル（.wav, .mp3等）が見つかりませんでした。"
                )
                return
            }
            
            let itemScenes = self.movieScenes.map { $0.toItemData() }
            let (newAudioItems, updatedScenes, matchedCount, totalSec) = SlideAudioMatcher.createAudioItemsFromFiles(
                audioFiles: audioFiles,
                scenes: itemScenes,
                syncSceneDuration: true
            )
            
            self.movieScenes = updatedScenes.map { MovieSceneData(item: $0) }
            self.audioItems = newAudioItems.map { MovieAudioData(item: $0) }
            updateSceneNames()
            recalculateTotalDuration()
            
            state.notify(
                title: "音声一括割り当て完了",
                message: "フォルダ「\(folderURL.lastPathComponent)」から、全\(newAudioItems.count)個の音声ファイルを分離管理トラックに取り込み、全\(movieScenes.count)シーン中 \(matchedCount)個に自動対応付けしました！\n合計音声時間: \(String(format: "%.1f", totalSec))秒"
            )
        }
    }
    
    // スライド個別音声指定
    private func assignSingleAudio(index: Int) {
        guard movieScenes.indices.contains(index) else { return }
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.audio, .wav, .mp3, .mpeg4Audio]
        panel.directoryURL = ProjectStorageManager.shared.folderURL(for: .sound)
        panel.message = "第\(index + 1)幕（\(movieScenes[index].title)）に割り当てる音声ファイルを選択してください"
        if panel.runModal() == .OK, let url = panel.url {
            let dur = SlideAudioMatcher.getAudioDuration(url: url) ?? 10.0
            movieScenes[index].audioPath = url.path
            movieScenes[index].audioFileName = url.lastPathComponent
            movieScenes[index].audioDuration = dur
            let animDur = movieScenes[index].animationDuration ?? (movieScenes[index].animationMeta.flatMap { FileFormatParser.extractDurationFromMeta($0) } ?? 0.0)
            let baseDur = max(movieScenes[index].duration, animDur)
            movieScenes[index].duration = max(baseDur, dur + 0.3)
            if movieScenes[index].animationDuration == nil && animDur > 0 {
                movieScenes[index].animationDuration = animDur
            }
            
            let startT = getSceneStartTime(sceneIndex: index)
            if let existingIdx = audioItems.firstIndex(where: { $0.targetSceneIndex == index }) {
                audioItems[existingIdx].audioPath = url.path
                audioItems[existingIdx].audioFileName = url.lastPathComponent
                audioItems[existingIdx].duration = dur
                audioItems[existingIdx].startTime = startT
            } else {
                let newAudio = MovieAudioData(
                    name: url.lastPathComponent,
                    audioPath: url.path,
                    audioFileName: url.lastPathComponent,
                    duration: dur,
                    startTime: startT,
                    targetSceneIndex: index,
                    targetSceneId: movieScenes[index].id,
                    volume: 1.0,
                    speakerCharacter: movieScenes[index].speakerCharacter,
                    isMuted: false
                )
                audioItems.append(newAudio)
            }
            
            updateSceneNames()
            recalculateTotalDuration()
            state.notify(title: "音声割り当て完了", message: "第\(index + 1)幕に「\(url.lastPathComponent)」を割り当てました。")
        }
    }
    
    // MARK: - サウンドメーカー（.tssm）プロジェクト読み込み・全機能自動割り振り
    private func loadTssmFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json, .data]
        panel.directoryURL = ProjectStorageManager.shared.folderURL(for: .sound)
        panel.allowsOtherFileTypes = true
        panel.message = "サウンドメーカープロジェクト（.tssm）を選択してください"
        panel.prompt = "サウンドプロジェクトを読込"
        if panel.runModal() == .OK, let url = panel.url {
            applyTssmFile(url: url)
        }
    }
    
    private func applyTssmFile(url: URL) {
        let existingItemScenes = self.movieScenes.map { $0.toItemData() }
        guard let result = SoundProjectImporter.importSoundProject(url: url, existingScenes: existingItemScenes) else {
            state.notify(title: "読込失敗", message: "「\(url.lastPathComponent)」は有効なサウンドメーカーファイルではありませんでした。")
            return
        }
        
        self.associatedSoundProjectName = result.soundProjectName
        self.movieScenes = result.updatedScenes.map { MovieSceneData(item: $0) }
        self.audioItems = result.audioItems.map { MovieAudioData(item: $0) }
        updateSceneNames()
        recalculateTotalDuration()
        self.currentTime = 0.0
        self.selectedSceneIndex = 0
        self.managementTab = .audioFiles
        
        startLoading(msg: "サウンドメーカー「\(url.lastPathComponent)」から全音声・BGM・効果音を取り込み中…")
        state.notify(
            title: "サウンド読込完了",
            message: "「\(url.lastPathComponent)」から全オーディオを取り込みました！\n・🎙️ セリフ音声: \(result.voiceCount)件\n・🎵 BGM: \(result.bgmCount)件\n・⚡ 効果音: \(result.seCount)件（音量・速度・逆再生設定を含む）\n・合計音声時間: \(String(format: "%.1f", result.totalAudioDuration))秒"
        )
    }

    // MARK: - プロジェクト保存機能（リポジトリルートのProjectsフォルダ連携・完全メタデータ保存・画像/テロップと音声の分離永続化）
    private func saveProject(asNew: Bool = false) {
        let project = MovieProjectData(
            projectName: currentFileName,
            duration: duration,
            scenes: scenes,
            fps: 60.0,
            resolution: "1920x1080",
            scenesData: self.movieScenes.map { $0.toItemData() },
            audioItems: self.audioItems.map { $0.toItemData() },
            soundProjectName: self.associatedSoundProjectName
        )
        
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(project) else {
            state.notify(title: "保存エラー", message: "プロジェクトデータのシリアライズに失敗しました。")
            return
        }
        
        if asNew || currentFileURL == nil {
            let savePanel = NSSavePanel()
            savePanel.directoryURL = ProjectStorageManager.shared.folderURL(for: .movie)
            var defaultName = currentFileName
            if !defaultName.hasSuffix(".tsvm") {
                defaultName = defaultName.replacingOccurrences(of: "\.[a-zA-Z0-9]+$", with: "", options: .regularExpression) + ".tsvm"
            }
            savePanel.nameFieldStringValue = defaultName
            savePanel.message = "ムービーメーカープロジェクト（.tsvm）をリポジトリのProjectsフォルダに保存します"
            savePanel.prompt = "保存"
            
            if savePanel.runModal() == .OK, let url = savePanel.url {
                do {
                    try data.write(to: url, options: .atomic)
                    self.currentFileURL = url
                    self.currentFileName = url.lastPathComponent
                    syncExportFileNameFromEditingFile()
                    state.notifyProjectSaved(fileName: currentFileName, fileURL: url, editor: .movie, sceneCount: scenes.count)
                } catch {
                    state.notify(title: "保存失敗", message: "ファイルの書き込み中にエラーが発生しました: \(error.localizedDescription)")
                }
            }
        } else if let targetURL = currentFileURL {
            // 上書き保存
            do {
                try data.write(to: targetURL, options: .atomic)
                state.notifyProjectSaved(fileName: currentFileName, fileURL: targetURL, editor: .movie, sceneCount: scenes.count)
            } catch {
                state.notify(title: "保存失敗", message: "ファイルの書き込み中にエラーが発生しました: \(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 統合スライド＆シナリオ読み込みメソッド（.tspm, .key, .pptx, .csv, .txt 等に対応）
    private func loadSlideScenarioURL(url: URL) {
        let ext = url.pathExtension.lowercased()
        let fileName = url.lastPathComponent
        
        if ext == "key" {
            startLoading(msg: "Keynote「\(fileName)」からスライド＆アニメーションを解析中…")
            DispatchQueue.global(qos: .userInitiated).async {
                let parsedSlides = FileFormatParser.parseKeynoteToSlides(fileURL: url)
                DispatchQueue.main.async {
                    self.applySlidesToMovie(slides: parsedSlides, sourceName: fileName, fileURL: url)
                }
            }
        } else if ext == "pptx" {
            startLoading(msg: "PowerPoint「\(fileName)」からスライドを解析中…")
            DispatchQueue.global(qos: .userInitiated).async {
                let parsedSlides = FileFormatParser.parsePowerPointToSlides(fileURL: url)
                DispatchQueue.main.async {
                    self.applySlidesToMovie(slides: parsedSlides, sourceName: fileName, fileURL: url)
                }
            }
        } else if ext == "tspm" || ext == "json" {
            if let data = try? Data(contentsOf: url),
               let project = SlideScenarioProjectData.loadProject(from: data) {
                applySlidesToMovie(slides: project.slides, sourceName: fileName, fileURL: url)
            } else if let content = try? String(contentsOf: url, encoding: .utf8) {
                let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
                if (trimmed.hasPrefix("{") || trimmed.hasPrefix("[")),
                   let data = trimmed.data(using: .utf8),
                   let project = SlideScenarioProjectData.loadProject(from: data) {
                    applySlidesToMovie(slides: project.slides, sourceName: fileName, fileURL: url)
                } else if trimmed.hasPrefix("{") || trimmed.hasPrefix("[") {
                    state.notify(title: "スライド読込エラー", message: "「\(fileName)」のJSON構文をスライドデータとして復元できませんでした。")
                } else {
                    let parsed = FileFormatParser.parseTextOrMarkdownToSlides(content: content, defaultTitle: url.deletingPathExtension().lastPathComponent)
                    applySlidesToMovie(slides: parsed, sourceName: fileName, fileURL: url)
                }
            } else {
                state.notify(title: "読込失敗", message: "「\(fileName)」を開くことができませんでした。")
            }
        } else if ext == "csv" {
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                let parsed = FileFormatParser.parseCSVToSlides(content: content)
                applySlidesToMovie(slides: parsed, sourceName: fileName, fileURL: url)
            }
        } else if let content = try? String(contentsOf: url, encoding: .utf8) {
            let parsed = FileFormatParser.parseTextOrMarkdownToSlides(content: content, defaultTitle: url.deletingPathExtension().lastPathComponent)
            applySlidesToMovie(slides: parsed, sourceName: fileName, fileURL: url)
        }
    }
    
    // スライド＆シナリオファイル読み込み
    private func loadSlideScenarioFile() {
        let panel = NSOpenPanel()
        var types: [UTType] = [.json, .text, .data]
        if let tspmType = UTType(filenameExtension: "tspm") { types.append(tspmType) }
        if let keyType = UTType(filenameExtension: "key") { types.append(keyType) }
        if let pptxType = UTType(filenameExtension: "pptx") { types.append(pptxType) }
        panel.allowedContentTypes = types
        panel.directoryURL = ProjectStorageManager.shared.folderURL(for: .slideScenario)
        panel.allowsOtherFileTypes = true
        panel.message = "スライド＆シナリオ・Keynote・PowerPointファイル（.tspm, .key, .pptx, .txt）を選択してください"
        if panel.runModal() == .OK, let url = panel.url {
            loadSlideScenarioURL(url: url)
        }
    }
    
    // Keynote (GUIアニメ抽出) 読み込み
    private func loadKeynoteWithGUI() {
        let panel = NSOpenPanel()
        if let keyType = UTType(filenameExtension: "key") {
            panel.allowedContentTypes = [keyType, .data]
        }
        panel.directoryURL = ProjectStorageManager.shared.folderURL(for: .slideScenario)
        panel.allowsOtherFileTypes = true
        panel.message = "Keynoteファイルを選択してください（※実行中にKeynoteが自動操作されます）"
        if panel.runModal() == .OK, let url = panel.url {
            let fileName = url.lastPathComponent
            startLoading(msg: "Keynote「\\(fileName)」をGUI操作で解析中…")
            DispatchQueue.global(qos: .userInitiated).async {
                let parsedSlides = FileFormatParser.parseKeynoteWithGUIScripting(fileURL: url)
                DispatchQueue.main.async {
                    self.applySlidesToMovie(slides: parsedSlides, sourceName: fileName, fileURL: url)
                }
            }
        }
    }
    
    private func applySlidesToMovie(slides: [SlideItemData], sourceName: String, fileURL: URL? = nil) {
        guard !slides.isEmpty else {
            self.scenes = ["第1幕: スライドインポート"]
            self.movieScenes = [MovieSceneData(title: "スライドインポート", duration: 10.0)]
            self.duration = 10.0
            self.currentTime = 0.0
            self.selectedSceneIndex = 0
            self.screenMode = .editor
            return
        }
        
        let cleanBase = sourceName
            .replacingOccurrences(of: "\.[a-zA-Z0-9]+$", with: "", options: .regularExpression)
            .precomposedStringWithCanonicalMapping
        
        // 1. 各スライドを MovieSceneItemData へ変換
        var initialItemScenes: [MovieSceneItemData] = []
        for (idx, slide) in slides.enumerated() {
            let extractedAnimDur = SlideAnimationKit.estimateDuration(
                meta: slide.animationMeta,
                noteDuration: slide.animationDuration ?? (slide.animationMeta.flatMap { FileFormatParser.extractDurationFromMeta($0) }),
                buildCount: SlideAnimationKit.parseRecipes(from: slide.animationMeta).count
            )
            let animDur = extractedAnimDur ?? 10.0
            
            var script = slide.pureScriptText ?? slide.noteScript
            var speaker = slide.speakerCharacter
            var meta = slide.animationMeta
            
            // noteScriptからメタ情報を再補完
            if !slide.noteScript.isEmpty {
                let parsed = FileFormatParser.parseNoteMeta(note: slide.noteScript)
                if speaker == nil || speaker?.isEmpty == true {
                    speaker = parsed.speaker
                }
                if script.isEmpty {
                    script = parsed.body.isEmpty ? slide.noteScript : parsed.body
                }
                if meta == nil || meta?.isEmpty == true {
                    meta = parsed.animMeta
                }
            }
            
            initialItemScenes.append(MovieSceneItemData(
                id: slide.id,
                title: slide.title.isEmpty ? "スライド \(idx + 1)" : slide.title,
                duration: animDur,
                imagePath: slide.imagePath,
                scriptText: script,
                speakerCharacter: speaker,
                animationMeta: meta,
                animationDuration: extractedAnimDur,
                backgroundImagePath: slide.backgroundImagePath,
                backgroundAnimation: slide.backgroundAnimation,
                characterImagePath: slide.characterImagePath,
                characterAnimation: slide.characterAnimation,
                objectsData: slide.objectsData,
                objectAnimation: slide.objectAnimation,
                telopText: slide.telopText ?? script,
                slideTransitionEffect: slide.slideTransitionEffect,
                slideTransitionDuration: slide.slideTransitionDuration
            ))
        }
        
        // 2. スライド画像の存在確認・キャッシュおよび同名Keynoteからの自動解決
        let resolvedItemScenes = SlideImageResolver.resolveSlideImages(
            scenes: initialItemScenes,
            projectName: cleanBase,
            projectURL: fileURL
        )
        
        self.movieScenes = resolvedItemScenes.map { MovieSceneData(item: $0) }
        
        // 3. 音声プロジェクト（.tssm）および音声フォルダの自動マッチング
        autoScanMatchingSoundProject(projectName: cleanBase)
        if self.audioItems.isEmpty {
            autoScanMatchingSoundFolder(projectName: cleanBase)
        }
        
        // 4. シーン名・合計時間の同期
        updateSceneNames()
        recalculateTotalDuration()
        
        self.currentTime = 0.0
        self.selectedSceneIndex = 0
        self.editorLayout = 5 // スライド＆シナリオメーカー連携レイアウトを表示
        
        // 5. プロジェクト名・書き出しデフォルトタイトル設定
        self.currentFileName = "\(cleanBase).tsvm"
        self.currentFileURL = nil
        self.exportFileName = cleanBase
        
        let imageCount = self.movieScenes.filter { $0.imagePath != nil && FileManager.default.fileExists(atPath: $0.imagePath!) }.count
        let imageNotice = imageCount > 0 ? "（画像有効: \(imageCount)/\(movieScenes.count)枚）" : ""
        let assignedAudioCount = self.audioItems.count
        let audioNotice = assignedAudioCount > 0 ? " / 音声: \(assignedAudioCount)個割当済" : ""
        
        startLoading(msg: "「\(sourceName)」から全\(movieScenes.count)個のシーンを取り込み中…")
        state.notify(
            title: "スライド読込完了",
            message: "「\(sourceName)」から全\(movieScenes.count)幕のシーンを取り込みました。\(imageNotice)\(audioNotice)\n合計時間: \(String(format: "%.1f", duration))秒"
        )
    }
    
    // YMM4プロジェクト読み込み
    private func loadYmmpFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json, .data]
        panel.directoryURL = ProjectStorageManager.shared.folderURL(for: .movie)
        panel.allowsOtherFileTypes = true
        panel.message = "ゆっくりムービーメーカー4ファイル（.ymmp）を選択してください"
        if panel.runModal() == .OK, let url = panel.url {
            currentFileName = url.lastPathComponent
            currentFileURL = url
            syncExportFileNameFromEditingFile()
            if let content = try? String(contentsOf: url, encoding: .utf8) {
                let parsed = FileFormatParser.parseYmmpScenes(content: content)
                self.scenes = parsed.scenes
                self.duration = parsed.duration
                self.movieScenes = parsed.scenes.enumerated().map { idx, name in
                    MovieSceneData(title: name, duration: parsed.duration / Double(max(1, parsed.scenes.count)))
                }
            }
            startLoading(msg: "ゆっくりムービーメーカー「\(url.lastPathComponent)」を変換インポート中…")
            state.notify(title: "YMM4読込完了", message: "YMM4タイムラインから\(scenes.count)個のシーンを復元しました。")
        }
    }
    
    // 既存tsvmファイル読み込み（スライド画像自動解決・音声自動復元対応）
    private func loadExistingTsvmFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json, .data]
        panel.directoryURL = ProjectStorageManager.shared.folderURL(for: .movie)
        panel.allowsOtherFileTypes = true
        panel.message = "ムービーメーカープロジェクト（.tsvm）を選択してください"
        if panel.runModal() == .OK, let url = panel.url {
            applyTsvmFile(url: url)
        }
    }
    
    // 編集画面ツールバーからの読み込み
    private func openFileInEditor() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json, .data, .movie, .text]
        panel.directoryURL = ProjectStorageManager.shared.folderURL(for: .movie)
        panel.allowsOtherFileTypes = true
        panel.message = "追加・置換するプロジェクトまたは素材ファイルを選択してください"
        if panel.runModal() == .OK, let url = panel.url {
            let ext = url.pathExtension.lowercased()
            if ext == "tsvm" {
                applyTsvmFile(url: url)
            } else if ext == "tssm" {
                applyTssmFile(url: url)
            } else if ext == "ymmp" {
                currentFileURL = url
                currentFileName = url.lastPathComponent
                if let content = try? String(contentsOf: url, encoding: .utf8) {
                    let parsed = FileFormatParser.parseYmmpScenes(content: content)
                    self.scenes = parsed.scenes
                    self.duration = parsed.duration
                    self.movieScenes = parsed.scenes.map { MovieSceneData(title: $0, duration: parsed.duration / Double(max(1, parsed.scenes.count))) }
                }
                state.notify(title: "YMM4読込完了", message: "「\(url.lastPathComponent)」を反映しました。")
            } else if ext == "tspm" || ext == "key" || ext == "pptx" || ext == "csv" || ext == "txt" || ext == "md" {
                loadSlideScenarioURL(url: url)
            } else {
                currentFileURL = url
                currentFileName = url.lastPathComponent
                self.scenes.append("新規シーン: \(url.deletingPathExtension().lastPathComponent)")
                self.movieScenes.append(MovieSceneData(title: url.deletingPathExtension().lastPathComponent, duration: 10.0))
                state.notify(title: "素材・プロジェクト読込", message: "「\(url.lastPathComponent)」をエディタに反映しました。")
            }
        }
    }
    
    // MARK: - .tsvm ファイル適用（スライド画像・台本・音声の完全自動復元・分離管理トラック展開）
    private func applyTsvmFile(url: URL) {
        let ext = url.pathExtension.lowercased()
        if ext == "tspm" || ext == "key" || ext == "pptx" || ext == "csv" {
            loadSlideScenarioURL(url: url)
            return
        }
        
        currentFileName = url.lastPathComponent
        currentFileURL = url
        exportFileName = url.deletingPathExtension().lastPathComponent
        
        if let data = try? Data(contentsOf: url),
           let project = try? JSONDecoder().decode(MovieProjectData.self, from: data) {
            
            self.associatedSoundProjectName = project.soundProjectName
            
            var itemScenes: [MovieSceneItemData] = []
            if let saved = project.scenesData, !saved.isEmpty {
                itemScenes = saved
            } else {
                // 古い .tsvm: scenes 文字列からベースを生成
                itemScenes = project.scenes.enumerated().map { idx, scTitle in
                    var cleanTitle = scTitle.replacingOccurrences(of: "^第[0-9]+幕:\\s*", with: "", options: .regularExpression)
                    cleanTitle = cleanTitle.replacingOccurrences(of: "\\s*\\(🎬.*\\)$", with: "", options: .regularExpression)
                    cleanTitle = cleanTitle.replacingOccurrences(of: "\\s*🎵$", with: "", options: .regularExpression)
                    return MovieSceneItemData(
                        title: cleanTitle.isEmpty ? "スライド \(idx + 1)" : cleanTitle,
                        duration: project.duration / Double(max(1, project.scenes.count))
                    )
                }
            }
            
            // スライド画像および台本を自動解決・復元（同名tspmまたはKeynoteから）
            let resolvedItems = SlideImageResolver.resolveSlideImages(
                scenes: itemScenes,
                projectName: project.projectName.isEmpty ? url.lastPathComponent : project.projectName,
                projectURL: url
            )
            
            self.movieScenes = resolvedItems.map { MovieSceneData(item: $0) }
            
            // 分離された音声トラックの復元
            if let savedAudios = project.audioItems, !savedAudios.isEmpty {
                self.audioItems = savedAudios.map { MovieAudioData(item: $0) }
            } else {
                // 旧形式 .tsvm: scenesData から分離音声アイテムを自動抽出
                let extracted = SlideAudioMatcher.extractAudioItemsFromScenes(scenes: resolvedItems)
                self.audioItems = extracted.map { MovieAudioData(item: $0) }
            }
            
            // BGMまたは効果音が未割り当て、または関連.tssmが存在する場合に自動マージ
            let hasBgmOrSe = self.audioItems.contains(where: { $0.isBGM || $0.isSE })
            if !hasBgmOrSe {
                autoScanMatchingSoundProject(projectName: url.deletingPathExtension().lastPathComponent)
            }
            
            // それでも音声が未割り当ての場合、Projects/Sound 配下のフォルダから自動割り当てを試行
            if self.audioItems.isEmpty {
                autoScanMatchingSoundFolder(projectName: url.deletingPathExtension().lastPathComponent)
            }
            
            updateSceneNames()
            recalculateTotalDuration()
            self.currentTime = 0.0
            self.selectedSceneIndex = 0
            self.editorLayout = 5 // スライド＆シナリオメーカー連携レイアウトを表示
            
            let imageCount = self.movieScenes.filter { $0.imagePath != nil }.count
            let audioCount = self.audioItems.count
            let bgmCount = self.audioItems.filter { $0.isBGM }.count
            let seCount = self.audioItems.filter { $0.isSE }.count
            
            startLoading(msg: "プロジェクト「\(url.lastPathComponent)」を展開中… (画像: \(imageCount)/\(movieScenes.count)枚)")
            state.notify(
                title: "プロジェクト読込完了",
                message: "「\(url.lastPathComponent)」を展開しました。\n・既存シーン: 全\(movieScenes.count)幕 (画像\(imageCount)枚有効)\n・分離音声ファイル: 全\(audioCount)個 (セリフ: \(audioCount - bgmCount - seCount) / 🎵BGM: \(bgmCount) / ⚡SE: \(seCount))"
            )
        } else if let content = try? String(contentsOf: url, encoding: .utf8) {
            let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
            if (trimmed.hasPrefix("{") || trimmed.hasPrefix("[")),
               let data = content.data(using: .utf8),
               let project = SlideScenarioProjectData.loadProject(from: data) {
                applySlidesToMovie(slides: project.slides, sourceName: url.lastPathComponent, fileURL: url)
                return
            }
            let parsed = FileFormatParser.parseTextOrMarkdownToSlides(content: content, defaultTitle: url.deletingPathExtension().lastPathComponent)
            applySlidesToMovie(slides: parsed, sourceName: url.lastPathComponent, fileURL: url)
        }
    }
    
    // サウンドメーカープロジェクト（.tssm）の自動検出・統合
    private func autoScanMatchingSoundProject(projectName: String) {
        let soundDir = ProjectStorageManager.shared.folderURL(for: .sound)
        let normalizedProjectName = projectName.precomposedStringWithCanonicalMapping
        
        var candidateURLs: [URL] = []
        if let enumerator = FileManager.default.enumerator(at: soundDir, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            while let itemURL = enumerator.nextObject() as? URL {
                if itemURL.pathExtension.lowercased() == "tssm" {
                    candidateURLs.append(itemURL)
                }
            }
        }
        
        var matchedURL: URL? = nil
        for u in candidateURLs {
            let base = u.deletingPathExtension().lastPathComponent.precomposedStringWithCanonicalMapping
            if normalizedProjectName == base || normalizedProjectName.contains(base) || base.contains(normalizedProjectName) {
                matchedURL = u
                break
            }
            if normalizedProjectName.contains("21") && normalizedProjectName.contains("22") && base.contains("21.22") {
                matchedURL = u
                break
            }
        }
        
        if let targetURL = matchedURL {
            let itemScenes = self.movieScenes.map { $0.toItemData() }
            if let result = SoundProjectImporter.importSoundProject(url: targetURL, existingScenes: itemScenes) {
                self.associatedSoundProjectName = result.soundProjectName
                var mergedAudios = self.audioItems
                for newAudio in result.audioItems {
                    if newAudio.trackType != "voice" {
                        if !mergedAudios.contains(where: { $0.id == newAudio.id }) {
                            mergedAudios.append(MovieAudioData(item: newAudio))
                        }
                    } else if mergedAudios.isEmpty {
                        mergedAudios.append(MovieAudioData(item: newAudio))
                    }
                }
                self.audioItems = mergedAudios
                self.movieScenes = result.updatedScenes.map { MovieSceneData(item: $0) }
            }
        }
    }

    // サウンドフォルダ自動検出・割り当て（分離音声トラック生成）
    private func autoScanMatchingSoundFolder(projectName: String) {
        if !audioItems.isEmpty { return }
        
        let soundDir = ProjectStorageManager.shared.folderURL(for: .sound)
        let normalizedProjectName = projectName.precomposedStringWithCanonicalMapping
        
        if let enumerator = FileManager.default.enumerator(at: soundDir, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]) {
            while let itemURL = enumerator.nextObject() as? URL {
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: itemURL.path, isDirectory: &isDir), isDir.boolValue {
                    let folderName = itemURL.lastPathComponent.precomposedStringWithCanonicalMapping
                    let matchesProject = normalizedProjectName.contains(folderName) || folderName.contains(normalizedProjectName)
                    let matchesEpisode = (normalizedProjectName.contains("21") && normalizedProjectName.contains("22") && folderName.contains("21話22話"))
                    
                    if matchesProject || matchesEpisode {
                        let audioFiles = SlideAudioMatcher.scanAudioFolder(folderURL: itemURL)
                        if !audioFiles.isEmpty {
                            let itemScenes = self.movieScenes.map { $0.toItemData() }
                            let (newAudios, updated, count, _) = SlideAudioMatcher.createAudioItemsFromFiles(audioFiles: audioFiles, scenes: itemScenes, syncSceneDuration: true)
                            if count > 0 {
                                self.movieScenes = updated.map { MovieSceneData(item: $0) }
                                self.audioItems = newAudios.map { MovieAudioData(item: $0) }
                                updateSceneNames()
                                recalculateTotalDuration()
                                break
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func executeExport() {
        guard !isExporting else { return }

        let format = exportFormat.lowercased()
        if format != "mp4" {
            state.notify(
                title: "書き出し形式（未対応）",
                message: "現在 Mac で確実に再生できるのは mp4 のみです。拡張子を mp4 にして書き出してください。"
            )
            return
        }

        if !(exportDestination.contains("Projects") || exportDestination.contains("ローカル") || exportDestination.contains("リポジトリ")) {
            state.notify(
                title: "書き出し先（未接続）",
                message: "クラウド等への直接書き出しは未接続です。「リポジトリ (Projects/Movie)」またはローカルを選んでください。"
            )
            return
        }

        let scenesToExport = movieScenes
        guard !scenesToExport.isEmpty else {
            state.notify(title: "書き出し不可", message: "シーンがありません。プロジェクトを読み込んでから書き出してください。")
            return
        }

        let movieDir = ProjectStorageManager.shared.folderURL(for: .movie)
        let safeName = exportFileName
            .replacingOccurrences(of: "/", with: "／")
            .replacingOccurrences(of: ":", with: "：")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fileName = (safeName.isEmpty ? "書き出し動画" : safeName) + ".mp4"
        let fileURL = movieDir.appendingPathComponent(fileName)

        let inputs: [MovieExporter.SceneInput] = scenesToExport.indices.map { idx in
            let sc = scenesToExport[idx]
            
            // 該当シーンで有効な全オーディオ（セリフ + BGM + 効果音）をレイヤーとして抽出
            let activeAudios = audioItems.filter { item in
                guard !item.isMuted else { return false }
                let s = item.startSceneIndex ?? item.targetSceneIndex ?? -1
                let e = item.endSceneIndex ?? s
                return s <= idx && idx <= e
            }
            
            var layers: [MovieExporter.AudioLayerInput] = []
            for item in activeAudios {
                if FileManager.default.fileExists(atPath: item.audioPath) {
                    layers.append(MovieExporter.AudioLayerInput(
                        path: item.audioPath,
                        volume: item.volume,
                        playbackRate: item.playbackRate,
                        isReversed: item.isReversed,
                        loops: item.loops,
                        duration: item.duration
                    ))
                }
            }
            
            if let scAudio = sc.audioPath, FileManager.default.fileExists(atPath: scAudio), !layers.contains(where: { $0.path == scAudio }) {
                layers.append(MovieExporter.AudioLayerInput(
                    path: scAudio,
                    volume: 1.0,
                    playbackRate: 1.0,
                    isReversed: false,
                    loops: false,
                    duration: sc.audioDuration
                ))
            }
            
            let hasAnim = sceneHasAnimation(sc)
            return MovieExporter.SceneInput(
                title: sc.title,
                imagePath: sc.imagePath,
                duration: effectiveSceneDuration(at: idx),
                hasAnimation: hasAnim,
                animationMeta: sc.animationMeta,
                audioLayers: layers,
                backgroundImagePath: sc.backgroundImagePath,
                characterImagePath: sc.characterImagePath,
                characterAnimation: sc.characterAnimation,
                telopText: sc.telopText ?? sc.scriptText,
                speakerCharacter: sc.speakerCharacter,
                slideTransitionEffect: sc.slideTransitionEffect,
                slideTransitionDuration: sc.slideTransitionDuration
            )
        }
        let qualityLabel = exportQuality

        isExporting = true
        exportProgress = 0.05
        screenMode = .loading
        loadingMessage = "動画を書き出し中…（ffmpeg）"
        loadingProgress = 0.05

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try MovieExporter.exportMP4(
                    scenes: inputs,
                    outputURL: fileURL,
                    qualityLabel: qualityLabel
                ) { p in
                    DispatchQueue.main.async {
                        self.exportProgress = p
                        self.loadingProgress = max(0.05, min(0.99, p))
                        self.loadingMessage = String(format: "動画を書き出し中… %.0f%%", p * 100)
                    }
                }
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.exportProgress = 1.0
                    self.loadingProgress = 1.0
                    self.screenMode = .editor
                    let sizeMB = Double((try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) / 1_048_576.0
                    self.state.notifyProjectSaved(
                        fileName: fileName,
                        fileURL: fileURL,
                        editor: .movie,
                        sceneCount: scenesToExport.count
                    )
                    self.state.notify(
                        title: "書き出し完了",
                        message: "「\(fileName)」を書き出しました。\n保存先: \(fileURL.path)\nサイズ: \(String(format: "%.1f", sizeMB)) MB\nFinder や QuickTime で再生できます。"
                    )
                    NSWorkspace.shared.activateFileViewerSelecting([fileURL])
                }
            } catch {
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.screenMode = .export
                    self.state.notify(
                        title: "書き出し失敗",
                        message: error.localizedDescription
                    )
                }
            }
        }
    }

    private func homeActionCard(title: String, desc: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(.accentColor)
                    Spacer()
                    Image(systemName: "arrow.forward.circle")
                        .foregroundColor(.secondary)
                }
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text(desc)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 90, alignment: .topLeading)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

struct AnimationStates {
    var slideScale: CGFloat = 1.0
    var slideOffsetX: CGFloat = 0.0
    var slideOffsetY: CGFloat = 0.0
    var slideOpacity: Double = 1.0
    
    var charScale: CGFloat = 1.0
    var charOffsetX: CGFloat = 0.0
    var charOffsetY: CGFloat = 0.0
    var charOpacity: Double = 1.0
    
    var objScale: CGFloat = 1.0
    var objOffsetX: CGFloat = 0.0
    var objOffsetY: CGFloat = 0.0
    var objOpacity: Double = 1.0
}

private func getAnimationStates(
    activeScene: MovieMakerView.MovieSceneData?,
    isAnim: Bool,
    isPlaying: Bool,
    p: Double,
    wallElapsed: Double = 0.0
) -> AnimationStates {
    var states = AnimationStates()
    guard let activeScene = activeScene else { return states }
    guard isPlaying else { return states }
    
    let progress = max(0.0, min(1.0, p))
    let bouncePhase = wallElapsed
    _ = isAnim
    
    func applyKind(
        _ kind: SlideAnimationKit.Kind,
        scale: inout CGFloat,
        ox: inout CGFloat,
        oy: inout CGFloat,
        op: inout Double,
        bounceAmp: CGFloat,
        bounceHz: Double,
        bounceDur: Double,
        bounceDecay: Bool
    ) {
        scale = 1.0; ox = 0.0; oy = 0.0; op = 1.0
        switch kind {
        case .zoomIn:     scale = 1.0 + CGFloat(progress) * 0.10
        case .zoomOut:    scale = 1.10 - CGFloat(progress) * 0.10
        case .fadeIn:     op = min(1.0, progress / 0.35)
        case .slideInRight: ox = CGFloat(1.0 - progress) * 200
        case .slideUp:    oy = CGFloat(1.0 - progress) * 100
        case .panRight:   scale = 1.05; ox = CGFloat(progress) * -30
        case .panLeft:    scale = 1.05; ox = CGFloat(progress) * 30
        case .kenBurns:   scale = 1.0 + CGFloat(progress) * 0.06; oy = CGFloat(progress) * -4.0
        case .bounce:
            let hz = max(0.4, bounceHz)
            let dur = max(0.25, bounceDur)
            let t = bouncePhase
            let angle = t * hz * 2.0 * .pi
            var amp = bounceAmp
            if bounceDecay {
                // Keynote「ディケイ」相当: 継続時間に向けて減衰（最低15%）
                let life = min(1.0, t / dur)
                amp = bounceAmp * CGFloat(max(0.15, 1.0 - life * 0.85))
            }
            oy = CGFloat(sin(angle)) * amp
            scale = 1.0 + CGFloat(max(0.0, sin(angle))) * 0.03
        }
    }
    
    func charBounceParams(from recipe: SlideAnimationKit.Recipe) -> (hz: Double, dur: Double, decay: Bool) {
        let dur = SlideAnimationKit.extractDurationSeconds(from: recipe.raw)
            ?? activeScene.animationDuration
            ?? Double(max(1, recipe.bounceCount)) / 1.73
        let hz = SlideAnimationKit.bounceFrequencyHz(recipe: recipe, durationHint: dur)
        let decay = recipe.raw.contains("ディケイ") || recipe.raw.lowercased().contains("decay") || dur >= 3.0
        return (hz, dur, decay)
    }
    
    func applyToChar(kind: SlideAnimationKit.Kind, recipe: SlideAnimationKit.Recipe? = nil) {
        var s: CGFloat = 1.0; var ox: CGFloat = 0; var oy: CGFloat = 0; var op: Double = 1
        let r = recipe ?? SlideAnimationKit.Recipe(kind: kind, target: .character, raw: "")
        let bp = charBounceParams(from: r)
        applyKind(kind, scale: &s, ox: &ox, oy: &oy, op: &op, bounceAmp: 16.0, bounceHz: bp.hz, bounceDur: bp.dur, bounceDecay: bp.decay)
        states.charScale = s
        states.charOffsetX = ox
        states.charOffsetY = oy
        states.charOpacity = op
    }
    
    func applyToSlide(kind: SlideAnimationKit.Kind) {
        var s: CGFloat = 1.0; var ox: CGFloat = 0; var oy: CGFloat = 0; var op: Double = 1
        // 背景に bounce は使わない
        let k = (kind == .bounce) ? SlideAnimationKit.Kind.kenBurns : kind
        applyKind(k, scale: &s, ox: &ox, oy: &oy, op: &op, bounceAmp: 0.0, bounceHz: 1.0, bounceDur: 1.0, bounceDecay: false)
        states.slideScale = s
        states.slideOffsetX = ox
        states.slideOffsetY = oy
        states.slideOpacity = op
    }
    
    func applyToObj(kind: SlideAnimationKit.Kind) {
        var s: CGFloat = 1.0; var ox: CGFloat = 0; var oy: CGFloat = 0; var op: Double = 1
        applyKind(kind, scale: &s, ox: &ox, oy: &oy, op: &op, bounceAmp: 6.0, bounceHz: 1.5, bounceDur: 1.0, bounceDecay: false)
        // オブジェクト既定の「表示」は短めのフェード＋上昇
        if kind == .kenBurns || kind == .bounce {
            let t = min(1.0, progress / 0.4)
            op = t
            oy = CGFloat(1.0 - t) * 18.0
            s = 1.0
            ox = 0
        }
        states.objScale = s
        states.objOffsetX = ox
        states.objOffsetY = oy
        states.objOpacity = op
    }
    
    // 1) backgroundAnimation → slide* のみ（無ければ静止）
    var slideAnimApplied = false
    if let bgAnimStr = activeScene.backgroundAnimation, !bgAnimStr.isEmpty {
        applyToSlide(kind: SlideAnimationKit.classify(token: bgAnimStr).kind)
        slideAnimApplied = true
    }
    
    // 2) characterAnimation → char* のみ（バウンスは wallElapsed + 回数/秒で駆動）
    var charAnimApplied = false
    if let charAnimStr = activeScene.characterAnimation, !charAnimStr.isEmpty {
        let charRecipe = SlideAnimationKit.classify(token: charAnimStr)
        let charKind: SlideAnimationKit.Kind = (charRecipe.kind == .kenBurns) ? .bounce : charRecipe.kind
        applyToChar(kind: charKind, recipe: SlideAnimationKit.Recipe(kind: charKind, target: .character, raw: charAnimStr, bounceCount: charRecipe.bounceCount))
        charAnimApplied = true
    }
    
    // 3) animationMeta recipes — ターゲット厳密分離（背景未設定時のみ slide 適用）
    let recipes = SlideAnimationKit.parseRecipes(from: activeScene.animationMeta)
    var objAnimApplied = false
    for recipe in recipes {
        switch recipe.target {
        case .slide:
            if !slideAnimApplied {
                applyToSlide(kind: recipe.kind)
                slideAnimApplied = true
            }
        case .character:
            if !charAnimApplied {
                let k = recipe.kind == .kenBurns ? SlideAnimationKit.Kind.bounce : recipe.kind
                applyToChar(kind: k, recipe: recipe)
                charAnimApplied = true
            }
        case .object:
            applyToObj(kind: recipe.kind)
            objAnimApplied = true
        }
    }
    
    // 4) objectAnimation → obj* のみ（無ければオブジェクト/テロップは動かさない）
    if !objAnimApplied, let objAnim = activeScene.objectAnimation, !objAnim.isEmpty {
        applyToObj(kind: SlideAnimationKit.classify(token: objAnim).kind)
        objAnimApplied = true
    }
    
    // キャラレイヤーが出るのに characterAnimation が空なら動かさない（Keynote静止に合わせる）
    // 背景デフォルト Ken Burns も付けない
    _ = (slideAnimApplied, charAnimApplied, objAnimApplied)
    
    return states
}
