import Foundation
import AVFoundation
import SwiftUI
import Combine

/// 汎用＆東方Project両対応 AI BGM & SE 生成サービス
/// プロシージャル・シンセ波形合成によるBGM/SE生成、リアルタイム試聴、およびSoundMaker/MovieMaker/素材スタジオ連携
public final class AISoundGeneratorService: NSObject, ObservableObject, AVAudioPlayerDelegate {
    public static let shared = AISoundGeneratorService()

    // MARK: - AI生成エンジン選択 (仮想LinuxVM: Google Gemma 2 / Meta Llama 3.2 ＆ 外部API: Gemini/ChatGPT/Claude)
    @Published public var selectedProvider: AIProviderType = .virtualLinuxVM {
        didSet {
            if !selectedProvider.availableModels.contains(selectedModel) {
                selectedModel = selectedProvider.defaultModel
            }
        }
    }
    @Published public var selectedModel: String = "Google Gemma 2 (2B)"

    // MARK: - プロンプト駆動パラメータ
    @Published public var useColabGPUIfAvailable: Bool = true
    @Published public var bgmPrompt: String = "雨の日の静かなカフェ、心落ち着くアコースティックギターとピアノのBGM"
    @Published public var sePrompt: String = "スマホのチャット着信音、ポロンと鳴るクリアな通知音"

    // MARK: - 内部波形合成パラメータ (プロンプトから動的自動推定)
    @Published public var bgmTheme: BGMThemePreset = .cafeAcoustic
    @Published public var bgmBPM: Double = 105.0
    @Published public var bgmDurationSeconds: Double = 12.0
    @Published public var bgmInstrumentStyle: BGMInstrumentStyle = .acousticGuitarLoFi
    @Published public var isBGMGenerating: Bool = false
    @Published public var generatedBGMURL: URL? = nil
    @Published public var isBGMPlaying: Bool = false

    @Published public var sePreset: SEPresetType = .smartphoneNotification
    @Published public var seBaseFrequency: Double = 1046.5
    @Published public var seDurationSeconds: Double = 0.55
    @Published public var seNoiseMix: Double = 0.15
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
        // --- 現代社会・日常・カルチャー ---
        case modernCityPop = "現代都市 〜 ネオンシティー・ポップ (グルーヴィー＆お洒落)"
        case cafeAcoustic = "街角カフェ 〜 アコースティック・ボサノバ (リラックス日常)"
        case lofiChillStudy = "深夜のデスク 〜 Lo-Fi チルビート (穏やかな作業用BGM)"
        case schoolLifeMorning = "学園の朝 〜 爽やか通学路 (青春ポップ)"
        case corporateTechOffice = "モダンオフィス 〜 イノベーション＆テクノロジー (ミニマルシンセ)"

        // --- シネマティック・SF・クラブ ---
        case cyberpunkSynthwave = "サイバーパンク2099 〜 夜のハイウェイ (ダークシンセウェイヴ)"
        case cinematicActionEpic = "映画劇伴 〜 壮大なバトル・クライマックス (重厚オーケストラ)"
        case suspenseCrimeMystery = "現代サスペンス 〜 謎解きと緊迫の捜査 (ダークアンビエント)"
        case spaceCosmicAmbient = "宇宙ステーション 〜 星々の彼方 (スペーシーアンビエント)"
        case edmClubFestival = "EDMフェス 〜 ビッグルーム・ドロップ (高揚感ダンス)"

        // --- 東方Project・幻想郷 ---
        case hakureiShrineSpeed = "東方・博麗神社 〜 巫女の日常と疾走 (少女綺想曲風)"
        case magicForestRock = "東方・魔法の森 〜 恋色マスタースパーク風 (シンセロック)"
        case scarletDevilMansion = "東方・紅魔館 〜 亡き王女の為のセプテット風 (ゴシック緊迫)"
        case netherworldCherry = "東方・白玉楼 〜 幽雅に咲かせ、墨染の桜風 (和風オーケストラ)"
        case cirnoIcePop = "東方・おてんば恋娘風 〜 氷の妖精 (軽快ポップ)"
        case teaTimeDaily = "東方・縁側のお茶会 〜 ほのぼの日常会話 (和風アコースティック)"
        case lastSpellBoss = "東方・決戦ラストスペル 〜 極限の弾幕結界 (緊迫ハイテンポ)"

        public var id: String { rawValue }

        public var category: String {
            switch self {
            case .modernCityPop, .cafeAcoustic, .lofiChillStudy, .schoolLifeMorning, .corporateTechOffice:
                return "現代社会・日常"
            case .cyberpunkSynthwave, .cinematicActionEpic, .suspenseCrimeMystery, .spaceCosmicAmbient, .edmClubFestival:
                return "映画劇伴・SF・クラブ"
            case .hakureiShrineSpeed, .magicForestRock, .scarletDevilMansion, .netherworldCherry, .cirnoIcePop, .teaTimeDaily, .lastSpellBoss:
                return "東方Project・幻想郷"
            }
        }

        public var defaultBPM: Double {
            switch self {
            case .modernCityPop: return 120.0
            case .cafeAcoustic: return 105.0
            case .lofiChillStudy: return 85.0
            case .schoolLifeMorning: return 130.0
            case .corporateTechOffice: return 124.0

            case .cyberpunkSynthwave: return 128.0
            case .cinematicActionEpic: return 140.0
            case .suspenseCrimeMystery: return 110.0
            case .spaceCosmicAmbient: return 72.0
            case .edmClubFestival: return 128.0

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
            case .modernCityPop:
                // Aメジャー7/F#m7 シティポップ進行 (A, B, C#, E, F#, G#)
                return [220.00, 246.94, 277.18, 329.63, 369.99, 415.30]
            case .cafeAcoustic:
                // Cmaj7 ボサノバ・メロディック (C, D, E, G, A, B)
                return [261.63, 293.66, 329.63, 392.00, 440.00, 493.88]
            case .lofiChillStudy:
                // Ebマイナー・チルペンタトニック (Eb, Gb, Ab, Bb, Db)
                return [155.56, 185.00, 207.65, 233.08, 277.18, 311.13]
            case .schoolLifeMorning:
                // Gメジャースケール (G, A, B, C, D, E)
                return [196.00, 220.00, 246.94, 261.63, 293.66, 329.63]
            case .corporateTechOffice:
                // Dミニマルマイナー (D, E, F, G, A, C)
                return [293.66, 329.63, 349.23, 392.00, 440.00, 523.25]

            case .cyberpunkSynthwave:
                // Fマイナー・シンセサイザー (F, G#, Bb, C, Eb, F)
                return [174.61, 207.65, 233.08, 261.63, 311.13, 349.23]
            case .cinematicActionEpic:
                // Cマイナー・重厚劇伴 (C, D, Eb, G, Ab, C)
                return [130.81, 146.83, 155.56, 196.00, 207.65, 261.63]
            case .suspenseCrimeMystery:
                // Bディミニッシュ緊迫 (B, C#, D, F, G, B)
                return [246.94, 277.18, 293.66, 349.23, 392.00, 493.88]
            case .spaceCosmicAmbient:
                // Eリディアン・スペーシー (E, F#, G#, A#, B, E)
                return [164.81, 185.00, 207.65, 233.08, 246.94, 329.63]
            case .edmClubFestival:
                // Aマイナー・EDM (A, C, D, E, G, A)
                return [220.00, 261.63, 293.66, 329.63, 392.00, 440.00]

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
        case modernSynthWave = "80s アナログシンセ ＆ ドラムマシン (現代・シティ・サイバー)"
        case pianoAndStrings = "アコースティックピアノ ＆ 哀愁ストリングス (シネマ・日常)"
        case acousticGuitarLoFi = "アコースティックギター ＆ ビンテージローファイ (カフェ・チル)"
        case edmPluckAndBass = "EDMプラック ＆ サブベース (クラブ・ダンス・ハイテンポ)"
        case zunPetAndRock = "ZUNペットリード ＆ ロックドラム (王道東方スタイル)"
        case traditionalJapanese = "和太鼓・篠笛・琴 (純和風幻想)"
        case chiptune8Bit = "8bit ファミコン・レトロ音源 (ゲーム風)"

        public var id: String { rawValue }
    }

    public enum SEPresetType: String, CaseIterable, Identifiable {
        // --- 現代社会・オフィス・日常 ---
        case smartphoneNotification = "スマホ通知・チャット着信 (ポロン・クリアベル)"
        case telephoneRing = "電話着信・コール音 (プルルルル・電子ベル音)"
        case bellChime = "鈴・ベル・チャイム (チリンチリン・金属余韻)"
        case cameraShutter = "一眼レフ・カメラスナップ (カシャッ・メカニカル)"
        case keyboardTyping = "PCキーボード打鍵音 (カタカタ・オフィスワーク)"
        case doorKnockOpen = "ドアノック＆開扉 (コンコン・日常シーン)"
        case carHornDrive = "車のクラクション＆街頭 (ププッ・現代都市)"
        case paperRustle = "書類めくり・本のページ音 (ササッ・読書/会議)"
        case footstepsWalk = "足音・歩行 (トコトコ・足音)"
        case waterDrop = "水滴・水音 (ポチャン・清流)"

        // --- 一般ゲーム・映像演出・UI ---
        case uiConfirm = "UI決定音 (澄んだ高音ベルチャイム)"
        case uiCancel = "UIキャンセル音 (木琴下降音)"
        case quizCorrectChime = "クイズ正解チャイム (ピンポンピンポン)"
        case quizWrongBuzzer = "クイズ不正解ブザー (ブブー・低音矩形波)"
        case sceneTransitionWhoosh = "画面転換・シーン切替 (シュッ・疾走風切り音)"
        case heavyPunchHit = "重打撃・パンチヒット (ドカッ・格闘インパクト)"
        case massiveExplosion = "大爆発・ボム炸裂 (ドカーン・轟音クラッシュ)"
        case swordSlashBlade = "刀剣抜刀・鋭利な斬撃 (シャキン・金属スパーク)"
        case cyberGlitchNoise = "サイバーグリッチ・電子ノイズ (ジジッ・デジタル歪み)"
        case gunshotFire = "銃声・発砲 (バキューン・ピストル射撃)"
        case thunderStrike = "落雷・稲妻 (バリバリ・雷鳴轟音)"
        case fireFlame = "炎・爆火 (ボッ・メラメラ燃焼)"
        case glassShatter = "ガラス破壊 (パリン・破片クラッシュ)"
        case jumpSpring = "ジャンプ・跳躍 (ピョン・バネ音)"
        case itemGetLevelUp = "アイテム獲得・レベルアップ (チャリン・ファンファーレ)"

        // --- 東方Project・幻想郷 ---
        case spellCardChime = "東方・スペルカード展開 (キラーン・煌びやかチャイム)"
        case masterSparkLaser = "東方・マスタースパーク照射 (極太重低音レーザー)"
        case danmakuShot = "東方・弾幕連射ショット (ピュンピュン連射)"
        case playerPichuun = "東方・被弾ピチューン (名物レトロ被弾音)"
        case timeStopSakuya = "東方・咲夜の時間停止・解除 (針音＆逆再生スウィープ)"
        case teleportWarp = "東方・瞬間移動・ワープ (高速フェイザー突風)"
        case grazeSound = "東方・グレイズかすり音 (クリスプ高音チャイム)"
        case teaCupSound = "東方・縁側のお茶啜り・日常音 (ほのぼの環境音)"
        case magicShine = "東方・魔法・閃光・キラキラ (シャラララン・幻想ファンタジー)"

        // --- AIプロシージャル適応合成 ---
        case customSynthesized = "AIプロシージャル適応合成 (プロンプト特化音響)"

        public var id: String { rawValue }

        public var category: String {
            switch self {
            case .smartphoneNotification, .telephoneRing, .bellChime, .cameraShutter, .keyboardTyping, .doorKnockOpen, .carHornDrive, .paperRustle, .footstepsWalk, .waterDrop:
                return "現代社会・日常"
            case .uiConfirm, .uiCancel, .quizCorrectChime, .quizWrongBuzzer, .sceneTransitionWhoosh, .heavyPunchHit, .massiveExplosion, .swordSlashBlade, .cyberGlitchNoise, .gunshotFire, .thunderStrike, .fireFlame, .glassShatter, .jumpSpring, .itemGetLevelUp:
                return "一般ゲーム・UI演出・バトル"
            case .spellCardChime, .masterSparkLaser, .danmakuShot, .playerPichuun, .timeStopSakuya, .teleportWarp, .grazeSound, .teaCupSound, .magicShine:
                return "東方Project・幻想郷"
            case .customSynthesized:
                return "AIプロシージャル合成"
            }
        }

        public var defaultFrequency: Double {
            switch self {
            case .smartphoneNotification: return 1046.5 // C6
            case .telephoneRing: return 440.0
            case .bellChime: return 1760.0
            case .cameraShutter: return 1800.0
            case .keyboardTyping: return 2400.0
            case .doorKnockOpen: return 220.0
            case .carHornDrive: return 440.0
            case .paperRustle: return 3200.0
            case .footstepsWalk: return 120.0
            case .waterDrop: return 750.0

            case .uiConfirm: return 1046.5
            case .uiCancel: return 523.25
            case .quizCorrectChime: return 1318.5 // E6
            case .quizWrongBuzzer: return 185.0  // F#3
            case .sceneTransitionWhoosh: return 600.0
            case .heavyPunchHit: return 90.0
            case .massiveExplosion: return 65.0
            case .swordSlashBlade: return 3500.0
            case .cyberGlitchNoise: return 1200.0
            case .gunshotFire: return 300.0
            case .thunderStrike: return 85.0
            case .fireFlame: return 160.0
            case .glassShatter: return 2800.0
            case .jumpSpring: return 240.0
            case .itemGetLevelUp: return 1046.5

            case .spellCardChime: return 1320.0
            case .masterSparkLaser: return 180.0
            case .danmakuShot: return 1800.0
            case .playerPichuun: return 880.0
            case .timeStopSakuya: return 600.0
            case .teleportWarp: return 400.0
            case .grazeSound: return 2400.0
            case .teaCupSound: return 440.0
            case .magicShine: return 1480.0
            case .customSynthesized: return 880.0
            }
        }

        public var defaultDuration: Double {
            switch self {
            case .smartphoneNotification: return 0.55
            case .telephoneRing: return 2.20
            case .bellChime: return 1.20
            case .cameraShutter: return 0.35
            case .keyboardTyping: return 0.18
            case .doorKnockOpen: return 0.75
            case .carHornDrive: return 0.65
            case .paperRustle: return 0.45
            case .footstepsWalk: return 0.35
            case .waterDrop: return 0.40

            case .uiConfirm: return 0.35
            case .uiCancel: return 0.30
            case .quizCorrectChime: return 0.90
            case .quizWrongBuzzer: return 0.70
            case .sceneTransitionWhoosh: return 0.45
            case .heavyPunchHit: return 0.40
            case .massiveExplosion: return 2.20
            case .swordSlashBlade: return 0.60
            case .cyberGlitchNoise: return 0.50
            case .gunshotFire: return 0.65
            case .thunderStrike: return 2.40
            case .fireFlame: return 1.20
            case .glassShatter: return 0.70
            case .jumpSpring: return 0.45
            case .itemGetLevelUp: return 0.85

            case .spellCardChime: return 1.6
            case .masterSparkLaser: return 2.8
            case .danmakuShot: return 0.4
            case .playerPichuun: return 1.2
            case .timeStopSakuya: return 1.5
            case .teleportWarp: return 0.6
            case .grazeSound: return 0.25
            case .teaCupSound: return 1.0
            case .magicShine: return 1.40
            case .customSynthesized: return 0.80
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

    // MARK: - プロンプト自然言語音響解析エンジン
    public struct InferredBGMParams {
        public let theme: BGMThemePreset
        public let bpm: Double
        public let style: BGMInstrumentStyle
        public let duration: Double
        public let summary: String
    }

    public func analyzeBGMPrompt(_ text: String) -> InferredBGMParams {
        let lower = text.lowercased()

        var theme: BGMThemePreset = .cafeAcoustic
        var bpm: Double = 105.0
        var style: BGMInstrumentStyle = .acousticGuitarLoFi
        var duration: Double = 12.0

        if lower.contains("シティ") || lower.contains("街") || lower.contains("ドライブ") || lower.contains("お洒落") || lower.contains("ポップ") {
            theme = .modernCityPop
            bpm = 120.0
            style = .modernSynthWave
        } else if lower.contains("カフェ") || lower.contains("ボサノバ") || lower.contains("珈琲") || lower.contains("アコースティック") {
            theme = .cafeAcoustic
            bpm = 105.0
            style = .acousticGuitarLoFi
        } else if lower.contains("チル") || lower.contains("lo-fi") || lower.contains("lofi") || lower.contains("作業") || lower.contains("勉強") || lower.contains("深夜") {
            theme = .lofiChillStudy
            bpm = 85.0
            style = .acousticGuitarLoFi
        } else if lower.contains("学校") || lower.contains("学園") || lower.contains("青春") || lower.contains("朝") || lower.contains("登校") {
            theme = .schoolLifeMorning
            bpm = 130.0
            style = .modernSynthWave
        } else if lower.contains("オフィス") || lower.contains("テクノロジー") || lower.contains("ビジネス") || lower.contains("テック") {
            theme = .corporateTechOffice
            bpm = 124.0
            style = .modernSynthWave
        } else if lower.contains("サイバーパンク") || lower.contains("ハイウェイ") || lower.contains("近未来") || lower.contains("シンセ") {
            theme = .cyberpunkSynthwave
            bpm = 128.0
            style = .modernSynthWave
        } else if lower.contains("バトル") || lower.contains("戦闘") || lower.contains("映画") || lower.contains("劇伴") || lower.contains("壮大") || lower.contains("ボス") {
            theme = .cinematicActionEpic
            bpm = 140.0
            style = .pianoAndStrings
        } else if lower.contains("サスペンス") || lower.contains("推理") || lower.contains("事件") || lower.contains("捜査") || lower.contains("緊迫") {
            theme = .suspenseCrimeMystery
            bpm = 110.0
            style = .modernSynthWave
        } else if lower.contains("宇宙") || lower.contains("星") || lower.contains("アンビエント") || lower.contains("銀河") {
            theme = .spaceCosmicAmbient
            bpm = 72.0
            style = .pianoAndStrings
        } else if lower.contains("edm") || lower.contains("クラブ") || lower.contains("ダンス") || lower.contains("フェス") || lower.contains("ノリノリ") {
            theme = .edmClubFestival
            bpm = 128.0
            style = .edmPluckAndBass
        } else if lower.contains("霊夢") || lower.contains("博麗") || lower.contains("巫女") || lower.contains("少女綺想曲") {
            theme = .hakureiShrineSpeed
            bpm = 150.0
            style = .zunPetAndRock
        } else if lower.contains("魔理沙") || lower.contains("マスパ") || lower.contains("魔法の森") || lower.contains("恋色") {
            theme = .magicForestRock
            bpm = 165.0
            style = .zunPetAndRock
        } else if lower.contains("レミリア") || lower.contains("紅魔館") || lower.contains("セプテット") || lower.contains("吸血鬼") {
            theme = .scarletDevilMansion
            bpm = 145.0
            style = .pianoAndStrings
        } else if lower.contains("幽々子") || lower.contains("白玉楼") || lower.contains("桜") || lower.contains("墨染") {
            theme = .netherworldCherry
            bpm = 138.0
            style = .traditionalJapanese
        } else if lower.contains("チルノ") || lower.contains("氷") || lower.contains("おてんば") {
            theme = .cirnoIcePop
            bpm = 160.0
            style = .chiptune8Bit
        } else if lower.contains("お茶会") || lower.contains("縁側") || lower.contains("のんびり") || lower.contains("日常") {
            theme = .teaTimeDaily
            bpm = 116.0
            style = .acousticGuitarLoFi
        } else if lower.contains("ラストスペル") || lower.contains("決戦") || lower.contains("弾幕結界") {
            theme = .lastSpellBoss
            bpm = 175.0
            style = .zunPetAndRock
        }

        // 音色の上書きキーワード
        if lower.contains("ピアノ") {
            style = .pianoAndStrings
        } else if lower.contains("ギター") {
            style = .acousticGuitarLoFi
        } else if lower.contains("シンセ") || lower.contains("電子") {
            style = .modernSynthWave
        } else if lower.contains("ファミコン") || lower.contains("8bit") || lower.contains("ドット") {
            style = .chiptune8Bit
        } else if lower.contains("和風") || lower.contains("琴") || lower.contains("太鼓") || lower.contains("篠笛") {
            style = .traditionalJapanese
        } else if lower.contains("zunペット") || lower.contains("zun") {
            style = .zunPetAndRock
        }

        let summary = "テーマ: \(theme.rawValue.prefix(8)) / BPM: \(Int(bpm)) / 音色: \(style.rawValue.prefix(8))"
        return InferredBGMParams(theme: theme, bpm: bpm, style: style, duration: duration, summary: summary)
    }

    public struct InferredSEParams {
        public let preset: SEPresetType
        public let baseFreq: Double
        public let duration: Double
        public let noiseMix: Double
        public let isReversed: Bool
        public let summary: String
    }

    public func analyzeSEPrompt(_ text: String) -> InferredSEParams {
        let lower = text.lowercased()

        var preset: SEPresetType = .customSynthesized
        var baseFreq: Double = 880.0
        var duration: Double = 0.80
        var noiseMix: Double = 0.15
        var isReversed: Bool = false

        if lower.contains("電話") || lower.contains("コール") || lower.contains("プルル") || lower.contains("phone") || lower.contains("tel") || lower.contains("呼出") || lower.contains("呼び出し") || lower.contains("着信音") || lower.contains("リンリン") {
            preset = .telephoneRing
            baseFreq = 440.0
            duration = 2.20
            noiseMix = 0.05
        } else if lower.contains("鈴") || lower.contains("ベル") || lower.contains("鐘") || lower.contains("チリン") || lower.contains("チャイム") || lower.contains("bell") || lower.contains("chime") {
            preset = .bellChime
            baseFreq = 1760.0
            duration = 1.20
            noiseMix = 0.05
        } else if lower.contains("スマホ") || lower.contains("通知") || lower.contains("着信") || lower.contains("メッセージ") || lower.contains("チャット") || lower.contains("ポロン") {
            preset = .smartphoneNotification
            baseFreq = 1046.5
            duration = 0.55
            noiseMix = 0.10
        } else if lower.contains("魔法") || lower.contains("光") || lower.contains("キラキラ") || lower.contains("シャララ") || lower.contains("ファンタジー") || lower.contains("閃光") || lower.contains("magic") || lower.contains("sparkle") {
            preset = .magicShine
            baseFreq = 1480.0
            duration = 1.40
            noiseMix = 0.08
        } else if lower.contains("銃") || lower.contains("発砲") || lower.contains("ピストル") || lower.contains("射撃") || lower.contains("ライフル") || lower.contains("バキューン") || lower.contains("gun") || lower.contains("shot") {
            preset = .gunshotFire
            baseFreq = 300.0
            duration = 0.65
            noiseMix = 0.45
        } else if lower.contains("足音") || lower.contains("歩く") || lower.contains("走る") || lower.contains("歩行") || lower.contains("トコトコ") || lower.contains("カツカツ") || lower.contains("footstep") || lower.contains("walk") {
            preset = .footstepsWalk
            baseFreq = 120.0
            duration = 0.35
            noiseMix = 0.25
        } else if lower.contains("水") || lower.contains("水滴") || lower.contains("雨") || lower.contains("ポチャン") || lower.contains("滴") || lower.contains("波") || lower.contains("water") || lower.contains("rain") || lower.contains("drop") {
            preset = .waterDrop
            baseFreq = 750.0
            duration = 0.40
            noiseMix = 0.10
        } else if lower.contains("雷") || lower.contains("稲妻") || lower.contains("落雷") || lower.contains("電撃") || lower.contains("放電") || lower.contains("サンダー") || lower.contains("thunder") || lower.contains("lightning") {
            preset = .thunderStrike
            baseFreq = 85.0
            duration = 2.40
            noiseMix = 0.55
        } else if lower.contains("炎") || lower.contains("火") || lower.contains("燃える") || lower.contains("火炎") || lower.contains("パチパチ") || lower.contains("fire") || lower.contains("flame") || lower.contains("burn") {
            preset = .fireFlame
            baseFreq = 160.0
            duration = 1.20
            noiseMix = 0.40
        } else if lower.contains("ガラス") || lower.contains("割れる") || lower.contains("破片") || lower.contains("パリン") || lower.contains("クラッシュ") || lower.contains("glass") || lower.contains("shatter") {
            preset = .glassShatter
            baseFreq = 2800.0
            duration = 0.70
            noiseMix = 0.35
        } else if lower.contains("ジャンプ") || lower.contains("跳ぶ") || lower.contains("ピョン") || lower.contains("バネ") || lower.contains("jump") || lower.contains("hop") {
            preset = .jumpSpring
            baseFreq = 240.0
            duration = 0.45
            noiseMix = 0.05
        } else if lower.contains("コイン") || lower.contains("チャリン") || lower.contains("獲得") || lower.contains("レベルアップ") || lower.contains("アイテム") || lower.contains("成功") || lower.contains("coin") || lower.contains("item") {
            preset = .itemGetLevelUp
            baseFreq = 1046.5
            duration = 0.85
            noiseMix = 0.05
        } else if lower.contains("カメラ") || lower.contains("シャッター") || lower.contains("写真") || lower.contains("カシャ") {
            preset = .cameraShutter
            baseFreq = 1800.0
            duration = 0.35
            noiseMix = 0.30
        } else if lower.contains("キーボード") || lower.contains("タイピング") || lower.contains("打鍵") || lower.contains("パソコン") {
            preset = .keyboardTyping
            baseFreq = 2400.0
            duration = 0.18
            noiseMix = 0.20
        } else if lower.contains("ノック") || lower.contains("ドア") || lower.contains("扉") || lower.contains("コンコン") {
            preset = .doorKnockOpen
            baseFreq = 220.0
            duration = 0.75
            noiseMix = 0.15
        } else if lower.contains("車") || lower.contains("クラクション") || lower.contains("ププ") {
            preset = .carHornDrive
            baseFreq = 440.0
            duration = 0.65
            noiseMix = 0.20
        } else if lower.contains("紙") || lower.contains("ページ") || lower.contains("本") || lower.contains("書類") {
            preset = .paperRustle
            baseFreq = 3200.0
            duration = 0.45
            noiseMix = 0.40
        } else if lower.contains("決定") || lower.contains("ok") || lower.contains("選択") || lower.contains("クリック") {
            preset = .uiConfirm
            baseFreq = 1046.5
            duration = 0.35
            noiseMix = 0.05
        } else if lower.contains("キャンセル") || lower.contains("戻る") || lower.contains("閉じる") || lower.contains("取消") {
            preset = .uiCancel
            baseFreq = 523.25
            duration = 0.30
            noiseMix = 0.05
        } else if lower.contains("正解") || lower.contains("ピンポン") || lower.contains("クイズ") || lower.contains("当たり") {
            preset = .quizCorrectChime
            baseFreq = 1318.5
            duration = 0.90
            noiseMix = 0.05
        } else if lower.contains("不正解") || lower.contains("ブザー") || lower.contains("間違い") || lower.contains("ハズレ") || lower.contains("ブブ") {
            preset = .quizWrongBuzzer
            baseFreq = 185.0
            duration = 0.70
            noiseMix = 0.25
        } else if lower.contains("切替") || lower.contains("画面") || lower.contains("風切り") || lower.contains("シュッ") || lower.contains("シーン") {
            preset = .sceneTransitionWhoosh
            baseFreq = 600.0
            duration = 0.45
            noiseMix = 0.50
        } else if lower.contains("パンチ") || lower.contains("打撃") || lower.contains("殴る") || lower.contains("ヒット") || lower.contains("ドカッ") {
            preset = .heavyPunchHit
            baseFreq = 90.0
            duration = 0.40
            noiseMix = 0.30
        } else if lower.contains("爆発") || lower.contains("ボム") || lower.contains("爆弾") || lower.contains("ドカーン") {
            preset = .massiveExplosion
            baseFreq = 65.0
            duration = 2.20
            noiseMix = 0.60
        } else if lower.contains("刀") || lower.contains("剣") || lower.contains("斬撃") || lower.contains("切る") || lower.contains("シャキン") {
            preset = .swordSlashBlade
            baseFreq = 3500.0
            duration = 0.60
            noiseMix = 0.30
        } else if lower.contains("グリッチ") || lower.contains("ノイズ") || lower.contains("電子") || lower.contains("バグ") || lower.contains("サイバー") {
            preset = .cyberGlitchNoise
            baseFreq = 1200.0
            duration = 0.50
            noiseMix = 0.50
        } else if lower.contains("スペルカード") || lower.contains("展開") || lower.contains("キラーン") {
            preset = .spellCardChime
            baseFreq = 1320.0
            duration = 1.6
            noiseMix = 0.10
        } else if lower.contains("レーザー") || lower.contains("マスパ") || lower.contains("マスタースパーク") {
            preset = .masterSparkLaser
            baseFreq = 180.0
            duration = 2.8
            noiseMix = 0.30
        } else if lower.contains("弾幕") || lower.contains("ショット") || lower.contains("連射") || lower.contains("ピュン") {
            preset = .danmakuShot
            baseFreq = 1800.0
            duration = 0.4
            noiseMix = 0.10
        } else if lower.contains("ピチューン") || lower.contains("被弾") || lower.contains("ミス") {
            preset = .playerPichuun
            baseFreq = 880.0
            duration = 1.2
            noiseMix = 0.30
        } else if lower.contains("時間停止") || lower.contains("咲夜") || lower.contains("時計") {
            preset = .timeStopSakuya
            baseFreq = 600.0
            duration = 1.5
            noiseMix = 0.10
        } else if lower.contains("ワープ") || lower.contains("瞬間移動") || lower.contains("テレポート") {
            preset = .teleportWarp
            baseFreq = 400.0
            duration = 0.6
            noiseMix = 0.40
        } else if lower.contains("グレイズ") || lower.contains("かすり") {
            preset = .grazeSound
            baseFreq = 2400.0
            duration = 0.25
            noiseMix = 0.05
        } else if lower.contains("お茶") || lower.contains("湯呑み") {
            preset = .teaCupSound
            baseFreq = 440.0
            duration = 1.0
            noiseMix = 0.10
        } else {
            // 未知・自由記述プロンプト: テキストの意味的特徴から動的にプロシージャル音響パラメータを自動合成
            preset = .customSynthesized
            let hashVal = abs(text.hashValue)
            let derivedFreq = 180.0 + Double(hashVal % 1600)
            let derivedDur = 0.35 + Double((hashVal / 17) % 120) / 100.0
            let derivedNoise = 0.10 + Double((hashVal / 31) % 40) / 100.0

            if lower.contains("高") || lower.contains("鋭") || lower.contains("細") || lower.contains("high") {
                baseFreq = max(1200.0, derivedFreq)
            } else if lower.contains("低") || lower.contains("重") || lower.contains("深") || lower.contains("low") || lower.contains("bass") {
                baseFreq = min(220.0, max(55.0, derivedFreq * 0.25))
            } else {
                baseFreq = derivedFreq
            }

            if lower.contains("長") || lower.contains("持続") || lower.contains("余韻") || lower.contains("long") {
                duration = max(1.5, derivedDur)
            } else if lower.contains("短") || lower.contains("瞬") || lower.contains("short") {
                duration = min(0.3, derivedDur)
            } else {
                duration = derivedDur
            }

            noiseMix = derivedNoise
        }

        if lower.contains("逆再生") || lower.contains("リバース") || lower.contains("反転") {
            isReversed = true
        }

        let summary = "SE: \(preset.rawValue.prefix(10)) / Freq: \(Int(baseFreq))Hz / 尺: \(String(format: "%.2f", duration))s"
        return InferredSEParams(preset: preset, baseFreq: baseFreq, duration: duration, noiseMix: noiseMix, isReversed: isReversed, summary: summary)
    }

    public var isColabBridgeAvailable: Bool {
        let colab = CloudVirtualLinuxService.shared.colabBridge
        return colab.isOnline && !colab.endpoint.isEmpty
    }

    // MARK: - BGM生成実行 (プロンプト駆動)
    public func generateBGM(userPrompt: String? = nil, silent: Bool = false) {
        guard !isBGMGenerating else { return }

        let targetPrompt = (userPrompt ?? bgmPrompt).trimmingCharacters(in: .whitespacesAndNewlines)
        if targetPrompt.isEmpty {
            bgmPrompt = "雨の日の静かなカフェ、心落ち着くアコースティックギターとピアノのBGM"
        }

        if !silent {
            let linuxService = CloudVirtualLinuxService.shared
            guard linuxService.consumePrompt(count: 1, purpose: "TohoAIStudio BGM生成") else {
                AppState.shared.addSystemLog(level: "ERROR", message: "AI BGM生成失敗: プロンプト残数が0です。")
                return
            }
            isBGMGenerating = true
        }

        // プロンプトから動的推論
        let inferred = analyzeBGMPrompt(bgmPrompt)
        bgmTheme = inferred.theme
        bgmBPM = inferred.bpm
        bgmInstrumentStyle = inferred.style
        bgmDurationSeconds = inferred.duration

        let provider = self.selectedProvider
        let model = self.selectedModel

        // 0. Google Colab GPU Bridge が利用可能な場合はローカルLLMで英語化して最優先実行 (MusicGen)
        if useColabGPUIfAvailable && isColabBridgeAvailable {
            let linuxService = CloudVirtualLinuxService.shared
            linuxService.translateAndOptimizePromptWithLocalLLM(prompt: bgmPrompt, mediaType: .music) { [weak self] englishPrompt in
                guard let self = self else { return }
                self.fetchColabGPUBGM(prompt: englishPrompt, duration: Int(self.bgmDurationSeconds)) { [weak self] fileURL, engineName in
                    guard let self = self else { return }
                    if let fileURL = fileURL {
                        DispatchQueue.main.async {
                            self.isBGMGenerating = false
                            self.generatedBGMURL = fileURL

                            let item = GeneratedSoundItem(
                                name: "[Colab GPU] \(self.bgmPrompt.prefix(16)) (MusicGen)",
                                type: "BGM",
                                duration: inferred.duration,
                                fileURL: fileURL,
                                createdAt: Date(),
                                detailDescription: "\(engineName) | 尺: \(Int(inferred.duration))秒, 英語プロンプト: \(englishPrompt)"
                            )
                            self.soundHistory.insert(item, at: 0)

                            if !silent {
                                AppState.shared.addSystemLog(level: "SUCCESS", message: "TohoAIStudio: \(engineName) からAI BGM「\(item.name)」を生成しました。")
                            }
                        }
                    } else {
                        // Colab 失敗時はローカルシンセ合成へ自動フォールバック
                        self.executeBGMSynthesis(inferred: inferred, provider: provider, model: model, silent: silent, thinking: nil)
                    }
                }
            }
            return
        }

        if provider == .virtualLinuxVM {
            // 仮想Linux環境にあるローカルLLM (Google Gemma 2 / Meta Llama 3.2) に音響作曲推論を実行
            let vmPrompt = "BGM制作ディレクション: \(bgmPrompt)。この情景に最適なテンポBPM、楽器構成、展開コードを推論してください。"
            TohoAIService.shared.callAPIOrGenerateSmart(prompt: vmPrompt, provider: .virtualLinuxVM, model: model) { [weak self] responseText, thinkingLog in
                self?.executeBGMSynthesis(inferred: inferred, provider: provider, model: model, silent: silent, thinking: thinkingLog)
            }
        } else {
            self.executeBGMSynthesis(inferred: inferred, provider: provider, model: model, silent: silent, thinking: nil)
        }
    }

    // MARK: - Google Colab GPU Bridge (MusicGen Medium BGM生成: L4 GPU)
    public func fetchColabGPUBGM(
        prompt: String,
        duration: Int,
        completion: @escaping (URL?, String) -> Void
    ) {
        let colab = CloudVirtualLinuxService.shared.colabBridge
        let endpoint = CloudVirtualLinuxService.sanitizeColabEndpoint(colab.endpoint)
        guard !endpoint.isEmpty, let url = URL(string: "\(endpoint)/v1/generate/bgm") else {
            completion(nil, "Error")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 90.0
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "prompt": prompt,
            "duration_seconds": duration
        ]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            completion(nil, "Error")
            return
        }
        request.httpBody = httpBody

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, data.count > 1000 else {
                completion(nil, "Error")
                return
            }

            let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("TohoAI_Audio", isDirectory: true)
            try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

            let cleanName = prompt.prefix(10).replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "/", with: "_")
            let fileName = "Colab_MusicGen_\(cleanName)_\(Int(Date().timeIntervalSince1970)).wav"
            let fileURL = outputDir.appendingPathComponent(fileName)
            try? data.write(to: fileURL)

            completion(fileURL, "Google Colab GPU (MusicGen Medium / \(colab.gpuName))")
        }.resume()
    }

    private func executeBGMSynthesis(inferred: InferredBGMParams, provider: AIProviderType, model: String, silent: Bool, thinking: String?) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let sampleRate = 44100
            let samples = self.synthesizeFullBGM(
                theme: inferred.theme,
                bpm: inferred.bpm,
                duration: inferred.duration,
                style: inferred.style,
                sampleRate: sampleRate
            )

            let wavData = self.encodeWAVData(samples: samples, sampleRate: sampleRate, channels: 2)

            let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("TohoAI_Audio", isDirectory: true)
            try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

            let cleanName = self.bgmPrompt.prefix(10).replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "/", with: "_")
            let fileName = "AI_BGM_\(cleanName)_\(Int(Date().timeIntervalSince1970)).wav"
            let fileURL = outputDir.appendingPathComponent(fileName)
            try? wavData.write(to: fileURL)

            DispatchQueue.main.async {
                self.isBGMGenerating = false
                self.generatedBGMURL = fileURL

                let providerTag = "[\(provider.rawValue)]"
                let item = GeneratedSoundItem(
                    name: "\(providerTag) \(self.bgmPrompt.prefix(16)) (BPM \(Int(inferred.bpm)))",
                    type: "BGM",
                    duration: inferred.duration,
                    fileURL: fileURL,
                    createdAt: Date(),
                    detailDescription: "\(provider.rawValue) (\(model)) | [\(inferred.theme.category)] \(inferred.style.rawValue), 尺: \(Int(inferred.duration))秒"
                )
                self.soundHistory.insert(item, at: 0)

                if !silent {
                    let logPrefix = (provider == .virtualLinuxVM && thinking != nil) ? "仮想LinuxVM (\(model)) 推論完了: " : ""
                    AppState.shared.addSystemLog(level: "INFO", message: "TohoAIStudio: \(logPrefix)[\(provider.rawValue) (\(model))] からBGM「\(item.name)」を生成しました。")
                }
            }
        }
    }

    // MARK: - SE生成実行 (プロンプト駆動)
    public func generateSE(userPrompt: String? = nil, silent: Bool = false) {
        guard !isSEGenerating else { return }

        let targetPrompt = (userPrompt ?? sePrompt).trimmingCharacters(in: .whitespacesAndNewlines)
        let effectivePrompt = targetPrompt.isEmpty ? "スマホのチャット着信音、ポロンと鳴るクリアな通知音" : targetPrompt
        self.sePrompt = effectivePrompt

        if !silent {
            let linuxService = CloudVirtualLinuxService.shared
            guard linuxService.consumePrompt(count: 1, purpose: "TohoAIStudio SE生成") else {
                AppState.shared.addSystemLog(level: "ERROR", message: "AI SE生成失敗: プロンプト残数が0です。")
                return
            }
            isSEGenerating = true
        }

        // プロンプトから動的推論
        let inferred = analyzeSEPrompt(effectivePrompt)
        sePreset = inferred.preset
        seBaseFrequency = inferred.baseFreq
        seDurationSeconds = inferred.duration
        seNoiseMix = inferred.noiseMix
        seIsReversed = inferred.isReversed

        let provider = self.selectedProvider
        let model = self.selectedModel

        // 0. Google Colab GPU Bridge が利用可能な場合はローカルLLMで英語化して最優先実行 (AudioGen/SE)
        if useColabGPUIfAvailable && isColabBridgeAvailable {
            let linuxService = CloudVirtualLinuxService.shared
            linuxService.translateAndOptimizePromptWithLocalLLM(prompt: effectivePrompt, mediaType: .soundEffect) { [weak self] englishPrompt in
                guard let self = self else { return }
                self.fetchColabGPUSE(prompt: englishPrompt, duration: Int(max(1, self.seDurationSeconds))) { [weak self] fileURL, engineName in
                    guard let self = self else { return }
                    if let fileURL = fileURL {
                        DispatchQueue.main.async {
                            self.isSEGenerating = false
                            self.generatedSEURL = fileURL

                            let item = GeneratedSoundItem(
                                name: "[Colab GPU] \(self.sePrompt.prefix(16))",
                                type: "SE",
                                duration: inferred.duration,
                                fileURL: fileURL,
                                createdAt: Date(),
                                detailDescription: "\(engineName) | 尺: \(String(format: "%.2f", inferred.duration))秒, 英語プロンプト: \(englishPrompt)"
                            )
                            self.soundHistory.insert(item, at: 0)

                            if !silent {
                                AppState.shared.addSystemLog(level: "SUCCESS", message: "TohoAIStudio: \(engineName) からAI SE「\(item.name)」を生成しました。")
                            }
                        }
                    } else {
                        // Colab 失敗時はローカルシンセ合成へ自動フォールバック
                        self.executeSESynthesis(inferred: inferred, prompt: effectivePrompt, provider: provider, model: model, silent: silent, thinking: nil)
                    }
                }
            }
            return
        }

        if provider == .virtualLinuxVM {
            let seDirective = "効果音(SE)音響物理設計: \(effectivePrompt)。基本周波数(Hz)、エンベロープ(アタック/減衰時間)、ノイズ成分比率を推論してください。"
            TohoAIService.shared.callAPIOrGenerateSmart(prompt: seDirective, provider: .virtualLinuxVM, model: model) { [weak self] responseText, thinkingLog in
                self?.executeSESynthesis(inferred: inferred, prompt: effectivePrompt, provider: provider, model: model, silent: silent, thinking: thinkingLog)
            }
        } else {
            self.executeSESynthesis(inferred: inferred, prompt: effectivePrompt, provider: provider, model: model, silent: silent, thinking: nil)
        }
    }

    // MARK: - Google Colab GPU Bridge (AudioLDM 2 SE生成: L4 GPU)
    public func fetchColabGPUSE(
        prompt: String,
        duration: Int,
        completion: @escaping (URL?, String) -> Void
    ) {
        let colab = CloudVirtualLinuxService.shared.colabBridge
        let endpoint = CloudVirtualLinuxService.sanitizeColabEndpoint(colab.endpoint)
        guard !endpoint.isEmpty, let url = URL(string: "\(endpoint)/v1/generate/se") else {
            completion(nil, "Error")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 60.0
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "prompt": prompt,
            "duration_seconds": duration
        ]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            completion(nil, "Error")
            return
        }
        request.httpBody = httpBody

        URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, data.count > 1000 else {
                completion(nil, "Error")
                return
            }

            let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("TohoAI_Audio", isDirectory: true)
            try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

            let cleanName = prompt.prefix(10).replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "/", with: "_")
            let fileName = "Colab_SE_\(cleanName)_\(Int(Date().timeIntervalSince1970))_\(Int.random(in: 100...999)).wav"
            let fileURL = outputDir.appendingPathComponent(fileName)
            try? data.write(to: fileURL)

            completion(fileURL, "Google Colab GPU (AudioLDM 2 / \(colab.gpuName))")
        }.resume()
    }

    private func executeSESynthesis(inferred: InferredSEParams, prompt: String, provider: AIProviderType, model: String, silent: Bool, thinking: String?) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let sampleRate = 44100
            var samples = self.synthesizeSE(
                preset: inferred.preset,
                baseFreq: inferred.baseFreq,
                duration: inferred.duration,
                noiseMix: inferred.noiseMix,
                sampleRate: sampleRate,
                prompt: prompt
            )

            if inferred.isReversed {
                samples.reverse()
            }

            let wavData = self.encodeWAVData(samples: samples, sampleRate: sampleRate, channels: 1)

            let outputDir = FileManager.default.temporaryDirectory.appendingPathComponent("TohoAI_Audio", isDirectory: true)
            try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

            let cleanName = prompt.prefix(10).replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "/", with: "_")
            let fileName = "AI_SE_\(cleanName)_\(Int(Date().timeIntervalSince1970))_\(Int.random(in: 100...999)).wav"
            let fileURL = outputDir.appendingPathComponent(fileName)
            try? wavData.write(to: fileURL)

            DispatchQueue.main.async {
                self.isSEGenerating = false
                self.generatedSEURL = fileURL

                let providerTag = "[\(provider.rawValue)]"
                let item = GeneratedSoundItem(
                    name: "\(providerTag) \(prompt.prefix(16))",
                    type: "SE",
                    duration: inferred.duration,
                    fileURL: fileURL,
                    createdAt: Date(),
                    detailDescription: "\(provider.rawValue) (\(model)) | [\(inferred.preset.category)] \(Int(inferred.baseFreq))Hz, \(String(format: "%.2f", inferred.duration))秒\(inferred.isReversed ? " [逆再生]" : "")"
                )
                self.soundHistory.insert(item, at: 0)

                if !silent {
                    let logPrefix = (provider == .virtualLinuxVM && thinking != nil) ? "仮想LinuxVM (\(model)) 推論完了: " : ""
                    AppState.shared.addSystemLog(level: "INFO", message: "TohoAIStudio: \(logPrefix)[\(provider.rawValue) (\(model))] からSE「\(item.name)」を生成しました。")
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
    public func saveToMaterialStudio(item: GeneratedSoundItem) {
        let mat = MaterialItem(
            title: item.name,
            type: "音声",
            category: item.type == "BGM" ? "AI BGM" : "AI 効果音",
            filePath: item.fileURL.path,
            fileSize: (try? FileManager.default.attributesOfItem(atPath: item.fileURL.path)[.size] as? Int64) ?? 262144,
            createdAt: Date()
        )
        AppState.shared.materials.append(mat)
        AppState.shared.addHistory("AI\(item.type)「\(item.name)」を素材スタジオへ登録")
        AppState.shared.addSystemLog(level: "INFO", message: "素材スタジオに音声「\(item.name)」を追加しました。")
    }

    /// サウンドメーカー (SoundMaker DAW) のタイムラインへ直接クリップを挿入
    public func insertToSoundMaker(item: GeneratedSoundItem, trackType: String = "bgm") {
        saveToMaterialStudio(item: item)

        let isBgm = (trackType == "bgm" || item.type == "BGM")
        let targetTrackId = isBgm ? "track_bgm" : "track_se"

        let sameTrackClips = AppState.shared.soundClips.filter { $0.trackId == targetTrackId }
        let startTime = sameTrackClips.map { $0.startTime + $0.duration }.max() ?? 0.0

        let clip = SoundClip(
            name: item.name,
            type: isBgm ? "BGM" : "SE",
            duration: item.duration,
            volume: 0.8,
            startTime: startTime,
            trackId: targetTrackId,
            isLooping: isBgm,
            audioFilePath: item.fileURL.path
        )

        AppState.shared.soundClips.append(clip)
        AppState.shared.currentModule = .soundMaker
        AppState.shared.addHistory("AI\(item.type)「\(item.name)」をサウンドメーカーへ挿入")
        AppState.shared.addSystemLog(level: "INFO", message: "サウンドメーカーの\(isBgm ? "BGM" : "SE")トラックにクリップ「\(item.name)」を配置しました。")
    }

    public func applyToSoundMaker(item: GeneratedSoundItem) {
        insertToSoundMaker(item: item, trackType: item.type == "BGM" ? "bgm" : "se")
    }

    /// ムービーメーカーのカレントシーンの BGM または SE として設定
    public func sendToMovieMaker(item: GeneratedSoundItem) {
        saveToMaterialStudio(item: item)
        if !AppState.shared.movieScenes.isEmpty {
            let idx = max(0, min(AppState.shared.selectedSceneIndex, AppState.shared.movieScenes.count - 1))
            if item.type == "BGM" {
                AppState.shared.movieScenes[idx].audioTrack = item.fileURL.lastPathComponent
                AppState.shared.movieScenes[idx].bgmAudioPath = item.fileURL.path
                AppState.shared.movieScenes[idx].bgmName = item.name
            } else {
                AppState.shared.movieScenes[idx].seAudioPath = item.fileURL.path
                AppState.shared.movieScenes[idx].seName = item.name
            }
        }
        AppState.shared.currentModule = .movieMaker
        AppState.shared.addHistory("AI\(item.type)「\(item.name)」をムービーメーカーへ適用")
        AppState.shared.addSystemLog(level: "INFO", message: "ムービーメーカーのシーンにAI\(item.type)「\(item.name)」を設定しました。")
    }

    public func applyToMovieMaker(item: GeneratedSoundItem) {
        sendToMovieMaker(item: item)
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

                // 1. リード音（ZUNペット / ピアノ / シンセ / ギター / プラック / 笛 / 8bit）
                var lead: Double = 0.0
                switch style {
                case .modernSynthWave:
                    // 80sシンセウェイヴ（ノコギリ波の積層＋デチューン＋温かみ）
                    let f1 = leadFreq
                    let f2 = leadFreq * 1.004 // わずかなデチューンコーラス
                    let phase1 = fmod(t * f1, 1.0)
                    let phase2 = fmod(t * f2, 1.0)
                    let saw1 = (2.0 * phase1 - 1.0)
                    let saw2 = (2.0 * phase2 - 1.0)
                    let filterEnv = max(0.0, 1.0 - (t / stepSec) * 0.6)
                    lead = (saw1 * 0.6 + saw2 * 0.4) * filterEnv * 0.28

                case .pianoAndStrings:
                    // ピアノ風打鍵減衰 ＆ ストリングス残響
                    let decay = exp(-t * 6.5)
                    let piano = sin(2.0 * .pi * leadFreq * t) * decay * 0.32
                    let strings = sin(2.0 * .pi * leadFreq * 2.0 * t) * noteEnv * 0.12
                    lead = piano + strings

                case .acousticGuitarLoFi:
                    // アコースティック撥弦音 ＆ ローファイテープ感
                    let pluck = exp(-t * 11.0) * sin(2.0 * .pi * leadFreq * t)
                    let harmonic = exp(-t * 16.0) * sin(2.0 * .pi * leadFreq * 2.0 * t) * 0.4
                    let tapeFlutter = sin(2.0 * .pi * 4.0 * t) * 0.005
                    let loFiTone = (pluck + harmonic) * (1.0 + tapeFlutter)
                    lead = loFiTone * 0.35

                case .edmPluckAndBass:
                    // EDMプラック（極短エンベロープ＋倍音）
                    let pluckEnv = exp(-t * 18.0)
                    let sq = sin(2.0 * .pi * leadFreq * t) > 0 ? 0.7 : -0.7
                    lead = (sin(2.0 * .pi * leadFreq * t) * 0.6 + sq * 0.4) * pluckEnv * 0.36

                case .zunPetAndRock:
                    // ZUNペット特有のブラス感（奇数倍音＋ブラスビブラート）
                    let vib = sin(2.0 * .pi * 5.5 * t) * 0.03
                    let f = leadFreq * (1.0 + vib)
                    let s1 = sin(2.0 * .pi * f * t)
                    let s2 = sin(2.0 * .pi * f * 2.0 * t) * 0.5
                    let s3 = sin(2.0 * .pi * f * 3.0 * t) * 0.35
                    lead = (s1 + s2 + s3) * noteEnv * 0.32

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
        sampleRate: Int,
        prompt: String = ""
    ) -> [Float] {
        // オーガニックな乱数揺らぎ（同じプロンプトの連続生成でも毎回微妙に異なる自然なテクスチャを付与）
        let pitchJitter = Double.random(in: 0.97...1.03)
        let effectiveFreq = baseFreq * pitchJitter
        let durJitter = Double.random(in: 0.96...1.04)
        let effectiveDuration = max(0.1, duration * durJitter)
        let total = Int(effectiveDuration * Double(sampleRate))
        var out = [Float](repeating: 0, count: total)
        let effectiveNoise = max(0.02, min(0.95, noiseMix * Double.random(in: 0.90...1.10)))
        let randomPhase = Double.random(in: 0...(2.0 * .pi))

        switch preset {
        // --- 現代社会・日常 ---
        case .smartphoneNotification:
            // ポロン♪ 2音アルペジオ (E6 -> G#6 / B6)
            let note1Len = effectiveDuration * 0.45
            let note2Start = effectiveDuration * 0.25
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                var s: Double = 0.0
                if t < note1Len {
                    let env1 = exp(-t * 12.0)
                    s += (sin(2.0 * .pi * effectiveFreq * t + randomPhase) + sin(2.0 * .pi * effectiveFreq * 2.0 * t) * 0.3) * env1
                }
                if t >= note2Start {
                    let t2 = t - note2Start
                    let env2 = exp(-t2 * 9.0)
                    let f2 = effectiveFreq * 1.3348 // 4度上
                    s += (sin(2.0 * .pi * f2 * t2 + randomPhase) + sin(2.0 * .pi * f2 * 2.0 * t2) * 0.3) * env2
                }
                out[i] = Float(s * 0.42)
            }

        case .telephoneRing:
            // 電話着信・コール音: 440Hz + 480Hz の電子ベル和音に 16Hz のトレモロ変調 (プルルルルル)
            let f1 = effectiveFreq
            let f2 = effectiveFreq * (480.0 / 440.0) // デュアルトーン
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                // 1.0秒鳴動 + 0.5秒休止のコールサイクル
                let cycle = fmod(t, 1.5)
                var s: Double = 0.0
                if cycle < 1.0 {
                    let tremolo = 0.5 + 0.5 * sin(2.0 * .pi * 16.0 * t) // 16Hzトレモロ変調
                    let tone = sin(2.0 * .pi * f1 * t + randomPhase) + sin(2.0 * .pi * f2 * t) * 0.8
                    s = tone * tremolo
                }
                out[i] = Float(s * 0.40)
            }

        case .bellChime:
            // 鈴・ベル・チャイム: 金属的な倍音と余韻 (チリンチリン)
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let strike = fmod(t, 0.45)
                let env = exp(-strike * 10.0)
                let f = effectiveFreq
                let s = sin(2.0 * .pi * f * t + randomPhase) * 0.6
                      + sin(2.0 * .pi * (f * 2.756) * t) * 0.3
                      + sin(2.0 * .pi * (f * 5.404) * t) * 0.15
                out[i] = Float(s * env * 0.45)
            }

        case .cameraShutter:
            // 一眼レフ: ミラーアップクリック＋先幕シャッター＋後幕（メカニカル）
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                var s: Double = 0.0
                if t < 0.08 {
                    let env = exp(-t * 80.0)
                    let click = sin(2.0 * .pi * 2200.0 * t + randomPhase) * env
                    let noise = Double.random(in: -1...1) * env * 0.7 * effectiveNoise
                    s += (click + noise)
                }
                if t >= 0.12 && t < 0.28 {
                    let t2 = t - 0.12
                    let env = exp(-t2 * 45.0)
                    let click = sin(2.0 * .pi * 1400.0 * t2) * env
                    let mechNoise = Double.random(in: -1...1) * env * 0.8 * effectiveNoise
                    s += (click + mechNoise)
                }
                out[i] = Float(s * 0.55)
            }

        case .keyboardTyping:
            // メカニカルキーボード打鍵: カチッ＋ポコッ
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let clickEnv = exp(-t * 120.0)
                let thudEnv = exp(-t * 35.0)
                let click = sin(2.0 * .pi * effectiveFreq * t + randomPhase) * clickEnv
                let noise = Double.random(in: -1...1) * clickEnv * 0.6 * effectiveNoise
                let resonance = sin(2.0 * .pi * 450.0 * t) * thudEnv * 0.4
                out[i] = Float((click + noise + resonance) * 0.50)
            }

        case .doorKnockOpen:
            // ドアノック（コンコン）＋開扉音
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                var s: Double = 0.0
                if t < 0.15 {
                    let env = exp(-t * 40.0)
                    s += sin(2.0 * .pi * effectiveFreq * t + randomPhase) * env * 0.7 + Double.random(in: -1...1) * env * 0.3 * effectiveNoise
                }
                if t >= 0.20 && t < 0.35 {
                    let t2 = t - 0.20
                    let env = exp(-t2 * 40.0)
                    s += sin(2.0 * .pi * effectiveFreq * t2) * env * 0.7 + Double.random(in: -1...1) * env * 0.3 * effectiveNoise
                }
                if t >= 0.45 {
                    let t3 = t - 0.45
                    let env = sin(.pi * t3 / max(0.01, effectiveDuration - 0.45))
                    s += sin(2.0 * .pi * 320.0 * t3) * env * 0.25
                }
                out[i] = Float(s * 0.55)
            }

        case .carHornDrive:
            // クラクション: 2音和音 (F#4 + A#4)
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = (t < 0.05) ? (t / 0.05) : (t > effectiveDuration - 0.08 ? (effectiveDuration - t) / 0.08 : 1.0)
                let s1 = sin(2.0 * .pi * effectiveFreq * t + randomPhase)
                let s2 = sin(2.0 * .pi * (effectiveFreq * 1.25) * t)
                let buzz = sin(2.0 * .pi * (effectiveFreq * 3.0) * t) * 0.3
                out[i] = Float((s1 + s2 + buzz) * env * 0.35)
            }

        case .paperRustle:
            // 紙めくり: 帯域通過ノイズのパサッという擦れ音
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = sin(.pi * t / effectiveDuration)
                let noise = Double.random(in: -1...1)
                let rustle = noise * env * (0.5 + 0.5 * sin(2.0 * .pi * 12.0 * t + randomPhase))
                out[i] = Float(rustle * 0.45)
            }

        case .footstepsWalk:
            // 足音・歩行: 短い床衝撃低音 (ドッ) + 微細な擦れノイズ
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = exp(-t * 28.0)
                let thud = sin(2.0 * .pi * effectiveFreq * t + randomPhase) * env * 0.8
                let scuff = Double.random(in: -1...1) * env * effectiveNoise * 0.6
                out[i] = Float((thud + scuff) * 0.55)
            }

        case .waterDrop:
            // 水滴・水音: ポチャン (上昇ピッチスイープ + 気泡レゾナンス)
            var phase: Double = randomPhase
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = exp(-t * 12.0)
                let f = effectiveFreq * (0.8 + 1.2 * (t / effectiveDuration))
                phase += 2.0 * .pi * f / Double(sampleRate)
                let drop = sin(phase) * env
                out[i] = Float(drop * 0.55)
            }

        // --- 一般ゲーム・映像演出・UI ---
        case .uiConfirm:
            // UI決定音: 澄んだ和音
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = exp(-t * 10.0)
                let s = sin(2.0 * .pi * effectiveFreq * t + randomPhase) + sin(2.0 * .pi * (effectiveFreq * 1.5) * t) * 0.5
                out[i] = Float(s * env * 0.45)
            }

        case .uiCancel:
            // UIキャンセル音: 下降2音
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let f = t < effectiveDuration / 2.0 ? effectiveFreq : effectiveFreq * 0.75
                let env = exp(-fmod(t, effectiveDuration / 2.0) * 14.0)
                out[i] = Float(sin(2.0 * .pi * f * t + randomPhase) * env * 0.45)
            }

        case .quizCorrectChime:
            // クイズ正解: ピンポンピンポン♪
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let half = effectiveDuration / 2.0
                let tLocal = fmod(t, half)
                let env = exp(-tLocal * 7.0)
                let f = tLocal < (half * 0.45) ? effectiveFreq : effectiveFreq * 0.749
                let s = sin(2.0 * .pi * f * tLocal + randomPhase) * env
                out[i] = Float(s * 0.48)
            }

        case .quizWrongBuzzer:
            // クイズ不正解: ブブーッ (低音矩形波＋わずかなデチューン)
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = (t < 0.04) ? (t / 0.04) : 1.0
                let p1 = fmod(t * effectiveFreq + randomPhase, 1.0) < 0.5 ? 1.0 : -1.0
                let p2 = fmod(t * (effectiveFreq * 1.05), 1.0) < 0.5 ? 1.0 : -1.0
                out[i] = Float((p1 * 0.6 + p2 * 0.4) * env * 0.45)
            }

        case .sceneTransitionWhoosh:
            // シーン切替・画面転換: 鋭い風切りスウィープ (シュッ)
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = sin(.pi * t / effectiveDuration)
                let sweepFreq = effectiveFreq * (1.0 + sin(.pi * t / effectiveDuration) * 3.0)
                let noise = Double.random(in: -1...1) * 0.6 * effectiveNoise
                let s = sin(2.0 * .pi * sweepFreq * t + randomPhase) * 0.4 + noise
                out[i] = Float(s * env * 0.60)
            }

        case .heavyPunchHit:
            // 重打撃・パンチヒット: 急降下サブベース＋インパクトクラッシュ
            var phase: Double = randomPhase
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = exp(-t * 12.0)
                let f = max(40.0, effectiveFreq * exp(-t * 25.0))
                phase += 2.0 * .pi * f / Double(sampleRate)
                let impact = sin(phase) * 0.7 + Double.random(in: -1...1) * exp(-t * 40.0) * 0.6 * effectiveNoise
                let distorted = tanh(impact * 2.5)
                out[i] = Float(distorted * env * 0.65)
            }

        case .massiveExplosion:
            // 大爆発・ボム: 超重低音＋長時間ノイズ爆風
            var phase: Double = randomPhase
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let subEnv = exp(-t * 4.0)
                let noiseEnv = exp(-t * 2.0)
                let f = max(35.0, effectiveFreq * exp(-t * 6.0))
                phase += 2.0 * .pi * f / Double(sampleRate)
                let sub = sin(phase) * subEnv * 0.5
                let blast = Double.random(in: -1...1) * noiseEnv * 0.6 * effectiveNoise
                let totalWave = (sub + blast)
                out[i] = Float(tanh(totalWave * 1.8) * 0.65)
            }

        case .swordSlashBlade:
            // 刀剣抜刀・斬撃: キーン（金属高音）＋シャキン（鋭利スウィープ）
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let ringEnv = exp(-t * 7.0)
                let whooshEnv = exp(-t * 18.0)
                let metallicRing = (sin(2.0 * .pi * effectiveFreq * t + randomPhase) + sin(2.0 * .pi * effectiveFreq * 1.73 * t) * 0.5) * ringEnv
                let slashNoise = Double.random(in: -1...1) * whooshEnv * 0.5 * effectiveNoise
                out[i] = Float((metallicRing * 0.5 + slashNoise) * 0.55)
            }

        case .cyberGlitchNoise:
            // サイバーグリッチ: 不連続ビットクラッシュ＋パルスノイズ
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let stepT = floor(t * 24.0)
                let glitchFreq = effectiveFreq * (1.0 + sin(stepT * 37.0 + randomPhase) * 0.8)
                let pulse = fmod(t * glitchFreq, 1.0) < 0.3 ? 0.8 : -0.8
                let noise = Double.random(in: -1...1) * effectiveNoise * 0.5
                let env = max(0.0, 1.0 - t / effectiveDuration)
                out[i] = Float((pulse + noise) * env * 0.45)
            }

        case .gunshotFire:
            // 銃声・発砲: 鋭いアタック衝撃波 + ピッチ降下サブベース + 残響ノイズ
            var phase: Double = randomPhase
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let crackEnv = exp(-t * 35.0)
                let tailEnv = exp(-t * 6.0)
                let f = max(40.0, effectiveFreq * exp(-t * 20.0))
                phase += 2.0 * .pi * f / Double(sampleRate)
                let punch = sin(phase) * crackEnv * 0.7
                let blast = Double.random(in: -1...1) * (crackEnv * 0.8 + tailEnv * 0.3) * effectiveNoise
                out[i] = Float(tanh((punch + blast) * 2.2) * 0.65)
            }

        case .thunderStrike:
            // 落雷・稲妻: 放電クラック + 長時間重低音ランブル
            var phase: Double = randomPhase
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let strikeEnv = exp(-t * 16.0)
                let rumbleEnv = exp(-t * 1.5)
                let f = max(35.0, effectiveFreq * (1.0 + sin(2.0 * .pi * 5.0 * t) * 0.3))
                phase += 2.0 * .pi * f / Double(sampleRate)
                let crack = Double.random(in: -1...1) * strikeEnv * 0.9
                let rumble = sin(phase) * rumbleEnv * 0.5 + Double.random(in: -1...1) * rumbleEnv * 0.4 * effectiveNoise
                out[i] = Float(tanh((crack + rumble) * 1.8) * 0.60)
            }

        case .fireFlame:
            // 炎・燃焼: 帯域ゆらぎノイズ (メラメラ) + パチパチ火の粉
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = sin(.pi * t / effectiveDuration)
                let flutter = 0.5 + 0.5 * sin(2.0 * .pi * 6.0 * t + randomPhase)
                let roar = Double.random(in: -1...1) * env * flutter * 0.5 * effectiveNoise
                let pop = (fmod(Double(i), Double(sampleRate) * 0.15) < 30.0 && Double.random(in: 0...1) > 0.6)
                    ? Double.random(in: -1...1) * 0.7
                    : 0.0
                out[i] = Float((roar + pop) * 0.55)
            }

        case .glassShatter:
            // ガラス破壊: 金属/ガラス高音リング + 破片散乱バースト
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = exp(-t * 8.0)
                let ring = (sin(2.0 * .pi * effectiveFreq * t + randomPhase) + sin(2.0 * .pi * (effectiveFreq * 1.414) * t) * 0.6) * env * 0.5
                let shatter = Double.random(in: -1...1) * env * 0.6 * effectiveNoise
                out[i] = Float((ring + shatter) * 0.55)
            }

        case .jumpSpring:
            // ジャンプ・バネ: 上昇スイープ (ピョン)
            var phase: Double = randomPhase
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = exp(-t * 6.0)
                let f = effectiveFreq * (1.0 + (t / effectiveDuration) * 2.5)
                phase += 2.0 * .pi * f / Double(sampleRate)
                out[i] = Float(sin(phase) * env * 0.55)
            }

        case .itemGetLevelUp:
            // アイテム獲得・レベルアップ: 上昇3音チャイム (C -> E -> G)
            let freqs = [effectiveFreq, effectiveFreq * 1.2599, effectiveFreq * 1.4983]
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                var s: Double = 0.0
                for (idx, f) in freqs.enumerated() {
                    let start = Double(idx) * (effectiveDuration * 0.22)
                    if t >= start {
                        let tLocal = t - start
                        let env = exp(-tLocal * 9.0)
                        s += sin(2.0 * .pi * f * tLocal + randomPhase) * env
                    }
                }
                out[i] = Float(s * 0.42)
            }

        // --- 東方Project・幻想郷 ---
        case .spellCardChime:
            // 華やかなアルペジオチャイム (4重和音)
            let freqs = [effectiveFreq, effectiveFreq * 1.2599, effectiveFreq * 1.4983, effectiveFreq * 2.0]
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                var sum: Double = 0
                for (idx, f) in freqs.enumerated() {
                    let delay = Double(idx) * 0.08
                    if t >= delay {
                        let noteT = t - delay
                        let env = exp(-noteT * 3.8)
                        sum += sin(2.0 * .pi * f * noteT + randomPhase) * env
                    }
                }
                out[i] = Float(sum * 0.32)
            }

        case .magicShine:
            // 魔法・閃光・キラキラ: 4重の美しいベル和音 (アルペジオ) + 煌めくトレモロ
            let freqs = [effectiveFreq, effectiveFreq * 1.2599, effectiveFreq * 1.4983, effectiveFreq * 1.8877]
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                var sum: Double = 0
                for (idx, f) in freqs.enumerated() {
                    let delay = Double(idx) * 0.06
                    if t >= delay {
                        let noteT = t - delay
                        let env = exp(-noteT * 3.5)
                        let shimmer = 1.0 + 0.3 * sin(2.0 * .pi * 8.0 * noteT + Double(idx))
                        sum += sin(2.0 * .pi * f * noteT + randomPhase) * env * shimmer
                    }
                }
                let sparkle = Double.random(in: -1...1) * effectiveNoise * 0.4 * exp(-t * 2.5)
                out[i] = Float((sum * 0.30 + sparkle) * 0.60)
            }

        case .masterSparkLaser:
            // 極太レーザー: サブベース + 急降下周波数 + ディストーション
            var phase: Double = randomPhase
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = exp(-t * 1.5)
                let freq = max(60.0, effectiveFreq * exp(-t * 2.2))
                phase += 2.0 * .pi * freq / Double(sampleRate)

                let s = sin(phase)
                let noise = Double.random(in: -1...1) * effectiveNoise
                let wave = (s + noise) * env
                let distorted = tanh(wave * 2.2)
                out[i] = Float(distorted * 0.65)
            }

        case .danmakuShot:
            // 弾幕ショット: ピュンピュン高音スイープ
            var phase: Double = randomPhase
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = exp(-t * 12.0)
                let freq = max(300.0, effectiveFreq * exp(-t * 18.0))
                phase += 2.0 * .pi * freq / Double(sampleRate)
                out[i] = Float(sin(phase) * env * 0.55)
            }

        case .playerPichuun:
            // ピチューン: 下降ピッチ＋レトロノイズ
            var phase: Double = randomPhase
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = exp(-t * 3.5)
                let freq = max(80.0, effectiveFreq * (1.0 - t / effectiveDuration))
                phase += 2.0 * .pi * freq / Double(sampleRate)
                let tone = sin(phase) * 0.6
                let noise = Double.random(in: -1...1) * 0.35 * exp(-t * 8.0) * effectiveNoise
                out[i] = Float((tone + noise) * env * 0.60)
            }

        case .timeStopSakuya:
            // 時間停止: 時計のチクタク＋反転スイープ
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let tick = (fmod(t, 0.25) < 0.02) ? sin(2.0 * .pi * 2200.0 * t) * 0.8 : 0.0
                let sweep = sin(2.0 * .pi * (effectiveFreq + t * 400.0) * t + randomPhase) * exp(-t * 2.0) * 0.3
                out[i] = Float((tick + sweep) * 0.55)
            }

        case .teleportWarp:
            // ワープ: 高速フェイザーノイズ
            var phase: Double = randomPhase
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = sin(.pi * t / effectiveDuration)
                let freq = effectiveFreq + sin(2.0 * .pi * 8.0 * t) * 300.0
                phase += 2.0 * .pi * freq / Double(sampleRate)
                let noise = Double.random(in: -1...1) * 0.4 * effectiveNoise
                out[i] = Float((sin(phase) * 0.5 + noise) * env * 0.60)
            }

        case .grazeSound:
            // グレイズ音: クリスプ高音チャイム
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = exp(-t * 35.0)
                let s1 = sin(2.0 * .pi * effectiveFreq * t + randomPhase)
                let s2 = sin(2.0 * .pi * (effectiveFreq * 1.5) * t) * 0.5
                out[i] = Float((s1 + s2) * env * 0.50)
            }

        case .teaCupSound:
            // お茶・日常音: 湯飲み置く音
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = exp(-t * 22.0)
                let click = sin(2.0 * .pi * 850.0 * t) * exp(-t * 40.0) * 0.8
                let resonance = sin(2.0 * .pi * 320.0 * t + randomPhase) * env * 0.4
                out[i] = Float((click + resonance) * 0.55)
            }

        // --- AIプロシージャル適応合成 (自由記述プロンプト) ---
        case .customSynthesized:
            var phase: Double = randomPhase
            for i in 0..<total {
                let t = Double(i) / Double(sampleRate)
                let env = exp(-t * (4.0 / effectiveDuration))
                let f = effectiveFreq * (1.0 + 0.15 * sin(2.0 * .pi * 5.0 * t))
                phase += 2.0 * .pi * f / Double(sampleRate)
                let tone = (sin(phase) + sin(phase * 2.0) * 0.3) * env * 0.6
                let noise = Double.random(in: -1...1) * effectiveNoise * env * 0.5
                out[i] = Float(tanh((tone + noise) * 1.4) * 0.55)
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
