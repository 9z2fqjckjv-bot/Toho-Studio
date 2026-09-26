import SwiftUI

public struct AccountSettingsDetailView: View {
    @ObservedObject var appState = AppState.shared
    @Binding var activeCategory: SettingsCategory

    @State private var selectedAccountTab: AccountTab = .nanndemoyaCloud
    @State private var selectedLocalSubTab: LocalAccountSubTab = .name

    public enum AccountTab: String, CaseIterable, Identifiable {
        case nanndemoyaCloud = "NanndemoyaCloud"
        case google = "Google"
        case local = "ローカルアカウント"
        public var id: String { rawValue }
    }

    public enum LocalAccountSubTab: String, CaseIterable, Identifiable {
        case name = "氏名"
        case birthday = "生年月日"
        case phoneNumber = "電話番号"
        case identityVerification = "本人確認"
        case security = "セキュリティ"
        case accountSwitch = "アカウント切替"
        public var id: String { rawValue }
    }

    public init(activeCategory: Binding<SettingsCategory> = .constant(.account)) {
        self._activeCategory = activeCategory
    }

    public var body: some View {
        HStack(spacing: 0) {
            // Column 3: Account Sub Tabs (NanndemoyaCloud, Google, Local)
            VStack(spacing: 12) {
                ReturnArrowButton {
                    // Return action if needed
                }
                .frame(maxWidth: .infinity, alignment: .center)

                ForEach(AccountTab.allCases) { tab in
                    KeynoteColumnButton(
                        title: tab.rawValue,
                        isSelected: selectedAccountTab == tab
                    ) {
                        selectedAccountTab = tab
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .frame(width: 170)
            .background(Color(red: 0.85, green: 0.91, blue: 0.96))
            .overlay(
                Rectangle()
                    .fill(Color(red: 0.22, green: 0.58, blue: 0.88))
                    .frame(width: 2),
                alignment: .trailing
            )

            // Column 4 & 5: Content based on selected account tab
            switch selectedAccountTab {
            case .nanndemoyaCloud:
                nanndemoyaCloudDetailView
            case .google:
                googleAccountDetailView
            case .local:
                localAccountDetailView
            }
        }
    }

    // MARK: - NanndemoyaCloud (Slide 40 & 仕様書補足事項)
    private var nanndemoyaCloudDetailView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 10)

                // User Avatar Icon
                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .foregroundColor(Color(red: 0.3, green: 0.35, blue: 0.4))

                // Name & Email
                VStack(spacing: 4) {
                    Text(appState.userName)
                        .font(.system(size: 24, weight: .bold))
                    Text(appState.userEmail)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text("プラン: SuperPlus (.jp) / 5TB プール")
                        .font(.caption)
                        .foregroundColor(Color(red: 0.12, green: 0.45, blue: 0.75))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color(red: 0.85, green: 0.92, blue: 0.98))
                        .cornerRadius(4)
                }

                // Action Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        activeCategory = .licenseAndAuth
                    }) {
                        Text("ライセンスで開く")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 220, height: 42)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.25, green: 0.6, blue: 0.95)))
                    }
                    .buttonStyle(.plain)

                    HStack(spacing: 12) {
                        Button(action: {
                            appState.isLoggedIn.toggle()
                            appState.log(appState.isLoggedIn ? "NanndemoyaCloudにログインしました" : "NanndemoyaCloudからログアウトしました")
                        }) {
                            Text(appState.isLoggedIn ? "ログアウト" : "ログイン")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(red: 0.3, green: 0.1, blue: 0.15))
                                .frame(width: 170, height: 42)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.98, green: 0.68, blue: 0.78)))
                        }
                        .buttonStyle(.plain)

                        KeynoteAnnotationBubble(appState.isLoggedIn ? "ログアウト済みの場合は「ログイン」と表示" : "ログイン時はブラウザで認証処理を行います")
                    }

                    Button(action: {
                        appState.log("NanndemoyaCloudの最新アカウント情報を更新しました")
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(Color(red: 0.35, green: 0.72, blue: 0.98))
                            Text("情報を更新")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }

                Divider().padding(.vertical, 8)

                // Additional terms & pricing info from specification supplement
                VStack(alignment: .leading, spacing: 10) {
                    Text("NanndemoyaCloud サービス利用追加規定")
                        .font(.headline)
                    Text("第1条（サービス構成およびアカウント形態）: Google Workspaceの基本機能に「何でも屋」独自のサポートおよび付帯サービスを統合したサブスクリプションサービスです。nanndemoyaドメインプランでは組織ドメイン内に個別アカウントを発行・配分します。\n第2条（料金および価格改定）: 本サービスの利用料金は月額制とし、デポジット型決済基盤「ベースパック」をご利用いただけます。\n第3条（データの管理および免責事項）: 各プランのドライブ容量（30GB、2TB、5TB等）は組織内プール容量として管理されます。重要なデータは定期的なバックアップを実施してください。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .padding(10)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)

                    HStack(spacing: 16) {
                        Link("料金表スプレッドシートを開く ↗️", destination: URL(string: "https://docs.google.com/spreadsheets/d/1V4FQ2rtK3L2-qI5_4HL00IpbIROZ5BsQlTzOTYRoLOg/edit?usp=sharing")!)
                            .font(.system(size: 12))
                        Button("料金表PDFパスを開く") {
                            NSWorkspace.shared.open(URL(fileURLWithPath: "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/NanndemoyaCloud利用料金表.pdf"))
                        }
                        .font(.system(size: 12))
                    }
                }
                .padding(.horizontal, 24)

                Spacer().frame(height: 20)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Google Account (Slide 41 & 仕様書補足事項)
    private var googleAccountDetailView: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer().frame(height: 10)

                Image(systemName: "person.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .foregroundColor(Color(red: 0.3, green: 0.35, blue: 0.4))

                VStack(spacing: 4) {
                    Text(appState.userName)
                        .font(.system(size: 24, weight: .bold))
                    Text("user@gmail.com")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    Text("※個人アカウントのみ（@gmail.com）が対象です")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 14) {
                    Link(destination: URL(string: "https://myaccount.google.com")!) {
                        Text("ブラウザで確認")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 220, height: 42)
                            .background(RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.25, green: 0.6, blue: 0.95)))
                    }

                    HStack(spacing: 12) {
                        Button(action: {
                            appState.log("Googleアカウントのログイン/ログアウト操作を実行しました")
                        }) {
                            Text("ログアウト")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(Color(red: 0.3, green: 0.1, blue: 0.15))
                                .frame(width: 170, height: 42)
                                .background(RoundedRectangle(cornerRadius: 8).fill(Color(red: 0.98, green: 0.68, blue: 0.78)))
                        }
                        .buttonStyle(.plain)

                        KeynoteAnnotationBubble("ログアウト済みの場合は「ログイン」と表示")
                    }

                    Button(action: {
                        appState.log("Googleアカウント情報を更新しました")
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 32, weight: .bold))
                                .foregroundColor(Color(red: 0.35, green: 0.72, blue: 0.98))
                            Text("情報を更新")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Spacer().frame(height: 20)
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Local Account (Slides 42-46)
    private var localAccountDetailView: some View {
        HStack(spacing: 0) {
            // Column 4: Local Account Sub Items (氏名, 生年月日, 電話番号, 本人確認, セキュリティ, アカウント切替)
            VStack(spacing: 10) {
                ReturnArrowButton {
                    // return action
                }
                .frame(maxWidth: .infinity, alignment: .center)

                ForEach(LocalAccountSubTab.allCases) { subTab in
                    KeynoteColumnButton(
                        title: subTab.rawValue,
                        isSelected: selectedLocalSubTab == subTab
                    ) {
                        selectedLocalSubTab = subTab
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.top, 16)
            .frame(width: 160)
            .background(Color(red: 0.90, green: 0.94, blue: 0.98))
            .overlay(
                Rectangle()
                    .fill(Color(red: 0.22, green: 0.58, blue: 0.88))
                    .frame(width: 2),
                alignment: .trailing
            )

            // Column 5: Local Account Detail Panel
            ScrollView {
                VStack(alignment: .center, spacing: 20) {
                    Spacer().frame(height: 20)

                    switch selectedLocalSubTab {
                    case .name:
                        VStack(spacing: 16) {
                            Text("本名: ズヤシ (zuyasi)")
                                .font(.system(size: 20, weight: .bold))
                            HStack(spacing: 20) {
                                Button("編集") { appState.log("ローカルアカウント氏名の編集ダイアログを開きます") }
                                Button("初期化") { appState.log("ローカルアカウント氏名を初期化しました") }
                                Button("ヘルプ") { appState.log("ローカルアカウント氏名に関するヘルプを表示します") }
                            }
                            .font(.system(size: 14))
                        }

                    case .birthday:
                        VStack(spacing: 16) {
                            Text("生年月日: 1998/08/10")
                                .font(.system(size: 20, weight: .bold))
                            HStack(spacing: 20) {
                                Button("編集") { appState.log("生年月日の編集ダイアログを開きます") }
                                Button("初期化") { appState.log("生年月日を初期化しました") }
                                Button("ヘルプ") { appState.log("生年月日に関するヘルプを表示します") }
                            }
                            .font(.system(size: 14))
                        }

                    case .phoneNumber:
                        VStack(spacing: 16) {
                            Text("電話番号: 070-9075-8210")
                                .font(.system(size: 20, weight: .bold))
                            HStack(spacing: 20) {
                                Button("編集") { appState.log("電話番号の編集ダイアログを開きます") }
                                Button("初期化") { appState.log("電話番号を初期化しました") }
                                Button("ヘルプ") { appState.log("電話番号に関するヘルプを表示します") }
                            }
                            .font(.system(size: 14))
                        }

                    case .identityVerification:
                        VStack(spacing: 16) {
                            Text("本人確認ステータス: 認証済み (Status: Verified)")
                                .font(.system(size: 17, weight: .bold))

                            HStack(spacing: 16) {
                                Button("認証する") { appState.log("本人確認認証プロセスを開始しました") }
                                    .buttonStyle(.borderedProminent)
                                Button("情報が古い場合") { appState.log("本人確認情報の再更新をリクエストしました") }
                                Button("ヘルプとサポート") { appState.log("本人確認サポートページを開きます") }
                            }

                            KeynoteAnnotationBubble(
                                "ストアにて自作のコンテンツや作品、素材を販売（有料無料を問いません。）する場合には、本人確認が必要です。なお、ローカルアカウントで本人確認をすると、認証情報がPC上に保存されます。セキュリティ上の懸念から、GoogleあるいはNanndemoyaCloudで本人確認を実施してください。"
                            )
                            .frame(maxWidth: 380)
                        }

                    case .security:
                        VStack(spacing: 16) {
                            Text("ログイン方法と認証方法")
                                .font(.headline)

                            VStack(alignment: .leading, spacing: 8) {
                                securityRow(title: "パスワード", status: "設定済み")
                                securityRow(title: "電話認証", status: "設定済み")
                                securityRow(title: "メール認証", status: "設定済み")
                                securityRow(title: "秘密の質問", status: "未設定")
                                securityRow(title: "ローカルパスキー", status: "設定済み")
                            }
                            .padding(12)
                            .background(Color(NSColor.controlBackgroundColor))
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.black.opacity(0.8), lineWidth: 2))

                            KeynoteAnnotationBubble(
                                "パスワードを忘れたり、電話が使えなくなった時に備え、複数の認証方法を用意することを強く推奨します。"
                            )
                            .frame(maxWidth: 380)

                            Button("本機能の詳細とヘルプはこちら ↗️") {
                                appState.log("セキュリティ詳細ヘルプを開きます")
                            }
                            .font(.system(size: 12))
                        }

                    case .accountSwitch:
                        VStack(spacing: 16) {
                            Text("アカウント切替")
                                .font(.headline)
                            KeynoteAnnotationBubble(
                                "同一端末で複数のローカルアカウントを利用している場合は、ここからアカウントを切り替えることができます。"
                            )
                            .frame(maxWidth: 380)

                            VStack(spacing: 8) {
                                ForEach(["zuyasi (管理者)", "Guest User", "東方制作アカウント"], id: \.self) { acc in
                                    HStack {
                                        Image(systemName: "person.circle")
                                        Text(acc)
                                        Spacer()
                                        Button("切替") {
                                            appState.userName = acc
                                            appState.log("アカウントを \(acc) に切り替えました")
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                    .padding(8)
                                    .background(Color(NSColor.controlBackgroundColor))
                                    .cornerRadius(6)
                                }
                            }
                            .frame(maxWidth: 360)
                        }
                    }

                    Spacer().frame(height: 20)
                }
                .padding(.horizontal, 20)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func securityRow(title: String, status: String) -> some View {
        HStack {
            Text("\(title):")
                .frame(width: 140, alignment: .leading)
            Text(status)
                .bold()
                .foregroundColor(status == "設定済み" ? .green : .secondary)
            Spacer()
            Button("変更") {
                appState.log("\(title)の設定変更画面を開きます")
            }
            .font(.system(size: 11))
        }
    }
}
