import Foundation
import SwiftUI

public struct PaidFeatureItem: Identifiable, Codable {
    public var id: String { "\(csvFileName)_\(planName)" }
    public let csvFileName: String
    public let category: String
    public let planName: String
    public let dataType: String
    public let defaultValue: String
    public var userValue: String
    public let sellingStatus: String
    public var isAvailableForPurchase: Bool {
        return sellingStatus.lowercased() == "yes" || sellingStatus.lowercased() == "on"
    }
    public var isEnabledByUser: Bool {
        return userValue.lowercased() == "on"
    }
    public var priceDescription: String
    public var details: String
}

public final class PaidFeatureService: ObservableObject {
    public static let shared = PaidFeatureService()

    public let paidDir = "/Volumes/ZSSD/GitHub/repository/TohoStudio/Application/Resource/Other/Info/Settings/Paid"

    @Published public var featureItems: [PaidFeatureItem] = []
    @Published public var categories: [String] = []
    @Published public var isLoading: Bool = false
    @Published public var lastLoadedAt: Date? = nil

    private init() {
        loadAllPaidCSVs()
    }

    /// Reads and parses all CSV files in the Paid directory
    public func loadAllPaidCSVs() {
        isLoading = true
        let fm = FileManager.default
        guard fm.fileExists(atPath: paidDir) else {
            isLoading = false
            return
        }

        var items: [PaidFeatureItem] = []
        var foundCategories: Set<String> = []

        if let enumerator = fm.enumerator(atPath: paidDir) {
            while let fileName = enumerator.nextObject() as? String {
                if fileName.hasSuffix(".csv") {
                    let fullPath = "\(paidDir)/\(fileName)"
                    let parsed = parsePaidCSV(filePath: fullPath, fileName: fileName)
                    items.append(contentsOf: parsed)
                    for p in parsed {
                        foundCategories.insert(p.category)
                    }
                }
            }
        }

        // Sort items by category and name
        items.sort { ($0.category, $0.planName) < ($1.category, $1.planName) }

        DispatchQueue.main.async {
            self.featureItems = items
            self.categories = Array(foundCategories).sorted()
            self.isLoading = false
            self.lastLoadedAt = Date()
        }
    }

    private func parsePaidCSV(filePath: String, fileName: String) -> [PaidFeatureItem] {
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return []
        }

        var items: [PaidFeatureItem] = []
        let lines = content.components(separatedBy: "\n")
        guard lines.count >= 2 else { return [] }

        let category = lines[0].trimmingCharacters(in: .whitespacesAndNewlines)

        var notes: String = ""
        var warnings: String = ""

        // Extract notes and warnings
        for line in lines {
            if line.contains("注意事項") || line.contains("Info") {
                notes += line + " "
            }
            if line.contains("不正に関するご注意事項") || line.contains("Warning regarding unauthorized actions") {
                warnings += line + " "
            }
        }

        for (idx, line) in lines.enumerated() {
            if idx < 2 { continue } // Skip category line and header
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { continue }

            let cols = parseCSVRow(trimmed)
            if cols.count >= 5 {
                let plan = cols[0].trimmingCharacters(in: .whitespacesAndNewlines)
                if plan.contains("Info") || plan.contains("注意事項") || plan.contains("Warning") || plan.contains("不正") {
                    continue
                }
                let dataType = cols[1].trimmingCharacters(in: .whitespacesAndNewlines)
                let def = cols[2].trimmingCharacters(in: .whitespacesAndNewlines)
                let user = cols[3].trimmingCharacters(in: .whitespacesAndNewlines)
                let selling = cols[4].trimmingCharacters(in: .whitespacesAndNewlines)

                let price = getPriceDescription(category: category, plan: plan, fileName: fileName)
                let details = getPlanDetails(category: category, plan: plan, fileName: fileName)

                let item = PaidFeatureItem(
                    csvFileName: fileName,
                    category: category.isEmpty ? fileName.replacingOccurrences(of: ".csv", with: "") : category,
                    planName: plan,
                    dataType: dataType,
                    defaultValue: def,
                    userValue: user,
                    sellingStatus: selling,
                    priceDescription: price,
                    details: details
                )
                items.append(item)
            }
        }

        return items
    }

    private func parseCSVRow(_ row: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false

        for char in row {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current)
        return result
    }

    private func getPriceDescription(category: String, plan: String, fileName: String) -> String {
        if fileName.contains("定額式プラン") {
            if plan == "0" { return "無料 (月1,000プロンプト・広告付)" }
            return "¥\(plan)/月 (月換算プロンプト枠拡大)"
        } else if fileName.contains("都度課金式プラン") {
            return "従量制クレジット課金 (API実費)"
        } else if fileName.contains("対応拡張子の追加") {
            if plan.contains("Free") || plan == "0" { return "無料" }
            return "¥\(plan) プラン"
        } else if fileName.contains("アプリ拡張") {
            if plan.lowercased().contains("bundle") { return "¥980/月 (一括バンドル)" }
            return "¥380/月"
        } else if fileName.contains("広告") {
            if fileName.contains("まとめて") { return "¥500/月 (全3種広告フリー)" }
            return "¥200/月"
        } else if fileName.contains("バックアップ") || fileName.contains("同期") {
            return "¥300/月"
        }
        return "有料オプション"
    }

    private func getPlanDetails(category: String, plan: String, fileName: String) -> String {
        if fileName.contains("定額式プラン") {
            switch plan {
            case "0": return "標準無料プラン: お試し広告視聴で1プロンプト追加利用可能"
            case "1000": return "2,500プロンプト/月 (無料比2.5倍、広告なし利用)"
            case "2000": return "5,000プロンプト/月 (無料比5倍、広告なし利用)"
            case "3000": return "10,000プロンプト/月 (無料比10倍、広告なし利用)"
            case "5000": return "20,000プロンプト/月 (無料比20倍、広告なし利用)"
            case "10000": return "50,000プロンプト/月 (最高峰プラン、広告なし利用)"
            default: return "AIプロンプトベース定額プラン"
            }
        } else if fileName.contains("対応拡張子の追加") {
            switch plan {
            case "100": return "ムービー: mov / キャラクター: png / サウンド: wav"
            case "200": return "キャラクター: svg / サウンド: m4a, aac, aif"
            case "300": return "ムービー: fcpbundle, prproj / キャラクター: pxd, psd / サウンド: logicx, sesx"
            default: return "デフォルト拡張子: mp4, ymmp, gvid, jpg, gdraw, mp3"
            }
        }
        return "\(category) - \(plan)"
    }

    /// Attempts to toggle or purchase a paid feature, requiring strict NanndemoyaCloud authentication
    public func purchaseOrToggleFeature(item: PaidFeatureItem, completion: @escaping (Bool, String) -> Void) {
        // 1. Verify NanndemoyaCloud authentication & Registered Device
        let appState = AppState.shared
        guard appState.isLoggedIn && appState.currentAccountType == "NanndemoyaCloud" else {
            // Unauthorized bypass attempt -> Block application
            ResourceIntegrityProtectionService.shared.triggerTamperBlock(
                reason: "NanndemoyaCloudの正規認証および利用端末登録を経由しない不正な有料機能アクセスが検知されました。",
                filePath: item.csvFileName,
                details: "Unauthorized access without registered NanndemoyaCloud credentials"
            )
            completion(false, "有料機能の利用にはNanndemoyaCloudのアカウント認証と端末登録が必須です。")
            return
        }

        guard item.isAvailableForPurchase else {
            completion(false, "現在このプランは販売休止中のため購入・有効化できません。")
            return
        }

        // Toggle user state and persist in CSV atomically through authorized app mechanism
        let newStatus = item.isEnabledByUser ? "off" : "on"
        let success = updateCSVUserStatus(fileName: item.csvFileName, planName: item.planName, newUserStatus: newStatus)

        if success {
            loadAllPaidCSVs()
            // Re-generate integrity baseline on developer mac
            if ResourceIntegrityProtectionService.shared.isDeveloperMachine {
                ResourceIntegrityProtectionService.shared.generateBaselineManifest()
            }
            completion(true, "\(item.planName) の設定を更新しました (\(newStatus))。")
        } else {
            completion(false, "CSV設定の更新に失敗しました。")
        }
    }

    private func updateCSVUserStatus(fileName: String, planName: String, newUserStatus: String) -> Bool {
        let fullPath = "\(paidDir)/\(fileName)"
        guard let content = try? String(contentsOfFile: fullPath, encoding: .utf8) else {
            return false
        }

        var lines = content.components(separatedBy: "\n")
        var updated = false

        for (idx, line) in lines.enumerated() {
            var cols = line.components(separatedBy: ",")
            if cols.count >= 5 {
                let plan = cols[0].trimmingCharacters(in: .whitespacesAndNewlines)
                if plan == planName {
                    cols[3] = newUserStatus
                    lines[idx] = cols.joined(separator: ",")
                    updated = true
                    break
                }
            }
        }

        if updated {
            let newContent = lines.joined(separator: "\n")
            do {
                try newContent.write(to: URL(fileURLWithPath: fullPath), atomically: true, encoding: .utf8)
                return true
            } catch {
                print("Failed to write CSV: \(error)")
                return false
            }
        }
        return false
    }
}
