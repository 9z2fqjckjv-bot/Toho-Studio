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

    private var syntheUtf8Ptr: SyntheUtf8Func?
    private var freeWavePtr: FreeWaveFunc?
    private var setDevKeyPtr: SetDevKeyFunc?
    private var setUsrKeyPtr: SetUsrKeyFunc?

    private var kanjiCreatePtr: KanjiCreateFunc?
    private var kanjiReleasePtr: KanjiReleaseFunc?
    private var kanjiConvertUtf8Ptr: KanjiConvertUtf8Func?
    private var kanjiSetDevKeyPtr: KanjiSetDevKeyFunc?

    private var loadedDylibHandle: UnsafeMutableRawPointer?

    private init() {
        loadLibraries()
        // License keys will be loaded and synchronized via AquesTalkLicenseManager.shared
    }

    deinit {
        if let handle = kanji2koeHandle, let releaseFunc = kanjiReleasePtr {
            releaseFunc(handle)
        }
        if let dylib = loadedDylibHandle {
            dlclose(dylib)
        }
    }

    public func loadLibraries() {
        let basePath = "/Volumes/ZSSD/GitHub/repository/TohoStudio/Application/AquesTalk"

        // Load AquesTalk1
        let voiceLibPath = "\(basePath)/AquesTalk1/lib/libAquesTalk1-\(currentVoice.dylibSuffix).dylib"
        if let handle = dlopen(voiceLibPath, RTLD_NOW) {
            loadedDylibHandle = handle
            if let sym = dlsym(handle, "AquesTalk_Synthe_Utf8") {
                syntheUtf8Ptr = unsafeBitCast(sym, to: SyntheUtf8Func.self)
            }
            if let sym = dlsym(handle, "AquesTalk_FreeWave") {
                freeWavePtr = unsafeBitCast(sym, to: FreeWaveFunc.self)
            }
            if let sym = dlsym(handle, "AquesTalk_SetDevKey") {
                setDevKeyPtr = unsafeBitCast(sym, to: SetDevKeyFunc.self)
            }
            if let sym = dlsym(handle, "AquesTalk_SetUsrKey") {
                setUsrKeyPtr = unsafeBitCast(sym, to: SetUsrKeyFunc.self)
            }
            isAquesTalkAvailable = (syntheUtf8Ptr != nil && freeWavePtr != nil)
            lastLog = "AquesTalk1 dylib loaded successfully (\(currentVoice.rawValue))"
        } else {
            isAquesTalkAvailable = false
            let err = String(cString: dlerror())
            lastLog = "AquesTalk1 dlopen fallback: \(err)"
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
            if let sym = dlsym(kHandle, "AqKanji2Koe_Convert_Utf8") {
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

    public func setVoiceType(_ voice: VoiceType) {
        guard voice != currentVoice else { return }
        currentVoice = voice
        loadLibraries()
    }

    public func applyKeys(dev: String, usr: String) {
        applyMultiKeys(aqDev: dev, aqUsr: usr, kanjiDev: dev)
    }

    public func applyMultiKeys(aqDev: String, aqUsr: String, kanjiDev: String) {
        self.devKey = aqDev.isEmpty ? kanjiDev : aqDev
        self.usrKey = aqUsr
        if let devFunc = setDevKeyPtr, !aqDev.isEmpty {
            aqDev.withCString { _ = devFunc($0) }
        }
        if let usrFunc = setUsrKeyPtr, !aqUsr.isEmpty {
            aqUsr.withCString { _ = usrFunc($0) }
        }
        if let kDevFunc = kanjiSetDevKeyPtr, !kanjiDev.isEmpty {
            kanjiDev.withCString { _ = kDevFunc($0) }
        }
    }

    /// Convert text (kanji/kana) to phonetic symbol string
    public func convertToVoiceSymbol(text: String) -> String {
        guard let handle = kanji2koeHandle, let convertFunc = kanjiConvertUtf8Ptr else {
            // Simple fallback pseudo-phonetic conversion
            return text.replacingOccurrences(of: "東方", with: "トーフオ_")
        }

        let bufferSize = 2048
        var buffer = [CChar](repeating: 0, count: bufferSize)
        let res = text.withCString { cText in
            convertFunc(handle, cText, &buffer, Int32(bufferSize))
        }

        if res == 0 {
            return String(cString: buffer)
        } else {
            return text // fallback on error code
        }
    }

    /// Synthesize speech and play via AVAudioPlayer, or fallback to NSSpeechSynthesizer
    public func synthesizeAndPlay(text: String, speed: Int = 100, onComplete: (() -> Void)? = nil) {
        let phoneticText = convertToVoiceSymbol(text: text)

        if isAquesTalkAvailable, let synthe = syntheUtf8Ptr, let freeWave = freeWavePtr {
            var dataSize: Int32 = 0
            let soundPtr = phoneticText.withCString { cPhonetic in
                synthe(cPhonetic, Int32(speed), &dataSize)
            }

            if let resultPtr = soundPtr, dataSize > 0 {
                let soundData = Data(bytes: resultPtr, count: Int(dataSize))
                freeWave(resultPtr)

                do {
                    audioPlayer = try AVAudioPlayer(data: soundData)
                    audioPlayer?.prepareToPlay()
                    audioPlayer?.play()
                    lastLog = "AquesTalk再生成功: [\(text)] (\(dataSize) bytes)"
                    onComplete?()
                    return
                } catch {
                    lastLog = "AVAudioPlayer再生エラー: \(error.localizedDescription)"
                }
            } else {
                lastLog = "AquesTalk_Synthe_Utf8 失敗 (code: \(dataSize)), フォールバック再生に切り替えます"
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
}
