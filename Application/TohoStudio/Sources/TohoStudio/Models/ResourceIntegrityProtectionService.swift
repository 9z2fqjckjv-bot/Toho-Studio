import Foundation
import CryptoKit
import AppKit
import IOKit

public struct FileIntegrityRecord: Codable {
    public let relativePath: String
    public let sha256: String
    public let fileSize: Int64
    public let lastModified: Date
}

public struct TamperIncidentReport: Identifiable, Codable {
    public var id: UUID = UUID()
    public var timestamp: Date = Date()
    public var reason: String
    public var affectedFilePath: String
    public var detectedDetails: String
    public var deviceUUID: String
}

public final class ResourceIntegrityProtectionService: ObservableObject {
    public static let shared = ResourceIntegrityProtectionService()

    /// Authorized Developer Machine Hardware UUID
    public let developerMachineUUID = "3A659115-4453-5944-9084-B0C46DB9040A"

    public let resourceRootPath = "/Volumes/ZSSD/GitHub/repository/TohoStudio/Application/Resource"
    public var manifestPath: String {
        return "\(resourceRootPath)/Other/Info/Settings/integrity_manifest.json"
    }
    public var blockLockFilePath: String {
        return "\(resourceRootPath)/Other/Info/Settings/.tamper_block.lock"
    }

    @Published public var isBlocked: Bool = false
    @Published public var currentIncident: TamperIncidentReport? = nil
    @Published public var isDeveloperMachine: Bool = false
    @Published public var verifiedFilesCount: Int = 0

    private init() {
        checkCurrentMachineIdentity()
        // Check if previously locked by tamper
        if FileManager.default.fileExists(atPath: blockLockFilePath) {
            self.isBlocked = true
            loadIncidentReport()
        }
    }

    /// Verifies if the current running Mac is the registered developer's Mac
    public func checkCurrentMachineIdentity() {
        let currentUUID = getMachineHardwareUUID()
        self.isDeveloperMachine = (currentUUID == developerMachineUUID)
    }

    /// Fetches IOPlatformUUID of the host Mac using native IOKit (thread-safe, zero subprocess re-entrancy)
    public static func getMachineHardwareUUID() -> String {
        let platformExpert = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPlatformExpertDevice"))
        if platformExpert != 0 {
            defer { IOObjectRelease(platformExpert) }
            if let property = IORegistryEntryCreateCFProperty(platformExpert, kIOPlatformUUIDKey as CFString, kCFAllocatorDefault, 0) {
                if let uuid = property.takeRetainedValue() as? String {
                    let cleaned = uuid.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleaned.isEmpty {
                        return cleaned
                    }
                }
            }
        }
        return "UNKNOWN_DEVICE"
    }

    public func getMachineHardwareUUID() -> String {
        return Self.getMachineHardwareUUID()
    }

    /// Calculates SHA256 of a local file
    public func calculateSHA256(for filePath: String) -> String? {
        guard let fileData = try? Data(contentsOf: URL(fileURLWithPath: filePath)) else {
            return nil
        }
        let digest = SHA256.hash(data: fileData)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    /// Generates and signs initial baseline manifest (authorized on Developer Mac)
    public func generateBaselineManifest() {
        guard isDeveloperMachine else {
            print("Permission denied: Baseline manifest can only be generated from Developer Mac.")
            return
        }

        let fm = FileManager.default
        guard fm.fileExists(atPath: resourceRootPath) else { return }

        var records: [FileIntegrityRecord] = []
        if let enumerator = fm.enumerator(atPath: resourceRootPath) {
            while let relative = enumerator.nextObject() as? String {
                if relative.hasPrefix(".") || relative.contains(".DS_Store") || relative.contains("integrity_manifest.json") || relative.contains(".tamper_block.lock") {
                    continue
                }
                let fullPath = "\(resourceRootPath)/\(relative)"
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: fullPath, isDirectory: &isDir), !isDir.boolValue {
                    if let sha = calculateSHA256(for: fullPath),
                       let attrs = try? fm.attributesOfItem(atPath: fullPath),
                       let size = attrs[.size] as? Int64,
                       let modDate = attrs[.modificationDate] as? Date {
                        records.append(FileIntegrityRecord(relativePath: relative, sha256: sha, fileSize: size, lastModified: modDate))
                    }
                }
            }
        }

        if let jsonData = try? JSONEncoder().encode(records) {
            try? jsonData.write(to: URL(fileURLWithPath: manifestPath), options: .atomic)
            print("Integrity baseline manifest successfully written: \(records.count) files recorded.")
        }
    }

    /// Audits all files in Resource, especially Paid CSVs and scripts
    public func verifyIntegrity() -> Bool {
        checkCurrentMachineIdentity()

        let fm = FileManager.default
        guard fm.fileExists(atPath: resourceRootPath) else { return true }

        // If manifest doesn't exist yet and we are on developer Mac, initialize it
        if !fm.fileExists(atPath: manifestPath) {
            if isDeveloperMachine {
                generateBaselineManifest()
                return true
            } else {
                triggerTamperBlock(reason: "セキュリティ整合性マニフェストが存在しません。リソースの不正削除または改竄の疑いがあります。", filePath: manifestPath, details: "Manifest missing")
                return false
            }
        }

        guard let manifestData = try? Data(contentsOf: URL(fileURLWithPath: manifestPath)),
              let records = try? JSONDecoder().decode([FileIntegrityRecord].self, from: manifestData) else {
            triggerTamperBlock(reason: "整合性マニフェストの破損が検知されました。", filePath: manifestPath, details: "Invalid manifest format")
            return false
        }

        var verified = 0
        for record in records {
            let fullPath = "\(resourceRootPath)/\(record.relativePath)"
            if !fm.fileExists(atPath: fullPath) {
                triggerTamperBlock(reason: "Resource内の保護されたファイルが削除または移動されています。", filePath: record.relativePath, details: "File missing: \(record.relativePath)")
                return false
            }

            guard let currentSHA = calculateSHA256(for: fullPath) else {
                triggerTamperBlock(reason: "ファイルの読み込み検証に失敗しました。", filePath: record.relativePath, details: "Unreadable file")
                return false
            }

            if currentSHA != record.sha256 {
                // Check if Paid CSV was modified directly outside application
                if record.relativePath.contains("Settings/Paid") {
                    triggerTamperBlock(
                        reason: "利用者が有料機能管理CSVファイル[\(record.relativePath)]を直接編集・改変した不正行為を検知しました。",
                        filePath: record.relativePath,
                        details: "Expected SHA256: \(record.sha256), Found: \(currentSHA)"
                    )
                    return false
                }
            }
            verified += 1
        }

        // Check for unauthorized new scripts or injection in Resource
        if let enumerator = fm.enumerator(atPath: "\(resourceRootPath)/Other/Info/Settings/Paid") {
            while let item = enumerator.nextObject() as? String {
                if item.hasSuffix(".csv") {
                    let csvPath = "\(resourceRootPath)/Other/Info/Settings/Paid/\(item)"
                    if let content = try? String(contentsOfFile: csvPath, encoding: .utf8) {
                        // Validate unauthorized direct switch to 'on' when selling is 'no'
                        let lines = content.components(separatedBy: "\n")
                        if lines.count >= 2 && !lines[1].contains("Data-Type") {
                            let header = lines[1].components(separatedBy: ",")
                            let userIdx: Int?
                            let sellingIdx: Int?
                            let defaultIdx: Int?
                            let planIdx: Int = 0

                            if let u = header.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "user" }),
                               let s = header.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "selling" }) {
                                userIdx = u
                                sellingIdx = s
                                defaultIdx = header.firstIndex(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == "default" })
                            } else {
                                userIdx = 3
                                sellingIdx = 4
                                defaultIdx = 2
                            }

                            for line in lines.dropFirst(2) {
                                let cols = line.components(separatedBy: ",")
                                guard let uIdx = userIdx, let sIdx = sellingIdx, cols.count > max(uIdx, sIdx) else { continue }
                                let plan = cols[planIdx].trimmingCharacters(in: .whitespacesAndNewlines)
                                if plan.contains("Info") || plan.contains("注意事項") || plan.contains("Warning") || plan.contains("不正") {
                                    continue
                                }
                                let user = cols[uIdx].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                let selling = cols[sIdx].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                                let def = (defaultIdx != nil && cols.count > defaultIdx!) ? cols[defaultIdx!].trimmingCharacters(in: .whitespacesAndNewlines).lowercased() : ""

                                // Free standard plans (e.g. Plan 0) or items whose default is 'on' are authorized to be 'on' even if selling is 'no'
                                if plan == "0" || def == "on" {
                                    continue
                                }

                                if selling == "no" && user == "on" {
                                    triggerTamperBlock(
                                        reason: "販売休止中プランまたは未認可の有料機能[\(plan)]がCSV上で直接\"on\"に不正改竄されています。",
                                        filePath: item,
                                        details: "Unauthorized state bypass in \(item)"
                                    )
                                    return false
                                }
                            }
                        }
                    }
                }
            }
        }

        DispatchQueue.main.async {
            self.verifiedFilesCount = verified
        }
        return true
    }

    /// Triggers immediate full application block
    public func triggerTamperBlock(reason: String, filePath: String, details: String) {
        let incident = TamperIncidentReport(
            reason: reason,
            affectedFilePath: filePath,
            detectedDetails: details,
            deviceUUID: getMachineHardwareUUID()
        )

        DispatchQueue.main.async {
            self.isBlocked = true
            self.currentIncident = incident
        }

        // Persist block lock file to prevent simple app restart bypass
        if let data = try? JSONEncoder().encode(incident) {
            try? data.write(to: URL(fileURLWithPath: blockLockFilePath), options: .atomic)
        }

        // Also notify AppState
        DispatchQueue.main.async {
            AppState.shared.addSystemLog(level: "ERROR", message: "【重大セキュリティ警告】\(reason) アプリケーションの利用を即時停止・ブロックしました。")
        }
    }

    private func loadIncidentReport() {
        if let data = try? Data(contentsOf: URL(fileURLWithPath: blockLockFilePath)),
           let incident = try? JSONDecoder().decode(TamperIncidentReport.self, from: data) {
            self.currentIncident = incident
        } else {
            self.currentIncident = TamperIncidentReport(
                reason: "Resourceフォルダの不正操作または改竄が検知されました。",
                affectedFilePath: "Resource/Other/Info/Settings/Paid",
                detectedDetails: "Persistent security lock active",
                deviceUUID: getMachineHardwareUUID()
            )
        }
    }

    /// Recovers and unblocks the application (STRICT: Allowed ONLY from Developer's Mac)
    public func unlockByDeveloper() -> Bool {
        checkCurrentMachineIdentity()
        guard isDeveloperMachine else {
            print("Access Denied: Unblock operation is only allowed from Developer's Mac (\(developerMachineUUID)).")
            return false
        }

        // Remove persistent lock
        if FileManager.default.fileExists(atPath: blockLockFilePath) {
            try? FileManager.default.removeItem(atPath: blockLockFilePath)
        }

        // Re-generate baseline manifest
        generateBaselineManifest()

        DispatchQueue.main.async {
            self.isBlocked = false
            self.currentIncident = nil
            AppState.shared.addSystemLog(level: "INFO", message: "開発者Macからの認証確認により、セキュリティブロックが正常に解除されました。")
        }
        return true
    }
}
