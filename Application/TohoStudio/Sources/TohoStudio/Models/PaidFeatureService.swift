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
        if isFreeDefaultPlan { return true }
        return userValue.lowercased() == "on" || (Int(userValue) ?? 0) > 0
    }
    public var isFreeDefaultPlan: Bool {
        return (planName == "0" && csvFileName.contains("対応拡張子の追加")) || defaultValue.lowercased() == "on"
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
            self.syncWithAppState()
        }
    }

    /// Synchronizes loaded CSV statuses with AppState properties
    public func syncWithAppState() {
        let appState = AppState.shared

        // 1. Extension Plan
        let extItems = featureItems.filter { $0.csvFileName.contains("対応拡張子") }
        if extItems.first(where: { $0.planName == "300" && $0.isEnabledByUser }) != nil {
            appState.extensionPlan = "300円プラン (全形式解放)"
        } else if extItems.first(where: { $0.planName == "200" && $0.isEnabledByUser }) != nil {
            appState.extensionPlan = "200円プラン"
        } else if extItems.first(where: { $0.planName == "100" && $0.isEnabledByUser }) != nil {
            appState.extensionPlan = "100円プラン"
        } else {
            appState.extensionPlan = "無料プラン (標準形式のみ)"
        }

        // 2. Advertising Free Hours
        var totalAdHours = 0
        for item in featureItems where item.csvFileName.contains("広告") {
            if let hours = Int(item.userValue), hours > 0 {
                totalAdHours += hours
            }
        }
        appState.adFreeRemainingHours = totalAdHours

        // 3. Backup and Sync Plan
        let backupActive = featureItems.contains { item in
            (item.csvFileName.contains("バックアップ") || item.csvFileName.contains("同期")) &&
            (item.userValue.lowercased() == "on" || (Int(item.userValue) ?? 0) > 0)
        }
        appState.backupSyncPlanActive = backupActive

        // 4. AI Plan Remaining Prompts
        let aiItems = featureItems.filter { $0.csvFileName.contains("定額式プラン") }
        if let highest = aiItems.filter({ $0.isEnabledByUser }).sorted(by: { (Int($0.planName) ?? 0) > (Int($1.planName) ?? 0) }).first {
            switch highest.planName {
            case "10000": appState.aiPlanRemainingPrompts = 50000
            case "5000": appState.aiPlanRemainingPrompts = 20000
            case "3000": appState.aiPlanRemainingPrompts = 10000
            case "2000": appState.aiPlanRemainingPrompts = 5000
            case "1000": appState.aiPlanRemainingPrompts = 2500
            default: appState.aiPlanRemainingPrompts = 1000
            }
        } else {
            appState.aiPlanRemainingPrompts = 0
        }

        // 5. Unlocked Extensions
        var unlocked: [String] = []
        for item in featureItems where item.csvFileName.contains("アプリ拡張") && item.isEnabledByUser {
            unlocked.append(item.planName)
        }
        if !unlocked.isEmpty {
            appState.unlockedExtensions = unlocked
        }
    }

    // MARK: - CSV Parsing for all 4 schema variants
    private func parsePaidCSV(filePath: String, fileName: String) -> [PaidFeatureItem] {
        guard let content = try? String(contentsOfFile: filePath, encoding: .utf8) else {
            return []
        }

        let rawRows = parseCSVToRows(content)
        guard rawRows.count >= 2 else { return [] }

        let categoryTitle = rawRows[0].first?.trimmingCharacters(in: .whitespacesAndNewlines) ?? fileName.replacingOccurrences(of: ".csv", with: "")

        // Check if format is Columnar (Tickets: Advertising, Backup, Sync)
        if rawRows.count >= 3 && rawRows[1].count > 1 && rawRows[1][0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "data-label" {
            return parseColumnarTicketCSV(rows: rawRows, categoryTitle: categoryTitle, fileName: fileName)
        }

        // Check if format is Row-Based with 6 columns (AI Pay-As-You-Go: Seller,Model,Data-Type,Default,User,Selling)
        if rawRows.count >= 2 && rawRows[1].count >= 6 && rawRows[1][0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "seller" {
            return parsePayAsYouGoCSV(rows: rawRows, categoryTitle: categoryTitle, fileName: fileName)
        }

        // Check if format is Row-Based with 6 columns (Super Bundle: Plan,Info,Data-Type,Default,User,Selling)
        if rawRows.count >= 2 && rawRows[1].count >= 6 && rawRows[1][1].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "info" {
            return parseSuperBundleCSV(rows: rawRows, categoryTitle: categoryTitle, fileName: fileName)
        }

        // Standard 5-Column Row-Based (AI Flat Rate, App Extensions, Extensions Status)
        return parseStandardRowCSV(rows: rawRows, categoryTitle: categoryTitle, fileName: fileName)
    }

    /// Parses CSV text respecting quoted multi-line fields
    private func parseCSVToRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var inQuotes = false

        let chars = Array(text)
        var i = 0
        while i < chars.count {
            let c = chars[i]
            if c == "\"" {
                if inQuotes && i + 1 < chars.count && chars[i + 1] == "\"" {
                    currentField.append("\"")
                    i += 1
                } else {
                    inQuotes.toggle()
                }
            } else if c == "," && !inQuotes {
                currentRow.append(currentField)
                currentField = ""
            } else if (c == "\r" || c == "\n") && !inQuotes {
                if c == "\r" && i + 1 < chars.count && chars[i + 1] == "\n" {
                    i += 1
                }
                currentRow.append(currentField)
                currentField = ""
                if !currentRow.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                    rows.append(currentRow)
                }
                currentRow = []
            } else {
                currentField.append(c)
            }
            i += 1
        }
        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            if !currentRow.allSatisfy({ $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
                rows.append(currentRow)
            }
        }
        return rows
    }

    // MARK: - Schema Parser 1: Columnar Ticket Format
    private func parseColumnarTicketCSV(rows: [[String]], categoryTitle: String, fileName: String) -> [PaidFeatureItem] {
        var items: [PaidFeatureItem] = []
        let headerRow = rows[1] // Data-Label,時間券,日券,週間券,月間券,年間券,Tatal

        var sellingRow: [String] = []
        var dataTypeRow: [String] = []
        var defaultRow: [String] = []
        var userRow: [String] = []

        for row in rows.dropFirst(2) {
            guard let label = row.first?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else { continue }
            if label == "selling" { sellingRow = row }
            else if label == "data-type" { dataTypeRow = row }
            else if label == "default" { defaultRow = row }
            else if label == "user" { userRow = row }
        }

        let catClean = categoryTitle.replacingOccurrences(of: "（フリー券の購入ボタン）", with: "")
            .replacingOccurrences(of: "（サービス利用券の購入ボタン）", with: "")

        for colIdx in 1..<headerRow.count {
            let planName = headerRow[colIdx].trimmingCharacters(in: .whitespacesAndNewlines)
            if planName.isEmpty || planName.lowercased().contains("tatal") || planName.lowercased().contains("total") {
                continue
            }

            let selling = colIdx < sellingRow.count ? sellingRow[colIdx].trimmingCharacters(in: .whitespacesAndNewlines) : "no"
            let dataType = colIdx < dataTypeRow.count ? dataTypeRow[colIdx].trimmingCharacters(in: .whitespacesAndNewlines) : "Number"
            let def = colIdx < defaultRow.count ? defaultRow[colIdx].trimmingCharacters(in: .whitespacesAndNewlines) : "0"
            let user = colIdx < userRow.count ? userRow[colIdx].trimmingCharacters(in: .whitespacesAndNewlines) : "0"

            let price = getTicketPriceDescription(plan: planName, fileName: fileName)
            let details = "\(catClean) - \(planName) (現在残高: \(user))"

            let item = PaidFeatureItem(
                csvFileName: fileName,
                category: catClean,
                planName: planName,
                dataType: dataType,
                defaultValue: def,
                userValue: user,
                sellingStatus: selling,
                priceDescription: price,
                details: details
            )
            items.append(item)
        }
        return items
    }

    // MARK: - Schema Parser 2: AI Pay-As-You-Go Format (6 cols)
    private func parsePayAsYouGoCSV(rows: [[String]], categoryTitle: String, fileName: String) -> [PaidFeatureItem] {
        var items: [PaidFeatureItem] = []
        for row in rows.dropFirst(2) {
            if row.count < 6 { continue }
            let seller = row[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let model = row[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if seller.contains("Info") || seller.contains("注意事項") || seller.contains("Warning") || seller.contains("不正") {
                continue
            }
            let dataType = row[2].trimmingCharacters(in: .whitespacesAndNewlines)
            let def = row[3].trimmingCharacters(in: .whitespacesAndNewlines)
            let user = row[4].trimmingCharacters(in: .whitespacesAndNewlines)
            let selling = row[5].trimmingCharacters(in: .whitespacesAndNewlines)

            let planName = "\(model) (\(seller))"
            let price = "従量制クレジット課金 (実費チャージ式)"
            let details = "\(seller)社 \(model)モデルを活用した高精度AI生成・検索連携機能"

            let item = PaidFeatureItem(
                csvFileName: fileName,
                category: "AI機能(都度課金)",
                planName: planName,
                dataType: dataType,
                defaultValue: def,
                userValue: user,
                sellingStatus: selling,
                priceDescription: price,
                details: details
            )
            items.append(item)
        }
        return items
    }

    // MARK: - Schema Parser 3: Super Bundle Format (6 cols with Info)
    private func parseSuperBundleCSV(rows: [[String]], categoryTitle: String, fileName: String) -> [PaidFeatureItem] {
        var items: [PaidFeatureItem] = []
        for row in rows.dropFirst(2) {
            if row.count < 6 { continue }
            let plan = row[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let info = row[1].trimmingCharacters(in: .whitespacesAndNewlines)
            if plan.contains("Info") || plan.contains("注意事項") || plan.contains("Warning") || plan.contains("不正") {
                continue
            }
            let dataType = row[2].trimmingCharacters(in: .whitespacesAndNewlines)
            let def = row[3].trimmingCharacters(in: .whitespacesAndNewlines)
            let user = row[4].trimmingCharacters(in: .whitespacesAndNewlines)
            let selling = row[5].trimmingCharacters(in: .whitespacesAndNewlines)

            let price = getSuperBundlePriceDescription(plan: plan)
            let details = info.isEmpty ? "\(categoryTitle) - \(plan)" : info

            let item = PaidFeatureItem(
                csvFileName: fileName,
                category: "アプリ拡張(スーパーバンドル)",
                planName: plan.replacingOccurrences(of: "\n", with: " "),
                dataType: dataType,
                defaultValue: def,
                userValue: user,
                sellingStatus: selling,
                priceDescription: price,
                details: details
            )
            items.append(item)
        }
        return items
    }

    // MARK: - Schema Parser 4: Standard 5-Column Row-Based Format
    private func parseStandardRowCSV(rows: [[String]], categoryTitle: String, fileName: String) -> [PaidFeatureItem] {
        var items: [PaidFeatureItem] = []
        for row in rows.dropFirst(2) {
            if row.count < 5 { continue }
            let plan = row[0].trimmingCharacters(in: .whitespacesAndNewlines)
            if plan.contains("Info") || plan.contains("注意事項") || plan.contains("Warning") || plan.contains("不正") {
                continue
            }
            let dataType = row[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let def = row[2].trimmingCharacters(in: .whitespacesAndNewlines)
            let user = row[3].trimmingCharacters(in: .whitespacesAndNewlines)
            let selling = row[4].trimmingCharacters(in: .whitespacesAndNewlines)

            let cat = categoryTitle.isEmpty ? fileName.replacingOccurrences(of: ".csv", with: "") : categoryTitle
            let price = getPriceDescription(category: cat, plan: plan, fileName: fileName)
            let details = getPlanDetails(category: cat, plan: plan, fileName: fileName)

            let item = PaidFeatureItem(
                csvFileName: fileName,
                category: cat,
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
        return items
    }

    // MARK: - Helper descriptions
    private func getTicketPriceDescription(plan: String, fileName: String) -> String {
        let isBulk = fileName.contains("3種類広告まとめて")
        switch plan {
        case "時間券": return isBulk ? "¥250 / 1時間" : "¥100 / 1時間"
        case "日券": return isBulk ? "¥750 / 24時間" : "¥300 / 24時間"
        case "週間券": return isBulk ? "¥2,500 / 7日間" : "¥1,000 / 7日間"
        case "月間券": return isBulk ? "¥6,250 / 30日間" : "¥2,500 / 30日間"
        case "年間券": return isBulk ? "¥20,000 / 実質無期限" : "¥10,000 / 実質無期限"
        default: return "¥300"
        }
    }

    private func getSuperBundlePriceDescription(plan: String) -> String {
        let clean = plan.lowercased()
        if clean.contains("all-in-one") { return "¥20,000/月 (全機能完全バンドル)" }
        if clean.contains("ai") { return "¥15,000/月 (全拡張+AI最強)" }
        if clean.contains("advertising") { return "¥16,000/月 (全拡張+全広告フリー)" }
        if clean.contains("unlimited pass") { return "¥12,000/月 (全拡張+バックアップ同期)" }
        if clean.contains("file extension") { return "¥8,150/月 (全拡張+全拡張子)" }
        return "¥8,000/月 (4ソフト拡張バンドル)"
    }

    private func getPriceDescription(category: String, plan: String, fileName: String) -> String {
        if fileName.contains("定額式プラン") {
            if plan == "0" { return "無料 (月1,000プロンプト・広告付)" }
            return "¥\(plan)/月 (月換算プロンプト枠拡大)"
        } else if fileName.contains("対応拡張子の追加") {
            if plan.contains("Free") || plan == "0" { return "無料 (標準形式)" }
            return "月額 ¥\(plan) プラン"
        } else if fileName.contains("アプリ拡張") {
            if plan.lowercased().contains("bundle") { return "¥980/月 (ソフト個別バンドル)" }
            return "¥380/月"
        }
        return "有料オプション"
    }

    private func getPlanDetails(category: String, plan: String, fileName: String) -> String {
        if fileName.contains("定額式プラン") {
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
            case "0": return "無料標準対応: mp4, ymmp, gvid, jpg, gdraw, mp3"
            case "100": return "100円プラン追加: mov, png, wav"
            case "200": return "200円プラン追加: svg, m4a, aac, aif"
            case "300": return "300円プラン追加: fcpbundle, prproj, pxd, psd, logicx, sesx"
            default: return "拡張子対応設定"
            }
        } else if fileName.contains("アプリ拡張") {
            return "\(category) 専門拡張機能 (\(plan))"
        }
        return "\(category) - \(plan)"
    }

    // MARK: - Safe Toggle & Purchase Execution
    public func purchaseOrToggleFeature(item: PaidFeatureItem, completion: @escaping (Bool, String) -> Void) {
        let appState = AppState.shared

        // Free default plans can be toggled or kept on without restrictions
        if item.isFreeDefaultPlan {
            let newStatus = item.isEnabledByUser ? "off" : "on"
            let success = updateCSVUserStatus(fileName: item.csvFileName, planName: item.planName, newUserStatus: newStatus)
            if success {
                loadAllPaidCSVs()
                if ResourceIntegrityProtectionService.shared.isDeveloperMachine {
                    ResourceIntegrityProtectionService.shared.generateBaselineManifest()
                }
                completion(true, "\(item.planName) の設定を更新しました (\(newStatus))。")
            } else {
                completion(false, "設定の更新に失敗しました。")
            }
            return
        }

        // For paid features: Selling == "no" plans are suspended from sale
        if !item.isAvailableForPurchase {
            completion(false, "“\(item.planName)” は現在販売休止中のため、設定はオフに固定されています。（仕様書補足事項規定）")
            return
        }

        // Strict NanndemoyaCloud authentication check for active paid purchases
        guard appState.isLoggedIn && appState.currentAccountType == "NanndemoyaCloud" else {
            ResourceIntegrityProtectionService.shared.triggerTamperBlock(
                reason: "NanndemoyaCloudの正規認証および利用端末登録を経由しない不正な有料機能アクセスが検知されました。",
                filePath: item.csvFileName,
                details: "Unauthorized access without registered NanndemoyaCloud credentials"
            )
            completion(false, "有料機能の利用にはNanndemoyaCloudのアカウント認証と端末登録が必須です。")
            return
        }

        let newStatus = item.isEnabledByUser ? "off" : "on"
        let success = updateCSVUserStatus(fileName: item.csvFileName, planName: item.planName, newUserStatus: newStatus)

        if success {
            loadAllPaidCSVs()
            if ResourceIntegrityProtectionService.shared.isDeveloperMachine {
                ResourceIntegrityProtectionService.shared.generateBaselineManifest()
            }
            completion(true, "\(item.planName) の設定を更新しました (\(newStatus))。")
        } else {
            completion(false, "CSV設定の更新に失敗しました。")
        }
    }

    /// Updates the user status in the corresponding CSV file according to its format
    public func updateCSVUserStatus(fileName: String, planName: String, newUserStatus: String) -> Bool {
        let fullPath = "\(paidDir)/\(fileName)"
        guard let content = try? String(contentsOfFile: fullPath, encoding: .utf8) else {
            return false
        }

        let rawRows = parseCSVToRows(content)
        guard rawRows.count >= 2 else { return false }

        var modifiedRows = rawRows
        var updated = false

        // Case A: Columnar Ticket Format
        if rawRows.count >= 3 && rawRows[1].count > 1 && rawRows[1][0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "data-label" {
            let header = rawRows[1]
            if let colIdx = header.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines) == planName }) {
                for (rowIdx, row) in rawRows.enumerated() {
                    if let label = row.first?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(), label == "user" {
                        if colIdx < modifiedRows[rowIdx].count {
                            modifiedRows[rowIdx][colIdx] = newUserStatus
                            updated = true
                            break
                        }
                    }
                }
            }
        }
        // Case B: AI Pay-As-You-Go (6 cols: Seller,Model,Data-Type,Default,User,Selling)
        else if rawRows.count >= 2 && rawRows[1].count >= 6 && rawRows[1][0].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "seller" {
            for (rowIdx, row) in rawRows.enumerated().dropFirst(2) {
                if row.count >= 6 {
                    let model = row[1].trimmingCharacters(in: .whitespacesAndNewlines)
                    let full = "\(model) (\(row[0].trimmingCharacters(in: .whitespacesAndNewlines)))"
                    if model == planName || full == planName {
                        modifiedRows[rowIdx][4] = newUserStatus
                        updated = true
                        break
                    }
                }
            }
        }
        // Case C: Super Bundle (6 cols: Plan,Info,Data-Type,Default,User,Selling)
        else if rawRows.count >= 2 && rawRows[1].count >= 6 && rawRows[1][1].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "info" {
            for (rowIdx, row) in rawRows.enumerated().dropFirst(2) {
                if row.count >= 6 {
                    let plan = row[0].trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "\n", with: " ")
                    if plan == planName || row[0].trimmingCharacters(in: .whitespacesAndNewlines) == planName {
                        modifiedRows[rowIdx][4] = newUserStatus
                        updated = true
                        break
                    }
                }
            }
        }
        // Case D: Standard 5-Column Row Format
        else {
            for (rowIdx, row) in rawRows.enumerated().dropFirst(2) {
                if row.count >= 5 {
                    let plan = row[0].trimmingCharacters(in: .whitespacesAndNewlines)
                    if plan == planName {
                        modifiedRows[rowIdx][3] = newUserStatus
                        updated = true
                        break
                    }
                }
            }
        }

        if updated {
            let serialized = serializeRowsToCSV(modifiedRows)
            do {
                try serialized.write(to: URL(fileURLWithPath: fullPath), atomically: true, encoding: .utf8)
                return true
            } catch {
                print("Failed to write CSV: \(error)")
                return false
            }
        }
        return false
    }

    private func serializeRowsToCSV(_ rows: [[String]]) -> String {
        return rows.map { row in
            row.map { field in
                if field.contains(",") || field.contains("\"") || field.contains("\n") {
                    let escaped = field.replacingOccurrences(of: "\"", with: "\"\"")
                    return "\"\(escaped)\""
                }
                return field
            }.joined(separator: ",")
        }.joined(separator: "\n")
    }

    // MARK: - Query APIs for Feature Availability across App
    public func isFeatureEnabled(category: String, plan: String) -> Bool {
        if let item = featureItems.first(where: {
            $0.category.contains(category) && ($0.planName == plan || $0.planName.contains(plan))
        }) {
            return item.isEnabledByUser
        }
        return false
    }

    public func isExtensionAllowed(_ ext: String) -> Bool {
        let clean = ext.replacingOccurrences(of: ".", with: "").lowercased()
        let defaultExts = ["mp4", "ymmp", "gvid", "jpg", "gdraw", "mp3", "tsvm", "tssm", "tscm", "tspm", "tsgm"]
        if defaultExts.contains(clean) { return true }

        let p100Exts = ["mov", "png", "wav"]
        let p200Exts = ["svg", "m4a", "aac", "aif"]

        let extItems = featureItems.filter { $0.csvFileName.contains("対応拡張子") }
        let p100Active = extItems.first(where: { $0.planName == "100" })?.isEnabledByUser ?? false
        let p200Active = extItems.first(where: { $0.planName == "200" })?.isEnabledByUser ?? false
        let p300Active = extItems.first(where: { $0.planName == "300" })?.isEnabledByUser ?? false

        if p300Active { return true }
        if p200Active && (defaultExts.contains(clean) || p100Exts.contains(clean) || p200Exts.contains(clean)) { return true }
        if p100Active && (defaultExts.contains(clean) || p100Exts.contains(clean)) { return true }

        return false
    }

    public func isAdFree(type: String) -> Bool {
        // Bulk pass checks
        if featureItems.contains(where: { $0.csvFileName.contains("3種類広告まとめて") && $0.isEnabledByUser }) {
            return true
        }
        // Specific pass check
        if featureItems.contains(where: { $0.csvFileName.contains(type) && $0.isEnabledByUser }) {
            return true
        }
        return false
    }

    public func isBackupSyncAllowed() -> Bool {
        let backup = featureItems.first(where: { $0.csvFileName.contains("バックアップ") && $0.isEnabledByUser }) != nil
        let sync = featureItems.first(where: { $0.csvFileName.contains("同期") && $0.isEnabledByUser }) != nil
        return backup || sync
    }
}
