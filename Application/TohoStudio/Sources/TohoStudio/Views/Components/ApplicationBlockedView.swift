import SwiftUI

public struct ApplicationBlockedView: View {
    @ObservedObject var integrityService = ResourceIntegrityProtectionService.shared
    @State private var unlockMessage: String? = nil
    @State private var showDeveloperDetails: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            Color.black.opacity(0.96)
                .edgesIgnoringSafeArea(.all)

            VStack(spacing: 24) {
                // Warning Header
                HStack(spacing: 16) {
                    Image(systemName: "exclamationmark.octagon.fill")
                        .font(.system(size: 56))
                        .foregroundColor(.red)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("【セキュリティ保護警告】利用停止処置が実行されました")
                            .font(.title)
                            .bold()
                            .foregroundColor(.white)
                        Text("Resourceフォルダ内の保護されたプログラムまたは有料機能管理CSVの直接操作・改竄が検知されました。")
                            .font(.subheadline)
                            .foregroundColor(.red.opacity(0.9))
                    }
                }

                Divider().background(Color.red.opacity(0.5))

                // Incident Details Box
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("検知された不正事由:")
                            .font(.headline)
                            .foregroundColor(.yellow)
                        Spacer()
                        Text(integrityService.currentIncident?.timestamp ?? Date(), style: .date)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    Text(integrityService.currentIncident?.reason ?? "Resourceフォルダ内のファイルに対する不正な直接変更またはNanndemoyaCloud未認可アクセス")
                        .font(.body)
                        .foregroundColor(.white)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.red.opacity(0.18))
                        .cornerRadius(8)

                    HStack {
                        Text("対象ファイル / パス:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(integrityService.currentIncident?.affectedFilePath ?? "Resource/Other/Info/Settings/Paid")
                            .font(.caption)
                            .foregroundColor(.white)
                            .bold()
                    }

                    HStack {
                        Text("端末ハードウェア識別子:")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(integrityService.currentIncident?.deviceUUID ?? integrityService.getMachineHardwareUUID())
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.gray)
                    }
                }
                .padding(20)
                .background(Color(NSColor.darkGray).opacity(0.5))
                .cornerRadius(10)

                // Developer Mac Verification Section
                VStack(spacing: 14) {
                    if integrityService.isDeveloperMachine {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.shield.fill")
                                .foregroundColor(.green)
                            Text("開発者（オーナー）Macが認識されました (UUID: \(integrityService.developerMachineUUID.prefix(8))...)")
                                .font(.subheadline)
                                .foregroundColor(.green)
                                .bold()
                        }

                        Button(action: {
                            let ok = integrityService.unlockByDeveloper()
                            if ok {
                                unlockMessage = "ブロックが解除され、整合性マニフェストが再構築されました。"
                            } else {
                                unlockMessage = "解除に失敗しました。"
                            }
                        }) {
                            HStack {
                                Image(systemName: "lock.open.fill")
                                Text("開発者Mac専用: ブロック解除と整合性修復を実行")
                                    .bold()
                            }
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    } else {
                        VStack(spacing: 8) {
                            HStack(spacing: 8) {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.orange)
                                Text("利用停止処置は、開発者のMacからのみ解除・変更が可能です。")
                                    .font(.headline)
                                    .foregroundColor(.orange)
                            }
                            Text("正規のライセンスおよび有料機能設定は、アプリケーション内の設定画面またはNanndemoyaCloudを通じて行ってください。解除には開発者（zuyasi）による専用認証が必要です。")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding(16)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                    }

                    if let msg = unlockMessage {
                        Text(msg)
                            .font(.subheadline)
                            .foregroundColor(.green)
                    }
                }

                Spacer()
            }
            .padding(40)
            .frame(maxWidth: 820, maxHeight: 600)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.15))
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.red, lineWidth: 2))
        }
        .zIndex(999) // Topmost overlay
    }
}
