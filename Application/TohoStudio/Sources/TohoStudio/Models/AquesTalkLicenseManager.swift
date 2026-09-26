import Foundation
import SwiftUI

public enum AquesTalkTargetLibrary: String, CaseIterable, Identifiable {
    case aquesTalk1 = "AquesTalk1"
    case aquesTalk2 = "AquesTalk2"
    case aquesTalk10 = "AquesTalk10"
    case aquesTalk2KanjiKoe = "AquesTalk2KanjiKoe"
    case commercialUse = "使用ライセンス"
    case development = "開発ライセンス"
    case aquesTalkPi = "AquesTalk Pi"
    case aquesTalkESP32 = "AquesTalk ESP32"

    public var id: String { rawValue }

    public static var voiceLibraries: [AquesTalkTargetLibrary] {
        return [.aquesTalk1, .aquesTalk2, .aquesTalk10, .aquesTalk2KanjiKoe, .aquesTalkPi, .aquesTalkESP32]
    }

    public var displayName: String {
        switch self {
        case .commercialUse: return "使用ライセンス（商用向け・まとめて利用）"
        case .development: return "包括開発ライセンス（全ライブラリ共通）"
        default: return "\(rawValue) ライセンス"
        }
    }

    public var shortName: String {
        switch self {
        case .commercialUse: return "使用ライセンス"
        case .development: return "包括開発ライセンス"
        default: return rawValue
        }
    }

    public var regularPurchaseURL: URL {
        switch self {
        case .aquesTalk1:
            return URL(string: "https://store.a-quest.com/items/7905423")!
        case .aquesTalk2:
            return URL(string: "https://store.a-quest.com/items/7905447")!
        case .aquesTalk10:
            return URL(string: "https://store.a-quest.com/items/8529902")!
        case .aquesTalk2KanjiKoe:
            return URL(string: "https://store.a-quest.com/items/8537381")!
        case .commercialUse:
            return URL(string: "https://store.a-quest.com/items/7413986")!
        case .development:
            return URL(string: "https://store.a-quest.com/")!
        case .aquesTalkPi:
            return URL(string: "https://store.a-quest.com/items/7456364")!
        case .aquesTalkESP32:
            return URL(string: "https://store.a-quest.com/items/10524168")!
        }
    }

    public var purchaseURL: URL {
        return regularPurchaseURL
    }

    public var devPurchaseURL: URL {
        switch self {
        case .aquesTalk1:
            return URL(string: "https://store.a-quest.com/items/7456426")!
        case .aquesTalk2:
            return URL(string: "https://store.a-quest.com/items/7456426")!
        case .aquesTalk10:
            return URL(string: "https://store.a-quest.com/items/8529902")!
        case .aquesTalk2KanjiKoe:
            return URL(string: "https://store.a-quest.com/items/8537381")!
        case .aquesTalkPi:
            return URL(string: "https://store.a-quest.com/items/7456364")!
        case .aquesTalkESP32:
            return URL(string: "https://store.a-quest.com/items/10524168")!
        default:
            return URL(string: "https://store.a-quest.com/")!
        }
    }

    public var purchaseButtonTitle: String {
        switch self {
        case .commercialUse:
            return "使用ライセンス（まとめて利用）を購入↗️"
        case .development:
            return "包括開発ライセンスを購入↗️"
        default:
            return "\(rawValue) 通常ライセンスを購入↗️"
        }
    }

    public var devPurchaseButtonTitle: String {
        return "\(rawValue) 開発ライセンスを購入↗️"
    }

    public var dylibDescription: String {
        switch self {
        case .aquesTalk1:
            return "AquesTalk1 音声合成エンジン (ゆっくりボイス標準エンジン)"
        case .aquesTalk2:
            return "AquesTalk2 音声合成エンジン (表現力向上・音響モデル拡張)"
        case .aquesTalk10:
            return "AquesTalk10 最新音声合成エンジン (高音質・小型化)"
        case .aquesTalk2KanjiKoe:
            return "AqKanji2Koe 漢字かな混じりテキスト言語解析・音韻変換エンジン"
        case .commercialUse:
            return "商用向け使用ライセンス (AquesTalk1, 2, 10, 2KanjiKoeをまとめて商用利用可能な包括ライセンス)"
        case .development:
            return "開発ライセンス (アプリケーション開発・組み込み・配布用包括ライセンス)"
        case .aquesTalkPi:
            return "AquesTalk Pi (Raspberry Pi・Linux組み込み向け)"
        case .aquesTalkESP32:
            return "AquesTalk ESP32 (超小型マイコン・IoT組み込み向け)"
        }
    }
}

public final class AquesTalkLicenseManager: ObservableObject {
    public static let shared = AquesTalkLicenseManager()

    /// 通常ライセンス / 使用ライセンスキー (キー: 対象ライブラリ)
    @Published public var regularKeys: [AquesTalkTargetLibrary: String] = [:]

    /// 開発ライセンスキー (各ライブラリ個別の開発ライセンスキー)
    @Published public var devKeys: [AquesTalkTargetLibrary: String] = [:]

    /// 包括開発ライセンスキー (全ライブラリ共通開発キー)
    @Published public var inclusiveDevKey: String = ""

    private let regularKeyPrefix = "AquesTalk_LicenseKey_"
    private let devKeyPrefix = "AquesTalk_DevLicenseKey_"

    private init() {
        loadAllKeys()
    }

    public func loadAllKeys() {
        var loadedRegular: [AquesTalkTargetLibrary: String] = [:]
        var loadedDev: [AquesTalkTargetLibrary: String] = [:]

        for lib in AquesTalkTargetLibrary.allCases {
            // Load regular keys
            let reg = (UserDefaults.standard.string(forKey: "\(regularKeyPrefix)\(lib.rawValue)") ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            loadedRegular[lib] = reg

            // Load library-specific dev keys
            let dev = (UserDefaults.standard.string(forKey: "\(devKeyPrefix)\(lib.rawValue)") ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
            loadedDev[lib] = dev
        }

        // Inclusive dev key (compatible with both keys)
        let incDev = (UserDefaults.standard.string(forKey: "\(devKeyPrefix)包括")
            ?? UserDefaults.standard.string(forKey: "\(regularKeyPrefix)開発ライセンス")
            ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.inclusiveDevKey = incDev

        self.regularKeys = loadedRegular
        self.devKeys = loadedDev

        syncWithBridge()
    }

    // MARK: - Regular Keys (通常ライセンス)

    public func getRegularKey(for lib: AquesTalkTargetLibrary) -> String {
        return regularKeys[lib] ?? ""
    }

    public func setRegularKey(_ key: String, for lib: AquesTalkTargetLibrary) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        regularKeys[lib] = trimmed
        UserDefaults.standard.set(trimmed, forKey: "\(regularKeyPrefix)\(lib.rawValue)")
        syncWithBridge()
    }

    public func removeRegularKey(for lib: AquesTalkTargetLibrary) {
        regularKeys[lib] = ""
        UserDefaults.standard.removeObject(forKey: "\(regularKeyPrefix)\(lib.rawValue)")
        syncWithBridge()
    }

    // MARK: - Dev Keys (各ライブラリの開発ライセンス)

    public func getDevKey(for lib: AquesTalkTargetLibrary) -> String {
        return devKeys[lib] ?? ""
    }

    public func setDevKey(_ key: String, for lib: AquesTalkTargetLibrary) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        devKeys[lib] = trimmed
        UserDefaults.standard.set(trimmed, forKey: "\(devKeyPrefix)\(lib.rawValue)")
        syncWithBridge()
    }

    public func removeDevKey(for lib: AquesTalkTargetLibrary) {
        devKeys[lib] = ""
        UserDefaults.standard.removeObject(forKey: "\(devKeyPrefix)\(lib.rawValue)")
        syncWithBridge()
    }

    // MARK: - Inclusive Dev Key (包括開発ライセンス)

    public func getInclusiveDevKey() -> String {
        return inclusiveDevKey
    }

    public func setInclusiveDevKey(_ key: String) {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        self.inclusiveDevKey = trimmed
        UserDefaults.standard.set(trimmed, forKey: "\(devKeyPrefix)包括")
        UserDefaults.standard.set(trimmed, forKey: "\(regularKeyPrefix)開発ライセンス")
        syncWithBridge()
    }

    public func removeInclusiveDevKey() {
        self.inclusiveDevKey = ""
        UserDefaults.standard.removeObject(forKey: "\(devKeyPrefix)包括")
        UserDefaults.standard.removeObject(forKey: "\(regularKeyPrefix)開発ライセンス")
        syncWithBridge()
    }

    // Backward compatibility helper
    public func getKey(for lib: AquesTalkTargetLibrary) -> String {
        return getRegularKey(for: lib)
    }

    public func setKey(_ key: String, for lib: AquesTalkTargetLibrary) {
        setRegularKey(key, for: lib)
    }

    public func removeKey(for lib: AquesTalkTargetLibrary) {
        removeRegularKey(for: lib)
    }

    // MARK: - Certification Checks

    /// Returns the effective dev key for a library (individual dev key or inclusive dev key)
    public func getEffectiveDevKey(for lib: AquesTalkTargetLibrary) -> String {
        let direct = getDevKey(for: lib)
        if !direct.isEmpty { return direct }
        return inclusiveDevKey
    }

    /// Is regular license certified?
    public func isRegularCertified(lib: AquesTalkTargetLibrary) -> Bool {
        if !getRegularKey(for: lib).isEmpty {
            return true
        }
        if lib != .commercialUse && lib != .development && !getRegularKey(for: .commercialUse).isEmpty {
            return true
        }
        return false
    }

    /// Is development license certified?
    public func isDevCertified(lib: AquesTalkTargetLibrary) -> Bool {
        if !getDevKey(for: lib).isEmpty {
            return true
        }
        if !inclusiveDevKey.isEmpty {
            return true
        }
        return false
    }

    /// Overall certification status
    public func isCertified(lib: AquesTalkTargetLibrary) -> Bool {
        if lib == .development {
            return !inclusiveDevKey.isEmpty || devKeys.values.contains { !$0.isEmpty }
        }
        return isRegularCertified(lib: lib) || isDevCertified(lib: lib)
    }

    // MARK: - Status Strings

    public func regularStatusText(for lib: AquesTalkTargetLibrary) -> String {
        if !getRegularKey(for: lib).isEmpty {
            return "認証済み（単体ライセンス適用）"
        }
        if lib != .commercialUse && lib != .development && !getRegularKey(for: .commercialUse).isEmpty {
            return "認証済み（使用ライセンスで包括適用）"
        }
        return "未認証"
    }

    public func devStatusText(for lib: AquesTalkTargetLibrary) -> String {
        if !getDevKey(for: lib).isEmpty {
            return "認証済み（個別開発ライセンス適用）"
        }
        if !inclusiveDevKey.isEmpty {
            return "認証済み（包括開発ライセンス適用）"
        }
        return "未認証"
    }

    public func licenseStatusText(for lib: AquesTalkTargetLibrary) -> String {
        if lib == .development {
            if !inclusiveDevKey.isEmpty {
                return "包括開発ライセンス適用中"
            }
            let certifiedCount = AquesTalkTargetLibrary.voiceLibraries.filter { !getDevKey(for: $0).isEmpty }.count
            if certifiedCount > 0 {
                return "\(certifiedCount)ライブラリの開発キー登録済み"
            }
            return "未認証"
        }

        let reg = isRegularCertified(lib: lib)
        let dev = isDevCertified(lib: lib)
        if reg && dev {
            return "認証済み（通常・開発ライセンス両方適用）"
        } else if dev {
            return devStatusText(for: lib)
        } else if reg {
            return regularStatusText(for: lib)
        }
        return "未認証"
    }

    // MARK: - Masked Display

    public func maskedRegularKey(for lib: AquesTalkTargetLibrary) -> String {
        let directKey = getRegularKey(for: lib)
        if !directKey.isEmpty {
            return mask(directKey)
        }
        if lib != .commercialUse && lib != .development {
            let collectiveKey = getRegularKey(for: .commercialUse)
            if !collectiveKey.isEmpty {
                return "\(mask(collectiveKey)) [使用ライセンス包括]"
            }
        }
        return "未設定"
    }

    public func maskedDevKey(for lib: AquesTalkTargetLibrary) -> String {
        let directKey = getDevKey(for: lib)
        if !directKey.isEmpty {
            return mask(directKey)
        }
        if !inclusiveDevKey.isEmpty {
            return "\(mask(inclusiveDevKey)) [包括開発キー適用]"
        }
        return "未設定"
    }

    public func maskedKey(for lib: AquesTalkTargetLibrary) -> String {
        if lib == .development {
            if !inclusiveDevKey.isEmpty {
                return "\(mask(inclusiveDevKey)) [包括開発キー]"
            }
            return "個別設定参照"
        }
        let reg = maskedRegularKey(for: lib)
        if reg != "未設定" { return reg }
        return maskedDevKey(for: lib)
    }

    public func mask(_ key: String) -> String {
        guard !key.isEmpty else { return "未設定" }
        if key.count <= 6 {
            return String(repeating: "•", count: key.count)
        }
        let prefix = key.prefix(3)
        let suffix = key.suffix(3)
        return "\(prefix)-••••-••••-\(suffix)"
    }

    // MARK: - Sync With Audio Engine Bridge

    public func syncWithBridge() {
        let aq1Dev = getEffectiveDevKey(for: .aquesTalk1)
        var aq1Usr = getRegularKey(for: .commercialUse)
        if aq1Usr.isEmpty {
            aq1Usr = getRegularKey(for: .aquesTalk1)
        }
        let kanjiDev = getEffectiveDevKey(for: .aquesTalk2KanjiKoe)

        AquesTalkBridge.shared.applyMultiKeys(
            aqDev: aq1Dev,
            aqUsr: aq1Usr,
            kanjiDev: kanjiDev
        )
    }
}
