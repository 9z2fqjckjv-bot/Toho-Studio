import Foundation
import AVFoundation
import SwiftUI
import Combine

/// 東方Project専用 AI BGM & SE 生成サービス
/// プロシージャル・シンセ波形合成によるBGM/SE生成、リアルタイム試聴、およびSoundMaker/MovieMaker/素材スタジオ連携
public final class AISoundGeneratorService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    public static let shared = AISoundGeneratorService()

    // MARK: - BGM生成パラメータ
    @Published public var bgmTheme: BGMThemePreset = .hakureiShrineSpeed
    @Published public var bgmBPM: Double = 150.0
    @Published public var bgmDurationSeconds: Double = 12.0
    @Published public var bgmInstrumentStyle: BGMInstrumentStyle = .zunPetAndRock
    @Published public var isBGMGenerating: Bool = false
    @Published public var generatedBGMURL: URL? = nil
    @Published public var isBGMPlaying: Bool = false

    // MARK: - SE生成パラメータ
    @Published public var sePreset: SEPresetType = .spellCardChime
    @Published public var seBaseFrequency: Double = 1320.0
    @Published public var seDurationSeconds: Double = 1.2
    @Published public var seNoiseMix: Double = 0.2
    @Published public var seIsReversed: Bool = false
    @Published public var isSEGenerating: Bool = false
    @Published public var generatedSEURL: URL? = nil
    @Published public var isSEPlaying: Bool = false

    // MARK: - 生成履歴
    @Published public var soundHistory: [GeneratedSoundItem] = []

    // 内部オーディオプレイヤー
    private var bgmPlayer: AVAudioPlayer? = nil
    private var sePlayer: AVAudioPlayer? = nil

    // MARK: - プリセット定義
    public enum BGMThemePreset: String, CaseIterable, Identifiable {
        case hakureiShrineSpeed = "博麗神社 〜 巫女の日常と疾走 (少女綺想曲風)"
        case magicForestRock = "魔法の森 〜 恋色マスタースパーク風 (シンセロック)"
        case scarletDevilMansion = "紅魔館 〜 亡き王女の為のセプテット風 (ゴシック緊迫)"
        case netherworldCherry = "白玉楼 〜 幽雅に咲かせ、墨染の桜風 (和風オーケストラ)"
        case cirnoIcePop = "おてんば恋娘風 〜 氷の妖精 (軽快ポップ)"
        case teaTimeDaily = "縁側のお茶会 〜 ほのぼの日常会話 (アコースティック)"
        case lastSpellBoss = "決戦ラストスペル 〜 極限の弾幕結界 (緊迫ハイテンポ)"

        public var id: String { rawValue }

        public var defaultBPM: Double {
            switch self {
            case .hakureiShrineSpeed: return 150.0
            case .magicForestRock: return 165.0
            case .scarletDevilMansion: return 145.0
            case .netherworldCherry: return 138.0
            case .cirnoIcePop: return 160.0
            case .teaTimeDaily: return 116.0
            case .lastSpellBoss: return 175.0
            }
        }

        public var scaleFrequencies: [Double] {
            switch self {
            case .hakureiShrineSpeed:
                // Dマイナー和風ヨナ抜き (D, F, G, A, C, D)
                return [293.66, 349.23, 392.00, 440.00, 523.25, 587.33]
            case .magicForestRock:
                // Eマイナーペンタトニック (E, G, A, B, D, E)
                return [164.81, 196.00, 220.00, 246.94, 293.66, 329.63]
            case .scarletDevilMansion:
                // Cマイナー・ハーモニックマイナー (C, D, Eb, G, Ab, B)
                return [261.63, 293.66, 311.13, 392.00, 415.30, 493.88]
            case .netherworldCherry:
                // Aマイナー和風調 (A, B, C, E, F, A)
                return [220.00, 246.94, 261.63, 329.63, 349.23, 440.00]
            case .cirnoIcePop:
                // Fメジャースケール (F, G, A, Bb, C, D)
                return [349.23, 392.00, 440.00, 466.16, 523.25, 587.33]
            case .teaTimeDaily:
                // Cメジャーペンタトニック (C, D, E, G, A)
                return [261.63, 293.66, 329.63, 392.00, 440.00]
            case .lastSpellBoss:
                // Gマイナー・ディミニッシュ混成 (G, Bb, C#, D, F)
                return [196.00, 233.08, 277.18, 293.66, 349.23, 392.00]
            }
        }
    }

    public enum BGMInstrumentStyle: String, CaseIterable, Identifiable {
        case zunPetAndRock = "ZUNペットリード ＆ ロックドラム (王道東方スタイル)"
        case pianoAndStrings = "ピアノアルペジオ ＆ 哀愁ストリングス"
        case traditionalJapanese = "和太鼓・篠笛・琴 (純和風幻想)"
        case chiptune8Bit = "8bit ファミコン・レトロ音源"

        public var id: String { rawValue }
    }

    public enum SEPresetType: String, CaseIterable, Identifiable {
        case spellCardChime = "スペルカード展開 (キラーン・煌びやかチャイム)"
        case masterSparkLaser = "マスタースパーク照射 (極太重低音レーザー)"
        case danmakuShot = "弾幕連射ショット (ピュンピュン連射)"
        case playerPichuun = "被弾・ピチューン (名物レトロ被弾音)"
        case timeStopSakuya = "咲夜の時間停止・解除 (針音＆逆再生スウィープ)"
        case teleportWarp = "瞬間移動・ワープ (高速フェイザー突風)"
        case grazeSound = "グレイズかすり音 (クリスプ高音チャイム)"
        case uiConfirm = "UI決定音 (澄んだベルチャイム)"
        case uiCancel = "UIキャンセル音 (木琴下降音)"
        case teaCupSound = "縁側のお茶啜り・日常音 (ほのぼの環境音)"

        public var id: String { rawValue }

        public var defaultFrequency: Double {
            switch self {
            case .spellCardChime: return 1320.0
            case .masterSparkLaser: return 180.0
            case .danmakuShot: return 1800.0
            case .playerPichuun: return 880.0
            case .timeStopSakuya: return 600.0
            case .teleportWarp: return 400.0
            case .grazeSound: return 2400.0
            case .uiConfirm: return 1046.5
            case .uiCancel: return 523.25
            case .teaCupSound: return 440.0
            }
        }

        public var defaultDuration: Double {
            switch self {
            case .spellCardChime: return 1.6
            case .masterSparkLaser: return 2.8
            case .danmakuShot: return 0.4
            case .playerPichuun: return 1.2
            case .timeStopSakuya: return 1.5
            case .teleportWarp: return 0.6
            case .grazeSound: return 0.25
            case .uiConfirm: return 0.35
            case .uiCancel: return 0.3
            case .teaCupSound: return 1.0
            }
        }
    }

    public struct GeneratedSoundItem: Identifiable, Equatable {
        public let id: UUID = UUID()
        public let name: String
        public let type: String // "BGM" or "SE"
        public let duration: Double
        public let fileURL: URL
        public let createdAt: Date
        public let detailDescription: String
    }

    private override init() {
        super.init()
        seedInitialPresetSounds()
    }

    private func seedInitialPresetSounds() {
        // 初期サンプルBGMとSEを生成・バッファ
        generateBGM(silent: true)
        generateSE(silent: true)
    }

    // MARK: - BGM生成実行
    public func generateBGM(silent: Bool = false) {
        guard !isBGMGenerating else { return }

        if !silent {
            let linuxService = CloudVirtualLinuxService.shared
            guard linuxService.consumePrompt(count: 1, purpose: "TohoAIStudio BGM生成") else {
                AppState.shared.addSystemLog(level: "ERROR", message: "AI BGM生成失敗: プロンプト残数が0です。")
                return
            }
            isBGMGenerating = true
        }

        let theme = bgmTheme
        let bpm = bgmBPM
        let duration = bgmDurationSeconds
        let style = bgmInstrumentStyle

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let sampleRate = 44100
            let samples = self.synthesizeFullBGM(
                theme: theme,
                bpm: bpm,
                duration: duration,
                style: style,
                sampleRate: sampleRate
            )

            let wavData = self.encodeWAVData(samples: samples, sampleRate: sampleRate, channels: 2)

            let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("TohoAI_Audio", isDirectory: true)
            try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

            let fileName = "TohoAI_BGM_\(theme.rawValue.prefix(6))_\(Int(Date().timeIntervalSince1970)).wav"
            let fileURL = outputDir.appendingPathComponent(fileName)
            try? wavData.write(to: fileURL)

            DispatchQueue.main.async {
                self.isBGMGenerating = false
                self.generatedBGMURL = fileURL

                let item = GeneratedSoundItem(
                    name: "\(theme.rawValue.prefix(12)) (BPM \(Int(bpm)))",
                    type: "BGM",
                    duration: duration,
                    fileURL: fileURL,
                    createdAt: Date(),
                    detailDescription: "東方風BGM: \(style.rawValue), 尺: \(Int(duration))秒"
                )
                self.soundHistory.insert(item, at: 0)

                if !silent {
                    AppState.shared.addSystemLog(level: "INFO", message: "TohoAIStudio: BGM「\(item.name)」を生成しました。")
                }
            }
        }
    }

    // MARK: - SE生成実行
    public func generateSE(silent: Bool = false) {
        guard !isSEGenerating else { return }

        if !silent {
            let linuxService = CloudVirtualLinuxService.shared
            guard linuxService.consumePrompt(count: 1, purpose: "TohoAIStudio SE生成") else {
                AppState.shared.addSystemLog(level: "ERROR", message: "AI SE生成失敗: プロンプト残数が0です。")
                return
            }
            isSEGenerating = true
        }

        let preset = sePreset
        let baseFreq = seBaseFrequency
        let duration = seDurationSeconds
        let noiseMix = seNoiseMix
        let isReversed = seIsReversed

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let sampleRate = 44100
            var samples = self.synthesizeSE(
                preset: preset,
                baseFreq: baseFreq,
                duration: duration,
                noiseMix: noiseMix,
                sampleRate: sampleRate
            )

            if isReversed {
                samples.reverse()
            }

            let wavData = self.encodeWAVData(samples: samples, sampleRate: sampleRate, channels: 1)

            let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("TohoAI_Audio", isDirectory: true)
            try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

            let fileName = "TohoAI_SE_\(preset.rawValue.prefix(6))_\(Int(Date().timeIntervalSince1970)).wav"
            let fileURL = outputDir.appendingPathComponent(fileName)
            try? wavData.write(to: fileURL)

            DispatchQueue.main.async {
                self.isSEGenerating = false
                self.generatedSEURL = fileURL

                let item = GeneratedSoundItem(
                    name: "\(preset.rawValue.prefix(12))",
                    type: "SE",
                    duration: duration,
                    fileURL: fileURL,
                    createdAt: Date(),
                    detailDescription: "東方風SE: \(Int(baseFreq))Hz, \(String(format: "%.1f", duration))秒\(isReversed ? " [逆再生]" : "")"
                )
                self.soundHistory.insert(item, at: 0)

                if !silent {
                    AppState.shared.addSystemLog(level: "INFO", message: "TohoAIStudio: SE「\(item.name)」を生成しました。")
                }
            }
        }
    }

    // MARK: - 試聴プレビュー制御
    public func togglePlayBGM() {
        if isBGMPlaying {
            bgmPlayer?.stop()
            isBGMPlaying = false
        } else {
            guard let url = generatedBGMURL else { return }
            do {
                bgmPlayer = try AVAudioPlayer(contentsOf: url)
                bgmPlayer?.delegate = self
                bgmPlayer?.numberOfLoops = -1 // ループ再生
                bgmPlayer?.play()
                isBGMPlaying = true
            } catch {
                print("BGM再生失敗: \(error)")
            }
        }
    }

    public func togglePlaySE() {
        guard let url = generatedSEURL else { return }
        do {
            sePlayer?.stop()
            sePlayer = try AVAudioPlayer(contentsOf: url)
            sePlayer?.delegate = self
            sePlayer?.play()
            isSEPlaying = true
        } catch {
            print("SE再生失敗: \(error)")
        }
    }

    public func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            if player == self.sePlayer {
                self.isSEPlaying = false
            }
            if player == self.bgmPlayer && player.numberOfLoops == 0 {
                self.isBGMPlaying = false
            }
        }
    }

    // MARK: - 制作スタジオ連携
    public func applyToSoundMaker(item: GeneratedSoundItem) {
        let clip = SoundClip(
            name: item.name,
            type: item.type,
            duration: item.duration,
            volume: 0.8,
            startTime: 0.0,
            audioFilePath: item.fileURL.path
        )
        AppState.shared.soundClips.append(clip)
        AppState.shared.addHistory("AI生成音声「\(item.name)」をサウンドメーカーのタイムラインへ配置")
    }

    public func applyToMovieMaker(item: GeneratedSoundItem) {
        if let lastIdx = AppState.shared.movieScenes.indices.last {
            if item.type == "BGM" {
                AppState.shared.movieScenes[lastIdx].audioTrack = item.fileURL.lastPathComponent
                AppState.shared.movieScenes[lastIdx].bgmAudioPath = item.fileURL.path
                AppState.shared.movieScenes[lastIdx].bgmName = item.name
            } else {
                AppState.shared.movieScenes[lastIdx].seAudioPath = item.fileURL.path
                AppState.shared.movieScenes[lastIdx].seName = item.name
            }
        }
        AppState.shared.addHistory("AI生成音声「\(item.name)」をムービーメーカーへ適用")
    }

    public func saveToMaterialStudio(item: GeneratedSoundItem) {
        let mat = MaterialItem(
            title: item.name,
            type: "音声",
            category: item.type == "BGM" ? "AI生成BGM" : "AI生成効果音",
            filePath: item.fileURL.path,
            fileSize: (try? FileManager.default.attributesOfItem(atPath: item.fileURL.path)[.size] as? Int64) ?? 102400,
            createdAt: Date()
        )
        AppState.shared.materials.append(mat)
        AppState.shared.addHistory("AI生成音声「\(item.name)」を素材スタジオへ登録")
    }

    // MARK: - BGM多重トラック波形合成
    private func synthesizeFullBGM(
        theme: BGMThemePreset,
        bpm: Double,
        duration: Double,
        style: BGMInstrumentStyle,
        sampleRate: Int
    ) -> [Float] {
        let totalSamples = Int(duration * Double(sampleRate))
        var left = [Float](repeating: 0, count: totalSamples)
        var right = [Float](repeating: 0, count: totalSamples)

        let beatSec = 60.0 / bpm
        let stepSec = beatSec / 2.0 // 8分音符
        let totalSteps = Int(duration / stepSec)
        let freqs = theme.scaleFrequencies

        // メロディ進行パターン
        let melodySeq = [0, 2, 4, 3, 5, 4, 2, 1, 0, 3, 5, 4, 2, 4, 1, 0]

        for step in 0..<totalSteps {
            let noteIdx = melodySeq[step % melodySeq.count] % freqs.count
            let leadFreq = freqs[noteIdx]
            let bassFreq = freqs[0] / 2.0

            let stepStart = Int(Double(step) * stepSec * Double(sampleRate))
            let stepLen = Int(stepSec * Double(sampleRate))

            for i in 0..<stepLen {
                let idx = stepStart + i
                guard idx < totalSamples else { break }

                let t = Double(i) / Double(sampleRate)
                let noteEnv = max(0.0, 1.0 - (t / stepSec) * 0.75)

                // 1. リード音（ZUNペット / ピアノ / 笛）
                var lead: Double = 0.0
                switch style {
                case .zunPetAndRock:
                    // ZUNペット特有のブラス感（奇数倍音＋ブラスビブラート）
                    let vib = sin(2.0 * .pi * 5.5 * t) * 0.03
                    let f = leadFreq * (1.0 + vib)
                    let s1 = sin(2.0 * .pi * f * t)
                    let s2 = sin(2.0 * .pi * f * 2.0 * t) * 0.5
                    let s3 = sin(2.0 * .pi * f * 3.0 * t) * 0.35
                    lead = (s1 + s2 + s3) * noteEnv * 0.32
                case .pianoAndStrings:
                    // ピアノ風打鍵減衰
                    let decay = exp(-t * 8.0)
                    lead = sin(2.0 * .pi * leadFreq * t) * decay * 0.35
                case .traditionalJapanese:
                    // 篠笛風（柔らかな倍音と空気感）
                    let breath = Double.random(in: -1...1) * 0.05
                    lead = (sin(2.0 * .pi * leadFreq * t) + breath) * noteEnv * 0.30
                case .chiptune8Bit:
                    // 矩形波
                    let phase = fmod(t * leadFreq, 1.0)
                    lead = (phase < 0.5 ? 1.0 : -1.0) * noteEnv * 0.22
                }

                // 2. ベースライン
                let bassEnv = (step % 2 == 0) ? max(0.0, 1.0 - (t / (stepSec * 1.8))) : 0.0
                let bass = sin(2.0 * .pi * bassFreq * t) * bassEnv * 0.30

                // 3. ドラム（キック ＆ スネア ＆ ハイハット）
                var drum: Double = 0.0
                if step % 4 == 0 && t < 0.12 { // キック
                    let kEnv = exp(-t * 28.0)
                    let kFreq = max(45.0, 150.0 * exp(-t * 35.0))
                    drum += sin(2.0 * .pi * kFreq * t) * kEnv * 0.45
                }
                if step % 4 == 2 && t < 0.15 { // スネア
                    let sEnv = exp(-t * 20.0)
                    let noise = Double.random(in: -1...1) * sEnv * 0.30
                    let tone = sin(2.0 * .pi * 200.0 * t) * sEnv * 0.20
                    drum += (noise + tone)
                }
                if step % 2 == 1 && t < 0.04 { // ハイハット
                    drum += Double.random(in: -1...1) * exp(-t * 70.0) * 0.15
                }

                // ステレオパンニング（リードはやや左、ストリングス/ベースはセンター）
                let combined = Float((lead + bass + drum) * 0.45)
                left[idx] += combined * 0.95
                right[idx] += combined * 1.05
            }
        }

        // インターリーブ・ステレオ波形生成
        var interleaved = [Float](repeating: 0, count: totalSamples * 2)
        for i in 0..<totalSamples {
            interleaved[i * 2] = min(max(left[i], -1.0), 1.0)
            interleaved[i * 2 + 1] = min(max(right[i], -1.0), 1.0)
        }
        return interleaved
    }

    // MARK: - SE単音波形合成
    private func synthesizeSE(
        preset: SEPresetType,
        baseFreq: Double,
        duration: Double,
        noiseMix: Double,
        sampleRate: Int
    ) -> [Float] {
        let total = Int(duration * Double(sampleRate))
        var out = [Float](repeating: 0, count: total)

        switch preset {
        case .spellCardChime:
            // 華やかなアルペジオチャイム (4重和音)
            let freqs = [baseFreq, baseFreq * 1.2599, baseFreq * 1.4983, baseFreq * 2.0]
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                var sum: Double = 0
                for (idx, f) in freqs.enumerated() {
                    let delay = Double(idx) * 0.08
                    if t >= delay {
                        let noteT = t - delay
                        let env = exp(-noteT * 3.8)
                        sum += sin(2.0 * .pi * f * noteT) * env
                    }
                }
                out[i] = Float(sum * 0.32)
            }

        case .masterSparkLaser:
            // 極太レーザー: サブベース + 急降下周波数 + ディストーション
            var phase: Double = 0
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = exp(-t * 1.5)
                let freq = max(60.0, baseFreq * exp(-t * 2.2))
                phase += 2.0 * .pi * freq / Double(sampleRate)

                let s = sin(phase)
                let noise = Double.random(in: -1...1) * noiseMix
                let wave = (s + noise) * env
                // クランチ・ディストーション
                let distorted = tanh(wave * 2.2)
                out[i] = Float(distorted * 0.65)
            }

        case .danmakuShot:
            // 弾幕ショット: ピュンピュン高音スイープ
            var phase: Double = 0
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = exp(-t * 12.0)
                let freq = max(300.0, baseFreq * exp(-t * 18.0))
                phase += 2.0 * .pi * freq / Double(sampleRate)
                out[i] = Float(sin(phase) * env * 0.55)
            }

        case .playerPichuun:
            // ピチューン: 下降ピッチ＋レトロノイズ
            var phase: Double = 0
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = exp(-t * 3.5)
                let freq = max(80.0, baseFreq * (1.0 - t / duration))
                phase += 2.0 * .pi * freq / Double(sampleRate)
                let tone = sin(phase) * 0.6
                let noise = Double.random(in: -1...1) * 0.35 * exp(-t * 8.0)
                out[i] = Float((tone + noise) * env * 0.60)
            }

        case .timeStopSakuya:
            // 時間停止: 時計のチクタク＋反転スイープ
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let tick = (fmod(t, 0.25) < 0.02) ? sin(2.0 * .pi * 2200.0 * t) * 0.8 : 0.0
                let sweep = sin(2.0 * .pi * (baseFreq + t * 400.0) * t) * exp(-t * 2.0) * 0.3
                out[i] = Float((tick + sweep) * 0.55)
            }

        case .teleportWarp:
            // ワープ: 高速フェイザーノイズ
            var phase: Double = 0
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = sin(.pi * t / duration)
                let freq = baseFreq + sin(2.0 * .pi * 8.0 * t) * 300.0
                phase += 2.0 * .pi * freq / Double(sampleRate)
                let noise = Double.random(in: -1...1) * 0.4
                out[i] = Float((sin(phase) * 0.5 + noise) * env * 0.60)
            }

        case .grazeSound:
            // グレイズ音: クリスプ高音チャイム
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = exp(-t * 35.0)
                let s1 = sin(2.0 * .pi * baseFreq * t)
                let s2 = sin(2.0 * .pi * (baseFreq * 1.5) * t) * 0.5
                out[i] = Float((s1 + s2) * env * 0.50)
            }

        case .uiConfirm:
            // UI決定音: 澄んだ和音
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = exp(-t * 10.0)
                let s = sin(2.0 * .pi * baseFreq * t) + sin(2.0 * .pi * (baseFreq * 1.5) * t) * 0.5
                out[i] = Float(s * env * 0.45)
            }

        case .uiCancel:
            // UIキャンセル音: 下降2音
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let f = t < duration / 2.0 ? baseFreq : baseFreq * 0.75
                let env = exp(-fmod(t, duration / 2.0) * 14.0)
                out[i] = Float(sin(2.0 * .pi * f * t) * env * 0.45)
            }

        case .teaCupSound:
            // お茶・日常音: 湯飲み置く音
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = exp(-t * 22.0)
                let click = sin(2.0 * .pi * 850.0 * t) * exp(-t * 40.0) * 0.8
                let resonance = sin(2.0 * .pi * 320.0 * t) * env * 0.4
                out[i] = Float((click + resonance) * 0.55)
            }
        }

        return out
    }

    // MARK: - WAV エンコーダー
    private func encodeWAVData(samples: [Float], sampleRate: Int, channels: Int) -> Data {
        var data = Data()

        let numSamples = samples.count
        let byteRate = sampleRate * channels * 2
        let blockAlign = channels * 2
        let dataSize = numSamples * 2
        let chunkSize = 36 + dataSize

        // RIFF header
        data.append(contentsOf: "RIFF".utf8)
        data.append(UInt32(chunkSize).littleEndianData)
        data.append(contentsOf: "WAVE".utf8)

        // fmt chunk
        data.append(contentsOf: "fmt ".utf8)
        data.append(UInt32(16).littleEndianData) // subchunk1Size
        data.append(UInt16(1).littleEndianData)  // audioFormat: PCM = 1
        data.append(UInt16(channels).littleEndianData)
        data.append(UInt32(sampleRate).littleEndianData)
        data.append(UInt32(byteRate).littleEndianData)
        data.append(UInt16(blockAlign).littleEndianData)
        data.append(UInt16(16).littleEndianData) // bitsPerSample: 16

        // data chunk
        data.append(contentsOf: "data".utf8)
        data.append(UInt32(dataSize).littleEndianData)

        // 16-bit PCM samples
        for s in samples {
            let clamped = max(-1.0, min(1.0, s))
            let intSample = Int16(clamped * 32767.0)
            data.append(intSample.littleEndianData)
        }

        return data
    }
}

// MARK: - Binary Helper Extensions
private extension FixedWidthInteger {
    var littleEndianData: Data {
        var val = self.littleEndian
        return Data(bytes: &val, count: MemoryLayout<Self>.size)
    }
}
