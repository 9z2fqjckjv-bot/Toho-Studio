import SwiftUI

public struct MenuBarCommands: Commands {
    @ObservedObject var appState: AppState

    public init(appState: AppState) {
        self.appState = appState
    }

    public var body: some Commands {
        // MARK: - Toho-Studio (cmd+t)
        CommandMenu("Toho-Studio") {
            Button("アプリ情報 (cmd+t+i)") {
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
                appState.log("新規編集ファイルを作成しました")
                appState.addHistory("ファイル: 新規作成")
            }
            .keyboardShortcut("n", modifiers: [.command, .option])

            Button("ファイル読み込み (cmd+f+r)") {
                if appState.currentModule == .slideScenarioMaker {
                    appState.activeModal = .slideLoader
                    appState.log("スライド＆シナリオメーカー: スライドの読み込みプログラムを開きました")
                } else {
                    appState.log("ファイル読み込みダイアログを開きました")
                }
                appState.addHistory("ファイル: ファイル読み込み")
            }
            .keyboardShortcut("r", modifiers: [.command, .option])

            Button("書き出し (cmd+f+e)") {
                appState.log("現在の編集ファイルを書き出しました")
                appState.addHistory("ファイル: 書き出し")
            }
            .keyboardShortcut("e", modifiers: [.command, .option])

            Button("複製 (cmd+f+c)") {
                appState.log("編集ファイルを複製しました")
                appState.addHistory("ファイル: 複製")
            }
            .keyboardShortcut("c", modifiers: [.command, .option])

            Button("巻き戻し (cmd+f+b)") {
                appState.log("編集ファイルを以前の状態に巻き戻しました")
                appState.addHistory("ファイル: 巻き戻し")
            }
            .keyboardShortcut("b", modifiers: [.command, .option])

            Button("バックアップ (cmd+f+shift+b)") {
                _ = StorageManager.shared.createBackup(fileName: "CurrentProject", content: "TohoStudio Project Backup Data")
                appState.log("プロジェクトのバックアップを作成しました")
                appState.addHistory("ファイル: バックアップ")
            }
            .keyboardShortcut("b", modifiers: [.command, .option, .shift])

            Divider()

            Button("上書き保存 (cmd+f+s)") {
                appState.log("編集ファイルを上書き保存しました")
                appState.addHistory("ファイル: 上書き保存")
            }
            .keyboardShortcut("s", modifiers: [.command])

            Button("ファイル保存 (cmd+f+shift+s)") {
                appState.log("プロジェクトファイルとして名前をつけて保存しました")
                appState.addHistory("ファイル: 名前をつけて保存")
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])

            Button("ファイル修復 (cmd+f+shift+r)") {
                _ = StorageManager.shared.repairFile(filePath: "CurrentProject")
                appState.log("ファイル修復処理を実行しました")
                appState.addHistory("ファイル: ファイル修復")
            }
            .keyboardShortcut("r", modifiers: [.command, .option, .shift])

            Button("整合性確認 (cmd+f+shift+c)") {
                appState.activeModal = .integrityAlert
                appState.addHistory("ファイル: 整合性確認")
            }
            .keyboardShortcut("c", modifiers: [.command, .option, .shift])

            Button("ファイル情報 (cmd+f+i)") {
                appState.activeModal = .fileInfo
                appState.addHistory("ファイル: ファイル情報")
            }
            .keyboardShortcut("i", modifiers: [.command, .option])
        }

        // MARK: - 編集 (cmd+e)
        CommandMenu("編集") {
            Button("やり直す (cmd+z)") {
                appState.log("操作をひとつ戻しました (Undo)")
                appState.addHistory("編集: やり直す")
            }
            .keyboardShortcut("z", modifiers: [.command])

            Button("進める (cmd+shift+z)") {
                appState.log("やり直した操作を進めました (Redo)")
                appState.addHistory("編集: 進める")
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])

            Divider()

            Button("トリミング (cmd+t)") {
                appState.activeModal = .trimmingPopup
                appState.addHistory("編集: トリミング")
            }
            .keyboardShortcut("t", modifiers: [.command])

            Button("分割 (cmd+e+c)") {
                appState.activeModal = .splitPopup
                appState.addHistory("編集: 分割")
            }
            .keyboardShortcut("c", modifiers: [.command, .control])

            Button("インポート (cmd+e+i)") {
                appState.log("素材スタジオにファイルをインポートしました")
                appState.addHistory("編集: インポート")
            }

            Button("エクスポート (cmd+e+o)") {
                appState.log("素材スタジオからファイルをエクスポートしました")
                appState.addHistory("編集: エクスポート")
            }

            Button("シーン情報 (cmd+e+shift+i)") {
                appState.activeModal = .fileInfo
                appState.addHistory("編集: シーン情報")
            }

            Button("画面更新 (cmd+e+r)") {
                appState.log("画面を更新し、最新状態を取得しました")
                appState.addHistory("編集: 画面更新")
            }

            Button("点検と修正 (cmd+e+u)") {
                appState.activeModal = .policyCheckPopup
                appState.addHistory("編集: 点検と修正")
            }

            Button("再生成 (cmd+e+p)") {
                if appState.currentModule == .slideScenarioMaker {
                    let path = SlideRecognitionService.shared.loadedProjectName.contains("/") ? SlideRecognitionService.shared.loadedProjectName : "/Volumes/ZSSD/GitHub/repository/TohoStudio/東方惑情録/東方惑情録　第1話.key"
                    SlideRecognitionService.shared.loadSlideProgram(filePath: path, replaceState: true) { _, _ in }
                    appState.log("スライド＆シナリオメーカー: 表示されているスライドの元ファイルを再読み込みしました")
                } else {
                    appState.log("現在表示中の要素を再生成しました")
                }
                appState.addHistory("編集: 再生成")
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
                appState.addHistory("編集: 編集履歴")
            }

            Button("自動保存 (cmd+e+a)") {
                StorageManager.shared.autoSaveEnabled.toggle()
                appState.log("自動保存を \(StorageManager.shared.autoSaveEnabled ? "有効" : "無効") にしました")
                appState.addHistory("編集: 自動保存切り替え")
            }

            Button("素材作成 (cmd+e+m)") {
                appState.log("編集中のデータから新規素材を作成し、素材スタジオに保存しました")
                appState.addHistory("編集: 素材作成")
            }

            Button("編集メモ (cmd+e+n)") {
                appState.activeModal = .memoPad
                appState.addHistory("編集: 編集メモ")
            }
        }

        // MARK: - 表示 (cmd+d)
        CommandMenu("表示") {
            Button("全画面表示 (cmd+d+a)") {
                appState.isFullScreen.toggle()
                appState.addHistory("表示: 全画面表示切り替え")
            }

            Button("進捗状況確認 (cmd+d+s)") {
                appState.activeModal = .backgroundProcess
                appState.addHistory("表示: 進捗状況確認")
            }

            Button("ログと実績 (cmd+d+l)") {
                appState.activeModal = .logsAndAchievements
                appState.addHistory("表示: ログと実績")
            }

            Button("バグレポート (cmd+d+b)") {
                appState.activeModal = .bugReport
                appState.addHistory("表示: バグレポート")
            }

            Button("Finderで表示 (cmd+d+f)") {
                appState.log("Finderでファイルパスを開きました")
                appState.addHistory("表示: Finderで表示")
            }

            Button("履歴一覧 (cmd+d+m)") {
                appState.activeModal = .historyList
                appState.addHistory("表示: 履歴一覧")
            }

            Button("ステータス (cmd+d+shift+s)") {
                appState.activeModal = .statusComparison
                appState.addHistory("表示: ステータス比較")
            }

            Button("スクショ (cmd+d+p)") {
                appState.log("画面スクリーンショットをキャプチャし素材スタジオに保存しました")
                appState.addHistory("表示: スクショ")
            }

            Button("デバック画面 (cmd+d+shift+l)") {
                appState.activeModal = .debugScreen
                appState.addHistory("表示: デバック画面")
            }

            Button("ソフト一覧 (cmd+d+option+s)") {
                appState.activeModal = .softwareList
                appState.addHistory("表示: ソフト一覧")
            }

            Button("機能リスト (cmd+d+option+l)") {
                appState.activeModal = .featureList
                appState.addHistory("表示: 機能リスト")
            }

            Button("備考録 (cmd+d+n)") {
                appState.activeModal = .memoPad
                appState.addHistory("表示: 備考録")
            }
        }

        // MARK: - 再生 (cmd+p) - ムービーメーカー専用
        CommandMenu("再生") {
            Button("全画面再生 (cmd+p+a)") {
                appState.isFullScreen = true
                appState.isPlaying = true
                appState.addHistory("再生: 全画面再生")
            }

            Button("ここから再生 (cmd+p+n)") {
                appState.isPlaying = true
                appState.addHistory("再生: ここから再生")
            }

            Button("ループ再生 (cmd+p+l)") {
                appState.isLooping.toggle()
                appState.addHistory("再生: ループ切り替え (\(appState.isLooping))")
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
                appState.addHistory("再生: 巻き戻し")
            }

            Button("早送り (cmd+p+f)") {
                appState.currentTime = min(appState.currentTime + 5.0, appState.totalDuration)
                appState.addHistory("再生: 早送り")
            }

            Button("デバック再生 (cmd+p+shift+d)") {
                appState.isDebugPlayback.toggle()
                appState.addHistory("再生: デバック再生切り替え")
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

        // MARK: - ウィンドウ (cmd+w)
        CommandMenu("ウィンドウ") {
            Button("レイアウト (cmd+w+l)") {
                appState.log("レイアウトを切り替えました")
                appState.addHistory("ウィンドウ: レイアウト切り替え")
            }

            Button("コードモード (cmd+c)") {
                appState.activeModal = .developer
                appState.addHistory("ウィンドウ: コードモード")
            }

            Button("リセット (cmd+w+r)") {
                appState.log("プログラムをリセットし初期状態に戻しました")
                appState.addHistory("ウィンドウ: リセット")
            }

            Button("更新 (cmd+w+shift+r)") {
                appState.log("表示画面を復元しました")
                appState.addHistory("ウィンドウ: 更新")
            }

            Button("新規展開 (cmd+w+n)") {
                appState.log("新規ウィンドウを開きました")
                appState.addHistory("ウィンドウ: 新規展開")
            }
        }

        // MARK: - ヘルプ (cmd+h)
        CommandMenu("ヘルプ") {
            Button("取扱説明書 (cmd+h+d)") {
                appState.activeModal = .featureList
                appState.addHistory("ヘルプ: 取扱説明書")
            }

            Button("ヘルプガイド (cmd+h+g)") {
                appState.activeModal = .featureList
                appState.addHistory("ヘルプ: ヘルプガイド")
            }

            Button("Q&A (cmd+h+q)") {
                appState.activeModal = .featureList
                appState.addHistory("ヘルプ: Q&A")
            }

            Button("クレジット (cmd+h+k)") {
                appState.activeModal = .appInfo
                appState.addHistory("ヘルプ: クレジット")
            }

            Button("困ったときは (cmd+h+n)") {
                appState.activeModal = .featureList
                appState.addHistory("ヘルプ: 困ったときは")
            }

            Button("ライセンス (cmd+h+l)") {
                appState.activeModal = .appInfo
                appState.addHistory("ヘルプ: ライセンス")
            }

            Button("サポート依頼 (cmd+h+s)") {
                appState.activeModal = .bugReport
                appState.addHistory("ヘルプ: サポート依頼")
            }
        }
    }
}
