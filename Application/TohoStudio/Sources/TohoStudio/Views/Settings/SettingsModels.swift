import SwiftUI

// MARK: - 11 Settings Categories (Keynote Slides 38-140 & 仕様書補足事項)
public enum SettingsCategory: String, CaseIterable, Identifiable {
    case account = "アカウント"
    case policy = "ポリシー"
    case billingAndUsage = "課金情報と使用量"
    case storageAndPerf = "ストレージとパフォーマンス"
    case cloud = "クラウド連携"
    case paidFeatures = "有料機能"
    case languageAndArea = "言語と地域"
    case legalAndCompliance = "法規制とコンプライアンス"
    case publishingDefaults = "作品公開のデフォルト設定"
    case licenseAndAuth = "ライセンスと認証設定"
    case initialization = "初期化"

    public var id: String { rawValue }

    public var iconName: String {
        switch self {
        case .account: return "person.crop.circle"
        case .policy: return "doc.text"
        case .billingAndUsage: return "creditcard"
        case .storageAndPerf: return "internaldrive"
        case .cloud: return "cloud"
        case .paidFeatures: return "star.circle"
        case .languageAndArea: return "globe"
        case .legalAndCompliance: return "scale.3d"
        case .publishingDefaults: return "arrow.up.doc"
        case .licenseAndAuth: return "key"
        case .initialization: return "arrow.counterclockwise"
        }
    }
}

// MARK: - Data Models for Tables & Graphs

public struct StorageDetailItem: Identifiable {
    public let id = UUID()
    public let majorCategory: String // 大分類
    public let middleCategory: String // 中分類
    public let fileName: String // ファイル名
    public let size: String // 容量
    public let description: String // 内容
}

public struct StorageReductionItem: Identifiable {
    public let id = UUID()
    public let fileName: String // 削除候補のファイル
    public let description: String // 内容
    public let reclaimableSize: String // 解放可能な容量
}

public struct RightsManagementItem: Identifiable {
    public let id = UUID()
    public let workNo: Int
    public let publishScope: String // 公開範囲 (○, △, ×)
    public let usageType: String // 利用形態 (○, △, ×)
    public let monetization: String // 収益化 (○, △, ×)
    public let commercialUse: String // 商業利用 (○, △, ×)
}

public struct InitTargetItem: Identifiable {
    public let id = UUID()
    public let itemNo: Int
    public let name: String
    public let dataSize: String
    public var isChecked: Bool
}

public struct ProcessMemoryUsage: Identifiable {
    public let id = UUID()
    public let processName: String
    public let memoryGB: Double
    public let percentage: Double
    public let color: Color
}
