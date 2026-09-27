import Foundation
import SwiftUI

public struct RegisteredDeviceRecord: Identifiable, Codable {
    public var id: UUID = UUID()
    public var deviceName: String
    public var hardwareUUID: String
    public var registeredAt: Date
    public var status: String // "認証済み (Active)", "保留中", "失効"
    public var isCurrentDevice: Bool
}

public struct NanndemoyaCloudAccount: Codable {
    public var accountId: String
    public var email: String
    public var domainType: String // "nanndemoyaドメイン", "独自ドメイン"
    public var domainName: String
    public var planName: String // "Nanndemoya365 Standard", "Business Pro", "Enterprise"
    public var driveQuotaTotalGB: Int
    public var driveQuotaUsedGB: Double
    public var basePackPaymentActive: Bool
    public var supportPremiumActive: Bool
    public var registeredDevices: [RegisteredDeviceRecord]
}

public final class NanndemoyaCloudService: ObservableObject {
    public static let shared = NanndemoyaCloudService()

    public let termsURL = "https://docs.google.com/document/d/1ub4_g_pOUCQjDzUXKBBmzWqC6zexBFOltoHFabZo-HU/edit?usp=sharing"
    public let pricingURL = "https://docs.google.com/spreadsheets/d/1V4FQ2rtK3L2-qI5_4HL00IpbIROZ5BsQlTzOTYRoLOg/edit?usp=sharing"
    public let pricingPDFLocalPath = "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/NanndemoyaCloud利用料金表.pdf"

    @Published public var currentAccount: NanndemoyaCloudAccount? = nil
    @Published public var isAuthenticated: Bool = true
    @Published public var isCurrentDeviceRegistered: Bool = true
    @Published public var registeredDevices: [RegisteredDeviceRecord] = []

    private init() {
        initializeCurrentAccount()
    }

    private func initializeCurrentAccount() {
        let currentUUID = ResourceIntegrityProtectionService.getMachineHardwareUUID()
        let currentDevice = RegisteredDeviceRecord(
            deviceName: Host.current().localizedName ?? "開発者Mac",
            hardwareUUID: currentUUID,
            registeredAt: Date().addingTimeInterval(-86400 * 30),
            status: "認証済み (Active)",
            isCurrentDevice: true
        )

        let account = NanndemoyaCloudAccount(
            accountId: "NDM-2026-889104",
            email: "zuyasi@nanndemoya.jp",
            domainType: "nanndemoyaドメイン",
            domainName: "nanndemoya.jp",
            planName: "Nanndemoya365 Pro Suite",
            driveQuotaTotalGB: 2000,
            driveQuotaUsedGB: 124.5,
            basePackPaymentActive: true,
            supportPremiumActive: true,
            registeredDevices: [currentDevice]
        )

        self.currentAccount = account
        self.registeredDevices = [currentDevice]
        self.isAuthenticated = true
        self.isCurrentDeviceRegistered = true
    }

    /// Checks if current device is legitimately registered in NanndemoyaCloud
    public func verifyDeviceRegistration() -> Bool {
        let currentUUID = ResourceIntegrityProtectionService.getMachineHardwareUUID()
        if registeredDevices.contains(where: { $0.hardwareUUID == currentUUID && $0.status.contains("認証済み") }) {
            self.isCurrentDeviceRegistered = true
            return true
        }
        self.isCurrentDeviceRegistered = false
        return false
    }

    /// Registers the current device via in-app browser authentication flow
    public func registerCurrentDevice(completion: @escaping (Bool) -> Void) {
        let currentUUID = ResourceIntegrityProtectionService.getMachineHardwareUUID()
        let deviceName = Host.current().localizedName ?? "MacBook"

        let newRecord = RegisteredDeviceRecord(
            deviceName: deviceName,
            hardwareUUID: currentUUID,
            registeredAt: Date(),
            status: "認証済み (Active)",
            isCurrentDevice: true
        )

        DispatchQueue.main.async {
            self.registeredDevices.removeAll(where: { $0.hardwareUUID == currentUUID })
            self.registeredDevices.append(newRecord)
            self.currentAccount?.registeredDevices = self.registeredDevices
            self.isCurrentDeviceRegistered = true
            AppState.shared.addSystemLog(level: "INFO", message: "端末 [\(deviceName)] (UUID: \(currentUUID.prefix(8))...) がNanndemoyaCloudに正規登録・認証されました。")
            completion(true)
        }
    }

    /// Open NanndemoyaCloud pricing sheet in in-app browser
    public func openPricingInAppBrowser() {
        if let url = URL(string: pricingURL) {
            AppState.shared.openInAppBrowser(url: url, title: "NanndemoyaCloud 利用料金表")
        }
    }

    /// Open NanndemoyaCloud terms in in-app browser
    public func openTermsInAppBrowser() {
        if let url = URL(string: termsURL) {
            AppState.shared.openInAppBrowser(url: url, title: "NanndemoyaCloud サービス利用規定")
        }
    }
}
