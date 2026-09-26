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
    public func togglePreview(clip: SoundClip) {
        if currentlyPlayingClipId == clip.id && isPreviewPlaying {
            stopPreview()
        } else {
            playPreview(clip: clip)
        }
    }

    /// クリップの試聴再生を開始 (倍速再生・逆再生・音量を適用)
    public func playPreview(clip: SoundClip, onFinished: (() -> Void)? = nil) {
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

                p.play()
                let rateStr = String(format: "%.2fx", clip.playbackRate)
                let revStr = clip.isReversed ? " [逆再生]" : ""
                AppState.shared.log("▶️ \(clip.type)『\(clip.name)』を再生中 (速度: \(rateStr)\(revStr), 音量: \(Int(clip.volume * 100))%)")
            }
        }
    }

    /// プレビュー試聴を停止
    public func stopPreview() {
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
                self.currentlyPlayingClipId = nil
                self.isPreviewPlaying = false
                self.previewPlayer = nil
            }
        }
    }

    // MARK: - タイムライン同期再生

    /// タイムライン再生開始時に該当するクリップの音声を流す
    public func startTimelinePlayback(from time: Double, clips: [SoundClip]) {
        stopTimelinePlayback()
        updateTimelinePlayback(currentTime: time, clips: clips)
    }

    /// タイムライン進行（タイマーtick）に合わせて音声を同期
    public func updateTimelinePlayback(currentTime: Double, clips: [SoundClip]) {
        // 現在時刻で鳴っているべきクリップ
        var shouldBePlayingIds: Set<UUID> = []

        for clip in clips {
            // キャラ音声、BGM、SEを対象
            let effectiveDuration = max(0.2, clip.duration / max(0.25, clip.playbackRate))
            let clipStart = clip.startTime
            let clipEnd = clipStart + effectiveDuration

            let isActive = (currentTime >= clipStart && currentTime < clipEnd)

            if isActive {
                shouldBePlayingIds.insert(clip.id)

                if timelinePlayers[clip.id] == nil {
                    // 新たに再生開始
                    let offsetInClip = (currentTime - clipStart) * max(0.25, clip.playbackRate)
                    if let player = createConfiguredPlayer(for: clip) {
                        if offsetInClip < player.duration {
                            player.currentTime = offsetInClip
                            player.play()
                            timelinePlayers[clip.id] = player
                        }
                    }
                }
            }
        }

        // 範囲外になったプレイヤーを停止
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
    public func createConfiguredPlayer(for clip: SoundClip) -> AVAudioPlayer? {
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

        // 2. 実ファイルがない、または生成できなかった場合はプリセット音源を生成
        if player == nil {
            if let wavData = presetAudioData(for: clip) {
                player = try? AVAudioPlayer(data: wavData)
            }
        }

        guard let p = player else { return nil }

        // 倍速再生の適用
        p.enableRate = true
        let safeRate = Float(max(0.25, min(3.0, clip.playbackRate)))
        p.rate = safeRate

        // 音量とループ設定
        p.volume = Float(max(0.0, min(1.0, clip.volume)))
        p.numberOfLoops = (clip.type == "BGM" && clip.isLooping) ? -1 : 0
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
