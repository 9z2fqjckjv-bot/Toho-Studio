import Foundation

/// ムービーメーカーのシーン（静止画 + 音声設定 + アニメ）から、Mac / QuickTime で再生できる実 MP4 を書き出す。
enum MovieExporter {
    enum ExportError: LocalizedError {
        case ffmpegNotFound
        case noScenes
        case ffmpegFailed(String)
        case writeFailed(String)

        var errorDescription: String? {
            switch self {
            case .ffmpegNotFound:
                return "ffmpeg が見つかりません。Homebrew で ffmpeg を入れてから再度書き出してください。"
            case .noScenes:
                return "書き出すシーンがありません。"
            case .ffmpegFailed(let msg):
                return "動画の生成に失敗しました。\n\(msg)"
            case .writeFailed(let msg):
                return "ファイルの保存に失敗しました。\n\(msg)"
            }
        }
    }

    public struct AudioLayerInput {
        public var path: String
        public var volume: Double
        public var playbackRate: Double
        public var isReversed: Bool
        public var loops: Bool
        public var duration: Double?
        
        public init(
            path: String,
            volume: Double = 1.0,
            playbackRate: Double = 1.0,
            isReversed: Bool = false,
            loops: Bool = false,
            duration: Double? = nil
        ) {
            self.path = path
            self.volume = volume
            self.playbackRate = playbackRate
            self.isReversed = isReversed
            self.loops = loops
            self.duration = duration
        }
    }

    struct SceneInput {
        var title: String
        var imagePath: String?
        var audioPath: String?
        /// タイムライン上のシーン尺（秒）
        var duration: Double
        var audioDuration: Double?
        /// 0.0 ... 1.0（ミュート時は 0）
        var volume: Double
        /// 再生速度（0.5 ... 2.0）。1.0 が等速。
        var playbackRate: Double
        /// 逆再生フラグ
        var isReversed: Bool
        /// Ken Burns 等のアニメを焼き込むか
        var hasAnimation: Bool
        var animationMeta: String?
        /// 該当シーンで鳴る複数オーディオレイヤー（セリフ・BGM・効果音）
        var audioLayers: [AudioLayerInput]
        
        // 8段階レイヤー情報
        var backgroundImagePath: String?
        var characterImagePath: String?
        var characterAnimation: String?
        var telopText: String?
        var speakerCharacter: String?
        var slideTransitionEffect: String?
        var slideTransitionDuration: Double?

        init(
            title: String,
            imagePath: String? = nil,
            audioPath: String? = nil,
            duration: Double,
            audioDuration: Double? = nil,
            volume: Double = 1.0,
            playbackRate: Double = 1.0,
            isReversed: Bool = false,
            hasAnimation: Bool = false,
            animationMeta: String? = nil,
            audioLayers: [AudioLayerInput] = [],
            backgroundImagePath: String? = nil,
            characterImagePath: String? = nil,
            characterAnimation: String? = nil,
            telopText: String? = nil,
            speakerCharacter: String? = nil,
            slideTransitionEffect: String? = nil,
            slideTransitionDuration: Double? = nil
        ) {
            self.title = title
            self.imagePath = imagePath
            self.audioPath = audioPath
            self.duration = duration
            self.audioDuration = audioDuration
            self.volume = volume
            self.playbackRate = playbackRate
            self.isReversed = isReversed
            self.hasAnimation = hasAnimation
            self.animationMeta = animationMeta
            self.backgroundImagePath = backgroundImagePath
            self.characterImagePath = characterImagePath
            self.characterAnimation = characterAnimation
            self.telopText = telopText
            self.speakerCharacter = speakerCharacter
            self.slideTransitionEffect = slideTransitionEffect
            self.slideTransitionDuration = slideTransitionDuration
            
            if !audioLayers.isEmpty {
                self.audioLayers = audioLayers
            } else if let audioPath, !audioPath.isEmpty, volume > 0.0001 {
                self.audioLayers = [AudioLayerInput(
                    path: audioPath,
                    volume: volume,
                    playbackRate: playbackRate,
                    isReversed: isReversed,
                    loops: false,
                    duration: audioDuration
                )]
            } else {
                self.audioLayers = []
            }
        }
    }

    struct Quality {
        var width: Int
        var height: Int
        var fps: Int
        var videoBitrate: String

        static func from(label: String) -> Quality {
            let q = label.lowercased()
            if q.contains("4k") {
                return Quality(width: 3840, height: 2160, fps: 30, videoBitrate: "12M")
            }
            if q.contains("720") {
                return Quality(width: 1280, height: 720, fps: 30, videoBitrate: "3M")
            }
            return Quality(width: 1920, height: 1080, fps: 30, videoBitrate: "6M")
        }
    }

    static func resolveFFmpegPath() -> String? {
        let candidates = [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/opt/local/bin/ffmpeg"
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
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
               !path.isEmpty,
               FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        } catch {}
        return nil
    }

    /// atempo は 0.5...2.0 のみなので、範囲外は連鎖させる
    static func atempoChain(_ rate: Double) -> String {
        var r = max(0.25, min(4.0, rate))
        var filters: [String] = []
        while r > 2.0 + 1e-6 {
            filters.append("atempo=2.0")
            r /= 2.0
        }
        while r < 0.5 - 1e-6 {
            filters.append("atempo=0.5")
            r /= 0.5
        }
        filters.append(String(format: "atempo=%.4f", r))
        return filters.joined(separator: ",")
    }

    static func exportMP4(
        scenes: [SceneInput],
        outputURL: URL,
        qualityLabel: String,
        progress: ((Double) -> Void)? = nil
    ) throws {
        guard !scenes.isEmpty else { throw ExportError.noScenes }
        guard let ffmpeg = resolveFFmpegPath() else { throw ExportError.ffmpegNotFound }

        let quality = Quality.from(label: qualityLabel)
        let fm = FileManager.default
        let workDir = fm.temporaryDirectory.appendingPathComponent(
            "TohoStudio_MovieExport_\(UUID().uuidString)",
            isDirectory: true
        )
        try fm.createDirectory(at: workDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: workDir) }

        var segmentURLs: [URL] = []
        let total = Double(max(scenes.count, 1))

        for (index, scene) in scenes.enumerated() {
            let segURL = workDir.appendingPathComponent(String(format: "seg_%04d.mp4", index))
            try encodeSegment(
                ffmpeg: ffmpeg,
                scene: scene,
                quality: quality,
                outputURL: segURL
            )
            segmentURLs.append(segURL)
            progress?(Double(index + 1) / (total + 1.0))
        }

        let listURL = workDir.appendingPathComponent("concat.txt")
        var listBody = ""
        for url in segmentURLs {
            let escaped = url.path.replacingOccurrences(of: "'", with: "'\\''")
            listBody += "file '\(escaped)'\n"
        }
        try listBody.write(to: listURL, atomically: true, encoding: .utf8)

        try fm.createDirectory(at: outputURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        if fm.fileExists(atPath: outputURL.path) {
            try fm.removeItem(at: outputURL)
        }

        let concatLog = try run(ffmpeg: ffmpeg, arguments: [
            "-y",
            "-f", "concat",
            "-safe", "0",
            "-i", listURL.path,
            "-c", "copy",
            "-movflags", "+faststart",
            outputURL.path
        ])

        let size = (try? outputURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        guard fm.fileExists(atPath: outputURL.path), size > 1000 else {
            throw ExportError.ffmpegFailed(truncate(concatLog))
        }

        let handle = try FileHandle(forReadingFrom: outputURL)
        defer { try? handle.close() }
        let head = handle.readData(ofLength: 12)
        let isFtyp = head.count >= 8 && head.subdata(in: 4..<8) == Data("ftyp".utf8)
        guard isFtyp else {
            throw ExportError.writeFailed("出力が MP4 コンテナではありません。")
        }
        progress?(1.0)
    }

    private static func encodeSegment(
        ffmpeg: String,
        scene: SceneInput,
        quality: Quality,
        outputURL: URL
    ) throws {
        let fm = FileManager.default
        let validLayers = scene.audioLayers.filter { fm.fileExists(atPath: $0.path) && $0.volume > 0.0001 }
        
        // シーン尺の決定: UI上のdurationを優先しつつ、有効な音声の再生尺も考慮
        var maxAudioPlayedDur = 0.0
        for layer in validLayers {
            let r = max(0.25, min(4.0, layer.playbackRate == 0 ? 1.0 : layer.playbackRate))
            let srcDur = layer.duration ?? scene.duration
            maxAudioPlayedDur = max(maxAudioPlayedDur, srcDur / r)
        }
        let transitionPad = max(0.0, scene.slideTransitionDuration ?? 0.0)
        let segmentDur = max(scene.duration, maxAudioPlayedDur > 0 ? maxAudioPlayedDur : 0.0, transitionPad, 0.2)
        let frames = max(1, Int(ceil(segmentDur * Double(quality.fps))))

        // 走査で得た animationMeta をプレビューと同じレシピで焼き込む
        let recipe = SlideAnimationKit.primarySlideRecipe(
            from: scene.animationMeta,
            forceWhenAnimated: scene.hasAnimation
        )
        let videoFilter = SlideAnimationKit.ffmpegVideoFilter(
            recipe: scene.hasAnimation ? recipe : nil,
            width: quality.width,
            height: quality.height,
            fps: quality.fps,
            frames: frames
        )

        var args: [String] = ["-y"]

        let bgCandidate = scene.backgroundImagePath ?? scene.imagePath
        let bgPath = (bgCandidate != nil && fm.fileExists(atPath: bgCandidate!)) ? bgCandidate : nil
        let charPath = (scene.characterImagePath != nil && fm.fileExists(atPath: scene.characterImagePath!)) ? scene.characterImagePath : nil

        var nextStreamIdx = 0
        var videoFilterGraph = ""
        
        // 映像入力設定
        if let bg = bgPath {
            args += ["-loop", "1", "-framerate", "\(quality.fps)", "-i", bg]
            let bgStream = nextStreamIdx
            nextStreamIdx += 1
            
            if let char = charPath {
                // キャラクター画像入力
                args += ["-loop", "1", "-framerate", "\(quality.fps)", "-i", char]
                let charStream = nextStreamIdx
                nextStreamIdx += 1
                
                let charHeight = max(100, Int(Double(quality.height) * 0.88))
                let charAnimToken = (scene.characterAnimation ?? "").lowercased()
                let wantsCharBounce = charAnimToken.contains("バウンス") || charAnimToken.contains("bounce") || charAnimToken.contains("呼吸") || charAnimToken.isEmpty
                let overlayY = wantsCharBounce ? "H-h+14*sin(2*PI*t*2)" : "H-h"
                videoFilterGraph = "[\(bgStream):v]\(videoFilter)[bg];[\(charStream):v]scale=-1:\(charHeight)[char];[bg][char]overlay=(W-w)/2:\(overlayY):format=auto[basev]"
                videoFilterGraph += Self.telopFilterSuffix(scene: scene, inputLabel: "basev", outputLabel: "vout")
            } else {
                videoFilterGraph = "[\(bgStream):v]\(videoFilter)[basev]"
                videoFilterGraph += Self.telopFilterSuffix(scene: scene, inputLabel: "basev", outputLabel: "vout")
            }
        } else {
            // 背景画像なし（単色黒）
            args += [
                "-f", "lavfi",
                "-i", "color=c=black:s=\(quality.width)x\(quality.height):r=\(quality.fps)"
            ]
            let bgStream = nextStreamIdx
            nextStreamIdx += 1
            
            if let char = charPath {
                args += ["-loop", "1", "-framerate", "\(quality.fps)", "-i", char]
                let charStream = nextStreamIdx
                nextStreamIdx += 1
                let charHeight = max(100, Int(Double(quality.height) * 0.88))
                let charAnimToken = (scene.characterAnimation ?? "").lowercased()
                let wantsCharBounce = charAnimToken.contains("バウンス") || charAnimToken.contains("bounce") || charAnimToken.contains("呼吸") || charAnimToken.isEmpty
                let overlayY = wantsCharBounce ? "H-h+14*sin(2*PI*t*2)" : "H-h"
                videoFilterGraph = "[\(bgStream):v]null[bg];[\(charStream):v]scale=-1:\(charHeight)[char];[bg][char]overlay=(W-w)/2:\(overlayY):format=auto[basev]"
                videoFilterGraph += Self.telopFilterSuffix(scene: scene, inputLabel: "basev", outputLabel: "vout")
            } else {
                videoFilterGraph = "[\(bgStream):v]null[basev]"
                videoFilterGraph += Self.telopFilterSuffix(scene: scene, inputLabel: "basev", outputLabel: "vout")
            }
        }

        // 音声入力設定
        let audioStartStreamIdx = nextStreamIdx
        for layer in validLayers {
            args += ["-i", layer.path]
            nextStreamIdx += 1
        }

        var filterComplexParts: [String] = [videoFilterGraph]
        var hasAudioOut = false

        if validLayers.isEmpty {
            // 音声なし: anullsrc で無音ストリームを合成
            args += [
                "-f", "lavfi",
                "-i", "anullsrc=channel_layout=stereo:sample_rate=44100"
            ]
            let anullStream = nextStreamIdx
            filterComplexParts.append("[\(anullStream):a]atrim=0:\(String(format: "%.3f", segmentDur)),apad[aout]")
            hasAudioOut = true
        } else if validLayers.count == 1 {
            let layer = validLayers[0]
            let r = max(0.25, min(4.0, layer.playbackRate == 0 ? 1.0 : layer.playbackRate))
            let vol = max(0.0, min(2.0, layer.volume))
            var afParts: [String] = []
            if layer.isReversed {
                afParts.append("areverse")
            }
            if abs(r - 1.0) > 0.001 {
                afParts.append(atempoChain(r))
            }
            afParts.append(String(format: "volume=%.4f", vol))
            afParts.append("apad")
            let afStr = afParts.joined(separator: ",")
            filterComplexParts.append("[\(audioStartStreamIdx):a]\(afStr)[aout]")
            hasAudioOut = true
        } else {
            // 複数音声レイヤーのamix
            var mixInputs = ""
            for (idx, layer) in validLayers.enumerated() {
                let streamIdx = audioStartStreamIdx + idx
                let r = max(0.25, min(4.0, layer.playbackRate == 0 ? 1.0 : layer.playbackRate))
                let vol = max(0.0, min(2.0, layer.volume))
                var afParts: [String] = []
                if layer.isReversed {
                    afParts.append("areverse")
                }
                if abs(r - 1.0) > 0.001 {
                    afParts.append(atempoChain(r))
                }
                afParts.append(String(format: "volume=%.4f", vol))
                let afStr = afParts.joined(separator: ",")
                filterComplexParts.append("[\(streamIdx):a]\(afStr)[a\(idx)]")
                mixInputs += "[a\(idx)]"
            }
            filterComplexParts.append("\(mixInputs)amix=inputs=\(validLayers.count):duration=longest:dropout_transition=0,apad[aout]")
            hasAudioOut = true
        }

        let fullFilterComplex = filterComplexParts.joined(separator: ";")
        args += [
            "-t", String(format: "%.3f", segmentDur),
            "-filter_complex", fullFilterComplex,
            "-map", "[vout]"
        ]
        if hasAudioOut {
            args += ["-map", "[aout]"]
        }
        args += [
            "-c:v", "libx264",
            "-preset", "veryfast",
            "-b:v", quality.videoBitrate,
            "-pix_fmt", "yuv420p",
            "-c:a", "aac",
            "-ac", "2",
            "-ar", "44100",
            "-b:a", "192k",
            outputURL.path
        ]

        let log = try run(ffmpeg: ffmpeg, arguments: args)
        guard fm.fileExists(atPath: outputURL.path) else {
            throw ExportError.ffmpegFailed(truncate(log))
        }
    }

    @discardableResult
    private static func run(ffmpeg: String, arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpeg)
        process.arguments = arguments
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        do {
            try process.run()
        } catch {
            throw ExportError.ffmpegFailed(error.localizedDescription)
        }
        process.waitUntilExit()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let combined = String(data: errData + outData, encoding: .utf8) ?? ""
        if process.terminationStatus != 0 {
            throw ExportError.ffmpegFailed(truncate(combined))
        }
        return combined
    }

    /// テロップがあれば drawtext。なければ null でラベルを転送。
    private static func telopFilterSuffix(scene: SceneInput, inputLabel: String, outputLabel: String) -> String {
        let raw = (scene.telopText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else {
            return ";[\(inputLabel)]null[\(outputLabel)]"
        }
        let speaker = scene.speakerCharacter ?? ""
        let display: String
        if !speaker.isEmpty && !raw.contains(speaker) {
            display = "\(speaker): \(raw)"
        } else {
            display = raw
        }
        let escaped = display
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: ":", with: "\\:")
            .replacingOccurrences(of: "'", with: "")
            .replacingOccurrences(of: "%", with: "")
            .components(separatedBy: .newlines).joined(separator: " ")
        let font = "/System/Library/Fonts/Hiragino Sans GB.ttc"
        return ";[\(inputLabel)]drawtext=fontfile=\(font):text='\(escaped)':x=(w-text_w)/2:y=h-72:fontsize=36:fontcolor=white:box=1:boxcolor=black@0.7:boxborderw=8[\(outputLabel)]"
    }

    private static func truncate(_ s: String, max: Int = 1200) -> String {
        if s.count <= max { return s }
        return String(s.suffix(max))
    }
}
