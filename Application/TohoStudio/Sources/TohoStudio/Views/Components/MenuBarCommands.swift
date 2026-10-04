import SwiftUI
import AppKit
import UniformTypeIdentifiers

public struct MenuBarCommands: Commands {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some Commands {
        // MARK: - Toho-Studio (cmd+t)
        CommandMenu("Toho-Studio") {
            Button("アプリトップ (cmd+0)") {
                withAnimation { appState.isShowingAppTop = true }
                appState.addHistory("メニュー: アプリトップを表示")
            }
            .keyboardShortcut("0", modifiers: [.command])

            Divider()

            Button("アプリ情報 (cmd+t+i)") {
                appState.appInfoInitialTab = 0
                appState.activeModal = .appInfo
                appState.addHistory("メニュー: アプリ情報を表示")
            }
            .keyboardShortcut("i", modifiers: [.command, .control])

            Button("設定画面 (cmd+t+s)") {
                appState.activeModal = .settings
                appState.addHistory("メニュー: 設定画面を表示")
            }
            .keyboardShortcut("s", modifiers: [.command, .control])

            Button("ストア (cmd+t+shift+s)") {
                appState.activeModal = .store
                appState.addHistory("メニュー: ストアを表示")
            }
            .keyboardShortcut("s", modifiers: [.command, .control, .shift])

            Button("再起動 (cmd+t+r)") {
                appState.activeModal = .reboot
                appState.addHistory("メニュー: 再起動ダイアログを表示")
            }
            .keyboardShortcut("r", modifiers: [.command, .control])

            Divider()

            Button("開発者 (cmd+t+e)") {
                appState.activeModal = .developer
                appState.addHistory("メニュー: 開発者コンソールを表示")
            }
            .keyboardShortcut("e", modifiers: [.command, .control])
        }

        // MARK: - ソフト (cmd+1..6)
        CommandMenu("ソフト") {
            Button("アプリトップ") {
                withAnimation { appState.isShowingAppTop = true }
            }
            .keyboardShortcut("0", modifiers: [.command])

            Divider()

            Button("ムービーメーカー") {
                withAnimation {
                    appState.currentModule = .movieMaker
                    appState.isShowingAppTop = false
                }
            }
            .keyboardShortcut("1", modifiers: [.command])

            Button("キャラクターメーカー") {
                withAnimation {
                    appState.currentModule = .characterMaker
                    appState.isShowingAppTop = false
                }
            }
            .keyboardShortcut("2", modifiers: [.command])

            Button("サウンドメーカー") {
                withAnimation {
                    appState.currentModule = .soundMaker
                    appState.isShowingAppTop = false
                }
            }
            .keyboardShortcut("3", modifiers: [.command])

            Button("スライド＆シナリオメーカー") {
                withAnimation {
                    appState.currentModule = .slideScenarioMaker
                    appState.isShowingAppTop = false
                }
            }
            .keyboardShortcut("4", modifiers: [.command])

            Button("ゲームメーカー") {
                withAnimation {
                    appState.currentModule = .gameMaker
                    appState.isShowingAppTop = false
                }
            }
            .keyboardShortcut("5", modifiers: [.command])

            Button("素材スタジオ") {
                withAnimation {
                    appState.currentModule = .materialStudio
                    appState.isShowingAppTop = false
                }
            }
            .keyboardShortcut("6", modifiers: [.command])

            Button("TohoAIStudio") {
                withAnimation {
                    appState.currentModule = .tohoAIStudio
                    appState.isShowingAppTop = false
                }
            }
            .keyboardShortcut("7", modifiers: [.command])
        }

        // MARK: - AI機能 (TohoAIStudio 新版仕様書)
        CommandMenu("AI機能") {
            Button("仮想LinuxVM 通信確認") {
                withAnimation {
                    appState.currentModule = .tohoAIStudio
                    appState.isShowingAppTop = false
                    TohoAIService.shared.activeProgramTab = .virtualLinuxVM
                }
            }

            Button("AIチャット") {
                withAnimation {
                    appState.currentModule = .tohoAIStudio
                    appState.isShowingAppTop = false
                    TohoAIService.shared.activeProgramTab = .aiChat
                }
            }

            Button("AI編集・推敲") {
                withAnimation {
                    appState.currentModule = .tohoAIStudio
                    appState.isShowingAppTop = false
                    TohoAIService.shared.activeProgramTab = .aiEditor
                }
            }

            Button("AI画像生成 (東方名所・キャラクター)") {
                withAnimation {
                    appState.currentModule = .tohoAIStudio
                    appState.isShowingAppTop = false
                    TohoAIService.shared.activeProgramTab = .aiImageGenerator
                }
            }

            Button("AI音楽・SE生成 (ZUNペットBGM/弾幕効果音)") {
                withAnimation {
                    appState.currentModule = .tohoAIStudio
                    appState.isShowingAppTop = false
                    TohoAIService.shared.activeProgramTab = .aiSoundGenerator
                }
            }

            Button("使用量・請求確認") {
                withAnimation {
                    appState.currentModule = .tohoAIStudio
                    appState.isShowingAppTop = false
                    TohoAIService.shared.activeProgramTab = .usageBilling
                }
            }

            Divider()

            Button("外部API管理 (Gemini / ChatGPT / Claude)") {
                withAnimation {
                    appState.currentModule = .tohoAIStudio
                    appState.isShowingAppTop = false
                    TohoAIService.shared.activeProgramTab = .externalAPI
                }
            }

            Button("専用ブラウザで請求確認") {
                withAnimation {
                    appState.currentModule = .tohoAIStudio
                    appState.isShowingAppTop = false
                    TohoAIService.shared.activeProgramTab = .inAppBrowser
                }
            }
        }

        // MARK: - ファイル (cmd+f)
        CommandMenu("ファイル") {
            Button("新規作成 (cmd+f+n)") {
                appState.activeModal = .newProject
                appState.addHistory("ファイル: 新規作成ダイアログ表示")
            }
            .keyboardShortcut("n", modifiers: [.command, .option])

            Button("ファイル読み込み (cmd+f+r)") {
                if appState.currentModule == .slideScenarioMaker {
                    appState.activeModal = .slideLoader
                    appState.log("スライド＆シナリオメーカー: スライドの読み込みプログラムを開きました")
                } else {
                    let panel = NSOpenPanel()
                    panel.allowsMultipleSelection = false
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = false
                    panel.message = "\(appState.currentModule.rawValue)に読み込むファイルを選択してください（スライド＆シナリオ .tspm / .key 等もインポート可能）"
                    if panel.runModal() == .OK, let url = panel.url {
                        let ext = url.pathExtension.lowercased()
                        if ["tspm", "key", "keynote", "gslide", "pptx"].contains(ext) {
                            // スライド＆シナリオメーカーのファイルを、現在のソフト（ムービー、サウンド、ゲーム等）に直接インポート！
                            appState.importSlideScenarioFile(from: url, targetModule: appState.currentModule)
                        } else if ext == "tsvm" && appState.currentModule == .movieMaker {
                            if let data = try? Data(contentsOf: url),
                               let scenes = try? JSONDecoder().decode([MovieScene].self, from: data) {
                                appState.movieScenes = scenes
                                appState.totalDuration = scenes.reduce(0.0) { $0 + $1.duration }
                                appState.currentProjectPath = url.path
                                appState.currentProjectName = url.deletingPathExtension().lastPathComponent
                                appState.log("ムービーメーカープロジェクトを読み込みました: \(scenes.count)シーン")
                            }
                        } else if ext == "tssm" {
                            if appState.currentModule == .movieMaker {
                                appState.assignAudioFromSoundMaker(url: url)
                            } else {
                                if appState.currentModule != .soundMaker {
                                    appState.currentModule = .soundMaker
                                }
                                appState.loadSoundMakerProject(from: url)
                            }
                        } else if ext == "tscm" {
                            if appState.currentModule != .characterMaker {
                                appState.currentModule = .characterMaker
                            }
                            appState.loadCharacterProject(from: url)
                        } else if ext == "tsgm" && appState.currentModule == .gameMaker {
                            if let data = try? Data(contentsOf: url),
                               let cmds = try? JSONDecoder().decode([GameCommand].self, from: data) {
                                appState.gameCommands = cmds
                                appState.currentProjectPath = url.path
                                appState.currentProjectName = url.deletingPathExtension().lastPathComponent
                                appState.log("ゲームメーカープロジェクトを読み込みました: \(cmds.count)コマンド")
                            }
                        } else {
                            // 汎用JSON・フォールバック
                            if let data = try? Data(contentsOf: url) {
                                if let slides = try? JSONDecoder().decode([SlideItem].self, from: data) {
                                    appState.slides = slides
                                    appState.importCurrentSlides(to: appState.currentModule)
                                } else {
                                    appState.importSlideScenarioFile(from: url, targetModule: appState.currentModule)
                                }
                            }
                        }
                    }
                }
                appState.addHistory("ファイル: ファイル読み込み実行")
            }
            .keyboardShortcut("r", modifiers: [.command, .option])

            Button("スライド＆シナリオからインポート (.tspm)") {
                let panel = NSOpenPanel()
                panel.allowsMultipleSelection = false
                panel.canChooseFiles = true
                panel.canChooseDirectories = false
                panel.message = "[\(appState.currentModule.rawValue)]へインポートするスライド＆シナリオファイル (.tspm / .key) を選択してください"
                if panel.runModal() == .OK, let url = panel.url {
                    appState.importSlideScenarioFile(from: url, targetModule: appState.currentModule)
                }
            }

            Button("書き出し (cmd+f+e)") {
                appState.activeModal = .fileExport
                appState.addHistory("ファイル: 書き出しダイアログ表示")
            }
            .keyboardShortcut("e", modifiers: [.command, .option])

            Button("複製 (cmd+f+c)") {
                appState.performDuplicate()
            }
            .keyboardShortcut("c", modifiers: [.command, .option])

            Button("巻き戻し (cmd+f+b)") {
                appState.performRollback()
            }
            .keyboardShortcut("b", modifiers: [.command, .option])

            Divider()

            Button("上書き保存 (cmd+f+s)") {
                appState.performSave()
            }
            .keyboardShortcut("s", modifiers: [.command])

            Button("ファイル保存 (cmd+f+shift+s)") {
                let panel = NSSavePanel()
                let ext = appState.currentModule.projectExtension
                panel.title = "\(appState.currentModule.rawValue)ファイルを保存 (\(ext))"
                panel.nameFieldStringValue = "\(appState.currentProjectName).\(ext)"
                if let uti = UTType(filenameExtension: ext) {
                    panel.allowedContentTypes = [uti]
                }
                if panel.runModal() == .OK, let url = panel.url {
                    appState.performSaveAs(fileName: url.deletingPathExtension().lastPathComponent)
                }
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Button("ファイル修復 (cmd+f+shift+r)") {
                appState.performRepair()
            }
            .keyboardShortcut("r", modifiers: [.command, .option, .shift])

            Button("整合性確認 (cmd+f+shift+c)") {
                appState.activeModal = .integrityAlert
                appState.addHistory("ファイル: 整合性確認を開きました")
            }
            .keyboardShortcut("c", modifiers: [.command, .option, .shift])

            Button("ファイル情報 (cmd+f+i)") {
                appState.activeModal = .fileInfo
                appState.addHistory("ファイル: ファイル情報を表示")
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
        }

        // MARK: - 編集 (cmd+e)
        CommandMenu("編集") {
            Button("やり直す (cmd+z)") {
                appState.performUndo()
            }
            .keyboardShortcut("z", modifiers: [.command])

            Button("進める (cmd+shift+z)") {
                appState.performRedo()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])

            Divider()

            // トリミング: ゲームメーカー以外で表示 (仕様書 78行目)
            if appState.currentModule != .gameMaker {
                Button("トリミング (cmd+t)") {
                    appState.activeModal = .trimmingPopup
                    appState.addHistory("編集: トリミングダイアログを開きました")
                }
                .keyboardShortcut("t", modifiers: [.command])
            }

            Button("分割 (cmd+e+c)") {
                appState.activeModal = .splitPopup
                appState.addHistory("編集: 分割ダイアログを開きました")
            }
            .keyboardShortcut("c", modifiers: [.command, .control])

            Button("インポート (cmd+e+i)") {
                appState.performImportMaterials()
            }
            .keyboardShortcut("i", modifiers: [.command, .control])

            Button("エクスポート (cmd+e+o)") {
                appState.performExportMaterials()
            }
            .keyboardShortcut("o", modifiers: [.command, .control])

            Button("シーン情報 (cmd+e+shift+i)") {
                appState.activeModal = .sceneInfo
                appState.addHistory("編集: シーン情報を表示")
            }
            .keyboardShortcut("i", modifiers: [.command, .control, .shift])

            Button("画面更新 (cmd+e+r)") {
                appState.log("画面を更新し、最新状態を取得しました")
                appState.addHistory("編集: 画面更新")
            }

            Button("点検と修正 (cmd+e+u)") {
                appState.activeModal = .policyCheckPopup
                appState.addHistory("編集: 点検と修正を開きました")
            }
            .keyboardShortcut("u", modifiers: [.command, .control])

            // 再生成: 素材スタジオ以外で表示 (仕様書 162行目)
            if appState.currentModule != .materialStudio {
                Button("再生成 (cmd+e+p)") {
                    appState.performRegenerate()
                }
                .keyboardShortcut("p", modifiers: [.command, .control])
            }

            Button("素材一覧 (cmd+e+s)") {
                if appState.currentModule == .materialStudio {
                    appState.currentModule = .movieMaker
                } else {
                    appState.currentModule = .materialStudio
                }
                appState.addHistory("編集: 素材一覧/素材スタジオ切り替え")
            }

            Button("編集履歴 (cmd+e+h)") {
                appState.activeModal = .historyList
                appState.addHistory("編集: 編集履歴を表示")
            }
            .keyboardShortcut("h", modifiers: [.command, .control])

            Button("自動保存 (cmd+e+a)") {
                StorageManager.shared.autoSaveEnabled.toggle()
                appState.log("自動保存を \(StorageManager.shared.autoSaveEnabled ? "有効" : "無効") にしました")
                appState.addHistory("編集: 自動保存切り替え")
            }
            .keyboardShortcut("a", modifiers: [.command, .control])

            Button("素材作成 (cmd+e+m)") {
                appState.performCreateMaterialFromCurrent()
            }
            .keyboardShortcut("m", modifiers: [.command, .control])

            if appState.currentModule == .characterMaker {
                Button("前後反転 (背中側/正面) (cmd+e+f)") {
                    appState.toggleCharacterFacingDirection()
                }
                .keyboardShortcut("f", modifiers: [.command, .control])
            }

            Button("編集メモ (cmd+e+n)") {
                appState.activeModal = .memoPad
                appState.addHistory("編集: 編集メモを開きました")
            }
            .keyboardShortcut("n", modifiers: [.command, .control])
        }

        // MARK: - 表示 (cmd+d)
        CommandMenu("表示") {
            Button(appState.isControlBarVisible ? "コントロールバーを消す" : "コントロールバーを表示") {
                withAnimation { appState.isControlBarVisible.toggle() }
            }
            .keyboardShortcut("c", modifiers: [.command, .shift])

            Divider()

            Button("全画面表示 (cmd+d+a)") {
                appState.isFullScreen.toggle()
                appState.addHistory("表示: 全画面表示切り替え (\(appState.isFullScreen ? "全画面" : "通常"))")
            }
            .keyboardShortcut("a", modifiers: [.command, .option])

            Button("進捗状況確認 (cmd+d+s)") {
                appState.activeModal = .backgroundProcess
                appState.addHistory("表示: 進捗状況確認を表示")
            }

            Button("ログと実績 (cmd+d+l)") {
                appState.activeModal = .logsAndAchievements
                appState.addHistory("表示: ログと実績を表示")
            }

            Button("バグレポート (cmd+d+b)") {
                appState.activeModal = .bugReport
                appState.addHistory("表示: バグレポートを開きました")
            }

            Button("Finderで表示 (cmd+d+f)") {
                appState.showInFinder()
            }

            Button("履歴一覧 (cmd+d+m)") {
                appState.activeModal = .historyList
                appState.addHistory("表示: 履歴一覧を表示")
            }

            Button("ステータス (cmd+d+shift+s)") {
                appState.activeModal = .statusComparison
                appState.addHistory("表示: ステータス比較を表示")
            }

            Button("スクショ (cmd+d+p)") {
                appState.captureScreen()
            }

            Button(appState.isScreenRecording ? "画面収録を停止 (cmd+d+shift+p)" : "画面収録を開始 (cmd+d+shift+p)") {
                appState.toggleScreenRecording()
            }

            Button("デバック画面 (cmd+d+shift+l)") {
                appState.activeModal = .debugScreen
                appState.addHistory("表示: デバック画面を表示")
            }

            Button("ソフト一覧 (cmd+d+option+s)") {
                appState.activeModal = .softwareList
                appState.addHistory("表示: ソフト一覧を表示")
            }

            Button("機能リスト (cmd+d+option+l)") {
                appState.activeModal = .featureList
                appState.addHistory("表示: 機能リストを表示")
            }
            .keyboardShortcut("l", modifiers: [.command, .option])

            Button("オプション (cmd+d+option)") {
                appState.activeModal = .contextOptions
                appState.addHistory("表示: コンテキストオプションを表示")
            }

            Button("備考録 (cmd+d+n)") {
                appState.activeModal = .memoPad
                appState.addHistory("表示: 備考録を表示")
            }

            Divider()

            Button("拡大 (cmd+d+z)") {
                appState.zoomScale = min(appState.zoomScale + 0.1, 1.8)
                appState.log("UI表示倍率を拡大しました: \(Int(appState.zoomScale * 100))%")
                appState.addHistory("表示: 拡大 (\(Int(appState.zoomScale * 100))%)")
            }

            Button("縮小 (cmd+d+shift+z)") {
                appState.zoomScale = max(appState.zoomScale - 0.1, 0.7)
                appState.log("UI表示倍率を縮小しました: \(Int(appState.zoomScale * 100))%")
                appState.addHistory("表示: 縮小 (\(Int(appState.zoomScale * 100))%)")
            }
        }

        // MARK: - 再生 (cmd+p) - ムービーメーカー専用 (仕様書 193行目)
        if appState.currentModule == .movieMaker {
            CommandMenu("再生") {
                Button("全画面再生 (cmd+p+a)") {
                    appState.isFullScreen = true
                    appState.isPlaying = true
                    appState.addHistory("再生: 全画面再生を開始")
                }

                Button("ここから再生 (cmd+p+n)") {
                    appState.isPlaying = true
                    appState.addHistory("再生: ここから再生")
                }

                Button("ループ再生 (cmd+p+l)") {
                    appState.isLooping.toggle()
                    appState.addHistory("再生: ループ切り替え (\(appState.isLooping ? "ループON" : "ループOFF"))")
                }

                Button("音量アップ (cmd+p+u)") {
                    appState.playbackVolume = min(appState.playbackVolume + 0.1, 1.0)
                    appState.addHistory("再生: 音量アップ (\(Int(appState.playbackVolume * 100))%)")
                }

                Button("音量ダウン (cmd+p+d)") {
                    appState.playbackVolume = max(appState.playbackVolume - 0.1, 0.0)
                    appState.addHistory("再生: 音量ダウン (\(Int(appState.playbackVolume * 100))%)")
                }

                Button("最初から再生 (cmd+p+s)") {
                    appState.currentTime = 0.0
                    appState.isPlaying = true
                    appState.addHistory("再生: 最初から再生")
                }

                Button("ここだけ再生 (cmd+p+option+s)") {
                    appState.isPlaying = true
                    appState.addHistory("再生: ここだけ再生")
                }

                Button("停止 (cmd+p+space+s)") {
                    appState.isPlaying = false
                    appState.addHistory("再生: 停止")
                }

                Button("巻き戻し (cmd+p+b)") {
                    appState.currentTime = max(appState.currentTime - 5.0, 0.0)
                    appState.addHistory("再生: 巻き戻し (5秒)")
                }

                Button("早送り (cmd+p+f)") {
                    appState.currentTime = min(appState.currentTime + 5.0, appState.totalDuration)
                    appState.addHistory("再生: 早送り (5秒)")
                }

                Divider()

                Menu("倍速再生 (cmd+p+数字キー)") {
                    Button("1.0倍速 (等倍)") { appState.playbackSpeed = 1.0 }
                    Button("1.5倍速") { appState.playbackSpeed = 1.5 }
                    Button("2.0倍速") { appState.playbackSpeed = 2.0 }
                    Button("3.0倍速") { appState.playbackSpeed = 3.0 }
                    Button("5.0倍速") { appState.playbackSpeed = 5.0 }
                    Button("9.0倍速") { appState.playbackSpeed = 9.0 }
                }

                Menu("素材情報表示 (cmd+p+特定キー)") {
                    Button("キャラクター情報 (c)") { appState.activeMaterialInfoKey = "c" }
                    Button("オブジェクト情報 (o)") { appState.activeMaterialInfoKey = "o" }
                    Button("背景画像情報 (b)") { appState.activeMaterialInfoKey = "b" }
                    Button("テロップ情報 (p)") { appState.activeMaterialInfoKey = "p" }
                    Button("非表示 (クリア)") { appState.activeMaterialInfoKey = nil }
                }

                Divider()

                Button("デバック再生 (cmd+p+shift+d)") {
                    appState.isDebugPlayback.toggle()
                    appState.addHistory("再生: デバック再生切り替え (\(appState.isDebugPlayback))")
                }

                Button("再生位置確認 (cmd+p+i)") {
                    appState.showPlaybackOverlay.toggle()
                    appState.addHistory("再生: 再生位置確認表示切り替え")
                }

                Button("レート確認 (cmd+p+r)") {
                    appState.showRateOverlay.toggle()
                    appState.addHistory("再生: レート確認表示切り替え")
                }
            }
        }

        // MARK: - ウィンドウ (cmd+w)
        CommandMenu("ウィンドウ") {
            Button("レイアウト切り替え (cmd+w+l)") {
                appState.cycleLayout()
            }

            Menu("レイアウトプリセット (仕様書準拠)") {
                ForEach(AppState.LayoutPresets, id: \.self) { preset in
                    Button(action: {
                        appState.setLayout(preset)
                    }) {
                        HStack {
                            Text(preset)
                            if appState.layoutMode == preset {
                                Text("✓")
                            }
                        }
                    }
                }
            }

            Button("コードモード (cmd+c)") {
                appState.activeModal = .developer
                appState.addHistory("ウィンドウ: コードモード (開発者コンソール)")
            }

            Button("リセット (cmd+w+r)") {
                appState.performSoftReset()
            }

            Button("更新 (cmd+w+shift+r)") {
                appState.performRestoreAfterReset()
            }

            Button("新規展開 (cmd+w+n)") {
                let url = Bundle.main.bundleURL
                let config = NSWorkspace.OpenConfiguration()
                config.createsNewApplicationInstance = true
                NSWorkspace.shared.openApplication(at: url, configuration: config, completionHandler: nil)
                appState.log("新しいウィンドウでアプリケーションを新規展開しました")
                appState.addHistory("ウィンドウ: 新規展開")
            }

            Button("アプリを閉じる (cmd+w+q)") {
                NSApplication.shared.hide(nil)
            }
            .keyboardShortcut("q", modifiers: [.command, .control])

            Button("パネル表示 (cmd+w+p)") {
                appState.isPanelDisplayMode.toggle()
                appState.log("パネル統合表示を \(appState.isPanelDisplayMode ? "有効" : "無効") にしました")
                appState.addHistory("ウィンドウ: パネル表示切り替え")
            }

            Button("オプション (cmd+w+o)") {
                appState.activeModal = .windowOptions
                appState.addHistory("ウィンドウ: オプション設定を表示")
            }
        }

        // MARK: - ヘルプ (cmd+h)
        CommandMenu("ヘルプ") {
            Button("取扱説明書 (cmd+h+d)") {
                appState.activeModal = .manual
                appState.addHistory("ヘルプ: 取扱説明書を表示")
            }

            Button("ヘルプガイド (cmd+h+g)") {
                appState.activeModal = .helpGuide
                appState.addHistory("ヘルプ: ヘルプガイドを表示")
            }

            Button("Q&A (cmd+h+q)") {
                appState.activeModal = .qa
                appState.addHistory("ヘルプ: Q&Aを表示")
            }

            Button("クレジット (cmd+h+k)") {
                appState.activeModal = .credits
                appState.addHistory("ヘルプ: クレジットを表示")
            }

            Button("困ったときは (cmd+h+n)") {
                appState.activeModal = .troubleshoot
                appState.addHistory("ヘルプ: 困ったときはを表示")
            }

            Button("ライセンス (cmd+h+l)") {
                appState.activeModal = .license
                appState.addHistory("ヘルプ: ライセンスを表示")
            }

            Button("サポート依頼 (cmd+h+s)") {
                appState.activeModal = .supportRequest
                appState.addHistory("ヘルプ: サポート依頼を表示")
            }
        }
    }
}

