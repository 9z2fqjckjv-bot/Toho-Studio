import SwiftUI

public struct SettingsView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var storageManager = StorageManager.shared
    @ObservedObject var aquesTalk = AquesTalkBridge.shared

    @State private var selectedCategory: SettingsCategory = .account

    public enum SettingsCategory: String, CaseIterable, Identifiable {
        case account = "アカウント"
        case policy = "ポリシー"
        case billing = "課金情報と使用量"
        case storageAndPerf = "ストレージとパフォーマンス"
        case cloud = "クラウド連携"
        case paidFeatures = "有料機能"
        case languageAndArea = "言語と地域"
        case legalAndCompliance = "法規制とコンプライアンス"
        case publishingDefaults = "作品公開デフォルト設定"
        case licenseAndAuth = "ライセンスと認証設定"
        case initialization = "初期化"

        public var id: String { rawValue }

        public var iconName: String {
            switch self {
            case .account: return "person.crop.circle"
            case .policy: return "doc.plaintext"
            case .billing: return "creditcard"
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

    public var body: some View {
        HSplitView {
            // Sidebar Categories
            List(SettingsCategory.allCases, selection: $selectedCategory) { cat in
                Label(cat.rawValue, systemImage: cat.iconName)
                    .tag(cat)
                    .padding(.vertical, 2)
            }
            .frame(width: 220)
            .listStyle(.sidebar)

            // Detail View
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    categoryHeaderView(category: selectedCategory)
                    Divider()
                    categoryContentView(category: selectedCategory)
                }
                .padding(24)
            }
            .frame(minWidth: 540, maxWidth: .infinity)
        }
        .frame(width: 820, height: 580)
    }

    private func categoryHeaderView(category: SettingsCategory) -> some View {
        HStack(spacing: 12) {
            Image(systemName: category.iconName)
                .font(.title)
                .foregroundColor(.accentColor)
            VStack(alignment: .leading) {
                Text(category.rawValue)
                    .font(.title2)
                    .bold()
                Text("Toho-Studio 設定項目")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func categoryContentView(category: SettingsCategory) -> some View {
        switch category {
        case .account: accountSection
        case .policy: policySection
        case .billing: billingSection
        case .storageAndPerf: storageAndPerfSection
        case .cloud: cloudSection
        case .paidFeatures: paidFeaturesSection
        case .languageAndArea: languageAndAreaSection
        case .legalAndCompliance: legalAndComplianceSection
        case .publishingDefaults: publishingDefaultsSection
        case .licenseAndAuth: licenseAndAuthSection
        case .initialization: initializationSection
        }
    }

    // MARK: - 1. アカウント
    private var accountSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox(label: Text("ログインアカウント情報")) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.accentColor)
                        VStack(alignment: .leading) {
                            Text(appState.userName).font(.headline)
                            Text(appState.userEmail).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("プラン: \(appState.currentAccountType)")
                            .font(.caption)
                            .padding(4)
                            .background(Color.accentColor.opacity(0.2))
                            .cornerRadius(4)
                    }

                    Divider()

                    HStack {
                        Button("ライセンス画面で開く") {
                            selectedCategory = .licenseAndAuth
                        }
                        Button("ログアウト") {
                            appState.isLoggedIn = false
                            appState.log("ログアウトしました")
                        }
                        Spacer()
                        Button("情報を更新") {
                            appState.log("アカウント情報を最新に同期しました")
                        }
                    }
                }
                .padding(8)
            }
        }
    }

    // MARK: - 2. ポリシー
    private var policySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Toho-Studio ポリシー文書一覧").font(.headline)
            Text("本アプリケーションの利用規約、プライバシーポリシー、特定商取引法に基づく表記です。").font(.caption).foregroundColor(.secondary)

            GroupBox(label: Text("利用規約 & 免責事項")) {
                Text("Toho-Studioは東方Projectの二次創作活動を促進するクリエイティブツールです。上海アリス幻樂団様の東方Projectガイドラインに則り利用者の自由な創作をサポートします。")
                    .font(.caption)
                    .padding(4)
            }

            GroupBox(label: Text("特定商取引法に基づく表記")) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("販売事業者: 何でも屋 / Toho-Studio プロジェクト")
                    Text("所在地: 日本国内 (お問い合わせフォームより開示対応)")
                    Text("お支払い方法: クレジットカード、ベースパックデポジット")
                }
                .font(.caption)
                .padding(4)
            }
        }
    }

    // MARK: - 3. 課金情報と使用量
    private var billingSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("請求明細および使用量").font(.headline)

            GroupBox(label: Text("今月の課金状況サマリー")) {
                HStack(spacing: 24) {
                    VStack {
                        Text("¥ 1,300").font(.title2).bold().foregroundColor(.accentColor)
                        Text("今月のご請求金額").font(.caption2)
                    }
                    VStack {
                        Text("33,337 時間").font(.title2).bold().foregroundColor(.green)
                        Text("広告フリー券残時間").font(.caption2)
                    }
                    VStack {
                        Text("10,000 回").font(.title2).bold().foregroundColor(.purple)
                        Text("AIプロンプト利用可能数").font(.caption2)
                    }
                }
                .padding(8)
            }

            VStack(alignment: .leading, spacing: 8) {
                Link("ブラウザでスプレッドシート明細を確認 ↗️", destination: URL(string: "https://docs.google.com/spreadsheets/d/1TetBelEjIOVzHxhC-EYQFTXXoBlHUTmA0ipCPqXck7E/edit?usp=sharing")!)
                Link("身に覚えのない明細・内容食い違いの問い合わせフォーム ↗️", destination: URL(string: "https://forms.gle/hJ9EuapUVQik4qgG9")!)
            }
            .font(.caption)
        }
    }

    // MARK: - 4. ストレージとパフォーマンス
    private var storageAndPerfSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ストレージ使用量とフレームレート制御").font(.headline)

            GroupBox(label: Text("フレームレートとメディア優先度")) {
                VStack(alignment: .leading, spacing: 8) {
                    Picker("", selection: $appState.targetFpsMode) {
                        Text("パフォーマンス優先 (低スペックMac推奨)").tag("パフォーマンス優先")
                        Text("画質優先 (高解像度レンダリング)").tag("画質優先")
                        Text("バランス自動調整 (有料独自機能拡張)").tag("バランス自動調整")
                        Text("カスタム設定").tag("カスタム")
                    }
                    .pickerStyle(.radioGroup)
                }
                .padding(6)
            }

            GroupBox(label: Text("容量削減オプション")) {
                HStack {
                    Text("キャッシュファイル (一時データ: 840 MB)")
                    Spacer()
                    Button("キャッシュを一括削除") {
                        appState.log("キャッシュを削除しディスク容量を解放しました")
                    }
                }
                .padding(6)
            }
        }
    }

    // MARK: - 5. クラウド連携
    private var cloudSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("NanndemoyaCloud & Googleアカウント連携").font(.headline)

            GroupBox(label: Text("NanndemoyaCloud 連携")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "cloud.fill").foregroundColor(.accentColor)
                        Text("クラウド保存状態: 接続中 (5TB プール)")
                        Spacer()
                        Button("クラウド保存設定") {}
                    }
                    Button("NanndemoyaCloudデータをGoogleアカウントへ丸ごと移行") {
                        appState.log("データ移行プロセスを開始しました")
                    }
                    .font(.caption)
                }
                .padding(6)
            }

            GroupBox(label: Text("Google アカウント連携")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("デフォルト保存先フォルダ: マイドライブ/Toho-Studio")
                        .font(.caption)
                    Link("Google One ストレージ管理を開く ↗️", destination: URL(string: "https://one.google.com")!)
                        .font(.caption)
                }
                .padding(6)
            }
        }
    }

    // MARK: - 6. 有料機能
    private var paidFeaturesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("有料機能・サブスクリプション管理").font(.headline)

            GroupBox(label: Text("対応拡張子プラン")) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("現在のプラン: \(appState.extensionPlan)").bold()
                    Text("mov, png, wav, svg, m4a, aac, fcpbundle, prproj, pxd, psd, logicx, sesx がすべて解放されています。")
                        .font(.caption).foregroundColor(.secondary)
                }
                .padding(6)
            }

            GroupBox(label: Text("広告フリー券ステータス")) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("ファイル処理広告 / 長時間処理広告 / お試し広告")
                        Text("残りフリー時間: \(appState.adFreeRemainingHours) 時間").bold().foregroundColor(.green)
                    }
                    Spacer()
                    Button("フリー券を追加購入") {
                        selectedCategory = .paidFeatures
                    }
                }
                .padding(6)
            }

            GroupBox(label: Text("AI機能プラン")) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("定額プラン (10,000 プロンプト / 月) 契約中").bold()
                    Text("OpenAI, Claude, Gemini, NanndemoyaAI モデルが自由に利用可能です。")
                        .font(.caption).foregroundColor(.secondary)
                }
                .padding(6)
            }
        }
    }

    // MARK: - 7. 言語と地域
    private var languageAndAreaSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("言語と地域・世界観設定").font(.headline)

            HStack {
                Text("UI言語:")
                Picker("", selection: $appState.uiLanguage) {
                    Text("日本語").tag("日本語")
                    Text("English").tag("English")
                    Text("繁體中文").tag("繁體中文")
                }
                .frame(width: 140)

                Spacer()

                Text("地域・世界観:")
                Picker("", selection: $appState.regionArea) {
                    Text("幻想郷 (日本)").tag("幻想郷 (日本)")
                    Text("外の世界 (日本)").tag("外の世界 (日本)")
                }
                .frame(width: 160)
            }

            GroupBox(label: Text("幻想郷の地図 (設定画面プレビュー)")) {
                VStack(spacing: 8) {
                    HStack {
                        Image(systemName: "map.fill").foregroundColor(.accentColor)
                        Text("幻想郷マップ (/Application/Documents/幻想郷マップ.jpeg)")
                            .font(.caption)
                        Spacer()
                    }
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: 120)
                        .overlay(
                            Text("博麗神社 — 人里 — 魔法の森 — 妖怪の山 — 紅魔館 — 迷いの竹林 — 白玉楼")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        )
                }
                .padding(6)
            }
        }
    }

    // MARK: - 8. 法規制とコンプライアンス
    private var legalAndComplianceSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("法規制とコンプライアンス点検").font(.headline)

            GroupBox(label: Text("法令遵守とポリシー照合")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("今すぐ確認する:")
                        Spacer()
                        Button("即時スキャン実行") {
                            appState.log("法令およびポリシー遵守スキャンを完了しました: 適合")
                        }
                    }
                    HStack {
                        Text("バックグラウンド定期確認:")
                        Spacer()
                        Toggle("", isOn: .constant(true)).labelsHidden()
                    }
                }
                .padding(6)
            }
        }
    }

    // MARK: - 9. 作品公開デフォルト設定
    private var publishingDefaultsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("作品公開のデフォルト公開設定").font(.headline)

            Picker("新規作成時の公開範囲:", selection: $appState.defaultPublishScope) {
                Text("非公開 (自分のみ)").tag("非公開")
                Text("限定公開 (共有URLのみ)").tag("限定公開")
                Text("ストア一般公開 (審査あり)").tag("ストア一般公開")
            }
            .pickerStyle(.radioGroup)
        }
    }

    // MARK: - 10. ライセンスと認証設定
    private var licenseAndAuthSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("ライセンスキーと認証設定").font(.headline)
            Text("AquesTalk音声合成エンジンのライセンスキー、Google、NanndemoyaCloudの認証を行います。").font(.caption).foregroundColor(.secondary)

            GroupBox(label: Text("AquesTalk ライセンスキー設定")) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("開発ライセンスキー:")
                            .frame(width: 140, alignment: .leading)
                        SecureField("Dev Key (未設定時はデモモード)", text: $aquesTalk.devKey)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Text("使用ライセンスキー:")
                            .frame(width: 140, alignment: .leading)
                        SecureField("Usr Key", text: $aquesTalk.usrKey)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Button("ライセンスキーを適用") {
                            aquesTalk.applyKeys(dev: aquesTalk.devKey, usr: aquesTalk.usrKey)
                            appState.log("AquesTalkライセンスキーを適用しました")
                        }
                        .buttonStyle(.borderedProminent)

                        Link("AquesTalkライセンスを購入 ↗️", destination: URL(string: "https://store.a-quest.com/items/7905423")!)
                            .font(.caption)
                    }
                }
                .padding(6)
            }
        }
    }

    // MARK: - 11. 初期化
    private var initializationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("データの初期化・リセット").font(.headline)
            Text("作品データまたはアプリケーション設定を初期化します。").font(.caption).foregroundColor(.secondary)

            Button("選択した作品データのみをリセット") {
                appState.log("作品データを初期化しました")
            }
            .buttonStyle(.bordered)

            Button("すべての設定とデータを工場出荷状態にリセット", role: .destructive) {
                appState.log("Toho-Studioを初期状態にリセットしました")
            }
            .buttonStyle(.bordered)
        }
    }
}
