import Foundation
import AVFoundation
import AppKit

public final class AquesTalkBridge: ObservableObject {
    public static let shared = AquesTalkBridge()

    @Published public var isAquesTalkAvailable: Bool = false
    @Published public var isAqKanjiAvailable: Bool = false
    @Published public var currentVoice: VoiceType = .f1
    @Published public var devKey: String = ""
    @Published public var usrKey: String = ""
    @Published public var isDevKeyValid: Bool = false
    @Published public var isUsrKeyValid: Bool = false
    @Published public var isKanjiDevKeyValid: Bool = false
    @Published public var lastLicenseStatus: String = "未認証"
    @Published public var lastLog: String = "AquesTalkBridge initialized"

    private var audioPlayer: AVAudioPlayer?
    private var kanji2koeHandle: UnsafeMutableRawPointer?

    // Function pointers for AquesTalk1
    private typealias SyntheUtf8Func = @convention(c) (UnsafePointer<CChar>, Int32, UnsafeMutablePointer<Int32>) -> UnsafeMutablePointer<UInt8>?
    private typealias FreeWaveFunc = @convention(c) (UnsafeMutablePointer<UInt8>) -> Void
    private typealias SetDevKeyFunc = @convention(c) (UnsafePointer<CChar>) -> Int32
    private typealias SetUsrKeyFunc = @convention(c) (UnsafePointer<CChar>) -> Int32

    // Function pointers for AqKanji2Koe
    private typealias KanjiCreateFunc = @convention(c) (UnsafePointer<CChar>, UnsafeMutablePointer<Int32>) -> UnsafeMutableRawPointer?
    private typealias KanjiReleaseFunc = @convention(c) (UnsafeMutableRawPointer) -> Void
    private typealias KanjiConvertUtf8Func = @convention(c) (UnsafeMutableRawPointer, UnsafePointer<CChar>, UnsafeMutablePointer<CChar>, Int32) -> Int32
    private typealias KanjiSetDevKeyFunc = @convention(c) (UnsafePointer<CChar>) -> Int32

    private struct VoiceSymbols {
        var handle: UnsafeMutableRawPointer
        var synthe: SyntheUtf8Func
        var freeWave: FreeWaveFunc
        var setDevKey: SetDevKeyFunc?
        var setUsrKey: SetUsrKeyFunc?
    }

    private var loadedVoiceSymbols: [VoiceType: VoiceSymbols] = [:]

    private var kanjiCreatePtr: KanjiCreateFunc?
    private var kanjiReleasePtr: KanjiReleaseFunc?
    private var kanjiConvertUtf8Ptr: KanjiConvertUtf8Func?
    private var kanjiSetDevKeyPtr: KanjiSetDevKeyFunc?

    private init() {
        loadLibraries()
        syncFromSavedUserDefaults()
    }

    deinit {
        if let handle = kanji2koeHandle, let releaseFunc = kanjiReleasePtr {
            releaseFunc(handle)
        }
        for (_, symbols) in loadedVoiceSymbols {
            dlclose(symbols.handle)
        }
    }

    public func loadLibraries() {
        let basePath = "/Volumes/ZSSD/GitHub/repository/TohoStudio/Application/AquesTalk"

        // Preload current voice and all voice types
        for voice in VoiceType.allCases {
            loadVoiceTypeLibrary(voice: voice, basePath: basePath)
        }

        if loadedVoiceSymbols[currentVoice] != nil {
            isAquesTalkAvailable = true
            lastLog = "AquesTalk1 dylib loaded successfully (\(currentVoice.rawValue))"
        } else {
            isAquesTalkAvailable = false
            lastLog = "AquesTalk1 dylib load fallback"
        }

        // Load AqKanji2Koe
        let kanjiLibPath = "\(basePath)/AquesTalk2KanjiKoe/lib/libAqKanji2Koe.dylib"
        let dicPath = "\(basePath)/AquesTalk2KanjiKoe/aq_dic"
        if let kHandle = dlopen(kanjiLibPath, RTLD_NOW) {
            if let sym = dlsym(kHandle, "AqKanji2Koe_Create") {
                kanjiCreatePtr = unsafeBitCast(sym, to: KanjiCreateFunc.self)
            }
            if let sym = dlsym(kHandle, "AqKanji2Koe_Release") {
                kanjiReleasePtr = unsafeBitCast(sym, to: KanjiReleaseFunc.self)
            }
            if let sym = dlsym(kHandle, "AqKanji2Koe_Convert") ?? dlsym(kHandle, "AqKanji2Koe_Convert_Utf8") {
                kanjiConvertUtf8Ptr = unsafeBitCast(sym, to: KanjiConvertUtf8Func.self)
            }
            if let sym = dlsym(kHandle, "AqKanji2Koe_SetDevKey") {
                kanjiSetDevKeyPtr = unsafeBitCast(sym, to: KanjiSetDevKeyFunc.self)
            }

            if let createFunc = kanjiCreatePtr {
                var errCode: Int32 = 0
                kanji2koeHandle = dicPath.withCString { cPath in
                    createFunc(cPath, &errCode)
                }
                isAqKanjiAvailable = (kanji2koeHandle != nil)
                if isAqKanjiAvailable {
                    lastLog += " | AqKanji2Koe loaded with dictionary"
                } else {
                    lastLog += " | AqKanji2Koe dictionary init code: \(errCode)"
                }
            }
        }
    }

    @discardableResult
    private func loadVoiceTypeLibrary(voice: VoiceType, basePath: String) -> VoiceSymbols? {
        if let existing = loadedVoiceSymbols[voice] {
            return existing
        }

        let voiceLibPath = "\(basePath)/AquesTalk1/lib/libAquesTalk1-\(voice.dylibSuffix).dylib"
        guard let handle = dlopen(voiceLibPath, RTLD_NOW) else {
            return nil
        }

        guard let symSynthe = dlsym(handle, "AquesTalk_Synthe_Utf8"),
              let symFree = dlsym(handle, "AquesTalk_FreeWave") else {
            dlclose(handle)
            return nil
        }

        let synthe = unsafeBitCast(symSynthe, to: SyntheUtf8Func.self)
        let freeWave = unsafeBitCast(symFree, to: FreeWaveFunc.self)

        var devFunc: SetDevKeyFunc? = nil
        var usrFunc: SetUsrKeyFunc? = nil
        if let symDev = dlsym(handle, "AquesTalk_SetDevKey") {
            devFunc = unsafeBitCast(symDev, to: SetDevKeyFunc.self)
        }
        if let symUsr = dlsym(handle, "AquesTalk_SetUsrKey") {
            usrFunc = unsafeBitCast(symUsr, to: SetUsrKeyFunc.self)
        }

        let symbols = VoiceSymbols(handle: handle, synthe: synthe, freeWave: freeWave, setDevKey: devFunc, setUsrKey: usrFunc)
        loadedVoiceSymbols[voice] = symbols

        // 既存のキーがあれば適用
        if !devKey.isEmpty, let dev = devFunc {
            let res = devKey.withCString { dev($0) }
            if res == 0 { isDevKeyValid = true }
        }
        if !usrKey.isEmpty, let usr = usrFunc {
            let res = usrKey.withCString { usr($0) }
            if res == 0 { isUsrKeyValid = true }
        }

        return symbols
    }

    public func setVoiceType(_ voice: VoiceType) {
        currentVoice = voice
        isAquesTalkAvailable = (loadedVoiceSymbols[voice] != nil)
    }

    public func syncFromSavedUserDefaults() {
        let devKeyPrefix = "AquesTalk_DevLicenseKey_"
        let regularKeyPrefix = "AquesTalk_LicenseKey_"

        let aq1Dev = UserDefaults.standard.string(forKey: "\(devKeyPrefix)AquesTalk1")
            ?? UserDefaults.standard.string(forKey: "\(devKeyPrefix)包括")
            ?? UserDefaults.standard.string(forKey: "\(regularKeyPrefix)開発ライセンス")
            ?? ""
        var aq1Usr = UserDefaults.standard.string(forKey: "\(regularKeyPrefix)使用ライセンス") ?? ""
        if aq1Usr.isEmpty {
            aq1Usr = UserDefaults.standard.string(forKey: "\(regularKeyPrefix)AquesTalk1") ?? ""
        }
        let kanjiDev = UserDefaults.standard.string(forKey: "\(devKeyPrefix)AquesTalk2KanjiKoe")
            ?? UserDefaults.standard.string(forKey: "\(devKeyPrefix)包括")
            ?? ""

        applyMultiKeys(aqDev: aq1Dev, aqUsr: aq1Usr, kanjiDev: kanjiDev)
    }

    public func applyKeys(dev: String, usr: String) {
        applyMultiKeys(aqDev: dev, aqUsr: usr, kanjiDev: dev)
    }

    public func applyMultiKeys(aqDev: String, aqUsr: String, kanjiDev: String) {
        let trimmedDev = aqDev.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let trimmedUsr = aqUsr.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        let trimmedKanji = kanjiDev.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        self.devKey = trimmedDev.isEmpty ? trimmedKanji : trimmedDev
        self.usrKey = trimmedUsr

        var devSuccessCount = 0
        var devTotalCount = 0
        var usrSuccessCount = 0
        var usrTotalCount = 0

        for (_, symbols) in loadedVoiceSymbols {
            if let devFunc = symbols.setDevKey {
                devTotalCount += 1
                if !trimmedDev.isEmpty {
                    let res = trimmedDev.withCString { devFunc($0) }
                    if res == 0 {
                        devSuccessCount += 1
                    }
                }
            }
            if let usrFunc = symbols.setUsrKey {
                usrTotalCount += 1
                if !trimmedUsr.isEmpty {
                    let res = trimmedUsr.withCString { usrFunc($0) }
                    if res == 0 {
                        usrSuccessCount += 1
                    }
                }
            }
        }

        var kanjiSuccess = false
        if let kDevFunc = kanjiSetDevKeyPtr {
            let keyToUse = !trimmedKanji.isEmpty ? trimmedKanji : trimmedDev
            if !keyToUse.isEmpty {
                let res = keyToUse.withCString { kDevFunc($0) }
                kanjiSuccess = (res == 0)
            }
        }

        self.isDevKeyValid = !trimmedDev.isEmpty && (devSuccessCount > 0 || devTotalCount == 0)
        self.isUsrKeyValid = !trimmedUsr.isEmpty && (usrSuccessCount > 0 || usrTotalCount == 0)
        self.isKanjiDevKeyValid = kanjiSuccess

        if isDevKeyValid && isUsrKeyValid {
            lastLicenseStatus = "認証済み (開発＆使用ライセンス適用中)"
        } else if isDevKeyValid {
            lastLicenseStatus = "開発ライセンス認証済み"
        } else if isUsrKeyValid {
            lastLicenseStatus = "使用ライセンス認証済み"
        } else {
            lastLicenseStatus = (!trimmedDev.isEmpty || !trimmedUsr.isEmpty) ? "認証エラー (キー不一致)" : "未認証 (評価版動作)"
        }

        lastLog = "ライセンス適用: Dev(\(isDevKeyValid ? "有効" : "無効")), Usr(\(isUsrKeyValid ? "有効" : "無効")), 漢字(\(isKanjiDevKeyValid ? "有効" : "無効")) - \(lastLicenseStatus)"
    }

    /// 東方キャラクター名から推奨されるVoiceTypeを解決（早苗はコゲ日記、それ以外はゆっくりボイスメーカー＞コゲ日記＞Gスカ）
    public func voiceType(for characterName: String) -> VoiceType {
        let name = characterName.trimmingCharacters(in: .whitespacesAndNewlines)
        // 1. 東風谷早苗: コゲの日記準拠（女性2）
        if name.contains("早苗") { return .f2 }

        // 2. ゆっくりボイスメーカー準拠
        if name.contains("霊夢") { return .f1 }
        if name.contains("魔理沙") { return .f2 }
        if name.contains("咲夜") { return .f1 }
        if name.contains("妖夢") { return .f2 }
        if name.contains("チルノ") { return .f2 }
        if name.contains("レミリア") { return .f1 }
        if name.contains("フラン") { return .jgr }
        if name.contains("アリス") { return .f1 }
        if name.contains("パチュリー") { return .f2 }
        if name.contains("こいし") { return .f2 }
        if name.contains("さとり") { return .jgr }
        if name.contains("文") { return .f2 }
        if name.contains("妹紅") { return .f2 }
        if name.contains("諏訪子") { return .f1 }
        if name.contains("神奈子") { return .f1 }
        if name.contains("にとり") { return .jgr }
        if name.contains("小傘") { return .imd1 }
        if name.contains("白蓮") { return .imd1 }
        if name.contains("萃香") || name.contains("すいか") { return .imd1 }
        if name.contains("優曇華") || name.contains("うどんげ") { return .f1 }
        if name.contains("輝夜") || name.contains("かぐや") { return .f1 }
        if name.contains("てゐ") { return .imd1 }
        if name.contains("空") || name.contains("おくう") { return .imd1 }
        if name.contains("映姫") || name.contains("えいき") { return .f2 }
        if name.contains("ぬえ") { return .f2 }
        if name.contains("はたて") { return .f2 }
        if name.contains("パルスィ") || name.contains("ぱるすぃ") { return .f2 }
        if name.contains("椛") || name.contains("もみじ") { return .f1 }
        if name.contains("ナズーリン") || name.contains("なずーりん") { return .f1 }
        if name.contains("星") || name.contains("とらまる") { return .f2 }
        if name.contains("ミスティア") || name.contains("みすちー") { return .f1 }
        if name.contains("ヤマメ") || name.contains("やまめ") { return .f2 }
        if name.contains("一輪") || name.contains("いちりん") { return .f2 }
        if name.contains("天子") || name.contains("てんこ") { return .f2 }
        if name.contains("リグル") || name.contains("りぐる") { return .m1 }
        if name.contains("リリーホワイト") { return .f1 }
        if name.contains("リリカ") { return .f1 }
        if name.contains("サニーミルク") { return .jgr }
        if name.contains("ルナチャイルド") { return .f2 }
        if name.contains("霖之助") || name.contains("こーりん") { return .m1 }
        if name.contains("きめぇまる") { return .m1 }

        // 3. コゲの日記準拠（ゆっくりボイスメーカーにないキャラ）
        if name.contains("紫") { return .f2 }
        if name.contains("幽々子") { return .f2 }
        if name.contains("藍") { return .f2 }
        if name.contains("橙") { return .f1 }
        if name.contains("大妖精") { return .f1 }
        if name.contains("ルーミア") { return .f1 }
        if name.contains("慧音") { return .imd1 }
        if name.contains("燐") || name.contains("お燐") { return .f2 }
        if name.contains("幽香") { return .imd1 }
        if name.contains("小鈴") { return .f1 }
        if name.contains("正邪") { return .imd1 }
        if name.contains("美鈴") { return .imd1 }
        if name.contains("小悪魔") { return .f1 }
        if name.contains("布都") { return .f1 }
        if name.contains("小町") { return .f2 }
        if name.contains("神子") { return .f1 }
        if name.contains("響子") { return .f1 }
        if name.contains("村紗") { return .f2 }

        // 4. Gスカブログ準拠（ゆっくりボイスメーカー・コゲの日記にないキャラ）
        if name.contains("永琳") { return .imd1 }
        if name.contains("華扇") { return .f1 }
        if name.contains("あうん") { return .f1 }
        if name.contains("スターサファイア") { return .f2 }
        if name.contains("龍") || name.contains("飯綱丸") { return .f2 }
        if name.contains("典") || name.contains("菅牧") { return .f1 }
        if name.contains("ミケ") || name.contains("豪徳寺") { return .f1 }
        if name.contains("駒草") || name.contains("山如") { return .f2 }
        if name.contains("魅須丸") { return .jgr }
        if name.contains("千亦") { return .f1 }
        if name.contains("百々世") { return .imd1 }
        if name.contains("たかね") { return .f2 }
        if name.contains("瓔花") { return .f1 }
        if name.contains("潤美") { return .f2 }
        if name.contains("久侘歌") { return .f1 }
        if name.contains("八千慧") { return .imd1 }
        if name.contains("磨弓") { return .jgr }
        if name.contains("袿姫") { return .imd1 }
        if name.contains("早鬼") { return .imd1 }
        if name.contains("慧ノ子") { return .f2 }
        if name.contains("先代巫女") { return .f1 }
        if name.contains("魅魔") { return .f2 }
        if name.contains("神綺") { return .f1 }
        if name.contains("夢美") { return .f1 }
        if name.contains("操夢") { return .imd1 }
        if name == "ナレーション" || name.contains("ナレーション") { return .f1 }

        return .f1
    }

    /// キャラクター名から推奨されるテンプレート設定（速度・音程など）を解決
    /// ルール: 東風谷早苗はコゲ日記、それ以外はゆっくりボイスメーカー＞コゲ日記＞Gスカ
    public func characterPreset(for characterName: String) -> (voice: VoiceType, speed: Int, pitch: Int) {
        let v = voiceType(for: characterName)
        let name = characterName.trimmingCharacters(in: .whitespacesAndNewlines)

        // 0. 交換夫婦・二次創作登場人物
        if name.contains("操夢") { return (.imd1, 100, 115) }
        if name == "ナレーション" || name.contains("ナレーション") { return (.f1, 100, 100) }

        // 1. 東風谷早苗: コゲの日記準拠（女性2, 速度90, 音程135）
        if name.contains("早苗") { return (.f2, 90, 135) }

        // 2. ゆっくりボイスメーカー準拠
        if name.contains("霊夢") { return (.f1, 100, 100) }
        if name.contains("魔理沙") { return (.f2, 100, 100) }
        if name.contains("咲夜") { return (.f1, 105, 125) }
        if name.contains("妖夢") { return (.f2, 115, 120) }
        if name.contains("チルノ") { return (.f2, 115, 120) }
        if name.contains("レミリア") { return (.f1, 80, 150) }
        if name.contains("フラン") { return (.jgr, 100, 100) }
        if name.contains("アリス") { return (.f1, 110, 130) }
        if name.contains("パチュリー") { return (.f2, 120, 115) }
        if name.contains("こいし") { return (.f2, 50, 181) }
        if name.contains("さとり") { return (.jgr, 115, 125) }
        if name.contains("文") { return (.f2, 100, 125) }
        if name.contains("妹紅") { return (.f2, 100, 120) }
        if name.contains("諏訪子") { return (.f1, 80, 175) }
        if name.contains("神奈子") { return (.f1, 115, 90) }
        if name.contains("にとり") { return (.jgr, 105, 105) }
        if name.contains("小傘") { return (.imd1, 110, 130) }
        if name.contains("白蓮") { return (.imd1, 102, 97) }
        if name.contains("萃香") || name.contains("すいか") { return (.imd1, 100, 150) }
        if name.contains("優曇華") || name.contains("うどんげ") { return (.f1, 80, 120) }
        if name.contains("輝夜") || name.contains("かぐや") { return (.f1, 100, 120) }
        if name.contains("てゐ") { return (.imd1, 110, 120) }
        if name.contains("空") || name.contains("おくう") { return (.imd1, 80, 170) }
        if name.contains("映姫") || name.contains("えいき") { return (.f2, 87, 117) }
        if name.contains("ぬえ") { return (.f2, 100, 180) }
        if name.contains("はたて") { return (.f2, 84, 121) }
        if name.contains("パルスィ") || name.contains("ぱるすぃ") { return (.f2, 80, 130) }
        if name.contains("椛") || name.contains("もみじ") { return (.f1, 120, 110) }
        if name.contains("ナズーリン") || name.contains("なずーりん") { return (.f1, 90, 115) }
        if name.contains("星") || name.contains("とらまる") { return (.f2, 120, 110) }
        if name.contains("ミスティア") || name.contains("みすちー") { return (.f1, 100, 105) }
        if name.contains("ヤマメ") || name.contains("やまめ") { return (.f2, 110, 115) }
        if name.contains("一輪") || name.contains("いちりん") { return (.f2, 65, 145) }
        if name.contains("天子") || name.contains("てんこ") { return (.f2, 75, 134) }
        if name.contains("リグル") || name.contains("りぐる") { return (.m1, 110, 140) }
        if name.contains("リリーホワイト") { return (.f1, 110, 115) }
        if name.contains("リリカ") { return (.f1, 95, 135) }
        if name.contains("サニーミルク") { return (.jgr, 125, 120) }
        if name.contains("ルナチャイルド") { return (.f2, 120, 125) }
        if name.contains("霖之助") || name.contains("こーりん") { return (.m1, 100, 105) }
        if name.contains("きめぇまる") { return (.m1, 80, 140) }

        // 3. コゲの日記準拠（ゆっくりボイスメーカーにないキャラ）
        if name.contains("紫") { return (.f2, 96, 127) }
        if name.contains("幽々子") { return (.f2, 96, 127) }
        if name.contains("藍") { return (.f2, 115, 113) }
        if name.contains("橙") { return (.f1, 80, 160) }
        if name.contains("大妖精") { return (.f1, 96, 138) }
        if name.contains("ルーミア") { return (.f1, 63, 165) }
        if name.contains("慧音") { return (.imd1, 95, 145) }
        if name.contains("燐") || name.contains("お燐") { return (.f2, 130, 125) }
        if name.contains("幽香") { return (.imd1, 100, 160) }
        if name.contains("小鈴") { return (.f1, 99, 130) }
        if name.contains("正邪") { return (.imd1, 110, 133) }
        if name.contains("美鈴") { return (.imd1, 110, 155) }
        if name.contains("小悪魔") { return (.f1, 95, 165) }
        if name.contains("布都") { return (.f1, 110, 123) }
        if name.contains("小町") { return (.f2, 100, 129) }
        if name.contains("神子") { return (.f1, 130, 103) }
        if name.contains("響子") { return (.f1, 70, 165) }
        if name.contains("村紗") { return (.f2, 100, 132) }

        // 4. Gスカブログ準拠（ゆっくりボイスメーカー・コゲの日記にないキャラ）
        if name.contains("永琳") { return (.imd1, 90, 130) }
        if name.contains("華扇") { return (.f1, 100, 140) }
        if name.contains("あうん") { return (.f1, 83, 140) }
        if name.contains("スターサファイア") { return (.f2, 60, 150) }
        if name.contains("龍") || name.contains("飯綱丸") { return (.f2, 93, 116) }
        if name.contains("典") || name.contains("菅牧") { return (.f1, 90, 130) }
        if name.contains("ミケ") || name.contains("豪徳寺") { return (.f1, 80, 180) }
        if name.contains("駒草") || name.contains("山如") { return (.f2, 110, 110) }
        if name.contains("魅須丸") { return (.jgr, 90, 150) }
        if name.contains("千亦") { return (.f1, 85, 140) }
        if name.contains("百々世") { return (.imd1, 80, 160) }
        if name.contains("たかね") { return (.f2, 90, 150) }
        if name.contains("瓔花") { return (.f1, 90, 160) }
        if name.contains("潤美") { return (.f2, 110, 120) }
        if name.contains("久侘歌") { return (.f1, 90, 160) }
        if name.contains("八千慧") { return (.imd1, 115, 120) }
        if name.contains("磨弓") { return (.jgr, 80, 160) }
        if name.contains("袿姫") { return (.imd1, 110, 140) }
        if name.contains("早鬼") { return (.imd1, 70, 180) }
        if name.contains("慧ノ子") { return (.f2, 85, 140) }
        if name.contains("先代巫女") { return (.f1, 130, 115) }
        if name.contains("魅魔") { return (.f2, 90, 125) }
        if name.contains("神綺") { return (.f1, 60, 130) }
        if name.contains("夢美") { return (.f1, 130, 80) }

        return (v, 100, 100)
    }

    /// Convert text (kanji/kana) to phonetic symbol string
    public func convertToVoiceSymbol(text: String) -> String {
        let cleaned = SlideItem.cleanDialogueText(from: text)
        let effectiveText = cleaned.isEmpty ? text : cleaned

        guard let handle = kanji2koeHandle, let convertFunc = kanjiConvertUtf8Ptr else {
            // Simple fallback pseudo-phonetic conversion
            return effectiveText.replacingOccurrences(of: "東方", with: "トーフオ_")
        }

        let bufferSize = 4096
        var buffer = [CChar](repeating: 0, count: bufferSize)
        let res = effectiveText.withCString { cText in
            convertFunc(handle, cText, &buffer, Int32(bufferSize))
        }

        if res == 0 {
            return String(cString: buffer)
        } else {
            return effectiveText // fallback on error code
        }
    }

    /// 音声を合成してWAVデータ（Data）を返す（音質改善、ピッチシフト、エフェクトを適用）
    public func synthesizeToWavData(
        text: String,
        speed: Int = 100,
        voice: VoiceType? = nil,
        pitch: Int = 100,
        quality: AudioQualitySetting = .enhanced,
        effect: AudioEffectType = .none
    ) -> Data? {
        let cleanedText = SlideItem.cleanDialogueText(from: text)
        let targetText = cleanedText.isEmpty ? text : cleanedText
        let targetVoice = voice ?? currentVoice
        let phoneticText = convertToVoiceSymbol(text: targetText)

        let basePath = "/Volumes/ZSSD/GitHub/repository/TohoStudio/Application/AquesTalk"
        let symbols = loadedVoiceSymbols[targetVoice] ?? loadVoiceTypeLibrary(voice: targetVoice, basePath: basePath)

        if let sym = symbols {
            var dataSize: Int32 = 0
            let soundPtr = phoneticText.withCString { cPhonetic in
                sym.synthe(cPhonetic, Int32(speed), &dataSize)
            }

            if let resultPtr = soundPtr, dataSize > 0 {
                let rawSoundData = Data(bytes: resultPtr, count: Int(dataSize))
                sym.freeWave(resultPtr)

                // 音質改善、ピッチシフト、エフェクト処理を適用 (ゆっくりボイスメーカー準拠)
                let processedData = AudioEffectProcessor.shared.process(
                    wavData: rawSoundData,
                    quality: quality,
                    effect: effect,
                    pitch: pitch
                )
                return processedData
            }
        }

        // フォールバック: 合成データが取得できない場合の擬似PCM/標準合成
        return generateFallbackWavData(text: targetText, speed: speed, quality: quality, effect: effect, pitch: pitch)
    }

    /// Synthesize speech and play via AVAudioPlayer, or fallback to NSSpeechSynthesizer
    public func synthesizeAndPlay(
        text: String,
        speed: Int = 100,
        voice: VoiceType? = nil,
        pitch: Int = 100,
        quality: AudioQualitySetting = .enhanced,
        effect: AudioEffectType = .none,
        onComplete: (() -> Void)? = nil
    ) {
        let cleanedText = SlideItem.cleanDialogueText(from: text)
        let targetText = cleanedText.isEmpty ? text : cleanedText
        if let wavData = synthesizeToWavData(text: targetText, speed: speed, voice: voice, pitch: pitch, quality: quality, effect: effect) {
            do {
                audioPlayer = try AVAudioPlayer(data: wavData)
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
                let effectDesc = effect == .echo ? " [エコー]" : ""
                let qualityDesc = quality == .enhanced ? " [高音質改善]" : " [原音]"
                let pitchDesc = pitch != 100 ? " [音程\(pitch)%]" : ""
                lastLog = "AquesTalk再生成功: [\(targetText)] (\(wavData.count) bytes)\(pitchDesc)\(qualityDesc)\(effectDesc)"
                onComplete?()
                return
            } catch {
                lastLog = "AVAudioPlayer再生エラー: \(error.localizedDescription)"
            }
        }

        // Native macOS Speech Synthesizer fallback
        #if os(macOS)
        let synth = NSSpeechSynthesizer()
        synth.rate = Float(speed * 2)
        synth.startSpeaking(text)
        lastLog = "macOS標準Speechで再生: [\(text)]"
        #endif
        onComplete?()
    }

    /// 音声ファイルが利用できない環境用の最小限のサイン波/無音WAVジェネレーター（プレビュー波形用）
    private func generateFallbackWavData(
        text: String,
        speed: Int,
        quality: AudioQualitySetting,
        effect: AudioEffectType,
        pitch: Int = 100
    ) -> Data {
        let sampleRate = quality.isEnabled ? 44100 : 8000
        let duration = max(0.5, Double(text.count) * 0.15 * (100.0 / Double(max(50, speed))))
        let sampleCount = Int(duration * Double(sampleRate))

        var samples = [Float](repeating: 0, count: sampleCount)
        let baseFreq: Float = 440.0
        let pitchMultiplier = Float(pitch) / 100.0
        let freq = baseFreq * pitchMultiplier
        for i in 0..<sampleCount {
            let t = Float(i) / Float(sampleRate)
            // 優しいビープトーン
            let env = min(1.0, Float(i) / 100.0) * min(1.0, Float(sampleCount - i) / 500.0)
            samples[i] = sin(2.0 * .pi * freq * t) * 0.15 * env
        }

        // エンコード
        let rawWav = encodeSimpleWav(samples: samples, sampleRate: sampleRate)
        return AudioEffectProcessor.shared.process(wavData: rawWav, quality: quality, effect: effect, pitch: pitch)
    }

    private func encodeSimpleWav(samples: [Float], sampleRate: Int) -> Data {
        let dataSize = UInt32(samples.count * 2)
        let fileSize = 36 + dataSize
        var data = Data()

        data.append(contentsOf: "RIFF".utf8)
        var cs = fileSize
        data.append(Data(bytes: &cs, count: 4))
        data.append(contentsOf: "WAVEfmt ".utf8)
        var s16: UInt32 = 16
        data.append(Data(bytes: &s16, count: 4))
        var f1: UInt16 = 1
        data.append(Data(bytes: &f1, count: 2))
        var ch1: UInt16 = 1
        data.append(Data(bytes: &ch1, count: 2))
        var sr = UInt32(sampleRate)
        data.append(Data(bytes: &sr, count: 4))
        var br = UInt32(sampleRate * 2)
        data.append(Data(bytes: &br, count: 4))
        var ba: UInt16 = 2
        data.append(Data(bytes: &ba, count: 2))
        var bp: UInt16 = 16
        data.append(Data(bytes: &bp, count: 2))
        data.append(contentsOf: "data".utf8)
        var ds = dataSize
        data.append(Data(bytes: &ds, count: 4))

        var int16s = [Int16](repeating: 0, count: samples.count)
        for i in 0..<samples.count {
            int16s[i] = Int16(max(-1.0, min(1.0, samples[i])) * 32767.0)
        }
        data.append(Data(bytes: int16s, count: int16s.count * 2))
        return data
    }
}
