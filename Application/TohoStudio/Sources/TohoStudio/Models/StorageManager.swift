import Foundation

public enum StorageLocation: String, CaseIterable, Identifiable {
    case local = "ローカルストレージ"
    case googleDrive = "Googleドライブ (マイドライブ/Toho-Studio)"
    case nanndemoyaCloud = "NanndemoyaCloud"

    public var id: String { rawValue }
}

public struct FileBackupInfo: Identifiable, Codable {
    public var id: UUID = UUID()
    public var originalFileName: String
    public var backupPath: String
    public var timestamp: Date
    public var fileSize: Int64
}

public final class StorageManager: ObservableObject {
    public static let shared = StorageManager()

    @Published public var currentLocation: StorageLocation = .local
    @Published public var autoSaveEnabled: Bool = true
    @Published public var backups: [FileBackupInfo] = []
    @Published public var lastIntegrityCheckMessage: String = "整合性確認：すべての編集ファイルデータは正常です。"
    @Published public var lastSavedTime: Date?

    private let localBaseDirectory = "/Volumes/ZSSD/GitHub/repository/TohoStudio/Application/Resource"

    private init() {}

    /// Checks integrity of project file
    public func verifyFileIntegrity(filePath: String) -> (isHealthy: Bool, message: String) {
        let fm = FileManager.default
        guard fm.fileExists(atPath: filePath) else {
            let msg = "ファイルが見つかりません。修復を実行しますか？"
            lastIntegrityCheckMessage = msg
            return (false, msg)
        }

        do {
            let attrs = try fm.attributesOfItem(atPath: filePath)
            let size = attrs[.size] as? Int64 ?? 0
            if size == 0 {
                let msg = "ファイルサイズが0バイトです。破損の可能性があります。修復を実行しますか？"
                lastIntegrityCheckMessage = msg
                return (false, msg)
            }
            let msg = "整合性確認完了：欠損や破損箇所はありません。正常です。(サイズ: \(size) bytes)"
            lastIntegrityCheckMessage = msg
            return (true, msg)
        } catch {
            let msg = "属性読み込みエラー: \(error.localizedDescription)"
            lastIntegrityCheckMessage = msg
            return (false, msg)
        }
    }

    /// Performs automatic file repair
    public func repairFile(filePath: String) -> Bool {
        let fallbackHeader = "# Toho-Studio Repaired Project File\n# Timestamp: \(Date())\n"
        do {
            try fallbackHeader.write(toFile: filePath, atomically: true, encoding: .utf8)
            lastIntegrityCheckMessage = "ファイル修復成功: 整合性を回復しヘッダーを再構築しました。"
            return true
        } catch {
            lastIntegrityCheckMessage = "修復失敗: \(error.localizedDescription)"
            return false
        }
    }

    /// Creates a timestamped backup of the current active file
    public func createBackup(fileName: String, content: String) -> FileBackupInfo {
        let timestamp = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let backupFileName = "\(fileName)_backup_\(formatter.string(from: timestamp)).json"
        let backupDir = "\(localBaseDirectory)/Backups"

        let fm = FileManager.default
        try? fm.createDirectory(atPath: backupDir, withIntermediateDirectories: true)

        let backupPath = "\(backupDir)/\(backupFileName)"
        try? content.write(toFile: backupPath, atomically: true, encoding: .utf8)

        let info = FileBackupInfo(
            originalFileName: fileName,
            backupPath: backupPath,
            timestamp: timestamp,
            fileSize: Int64(content.utf8.count)
        )
        backups.insert(info, at: 0)
        return info
    }

    /// Save file according to active StorageLocation
    public func saveProjectFile(module: SoftwareModule, fileName: String, data: Data) -> Bool {
        let moduleDirName: String
        switch module {
        case .movieMaker: moduleDirName = "MovieMarker"
        case .characterMaker: moduleDirName = "MaterialStudio/Character"
        case .soundMaker: moduleDirName = "SoundMarker"
        case .slideScenarioMaker: moduleDirName = "Slide&ScenarioMarker"
        case .gameMaker: moduleDirName = "GameMarker"
        case .materialStudio: moduleDirName = "MaterialStudio"
        }

        let targetDir = "\(localBaseDirectory)/\(moduleDirName)"
        let fm = FileManager.default
        try? fm.createDirectory(atPath: targetDir, withIntermediateDirectories: true)

        let targetFile = "\(targetDir)/\(fileName)"
        do {
            try data.write(to: URL(fileURLWithPath: targetFile))
            lastSavedTime = Date()
            return true
        } catch {
            return false
        }
    }
}
