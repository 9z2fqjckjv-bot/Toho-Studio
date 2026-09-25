import Foundation

public struct PolicyCheckResult: Identifiable, Codable {
    public var id: UUID = UUID()
    public var targetPlatform: String // "YouTube", "ニコニコ動画", "Steam", "Roblox", "Epic Games", "東方Projectガイドライン"
    public var issueCount: Int
    public var detectedWords: [String]
    public var recommendedReplacements: [String: String]
    public var isCompliant: Bool
    public var message: String
}

public final class ComplianceService: ObservableObject {
    public static let shared = ComplianceService()

    @Published public var lastCheckResults: [PolicyCheckResult] = []
    @Published public var isChecking: Bool = false

    // Dictionary of sensitive words across platforms and safe replacements
    private let sensitiveWordDictionary: [String: [String: String]] = [
        "血液・残虐表現": [
            "血だらけ": "傷だらけ",
            "大量出血": "大きなダメージ",
            "惨殺": "撃破",
            "首をはねる": "討ち倒す",
            "臓器": "核",
            "肉片": "残光"
        ],
        "暴力・脅迫表現": [
            "殺す": "やっつける",
            "皆殺し": "総力戦",
            "ぶっ殺す": "懲らしめる",
            "死ね": "消え去れ"
        ],
        "性的・不適切表現": [
            "叡智": "親密",
            "脱衣": "衣装替え",
            "露出": "開放"
        ]
    ]

    private init() {}

    /// Scans text across policy guidelines
    public func scanText(_ text: String, platforms: [String] = ["YouTube", "ニコニコ動画", "Steam", "Roblox", "Epic Games", "東方Projectガイドライン"]) -> [PolicyCheckResult] {
        var results: [PolicyCheckResult] = []

        for platform in platforms {
            var detected: [String] = []
            var replacements: [String: String] = [:]

            for (category, dict) in sensitiveWordDictionary {
                for (badWord, safeWord) in dict {
                    if text.contains(badWord) {
                        detected.append("\(badWord) [\(category)]")
                        replacements[badWord] = safeWord
                    }
                }
            }

            // Platform-specific rules
            if platform == "Roblox" && (text.contains("課金") || text.contains("ギャンブル")) {
                detected.append("外部決済・不適切表現 [Robloxポリシー]")
                replacements["課金"] = "ゲーム内アイテム取得"
            }

            let isOk = detected.isEmpty
            let msg = isOk ?
                "\(platform)の最新ポリシーに完全に適合しています。" :
                "\(platform)のポリシーに抵触する可能性がある表現が\(detected.count)件検出されました。"

            results.append(PolicyCheckResult(
                targetPlatform: platform,
                issueCount: detected.count,
                detectedWords: detected,
                recommendedReplacements: replacements,
                isCompliant: isOk,
                message: msg
            ))
        }

        self.lastCheckResults = results
        return results
    }

    /// Automatically replaces detected words in text with safe terms
    public func sanitizeText(_ text: String) -> String {
        var sanitized = text
        for (_, dict) in sensitiveWordDictionary {
            for (badWord, safeWord) in dict {
                sanitized = sanitized.replacingOccurrences(of: badWord, with: safeWord)
            }
        }
        return sanitized
    }
}
