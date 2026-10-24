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

        let targetSampleRate = quality.isEnabled ? 44100 : 8000

        // 1. バリピッチ＆リサンプリング (AVAudioConverter 最高品質Sinc補間)
        // ゆっくりボイスメーカーおよびSoftalkの正規仕様に完全準拠：
        // 音程（ピッチ：早苗135%、咲夜125%、こいし181%等）の変更を、Sincリサンプリングによる自然なスケーリングで実行。
        // フェーズボコーダーや波形切り貼りを一切介さないため、二重音・やまびこ・位相の濁り・お風呂場感・不自然な速度伸長が
        // 物理的に100%生じず、動画でおなじみの「あのゆっくりキャラの声とテンポ」そのものを完璧に再現します。
        let pitchRatio = (pitch > 0 && pitch != 100) ? (Double(pitch) / 100.0) : 1.0
        let effectiveSrcRate = Double(sampleRate) * pitchRatio

        if effectiveSrcRate != Double(targetSampleRate) {
            samples = resampleWithAudioConverter(samples: samples, from: effectiveSrcRate, to: Double(targetSampleRate))
            sampleRate = targetSampleRate
        }

        // 2. 高音質化時のボーカルプレゼンスEQ (こもり感を上品に引き締め、言葉の通りを向上)
        if quality.isEnabled {
            samples = applyVocalClarityEQ(samples: samples, sampleRate: sampleRate)
        }

        // 3. エフェクト処理 (ユーザーが明示的にエコーを指定した場合のみ)
        if effect == .echo {
            samples = applyEcho(samples: samples, sampleRate: sampleRate, delayTimeSeconds: 0.18, feedback: 0.36, wetLevel: 0.42)
        }

        // 4. ピークリミッティング (音割れ・クリップ歪みの防止)
        samples = applyPeakLimiter(samples: samples, targetPeak: 0.96)

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

    /// 2つ以上のWAVデータを同時に合成（ミックス）し、1つの16bit PCM WAVデータとして出力
    /// 2人の話者が同時に喋るユニゾン／デュエット音声を生成するために使用
    public func mixWavs(_ wavList: [Data], quality: AudioQualitySetting = .enhanced) -> Data? {
        let validWavs = wavList.compactMap { parseWav(data: $0) }
        guard !validWavs.isEmpty else { return nil }
        if validWavs.count == 1 {
            return wavList[0]
        }

        let targetSampleRate = quality.isEnabled ? 44100 : (validWavs.map { $0.sampleRate }.max() ?? 44100)

        // 全てのWAVを同一サンプリングレートにリサンプリング
        var resampledList: [[Float]] = []
        var maxSamples = 0
        for wav in validWavs {
            var s = wav.samples
            if wav.sampleRate != targetSampleRate {
                s = resampleWithAudioConverter(samples: s, from: Double(wav.sampleRate), to: Double(targetSampleRate))
            }
            if s.count > maxSamples {
                maxSamples = s.count
            }
            resampledList.append(s)
        }

        guard maxSamples > 0 else { return nil }

        // サンプルを加算合成
        var mixed = [Float](repeating: 0.0, count: maxSamples)
        // 話者数に応じたヘッドルーム係数 (2人なら各0.81倍程度にして自然な音量バランス＆音割れ防止)
        let scale: Float = resampledList.count > 1 ? (1.0 / sqrt(Float(resampledList.count))) * 1.15 : 1.0

        for sList in resampledList {
            for i in 0..<sList.count {
                mixed[i] += sList[i] * scale
            }
        }

        // 高音質化時のボーカルプレゼンス調整
        if quality.isEnabled {
            mixed = applyVocalClarityEQ(samples: mixed, sampleRate: targetSampleRate)
        }

        // ピークリミッター適用
        mixed = applyPeakLimiter(samples: mixed, targetPeak: 0.96)

        return encodeWav(samples: mixed, sampleRate: targetSampleRate)
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

    // MARK: - Resampling (AVAudioConverter with Max Quality Sinc Filter)
    private func resampleWithAudioConverter(samples: [Float], from srcRate: Double, to dstRate: Double) -> [Float] {
        guard !samples.isEmpty && srcRate > 0 && dstRate > 0 else { return samples }
        if abs(srcRate - dstRate) < 0.1 { return samples }

        guard let srcFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: srcRate, channels: 1, interleaved: false),
              let dstFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: dstRate, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: srcFormat, to: dstFormat) else {
            return resampleFallback(samples: samples, from: srcRate, to: dstRate)
        }

        converter.sampleRateConverterQuality = AVAudioQuality.max.rawValue

        let srcFrames = AVAudioFrameCount(samples.count)
        guard let srcBuffer = AVAudioPCMBuffer(pcmFormat: srcFormat, frameCapacity: srcFrames) else {
            return resampleFallback(samples: samples, from: srcRate, to: dstRate)
        }
        srcBuffer.frameLength = srcFrames
        let srcChannel = srcBuffer.floatChannelData![0]
        for i in 0..<samples.count {
            srcChannel[i] = samples[i]
        }

        let expectedDstFrames = AVAudioFrameCount(ceil(Double(srcFrames) * dstRate / srcRate))
        guard let dstBuffer = AVAudioPCMBuffer(pcmFormat: dstFormat, frameCapacity: expectedDstFrames + 2048) else {
            return resampleFallback(samples: samples, from: srcRate, to: dstRate)
        }

        var inputProvided = false
        var error: NSError?
        let status = converter.convert(to: dstBuffer, error: &error) { _, outStatus in
            if !inputProvided {
                inputProvided = true
                outStatus.pointee = .haveData
                return srcBuffer
            } else {
                outStatus.pointee = .endOfStream
                return nil
            }
        }

        if (status == .haveData || status == .endOfStream || status == .inputRanDry), dstBuffer.frameLength > 0 {
            var output = [Float](repeating: 0, count: Int(dstBuffer.frameLength))
            let ptr = dstBuffer.floatChannelData![0]
            for i in 0..<Int(dstBuffer.frameLength) {
                output[i] = ptr[i]
            }
            return output
        }

        return resampleFallback(samples: samples, from: srcRate, to: dstRate)
    }

    // MARK: - Resampling Fallback (Catmull-Rom Hermite)
    private func resampleFallback(samples: [Float], from srcRate: Double, to dstRate: Double) -> [Float] {
        guard !samples.isEmpty && srcRate > 0 && dstRate > 0 else { return samples }
        let ratio = srcRate / dstRate
        let outputCount = Int(Double(samples.count) * dstRate / srcRate)
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

            let a0 = -0.5 * p0 + 1.5 * p1 - 1.5 * p2 + 0.5 * p3
            let a1 = p0 - 2.5 * p1 + 2.0 * p2 - 0.5 * p3
            let a2 = -0.5 * p0 + 0.5 * p2
            let a3 = p1

            output[i] = a0 * frac * frac * frac + a1 * frac * frac + a2 * frac + a3
        }

        return output
    }

    // MARK: - Vocal Clarity EQ (自然なボーカル明瞭化・こもり抑制)
    /// 1. 80Hz以下の不要な直流・超低周波ノイズをカット (High-Pass)
    /// 2. 280Hz付近のこもり感を軽く引き締め (-1.5dB)
    /// 3. 3.0kHz付近の言葉の通り・滑舌をマイルドにブースト (+2.0dB)
    /// ※過剰なエキサイター歪みは排除し、AquesTalkのピュアでクリアな原音の透明感を最優先
    private func applyVocalClarityEQ(samples: [Float], sampleRate: Int) -> [Float] {
        guard samples.count > 4 else { return samples }
        let sr = Double(sampleRate)

        var hpFilter = BiquadFilter.highPass(sampleRate: sr, f0: 80.0, q: 0.707)
        var mudCutFilter = BiquadFilter.peakingEQ(sampleRate: sr, f0: 280.0, gainDB: -1.5, q: 1.0)
        var presenceFilter = BiquadFilter.peakingEQ(sampleRate: sr, f0: 3000.0, gainDB: 2.0, q: 1.0)

        var output = [Float](repeating: 0, count: samples.count)
        for i in 0..<samples.count {
            var s = samples[i]
            s = hpFilter.process(s)
            s = mudCutFilter.process(s)
            s = presenceFilter.process(s)
            output[i] = s
        }

        return output
    }

    // MARK: - Audio Biquad Filter (RBJ Audio EQ Cookbook準拠)
    private struct BiquadFilter {
        var b0: Float, b1: Float, b2: Float
        var a1: Float, a2: Float
        var x1: Float = 0, x2: Float = 0
        var y1: Float = 0, y2: Float = 0

        mutating func process(_ x: Float) -> Float {
            let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1
            x1 = x
            y2 = y1
            y1 = y
            return y
        }

        static func peakingEQ(sampleRate: Double, f0: Double, gainDB: Double, q: Double = 1.0) -> BiquadFilter {
            let A = pow(10.0, gainDB / 40.0)
            let w0 = 2.0 * .pi * f0 / sampleRate
            let alpha = sin(w0) / (2.0 * q)
            let cosw0 = cos(w0)

            let b0 = 1.0 + alpha * A
            let b1 = -2.0 * cosw0
            let b2 = 1.0 - alpha * A
            let a0 = 1.0 + alpha / A
            let a1 = -2.0 * cosw0
            let a2 = 1.0 - alpha / A

            return BiquadFilter(
                b0: Float(b0 / a0),
                b1: Float(b1 / a0),
                b2: Float(b2 / a0),
                a1: Float(a1 / a0),
                a2: Float(a2 / a0)
            )
        }

        static func highPass(sampleRate: Double, f0: Double, q: Double = 0.707) -> BiquadFilter {
            let w0 = 2.0 * .pi * f0 / sampleRate
            let alpha = sin(w0) / (2.0 * q)
            let cosw0 = cos(w0)

            let b0 = (1.0 + cosw0) / 2.0
            let b1 = -(1.0 + cosw0)
            let b2 = (1.0 + cosw0) / 2.0
            let a0 = 1.0 + alpha
            let a1 = -2.0 * cosw0
            let a2 = 1.0 - alpha

            return BiquadFilter(
                b0: Float(b0 / a0),
                b1: Float(b1 / a0),
                b2: Float(b2 / a0),
                a1: Float(a1 / a0),
                a2: Float(a2 / a0)
            )
        }
    }

    // MARK: - Echo / Delay Effect (明示指定時のみ適用)
    private func applyEcho(
        samples: [Float],
        sampleRate: Int,
        delayTimeSeconds: Double,
        feedback: Float,
        wetLevel: Float
    ) -> [Float] {
        let delaySamples = max(1, Int(delayTimeSeconds * Double(sampleRate)))
        let extraTailSamples = delaySamples * 4
        let totalCount = samples.count + extraTailSamples
        var output = [Float](repeating: 0, count: totalCount)

        var delayBuffer = [Float](repeating: 0, count: delaySamples)
        var delayIndex = 0

        for i in 0..<totalCount {
            let dry = (i < samples.count) ? samples[i] : 0.0
            let delayed = delayBuffer[delayIndex]

            let wet = delayed * wetLevel
            output[i] = dry * 0.88 + wet

            delayBuffer[delayIndex] = dry + delayed * feedback
            delayIndex = (delayIndex + 1) % delaySamples
        }

        return output
    }

    // MARK: - Peak Limiter (音割れ・クリップ歪み防止)
    private func applyPeakLimiter(samples: [Float], targetPeak: Float = 0.95) -> [Float] {
        guard !samples.isEmpty else { return samples }
        var maxPeak: Float = 0.0
        for s in samples {
            let a = abs(s)
            if a > maxPeak { maxPeak = a }
        }
        guard maxPeak > 0.0 else { return samples }

        if maxPeak > targetPeak {
            let scale = targetPeak / maxPeak
            return samples.map { $0 * scale }
        } else {
            return samples
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

