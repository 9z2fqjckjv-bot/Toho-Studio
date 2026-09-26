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
                        } else if ext == "tssm" && appState.currentModule == .soundMaker {
                            if let data = try? Data(contentsOf: url),
                               let clips = try? JSONDecoder().decode([SoundClip].self, from: data) {
                                appState.soundClips = clips
                                appState.currentProjectPath = url.path
                                appState.currentProjectName = url.deletingPathExtension().lastPathComponent
                                appState.log("サウンドメーカープロジェクトを読み込みました: \(clips.count)クリップ")
                            }
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

            Button("バックアップ (cmd+f+shift+b)") {
                appState.activeModal = .backupManager
                appState.addHistory("ファイル: バックアップ管理を開きました")
            }
            .keyboardShortcut("b", modifiers: [.command, .option, .shift])

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

            Button("編集メモ (cmd+e+n)") {
                appState.activeModal = .memoPad
                appState.addHistory("編集: 編集メモを開きました")
            }
            .keyboardShortcut("n", modifiers: [.command, .control])
        }

        // MARK: - 表示 (cmd+d)
        CommandMenu("表示") {
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

            Menu("機能リスト (cmd+d+option+l)") {
                // 1. AquesTalkで音声を生成 (サブメニュー)
                Menu("AquesTalkで音声を生成") {
                    Button("スライド＆シナリオから全音声一括生成...") {
                        appState.activeModal = .batchVoiceGenerator
                        appState.addHistory("音声: スライドから全音声一括生成画面を表示")
                    }
                    .keyboardShortcut("b", modifiers: [.command, .control, .shift])

                    Button("音声生成スタジオを開く...") {
                        appState.activeModal = .aquesTalkGenerator
                    }
                    .keyboardShortcut("a", modifiers: [.command, .control, .shift])

                    Button("複数シーン跨ぎBGM・SEを挿入...") {
                        appState.activeModal = .spanAudioInsert
                        appState.addHistory("音声: 複数シーン跨ぎBGM・SE挿入画面を表示")
                    }
                    .keyboardShortcut("m", modifiers: [.command, .control, .shift])

                    Divider()

                    // 東風谷早苗 (コゲの日記)
                    Button("東風谷早苗 [女性2 / 速度100%, 音程115] (コゲの日記)") {
                        appState.applyVoiceTemplateByName("東風谷早苗 (コゲの日記)")
                    }

                    Divider()

                    // 独自テンプレート4種 (imd1,100,115 / l1,100,115 / m1,100,115 / m2,100,115)
                    Menu("独自テンプレート (4種)") {
                        Button("imd1 (中性) - 速度100%, 音程115") {
                            appState.applyVoiceTemplateByName("imd1,100,115 (独自)")
                        }
                        Button("l1 (児童/jgr) - 速度100%, 音程115") {
                            appState.applyVoiceTemplateByName("l1,100,115 (独自)")
                        }
                        Button("m1 (男声1) - 速度100%, 音程115") {
                            appState.applyVoiceTemplateByName("m1,100,115 (独自)")
                        }
                        Button("m2 (男声2) - 速度100%, 音程115") {
                            appState.applyVoiceTemplateByName("m2,100,115 (独自)")
                        }
                    }

                    // コゲの日記 テンプレート
                    Menu("コゲの日記 テンプレート") {
                        Button("博麗霊夢 [女性1 / 速度100%, 音程100]") {
                            appState.applyVoiceTemplateByName("博麗霊夢 (コゲの日記)")
                        }
                        Button("霧雨魔理沙 [女性2 / 速度100%, 音程100]") {
                            appState.applyVoiceTemplateByName("霧雨魔理沙 (コゲの日記)")
                        }
                        Button("魂魄妖夢 [女性1 / 速度100%, 音程100]") {
                            appState.applyVoiceTemplateByName("魂魄妖夢 (コゲの日記)")
                        }
                        Button("十六夜咲夜 [女性1 / 速度105%, 音程125]") {
                            appState.applyVoiceTemplateByName("十六夜咲夜 (コゲの日記)")
                        }
                        Button("チルノ [女性2 / 速度115%, 音程120]") {
                            appState.applyVoiceTemplateByName("チルノ (コゲの日記)")
                        }
                        Button("八雲紫 [女性2 / 速度96%, 音程127]") {
                            appState.applyVoiceTemplateByName("八雲紫 (コゲの日記)")
                        }
                        Button("八雲藍 [女性2 / 速度115%, 音程113]") {
                            appState.applyVoiceTemplateByName("八雲藍 (コゲの日記)")
                        }
                        Button("橙 [女性1 / 速度80%, 音程160]") {
                            appState.applyVoiceTemplateByName("橙 (コゲの日記)")
                        }
                        Button("レミリア・スカーレット [女性2 / 速度80%, 音程150]") {
                            appState.applyVoiceTemplateByName("レミリア・スカーレット (コゲの日記)")
                        }
                        Button("フランドール・スカーレット [機械1 / 速度115%, 音程100]") {
                            appState.applyVoiceTemplateByName("フランドール・スカーレット (コゲの日記)")
                        }
                        Button("アリス・マーガトロイド [女性1 / 速度110%, 音程130]") {
                            appState.applyVoiceTemplateByName("アリス・マーガトロイド (コゲの日記)")
                        }
                        Button("パチュリー・ノーレッジ [中性 / 速度100%, 音程140]") {
                            appState.applyVoiceTemplateByName("パチュリー・ノーレッジ (コゲの日記)")
                        }
                        Button("射命丸文 [女性2 / 速度120%, 音程125]") {
                            appState.applyVoiceTemplateByName("射命丸文 (コゲの日記)")
                        }
                        Button("犬走椛 [女性1 / 速度120%, 音程110]") {
                            appState.applyVoiceTemplateByName("犬走椛 (コゲの日記)")
                        }
                        Button("古明地さとり [女性1 / 速度89%, 音程134]") {
                            appState.applyVoiceTemplateByName("古明地さとり (コゲの日記)")
                        }
                        Button("古明地こいし [女性2 / 速度75%, 音程181]") {
                            appState.applyVoiceTemplateByName("古明地こいし (コゲの日記)")
                        }
                        Button("風見幽香 [中性 / 速度100%, 音程160]") {
                            appState.applyVoiceTemplateByName("風見幽香 (コゲの日記)")
                        }
                        Button("藤原妹紅 [女性2 / 速度120%, 音程130]") {
                            appState.applyVoiceTemplateByName("藤原妹紅 (コゲの日記)")
                        }
                    }

                    // Gスカブログ・ゆっくりボイスメーカー テンプレート
                    Menu("Gスカブログ・ゆっくりボイスメーカー テンプレート") {
                        Button("八坂神奈子 [女性1 / 速度115%, 音程90]") {
                            appState.applyVoiceTemplateByName("八坂神奈子 (Gスカブログ)")
                        }
                        Button("洩矢諏訪子 [女性1 / 速度80%, 音程175]") {
                            appState.applyVoiceTemplateByName("洩矢諏訪子 (Gスカブログ)")
                        }
                        Button("多々良小傘 [女性2 / 速度105%, 音程145]") {
                            appState.applyVoiceTemplateByName("多々良小傘 (Gスカブログ)")
                        }
                        Button("聖白蓮 [女性2 / 速度96%, 音程120]") {
                            appState.applyVoiceTemplateByName("聖白蓮 (Gスカブログ)")
                        }
                        Button("豊聡耳神子 [女性1 / 速度130%, 音程103]") {
                            appState.applyVoiceTemplateByName("豊聡耳神子 (Gスカブログ)")
                        }
                        Button("鬼人正邪 [中性 / 速度110%, 音程133]") {
                            appState.applyVoiceTemplateByName("鬼人正邪 (Gスカブログ)")
                        }
                        Button("少名針妙丸 [児童 / 速度120%, 音程160]") {
                            appState.applyVoiceTemplateByName("少名針妙丸 (ゆっくりボイスメーカー)")
                        }
                        Button("純狐 [女性3 / 速度95%, 音程105]") {
                            appState.applyVoiceTemplateByName("純狐 (ゆっくりボイスメーカー)")
                        }
                    }
                }

                // 2. レイアウト切り替え (仕様書準拠)
                Menu("レイアウト切り替え (仕様書準拠)") {
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

                Divider()

                Button("機能リスト＆ショートカット一覧を開く...") {
                    appState.activeModal = .featureList
                    appState.addHistory("表示: 機能リストを表示")
                }
            }

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

