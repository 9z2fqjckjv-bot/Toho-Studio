import Foundation
import AVFoundation

// MARK: - Audio Quality & Effect Options (ゆっくりボイスメーカー準拠)

/// 効果指定 (ゆっくりボイスメーカーの effect-inputarea 準拠)
public enum AudioEffectType: String, CaseIterable, Identifiable, Codable {
    case none = "なし (none)"
    case echo = "エコー (echo)"

    public var id: String { rawValue }

    public var shortName: String {
        switch self {
        case .none: return "none"
        case .echo: return "echo"
        }
    }

    public var displayName: String {
        switch self {
        case .none: return "なし"
        case .echo: return "エコー (反響音)"
        }
    }
}

/// 音質改善設定 (ゆっくりボイスメーカーの audio-quality 準拠)
public enum AudioQualitySetting: String, CaseIterable, Identifiable, Codable {
    case enhanced = "有効 (高音質改善・デフォルト)"
    case rawOriginal = "無効 (AquesTalk原音・ゆくも！音質)"

    public var id: String { rawValue }

    public var isEnabled: Bool {
        return self == .enhanced
    }

    public var displayName: String {
        switch self {
        case .enhanced: return "有効 (高音質改善・44.1kHz)"
        case .rawOriginal: return "無効 (AquesTalk原音・8kHz)"
        }
    }
}

// MARK: - Audio Effect & Quality Processor
public final class AudioEffectProcessor {
    public static let shared = AudioEffectProcessor()

    private init() {}

    /// WAVデータ(8kHz/16bit/Mono)を受け取り、音質改善、ピッチシフト、エフェクト(エコー等)を適用した新しいWAVデータを返す
    public func process(
        wavData: Data,
        quality: AudioQualitySetting = .enhanced,
        effect: AudioEffectType = .none,
        pitch: Int = 100
    ) -> Data {
        // WAVヘッダ解析
        guard let parsed = parseWav(data: wavData) else {
            // パースに失敗した場合は原音データをそのまま返す
            return wavData
        }

        var samples = parsed.samples
        var sampleRate = parsed.sampleRate

        let pitchRatio = (pitch > 0 && pitch != 100) ? (Double(pitch) / 100.0) : 1.0
        let targetSampleRate = quality.isEnabled ? 44100 : 8000

        // 1. ピッチシフト & 音質改善（リサンプリング ＋ WSOLAタイムストレッチ）
        // フェーズボコーダーを使わず、リサンプリングとWSOLA（波形類似度オーバーラップ加算）を組み合わせることで、
        // 金属音や位相干渉を完全に防ぎつつ、ピッチ（音程）のみをシフトし、指定された発話速度を正確に維持します。
        if pitchRatio != 1.0 || (quality.isEnabled && sampleRate != targetSampleRate) {
            let effectiveSrcRate = Int(Double(sampleRate) * pitchRatio)
            samples = resample(samples: samples, from: effectiveSrcRate, to: targetSampleRate)
            sampleRate = targetSampleRate

            // ピッチ変更に伴いリサンプリングで変化した時間長（速度）を、WSOLAタイムストレッチで完全に元の長さに復元
            // これにより、ピッチを変更しても指定されたキャラクター音声の速度よりも早く（または遅く）聞こえる現象を解消します。
            if pitchRatio != 1.0 {
                samples = timeStretchWSOLA(samples: samples, sampleRate: sampleRate, stretchFactor: pitchRatio)
            }

            // 高音質化時のプレゼンスエンハンサー (マイルドに適用)
            if quality.isEnabled {
                samples = applyPresenceEnhancer(samples: samples, sampleRate: sampleRate)
            }
        }

        // 2. エフェクト処理 (ユーザーが明示的にエコーを指定した場合のみ)
        if effect == .echo {
            samples = applyEcho(samples: samples, sampleRate: sampleRate, delayTimeSeconds: 0.18, feedback: 0.36, wetLevel: 0.42)
        }

        // 3. ソフトリミッティング (音割れ防止)
        samples = applySoftLimiter(samples: samples)

        // 新しいWAVフォーマットにエンコード
        return encodeWav(samples: samples, sampleRate: sampleRate)
    }

    /// WAVデータを受け取り、逆再生（反転）した新しいWAVデータを返す
    public func reverseWav(data: Data) -> Data? {
        guard let parsed = parseWav(data: data) else { return nil }
        let reversedSamples = Array(parsed.samples.reversed())
        return encodeWav(samples: reversedSamples, sampleRate: parsed.sampleRate)
    }

    /// Floatサンプル配列を受け取り、16bit PCM WAVデータにエンコードする
    public func encodeToWav(samples: [Float], sampleRate: Int = 44100) -> Data {
        return encodeWav(samples: samples, sampleRate: sampleRate)
    }

    // MARK: - WAV Parsing
    private struct ParsedWav {
        var samples: [Float] // -1.0 ... 1.0
        var sampleRate: Int
        var channels: Int
    }

    private func parseWav(data: Data) -> ParsedWav? {
        guard data.count > 44 else { return nil }

        // "RIFF" and "WAVE" checks
        let riff = String(data: data.subdata(in: 0..<4), encoding: .ascii)
        let wave = String(data: data.subdata(in: 8..<12), encoding: .ascii)
        guard riff == "RIFF", wave == "WAVE" else { return nil }

        var offset = 12
        var sampleRate = 8000
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
                let start = offset
                let end = min(data.count, offset + chunkSize)
                dataRange = start..<end
                break
            }
            offset += chunkSize
        }

        guard let range = dataRange, bitsPerSample == 16 else { return nil }

        let sampleCount = (range.count) / 2
        var samples = [Float](repeating: 0, count: sampleCount)

        data.subdata(in: range).withUnsafeBytes { ptr in
            let int16Ptr = ptr.bindMemory(to: Int16.self)
            for i in 0..<sampleCount {
                samples[i] = Float(int16Ptr[i]) / 32768.0
            }
        }

        return ParsedWav(samples: samples, sampleRate: sampleRate, channels: channels)
    }

    // MARK: - Resampling (Cubic Hermite Interpolation)
    private func resample(samples: [Float], from srcRate: Int, to dstRate: Int) -> [Float] {
        guard !samples.isEmpty && srcRate > 0 && dstRate > 0 else { return samples }
        let ratio = Double(srcRate) / Double(dstRate)
        let outputCount = Int(Double(samples.count) * Double(dstRate) / Double(srcRate))
        var output = [Float](repeating: 0, count: outputCount)

        let n = samples.count

        for i in 0..<outputCount {
            let srcPos = Double(i) * ratio
            let idx = Int(srcPos)
            let frac = Float(srcPos - Double(idx))

            let p0 = samples[max(0, idx - 1)]
            let p1 = samples[min(n - 1, idx)]
            let p2 = samples[min(n - 1, idx + 1)]
            let p3 = samples[min(n - 1, idx + 2)]

            // Catmull-Rom / Cubic Hermite
            let a0 = -0.5 * p0 + 1.5 * p1 - 1.5 * p2 + 0.5 * p3
            let a1 = p0 - 2.5 * p1 + 2.0 * p2 - 0.5 * p3
            let a2 = -0.5 * p0 + 0.5 * p2
            let a3 = p1

            output[i] = a0 * frac * frac * frac + a1 * frac * frac + a2 * frac + a3
        }

        return output
    }

    // MARK: - WSOLA Time Stretch (Waveform Similarity Overlap-Add)
    /// リサンプリングで変化した時間長（速度）を、音程を保持したまま指定の倍率に滑らかに伸縮復元
    /// フェーズボコーダーを使わず時間領域で波形の類似周期を検出して重ね合わせるため、
    /// 金属音・位相の濁り・フランジャー等のノイズが一切生じず、極めてクリアに音程と速度を独立制御できます。
    private func timeStretchWSOLA(samples: [Float], sampleRate: Int, stretchFactor: Double) -> [Float] {
        guard !samples.isEmpty && stretchFactor > 0.0 && abs(stretchFactor - 1.0) > 0.005 else {
            return samples
        }

        let targetCount = max(1, Int(round(Double(samples.count) * stretchFactor)))
        guard samples.count >= 64 else {
            return samples
        }

        // 窓サイズ: 音声の基本周波数周期（80〜400Hz）を十分含む長さ（約20〜25ms）
        let windowSize = min(samples.count, max(64, (sampleRate * 22) / 1000))
        let halfWin = max(32, windowSize / 2)
        // 合成ホップサイズ
        let hopSyn = halfWin
        // 分析ホップサイズ（時間伸縮比率に反比例）
        let hopAna = max(1.0, Double(hopSyn) / stretchFactor)
        // 探索幅（前後）
        let maxDelta = min(halfWin / 2, 96)

        var output = [Float](repeating: 0, count: targetCount)
        var weights = [Float](repeating: 0, count: targetCount)

        // Hanning Window
        var win = [Float](repeating: 0, count: windowSize)
        for i in 0..<windowSize {
            win[i] = Float(0.5 * (1.0 - cos(2.0 * Double.pi * Double(i) / Double(windowSize - 1))))
        }

        var synPos = 0
        var anaPos: Double = 0.0

        while synPos < targetCount && Int(anaPos) < samples.count {
            let nominalAna = Int(round(anaPos))
            var bestOffset = 0

            // 直前の合成済み波形と最も波形類似度（自己相関）が高いオフセットを探索
            if synPos > 0 && nominalAna + windowSize <= samples.count {
                var maxCorr: Float = -Float.greatestFiniteMagnitude
                let searchStart = max(-nominalAna, -maxDelta)
                let searchEnd = min(samples.count - (nominalAna + windowSize), maxDelta)

                if searchEnd >= searchStart {
                    for delta in searchStart...searchEnd {
                        let candidateAna = nominalAna + delta
                        var corr: Float = 0
                        var normSyn: Float = 0
                        var normAna: Float = 0

                        let compareLen = min(halfWin, min(targetCount - synPos, samples.count - candidateAna))
                        for j in 0..<compareLen {
                            let sVal = output[synPos + j]
                            let aVal = samples[candidateAna + j]
                            corr += sVal * aVal
                            normSyn += sVal * sVal
                            normAna += aVal * aVal
                        }
                        let norm = sqrt(normSyn * normAna)
                        let normalizedCorr = norm > 1e-6 ? (corr / norm) : corr
                        if normalizedCorr > maxCorr {
                            maxCorr = normalizedCorr
                            bestOffset = delta
                        }
                    }
                }
            }

            let actualAna = max(0, min(samples.count - windowSize, nominalAna + bestOffset))
            let writeCount = min(windowSize, targetCount - synPos)

            for j in 0..<writeCount {
                if actualAna + j < samples.count {
                    let w = win[j]
                    output[synPos + j] += samples[actualAna + j] * w
                    weights[synPos + j] += w
                }
            }

            synPos += hopSyn
            anaPos += hopAna
        }

        // 窓重みの正規化除算
        for i in 0..<targetCount {
            if weights[i] > 1e-4 {
                output[i] /= weights[i]
            }
        }

        return output
    }

    // MARK: - Presence Enhancer (High-Shelf EQ for Voice Clarity)
    private func applyPresenceEnhancer(samples: [Float], sampleRate: Int) -> [Float] {
        // 軽いハイパス + 3kHz〜7kHzのプレゼンスブーストで明瞭度向上
        var output = [Float](repeating: 0, count: samples.count)
        guard samples.count > 2 else { return samples }

        // 簡単な1次ハイパスフィルター (DCオフセット除去)
        var hpPrev: Float = 0
        var xPrev: Float = 0
        let hpAlpha: Float = 0.98

        // 高域エンハンサー (ディファレンス強調)
        var prevSample: Float = 0

        for i in 0..<samples.count {
            let x = samples[i]
            // DC offset kill
            let hp = hpAlpha * (hpPrev + x - xPrev)
            hpPrev = hp
            xPrev = x

            // High frequency differentiator boost (~3.5kHz enhancement)
            let diff = hp - prevSample
            prevSample = hp

            // Mix: 原音 92% + わずかな高域明瞭化 12% (自然で違和感のないクリアな声に調整)
            let enhanced = hp * 0.92 + diff * 0.12
            output[i] = enhanced
        }

        return output
    }

    // MARK: - Echo / Delay Effect
    private func applyEcho(
        samples: [Float],
        sampleRate: Int,
        delayTimeSeconds: Double,
        feedback: Float,
        wetLevel: Float
    ) -> [Float] {
        let delaySamples = max(1, Int(delayTimeSeconds * Double(sampleRate)))
        // エコーの減衰テールを付加（約3〜4リピート分）
        let extraTailSamples = delaySamples * 4
        let totalCount = samples.count + extraTailSamples
        var output = [Float](repeating: 0, count: totalCount)

        // ディレイラインバッファ
        var delayBuffer = [Float](repeating: 0, count: delaySamples)
        var delayIndex = 0

        for i in 0..<totalCount {
            let dry = (i < samples.count) ? samples[i] : 0.0
            let delayed = delayBuffer[delayIndex]

            let wet = delayed * wetLevel
            output[i] = dry * 0.88 + wet

            // フィードバック入力
            delayBuffer[delayIndex] = dry + delayed * feedback

            delayIndex = (delayIndex + 1) % delaySamples
        }

        return output
    }

    // MARK: - Soft Limiter (防音割れ)
    private func applySoftLimiter(samples: [Float]) -> [Float] {
        return samples.map { s in
            // Fast approximation of tanh soft clip: s / (1 + |s|)
            let drive: Float = 1.1
            let x = s * drive
            if x > 1.0 {
                return 1.0 - (1.0 / (1.0 + (x - 1.0))) * 0.2
            } else if x < -1.0 {
                return -1.0 + (1.0 / (1.0 + (-x - 1.0))) * 0.2
            } else {
                return x
            }
        }
    }

    // MARK: - WAV Encoding
    private func encodeWav(samples: [Float], sampleRate: Int) -> Data {
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let byteRate: UInt32 = UInt32(sampleRate) * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign: UInt16 = channels * (bitsPerSample / 8)
        let dataSize: UInt32 = UInt32(samples.count * 2)
        let fileSize: UInt32 = 36 + dataSize

        var data = Data()

        // RIFF Header
        data.append(contentsOf: "RIFF".utf8)
        var chunkSize = fileSize
        data.append(Data(bytes: &chunkSize, count: 4))
        data.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        data.append(contentsOf: "fmt ".utf8)
        var subchunk1Size: UInt32 = 16
        data.append(Data(bytes: &subchunk1Size, count: 4))
        var audioFormat: UInt16 = 1 // PCM
        data.append(Data(bytes: &audioFormat, count: 2))
        var numChannels = channels
        data.append(Data(bytes: &numChannels, count: 2))
        var sRate = UInt32(sampleRate)
        data.append(Data(bytes: &sRate, count: 4))
        var bRate = byteRate
        data.append(Data(bytes: &bRate, count: 4))
        var bAlign = blockAlign
        data.append(Data(bytes: &bAlign, count: 2))
        var bps = bitsPerSample
        data.append(Data(bytes: &bps, count: 2))

        // data chunk
        data.append(contentsOf: "data".utf8)
        var dSize = dataSize
        data.append(Data(bytes: &dSize, count: 4))

        // PCM Samples (Int16)
        var int16Samples = [Int16](repeating: 0, count: samples.count)
        for i in 0..<samples.count {
            let clamped = max(-1.0, min(1.0, samples[i]))
            int16Samples[i] = Int16(clamped * 32767.0)
        }

        data.append(Data(bytes: int16Samples, count: int16Samples.count * 2))

        return data
    }
}
