import Foundation
import AppKit

/// ムービーメーカーのタイムライン（各シーン・音声・画像・テロップ）から、実動画（MP4 / ProRes MOV）およびプロジェクトファイルを書き出すエクスポーター
public enum MovieExporter {
    public enum ExportError: LocalizedError {
        case ffmpegNotFound
        case noScenes
        case ffmpegFailed(String)
        case writeFailed(String)
        case cancelled

        public var errorDescription: String? {
            switch self {
            case .ffmpegNotFound:
                return "ffmpeg が見つかりませんでした。Homebrew 等で ffmpeg をインストールしてください (/opt/homebrew/bin/ffmpeg)。"
            case .noScenes:
                return "書き出し対象のシーンがありません。"
            case .ffmpegFailed(let msg):
                return "動画の生成に失敗しました:\n\(msg)"
            case .writeFailed(let msg):
                return "ファイルの保存に失敗しました:\n\(msg)"
            case .cancelled:
                return "書き出しがキャンセルされました。"
            }
        }
    }

    public struct ExportOptions {
        public var format: String // "MP4 (H.264)", "MOV (ProRes)", "YMMP", "GVID", etc.
        public var width: Int = 1920
        public var height: Int = 1080
        public var fps: Int = 30
        public var videoBitrate: String = "8M"
        public var audioBitrate: String = "192k"
        public var includeBurnedSubtitles: Bool = true
        public var exportSrtFile: Bool = false

        public init(
            format: String,
            width: Int = 1920,
            height: Int = 1080,
            fps: Int = 30,
            videoBitrate: String = "8M",
            audioBitrate: String = "192k",
            includeBurnedSubtitles: Bool = true,
            exportSrtFile: Bool = false
        ) {
            self.format = format
            self.width = width
            self.height = height
            self.fps = fps
            self.videoBitrate = videoBitrate
            self.audioBitrate = audioBitrate
            self.includeBurnedSubtitles = includeBurnedSubtitles
            self.exportSrtFile = exportSrtFile
        }
    }

    // キャンセル制御用フラグ
    private static var isCancelled = false
    private static var currentProcess: Process?

    public static func cancelExport() {
        isCancelled = true
        currentProcess?.terminate()
        currentProcess = nil
    }

    /// ffmpeg の実行パスを検索
    public static func resolveFFmpegPath() -> String? {
        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/opt/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]
        let fm = FileManager.default
        for path in candidates {
            if fm.isExecutableFile(atPath: path) {
                return path
            }
        }
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        which.arguments = ["ffmpeg"]
        let pipe = Pipe()
        which.standardOutput = pipe
        which.standardError = FileHandle.nullDevice
        do {
            try which.run()
            which.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               !path.isEmpty, fm.isExecutableFile(atPath: path) {
                return path
            }
        } catch {}
        return nil
    }

    /// 動画またはプロジェクトの書き出しを実行
    public static func export(
        scenes: [MovieScene],
        outputURL: URL,
        options: ExportOptions,
        progress: @escaping (Double, String) -> Void
    ) async throws {
        isCancelled = false
        currentProcess = nil

        guard !scenes.isEmpty else {
            throw ExportError.noScenes
        }

        let isVideo = options.format.contains("MP4") || options.format.contains("MOV") || options.format.contains("ProRes") || options.format.contains("H.264")

        if isVideo {
            try await exportVideo(scenes: scenes, outputURL: outputURL, options: options, progress: progress)
        } else if options.format.contains("YMMP") {
            try exportYMMP(scenes: scenes, outputURL: outputURL)
            progress(1.0, "YMMPプロジェクトの書き出しが完了しました")
        } else {
            // GVID / FCPBUNDLE / PRPROJ / JSON 形式
            try exportProjectJSON(scenes: scenes, outputURL: outputURL, formatName: options.format)
            progress(1.0, "\(options.format) プロジェクトの書き出しが完了しました")
        }
    }

    // MARK: - 実動画エクスポート (ffmpeg)
    private static func exportVideo(
        scenes: [MovieScene],
        outputURL: URL,
        options: ExportOptions,
        progress: @escaping (Double, String) -> Void
    ) async throws {
        guard let ffmpeg = resolveFFmpegPath() else {
            throw ExportError.ffmpegNotFound
        }

        let isProRes = options.format.contains("ProRes") || options.format.contains("MOV")
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("TohoStudio_Export_\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? fm.removeItem(at: tempDir)
        }

        var segmentURLs: [URL] = []
        let totalScenes = scenes.count

        for (index, scene) in scenes.enumerated() {
            if isCancelled { throw ExportError.cancelled }

            let currentProgress = Double(index) / Double(totalScenes)
            let statusText = "シーン \(index + 1) / \(totalScenes) をレンダリング中... (\(Int(currentProgress * 100))%)"
            await MainActor.run {
                progress(currentProgress, statusText)
            }

            let ext = isProRes ? "mov" : "mp4"
            let segURL = tempDir.appendingPathComponent(String(format: "seg_%04d.\(ext)", index))

            try encodeSceneSegment(
                ffmpeg: ffmpeg,
                scene: scene,
                index: index,
                options: options,
                isProRes: isProRes,
                outputURL: segURL
            )

            segmentURLs.append(segURL)
        }

        if isCancelled { throw ExportError.cancelled }

        await MainActor.run {
            progress(0.95, "全シーンを1本の動画に結合中...")
        }

        // Concat リストを作成
        let concatListURL = tempDir.appendingPathComponent("concat_list.txt")
        var listContent = ""
        for url in segmentURLs {
            let escaped = url.path.replacingOccurrences(of: "'", with: "'\\''")
            listContent += "file '\(escaped)'\n"
        }
        try listContent.write(to: concatListURL, atomically: true, encoding: .utf8)

        // 出力先ディレクトリを確保し、既存ファイルを削除
        try fm.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: outputURL.path) {
            try fm.removeItem(at: outputURL)
        }

        var concatArgs: [String] = [
            "-nostdin",
            "-y",
            "-f", "concat",
            "-safe", "0",
            "-i", concatListURL.path,
            "-c", "copy"
        ]
        if !isProRes {
            concatArgs += ["-movflags", "+faststart"]
        }
        concatArgs.append(outputURL.path)

        let concatLog = try runProcess(executable: ffmpeg, arguments: concatArgs)
        guard fm.fileExists(atPath: outputURL.path) else {
            throw ExportError.ffmpegFailed("結合処理に失敗しました:\n\(concatLog)")
        }

        // YouTube / ニコニコ動画向け SRT 字幕ファイルの出力
        if options.exportSrtFile {
            let srtURL = outputURL.deletingPathExtension().appendingPathExtension("srt")
            try? exportSrt(scenes: scenes, outputURL: srtURL)
        }

        await MainActor.run {
            progress(1.0, "書き出し完了！")
        }
    }

    // MARK: - シーンごとの個別エンコード
    private static func encodeSceneSegment(
        ffmpeg: String,
        scene: MovieScene,
        index: Int,
        options: ExportOptions,
        isProRes: Bool,
        outputURL: URL
    ) throws {
        let fm = FileManager.default
        let duration = max(0.5, scene.duration)
        let w = options.width
        let h = options.height
        let fps = options.fps

        var args: [String] = ["-nostdin", "-y"]
        var inputIndex = 0

        // 1. 映像ソースの決定 (Keynote動画 > スライド画像 > 背景+立ち絵 > 背景のみ > 単色黒)
        let resolvedVideoPath: String? = {
            if let p = scene.videoPath, fm.fileExists(atPath: p) { return p }
            return nil
        }()

        let resolvedSlideImagePath: String? = {
            if let p = scene.slideImagePath, fm.fileExists(atPath: p) { return p }
            return nil
        }()

        let resolvedBgPath: String? = {
            if let p = scene.backgroundImagePath, fm.fileExists(atPath: p) { return p }
            return resolveImageFallback(name: scene.backgroundName, subfolder: "背景")
        }()

        let resolvedCharPath: String? = {
            if let p = scene.characterImagePath, fm.fileExists(atPath: p) { return p }
            return resolveImageFallback(name: scene.characterName, subfolder: "立ち絵")
        }()

        var filterComplex = ""
        let videoOutLabel = "vout"
        let baseVideoLabel = "basev"

        if let vPath = resolvedVideoPath {
            // Keynote記録アニメーション動画
            args += ["-i", vPath]
            let vStream = inputIndex
            inputIndex += 1
            // 解像度合わせと尺制限
            filterComplex += "[\(vStream):v]scale=\(w):\(h):force_original_aspect_ratio=decrease,pad=\(w):\(h):(ow-iw)/2:(oh-ih)/2,setsar=1,fps=\(fps)[\(baseVideoLabel)]"
        } else if let sPath = resolvedSlideImagePath {
            // スライド画像
            args += ["-loop", "1", "-framerate", "\(fps)", "-t", String(format: "%.3f", duration), "-i", sPath]
            let sStream = inputIndex
            inputIndex += 1
            filterComplex += "[\(sStream):v]scale=\(w):\(h):force_original_aspect_ratio=decrease,pad=\(w):\(h):(ow-iw)/2:(oh-ih)/2,setsar=1[\(baseVideoLabel)]"
        } else if let bgPath = resolvedBgPath {
            args += ["-loop", "1", "-framerate", "\(fps)", "-t", String(format: "%.3f", duration), "-i", bgPath]
            let bgStream = inputIndex
            inputIndex += 1

            if let charPath = resolvedCharPath {
                // 背景 + キャラクター立ち絵
                args += ["-loop", "1", "-framerate", "\(fps)", "-t", String(format: "%.3f", duration), "-i", charPath]
                let charStream = inputIndex
                inputIndex += 1
                let charHeight = Int(Double(h) * 0.88)
                filterComplex += "[\(bgStream):v]scale=\(w):\(h):force_original_aspect_ratio=increase,crop=\(w):\(h),setsar=1[bg];"
                filterComplex += "[\(charStream):v]scale=-1:\(charHeight)[char];"
                filterComplex += "[bg][char]overlay=(W-w)/2:H-h[\(baseVideoLabel)]"
            } else {
                // 背景のみ
                filterComplex += "[\(bgStream):v]scale=\(w):\(h):force_original_aspect_ratio=increase,crop=\(w):\(h),setsar=1[\(baseVideoLabel)]"
            }
        } else {
            // 単色黒
            args += [
                "-f", "lavfi",
                "-t", String(format: "%.3f", duration),
                "-i", "color=c=black:s=\(w)x\(h):r=\(fps)"
            ]
            let colorStream = inputIndex
            inputIndex += 1
            filterComplex += "[\(colorStream):v]null[\(baseVideoLabel)]"
        }

        // テロップ (字幕) の重畳 (CoreGraphicsで透過PNGを生成しoverlay合成)
        let telopText = (scene.telop.isEmpty ? scene.slideTitle : scene.telop).trimmingCharacters(in: .whitespacesAndNewlines)
        let telopPNGURL = outputURL.deletingLastPathComponent().appendingPathComponent(String(format: "telop_%04d.png", index))
        let shouldBurn = options.includeBurnedSubtitles
        let hasTelop = shouldBurn && generateTelopImage(
            speaker: scene.characterName,
            text: telopText,
            width: w,
            height: h,
            outputURL: telopPNGURL
        )

        if hasTelop {
            args += ["-loop", "1", "-framerate", "\(fps)", "-t", String(format: "%.3f", duration), "-i", telopPNGURL.path]
            let telopStream = inputIndex
            inputIndex += 1
            filterComplex += ";[\(baseVideoLabel)][\(telopStream):v]overlay=0:0[\(videoOutLabel)]"
        } else {
            filterComplex += ";[\(baseVideoLabel)]null[\(videoOutLabel)]"
        }

        // 2. 音声ソースの決定 (Voice, BGM, SE)
        var audioInputs: [String] = []
        if let v = scene.voiceAudioPath, fm.fileExists(atPath: v) { audioInputs.append(v) }
        if let b = scene.bgmAudioPath, fm.fileExists(atPath: b) { audioInputs.append(b) }
        if let s = scene.seAudioPath, fm.fileExists(atPath: s) { audioInputs.append(s) }

        let audioOutLabel = "aout"
        if audioInputs.isEmpty {
            // 音声なし: anullsrc で無音ストリームを供給
            args += [
                "-f", "lavfi",
                "-t", String(format: "%.3f", duration),
                "-i", "anullsrc=channel_layout=stereo:sample_rate=44100"
            ]
            let anullStream = inputIndex
            inputIndex += 1
            filterComplex += ";[\(anullStream):a]atrim=0:\(String(format: "%.3f", duration)),apad[\(audioOutLabel)]"
        } else if audioInputs.count == 1 {
            args += ["-i", audioInputs[0]]
            let aStream = inputIndex
            inputIndex += 1
            filterComplex += ";[\(aStream):a]atrim=0:\(String(format: "%.3f", duration)),apad[\(audioOutLabel)]"
        } else {
            // 複数音声を amix で合成
            var amixLabels = ""
            for aPath in audioInputs {
                args += ["-i", aPath]
                let sIdx = inputIndex
                inputIndex += 1
                filterComplex += ";[\(sIdx):a]atrim=0:\(String(format: "%.3f", duration)),apad[a\(sIdx)]"
                amixLabels += "[a\(sIdx)]"
            }
            filterComplex += ";\(amixLabels)amix=inputs=\(audioInputs.count):duration=longest:dropout_transition=0[\(audioOutLabel)]"
        }

        // 出力引数の組み立て
        args += [
            "-t", String(format: "%.3f", duration),
            "-filter_complex", filterComplex,
            "-map", "[\(videoOutLabel)]",
            "-map", "[\(audioOutLabel)]"
        ]

        if isProRes {
            args += [
                "-c:v", "prores_ks",
                "-profile:v", "3", // ProRes 422 HQ
                "-pix_fmt", "yuv422p10le",
                "-c:a", "pcm_s16le",
                "-ar", "44100",
                "-ac", "2",
                outputURL.path
            ]
        } else {
            args += [
                "-c:v", "libx264",
                "-preset", "veryfast",
                "-crf", "20",
                "-pix_fmt", "yuv420p",
                "-c:a", "aac",
                "-b:a", options.audioBitrate,
                "-ar", "44100",
                "-ac", "2",
                outputURL.path
            ]
        }

        let log = try runProcess(executable: ffmpeg, arguments: args)
        guard fm.fileExists(atPath: outputURL.path) else {
            throw ExportError.ffmpegFailed("シーン \(index + 1) のエンコードに失敗しました:\n\(log)")
        }
    }

    // MARK: - プロセス実行補助
    @discardableResult
    private static func runProcess(executable: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = pipe
        process.standardError = pipe
        currentProcess = process

        do {
            try process.run()
        } catch {
            throw ExportError.ffmpegFailed("プロセス起動エラー: \(error.localizedDescription)")
        }

        process.waitUntilExit()
        currentProcess = nil

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        if process.terminationStatus != 0 && !isCancelled {
            throw ExportError.ffmpegFailed(truncate(output))
        }
        return output
    }

    private static func truncate(_ s: String, maxLen: Int = 1200) -> String {
        if s.count <= maxLen { return s }
        return String(s.suffix(maxLen))
    }

    private static func resolveImageFallback(name: String, subfolder: String) -> String? {
        guard !name.isEmpty else { return nil }
        let cleanName = name.replacingOccurrences(of: ".png", with: "")
            .replacingOccurrences(of: ".jpg", with: "")
            .replacingOccurrences(of: ".jpeg", with: "")
        let searchDirs = [
            "/Volumes/ZSSD/GitHub/repository/TohoStudio/動画用/\(subfolder)",
            "/Volumes/ZSSD/GitHub/repository/TohoStudio/.cache/keynote_extracted",
            "/Volumes/ZSSD/GitHub/repository/TohoStudio/.cache/keynote_slides"
        ]
        let fm = FileManager.default
        for dir in searchDirs where fm.fileExists(atPath: dir) {
            if let files = try? fm.contentsOfDirectory(atPath: dir) {
                for file in files where file.contains(cleanName) {
                    return (dir as NSString).appendingPathComponent(file)
                }
            }
        }
        return nil
    }

    // MARK: - YMMP (ゆっくりMovieMaker4) プロジェクトエクスポート
    private static func exportYMMP(scenes: [MovieScene], outputURL: URL) throws {
        var items: [[String: Any]] = []
        var currentFrame = 0
        let fps = 30

        for (idx, sc) in scenes.enumerated() {
            let frames = max(1, Int(sc.duration * Double(fps)))
            var item: [String: Any] = [
                "Index": idx + 1,
                "Frame": currentFrame,
                "Length": frames,
                "DurationSeconds": sc.duration,
                "Title": sc.title,
                "Telop": sc.telop,
                "CharacterName": sc.characterName,
                "BackgroundName": sc.backgroundName
            ]
            if let vp = sc.videoPath { item["VideoPath"] = vp }
            if let sp = sc.slideImagePath { item["SlideImagePath"] = sp }
            if let bp = sc.backgroundImagePath { item["BackgroundImagePath"] = bp }
            if let cp = sc.characterImagePath { item["CharacterImagePath"] = cp }
            if let va = sc.voiceAudioPath { item["VoiceAudioPath"] = va }
            if let bgm = sc.bgmAudioPath { item["BgmAudioPath"] = bgm }
            if let se = sc.seAudioPath { item["SeAudioPath"] = se }

            items.append(item)
            currentFrame += frames
        }

        let ymmpPayload: [String: Any] = [
            "AppName": "Toho-Studio",
            "Version": "2.0.0",
            "ExportDate": ISO8601DateFormatter().string(from: Date()),
            "FPS": fps,
            "TotalFrames": currentFrame,
            "TotalDurationSeconds": Double(currentFrame) / Double(fps),
            "Scenes": items
        ]

        let data = try JSONSerialization.data(withJSONObject: ymmpPayload, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: outputURL, options: .atomic)
    }

    // MARK: - 汎用プロジェクト JSON エクスポート
    private static func exportProjectJSON(scenes: [MovieScene], outputURL: URL, formatName: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        struct ProjectExportContainer: Codable {
            let appName: String
            let version: String
            let format: String
            let exportTimestamp: Date
            let totalScenes: Int
            let totalDuration: Double
            let scenes: [MovieScene]
        }

        let container = ProjectExportContainer(
            appName: "TohoStudio",
            version: "2.0.0",
            format: formatName,
            exportTimestamp: Date(),
            totalScenes: scenes.count,
            totalDuration: scenes.reduce(0.0) { $0 + $1.duration },
            scenes: scenes
        )

        let data = try encoder.encode(container)
        try data.write(to: outputURL, options: .atomic)
    }

    // MARK: - CoreGraphics によるテロップ透過画像生成 (drawtext非依存)
    private static func generateTelopImage(
        speaker: String,
        text: String,
        width: Int,
        height: Int,
        outputURL: URL
    ) -> Bool {
        let cleanText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanText.isEmpty || !speaker.isEmpty else { return false }

        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: width,
            pixelsHigh: height,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: width * 4,
            bitsPerPixel: 32
        ) else { return false }

        NSGraphicsContext.saveGraphicsState()
        guard let context = NSGraphicsContext(bitmapImageRep: rep) else {
            NSGraphicsContext.restoreGraphicsState()
            return false
        }
        NSGraphicsContext.current = context

        let displayText: String
        if !speaker.isEmpty && !cleanText.contains(speaker) {
            displayText = "【\(speaker)】 \(cleanText)"
        } else {
            displayText = cleanText
        }

        let fontSize = max(18.0, CGFloat(height) * 0.04)
        let font = NSFont.boldSystemFont(ofSize: fontSize)

        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byWordWrapping

        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.8)
        shadow.shadowOffset = NSSize(width: 2, height: -2)
        shadow.shadowBlurRadius = 3

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraphStyle,
            .shadow: shadow
        ]

        let attrString = NSAttributedString(string: displayText, attributes: attrs)
        let maxTextWidth = CGFloat(width) * 0.85
        let boundingRect = attrString.boundingRect(
            with: NSSize(width: maxTextWidth, height: CGFloat(height) * 0.3),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )

        let padX: CGFloat = 24
        let padY: CGFloat = 12
        let boxWidth = min(CGFloat(width) - 40, ceil(boundingRect.width) + padX * 2)
        let boxHeight = ceil(boundingRect.height) + padY * 2
        let boxX = (CGFloat(width) - boxWidth) / 2.0
        let boxY: CGFloat = CGFloat(height) * 0.06 // 下から6%の位置

        // 背景ボックス (半透明黒角丸)
        let boxPath = NSBezierPath(
            roundedRect: NSRect(x: boxX, y: boxY, width: boxWidth, height: boxHeight),
            xRadius: 10,
            yRadius: 10
        )
        NSColor(calibratedWhite: 0.05, alpha: 0.78).setFill()
        boxPath.fill()

        // 枠線
        NSColor(calibratedWhite: 1.0, alpha: 0.15).setStroke()
        boxPath.lineWidth = 1.5
        boxPath.stroke()

        // テキスト描画 (上下中央揃え)
        let textDrawRect = NSRect(
            x: boxX + padX,
            y: boxY + (boxHeight - boundingRect.height) / 2.0,
            width: boxWidth - padX * 2,
            height: boundingRect.height
        )
        attrString.draw(in: textDrawRect)

        NSGraphicsContext.restoreGraphicsState()

        guard let pngData = rep.representation(using: .png, properties: [:]) else { return false }
        do {
            try pngData.write(to: outputURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    // MARK: - YouTube / ニコニコ動画用 SRT 字幕エクスポート
    public static func formatSrtTime(_ seconds: Double) -> String {
        let totalMs = Int(max(0, seconds) * 1000)
        let ms = totalMs % 1000
        let totalSec = totalMs / 1000
        let sec = totalSec % 60
        let min = (totalSec / 60) % 60
        let hour = totalSec / 3600
        return String(format: "%02d:%02d:%02d,%03d", hour, min, sec, ms)
    }

    public static func exportSrt(scenes: [MovieScene], outputURL: URL) throws {
        var srtContent = ""
        var currentTime: Double = 0.0
        var srtIndex = 1

        for scene in scenes {
            let dur = max(0.5, scene.duration)
            let rawText = (scene.telop.isEmpty ? scene.slideTitle : scene.telop).trimmingCharacters(in: .whitespacesAndNewlines)
            if !rawText.isEmpty {
                let startTimeStr = formatSrtTime(currentTime)
                let endTimeStr = formatSrtTime(currentTime + dur)
                let textToDisplay = (!scene.characterName.isEmpty && !rawText.contains(scene.characterName)) ? "\(scene.characterName): \(rawText)" : rawText

                srtContent += "\(srtIndex)\n"
                srtContent += "\(startTimeStr) --> \(endTimeStr)\n"
                srtContent += "\(textToDisplay)\n\n"
                srtIndex += 1
            }
            currentTime += dur
        }

        try srtContent.write(to: outputURL, atomically: true, encoding: .utf8)
    }
}
