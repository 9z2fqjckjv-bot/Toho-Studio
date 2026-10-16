import Foundation
import AVFoundation
import Combine

/// サウンドメーカー専用のオーディオ再生管理マネージャー
/// BGM / SE の試聴プレビュー、倍速再生、逆再生、およびタイムライン同期再生を統括
public final class SoundMakerAudioManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    public static let shared = SoundMakerAudioManager()

    // 現在プレビュー試聴中のクリップID
    @Published public var currentlyPlayingClipId: UUID? = nil
    @Published public var isPreviewPlaying: Bool = false

    // 試聴用プレイヤー
    private var previewPlayer: AVAudioPlayer? = nil
    private var previewTimer: Timer? = nil

    // タイムライン再生用のマルチトラックプレイヤー辞書 [ClipID: AVAudioPlayer]
    private var timelinePlayers: [UUID: AVAudioPlayer] = [:]
    private var activeTimelineClipIds: Set<UUID> = []

    // 逆再生オーディオのキャッシュ (元パス+反転 -> テンポラリURL)
    private var reversedAudioCache: [String: URL] = [:]

    // 合成プリセット音源のキャッシュ (名前+反転 -> Data)
    private var synthesizedPresetCache: [String: Data] = [:]

    private override init() {
        super.init()
    }

    // MARK: - プレビュー試聴 (Toggle / Play / Stop)

    /// クリップの試聴再生をトグル
    public func togglePreview(clip: SoundClip, sceneDuration: Double? = nil) {
        if currentlyPlayingClipId == clip.id && isPreviewPlaying {
            stopPreview()
        } else {
            playPreview(clip: clip, sceneDuration: sceneDuration)
        }
    }

    /// フェード進行度 (0.0...1.0) を自然な聴感カーブ（S字スムースステップ / イコールパワー）に変換
    public static func fadeCurveGain(progress: Double) -> Double {
        let clamped = max(0.0, min(1.0, progress))
        // S-curve (0.5 * (1 - cos(π * x))) により、急激な立ち上がりや落ち込みを防ぎ滑らかに減衰
        return 0.5 * (1.0 - cos(.pi * clamped))
    }

    /// クリップの試聴再生を開始 (倍速再生・逆再生・音量・フェードイン・フェードアウト・即切りを適用)
    public func playPreview(clip: SoundClip, sceneDuration: Double? = nil, onFinished: (() -> Void)? = nil) {
        stopPreview()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            let player = self.createConfiguredPlayer(for: clip)

            DispatchQueue.main.async {
                guard let p = player else {
                    AppState.shared.log("⚠️ 音声再生の準備に失敗しました: \(clip.name)")
                    self.currentlyPlayingClipId = nil
                    self.isPreviewPlaying = false
                    return
                }

                self.previewPlayer = p
                self.previewPlayer?.delegate = self
                self.currentlyPlayingClipId = clip.id
                self.isPreviewPlaying = true

                // 実効再生時間と即切り上限
                // ループ再生（繰り返し）の場合は、クリップの指定 duration やシーン跨ぎ区間までループ再生を継続
                var playLimit: Double
                if clip.isLooping {
                    playLimit = max(clip.duration > 0 ? clip.duration : 60.0, clip.effectiveDuration * 4.0)
                } else {
                    // ループなしの場合、clip.duration が指定されていればその長さを上限とする
                    if clip.duration > 0 {
                        playLimit = min(clip.duration, clip.effectiveDuration)
                    } else {
                        playLimit = clip.effectiveDuration
                    }
                }

                // シーン終了時即切りが有効な場合の上限カット
                if clip.isCutOffOnSceneEnd, let sDur = sceneDuration, sDur > 0 {
                    playLimit = min(playLimit, sDur)
                }

                // フェードインの初期音量設定
                if clip.fadeInDuration > 0.001 {
                    p.volume = 0.0
                } else {
                    p.volume = Float(max(0.0, min(1.0, clip.volume)))
                }

                p.play()
                let rateStr = String(format: "%.2fx", clip.playbackRate)
                let revStr = clip.isReversed ? " [逆再生]" : ""
                let loopStr = clip.isLooping ? " [ループ有効]" : ""
                let cutStr = clip.isCutOffOnSceneEnd ? " [即切り有効]" : ""
                let fiStr = clip.fadeInDuration > 0 ? " [FI:\(String(format: "%.1f", clip.fadeInDuration))s]" : ""
                let foStr = clip.fadeOutDuration > 0 ? " [FO:\(String(format: "%.1f", clip.fadeOutDuration))s]" : ""
                AppState.shared.log("▶️ \(clip.type)『\(clip.name)』を再生中 (速度: \(rateStr)\(revStr), 音量: \(Int(clip.volume * 100))%\(loopStr)\(cutStr)\(fiStr)\(foStr))")

                // フェードおよび即切り監視タイマー
                let startTime = Date()
                self.previewTimer?.invalidate()
                let timer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] timer in
                    guard let self = self, let p = self.previewPlayer, p.isPlaying else {
                        timer.invalidate()
                        return
                    }

                    let elapsed = Date().timeIntervalSince(startTime)
                    let remaining = playLimit - elapsed

                    // 即切りまたは実効再生時間到達で停止
                    if elapsed >= playLimit {
                        self.stopPreview()
                        onFinished?()
                        return
                    }

                    // フェードイン計算
                    var inFactor = 1.0
                    if clip.fadeInDuration > 0.001 {
                        inFactor = SoundMakerAudioManager.fadeCurveGain(progress: elapsed / clip.fadeInDuration)
                    }

                    // フェードアウト計算
                    var outFactor = 1.0
                    if clip.fadeOutDuration > 0.001 {
                        outFactor = SoundMakerAudioManager.fadeCurveGain(progress: remaining / clip.fadeOutDuration)
                    }

                    let mult = min(inFactor, outFactor)
                    p.volume = Float(max(0.0, min(1.0, clip.volume * mult)))
                }
                self.previewTimer = timer
                RunLoop.main.add(timer, forMode: .common)
            }
        }
    }

    /// プレビュー試聴を停止
    public func stopPreview() {
        previewTimer?.invalidate()
        previewTimer = nil
        if let p = previewPlayer, p.isPlaying {
            p.stop()
        }
        previewPlayer = nil
        currentlyPlayingClipId = nil
        isPreviewPlaying = false
    }

    // MARK: - AVAudioPlayerDelegate
    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            if self.previewPlayer === player {
                self.stopPreview()
            }
        }
    }

    // MARK: - タイムライン同期再生

    /// タイムライン再生開始時に該当するクリップの音声を流す
    public func startTimelinePlayback(from time: Double, clips: [SoundClip], scenes: [MovieScene] = []) {
        stopTimelinePlayback()
        updateTimelinePlayback(currentTime: time, clips: clips, scenes: scenes)
    }

    /// タイムライン進行（タイマーtick）に合わせて音声を同期
    public func updateTimelinePlayback(currentTime: Double, clips: [SoundClip], scenes: [MovieScene] = []) {
        // シーンごとの開始・終了時刻マップ
        let targetScenes = !scenes.isEmpty ? scenes : AppState.shared.movieScenes
        var sceneRanges: [Int: (start: Double, end: Double)] = [:]
        var accTime: Double = 0.0
        for (i, sc) in targetScenes.enumerated() {
            sceneRanges[i + 1] = (accTime, accTime + sc.duration)
            accTime += sc.duration
        }

        // 現在時刻で鳴っているべきクリップ
        var shouldBePlayingIds: Set<UUID> = []

        for clip in clips {
            let clipStart = clip.startTime

            // クリップ本来の再生有効長
            // 繰り返し再生 (isLooping) の場合は、クリップの duration (または跨ぎ区間末尾) まで鳴り続ける
            // ループなしの場合は、音源自体の実効長 (effectiveDuration)
            let baseDuration = clip.isLooping ? max(clip.duration, clip.effectiveDuration) : (clip.duration > 0 ? min(clip.duration, clip.effectiveDuration) : clip.effectiveDuration)
            var clipEnd = clipStart + baseDuration

            // シーン跨ぎおよび単一シーンの即切り (isCutOffOnSceneEnd) 制御
            let isSpanning = clip.isSpanningScenes || (clip.spanStartSceneIndex != nil && clip.spanEndSceneIndex != nil)
            let targetCutSceneIndex = clip.spanEndSceneIndex ?? clip.sceneIndex

            // 台詞コンテキストの解決 (Voice クリップ または MovieScene の台詞)
            let dialogueCtx = VoiceTextTimingService.resolveDialogueContext(
                clip: clip,
                clips: clips,
                scenes: targetScenes
            )

            // 実効再生開始時刻の算出: セリフの任意の文字から再生開始
            var effectiveStart = clipStart
            var hasVoiceTrigger = false

            let targetChar = clip.startCharIndex ?? clip.fadeInCharIndex
            if let ctx = dialogueCtx, let charIdx = targetChar {
                if let timing = ctx.timings.first(where: { $0.index == charIdx }) {
                    effectiveStart = ctx.sceneStartTime + timing.startSeconds + clip.voiceTriggerOffset
                    hasVoiceTrigger = true
                }
            }

            // 実効再生終了時刻の算出
            clipEnd = effectiveStart + baseDuration

            if let targetIdx = targetCutSceneIndex, let targetRange = sceneRanges[targetIdx] {
                if isSpanning {
                    // シーン跨ぎSE・BGM: 跨ぎ終了シーンの末尾境界
                    let spanEndBoundary = targetRange.end
                    if clip.isLooping {
                        clipEnd = max(clipEnd, spanEndBoundary)
                    }
                    if clip.isCutOffOnSceneEnd {
                        clipEnd = min(clipEnd, spanEndBoundary)
                    }
                } else {
                    // 単一シーン所属:
                    if clip.isCutOffOnSceneEnd {
                        clipEnd = min(clipEnd, targetRange.end)
                    }
                }
            }

            // フェードアウト開始時刻の算出: セリフの任意の文字からフェードアウト開始
            var effectiveFadeOutStart = clipEnd - max(0.001, clip.fadeOutDuration)
            if let ctx = dialogueCtx, let outIdx = clip.fadeOutCharIndex {
                if let timing = ctx.timings.first(where: { $0.index == outIdx }) {
                    effectiveFadeOutStart = ctx.sceneStartTime + timing.startSeconds + clip.voiceTriggerOffset
                }
            }

            // 指定文字または開始時刻に達するまでは絶対に鳴らさない（発話開始時の強制音声開始を完全防止）
            let isActive = (currentTime >= effectiveStart && currentTime < clipEnd)

            if isActive {
                shouldBePlayingIds.insert(clip.id)

                // 指定文字の瞬間から音源の0秒目を流すため、effectiveStart からオフセットを計算
                let offsetInClip = (currentTime - effectiveStart) * max(0.25, clip.playbackRate)

                // フェードイン計算
                var inFactor = 1.0
                if clip.fadeInDuration > 0.001 {
                    let elapsedIn = currentTime - effectiveStart
                    inFactor = SoundMakerAudioManager.fadeCurveGain(progress: elapsedIn / clip.fadeInDuration)
                }

                // フェードアウト計算
                var outFactor = 1.0
                if clip.fadeOutDuration > 0.001 {
                    if currentTime >= effectiveFadeOutStart {
                        let elapsedOut = currentTime - effectiveFadeOutStart
                        let progress = min(1.0, max(0.0, elapsedOut / clip.fadeOutDuration))
                        outFactor = SoundMakerAudioManager.fadeCurveGain(progress: 1.0 - progress)
                    }
                } else if currentTime >= effectiveFadeOutStart {
                    outFactor = 0.0
                }

                let fadeMultiplier = min(inFactor, outFactor)
                let currentVol = Float(max(0.0, min(1.0, clip.volume * fadeMultiplier)))

                if let existingPlayer = timelinePlayers[clip.id] {
                    // 既に再生中の場合、フェードイン・フェードアウト音量を動的計算して適用
                    existingPlayer.volume = currentVol
                } else {
                    // 新たに再生開始 (初期音量をフェード係数に合わせて設定し音漏れを防止)
                    if let player = createConfiguredPlayer(for: clip, initialVolume: currentVol) {
                        let playerDur = player.duration
                        if playerDur > 0 {
                            let targetPlayerTime = clip.isLooping ? offsetInClip.truncatingRemainder(dividingBy: playerDur) : offsetInClip
                            if targetPlayerTime < playerDur {
                                player.volume = currentVol
                                player.currentTime = targetPlayerTime
                                player.play()
                                timelinePlayers[clip.id] = player
                            }
                        }
                    }
                }
            }
        }

        // 範囲外（シーン終了または即切り到達）になったプレイヤーを直ちに停止
        for (id, player) in timelinePlayers {
            if !shouldBePlayingIds.contains(id) {
                player.stop()
                timelinePlayers.removeValue(forKey: id)
            }
        }
    }

    /// タイムライン再生の音声をすべて停止
    public func stopTimelinePlayback() {
        for (_, player) in timelinePlayers {
            player.stop()
        }
        timelinePlayers.removeAll()
    }

    // MARK: - 設定済み AVAudioPlayer の生成

    /// クリップの設定（ファイル/プリセット、倍速再生、逆再生、音量、ループ）を適用した AVAudioPlayer を作成
    public func createConfiguredPlayer(for clip: SoundClip, initialVolume: Float? = nil) -> AVAudioPlayer? {
        var player: AVAudioPlayer? = nil

        // 1. 実ファイルが存在する場合
        if let path = clip.audioFilePath, FileManager.default.fileExists(atPath: path) {
            let fileURL = URL(fileURLWithPath: path)
            if clip.isReversed {
                // 逆再生ファイルの取得または生成
                if let revURL = reversedAudioURL(for: fileURL) {
                    player = try? AVAudioPlayer(contentsOf: revURL)
                }
            } else {
                player = try? AVAudioPlayer(contentsOf: fileURL)
            }
        }

        // 2. 実ファイルがない、または生成できなかった場合はセリフ合成またはプリセット音源を生成
        if player == nil {
            if clip.type == "Voice", let text = clip.text, !text.isEmpty {
                let char = clip.character ?? "博麗霊夢"
                let vType = clip.voiceType ?? AquesTalkBridge.shared.voiceType(for: char)
                let effectivePitch = clip.pitch != 100 ? clip.pitch : AquesTalkBridge.shared.characterPreset(for: char).pitch
                if let wavData = AquesTalkBridge.shared.synthesizeToWavData(
                    text: text,
                    speed: clip.speed,
                    voice: vType,
                    pitch: effectivePitch,
                    quality: .enhanced,
                    effect: .none
                ) {
                    player = try? AVAudioPlayer(data: wavData)
                }
            } else if let wavData = presetAudioData(for: clip) {
                player = try? AVAudioPlayer(data: wavData)
            }
        }

        guard let p = player else { return nil }

        // 倍速再生の適用
        p.enableRate = true
        let safeRate = Float(max(0.25, min(3.0, clip.playbackRate)))
        p.rate = safeRate

        // 音量とループ設定 (初期音量指定またはフェードイン時の0音量考慮)
        let resolvedVol: Float
        if let iv = initialVolume {
            resolvedVol = iv
        } else if clip.fadeInDuration > 0.001 {
            resolvedVol = 0.0
        } else {
            resolvedVol = Float(max(0.0, min(1.0, clip.volume)))
        }
        p.volume = resolvedVol
        p.numberOfLoops = clip.isLooping ? -1 : 0
        p.prepareToPlay()

        return p
    }

    // MARK: - 逆再生オーディオファイルの生成 & キャッシュ

    /// 外部オーディオファイル（wav, mp3, m4a等）を逆順に反転したテンポラリWAVファイルを生成
    private func reversedAudioURL(for sourceURL: URL) -> URL? {
        let key = sourceURL.path
        if let cached = reversedAudioCache[key], FileManager.default.fileExists(atPath: cached.path) {
            return cached
        }

        do {
            let file = try AVAudioFile(forReading: sourceURL)
            let format = file.processingFormat
            let frameCount = AVAudioFrameCount(file.length)
            guard frameCount > 0,
                  let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                return nil
            }
            try file.read(into: buffer)

            let channels = Int(format.channelCount)
            let frames = Int(buffer.frameLength)
            guard frames > 0, let channelData = buffer.floatChannelData else { return nil }

            guard let reversedBuffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames)) else {
                return nil
            }
            reversedBuffer.frameLength = AVAudioFrameCount(frames)
            guard let revChannelData = reversedBuffer.floatChannelData else { return nil }

            // 左右全チャンネルのサンプルを逆順にコピー
            for ch in 0..<channels {
                let src = channelData[ch]
                let dst = revChannelData[ch]
                for i in 0..<frames {
                    dst[i] = src[frames - 1 - i]
                }
            }

            // テンポラリディレクトリに書き出し
            let tempDir = FileManager.default.temporaryDirectory
            let outURL = tempDir.appendingPathComponent("reversed_\(UUID().uuidString).wav")
            let settings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM,
                AVSampleRateKey: format.sampleRate,
                AVNumberOfChannelsKey: channels,
                AVLinearPCMBitDepthKey: 16,
                AVLinearPCMIsFloatKey: false,
                AVLinearPCMIsBigEndianKey: false
            ]
            let outFile = try AVAudioFile(forWriting: outURL, settings: settings)
            try outFile.write(from: reversedBuffer)

            reversedAudioCache[key] = outURL
            return outURL
        } catch {
            print("Reversed audio generation failed: \(error)")
            return nil
        }
    }

    // MARK: - 高品質プリセット音源シンセシス

    /// プリセットのSEやBGMのWAVデータを生成 (実ファイルがない場合でも美しい音が鳴る)
    public func presetAudioData(for clip: SoundClip) -> Data? {
        let cacheKey = "\(clip.name)_\(clip.type)_\(clip.isReversed)"
        if let cached = synthesizedPresetCache[cacheKey] {
            return cached
        }

        let sampleRate = 44100
        var samples: [Float]

        if clip.type == "SE" {
            samples = generatePresetSESamples(name: clip.name, sampleRate: sampleRate)
        } else {
            samples = generatePresetBGMSamples(name: clip.name, sampleRate: sampleRate)
        }

        if clip.isReversed {
            samples.reverse()
        }

        let wavData = AudioEffectProcessor.shared.encodeToWav(samples: samples, sampleRate: sampleRate)
        synthesizedPresetCache[cacheKey] = wavData
        return wavData
    }

    // MARK: - 効果音 (SE) シンセ波形ジェネレータ
    private func generatePresetSESamples(name: String, sampleRate: Int) -> [Float] {
        let nLower = name.lowercased()

        if nLower.contains("決定") || nLower.contains("チャイム") || nLower.contains("システム") {
            // 決定音: C6 (1046Hz) と G6 (1568Hz) の澄んだクリスタル和音ベル
            let dur = 0.55
            let total = Int(dur * Double(sampleRate))
            var out = [Float](repeating: 0, count: total)
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = exp(-t * 7.5)
                let s1 = sin(2.0 * .pi * 1046.5 * t)
                let s2 = sin(2.0 * .pi * 1567.98 * t) * 0.7
                let s3 = sin(2.0 * .pi * 2093.0 * t) * 0.3
                out[i] = Float((s1 + s2 + s3) * env * 0.45)
            }
            return out
        } else if nLower.contains("キャンセル") {
            // キャンセル音: E5 (659Hz) -> C5 (523Hz) 下降トーン
            let dur = 0.35
            let total = Int(dur * Double(sampleRate))
            var out = [Float](repeating: 0, count: total)
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = exp(-t * 9.0)
                let freq = (t < 0.12) ? 659.25 : 523.25
                let s = sin(2.0 * .pi * freq * t) + 0.3 * sin(2.0 * .pi * freq * 2.0 * t)
                out[i] = Float(s * env * 0.42)
            }
            return out
        } else if nLower.contains("打撃") || nLower.contains("爆発") || nLower.contains("ヒット") {
            // 打撃・爆発音: サブベースピッチ急降下 + ホワイトノイズバースト
            let dur = 0.8
            let total = Int(dur * Double(sampleRate))
            var out = [Float](repeating: 0, count: total)
            var phase: Double = 0
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = exp(-t * 5.0)
                let freq = max(35.0, 160.0 * exp(-t * 12.0))
                phase += 2.0 * .pi * freq / Double(sampleRate)
                let kick = sin(phase)
                let noise = (Double.random(in: -1.0...1.0)) * exp(-t * 18.0) * 0.8
                out[i] = Float((kick * 0.65 + noise) * env * 0.55)
            }
            return out
        } else if nLower.contains("弾幕") || nLower.contains("発射") || nLower.contains("魔法") {
            // 弾幕魔法音: 1400Hz -> 400Hz の高速FMスイープ
            let dur = 0.45
            let total = Int(dur * Double(sampleRate))
            var out = [Float](repeating: 0, count: total)
            var phase: Double = 0
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = exp(-t * 6.5)
                let freq = max(300.0, 1400.0 * (1.0 - t / dur))
                phase += 2.0 * .pi * freq / Double(sampleRate)
                let mod = sin(2.0 * .pi * 80.0 * t) * 0.3
                let s = sin(phase + mod)
                let sparkle = (Double.random(in: -1.0...1.0)) * 0.15 * exp(-t * 10.0)
                out[i] = Float((s + sparkle) * env * 0.5)
            }
            return out
        } else if nLower.contains("ピチュン") || nLower.contains("被弾") || nLower.contains("消失") {
            // ピチュン: 東方特有のサイン波急降下 (1800Hz -> 220Hz)
            let dur = 0.65
            let total = Int(dur * Double(sampleRate))
            var out = [Float](repeating: 0, count: total)
            var phase: Double = 0
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = exp(-t * 5.5)
                let freq = max(180.0, 1800.0 * exp(-t * 15.0))
                phase += 2.0 * .pi * freq / Double(sampleRate)
                let s = sin(phase)
                out[i] = Float(s * env * 0.6)
            }
            return out
        } else if nLower.contains("スペルカード") || nLower.contains("キラーン") {
            // スペルカード展開: 華やかなアルペジオチャイム (E6, G#6, B6, E7)
            let dur = 1.6
            let total = Int(dur * Double(sampleRate))
            var out = [Float](repeating: 0, count: total)
            let freqs = [1318.5, 1661.2, 1975.5, 2637.0]
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                var sum: Double = 0
                for (idx, f) in freqs.enumerated() {
                    let delay = Double(idx) * 0.1
                    if t >= delay {
                        let noteT = t - delay
                        let env = exp(-noteT * 3.5)
                        sum += sin(2.0 * .pi * f * noteT) * env
                    }
                }
                out[i] = Float(sum * 0.28)
            }
            return out
        } else {
            // 汎用効果音 (ポップ音)
            let dur = 0.3
            let total = Int(dur * Double(sampleRate))
            var out = [Float](repeating: 0, count: total)
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = exp(-t * 14.0)
                let s = sin(2.0 * .pi * 880.0 * t)
                out[i] = Float(s * env * 0.45)
            }
            return out
        }
    }

    // MARK: - 背景音楽 (BGM) シンセ波形ジェネレータ
    private func generatePresetBGMSamples(name: String, sampleRate: Int) -> [Float] {
        let nLower = name.lowercased()

        if nLower.contains("恋色") || nLower.contains("マスタースパーク") {
            // ロック調疾走BGM: 約6.0秒 (160 BPM)
            return synthesizeArpBGM(
                scaleFreqs: [164.81, 196.0, 220.0, 246.94, 293.66, 329.63, 392.0], // Eマイナー
                bpm: 160.0,
                duration: 6.0,
                sampleRate: sampleRate,
                isRock: true
            )
        } else if nLower.contains("ほのぼの") || nLower.contains("日常") {
            // 明るいピチカート日常BGM: 約6.4秒 (120 BPM)
            return synthesizeArpBGM(
                scaleFreqs: [261.63, 293.66, 329.63, 392.0, 440.0, 523.25], // Cメジャーペンタ
                bpm: 120.0,
                duration: 6.4,
                sampleRate: sampleRate,
                isRock: false
            )
        } else {
            // 東方原曲風・和風オーケストラBGM (少女綺想曲風): 約6.4秒 (150 BPM)
            return synthesizeArpBGM(
                scaleFreqs: [293.66, 349.23, 392.0, 440.0, 523.25, 587.33, 698.46], // Dマイナー和風
                bpm: 150.0,
                duration: 6.4,
                sampleRate: sampleRate,
                isRock: false
            )
        }
    }

    /// 8分音符アルペジオ＋ベースラインの音楽ループ生成
    private func synthesizeArpBGM(
        scaleFreqs: [Double],
        bpm: Double,
        duration: Double,
        sampleRate: Int,
        isRock: Bool
    ) -> [Float] {
        let total = Int(duration * Double(sampleRate))
        var out = [Float](repeating: 0, count: total)

        let beatSeconds = 60.0 / bpm
        let stepSeconds = beatSeconds / 2.0 // 8分音符
        let totalSteps = Int(duration / stepSeconds)

        // リードメロディのステップパターン
        let melodySeq = [0, 2, 4, 3, 5, 4, 2, 1, 0, 3, 5, 6, 5, 4, 2, 0]

        for step in 0..<totalSteps {
            let noteIdx = melodySeq[step % melodySeq.count] % scaleFreqs.count
            let leadFreq = scaleFreqs[noteIdx]
            let bassFreq = scaleFreqs[0] / 2.0 // 1オクターブ下のルート音

            let stepStartSample = Int(Double(step) * stepSeconds * Double(sampleRate))
            let stepLenSamples = Int(stepSeconds * Double(sampleRate))

            for i in 0..<stepLenSamples {
                let sampleIdx = stepStartSample + i
                guard sampleIdx < total else { break }

                let t = Double(i) / Double(sampleRate)
                let noteEnv = max(0.0, 1.0 - (t / stepSeconds) * 0.8)

                // リードシンセ
                let s1 = sin(2.0 * .pi * leadFreq * t)
                let s2 = isRock ? sin(2.0 * .pi * leadFreq * 2.0 * t) * 0.4 : sin(2.0 * .pi * leadFreq * 3.0 * t) * 0.25
                let lead = (s1 + s2) * noteEnv * 0.28

                // ベース音 (4分音符ごと)
                let bassEnv = (step % 2 == 0) ? max(0.0, 1.0 - (t / (stepSeconds * 1.8))) : 0.0
                let bass = sin(2.0 * .pi * bassFreq * t) * bassEnv * 0.35

                // 軽いリズムクラップ/ハット
                let hat = (step % 2 == 1 && t < 0.05) ? (Double.random(in: -1...1) * 0.12 * (1.0 - t / 0.05)) : 0.0

                out[sampleIdx] += Float((lead + bass + hat) * 0.48)
            }
        }

        return out
    }
}
