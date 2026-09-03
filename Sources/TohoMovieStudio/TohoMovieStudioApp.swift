import AppKit
import SwiftUI

@main
struct TohoMovieStudioApp: App {
    var body: some Scene {
        WindowGroup {
            StudioView()
                .frame(minWidth: 1080, minHeight: 760)
        }
    }
}

struct AssetManifest: Decodable {
    var videos: [String]
    var slides: [String]
    var audios: [String]
    var bgm: [String]
    var soundEffects: [String]
    var scripts: [String]
}

struct AnalysisResponse: Decodable {
    var videoDuration: Double?
    var scriptSceneCount: Int
    var matchedSceneCount: Int
    var missingSceneCount: Int
    var plannedExtraScenes: [ScenePlanItem]
}

struct ScenePlanItem: Codable, Identifiable {
    var id: String
    var slideNumber: Int
    var slide: String
    var audio: String
    var character: String
    var scriptText: String
    var duration: Double
    var at: Int
    var inScript: Bool
    var hasAudio: Bool
    var presentInVideo: Bool
    var needsInsertion: Bool
    var se: String
    var enabled: Bool

    enum CodingKeys: String, CodingKey {
        case id
        case slideNumber
        case slide
        case audio
        case character
        case scriptText
        case duration
        case at
        case inScript
        case hasAudio
        case presentInVideo
        case needsInsertion
        case se
        case enabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        slideNumber = try container.decode(Int.self, forKey: .slideNumber)
        slide = try container.decode(String.self, forKey: .slide)
        audio = try container.decode(String.self, forKey: .audio)
        character = try container.decode(String.self, forKey: .character)
        scriptText = try container.decode(String.self, forKey: .scriptText)
        duration = try container.decode(Double.self, forKey: .duration)
        at = try container.decode(Int.self, forKey: .at)
        inScript = try container.decode(Bool.self, forKey: .inScript)
        hasAudio = try container.decode(Bool.self, forKey: .hasAudio)
        presentInVideo = try container.decode(Bool.self, forKey: .presentInVideo)
        needsInsertion = try container.decode(Bool.self, forKey: .needsInsertion)
        se = try container.decodeIfPresent(String.self, forKey: .se) ?? ""
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? needsInsertion
    }

    init(
        id: String,
        slideNumber: Int,
        slide: String,
        audio: String,
        character: String,
        scriptText: String,
        duration: Double,
        at: Int,
        inScript: Bool,
        hasAudio: Bool,
        presentInVideo: Bool,
        needsInsertion: Bool,
        se: String,
        enabled: Bool
    ) {
        self.id = id
        self.slideNumber = slideNumber
        self.slide = slide
        self.audio = audio
        self.character = character
        self.scriptText = scriptText
        self.duration = duration
        self.at = at
        self.inScript = inScript
        self.hasAudio = hasAudio
        self.presentInVideo = presentInVideo
        self.needsInsertion = needsInsertion
        self.se = se
        self.enabled = enabled
    }
}

struct ExportProgress: Decodable {
    var type: String?
    var phase: String
    var totalScenes: Int
    var completedScenes: Int
    var remainingScenes: Int
    var elapsedSeconds: Double
    var estimatedRemainingSeconds: Double?
    var output: String?

    var fraction: Double {
        guard totalScenes > 0 else { return completedScenes > 0 ? 1 : 0 }
        return min(max(Double(completedScenes) / Double(totalScenes), 0), 1)
    }
}

struct MovieStudioPlan: Encodable {
    var bgm: String
    var extraScenes: [PlanScene]

    enum CodingKeys: String, CodingKey {
        case bgm
        case extraScenes = "extra_scenes"
    }
}

struct PlanScene: Encodable {
    var slide: String
    var at: Int
    var duration: Double
    var se: String
    var enabled: Bool
}

@MainActor
final class StudioModel: ObservableObject {
    @Published var projectPath = "/Volumes/ZSSD/GitHub/repository/Toho-Project-Second-Story"
    @Published var inputVideo = "Movie archive/交換夫婦/22話.mp4"
    @Published var scriptPath = "script.csv"
    @Published var outputPath = "studio_export.mp4"
    @Published var bgmPath = ""
    @Published var soundEffectPath = ""
    @Published var extraSlideSeconds = "3.0"
    @Published var log = ""
    @Published var isRunning = false
    @Published var isExportSheetPresented = false
    @Published var exportProgress: ExportProgress?
    @Published var analysis: AnalysisResponse?
    @Published var scenePlan: [ScenePlanItem] = []
    @Published var manifest = AssetManifest(videos: [], slides: [], audios: [], bgm: [], soundEffects: [], scripts: [])

    private var commandStartedAt = Date()

    private var pythonPath: String {
        let venv = URL(fileURLWithPath: projectPath).appendingPathComponent(".venv/bin/python").path
        return FileManager.default.fileExists(atPath: venv) ? venv : "/usr/bin/python3"
    }

    func chooseProjectFolder() {
        if let url = chooseFolder(title: "プロジェクトフォルダを選択") {
            projectPath = url.path
            inputVideo = ""
            analysis = nil
            scenePlan = []
            Task { await scanAssets() }
        }
    }

    func chooseInputVideo() {
        if let url = chooseFile(title: "入力動画を選択") { inputVideo = relativePath(for: url) }
    }

    func chooseScript() {
        if let url = chooseFile(title: "台本CSVを選択") { scriptPath = relativePath(for: url) }
    }

    func chooseBGM() {
        if let url = chooseFile(title: "BGMを選択") { bgmPath = relativePath(for: url) }
    }

    func chooseSoundEffect() {
        if let url = chooseFile(title: "効果音を選択") { soundEffectPath = relativePath(for: url) }
    }

    func applyDefaultSoundEffect() {
        for index in scenePlan.indices where scenePlan[index].se.isEmpty {
            scenePlan[index].se = soundEffectPath
        }
    }

    func scanAssets() async { await runStudioCommand(["scan", "--json"], decodeManifest: true) }
    func startAquesTalkAPI() async { await runStudioCommand(["run", "aquestalk"], detach: true) }
    func runScriptExtraction() async { await runStudioCommand(["run", "extract-script", "--script", scriptPath]) }
    func runAudioAndVideoPipeline() async { await runStudioCommand(["run", "pipeline", "--script", scriptPath]) }

    func analyzeVideo() async {
        exportProgress = ExportProgress(
            type: "progress",
            phase: "分析中",
            totalScenes: 1,
            completedScenes: 0,
            remainingScenes: 1,
            elapsedSeconds: 0,
            estimatedRemainingSeconds: nil,
            output: nil
        )
        isExportSheetPresented = true

        let args = ["analyze", "--input", inputVideo, "--script", scriptPath, "--extra-slide-seconds", extraSlideSeconds, "--json"]
        await runStudioCommand(args, decodeAnalysis: true)
    }

    func exportEnhancedVideo() async {
        do {
            try writePlanFile()
        } catch {
            appendLog("movie_studio_plan.json の保存に失敗しました: \(error.localizedDescription)")
            return
        }

        let enabledCount = scenePlan.filter(\.enabled).count
        exportProgress = ExportProgress(type: "progress", phase: "開始", totalScenes: enabledCount, completedScenes: 0, remainingScenes: enabledCount, elapsedSeconds: 0, estimatedRemainingSeconds: nil, output: nil)
        isExportSheetPresented = true

        var args = [
            "export",
            "--input", inputVideo,
            "--script", scriptPath,
            "--output", outputPath,
            "--extra-slide-seconds", extraSlideSeconds,
            "--plan", "movie_studio_plan.json",
            "--progress-json"
        ]
        if !bgmPath.isEmpty { args += ["--bgm", bgmPath] }
        if !soundEffectPath.isEmpty { args += ["--se", soundEffectPath] }
        await runStudioCommand(args, parseProgress: true)
    }

    private func writePlanFile() throws {
        let scenes = scenePlan
            .filter { $0.enabled && !$0.slide.isEmpty }
            .sorted { lhs, rhs in
                if lhs.at == rhs.at { return lhs.slideNumber < rhs.slideNumber }
                return lhs.at < rhs.at
            }
            .map { PlanScene(slide: $0.slide, at: $0.at, duration: $0.duration, se: $0.se, enabled: $0.enabled) }
        let plan = MovieStudioPlan(bgm: bgmPath, extraScenes: scenes)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let data = try encoder.encode(plan)
        let url = URL(fileURLWithPath: projectPath).appendingPathComponent("movie_studio_plan.json")
        try data.write(to: url, options: .atomic)
        appendLog("movie_studio_plan.json を保存しました。追加シーン: \(scenes.count) 件")
    }

    private func runStudioCommand(_ args: [String], decodeManifest: Bool = false, decodeAnalysis: Bool = false, parseProgress: Bool = false, detach: Bool = false) async {
        isRunning = true
        commandStartedAt = Date()
        defer { isRunning = false }

        let script = URL(fileURLWithPath: projectPath).appendingPathComponent("toho_movie_studio.py").path
        let process = Process()
        process.executableURL = URL(fileURLWithPath: pythonPath)
        process.currentDirectoryURL = URL(fileURLWithPath: projectPath)
        process.arguments = [script] + args

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        appendLog("$ \(([pythonPath, script] + args).joined(separator: " "))")
        var capturedOutput = ""

        if parseProgress {
            pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty, let output = String(data: data, encoding: .utf8) else { return }
                Task { @MainActor in
                    self?.handleProcessOutput(output, parseProgress: true)
                }
            }
        }

        do {
            try process.run()
            if detach {
                appendLog("AquesTalk APIを別プロセスで起動しました。")
                return
            }

            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                DispatchQueue.global(qos: .userInitiated).async {
                    process.waitUntilExit()
                    continuation.resume()
                }
            }

            pipe.fileHandleForReading.readabilityHandler = nil
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            capturedOutput = String(data: data, encoding: .utf8) ?? ""
            handleProcessOutput(capturedOutput, parseProgress: parseProgress)

            if decodeManifest, let data = capturedOutput.data(using: .utf8) {
                do {
                    manifest = try JSONDecoder().decode(AssetManifest.self, from: data)
                    if inputVideo.isEmpty, let first = manifest.videos.first { inputVideo = first }
                    if let firstScript = manifest.scripts.first, scriptPath.isEmpty { scriptPath = firstScript }
                    if bgmPath.isEmpty, let firstBGM = manifest.bgm.first { bgmPath = firstBGM }
                    if soundEffectPath.isEmpty, let firstSE = manifest.soundEffects.first { soundEffectPath = firstSE }
                } catch {
                    appendLog("素材一覧JSONの解析に失敗しました: \(error.localizedDescription)")
                }
            }

            if decodeAnalysis, let data = capturedOutput.data(using: .utf8) {
                do {
                    let response = try JSONDecoder().decode(AnalysisResponse.self, from: data)
                    analysis = response
                    scenePlan = response.plannedExtraScenes
                    if !soundEffectPath.isEmpty { applyDefaultSoundEffect() }
                    exportProgress = ExportProgress(
                        type: "progress",
                        phase: "分析完了",
                        totalScenes: 1,
                        completedScenes: 1,
                        remainingScenes: 0,
                        elapsedSeconds: Date().timeIntervalSince(commandStartedAt),
                        estimatedRemainingSeconds: 0,
                        output: nil
                    )
                    appendLog("分析完了: 台本 \(response.scriptSceneCount) シーン / 照合 \(response.matchedSceneCount) シーン / 追加候補 \(response.missingSceneCount) シーン")
                } catch {
                    exportProgress = ExportProgress(
                        type: "progress",
                        phase: "分析失敗",
                        totalScenes: 1,
                        completedScenes: 0,
                        remainingScenes: 1,
                        elapsedSeconds: Date().timeIntervalSince(commandStartedAt),
                        estimatedRemainingSeconds: nil,
                        output: nil
                    )
                    appendLog("分析JSONの解析に失敗しました: \(error.localizedDescription)")
                }
            }

            if process.terminationStatus != 0 { appendLog("終了コード: \(process.terminationStatus)") }
        } catch {
            appendLog("実行に失敗しました: \(error.localizedDescription)")
        }
    }

    private func handleProcessOutput(_ text: String, parseProgress: Bool) {
        let lines = text.split(whereSeparator: \.isNewline).map(String.init)
        for line in lines {
            if parseProgress, let data = line.data(using: .utf8), let progress = try? JSONDecoder().decode(ExportProgress.self, from: data), progress.type == "progress" {
                exportProgress = progress
            } else {
                appendLog(line)
            }
        }
    }

    private func appendLog(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .newlines)
        guard !trimmed.isEmpty else { return }
        log += (log.isEmpty ? "" : "\n") + trimmed
    }

    private func chooseFolder(title: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func chooseFile(title: String) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func relativePath(for url: URL) -> String {
        let root = URL(fileURLWithPath: projectPath).standardizedFileURL.path
        let path = url.standardizedFileURL.path
        if path.hasPrefix(root + "/") { return String(path.dropFirst(root.count + 1)) }
        return path
    }
}

struct StudioView: View {
    @StateObject private var model = StudioModel()

    var body: some View {
        NavigationSplitView {
            assetList
                .navigationTitle("素材")
                .frame(minWidth: 280)
        } detail: {
            VStack(alignment: .leading, spacing: 14) {
                header
                settings
                analysisSummary
                actions
                sceneEditor
                logView
            }
            .padding(20)
        }
        .task { await model.scanAssets() }
        .sheet(isPresented: $model.isExportSheetPresented) {
            ExportProgressView(progress: model.exportProgress, isRunning: model.isRunning)
                .frame(width: 420)
                .padding(24)
        }
    }

    private var assetList: some View {
        List {
            Section("動画") {
                ForEach(model.manifest.videos, id: \.self) { item in Button(item) { model.inputVideo = item } }
            }
            Section("スライド") {
                Text("\(model.manifest.slides.count) 件")
                ForEach(Array(model.manifest.slides.prefix(12)), id: \.self) { Text($0) }
            }
            Section("音声") {
                Text("\(model.manifest.audios.count) 件")
                ForEach(Array(model.manifest.audios.prefix(12)), id: \.self) { Text($0) }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Toho Movie Studio").font(.system(size: 30, weight: .semibold))
            HStack {
                TextField("プロジェクト", text: $model.projectPath)
                Button("選択") { model.chooseProjectFolder() }
                Button("再読込") { Task { await model.scanAssets() } }.disabled(model.isRunning)
            }
        }
    }

    private var settings: some View {
        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 10) {
            GridRow { Text("入力動画"); TextField("Movie archive/...", text: $model.inputVideo); Button("選択") { model.chooseInputVideo() } }
            GridRow { Text("台本CSV"); TextField("script.csv", text: $model.scriptPath); Button("選択") { model.chooseScript() } }
            GridRow { Text("BGM"); TextField("任意", text: $model.bgmPath); Button("選択") { model.chooseBGM() } }
            GridRow { Text("効果音"); TextField("任意", text: $model.soundEffectPath); Button("選択") { model.chooseSoundEffect() } }
            GridRow { Text("出力"); TextField("studio_export.mp4", text: $model.outputPath); TextField("追加秒", text: $model.extraSlideSeconds).frame(width: 80) }
        }
        .textFieldStyle(.roundedBorder)
    }

    private var analysisSummary: some View {
        HStack(spacing: 18) {
            SummaryValue(title: "台本", value: "\(model.analysis?.scriptSceneCount ?? 0)")
            SummaryValue(title: "照合", value: "\(model.analysis?.matchedSceneCount ?? 0)")
            SummaryValue(title: "追加候補", value: "\(model.scenePlan.filter(\.enabled).count)")
            if let duration = model.analysis?.videoDuration {
                SummaryValue(title: "動画秒数", value: "\(Int(duration.rounded()))s")
            }
        }
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button("AquesTalk API起動") { Task { await model.startAquesTalkAPI() } }
            Button("台本作成") { Task { await model.runScriptExtraction() } }
            Button("音声+基本動画") { Task { await model.runAudioAndVideoPipeline() } }
            Button("分析") { Task { await model.analyzeVideo() } }
            Button("効果音を候補へ適用") { model.applyDefaultSoundEffect() }.disabled(model.soundEffectPath.isEmpty || model.scenePlan.isEmpty)
            Button("挿入+音響+書き出し") { Task { await model.exportEnhancedVideo() } }.buttonStyle(.borderedProminent)
        }
        .disabled(model.isRunning)
    }

    private var sceneEditor: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("追加シーン").font(.headline)
            ScrollView {
                LazyVStack(spacing: 8) {
                    if model.scenePlan.isEmpty {
                        Text("分析すると、動画に無いスライド画像がスライド順に表示されます。")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 12)
                    }
                    ForEach($model.scenePlan) { $scene in
                        ScenePlanRow(scene: $scene)
                    }
                }
                .padding(.trailing, 4)
            }
            .frame(minHeight: 150, maxHeight: 260)
        }
    }

    private var logView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ログ").font(.headline)
            ScrollView {
                Text(model.log.isEmpty ? "待機中" : model.log)
                    .font(.system(.body, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(10)
            }
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }
}

struct SummaryValue: View {
    var title: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.title3.monospacedDigit())
        }
        .frame(width: 88, alignment: .leading)
    }
}

struct ScenePlanRow: View {
    @Binding var scene: ScenePlanItem

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 10, verticalSpacing: 6) {
            GridRow {
                Toggle("", isOn: $scene.enabled).labelsHidden()
                Text("#\(scene.slideNumber)")
                    .font(.headline.monospacedDigit())
                    .frame(width: 48, alignment: .leading)
                Text(scene.slide)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Stepper(value: $scene.at, in: 0...86_400, step: 1) {
                    Text("\(scene.at)s")
                        .font(.body.monospacedDigit())
                        .frame(width: 72, alignment: .trailing)
                }
                TextField("秒数", value: $scene.duration, format: .number.precision(.fractionLength(1)))
                    .frame(width: 70)
                TextField("効果音", text: $scene.se)
                    .frame(minWidth: 160)
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(8)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct ExportProgressView: View {
    @Environment(\.dismiss) private var dismiss
    var progress: ExportProgress?
    var isRunning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.title2.weight(.semibold))
            ProgressView(value: progress?.fraction ?? 0)
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow { Text("状況"); Text(progress?.phase ?? "待機中") }
                GridRow { Text("残りシーン"); Text("\(progress?.remainingScenes ?? 0)") }
                GridRow { Text("経過"); Text("\(Int(progress?.elapsedSeconds ?? 0))s") }
                GridRow { Text("推定残り"); Text(remainingText) }
            }
            if let output = progress?.output {
                Text(output).font(.caption).foregroundStyle(.secondary)
            }
            HStack {
                Spacer()
                Button(isRunning ? "実行中" : "閉じる") { dismiss() }
                    .disabled(isRunning)
            }
        }
    }

    private var title: String {
        guard let phase = progress?.phase else { return "処理状況" }
        return phase.hasPrefix("分析") ? "分析" : "エクスポート"
    }

    private var remainingText: String {
        guard let seconds = progress?.estimatedRemainingSeconds else { return "計算中" }
        return "\(Int(seconds))s"
    }
}
