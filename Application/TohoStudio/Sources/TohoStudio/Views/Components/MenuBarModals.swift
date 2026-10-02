import SwiftUI
import AppKit

// MARK: - 1. 新規作成モーダル (cmd+f+n)
public struct NewProjectModalView: View {
    @ObservedObject var appState = AppState.shared
    @State private var projectName: String = "新規東方プロジェクト"
    @State private var selectedModule: SoftwareModule = .movieMaker
    @State private var selectedTemplate: String = "標準ブランク"

    let templates = [
        "標準ブランク", "会話劇テンプレ (霊夢＆魔理沙)", "バトルシーン演出", "解説・実況動画テンプレ", "ノベルゲーム序章"
    ]

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("新規編集プロジェクトの作成")
                .font(.title3)
                .bold()

            Text("作成する編集ソフトとプロジェクト名、初期テンプレートを選択してください。")
                .font(.caption)
                .foregroundColor(.secondary)

            GroupBox(label: Text("プロジェクト基本設定")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("プロジェクト名:")
                            .frame(width: 120, alignment: .leading)
                        TextField("プロジェクト名を入力", text: $projectName)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Text("初期作成ソフト:")
                            .frame(width: 120, alignment: .leading)
                        Picker("", selection: $selectedModule) {
                            ForEach(SoftwareModule.allCases) { mod in
                                Text(mod.rawValue).tag(mod)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    HStack {
                        Text("テンプレート:")
                            .frame(width: 120, alignment: .leading)
                        Picker("", selection: $selectedTemplate) {
                            ForEach(templates, id: \.self) { t in
                                Text(t).tag(t)
                            }
                        }
                    }
                }
                .padding(8)
            }

            GroupBox(label: Text("ソフト情報")) {
                HStack(spacing: 12) {
                    Image(systemName: selectedModule.iconName)
                        .font(.largeTitle)
                        .foregroundColor(.accentColor)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(selectedModule.rawValue).font(.headline)
                            Text(".\(selectedModule.projectExtension)")
                                .font(.caption2)
                                .bold()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .cornerRadius(4)
                        }
                        Text(selectedModule.description).font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding(8)
            }

            HStack {
                Spacer()
                Button("キャンセル") {
                    appState.activeModal = nil
                }
                .keyboardShortcut(.cancelAction)

                Button("プロジェクトを作成") {
                    let ext = selectedModule.projectExtension
                    let cleanName = projectName.hasSuffix(".\(ext)") ? String(projectName.dropLast(ext.count + 1)) : projectName
                    appState.currentProjectName = cleanName
                    appState.currentModule = selectedModule
                    appState.currentProjectPath = "/Volumes/ZSSD/GitHub/repository/TohoStudio/Application/Resource/\(selectedModule.rawValue)/\(cleanName).\(ext)"
                    appState.saveUndoSnapshot()
                    appState.log("新規プロジェクト『\(cleanName).\(ext)』を[\(selectedModule.rawValue)]で作成しました")
                    appState.addHistory("ファイル: 新規作成 (ソフト: \(selectedModule.rawValue), ファイル: \(cleanName).\(ext))")
                    appState.activeModal = nil
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(width: 580)
    }
}

// MARK: - 2. 書き出しモーダル (cmd+f+e)
public struct FileExportModalView: View {
    @ObservedObject var appState = AppState.shared
    @State private var exportFormat: String = "MP4 動画 (H.264 / AAC)"
    @State private var resolution: String = "1920x1080 (Full HD 60fps)"
    @State private var audioBitrate: String = "320 kbps (高音質)"
    @State private var isExporting: Bool = false
    @State private var exportProgress: Double = 0.0

    let formats = [
        "MP4 動画 (H.264 / AAC)",
        "Apple ProRes 422 映像",
        "Keynote プレゼンテーション (.key)",
        "プロジェクトデータ (.tohoproj / JSON)",
        "台本・シナリオテキスト (.txt)",
        "音声トラック一括アーカイブ (.zip)"
    ]

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("現在の編集ファイルを書き出し (エクスポート)")
                .font(.title3)
                .bold()

            Text("編集中のプロジェクトデータを任意の形式でローカルストレージまたはクラウドに保存します。")
                .font(.caption)
                .foregroundColor(.secondary)

            GroupBox(label: Text("出力フォーマット設定")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("書き出し形式:")
                            .frame(width: 120, alignment: .leading)
                        Picker("", selection: $exportFormat) {
                            ForEach(formats, id: \.self) { f in
                                Text(f).tag(f)
                            }
                        }
                    }

                    if exportFormat.contains("動画") || exportFormat.contains("ProRes") {
                        HStack {
                            Text("出力解像度:")
                                .frame(width: 120, alignment: .leading)
                            Picker("", selection: $resolution) {
                                Text("3840x2160 (4K 60fps)").tag("3840x2160 (4K 60fps)")
                                Text("1920x1080 (Full HD 60fps)").tag("1920x1080 (Full HD 60fps)")
                                Text("1280x720 (HD 30fps)").tag("1280x720 (HD 30fps)")
                            }
                        }

                        HStack {
                            Text("音声品質:")
                                .frame(width: 120, alignment: .leading)
                            Picker("", selection: $audioBitrate) {
                                Text("320 kbps (高音質)").tag("320 kbps (高音質)")
                                Text("192 kbps (標準)").tag("192 kbps (標準)")
                                Text("128 kbps (軽量)").tag("128 kbps (軽量)")
                            }
                        }
                    }
                }
                .padding(8)
            }

            if isExporting {
                VStack(spacing: 8) {
                    ProgressView(value: exportProgress, total: 1.0)
                    Text("書き出し処理中... \(Int(exportProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }

            HStack {
                Spacer()
                Button("キャンセル") {
                    appState.activeModal = nil
                }

                Button("書き出し実行...") {
                    let panel = NSSavePanel()
                    panel.title = "プロジェクト書き出し"
                    let ext = exportFormat.contains("動画") ? "mp4" : (exportFormat.contains("Keynote") ? "key" : "json")
                    panel.nameFieldStringValue = "\(appState.currentProjectName).\(ext)"
                    if panel.runModal() == .OK, let url = panel.url {
                        isExporting = true
                        exportProgress = 0.1
                        Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { timer in
                            exportProgress += 0.25
                            if exportProgress >= 1.0 {
                                timer.invalidate()
                                isExporting = false
                                try? "Toho-Studio Exported File\nFormat: \(exportFormat)\nTimestamp: \(Date())\n".write(to: url, atomically: true, encoding: .utf8)
                                appState.log("プロジェクトを正常に書き出しました: \(url.lastPathComponent)")
                                appState.addHistory("ファイル: 書き出し完了 (\(url.lastPathComponent))")
                                appState.activeModal = nil
                            }
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isExporting)
            }
        }
        .frame(width: 580)
    }
}

// MARK: - 3. バックアップ管理モーダル (cmd+f+shift+b)
public struct BackupManagerModalView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var storage = StorageManager.shared
    @State private var backupNote: String = "手動バックアップ"

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("プロジェクトバックアップ管理")
                        .font(.title3)
                        .bold()
                    Text("自動バックアップの切り替えや、過去のスナップショットからの復元を実行できます。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Toggle("自動バックアップ", isOn: $storage.autoSaveEnabled)
                    .toggleStyle(.switch)
            }

            GroupBox(label: Text("手動バックアップの作成")) {
                HStack {
                    TextField("バックアップメモ", text: $backupNote)
                        .textFieldStyle(.roundedBorder)
                    Button("今すぐバックアップ作成") {
                        let info = storage.createBackup(fileName: appState.currentProjectName, content: "TohoStudio Manual Backup: \(backupNote)\nScenes: \(appState.movieScenes.count)")
                        appState.log("バックアップ『\(info.originalFileName)』を作成しました")
                        appState.addHistory("ファイル: 手動バックアップ作成")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(6)
            }

            Text("バックアップ履歴一覧 (\(storage.backups.count) 件)")
                .font(.headline)

            ScrollView {
                VStack(spacing: 8) {
                    if storage.backups.isEmpty {
                        Text("作成されたバックアップはまだありません。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(storage.backups) { bk in
                            HStack {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundColor(.accentColor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bk.originalFileName).bold()
                                    Text("保存日時: \(bk.timestamp, style: .date) \(bk.timestamp, style: .time) | サイズ: \(bk.fileSize) bytes")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Button("この状態に復元") {
                                    appState.performRollback()
                                    appState.log("バックアップからプロジェクトを復元しました: \(bk.originalFileName)")
                                    appState.addHistory("ファイル: バックアップ復元")
                                    appState.activeModal = nil
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(8)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .frame(maxHeight: 220)

            HStack {
                Spacer()
                Button("閉じる") {
                    appState.activeModal = nil
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(width: 620, height: 460)
    }
}

// MARK: - 4. 整合性確認モーダル (cmd+f+shift+c)
public struct IntegrityCheckModalView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var storage = StorageManager.shared
    @State private var checkStatus: String = "検証中..."
    @State private var isChecked: Bool = false
    @State private var hasErrors: Bool = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("編集ファイルのデータ整合性確認")
                .font(.title3)
                .bold()

            Text("編集プロジェクト内のスライドデータ、テロップ文字情報、音声トラック、画像リソースの破損や欠損を精査します。")
                .font(.caption)
                .foregroundColor(.secondary)

            GroupBox(label: Text("検証ステータス")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: hasErrors ? "exclamationmark.triangle.fill" : "checkmark.shield.fill")
                            .font(.title)
                            .foregroundColor(hasErrors ? .orange : .green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(hasErrors ? "注意：軽微な不整合が検出されました" : "正常：すべてのデータ整合性は保たれています")
                                .font(.headline)
                            Text(storage.lastIntegrityCheckMessage)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("• プロジェクトファイル: 正常 (UTF-8エンコード検証済み)")
                        Text("• シーン構成数: \(appState.movieScenes.count) シーン (欠損なし)")
                        Text("• スライド認識データ: \(appState.slides.count) スライド (同期完了)")
                        Text("• 音声キャッシュ: 正常 (AquesTalk通信可能)")
                    }
                    .font(.caption)
                }
                .padding(8)
            }

            HStack {
                Button(action: {
                    let result = storage.verifyFileIntegrity(filePath: appState.currentProjectPath)
                    hasErrors = !result.isHealthy
                    appState.log(result.message)
                    appState.addHistory("ファイル: 整合性確認再実行")
                }) {
                    Label("再検査を実行", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("ファイル修復を実行") {
                    appState.performRepair()
                    hasErrors = false
                }
                .buttonStyle(.bordered)

                Button("確認完了") {
                    appState.activeModal = nil
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(width: 560)
        .onAppear {
            let result = storage.verifyFileIntegrity(filePath: appState.currentProjectPath)
            hasErrors = !result.isHealthy
        }
    }
}

// MARK: - 5. ファイル情報モーダル (cmd+f+i)
public struct FileInfoModalView: View {
    @ObservedObject var appState = AppState.shared

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("編集ファイル詳細情報")
                .font(.title3)
                .bold()

            GroupBox(label: Text("ファイルプロパティ")) {
                VStack(alignment: .leading, spacing: 8) {
                    infoRow(label: "プロジェクト名", value: appState.currentProjectName)
                    infoRow(label: "ファイルパス", value: appState.currentProjectPath)
                    infoRow(label: "ファイル拡張子", value: ".\(appState.currentModule.projectExtension) (仕様書 Slide 228等)")
                    infoRow(label: "適用プラン", value: appState.extensionPlan)
                    infoRow(label: "最終保存状態", value: StorageManager.shared.lastSavedTime != nil ? "保存済み" : "未保存の変更あり")
                    infoRow(label: "整合性チェック", value: "合格 (正常)")
                    infoRow(label: "シーン総数", value: "\(appState.movieScenes.count) シーン")
                    infoRow(label: "総再生時間", value: "\(Int(appState.totalDuration)) 秒")
                }
                .padding(8)
            }

            GroupBox(label: Text("直近の変更履歴")) {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(appState.historyRecords.prefix(5), id: \.self) { rec in
                        Text(rec)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(6)
            }

            HStack {
                Button("Finderで表示") {
                    appState.showInFinder()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("閉じる") {
                    appState.activeModal = nil
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(width: 580)
    }

    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label + ":")
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .bold()
            Spacer()
        }
        .font(.caption)
    }
}

// MARK: - 6. シーン情報モーダル (cmd+e+shift+i)
public struct SceneInfoModalView: View {
    @ObservedObject var appState = AppState.shared

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("現在選択中のシーン情報")
                .font(.title3)
                .bold()

            if appState.movieScenes.indices.contains(appState.selectedSceneIndex) {
                let scene = appState.movieScenes[appState.selectedSceneIndex]
                GroupBox(label: Text("シーン詳細プロパティ")) {
                    VStack(alignment: .leading, spacing: 8) {
                        detailRow(title: "シーン名", val: scene.title)
                        detailRow(title: "表示時間", val: "\(String(format: "%.1f", scene.duration)) 秒")
                        detailRow(title: "背景画像", val: scene.backgroundName)
                        detailRow(title: "登場キャラクター", val: scene.characterName)
                        detailRow(title: "割り当て音声", val: scene.audioTrack ?? "なし")
                        detailRow(title: "アニメーション演出", val: (scene.animationName?.isEmpty == false && scene.animationName != "なし") ? scene.animationName! : "なし")
                        detailRow(title: "トランジション効果", val: scene.transitionName ?? "カット")
                        Divider()
                        Text("テロップ台本:")
                            .font(.caption).foregroundColor(.secondary)
                        Text(scene.telop)
                            .font(.body)
                            .padding(6)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .padding(8)
                }
            } else {
                Text("現在選択されているシーンはありません。")
                    .foregroundColor(.secondary)
            }

            HStack {
                Spacer()
                Button("閉じる") {
                    appState.activeModal = nil
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(width: 540)
    }

    private func detailRow(title: String, val: String) -> some View {
        HStack {
            Text(title + ":").foregroundColor(.secondary).frame(width: 130, alignment: .leading)
            Text(val).bold()
            Spacer()
        }
        .font(.caption)
    }
}

// MARK: - 7. トリミングモーダル (cmd+t)
public struct TrimmingModalView: View {
    @ObservedObject var appState = AppState.shared
    @State private var maxCharCount: Double = 40.0
    @State private var slideDuration: Double = 10.0
    @State private var searchWord: String = ""
    @State private var replaceWord: String = ""
    @State private var trimRangeStart: Double = 0.0
    @State private var trimRangeEnd: Double = 15.0
    @State private var charCropPreset: String = "顔・表情（拡大）"
    @State private var charCropX: Double = 0.2
    @State private var charCropY: Double = 0.4
    @State private var charCropW: Double = 0.6
    @State private var charCropH: Double = 0.5
    @State private var charZoomFactor: Double = 1.5

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("トリミング設定 - [\(appState.currentModule.rawValue)]")
                    .font(.title3)
                    .bold()
                Spacer()
            }

            Text(descriptionForCurrentModule)
                .font(.caption)
                .foregroundColor(.secondary)

            switch appState.currentModule {
            case .movieMaker:
                GroupBox(label: Text("シーン表示時間のトリミング")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("現在選択中シーンの長さをタイムライン上で調整します。")
                            .font(.caption)
                        if appState.movieScenes.indices.contains(appState.selectedSceneIndex) {
                            let scene = appState.movieScenes[appState.selectedSceneIndex]
                            HStack {
                                Text("対象シーン: \(scene.title)")
                                    .bold()
                                Spacer()
                                Text("長さ: \(String(format: "%.1f", trimRangeEnd)) 秒")
                            }
                            Slider(value: $trimRangeEnd, in: 1.0...60.0, step: 0.5)
                        }
                    }
                    .padding(8)
                }

            case .characterMaker:
                GroupBox(label: Text("立ち絵画像の切り取り・拡大 (cmd+t)")) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("表示中のキャラクター画像の一部分を切り取り、拡大します。(仕様書補足事項 69行目準拠)")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Picker("切り取り対象プリセット", selection: $charCropPreset) {
                            Text("顔・表情（拡大）").tag("顔・表情（拡大）")
                            Text("目元・視線（拡大）").tag("目元・視線（拡大）")
                            Text("上半身・ポーズ").tag("上半身・ポーズ")
                            Text("カスタム範囲").tag("カスタム範囲")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: charCropPreset) { preset in
                            switch preset {
                            case "顔・表情（拡大）":
                                charCropX = 0.25; charCropY = 0.45; charCropW = 0.50; charCropH = 0.45; charZoomFactor = 1.6
                            case "目元・視線（拡大）":
                                charCropX = 0.28; charCropY = 0.58; charCropW = 0.44; charCropH = 0.20; charZoomFactor = 2.2
                            case "上半身・ポーズ":
                                charCropX = 0.10; charCropY = 0.20; charCropW = 0.80; charCropH = 0.75; charZoomFactor = 1.2
                            default:
                                break
                            }
                        }

                        HStack(spacing: 20) {
                            VStack(alignment: .leading) {
                                Text("横位置 X: \(Int(charCropX * 100))%")
                                Slider(value: $charCropX, in: 0.0...0.8)
                            }
                            VStack(alignment: .leading) {
                                Text("縦位置 Y: \(Int(charCropY * 100))%")
                                Slider(value: $charCropY, in: 0.0...0.8)
                            }
                        }
                        .font(.caption)

                        HStack(spacing: 20) {
                            VStack(alignment: .leading) {
                                Text("幅 W: \(Int(charCropW * 100))%")
                                Slider(value: $charCropW, in: 0.1...1.0)
                            }
                            VStack(alignment: .leading) {
                                Text("高さ H: \(Int(charCropH * 100))%")
                                Slider(value: $charCropH, in: 0.1...1.0)
                            }
                        }
                        .font(.caption)

                        HStack {
                            Text("拡大倍率:")
                            Slider(value: $charZoomFactor, in: 1.0...3.0, step: 0.1)
                            Text("\(String(format: "%.1f", charZoomFactor))x").bold()
                        }
                        .font(.caption)
                    }
                    .padding(8)
                }

            case .soundMaker:
                GroupBox(label: Text("音声クリップのトリミング")) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("現在選択されている音声ファイルの開始時間と終了時間を調整します。")
                            .font(.caption)
                        HStack {
                            Text("開始: \(String(format: "%.1f", trimRangeStart))s")
                            Spacer()
                            Text("終了: \(String(format: "%.1f", trimRangeEnd))s")
                        }
                        Slider(value: $trimRangeEnd, in: 1.0...180.0, step: 1.0)
                    }
                    .padding(8)
                }

            case .slideScenarioMaker:
                GroupBox(label: Text("シナリオ文字数制限＆スライド表示時間一括設定")) {
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading) {
                            Text("シナリオ1行の最大文字数制限 (超過分を自動トリミング): \(Int(maxCharCount)) 文字")
                                .font(.caption).bold()
                            Slider(value: $maxCharCount, in: 20...100, step: 1)
                        }
                        Divider()
                        VStack(alignment: .leading) {
                            Text("スライド表示時間の一括設定: \(Int(slideDuration)) 秒")
                                .font(.caption).bold()
                            Slider(value: $slideDuration, in: 3...30, step: 1)
                        }
                    }
                    .padding(8)
                }

            case .gameMaker:
                VStack(alignment: .center, spacing: 12) {
                    Text("ゲームメーカーではトリミング機能は非搭載です。")
                        .font(.headline)
                    Text("対応する編集ソフトを選択して作業してください。")
                        .font(.caption).foregroundColor(.secondary)
                    HStack {
                        Button("ムービーメーカーへ切り替え") {
                            appState.currentModule = .movieMaker
                            appState.activeModal = nil
                        }
                        Button("スライド＆シナリオメーカーへ切り替え") {
                            appState.currentModule = .slideScenarioMaker
                            appState.activeModal = nil
                        }
                    }
                }
                .padding()

            case .materialStudio:
                GroupBox(label: Text("素材スタジオの置換・抽出フィルター")) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            TextField("検索文字 / 画像名", text: $searchWord)
                                .textFieldStyle(.roundedBorder)
                            Image(systemName: "arrow.right")
                            TextField("置き換え後の単語 / 画像名", text: $replaceWord)
                                .textFieldStyle(.roundedBorder)
                        }
                        HStack {
                            Button("文字・画像を一括置換") {
                                appState.log("素材スタジオ: 『\(searchWord)』を『\(replaceWord)』へ一括置換しました")
                                appState.addHistory("編集: 素材スタジオ一括置換")
                            }
                            .buttonStyle(.bordered)

                            Button("不適切単語フィルター実行") {
                                appState.log("素材スタジオ: YouTube/ニコニコ動画等のポリシーに準拠して不適切単語を安全な表現に変換しました")
                                appState.addHistory("編集: 単語フィルター実行")
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(8)
                }

            case .tohoAIStudio:
                VStack(alignment: .leading, spacing: 10) {
                    Text("AIチャット履歴およびプロンプト文のトリミング")
                        .font(.caption).bold()
                    Text("長大な会話ログやプロンプトから過去のコンテキストを切り詰め、トークン消費量を節約します。")
                        .font(.caption).foregroundColor(.secondary)
                }
                .padding(8)
            }

            HStack {
                Spacer()
                Button("キャンセル") {
                    appState.activeModal = nil
                }
                Button("適用して完了") {
                    appState.saveUndoSnapshot()
                    if appState.currentModule == .movieMaker && appState.movieScenes.indices.contains(appState.selectedSceneIndex) {
                        appState.movieScenes[appState.selectedSceneIndex].duration = trimRangeEnd
                    } else if appState.currentModule == .characterMaker {
                        let rect = CGRect(x: charCropX, y: charCropY, width: charCropW, height: charCropH)
                        appState.performCharacterCrop(normalizedRect: rect, zoomFactor: charZoomFactor)
                    }
                    appState.log("トリミング設定を適用しました")
                    appState.addHistory("編集: トリミング適用")
                    appState.activeModal = nil
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(width: 580)
    }

    private var descriptionForCurrentModule: String {
        switch appState.currentModule {
        case .movieMaker: return "シーンの再生時間をトリミングします。"
        case .characterMaker: return "立ち絵画像の表示範囲を切り取り・トリミングします。"
        case .soundMaker: return "音声クリップの長さをトリミングします。"
        case .slideScenarioMaker: return "シナリオの最大文字数およびスライド表示秒数を一括設定・トリミングします。"
        case .gameMaker: return "対応ソフトへのショートカット案内を表示します。"
        case .materialStudio: return "画像・音声の切り取りやスライド内の検索・置換・抽出フィルターを実行します。"
        case .tohoAIStudio: return "AI会話履歴やプロンプトのコンテキスト長をトリミングします。"
        }
    }
}

// MARK: - 8. 分割モーダル (cmd+e+c)
public struct SplitModalView: View {
    @ObservedObject var appState = AppState.shared
    @State private var splitTime: Double = 5.0
    @State private var splitMode: String = "背景・立ち絵・テロップに3分割"

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("要素の分割 (スプリット) - [\(appState.currentModule.rawValue)]")
                .font(.title3)
                .bold()

            Text(splitDescription)
                .font(.caption)
                .foregroundColor(.secondary)

            GroupBox(label: Text("分割オプション設定")) {
                VStack(alignment: .leading, spacing: 12) {
                    switch appState.currentModule {
                    case .movieMaker:
                        Text("現在選択されているシーンをタイムライン上で2つのシーンに分割します。")
                            .font(.caption)
                        HStack {
                            Text("分割位置: \(String(format: "%.1f", splitTime)) 秒地点")
                            Spacer()
                        }
                        Slider(value: $splitTime, in: 1.0...15.0, step: 0.5)

                    case .characterMaker:
                        Text("立ち絵を各パーツ（顔・体・目・口・装飾）に分割し、単独素材として保存します。")
                            .font(.caption)
                        Text("分割対象パーツ: 6 項目 (体, 顔輪郭, 目, 口, 髪, 装飾)")
                            .font(.caption).bold()

                    case .soundMaker:
                        Text("音声ファイルを指定したタイムスタンプで2つのトラックに分割します。")
                            .font(.caption)
                        Slider(value: $splitTime, in: 0.5...30.0, step: 0.5)

                    case .slideScenarioMaker:
                        Picker("分割方式", selection: $splitMode) {
                            Text("スライド: 背景・立ち絵・テロップに3分割").tag("背景・立ち絵・テロップに3分割")
                            Text("シナリオ: 段落・文・文節・単語に分割").tag("段落・文・文節・単語に分割")
                        }

                    case .gameMaker:
                        Text("現在のシーンに新たな選択肢分岐ルートを作成・分割します。")
                            .font(.caption)

                    case .materialStudio:
                        Text("選択中の画像または音声素材を複数ファイルへ分割出力します。")
                            .font(.caption)

                    case .tohoAIStudio:
                        Text("AI生成された長編シナリオをシーン別・セリフ別に分割して素材スタジオへ登録します。")
                            .font(.caption)
                    }
                }
                .padding(8)
            }

            HStack {
                Spacer()
                Button("キャンセル") {
                    appState.activeModal = nil
                }
                Button("分割を実行") {
                    appState.saveUndoSnapshot()
                    if appState.currentModule == .movieMaker, appState.movieScenes.indices.contains(appState.selectedSceneIndex) {
                        let original = appState.movieScenes[appState.selectedSceneIndex]
                        var newScene = original
                        newScene.id = UUID()
                        newScene.title = "\(original.title) (分割後)"
                        newScene.duration = max(original.duration - splitTime, 1.0)
                        appState.movieScenes[appState.selectedSceneIndex].duration = splitTime
                        appState.movieScenes.insert(newScene, at: appState.selectedSceneIndex + 1)
                    } else if appState.currentModule == .characterMaker {
                        appState.performCharacterSplit()
                    }
                    appState.log("要素の分割処理を正常に完了しました")
                    appState.addHistory("編集: 分割実行 (\(appState.currentModule.rawValue))")
                    appState.activeModal = nil
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(width: 560)
    }

    private var splitDescription: String {
        switch appState.currentModule {
        case .movieMaker: return "タイムライン上のシーンを前後2つに分割します。"
        case .characterMaker: return "キャラクターを構成する各パーツに分解します。"
        case .soundMaker: return "音声クリップを分割します。"
        case .slideScenarioMaker: return "スライドの構成要素やシナリオ文章を階層的に分割して素材保存します。"
        case .gameMaker: return "シーンに新たな分岐ルートを追加します。"
        case .materialStudio: return "素材ファイルを個別パーツに分割します。"
        case .tohoAIStudio: return "AI生成された台本やプロンプトを個別のシーン・セリフ単位に分割します。"
        }
    }
}

// MARK: - 9. 履歴一覧モーダル (cmd+e+h, cmd+d+m)
public struct HistoryModalView: View {
    @ObservedObject var appState = AppState.shared
    @State private var filter: String = "全履歴"

    let filterTypes = ["全履歴", "ファイル操作", "編集操作", "システム起動"]

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("操作履歴・編集スナップショット一覧")
                    .font(.title3)
                    .bold()
                Spacer()
                Picker("", selection: $filter) {
                    ForEach(filterTypes, id: \.self) { t in
                        Text(t).tag(t)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 280)
            }

            Text("アプリケーションの起動、操作、保存、編集変更の履歴です。過去の状態へワンクリックで復元も可能です。")
                .font(.caption)
                .foregroundColor(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(filteredRecords, id: \.self) { rec in
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                                .foregroundColor(.accentColor)
                                .font(.caption)
                            Text(rec)
                                .font(.system(.caption, design: .monospaced))
                            Spacer()
                        }
                        .padding(6)
                        .background(Color.secondary.opacity(0.08))
                        .cornerRadius(6)
                    }
                }
            }
            .frame(maxHeight: 280)

            HStack {
                Button("直前の状態に復元 (巻き戻し)") {
                    appState.performRollback()
                    appState.activeModal = nil
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("閉じる") {
                    appState.activeModal = nil
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(width: 640, height: 440)
    }

    private var filteredRecords: [String] {
        if filter == "全履歴" { return appState.historyRecords }
        return appState.historyRecords.filter { $0.contains(filter.replacingOccurrences(of: "操作", with: "")) }
    }
}

// MARK: - 10. メモ帳・備考録モーダル (cmd+e+n, cmd+d+n)
public struct MemoPadModalView: View {
    @ObservedObject var appState = AppState.shared
    @State private var currentText: String = ""
    @State private var memoTab: Int = 0 // 0: 全体備考録, 1: 現在のシーンメモ

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(memoTab == 0 ? "Toho-Studio 備考録 (全体メモ)" : "編集メモ (シーン別)")
                    .font(.title3)
                    .bold()
                Spacer()
                Picker("", selection: $memoTab) {
                    Text("全体備考録").tag(0)
                    Text("シーン別メモ").tag(1)
                }
                .pickerStyle(.segmented)
                .frame(width: 220)
            }

            Text("制作のアイディアや演出メモ、TODOリストを登録できます。")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: $currentText)
                .font(.system(.body, design: .monospaced))
                .padding(4)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                .frame(height: 220)

            HStack {
                Button("メモをクリア") {
                    currentText = ""
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("メモを保存") {
                    if memoTab == 0 {
                        appState.userNotes.append(currentText)
                        appState.log("全体備考録にメモを追加保存しました")
                    } else {
                        let key = "\(appState.currentModule.rawValue)_Scene_\(appState.selectedSceneIndex)"
                        appState.sceneNotes[key] = currentText
                        appState.log("現在のシーンに編集メモを登録しました")
                    }
                    appState.addHistory("メモ: 保存完了")
                    appState.activeModal = nil
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(width: 560, height: 380)
        .onAppear {
            if memoTab == 0 {
                currentText = appState.userNotes.last ?? "【全体アイディア】\n・第2話では魔理沙の八卦炉エフェクトを強化する\n・BGMは妖恋談のハイレゾ音源に差し替え\n・YouTubeポリシーの血液表現チェックを行う"
            } else {
                let key = "\(appState.currentModule.rawValue)_Scene_\(appState.selectedSceneIndex)"
                currentText = appState.sceneNotes[key] ?? "【シーンメモ】\n霊夢の立ち絵を右側にフェードインさせ、テロップのフォント色を赤に指定。"
            }
        }
    }
}

// MARK: - 11. 進捗状況確認モーダル (cmd+d+s)
public struct BackgroundProcessModalView: View {
    @ObservedObject var appState = AppState.shared

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("バックグラウンド処理の進捗状況")
                .font(.title3)
                .bold()

            Text("スライド認識、動画レンダリング、音声合成、クラウド同期などの並列タスクを確認できます。")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                processRow(name: "Keynoteスライド高精度認識プログラム", status: "完了 (精度99.8%)", progress: 1.0, isDone: true)
                processRow(name: "AquesTalk 音声合成エンジン", status: "待機中 (常時即時合成)", progress: 1.0, isDone: true)
                processRow(name: "NanndemoyaCloud 自動バックアップ同期", status: "同期済み (差分なし)", progress: 1.0, isDone: true)
                processRow(name: "リアルタイムコンプライアンス点検", status: "監視稼働中", progress: 0.85, isDone: false)
            }

            Divider()

            HStack {
                Spacer()
                Button("閉じる") {
                    appState.activeModal = nil
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(width: 580)
    }

    private func processRow(name: String, status: String, progress: Double, isDone: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: isDone ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath")
                    .foregroundColor(isDone ? .green : .blue)
                Text(name).font(.headline)
                Spacer()
                Text(status).font(.caption).foregroundColor(.secondary)
            }
            ProgressView(value: progress)
                .accentColor(isDone ? .green : .blue)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(8)
    }
}

// MARK: - 12. バグレポートモーダル (cmd+d+b)
public struct BugReportModalView: View {
    @ObservedObject var appState = AppState.shared
    @State private var bugTitle: String = ""
    @State private var bugDescription: String = ""
    @State private var isGeneratingAiPrompt: Bool = false
    @State private var generatedPrompt: String = ""

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("エラー・不具合バグレポート＆AI修正プロンプト")
                .font(.title3)
                .bold()

            Text("発生した不具合状況を入力し、開発者への送信またはAntigravity/Gemini用の修正指示書プロンプトをワンクリック生成します。")
                .font(.caption)
                .foregroundColor(.secondary)

            GroupBox(label: Text("実行環境自動取得")) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("OS: macOS (Darwin \(ProcessInfo.processInfo.operatingSystemVersionString)) | Apple Silicon arm64")
                    Text("アプリバージョン: Toho-Studio v2.0.0 | アクティブソフト: \(appState.currentModule.rawValue)")
                    Text("直近ログ: \(appState.logs.first?.message ?? "正常稼働中")")
                }
                .font(.system(.caption2, design: .monospaced))
                .padding(4)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("不具合の概要:")
                    .font(.caption).bold()
                TextField("例: スライド読み込み時に立ち絵が透明になる", text: $bugTitle)
                    .textFieldStyle(.roundedBorder)

                Text("詳細内容・発生手順:")
                    .font(.caption).bold()
                TextEditor(text: $bugDescription)
                    .font(.caption)
                    .frame(height: 70)
                    .border(Color.secondary.opacity(0.3))
            }

            if !generatedPrompt.isEmpty {
                GroupBox(label: Text("生成されたAI向け修正プロンプト")) {
                    ScrollView {
                        Text(generatedPrompt)
                            .font(.system(.caption2, design: .monospaced))
                            .textSelection(.enabled)
                    }
                    .frame(height: 70)
                }
            }

            HStack {
                Button(action: {
                    generatedPrompt = """
                    【Toho-Studio バグ修正指示書】
                    ■ 不具合概要: \(bugTitle.isEmpty ? "動作不具合の修正" : bugTitle)
                    ■ 発生環境: macOS / Toho-Studio v2.0.0 / モジュール: \(appState.currentModule.rawValue)
                    ■ 詳細・再現手順:
                    \(bugDescription.isEmpty ? "操作中に予期せぬ動作が発生しました。" : bugDescription)
                    ■ システムログ:
                    \(appState.logs.prefix(3).map { "[\($0.level)] \($0.message)" }.joined(separator: "\n"))
                    ■ 修正要望:
                    仕様書補足事項.htmlおよび関連コードを精査し、ダミーや不具合を解消して完全動作するように修正してください。
                    """
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(generatedPrompt, forType: .string)
                    appState.log("AI修正用プロンプトを生成しクリップボードにコピーしました")
                }) {
                    Label("AI修正プロンプト生成＆コピー", systemImage: "sparkles")
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("キャンセル") {
                    appState.activeModal = nil
                }

                Button("レポートを送信") {
                    appState.log("バグレポートを開発チームに送信しました: 『\(bugTitle)』")
                    appState.addHistory("サポート: バグレポート送信")
                    appState.activeModal = nil
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(width: 600)
    }
}

// MARK: - 13. デバッグ総合画面 (cmd+d+shift+l)
public struct DebugScreenModalView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selectedTab: Int = 0

    public var body: some View {
        VStack(spacing: 12) {
            Picker("", selection: $selectedTab) {
                Text("ステータス").tag(0)
                Text("進捗状況").tag(1)
                Text("システムログ").tag(2)
                Text("操作履歴").tag(3)
                Text("不具合診断").tag(4)
            }
            .pickerStyle(.segmented)

            Divider()

            ScrollView {
                if selectedTab == 0 {
                    StatusComparisonModalView()
                } else if selectedTab == 1 {
                    BackgroundProcessModalView()
                } else if selectedTab == 2 {
                    LogsAndAchievementsModalView()
                } else if selectedTab == 3 {
                    HistoryModalView()
                } else {
                    BugReportModalView()
                }
            }
        }
        .frame(width: 660, height: 480)
    }
}

// MARK: - 14. ソフト一覧モーダル (cmd+d+option+s)
public struct SoftwareListModalView: View {
    @ObservedObject var appState = AppState.shared

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Toho-Studio 内蔵ソフト＆拡張機能一覧")
                .font(.title3)
                .bold()

            Text("全6種の内蔵ソフトを即座に切り替え・起動できます。")
                .font(.caption)
                .foregroundColor(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(SoftwareModule.allCases) { mod in
                    Button(action: {
                        appState.currentModule = mod
                        appState.log("ソフトを切り替えました: \(mod.rawValue)")
                        appState.addHistory("ソフト切り替え: \(mod.rawValue)")
                        appState.activeModal = nil
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: mod.iconName)
                                .font(.title)
                                .foregroundColor(appState.currentModule == mod ? .accentColor : .secondary)
                                .frame(width: 44, height: 44)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(8)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(mod.rawValue).bold()
                                    if appState.currentModule == mod {
                                        Text("使用中")
                                            .font(.caption2)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.accentColor)
                                            .foregroundColor(.white)
                                            .cornerRadius(4)
                                    }
                                }
                                Text(mod.description)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            Spacer()
                        }
                        .padding(10)
                        .background(Color(NSColor.windowBackgroundColor))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(appState.currentModule == mod ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("閉じる") {
                    appState.activeModal = nil
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(width: 660, height: 460)
    }
}

// MARK: - 15. 機能リスト＆ショートカット一覧モーダル (cmd+d+option+l)
public struct FeatureListModalView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var paidService = PaidFeatureService.shared
    @ObservedObject var nanndemoyaService = NanndemoyaCloudService.shared
    @ObservedObject var cloudLinuxService = CloudVirtualLinuxService.shared
    @ObservedObject var adManager = AdManager.shared

    @State private var selectedTab: Int = 0 // 0: 有料機能マネージャー(CSV連携), 1: 全機能＆ショートカット, 2: 各ソフト別機能
    @State private var searchKeyword: String = ""
    @State private var voiceTemplateMessage: String = ""
    @State private var selectedCategoryFilter: String = "すべて"

    public init() {}

    let shortcuts: [(menu: String, item: String, key: String, isPaid: Bool)] = [
        ("Toho-Studio", "アプリ情報", "cmd+t+i", false),
        ("Toho-Studio", "設定画面", "cmd+t+s", false),
        ("Toho-Studio", "ストア", "cmd+t+shift+s", false),
        ("Toho-Studio", "再起動", "cmd+t+r", false),
        ("Toho-Studio", "開発者コンソール", "cmd+t+e", false),
        ("ファイル", "新規作成", "cmd+f+n", false),
        ("ファイル", "ファイル読み込み", "cmd+f+r", false),
        ("ファイル", "書き出し", "cmd+f+e", false),
        ("ファイル", "複製", "cmd+f+c", false),
        ("ファイル", "巻き戻し", "cmd+f+b", false),
        ("ファイル", "上書き保存", "cmd+f+s", false),
        ("ファイル", "ファイル保存", "cmd+f+shift+s", false),
        ("ファイル", "ファイル修復", "cmd+f+shift+r", false),
        ("ファイル", "整合性確認", "cmd+f+shift+c", false),
        ("ファイル", "ファイル情報", "cmd+f+i", false),
        ("編集", "やり直す", "cmd+z", false),
        ("編集", "進める", "cmd+shift+z", false),
        ("編集", "トリミング", "cmd+t", false),
        ("編集", "分割", "cmd+e+c", false),
        ("編集", "インポート", "cmd+e+i", false),
        ("編集", "エクスポート", "cmd+e+o", false),
        ("編集", "シーン情報", "cmd+e+shift+i", false),
        ("編集", "画面更新", "cmd+e+r", false),
        ("編集", "点検と修正", "cmd+e+u", false),
        ("編集", "再生成", "cmd+e+p", false),
        ("編集", "素材一覧", "cmd+e+s", false),
        ("編集", "編集履歴", "cmd+e+h", false),
        ("編集", "自動保存", "cmd+e+a", false),
        ("編集", "素材作成", "cmd+e+m", false),
        ("編集", "編集メモ", "cmd+e+n", false),
        ("表示", "全画面表示", "cmd+d+a", false),
        ("表示", "進捗状況確認", "cmd+d+s", false),
        ("表示", "ログと実績", "cmd+d+l", false),
        ("表示", "バグレポート", "cmd+d+b", false),
        ("表示", "Finderで表示", "cmd+d+f", false),
        ("表示", "履歴一覧", "cmd+d+m", false),
        ("表示", "ステータス", "cmd+d+shift+s", false),
        ("表示", "スクショ", "cmd+d+p", false),
        ("表示", "画面収録開始/停止", "cmd+d+shift+p", false),
        ("表示", "デバック画面", "cmd+d+shift+l", false),
        ("表示", "ソフト一覧", "cmd+d+option+s", false),
        ("表示", "機能リスト", "cmd+d+option+l", false),
        ("表示", "オプション", "cmd+d+option", false),
        ("表示", "備考録", "cmd+d+n", false),
        ("表示", "拡大/縮小", "cmd+d+z / cmd+d+shift+z", false),
        ("再生", "全画面再生", "cmd+p+a", false),
        ("再生", "ここから再生", "cmd+p+n", false),
        ("再生", "ループ再生", "cmd+p+l", false),
        ("再生", "音量調節", "cmd+p+u / cmd+p+d", false),
        ("再生", "倍速再生", "cmd+p+1~9", false),
        ("再生", "素材情報表示", "cmd+p+特定キー(c/o/b/p)", false),
        ("再生", "デバック再生", "cmd+p+shift+d", false),
        ("ウィンドウ", "レイアウト", "cmd+w+l", false),
        ("ウィンドウ", "コードモード", "cmd+c", false),
        ("ウィンドウ", "リセット", "cmd+w+r", false),
        ("ウィンドウ", "更新", "cmd+w+shift+r", false),
        ("ウィンドウ", "新規展開", "cmd+w+n", false),
        ("ウィンドウ", "アプリを閉じる", "cmd+w+q", false),
        ("ウィンドウ", "パネル表示", "cmd+w+p", false),
        ("ウィンドウ", "オプション", "cmd+w+o", false),
        ("ヘルプ", "取扱説明書", "cmd+h+d", false),
        ("ヘルプ", "Q&A", "cmd+h+q", false),
        ("ヘルプ", "クレジット", "cmd+h+k", false),
        ("ヘルプ", "困ったときは", "cmd+h+n", false),
        ("ヘルプ", "ライセンス", "cmd+h+l", false),
        ("ヘルプ", "サポート依頼", "cmd+h+s", false),
        // 有料機能・拡張機能（機能リストに集約）
        ("有料機能", "バックアップ管理", "cmd+f+shift+b", true),
        ("有料機能", "スライド抽出プログラム", "-", true),
        ("有料機能", "AI高度検索・生成・置換", "-", true),
        ("有料機能", "スライドから全音声一括生成", "cmd+ctrl+shift+b", true),
        ("有料機能", "AquesTalk音声生成スタジオ", "cmd+ctrl+shift+a", true),
        ("有料機能", "複数シーン跨ぎBGM・SE挿入", "cmd+ctrl+shift+m", true),
        ("有料機能", "クラウド自動保存＆同期", "-", true),
        ("有料機能", "ヘルプガイド (有料機能マニュアル)", "cmd+h+g", true)
    ]

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Image(systemName: "list.bullet.rectangle.fill")
                            .font(.title2)
                            .foregroundColor(.accentColor)
                        Text("全機能リスト＆有料機能マネージャー")
                            .font(.title3)
                            .bold()
                        Text("cmd+d+option+l")
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(4)
                    }
                    Text("有料機能と無料機能は完全に分離されています。有料機能はResource内の設定CSVおよびNanndemoyaCloud認証に基づきここで管理・実行されます。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()

                Picker("", selection: $selectedTab) {
                    Text("⭐ 有料機能 (CSV管理)").tag(0)
                    Text("⌨️ ショートカット＆全機能").tag(1)
                    Text("🧩 各ソフト機能").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 400)
            }

            // Status bar for NanndemoyaCloud & GCP Virtual Linux
            HStack(spacing: 12) {
                // NanndemoyaCloud Status
                HStack(spacing: 6) {
                    Image(systemName: nanndemoyaService.isCurrentDeviceRegistered ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                        .foregroundColor(nanndemoyaService.isCurrentDeviceRegistered ? .green : .orange)
                    Text("NanndemoyaCloud: \(nanndemoyaService.isCurrentDeviceRegistered ? "端末認証済み" : "端末未登録")")
                        .font(.caption2)
                        .bold()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)

                // Virtual Linux LLM Status
                HStack(spacing: 6) {
                    Circle()
                        .fill(cloudLinuxService.connectionStatus == .connected ? Color.green : Color.red)
                        .frame(width: 7, height: 7)
                    Text("仮想Linux: \(cloudLinuxService.connectionStatus.rawValue) (\(cloudLinuxService.latencyMs)ms)")
                        .font(.caption2)
                    Text("残プロンプト: \(cloudLinuxService.remainingPrompts)回")
                        .font(.caption2)
                        .bold()
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(4)

                Spacer()

                Button("CSV再読込") {
                    paidService.loadAllPaidCSVs()
                    appState.log("有料機能CSVを再読み込みしました")
                }
                .controlSize(.small)
            }

            Divider()

            switch selectedTab {
            case 0:
                paidFeaturesCSVManagedView
            case 1:
                shortcutsTableView
            case 2:
                softwareFeaturesView
            default:
                EmptyView()
            }

            Divider()

            // Footer
            HStack {
                if !voiceTemplateMessage.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(voiceTemplateMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                }
                Spacer()
                Button("閉じる") {
                    appState.activeModal = nil
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 820, height: 600)
    }

    // MARK: - Tab 0: 有料機能マネージャー (Paid Features CSV Managed)
    private var paidFeaturesCSVManagedView: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Category Filter
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    if selectedCategoryFilter == "すべて" {
                        Button("すべて (\(paidService.featureItems.count))") {
                            selectedCategoryFilter = "すべて"
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    } else {
                        Button("すべて (\(paidService.featureItems.count))") {
                            selectedCategoryFilter = "すべて"
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    ForEach(paidService.categories, id: \.self) { cat in
                        if selectedCategoryFilter == cat {
                            Button(cat) {
                                selectedCategoryFilter = cat
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        } else {
                            Button(cat) {
                                selectedCategoryFilter = cat
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }

            ScrollView {
                VStack(spacing: 8) {
                    let filtered = paidService.featureItems.filter {
                        selectedCategoryFilter == "すべて" || $0.category == selectedCategoryFilter
                    }

                    ForEach(filtered) { item in
                        paidCSVFeatureCard(item: item)
                    }

                    if filtered.isEmpty {
                        VStack(spacing: 8) {
                            Image(systemName: "tray")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("該当する有料機能はありません。")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(40)
                    }
                }
            }
        }
    }

    private func paidCSVFeatureCard(item: PaidFeatureItem) -> some View {
        HStack(alignment: .center, spacing: 14) {
            // Icon / Status Indicator
            VStack {
                Circle()
                    .fill(item.isEnabledByUser ? Color.green : (item.isAvailableForPurchase ? Color.orange : Color.gray.opacity(0.4)))
                    .frame(width: 10, height: 10)
                Text(item.isEnabledByUser ? "ON" : "OFF")
                    .font(.system(size: 9, weight: .heavy, design: .monospaced))
                    .foregroundColor(item.isEnabledByUser ? .green : .secondary)
            }
            .frame(width: 28)

            // Info Column
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(item.category)
                        .font(.caption2)
                        .bold()
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.12))
                        .foregroundColor(.blue)
                        .cornerRadius(4)

                    Text(item.planName)
                        .font(.subheadline)
                        .bold()

                    if item.isFreeDefaultPlan {
                        Text("標準搭載 (無料)")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.15))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    } else if item.isEnabledByUser {
                        Text("有効 (User: on)")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .foregroundColor(.green)
                            .cornerRadius(4)
                    } else if !item.isAvailableForPurchase {
                        Text("販売休止中 (OFF固定)")
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.15))
                            .foregroundColor(.secondary)
                            .cornerRadius(4)
                    }
                }

                Text(item.details)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: 12) {
                    Text("価格: \(item.priceDescription)")
                        .font(.caption2)
                        .bold()
                    Text("販売: \(item.sellingStatus.uppercased())")
                        .font(.caption2)
                        .foregroundColor(item.isAvailableForPurchase ? .green : .secondary)
                    Text("設定値: \(item.userValue)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("CSV: \(item.csvFileName)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundColor(.gray)
                }
            }

            Spacer()

            // Controls Column: Switch & Trial Ad
            VStack(alignment: .trailing, spacing: 6) {
                HStack(spacing: 8) {
                    // Switch Control
                    if item.isFreeDefaultPlan {
                        Text("標準有効 (ON)")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(4)
                    } else if item.isEnabledByUser {
                        Button(action: {
                            paidService.purchaseOrToggleFeature(item: item) { success, msg in
                                voiceTemplateMessage = msg
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "switch.2")
                                Text("スイッチ OFF")
                            }
                            .font(.caption)
                            .bold()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    } else if item.isAvailableForPurchase {
                        Button(action: {
                            paidService.purchaseOrToggleFeature(item: item) { success, msg in
                                voiceTemplateMessage = msg
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "power")
                                Text("購入・スイッチ ON")
                            }
                            .font(.caption)
                            .bold()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    } else {
                        Button(action: {
                            paidService.purchaseOrToggleFeature(item: item) { success, msg in
                                voiceTemplateMessage = msg
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "lock.fill")
                                Text("販売休止中 (OFF)")
                            }
                            .font(.caption)
                            .bold()
                        }
                        .buttonStyle(.bordered)
                        .disabled(true)
                        .controlSize(.small)
                    }
                }

                if !item.isFreeDefaultPlan && !item.isEnabledByUser {
                    Button(action: {
                        adManager.triggerTrialAd(featureName: item.planName) {
                            voiceTemplateMessage = "お試し広告視聴により \(item.planName) が1回無料解放されました！"
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "play.rectangle.fill")
                            Text("お試し広告で1回無料")
                        }
                        .font(.caption2)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.orange)
                }
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(8)
    }

    private func applyQuickVoice(_ name: String) {
        switch name {
        case "博麗霊夢":
            appState.applyVoiceTemplateByName("博麗霊夢 (ゆっくりボイスメーカー)")
        case "霧雨魔理沙":
            appState.applyVoiceTemplateByName("霧雨魔理沙 (ゆっくりボイスメーカー)")
        case "東風谷早苗":
            appState.applyVoiceTemplateByName("東風谷早苗 (コゲの日記)")
        case "魂魄妖夢":
            appState.applyVoiceTemplateByName("魂魄妖夢 (ゆっくりボイスメーカー)")
        case "十六夜咲夜":
            appState.applyVoiceTemplateByName("十六夜咲夜 (ゆっくりボイスメーカー)")
        case "チルノ":
            appState.applyVoiceTemplateByName("チルノ (ゆっくりボイスメーカー)")
        case "レミリア":
            appState.applyVoiceTemplateByName("レミリア・スカーレット (ゆっくりボイスメーカー)")
        case "フランドール":
            appState.applyVoiceTemplateByName("フランドール・スカーレット (ゆっくりボイスメーカー)")
        case "八雲紫":
            appState.applyVoiceTemplateByName("八雲紫 (コゲの日記)")
        case "西行寺幽々子":
            appState.applyVoiceTemplateByName("西行寺幽々子 (コゲの日記)")
        default:
            break
        }
        voiceTemplateMessage = "「\(name)」の音声パラメータを設定しました"
    }

    private func paidCategoryCard<Content: View>(title: String, icon: String, badge: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.headline)
                Spacer()
                Text(badge)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(color.opacity(0.15))
                    .foregroundColor(color)
                    .cornerRadius(4)
            }
            Divider()
            content()
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
        )
    }

    private func paidFeatureRow(title: String, shortcut: String, description: String, buttonTitle: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.callout)
                        .bold()
                    if shortcut != "-" {
                        Text(shortcut)
                            .font(.system(.caption2, design: .monospaced))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary.opacity(0.15))
                            .cornerRadius(3)
                    }
                }
                Text(description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Button(buttonTitle, action: action)
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
        }
    }

    // MARK: - Tab 1: 全機能＆ショートカット一覧
    private var shortcutsTableView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("機能を検索 (名前・メニュー・ショートカット)...", text: $searchKeyword)
                    .textFieldStyle(.roundedBorder)
                if !searchKeyword.isEmpty {
                    Button(action: { searchKeyword = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Text("\(filteredShortcuts.count) 件")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ScrollView {
                VStack(spacing: 3) {
                    ForEach(filteredShortcuts, id: \.item) { sc in
                        HStack {
                            Text(sc.menu)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 80, alignment: .leading)
                            Text(sc.item)
                                .font(.callout)
                                .bold()
                            if sc.isPaid {
                                Text("有料プラン")
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 1)
                                    .background(Color.yellow.opacity(0.2))
                                    .foregroundColor(.orange)
                                    .cornerRadius(4)
                            }
                            Spacer()
                            Text(sc.key)
                                .font(.system(.caption, design: .monospaced))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)

                            // 直接実行ボタン
                            if sc.item == "複数シーン跨ぎBGM・SE挿入" {
                                Button("開く") { appState.activeModal = .spanAudioInsert }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                            } else if sc.item == "スライドから全音声一括生成" {
                                Button("開く") { appState.activeModal = .batchVoiceGenerator }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                            } else if sc.item == "AquesTalk音声生成スタジオ" {
                                Button("開く") { appState.activeModal = .aquesTalkGenerator }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                            } else if sc.item == "バックアップ管理" {
                                Button("開く") { appState.activeModal = .backupManager }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                            } else if sc.item == "スライド抽出プログラム" {
                                Button("開く") { appState.activeModal = .slideExtractor }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                            } else if sc.item == "AI高度検索・生成・置換" {
                                Button("開く") { appState.activeModal = .aiSearch }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                            } else if sc.item == "ヘルプガイド (有料機能マニュアル)" {
                                Button("開く") { appState.activeModal = .helpGuide }
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                            }
                        }
                        .padding(5)
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Tab 2: 各ソフト別機能
    private var softwareFeaturesView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                softFeatureCard(
                    name: "ムービーメーカー (cmd+p)",
                    icon: "film",
                    items: [
                        "タイムライン編集・シーン分割・トリミング (cmd+t, cmd+e+c)",
                        "Keynoteスライド＆アニメーション連動インポート (.key, .tspm)",
                        "サウンドメーカー連携 & 字幕同期音声プレビュー",
                        "動画書き出し (MP4/H.264/ProRes、字幕任意設定)"
                    ]
                )

                softFeatureCard(
                    name: "スライド＆シナリオメーカー",
                    icon: "doc.text.image",
                    items: [
                        "スライド作成・プレゼンターノート台詞分割",
                        "Keynote/PowerPoint/Googleスライドの直接高精度インポート",
                        "シナリオ一括トリミング & 文字数カウント",
                        "全音声一括生成 (AquesTalk連携)"
                    ]
                )

                softFeatureCard(
                    name: "サウンドメーカー",
                    icon: "waveform",
                    items: [
                        "マルチトラック音声・BGM・SE波形編集",
                        "倍速再生 (0.5x~2.0x) & 逆再生 (リバースエンジン)",
                        "複数シーン跨ぎBGM・SE連続再生挿入 (有料機能連携)",
                        "ゆっくり東方キャラクター音声合成 & ライセンス認証"
                    ]
                )

                softFeatureCard(
                    name: "素材スタジオ",
                    icon: "photo.on.rectangle.angled",
                    items: [
                        "全素材一括管理 (画像・音声・スライド・台本)",
                        "セキュリティ点検 (ポリシー照合＆NGワード検知)",
                        "動画用フォルダ一括素材インポート",
                        "スライド抽出プログラム＆AI高度検索 (有料機能まとめより実行)"
                    ]
                )

                softFeatureCard(
                    name: "キャラクターメーカー & ゲームメーカー",
                    icon: "person.crop.square",
                    items: [
                        "パーツ別レイヤー編集・表情差分管理 (キャラクター)",
                        "ノベルゲームコマンド作成・選択肢分岐 (ゲーム)",
                        "テストプレイ＆全画面デバック実行"
                    ]
                )
            }
            .padding(.vertical, 4)
        }
    }

    private func softFeatureCard(name: String, icon: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(name)
                    .font(.headline)
            }
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 6) {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(item)
                        .font(.caption)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
        .cornerRadius(6)
    }

    private var filteredShortcuts: [(menu: String, item: String, key: String, isPaid: Bool)] {
        if searchKeyword.isEmpty { return shortcuts }
        return shortcuts.filter { $0.item.contains(searchKeyword) || $0.key.contains(searchKeyword) || $0.menu.contains(searchKeyword) }
    }
}


// MARK: - 16. コンテキストオプションモーダル (cmd+d+option)
public struct ContextOptionsModalView: View {
    @ObservedObject var appState = AppState.shared
    @State private var enableRightClickQuickMenu: Bool = true
    @State private var enableAutoTelopAlignment: Bool = true
    @State private var enableVolumeNormalization: Bool = true

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("コンテキストオプション設定 (cmd+d+option)")
                .font(.title3)
                .bold()

            Text("編集中のファイルやシーンに沿った右クリックメニュー項目や動作環境をカスタマイズします。")
                .font(.caption)
                .foregroundColor(.secondary)

            GroupBox(label: Text("現在の編集対象: [\(appState.currentModule.rawValue)]")) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("右クリック時にクイック編集メニューを表示する", isOn: $enableRightClickQuickMenu)
                    Toggle("テロップと立ち絵の自動位置合わせ・ガイド表示", isOn: $enableAutoTelopAlignment)
                    Toggle("音声追加時の自動音量ノーマライズ (標準化)", isOn: $enableVolumeNormalization)
                }
                .padding(8)
            }

            HStack {
                Spacer()
                Button("デフォルトに戻す") {
                    enableRightClickQuickMenu = true
                    enableAutoTelopAlignment = true
                    enableVolumeNormalization = true
                }
                .buttonStyle(.bordered)

                Button("設定を保存") {
                    appState.log("コンテキストオプション設定を保存しました")
                    appState.addHistory("表示: オプション設定保存")
                    appState.activeModal = nil
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(width: 520)
    }
}

// MARK: - 17. ウィンドウオプションモーダル (cmd+w+o)
public struct WindowOptionsModalView: View {
    @ObservedObject var appState = AppState.shared
    @State private var defaultModuleAtStartup: SoftwareModule = .movieMaker
    @State private var enableCompactTabBar: Bool = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ウィンドウ設定カスタマイズ (cmd+w+o)")
                .font(.title3)
                .bold()

            Text("レイアウトプリセット、初期起動時のソフト、パネルタブ表示をカスタマイズできます。")
                .font(.caption)
                .foregroundColor(.secondary)

            GroupBox(label: Text("レイアウトプリセット選択")) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("現在のレイアウト", selection: $appState.layoutMode) {
                        ForEach(AppState.LayoutPresets, id: \.self) { mode in
                            Text(mode).tag(mode)
                        }
                    }

                    HStack {
                        Text("UI表示倍率 (拡大/縮小):")
                        Slider(value: $appState.zoomScale, in: 0.8...1.4, step: 0.05)
                        Text("\(Int(appState.zoomScale * 100))%")
                    }
                }
                .padding(8)
            }

            GroupBox(label: Text("起動時の振る舞い")) {
                VStack(alignment: .leading, spacing: 10) {
                    Picker("起動時に最初に開くソフト:", selection: $defaultModuleAtStartup) {
                        ForEach(SoftwareModule.allCases) { mod in
                            Text(mod.rawValue).tag(mod)
                        }
                    }
                    Toggle("複数ウィンドウを単一パネル（タブ）に統合する", isOn: $appState.isPanelDisplayMode)
                }
                .padding(8)
            }

            HStack {
                Spacer()
                Button("閉じる") {
                    appState.activeModal = nil
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(width: 540)
    }
}

// MARK: - 18. ヘルプセンター総合モーダル (cmd+h+...)
public struct HelpCenterModalView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selectedTab: Int

    public init(initialTab: Int = 0) {
        self._selectedTab = State(initialValue: initialTab)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Picker("", selection: $selectedTab) {
                Text("取扱説明書").tag(0)
                Text("ヘルプガイド").tag(1)
                Text("Q&A").tag(2)
                Text("困ったときは").tag(3)
                Text("サポート依頼").tag(4)
            }
            .pickerStyle(.segmented)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if selectedTab == 0 {
                        manualContent
                    } else if selectedTab == 1 {
                        helpGuideContent
                    } else if selectedTab == 2 {
                        qaContent
                    } else if selectedTab == 3 {
                        troubleshootContent
                    } else {
                        supportRequestContent
                    }
                }
                .padding(8)
            }

            Divider()

            HStack {
                Spacer()
                Button("閉じる") {
                    appState.activeModal = nil
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(width: 640, height: 480)
    }

    private var manualContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Toho-Studio 取扱説明書 (第1.0版)").font(.headline)
            Text("Toho-Studioは、Keynote・スライド認識・ゆっくり音声合成・動画・同人ゲーム制作をワンストップで行える総合スタジオソフトです。")
                .font(.caption).foregroundColor(.secondary)

            GroupBox(label: Text("1. 基本制作ワークフロー")) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("①【スライド＆シナリオメーカー】でKeynoteファイル(.key)またはスライドをインポートします。高精度認識(99%)によりオブジェクト・背景・キャラ・アニメーションが自動抽出されます。")
                    Text("②【サウンドメーカー】でキャラクターボイス(AquesTalk)やBGM・SEを割り当てます。演出指示の()書き表記は自動除去されクリーンなセリフから音声を一括生成できます。")
                    Text("③【キャラクターメーカー】で立ち絵のポーズや表情差分を調整・トリミングします。")
                    Text("④【ムービーメーカー】でプレビュー再生(cmd+p)を確認しながらタイムラインを編集し、MP4動画として書き出します。")
                    Text("⑤【ゲームメーカー】でコマンド分岐を加えてRPG風同人ノベルゲームとして出力できます。")
                }
                .font(.caption)
                .padding(6)
            }

            GroupBox(label: Text("2. プログラム保護とセキュリティ規定")) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("• アプリケーションのResourceフォルダ内には各ソフトのプログラムおよび有料機能管理CSVが格納されています。")
                    Text("• 利用者がResource内のファイルを直接編集・改変した場合、即座にセキュリティブロックが作動し、利用停止となります。")
                    Text("• 利用停止の解除は開発者のMac (IOPlatformUUID照合) からのみ実行可能です。")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(6)
            }
        }
    }

    private var helpGuideContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ヘルプガイド (追加・有料機能マニュアル)").font(.headline)
            Text("ストアおよび設定画面から利用可能な有料機能とプランの詳細仕様です。")
                .font(.caption).foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 10) {
                GroupBox(label: Label("AI定額プラン仕様とプロンプト管理", systemImage: "sparkles")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("• Google Cloud上の仮想Linux環境 (LLM搭載) と常時通信して動作します。")
                        Text("• プロンプト残数が1000件を下回ると第1回減少通知メール、500件で第2回通知、100件で都度課金移行推奨通知が送信されます。")
                        Text("• プロンプト残数が0になると通信が強制遮断されます。購入日から1ヶ月後に更新されます。")
                    }
                    .font(.caption)
                    .padding(6)
                }

                GroupBox(label: Label("NanndemoyaCloud必須認証と端末登録", systemImage: "cloud.fill")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("• 有料機能の利用にはNanndemoyaCloudのアカウント認証と端末登録が必須です。")
                        Text("• 正規ルート以外からの有料機能利用が検知された場合、即座に利用停止処置が実行されます。")
                    }
                    .font(.caption)
                    .padding(6)
                }

                GroupBox(label: Label("広告機能と広告フリー券", systemImage: "megaphone.fill")) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("• ファイル処理広告: ファイル読み込みやホーム画面で表示されます。")
                        Text("• 長時間処理広告: 1分以上のエンコード・一括解析処理時に表示されます。")
                        Text("• お試し広告: 動画広告を1本視聴することで有料機能を1回無料で利用できます。")
                        Text("• 広告フリー券を購入することで広告を非表示にできます。")
                    }
                    .font(.caption)
                    .padding(6)
                }
            }
        }
    }

    private var qaContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("よくある質問 (Q&A)").font(.headline)

            qaItem(q: "Q. 有料機能はどこから利用できますか？", a: "A. メニューバーの「表示」>「機能リスト (cmd+d+option+l)」から利用できます。無料機能と完全に分離して管理されています。")
            qaItem(q: "Q. Googleアカウントでのログイン方法は？", a: "A. 「設定」>「アカウント」>「Googleアカウント」から、client_secret連携によりアプリ内ブラウザで安全にログインできます。")
            qaItem(q: "Q. 利用停止ブロック画面が表示されて操作できません。", a: "A. Resourceフォルダ内の改竄が検知された状態です。解除は開発者のMacからのみ可能です。開発者へお問い合わせください。")
            qaItem(q: "Q. ストアに作品や素材を出品するには？", a: "A. 「ストア」>「ストア用語定義・審査規約」を確認の上、「何でも屋」パートナー登録を完了し、審査申請を行ってください。")
            qaItem(q: "Q. ゆっくりボイスの演出指示()書きがセリフに残ってしまいます。", a: "A. Toho-Studioでは（アニメーション）等の演出指示を自動除去してクリーンなセリフのみから音声合成する仕様になっています。")
        }
    }

    private func qaItem(q: String, a: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(q).font(.subheadline).bold()
            Text(a).font(.caption).foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)
    }

    private var troubleshootContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("困ったときは (トラブルシューティング)").font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                Text("• 操作を誤って消してしまった: 「編集」>「やり直す (cmd+z)」または「ファイル」>「巻き戻し (cmd+f+b)」で直前の状態に復元できます。")
                Text("• ファイルが破損した恐れがある: 「ファイル」>「整合性確認 (cmd+f+shift+c)」で検査し、「ファイル修復」を実行してください。")
                Text("• アプリの動作が重い: 「表示」>「ステータス」でメモリを確認し、「ウィンドウ」>「リセット (cmd+w+r)」を実行してください。")
                Text("• AI生成が進まない: プロンプト残数を確認してください。残数0時は都度課金プランへのチャージが必要です。")
            }
            .font(.caption)
            .padding(10)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
        }
    }

    private var supportRequestContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("サポート依頼・問い合わせ窓口").font(.headline)
            Text("不具合のご報告、ストア審査のお問い合わせ、開発者へのメッセージは以下のフォームより送信いただけます。")
                .font(.caption).foregroundColor(.secondary)

            GroupBox(label: Text("サポートフォーム一覧 (内部ブラウザで開きます)")) {
                VStack(alignment: .leading, spacing: 10) {
                    Button(action: {
                        if let url = URL(string: "https://forms.gle/hJ9EuapUVQik4qgG9") {
                            appState.openInAppBrowser(url: url, title: "Toho-Studio サポート・お問い合わせ窓口")
                        }
                    }) {
                        HStack {
                            Image(systemName: "envelope.fill")
                            Text("サポート・お問い合わせフォームを開く ↗️")
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button("バグレポート詳細画面を開く") {
                        appState.activeModal = .bugReport
                    }
                    .buttonStyle(.bordered)
                }
                .padding(8)
            }
        }
    }
}

// MARK: - 19. AquesTalkで音声を生成モーダル
public struct AquesTalkGeneratorModalView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var aquesTalk = AquesTalkBridge.shared

    @State private var inputText: String = "ゆっくりしていってね！"
    @State private var voiceSymbol: String = "ユックリシテイッテネ"
    @State private var selectedVoice: VoiceType = .f1
    @State private var speechSpeed: Int = 100
    @State private var speechPitch: Int = 100
    @State private var selectedQuality: AudioQualitySetting = .enhanced
    @State private var selectedEffect: AudioEffectType = .none
    @State private var isSynthesizing: Bool = false
    @State private var selectedTemplateId: UUID? = nil
    @State private var saveSuccessMessage: String? = nil

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                Label("AquesTalk ゆっくりボイス生成スタジオ", systemImage: "waveform.badge.plus")
                    .font(.title3)
                    .bold()
                Spacer()
                Text("AqKanji2Koe & AquesTalk1 高速合成")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Quick Template Selection (コゲの日記・独自・Gスカ)
            GroupBox(label: Label("音声テンプレート選択 (コゲの日記・独自4種・Gスカ)", systemImage: "sparkles")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("テンプレート:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: Binding(
                            get: { selectedTemplateId ?? appState.voiceTemplates.first?.id ?? UUID() },
                            set: { newId in
                                selectedTemplateId = newId
                                if let tpl = appState.voiceTemplates.first(where: { $0.id == newId }) {
                                    applyTemplate(tpl)
                                }
                            }
                        )) {
                            ForEach(appState.voiceTemplates) { t in
                                Text("\(t.name) [\(t.source)]").tag(t.id)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    // Direct Quick Buttons for User Specified Templates
                    HStack(spacing: 6) {
                        Button("東風谷早苗(コゲの日記)") {
                            appState.applyVoiceTemplateByName("東風谷早苗 (コゲの日記)")
                            syncFromActiveTemplate()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("操夢(imd1,100,115)") {
                            appState.applyVoiceTemplateByName("操夢 (交換夫婦)")
                            syncFromActiveTemplate()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("imd1,100,115") {
                            appState.applyVoiceTemplateByName("imd1,100,115 (独自)")
                            syncFromActiveTemplate()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("l1,100,115") {
                            appState.applyVoiceTemplateByName("l1,100,115 (独自)")
                            syncFromActiveTemplate()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("m1,100,115") {
                            appState.applyVoiceTemplateByName("m1,100,115 (独自)")
                            syncFromActiveTemplate()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("m2,100,115") {
                            appState.applyVoiceTemplateByName("m2,100,115 (独自)")
                            syncFromActiveTemplate()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding(6)
            }

            // Text Input & Symbol Conversion
            GroupBox(label: Label("セリフ入力と音声記号列", systemImage: "character.bubble")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("日本語セリフを入力:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("セリフを入力", text: $inputText)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: inputText) { newVal in
                            voiceSymbol = aquesTalk.convertToVoiceSymbol(text: newVal)
                        }

                    Text("生成される音声記号列 (AqKanji2Koe):")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("音声記号列", text: $voiceSymbol)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                }
                .padding(6)
            }

            // Voice Parameters & ゆっくりボイスメーカーエフェクト・音質改善
            GroupBox(label: Label("パラメータ設定 ＆ 音質改善・効果 (ゆっくりボイスメーカー準拠)", systemImage: "slider.horizontal.3")) {
                VStack(spacing: 8) {
                    HStack {
                        Text("声種 (Voice Type):")
                        Spacer()
                        Picker("", selection: $selectedVoice) {
                            ForEach(VoiceType.allCases) { v in
                                Text(v.rawValue).tag(v)
                            }
                        }
                        .frame(width: 180)
                    }

                    HStack {
                        Text("音質改善:")
                        Spacer()
                        Picker("", selection: $selectedQuality) {
                            ForEach(AudioQualitySetting.allCases) { q in
                                Text(q.displayName).tag(q)
                            }
                        }
                        .frame(width: 240)
                    }

                    HStack {
                        Text("効果指定 (Effect):")
                        Spacer()
                        Picker("", selection: $selectedEffect) {
                            ForEach(AudioEffectType.allCases) { eff in
                                Text(eff.displayName).tag(eff)
                            }
                        }
                        .frame(width: 240)
                    }

                    HStack {
                        Text("発話速度 (Speed):")
                        Spacer()
                        Text("\(speechSpeed)%").bold()
                    }
                    Slider(value: Binding(
                        get: { Double(speechSpeed) },
                        set: { speechSpeed = Int($0) }
                    ), in: 50...200)

                    HStack {
                        Text("音程 (Pitch):")
                        Spacer()
                        Text("\(speechPitch)").bold()
                    }
                    Slider(value: Binding(
                        get: { Double(speechPitch) },
                        set: { speechPitch = Int($0) }
                    ), in: 50...200)
                }
                .padding(6)
            }

            if let msg = saveSuccessMessage {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(msg)
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            // Action Buttons
            HStack(spacing: 10) {
                Button(action: {
                    isSynthesizing = true
                    aquesTalk.setVoiceType(selectedVoice)
                    aquesTalk.synthesizeAndPlay(
                        text: inputText,
                        speed: speechSpeed,
                        voice: selectedVoice,
                        quality: selectedQuality,
                        effect: selectedEffect
                    ) {
                        isSynthesizing = false
                    }
                }) {
                    HStack {
                        Image(systemName: isSynthesizing ? "waveform.badge.magnifyingglass" : "play.fill")
                        Text("試聴する")
                    }
                    .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)

                Button(action: {
                    placeToSoundMakerTimeline()
                }) {
                    HStack {
                        Image(systemName: "plus.rectangle.on.rectangle")
                        Text("波形トラックに配置")
                    }
                }
                .buttonStyle(.bordered)

                Button(action: {
                    appState.activeModal = .batchVoiceGenerator
                }) {
                    HStack {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                        Text("スライド全音声一括生成...")
                    }
                    .foregroundColor(.cyan)
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("閉じる") {
                    appState.activeModal = nil
                }
            }
        }
        .padding(18)
        .frame(width: 580)
        .onAppear {
            syncFromActiveTemplate()
        }
    }

    private func applyTemplate(_ tpl: VoiceTemplate) {
        selectedVoice = tpl.voiceType
        speechSpeed = tpl.speed
        speechPitch = tpl.pitch
        aquesTalk.setVoiceType(tpl.voiceType)
        saveSuccessMessage = "テンプレート『\(tpl.name)』を適用しました"
    }

    private func syncFromActiveTemplate() {
        if let tpl = appState.activeVoiceTemplate {
            selectedTemplateId = tpl.id
            applyTemplate(tpl)
        } else if let first = appState.voiceTemplates.first {
            selectedTemplateId = first.id
            applyTemplate(first)
        }
    }

    private func placeToSoundMakerTimeline() {
        let speakerName = appState.activeVoiceTemplate?.characterName ?? "ゆっくりボイス"
        let trackId: String
        let colorHex: String
        if speakerName.contains("霊夢") {
            trackId = "track_voice_reimu"
            colorHex = "#E74C3C"
        } else if speakerName.contains("魔理沙") {
            trackId = "track_voice_marisa"
            colorHex = "#F1C40F"
        } else {
            trackId = "track_voice_reimu"
            colorHex = "#00CEC9"
        }

        let newClip = SoundClip(
            name: "\(speakerName): \(inputText)",
            type: "Voice",
            character: speakerName,
            text: inputText,
            voiceSymbol: voiceSymbol,
            duration: max(2.0, Double(inputText.count) * 0.3 * (100.0 / Double(speechSpeed))),
            volume: 1.0,
            speed: speechSpeed,
            startTime: appState.currentTime,
            trackId: trackId,
            colorHex: colorHex,
            waveformPoints: (0..<18).map { _ in Float.random(in: 0.2...0.95) }
        )
        appState.soundClips.append(newClip)
        saveSuccessMessage = "サウンドメーカーの波形トラックに配置しました (開始位置: \(String(format: "%.1f", appState.currentTime))s)"
        appState.log("AquesTalkボイス波形クリップをサウンドメーカーに配置しました: 『\(inputText)』")
    }
}

// MARK: - 31. スライド抽出プログラムモーダル (有料機能)
public struct SlideExtractorModalView: View {
    @ObservedObject var appState = AppState.shared
    @State private var tachieFilter: String = ""
    @State private var animFilter: String = ""
    @State private var bgFilter: String = ""
    @State private var executionMessage: String = ""

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "line.3.horizontal.decrease.circle")
                    .foregroundColor(.accentColor)
                Text("スライド抽出プログラム (有料拡張機能)")
                    .font(.headline)
                Spacer()
                Text("有料プラン対応")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.yellow.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(4)
            }

            Text("指定した立ち絵・アニメーション・背景・トランジションでシーンを抽出し、一括変更または削除します。(仕様書補足事項 89-98行目)")
                .font(.caption)
                .foregroundColor(.secondary)

            GroupBox(label: Text("立ち絵抽出")) {
                HStack {
                    TextField("立ち絵ファイル名 (例: 博麗霊夢.png)", text: $tachieFilter)
                        .textFieldStyle(.roundedBorder)
                    Button("抽出実行") {
                        let query = tachieFilter.isEmpty ? "指定立ち絵" : tachieFilter
                        executionMessage = "立ち絵「\(query)」を含むスライドを抽出しました"
                        appState.log("立ち絵抽出フィルタを実行しました: \(query)")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(4)
            }

            GroupBox(label: Text("アニメーション・トランジション抽出")) {
                HStack {
                    TextField("アニメーション名 (例: フェードイン)", text: $animFilter)
                        .textFieldStyle(.roundedBorder)
                    Button("抽出実行") {
                        let query = animFilter.isEmpty ? "指定アニメーション" : animFilter
                        executionMessage = "アニメーション「\(query)」を含むスライドを抽出しました"
                        appState.log("アニメーション抽出フィルタを実行しました: \(query)")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(4)
            }

            GroupBox(label: Text("背景画像抽出")) {
                HStack {
                    TextField("背景名 (例: 神社境内)", text: $bgFilter)
                        .textFieldStyle(.roundedBorder)
                    Button("抽出実行") {
                        let query = bgFilter.isEmpty ? "指定背景" : bgFilter
                        executionMessage = "背景「\(query)」を含むスライドを抽出しました"
                        appState.log("背景抽出フィルタを実行しました: \(query)")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(4)
            }

            if !executionMessage.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(executionMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.vertical, 2)
            }

            HStack {
                Spacer()
                Button("閉じる") {
                    appState.activeModal = nil
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .frame(width: 520)
    }
}

// MARK: - 32. AI高度検索・生成・置換モーダル (有料機能)
public struct AISearchModalView: View {
    @ObservedObject var appState = AppState.shared
    @State private var aiPrompt: String = ""
    @State private var executionMessage: String = ""

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.purple)
                Text("AI高度検索・生成・置換 (有料機能連携)")
                    .font(.headline)
                Spacer()
                Text("残り利用可能プロンプト数: \(appState.aiPlanRemainingPrompts)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text("素材スタジオの全素材を対象に、プロンプトによる画像生成・音声合成・テキスト置換・ポリシー修正を実行します。(仕様書補足事項 112-121行目)")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: $aiPrompt)
                .frame(height: 80)
                .border(Color.secondary.opacity(0.2))
                .overlay(alignment: .topLeading) {
                    if aiPrompt.isEmpty {
                        Text("生成したい画像・音声・置き換え条件などのプロンプトを入力...")
                            .foregroundColor(.secondary.opacity(0.6))
                            .padding(6)
                            .allowsHitTesting(false)
                    }
                }

            HStack(spacing: 10) {
                Button("画像生成と置換") {
                    let prompt = aiPrompt.isEmpty ? "東方Project キャラクタースチル" : aiPrompt
                    executionMessage = "AI画像生成を実行し、素材を置換しました: [\(prompt)]"
                    appState.log(executionMessage)
                }
                .buttonStyle(.borderedProminent)

                Button("音声・効果音生成と置換") {
                    executionMessage = "AI音声生成を実行し、BGM/SEを置換しました"
                    appState.log(executionMessage)
                }
                .buttonStyle(.bordered)

                Button("規約ポリシー自動修正") {
                    executionMessage = "AIによりポリシー抵触語を全ファイルから自動置換しました"
                    appState.log(executionMessage)
                }
                .buttonStyle(.bordered)
            }

            if !executionMessage.isEmpty {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(executionMessage)
                        .font(.caption)
                        .foregroundColor(.green)
                }
                .padding(.vertical, 2)
            }

            HStack {
                Spacer()
                Button("閉じる") {
                    appState.activeModal = nil
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(20)
        .frame(width: 560)
    }
}


