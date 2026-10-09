import Foundation
import AVFoundation
import AppKit

/// サウンドメーカー専用のオーディオエクスポート管理マネージャー
/// WAV, MP3, M4A, AIFF の音声ファイル書き出しに加え、
/// Logic Pro (.logicx), Adobe Audition (.sesx), マルチトラックステム, ZIP一括アーカイブ書き出しに対応
public final class SoundMakerExporter {

    // MARK: - Export Scope & Error Definitions

    public enum ExportScope: String, CaseIterable, Identifiable {
        case masterMix = "マスターミックス (全トラック統合)"
        case trackStems = "トラック別ステム (各トラック個別音声)"
        case individualClips = "全クリップ個別ファイル (セリフ・SE・BGM一括)"

        public var id: String { rawValue }
    }

    public enum ExportError: LocalizedError {
        case noClips
        case cancelled
        case ffmpegNotFound
        case fileWriteFailed(String)
        case unsupportedFormat(String)
        case audioProcessingFailed(String)

        public var errorDescription: String? {
            switch self {
            case .noClips:
                return "書き出し対象の音声クリップがありません。"
            case .cancelled:
                return "書き出しがキャンセルされました。"
            case .ffmpegNotFound:
                return "高音質エンコーダ (ffmpeg) が見つかりませんでした。"
            case .fileWriteFailed(let msg):
                return "ファイルの書き込みに失敗しました: \(msg)"
            case .unsupportedFormat(let fmt):
                return "未対応の書き出しフォーマットです: \(fmt)"
            case .audioProcessingFailed(let msg):
                return "音声処理中にエラーが発生しました: \(msg)"
            }
        }
    }

    public struct ExportOptions {
        public var format: String
        public var scope: ExportScope
        public var sampleRate: Int
        public var bitDepth: Int
        public var audioBitrate: String
        public var normalize: Bool
        public var includeEffects: Bool

        public init(
            format: String = "WAV (非圧縮・最高音質)",
            scope: ExportScope = .masterMix,
            sampleRate: Int = 44100,
            bitDepth: Int = 16,
            audioBitrate: String = "192k",
            normalize: Bool = true,
            includeEffects: Bool = true
        ) {
            self.format = format
            self.scope = scope
            self.sampleRate = sampleRate
            self.bitDepth = bitDepth
            self.audioBitrate = audioBitrate
            self.normalize = normalize
            self.includeEffects = includeEffects
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

    // MARK: - メインエクスポートエントリーポイント

    public static func export(
        clips: [SoundClip],
        tracks: [AudioTrack],
        scenes: [MovieScene],
        outputURL: URL,
        options: ExportOptions,
        progress: @escaping (Double, String) -> Void
    ) async throws {
        isCancelled = false
        currentProcess = nil

        guard !clips.isEmpty else {
            throw ExportError.noClips
        }

        let fmt = options.format.uppercased()

        if fmt.contains("LOGICX") {
            try await exportLogicXProject(
                clips: clips,
                tracks: tracks,
                scenes: scenes,
                outputURL: outputURL,
                options: options,
                progress: progress
            )
        } else if fmt.contains("SESX") {
            try await exportAuditionSesx(
                clips: clips,
                tracks: tracks,
                scenes: scenes,
                outputURL: outputURL,
                options: options,
                progress: progress
            )
        } else if fmt.contains("ZIP") || options.scope == .trackStems || options.scope == .individualClips {
            try await exportMultiTrackPackage(
                clips: clips,
                tracks: tracks,
                scenes: scenes,
                outputURL: outputURL,
                options: options,
                progress: progress
            )
        } else {
            // 単一マスターオーディオファイル書き出し (WAV, MP3, M4A, AIFF)
            try await exportMasterAudio(
                clips: clips,
                tracks: tracks,
                scenes: scenes,
                outputURL: outputURL,
                options: options,
                progress: progress
            )
        }

        await MainActor.run {
            progress(1.0, "書き出しが完了しました")
        }
    }

    // MARK: - 単一マスターオーディオ書き出し

    private static func exportMasterAudio(
        clips: [SoundClip],
        tracks: [AudioTrack],
        scenes: [MovieScene],
        outputURL: URL,
        options: ExportOptions,
        progress: @escaping (Double, String) -> Void
    ) async throws {
        await MainActor.run {
            progress(0.1, "タイムライン音声を合成・ミキシング中...")
        }

        // 1. マスターミックスの Float バッファを生成 (Stereo)
        let (leftSamples, rightSamples) = try await renderMixdown(
            clips: clips,
            tracks: tracks,
            scenes: scenes,
            options: options
        ) { p, msg in
            progress(0.1 + p * 0.5, msg)
        }

        if isCancelled { throw ExportError.cancelled }

        await MainActor.run {
            progress(0.65, "出力フォーマットに変換中...")
        }

        let fmt = options.format.uppercased()
        let fm = FileManager.default
        let tempDir = fm.temporaryDirectory.appendingPathComponent("TSExport_\(UUID().uuidString)")
        try fm.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tempDir) }

        let tempWavURL = tempDir.appendingPathComponent("master_temp.wav")
        try writeWavFile(
            left: leftSamples,
            right: rightSamples,
            sampleRate: options.sampleRate,
            bitDepth: options.bitDepth,
            outputURL: tempWavURL
        )

        if fmt.contains("WAV") {
            if fm.fileExists(atPath: outputURL.path) {
                try? fm.removeItem(at: outputURL)
            }
            try fm.copyItem(at: tempWavURL, to: outputURL)
        } else if fmt.contains("MP3") {
            try await convertWithFFmpeg(
                inputURL: tempWavURL,
                outputURL: outputURL,
                codecArgs: ["-codec:a", "libmp3lame", "-b:a", options.audioBitrate]
            )
        } else if fmt.contains("M4A") || fmt.contains("AAC") {
            if let _ = MovieExporter.resolveFFmpegPath() {
                try await convertWithFFmpeg(
                    inputURL: tempWavURL,
                    outputURL: outputURL,
                    codecArgs: ["-c:a", "aac", "-b:a", options.audioBitrate]
                )
            } else {
                // FFmpeg がない場合は AVAssetExport でフォールバック
                try await convertWavToM4AViaAVFoundation(sourceWavURL: tempWavURL, outputM4AURL: outputURL)
            }
        } else if fmt.contains("AIFF") {
            if let _ = MovieExporter.resolveFFmpegPath() {
                try await convertWithFFmpeg(
                    inputURL: tempWavURL,
                    outputURL: outputURL,
                    codecArgs: ["-c:a", options.bitDepth == 24 ? "pcm_s24be" : "pcm_s16be"]
                )
            } else {
                // WAVをそのままコピーまたは書き出し
                try writeWavFile(left: leftSamples, right: rightSamples, sampleRate: options.sampleRate, bitDepth: options.bitDepth, outputURL: outputURL)
            }
        } else {
            // デフォルトは WAV
            if fm.fileExists(atPath: outputURL.path) {
                try? fm.removeItem(at: outputURL)
            }
            try fm.copyItem(at: tempWavURL, to: outputURL)
        }
    }

    // MARK: - トラック別ステム & ZIP一括パッケージ書き出し

    private static func exportMultiTrackPackage(
        clips: [SoundClip],
        tracks: [AudioTrack],
        scenes: [MovieScene],
        outputURL: URL,
        options: ExportOptions,
        progress: @escaping (Double, String) -> Void
    ) async throws {
        let fm = FileManager.default
        let isZip = outputURL.pathExtension.lowercased() == "zip" || options.format.uppercased().contains("ZIP")

        let stagingDir: URL
        if isZip {
            stagingDir = fm.temporaryDirectory.appendingPathComponent("TS_Archive_\(UUID().uuidString)")
            try fm.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        } else if outputURL.hasDirectoryPath || fm.fileExists(atPath: outputURL.path) {
            stagingDir = outputURL
        } else {
            stagingDir = outputURL
            try fm.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        }
        defer {
            if isZip {
                try? fm.removeItem(at: stagingDir)
            }
        }

        let stemsDir = stagingDir.appendingPathComponent("Stems", isDirectory: true)
        let clipsDir = stagingDir.appendingPathComponent("Clips", isDirectory: true)
        try fm.createDirectory(at: stemsDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: clipsDir, withIntermediateDirectories: true)

        let ext = options.format.uppercased().contains("MP3") ? "mp3" : (options.format.uppercased().contains("M4A") ? "m4a" : "wav")

        // 1. マスターミックスの書き出し
        await MainActor.run { progress(0.15, "マスターミックスをレンダリング中...") }
        let (mLeft, mRight) = try await renderMixdown(clips: clips, tracks: tracks, scenes: scenes, options: options, progress: { _, _ in })
        let masterWavURL = stagingDir.appendingPathComponent("00_Master_Mix.wav")
        try writeWavFile(left: mLeft, right: mRight, sampleRate: options.sampleRate, bitDepth: options.bitDepth, outputURL: masterWavURL)
        if ext != "wav" && MovieExporter.resolveFFmpegPath() != nil {
            let masterTargetURL = stagingDir.appendingPathComponent("00_Master_Mix.\(ext)")
            let args = ext == "mp3" ? ["-codec:a", "libmp3lame", "-b:a", options.audioBitrate] : ["-c:a", "aac", "-b:a", options.audioBitrate]
            try? await convertWithFFmpeg(inputURL: masterWavURL, outputURL: masterTargetURL, codecArgs: args)
        }

        // 2. トラック別ステムの書き出し
        let activeTracks = resolvedTracks(for: clips, allTracks: tracks)
        let totalSteps = Double(max(1, activeTracks.count + clips.count))
        var currentStep = 0.0

        for (idx, track) in activeTracks.enumerated() {
            if isCancelled { throw ExportError.cancelled }
            let trackClips = clipsForTrack(track, from: clips)
            guard !trackClips.isEmpty else { continue }

            let step = currentStep
            await MainActor.run {
                let p = 0.25 + (step / totalSteps) * 0.4
                progress(p, "トラック 『\(track.name)』 のステムを出力中...")
            }

            let (tLeft, tRight) = try await renderClipsMix(
                clips: trackClips,
                trackVolume: track.volume,
                trackPan: track.pan,
                scenes: scenes,
                options: options
            )

            let safeTrackName = track.name.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: " ", with: "_")
            let stemWavURL = stemsDir.appendingPathComponent(String(format: "Track_%02d_%@.wav", idx + 1, safeTrackName))
            try writeWavFile(left: tLeft, right: tRight, sampleRate: options.sampleRate, bitDepth: options.bitDepth, outputURL: stemWavURL)

            if ext != "wav" && MovieExporter.resolveFFmpegPath() != nil {
                let stemTargetURL = stemsDir.appendingPathComponent(String(format: "Track_%02d_%@.%@", idx + 1, safeTrackName, ext))
                let args = ext == "mp3" ? ["-codec:a", "libmp3lame", "-b:a", options.audioBitrate] : ["-c:a", "aac", "-b:a", options.audioBitrate]
                try? await convertWithFFmpeg(inputURL: stemWavURL, outputURL: stemTargetURL, codecArgs: args)
            }
            currentStep += 1.0
        }

        // 3. 個別クリップファイルの書き出し
        for (cIdx, clip) in clips.enumerated() {
            if isCancelled { throw ExportError.cancelled }

            let step = currentStep
            await MainActor.run {
                let p = 0.65 + (step / totalSteps) * 0.25
                progress(p, "クリップ 『\(clip.name)』 を出力中 (\(cIdx + 1)/\(clips.count))...")
            }

            if let (cLeft, cRight) = try? await resolveClipSamples(clip: clip, scenes: scenes, targetSampleRate: options.sampleRate) {
                let sIdx = clip.sceneIndex ?? (cIdx + 1)
                let safeName = clip.name.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: " ", with: "_")
                let clipWavURL = clipsDir.appendingPathComponent(String(format: "Scene_%03d_%@_%@.wav", sIdx, clip.type, safeName))
                try? writeWavFile(left: cLeft, right: cRight, sampleRate: options.sampleRate, bitDepth: 16, outputURL: clipWavURL)
            }
            currentStep += 1.0
        }

        // 4. セッション情報テキストの生成
        let reportText = generateTimelineReport(clips: clips, tracks: activeTracks, scenes: scenes)
        let reportURL = stagingDir.appendingPathComponent("Timeline_Report.txt")
        try? reportText.write(to: reportURL, atomically: true, encoding: .utf8)

        // 5. ZIP圧縮 (必要な場合)
        if isZip {
            await MainActor.run { progress(0.92, "ZIPアーカイブを生成中...") }
            if fm.fileExists(atPath: outputURL.path) {
                try? fm.removeItem(at: outputURL)
            }

            let zipProcess = Process()
            zipProcess.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
            zipProcess.currentDirectoryURL = stagingDir
            zipProcess.arguments = ["-r", outputURL.path, "."]
            currentProcess = zipProcess

            let pipe = Pipe()
            zipProcess.standardOutput = pipe
            zipProcess.standardError = pipe
            try zipProcess.run()
            zipProcess.waitUntilExit()

            if zipProcess.terminationStatus != 0 {
                throw ExportError.fileWriteFailed("ZIPアーカイブの作成に失敗しました")
            }
        }
    }

    // MARK: - Adobe Audition (.sesx) プロジェクト書き出し

    private static func exportAuditionSesx(
        clips: [SoundClip],
        tracks: [AudioTrack],
        scenes: [MovieScene],
        outputURL: URL,
        options: ExportOptions,
        progress: @escaping (Double, String) -> Void
    ) async throws {
        let fm = FileManager.default
        let projectDir = outputURL.deletingPathExtension()
        try fm.createDirectory(at: projectDir, withIntermediateDirectories: true)

        let audioDir = projectDir.appendingPathComponent("Audio Files", isDirectory: true)
        try fm.createDirectory(at: audioDir, withIntermediateDirectories: true)

        await MainActor.run { progress(0.2, "Adobe Audition 用オーディオファイルをレンダリング中...") }

        let activeTracks = resolvedTracks(for: clips, allTracks: tracks)
        var fileReferences: [(id: String, fileName: String, relativePath: String, clip: SoundClip)] = []

        // 各クリップの音声ファイルを Audio Files に出力
        for (cIdx, clip) in clips.enumerated() {
            if isCancelled { throw ExportError.cancelled }

            let sIdx = clip.sceneIndex ?? (cIdx + 1)
            let safeName = clip.name.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: " ", with: "_")
            let wavName = String(format: "Clip_%03d_%@_%@.wav", sIdx, clip.type, safeName)
            let clipWavURL = audioDir.appendingPathComponent(wavName)

            if let (cLeft, cRight) = try? await resolveClipSamples(clip: clip, scenes: scenes, targetSampleRate: options.sampleRate) {
                try writeWavFile(left: cLeft, right: cRight, sampleRate: options.sampleRate, bitDepth: 16, outputURL: clipWavURL)
            } else if let srcPath = clip.audioFilePath, fm.fileExists(atPath: srcPath) {
                try? fm.copyItem(at: URL(fileURLWithPath: srcPath), to: clipWavURL)
            }

            fileReferences.append((id: "file_\(cIdx + 1)", fileName: wavName, relativePath: "Audio Files/\(wavName)", clip: clip))
        }

        await MainActor.run { progress(0.7, "Adobe Audition .sesx XML セッションを生成中...") }

        // SESX XML ドキュメント生成
        var sesx = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"no\" ?>\n"
        sesx += "<session author=\"TohoStudio SoundMaker\" appVersion=\"2.0\" sampleRate=\"\(options.sampleRate)\" bitDepth=\"\(options.bitDepth)\" channelType=\"stereo\">\n"
        sesx += "  <tracks>\n"

        for (tIdx, track) in activeTracks.enumerated() {
            let tClips = fileReferences.filter { ref in
                let c = ref.clip
                return c.trackId == track.id || c.type.lowercased() == track.type.lowercased() || (track.type == "voice" && c.type == "Voice")
            }

            sesx += "    <audioTrack id=\"\(tIdx + 1)\" name=\"\(track.name)\" volume=\"\(track.volume)\" pan=\"\(track.pan)\" muted=\"\(track.isMuted ? "true" : "false")\" solo=\"\(track.isSolo ? "true" : "false")\">\n"
            for ref in tClips {
                let startSample = Int64(ref.clip.startTime * Double(options.sampleRate))
                let durationSample = Int64(ref.clip.effectiveDuration * Double(options.sampleRate))
                sesx += "      <audioClip name=\"\(ref.clip.name)\" fileID=\"\(ref.id)\" startPoint=\"\(startSample)\" duration=\"\(durationSample)\" fadeIn=\"\(ref.clip.fadeInDuration)\" fadeOut=\"\(ref.clip.fadeOutDuration)\" />\n"
            }
            sesx += "    </audioTrack>\n"
        }

        sesx += "  </tracks>\n"
        sesx += "  <files>\n"
        for ref in fileReferences {
            sesx += "    <file id=\"\(ref.id)\" name=\"\(ref.fileName)\" relativePath=\"\(ref.relativePath)\" />\n"
        }
        sesx += "  </files>\n"
        sesx += "</session>\n"

        let targetSesxURL = projectDir.appendingPathComponent(outputURL.lastPathComponent)
        try sesx.write(to: targetSesxURL, atomically: true, encoding: .utf8)

        // 指定URLにもコピー
        if outputURL != targetSesxURL {
            try? fm.removeItem(at: outputURL)
            try? fm.copyItem(at: targetSesxURL, to: outputURL)
        }
    }

    // MARK: - Logic Pro (.logicx) プロジェクトパッケージ書き出し

    private static func exportLogicXProject(
        clips: [SoundClip],
        tracks: [AudioTrack],
        scenes: [MovieScene],
        outputURL: URL,
        options: ExportOptions,
        progress: @escaping (Double, String) -> Void
    ) async throws {
        let fm = FileManager.default
        // .logicx はパッケージディレクトリ
        let packageDir = outputURL.pathExtension.lowercased() == "logicx" ? outputURL : outputURL.appendingPathExtension("logicx")
        try fm.createDirectory(at: packageDir, withIntermediateDirectories: true)

        let mediaDir = packageDir.appendingPathComponent("Media/Audio Files", isDirectory: true)
        let altDir = packageDir.appendingPathComponent("Alternatives/000", isDirectory: true)
        let resourcesDir = packageDir.appendingPathComponent("Resources", isDirectory: true)

        try fm.createDirectory(at: mediaDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: altDir, withIntermediateDirectories: true)
        try fm.createDirectory(at: resourcesDir, withIntermediateDirectories: true)

        await MainActor.run { progress(0.2, "Logic Pro 用ステム音声をレンダリング中...") }

        let activeTracks = resolvedTracks(for: clips, allTracks: tracks)

        // 1. 各トラックのステムWAVを Media/Audio Files にレンダリング
        var trackSummaries: [[String: Any]] = []

        for (idx, track) in activeTracks.enumerated() {
            if isCancelled { throw ExportError.cancelled }
            let trackClips = clipsForTrack(track, from: clips)

            let (tLeft, tRight) = try await renderClipsMix(
                clips: trackClips,
                trackVolume: track.volume,
                trackPan: track.pan,
                scenes: scenes,
                options: options
            )

            let safeName = track.name.replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: " ", with: "_")
            let stemName = String(format: "%02d_%@.wav", idx + 1, safeName)
            let stemURL = mediaDir.appendingPathComponent(stemName)
            try writeWavFile(left: tLeft, right: tRight, sampleRate: options.sampleRate, bitDepth: 24, outputURL: stemURL)

            trackSummaries.append([
                "TrackID": idx + 1,
                "Name": track.name,
                "Type": track.type,
                "Volume": track.volume,
                "Pan": track.pan,
                "AudioFile": stemName,
                "ClipCount": trackClips.count
            ])
        }

        // 2. マスターミックスも同梱
        let (mLeft, mRight) = try await renderMixdown(clips: clips, tracks: tracks, scenes: scenes, options: options, progress: { _, _ in })
        let masterStemURL = mediaDir.appendingPathComponent("00_Master_Mixdown.wav")
        try writeWavFile(left: mLeft, right: mRight, sampleRate: options.sampleRate, bitDepth: 24, outputURL: masterStemURL)

        await MainActor.run { progress(0.75, "Logic Pro プロジェクトメタデータを生成中...") }

        // 3. Alternatives/000/ProjectData plist 生成
        let projectDict: [String: Any] = [
            "ApplicationVersion": "Logic Pro X Compatible (TohoStudio SoundMaker)",
            "CreationDate": ISO8601DateFormatter().string(from: Date()),
            "SampleRate": options.sampleRate,
            "BitDepth": options.bitDepth,
            "Tempo": 120.0,
            "TimeSignature": "4/4",
            "Tracks": trackSummaries,
            "TotalClips": clips.count,
            "TotalDuration": scenes.reduce(0.0) { $0 + $1.duration }
        ]

        let plistData = try PropertyListSerialization.data(fromPropertyList: projectDict, format: .xml, options: 0)
        try plistData.write(to: altDir.appendingPathComponent("ProjectData"))

        // 4. Readme / Session Notes
        let readme = """
        =======================================================
        TohoStudio SoundMaker - Logic Pro Project Bundle (.logicx)
        =======================================================
        作成日時: \(Date())
        プロジェクト形式: 24-bit / \(options.sampleRate)Hz Multi-Track Stems
        
        【トラック一覧】
        \(activeTracks.enumerated().map { "Track \($0.offset + 1): \($0.element.name) (\($0.element.type))" }.joined(separator: "\n"))

        【使い方】
        Logic Proで本パッケージを開くか、Media/Audio Files 配下の各トラック別ステムWAVを新規プロジェクトにドラッグ＆ドロップしてミックスを行ってください。
        """
        try? readme.write(to: packageDir.appendingPathComponent("README.txt"), atomically: true, encoding: .utf8)
    }

    // MARK: - オーディオミキシング & レンダリングロジック

    /// 全トラック・クリップを統合したステレオマスターミックス Float 配列を生成
    public static func renderMixdown(
        clips: [SoundClip],
        tracks: [AudioTrack],
        scenes: [MovieScene],
        options: ExportOptions,
        progress: @escaping (Double, String) -> Void
    ) async throws -> (left: [Float], right: [Float]) {
        let activeTracks = resolvedTracks(for: clips, allTracks: tracks)

        // ソロトラックが存在する場合はソロのみに限定
        let soloTracks = activeTracks.filter { $0.isSolo }
        let effectiveTracks = !soloTracks.isEmpty ? soloTracks : activeTracks.filter { !$0.isMuted }

        // 総再生時間の算出
        let maxClipEnd = clips.map { $0.startTime + $0.effectiveDuration }.max() ?? 0.0
        let scenesTotal = scenes.reduce(0.0) { $0 + $1.duration }
        let totalDuration = max(1.0, max(scenesTotal, maxClipEnd))

        let totalFrames = Int(ceil(totalDuration * Double(options.sampleRate)))
        var masterLeft = [Float](repeating: 0.0, count: totalFrames)
        var masterRight = [Float](repeating: 0.0, count: totalFrames)

        let totalTracksCount = Double(max(1, effectiveTracks.count))

        for (idx, track) in effectiveTracks.enumerated() {
            if isCancelled { throw ExportError.cancelled }

            let trackClips = clipsForTrack(track, from: clips)
            guard !trackClips.isEmpty else { continue }

            await MainActor.run {
                let p = Double(idx) / totalTracksCount
                progress(p, "トラック 『\(track.name)』 をミキシング中...")
            }

            let (tLeft, tRight) = try await renderClipsMix(
                clips: trackClips,
                trackVolume: track.volume,
                trackPan: track.pan,
                scenes: scenes,
                options: options
            )

            let mixCount = min(totalFrames, tLeft.count)
            for i in 0..<mixCount {
                masterLeft[i] += tLeft[i]
                masterRight[i] += tRight[i]
            }
        }

        // ノーマライズ & ソフトリミッター
        if options.normalize {
            applyNormalization(left: &masterLeft, right: &masterRight)
        } else {
            applySoftLimiter(samples: &masterLeft)
            applySoftLimiter(samples: &masterRight)
        }

        return (masterLeft, masterRight)
    }

    /// 特定トラックのクリップ群をステレオ Float 配列にミキシング
    private static func renderClipsMix(
        clips: [SoundClip],
        trackVolume: Double,
        trackPan: Double,
        scenes: [MovieScene],
        options: ExportOptions
    ) async throws -> (left: [Float], right: [Float]) {
        let maxClipEnd = clips.map { $0.startTime + $0.effectiveDuration }.max() ?? 0.0
        let scenesTotal = scenes.reduce(0.0) { $0 + $1.duration }
        let totalDuration = max(1.0, max(scenesTotal, maxClipEnd))
        let totalFrames = Int(ceil(totalDuration * Double(options.sampleRate)))

        var outLeft = [Float](repeating: 0.0, count: totalFrames)
        var outRight = [Float](repeating: 0.0, count: totalFrames)

        // トラックパンの係数 (等音響パワーパン)
        let tPanClamped = max(-1.0, min(1.0, trackPan))
        let trackLeftGain = Float(cos((tPanClamped + 1.0) * .pi / 4.0) * trackVolume)
        let trackRightGain = Float(sin((tPanClamped + 1.0) * .pi / 4.0) * trackVolume)

        for clip in clips {
            if isCancelled { throw ExportError.cancelled }

            let (clipL, clipR) = try await resolveClipSamples(
                clip: clip,
                scenes: scenes,
                targetSampleRate: options.sampleRate
            )

            let startFrame = max(0, Int(clip.startTime * Double(options.sampleRate)))
            let framesToCopy = min(clipL.count, totalFrames - startFrame)

            guard framesToCopy > 0 else { continue }

            for i in 0..<framesToCopy {
                let dstIdx = startFrame + i
                outLeft[dstIdx] += clipL[i] * trackLeftGain
                outRight[dstIdx] += clipR[i] * trackRightGain
            }
        }

        return (outLeft, outRight)
    }

    // MARK: - クリップ単位のオーディオサンプル取得 & エフェクト適用

    /// クリップの設定（ファイル/シンセ音源、倍速、反転、フェード、即切り、パン、音量）を適用した Float サンプルを返す
    public static func resolveClipSamples(
        clip: SoundClip,
        scenes: [MovieScene],
        targetSampleRate: Int
    ) async throws -> (left: [Float], right: [Float]) {
        var baseMono: [Float] = []
        let fm = FileManager.default

        // 1. 実ファイルからの読み込み
        if let path = clip.audioFilePath, fm.fileExists(atPath: path) {
            let fileURL = URL(fileURLWithPath: path)
            if let samples = readAudioFileSamples(url: fileURL, targetSampleRate: targetSampleRate) {
                baseMono = samples
            }
        }

        // 2. 実ファイルがない場合の合成生成
        if baseMono.isEmpty {
            if clip.type == "Voice", let text = clip.text, !text.isEmpty {
                // AquesTalk 音声合成
                let rawData = AquesTalkBridge.shared.synthesizeToWavData(
                    text: text,
                    speed: clip.speed,
                    voice: clip.voiceType ?? .f1,
                    pitch: clip.pitch,
                    quality: .enhanced,
                    effect: .none
                )
                if let data = rawData, let parsed = parseWavSamples(data: data) {
                    baseMono = resample(samples: parsed.samples, from: parsed.sampleRate, to: targetSampleRate)
                }
            } else {
                // SE または BGM のプリセットシンセシス音源
                if let wavData = SoundMakerAudioManager.shared.presetAudioData(for: clip),
                   let parsed = parseWavSamples(data: wavData) {
                    baseMono = resample(samples: parsed.samples, from: parsed.sampleRate, to: targetSampleRate)
                }
            }
        }

        // フォールバック: 無音パルス
        if baseMono.isEmpty {
            let durFrames = Int(max(0.1, clip.effectiveDuration) * Double(targetSampleRate))
            baseMono = [Float](repeating: 0.0, count: durFrames)
        }

        // 3. 逆再生 (Reverse)
        if clip.isReversed {
            baseMono.reverse()
        }

        // 4. 倍速再生レート適用
        if clip.playbackRate != 1.0 && clip.playbackRate > 0.1 {
            baseMono = applyPlaybackRate(samples: baseMono, rate: clip.playbackRate)
        }

        // 5. SE のシーン終了時即切り (isCutOffOnSceneEnd)
        if clip.type == "SE" && clip.isCutOffOnSceneEnd {
            let maxLimitSeconds = resolveSceneCutoffDuration(clip: clip, scenes: scenes)
            if let limit = maxLimitSeconds, limit > 0 {
                let maxFrames = Int(limit * Double(targetSampleRate))
                if baseMono.count > maxFrames {
                    baseMono = Array(baseMono.prefix(maxFrames))
                }
            }
        }

        // 6. フェードイン・フェードアウト エンベロープ適用
        let totalFrames = baseMono.count
        let totalSeconds = Double(totalFrames) / Double(targetSampleRate)

        for i in 0..<totalFrames {
            let t = Double(i) / Double(targetSampleRate)
            let remaining = totalSeconds - t

            var inFactor: Double = 1.0
            if clip.fadeInDuration > 0.05 {
                inFactor = min(1.0, max(0.0, t / clip.fadeInDuration))
            }

            var outFactor: Double = 1.0
            if clip.fadeOutDuration > 0.05 {
                outFactor = min(1.0, max(0.0, remaining / clip.fadeOutDuration))
            }

            let env = Float(min(inFactor, outFactor))
            baseMono[i] *= env * Float(clip.volume)
        }

        // 7. ステレオパンニング適用 (等音響パワーパン)
        let panClamped = max(-1.0, min(1.0, clip.pan))
        let leftMult = Float(cos((panClamped + 1.0) * .pi / 4.0))
        let rightMult = Float(sin((panClamped + 1.0) * .pi / 4.0))

        let leftSamples = baseMono.map { $0 * leftMult }
        let rightSamples = baseMono.map { $0 * rightMult }

        return (leftSamples, rightSamples)
    }

    // MARK: - シーン即切りの制限秒数計算

    private static func resolveSceneCutoffDuration(clip: SoundClip, scenes: [MovieScene]) -> Double? {
        guard !scenes.isEmpty else { return nil }

        var accTime = 0.0
        var sceneRanges: [Int: (start: Double, end: Double)] = [:]
        for (i, sc) in scenes.enumerated() {
            sceneRanges[i + 1] = (accTime, accTime + sc.duration)
            accTime += sc.duration
        }

        let targetSceneIdx = clip.spanEndSceneIndex ?? clip.sceneIndex
        if let sIdx = targetSceneIdx, let range = sceneRanges[sIdx] {
            let availableInScene = max(0.05, range.end - clip.startTime)
            return availableInScene
        }
        return nil
    }

    // MARK: - トラック解決ヘルパー

    private static func resolvedTracks(for clips: [SoundClip], allTracks: [AudioTrack]) -> [AudioTrack] {
        if !allTracks.isEmpty {
            return allTracks
        }
        // デフォルトトラック
        return [
            AudioTrack(id: "track_movie", name: "Movie Audio", type: "movie", icon: "film", colorHex: "#3897F0"),
            AudioTrack(id: "track_voice", name: "Voice (セリフ)", type: "voice", icon: "bubble.left.and.bubble.right.fill", colorHex: "#E74C3C"),
            AudioTrack(id: "track_se", name: "SE (効果音)", type: "se", icon: "bolt.fill", colorHex: "#2ECC71"),
            AudioTrack(id: "track_bgm", name: "BGM (背景音楽)", type: "bgm", icon: "music.note", colorHex: "#9B59B6")
        ]
    }

    private static func clipsForTrack(_ track: AudioTrack, from clips: [SoundClip]) -> [SoundClip] {
        return clips.filter { clip in
            if let tId = clip.trackId, tId == track.id {
                return true
            }
            if track.type == "voice" && clip.type == "Voice" {
                if let char = track.characterName, let cChar = clip.character, char == cChar {
                    return true
                }
                return true
            }
            return clip.type.lowercased() == track.type.lowercased()
        }
    }

    // MARK: - オーディオファイル読み込み (AVAudioFile)

    private static func readAudioFileSamples(url: URL, targetSampleRate: Int) -> [Float]? {
        do {
            let file = try AVAudioFile(forReading: url)
            let format = file.processingFormat
            let frameCount = AVAudioFrameCount(file.length)
            guard frameCount > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return nil
            }
            try file.read(into: buffer)

            guard let channelData = buffer.floatChannelData else { return nil }
            let channels = Int(format.channelCount)
            let frames = Int(buffer.frameLength)

            var mono = [Float](repeating: 0.0, count: frames)
            for ch in 0..<channels {
                let src = channelData[ch]
                for f in 0..<frames {
                    mono[f] += src[f]
                }
            }
            let mult = 1.0 / Float(max(1, channels))
            for f in 0..<frames {
                mono[f] *= mult
            }

            let srcRate = Int(format.sampleRate)
            if srcRate != targetSampleRate {
                return resample(samples: mono, from: srcRate, to: targetSampleRate)
            }
            return mono
        } catch {
            return nil
        }
    }

    // MARK: - WAV パース & エンコード

    private static func parseWavSamples(data: Data) -> (samples: [Float], sampleRate: Int)? {
        guard data.count > 44 else { return nil }
        guard let riff = String(data: data.subdata(in: 0..<4), encoding: .ascii), riff == "RIFF",
              let wave = String(data: data.subdata(in: 8..<12), encoding: .ascii), wave == "WAVE" else {
            return nil
        }

        var offset = 12
        var sampleRate = 44100
        var channels = 1
        var bitsPerSample = 16
        var dataRange: Range<Int>?

        while offset + 8 <= data.count {
            let chunkId = String(data: data.subdata(in: offset..<offset+4), encoding: .ascii) ?? ""
            let chunkSize = Int(data.withUnsafeBytes { $0.load(fromByteOffset: offset + 4, as: UInt32.self) })
            offset += 8

            if chunkId == "fmt " && chunkSize >= 16 {
                channels = Int(data.withUnsafeBytes { $0.load(fromByteOffset: offset + 2, as: UInt16.self) })
                sampleRate = Int(data.withUnsafeBytes { $0.load(fromByteOffset: offset + 4, as: UInt32.self) })
                bitsPerSample = Int(data.withUnsafeBytes { $0.load(fromByteOffset: offset + 14, as: UInt16.self) })
            } else if chunkId == "data" {
                dataRange = offset ..< min(data.count, offset + chunkSize)
                break
            }
            offset += chunkSize
        }

        guard let range = dataRange, bitsPerSample == 16 else { return nil }
        let sampleCount = range.count / 2
        var samples = [Float](repeating: 0, count: sampleCount / max(1, channels))

        data.subdata(in: range).withUnsafeBytes { ptr in
            let int16Ptr = ptr.bindMemory(to: Int16.self)
            if channels == 1 {
                for i in 0..<samples.count {
                    samples[i] = Float(int16Ptr[i]) / 32768.0
                }
            } else {
                for i in 0..<samples.count {
                    let l = Float(int16Ptr[i * channels]) / 32768.0
                    let r = Float(int16Ptr[i * channels + 1]) / 32768.0
                    samples[i] = (l + r) * 0.5
                }
            }
        }

        return (samples, sampleRate)
    }

    /// 高品質ステレオ WAV ファイルの生成 (16-bit または 24-bit PCM)
    public static func writeWavFile(
        left: [Float],
        right: [Float],
        sampleRate: Int,
        bitDepth: Int = 16,
        outputURL: URL
    ) throws {
        let frameCount = min(left.count, right.count)
        let channels: UInt16 = 2
        let bytesPerSample = bitDepth / 8
        let blockAlign = channels * UInt16(bytesPerSample)
        let byteRate = UInt32(sampleRate) * UInt32(blockAlign)
        let dataSize = UInt32(frameCount * Int(blockAlign))
        let fileSize = 36 + dataSize

        var data = Data()
        data.reserveCapacity(44 + Int(dataSize))

        // RIFF Header
        data.append(contentsOf: "RIFF".utf8)
        var fSize = fileSize
        data.append(Data(bytes: &fSize, count: 4))
        data.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        data.append(contentsOf: "fmt ".utf8)
        var fmtSize: UInt32 = 16
        data.append(Data(bytes: &fmtSize, count: 4))
        var audioFormat: UInt16 = 1 // Linear PCM
        data.append(Data(bytes: &audioFormat, count: 2))
        var ch = channels
        data.append(Data(bytes: &ch, count: 2))
        var sRate = UInt32(sampleRate)
        data.append(Data(bytes: &sRate, count: 4))
        var bRate = byteRate
        data.append(Data(bytes: &bRate, count: 4))
        var bAlign = blockAlign
        data.append(Data(bytes: &bAlign, count: 2))
        var bits = UInt16(bitDepth)
        data.append(Data(bytes: &bits, count: 2))

        // data chunk
        data.append(contentsOf: "data".utf8)
        var dSize = dataSize
        data.append(Data(bytes: &dSize, count: 4))

        if bitDepth == 24 {
            for i in 0..<frameCount {
                let lClamped = max(-1.0, min(1.0, left[i]))
                let rClamped = max(-1.0, min(1.0, right[i]))

                let lInt = Int32(lClamped * 8388607.0)
                let rInt = Int32(rClamped * 8388607.0)

                data.append(UInt8(lInt & 0xFF))
                data.append(UInt8((lInt >> 8) & 0xFF))
                data.append(UInt8((lInt >> 16) & 0xFF))

                data.append(UInt8(rInt & 0xFF))
                data.append(UInt8((rInt >> 8) & 0xFF))
                data.append(UInt8((rInt >> 16) & 0xFF))
            }
        } else {
            // 16-bit
            for i in 0..<frameCount {
                let lClamped = max(-1.0, min(1.0, left[i]))
                let rClamped = max(-1.0, min(1.0, right[i]))

                var lInt = Int16(lClamped * 32767.0)
                var rInt = Int16(rClamped * 32767.0)

                data.append(Data(bytes: &lInt, count: 2))
                data.append(Data(bytes: &rInt, count: 2))
            }
        }

        try data.write(to: outputURL)
    }

    // MARK: - FFmpeg 変換パイプライン

    private static func convertWithFFmpeg(
        inputURL: URL,
        outputURL: URL,
        codecArgs: [String]
    ) async throws {
        guard let ffmpeg = MovieExporter.resolveFFmpegPath() else {
            throw ExportError.ffmpegNotFound
        }

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpeg)
        process.arguments = ["-y", "-nostdin", "-i", inputURL.path] + codecArgs + [outputURL.path]
        process.standardInput = FileHandle.nullDevice
        currentProcess = process

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if isCancelled {
            throw ExportError.cancelled
        }

        if process.terminationStatus != 0 {
            let errStr = String(data: data, encoding: .utf8) ?? "FFmpeg execution failed"
            throw ExportError.fileWriteFailed(errStr)
        }
    }

    // MARK: - AVFoundation M4A フォールバック

    private static func convertWavToM4AViaAVFoundation(sourceWavURL: URL, outputM4AURL: URL) async throws {
        let asset = AVURLAsset(url: sourceWavURL)
        guard let session = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw ExportError.audioProcessingFailed("AVAssetExportSession 初期化失敗")
        }

        if FileManager.default.fileExists(atPath: outputM4AURL.path) {
            try? FileManager.default.removeItem(at: outputM4AURL)
        }

        session.outputURL = outputM4AURL
        session.outputFileType = .m4a

        await session.export()
        if let err = session.error {
            throw ExportError.audioProcessingFailed(err.localizedDescription)
        }
    }

    // MARK: - 音声処理ユーティリティ (リサンプリング、速度、ノーマライズ)

    private static func resample(samples: [Float], from srcRate: Int, to dstRate: Int) -> [Float] {
        guard srcRate != dstRate, !samples.isEmpty else { return samples }
        let ratio = Double(srcRate) / Double(dstRate)
        let outCount = Int(Double(samples.count) / ratio)
        var out = [Float](repeating: 0, count: outCount)

        for i in 0..<outCount {
            let srcIdx = Double(i) * ratio
            let idx0 = Int(srcIdx)
            let idx1 = min(idx0 + 1, samples.count - 1)
            let frac = Float(srcIdx - Double(idx0))
            out[i] = samples[idx0] * (1.0 - frac) + samples[idx1] * frac
        }
        return out
    }

    private static func applyPlaybackRate(samples: [Float], rate: Double) -> [Float] {
        guard rate > 0.1, rate != 1.0, !samples.isEmpty else { return samples }
        let outCount = Int(Double(samples.count) / rate)
        var out = [Float](repeating: 0, count: outCount)

        for i in 0..<outCount {
            let srcIdx = Double(i) * rate
            let idx0 = Int(srcIdx)
            let idx1 = min(idx0 + 1, samples.count - 1)
            let frac = Float(srcIdx - Double(idx0))
            if idx0 < samples.count {
                out[i] = samples[idx0] * (1.0 - frac) + samples[idx1] * frac
            }
        }
        return out
    }

    private static func applyNormalization(left: inout [Float], right: inout [Float]) {
        var peak: Float = 0.0
        let count = min(left.count, right.count)
        for i in 0..<count {
            peak = max(peak, abs(left[i]))
            peak = max(peak, abs(right[i]))
        }

        if peak > 0.001 {
            let targetPeak: Float = 0.95 // -0.45 dBFS
            let gain = targetPeak / peak
            for i in 0..<count {
                left[i] *= gain
                right[i] *= gain
            }
        }
        applySoftLimiter(samples: &left)
        applySoftLimiter(samples: &right)
    }

    private static func applySoftLimiter(samples: inout [Float]) {
        for i in 0..<samples.count {
            let s = samples[i]
            if s > 1.0 {
                samples[i] = 1.0 - exp(-(s - 1.0)) * 0.1
            } else if s < -1.0 {
                samples[i] = -1.0 + exp(s + 1.0) * 0.1
            }
        }
    }

    // MARK: - タイムラインレポート生成

    private static func generateTimelineReport(clips: [SoundClip], tracks: [AudioTrack], scenes: [MovieScene]) -> String {
        var report = """
        ================================================================================
        TohoStudio SoundMaker - タイムライン書き出しレポート
        ================================================================================
        書き出し日時: \(Date())
        総シーン数: \(scenes.count)
        総クリップ数: \(clips.count)
        総トラック数: \(tracks.count)
        
        【トラック設定一覧】
        """

        for (i, t) in tracks.enumerated() {
            let state = t.isMuted ? " [Muted]" : (t.isSolo ? " [Solo]" : "")
            report += "\n\(i + 1). \(t.name) (Type: \(t.type), Vol: \(Int(t.volume * 100))%, Pan: \(String(format: "%+.2f", t.pan))\(state))"
        }

        report += "\n\n【シーン別クリップ一覧】\n"
        for (idx, clip) in clips.enumerated() {
            let timeStr = String(format: "%02d:%05.2f", Int(clip.startTime) / 60, clip.startTime.truncatingRemainder(dividingBy: 60))
            let durStr = String(format: "%.2fs", clip.effectiveDuration)
            let sIdx = clip.sceneIndex.map { "Scene \($0)" } ?? "Free"
            report += String(format: "%03d. [%@] [%@] %@ (%@, %@)\n", idx + 1, sIdx, clip.type, clip.name, timeStr, durStr)
            if let text = clip.text, !text.isEmpty {
                report += "     セリフ: \(text)\n"
            }
        }

        return report
    }
}
