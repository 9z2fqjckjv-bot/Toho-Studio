import SwiftUI

public struct BillingUsageDetailView: View {
    @State private var selectedSubCategory: SubCategory = .billing
    @State private var selectedBillingSource: BillingSource = .store
    @State private var usageViewType: UsageViewType = .memory
    @State private var showingExternalSheet = false
    @State private var sheetURL: URL?

    public enum SubCategory: String, CaseIterable {
        case billing = "課金情報"
        case usage = "使用量"
    }

    public enum BillingSource: String, CaseIterable {
        case store = "ストア"
        case official = "公式"
    }

    public enum UsageViewType: String, CaseIterable {
        case memory = "メモリの利用量と容量"
        case storage = "ストレージ容量"
    }

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // Column 3: Subcategory Selector (課金情報 / 使用量)
            VStack(spacing: 8) {
                ForEach(SubCategory.allCases, id: \.self) { cat in
                    KeynoteColumnButton(
                        title: cat.rawValue,
                        isSelected: selectedSubCategory == cat
                    ) {
                        selectedSubCategory = cat
                    }
                }
                Spacer()
            }
            .frame(width: 140)
            .padding(.horizontal, 10)
            .padding(.vertical, 16)
            .background(Color(red: 0.88, green: 0.92, blue: 0.96))

            Divider()

            // Column 4 & Main Content Area
            if selectedSubCategory == .billing {
                billingView
            } else {
                usageView
            }
        }
    }

    // MARK: - Billing View (ストア / 公式)
    private var billingView: some View {
        HStack(spacing: 0) {
            // Column 4: Billing Source (ストア / 公式)
            VStack(spacing: 8) {
                ForEach(BillingSource.allCases, id: \.self) { source in
                    KeynoteColumnButton(
                        title: source.rawValue,
                        isSelected: selectedBillingSource == source
                    ) {
                        selectedBillingSource = source
                    }
                }
                Spacer()
            }
            .frame(width: 120)
            .padding(.horizontal, 10)
            .padding(.vertical, 16)
            .background(Color(red: 0.92, green: 0.95, blue: 0.98))

            Divider()

            // Main Detail Panel
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if selectedBillingSource == .store {
                        storeBillingDetail
                    } else {
                        officialBillingDetail
                    }
                }
                .padding(24)
            }
        }
    }

    private var storeBillingDetail: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("ストア経由の課金情報と明細")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

            // 請求情報
            VStack(alignment: .leading, spacing: 8) {
                Text("請求情報")
                    .font(.system(size: 14, weight: .bold))
                HStack(spacing: 12) {
                    Image(systemName: "creditcard.fill")
                        .foregroundColor(.blue)
                    Text("クレジットカード (Visa ****-****-****-4242)")
                        .font(.system(size: 13))
                    Spacer()
                    Text("有効期限: 2028/12")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))
            }

            // 明細
            VStack(alignment: .leading, spacing: 8) {
                Text("明細")
                    .font(.system(size: 14, weight: .bold))
                VStack(spacing: 0) {
                    HStack {
                        Text("購入日時").frame(width: 140, alignment: .leading)
                        Text("金額").frame(width: 80, alignment: .trailing)
                        Text("購入内容").frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.system(size: 12, weight: .bold))
                    .padding(8)
                    .background(Color(red: 0.88, green: 0.92, blue: 0.96))

                    Divider()

                    storeRow(date: "2026/09/25 18:22", amount: "¥1,500", desc: "キャラクターメーカー 追加パック")
                    Divider()
                    storeRow(date: "2026/09/20 11:05", amount: "¥300", desc: "対応拡張子追加プラン（月額）")
                    Divider()
                    storeRow(date: "2026/09/15 09:30", amount: "¥8,000", desc: "スーパーバンドル ライセンス")
                }
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))
            }

            // Action Buttons & Support Links
            billingActionLinks(isOfficial: false)
        }
    }

    private var officialBillingDetail: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("公式配布の請求情報と支払い期日")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

            // 請求情報
            VStack(alignment: .leading, spacing: 8) {
                Text("請求情報")
                    .font(.system(size: 14, weight: .bold))
                HStack(spacing: 12) {
                    Image(systemName: "banknote")
                        .foregroundColor(.green)
                    Text("ベースパック決済 / NanndemoyaPay")
                        .font(.system(size: 13))
                    Spacer()
                    Text("残高: ¥45,200")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(Color(red: 0.12, green: 0.45, blue: 0.25))
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))
            }

            // 支払い期日と金額
            VStack(alignment: .leading, spacing: 8) {
                Text("支払い期日と金額")
                    .font(.system(size: 14, weight: .bold))
                VStack(spacing: 0) {
                    HStack {
                        Text("支払い期日").frame(width: 120, alignment: .leading)
                        Text("金額").frame(width: 90, alignment: .trailing)
                        Text("詳細").frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.system(size: 12, weight: .bold))
                    .padding(8)
                    .background(Color(red: 0.88, green: 0.92, blue: 0.96))

                    Divider()

                    officialRow(date: "2026/10/01", amount: "¥10,000", desc: "AI機能 定額式プラン（最強プラン）")
                    Divider()
                    officialRow(date: "2026/10/15", amount: "¥5,000", desc: "NanndemoyaCloud SuperPremium")
                    Divider()
                    officialRow(date: "2026/11/01", amount: "¥8,150", desc: "バンドルセット＆拡張子セット")
                }
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))
            }

            billingActionLinks(isOfficial: true)
        }
    }

    private func storeRow(date: String, amount: String, desc: String) -> some View {
        HStack {
            Text(date).font(.system(size: 11)).frame(width: 140, alignment: .leading)
            Text(amount).font(.system(size: 11, weight: .bold)).frame(width: 80, alignment: .trailing)
            Text(desc).font(.system(size: 11)).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func officialRow(date: String, amount: String, desc: String) -> some View {
        HStack {
            Text(date).font(.system(size: 11)).frame(width: 120, alignment: .leading)
            Text(amount).font(.system(size: 11, weight: .bold)).frame(width: 90, alignment: .trailing)
            Text(desc).font(.system(size: 11)).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func billingActionLinks(isOfficial: Bool) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: {
                if let url = URL(string: "https://docs.google.com/spreadsheets/d/1TetBelEjIOVzHxhC-EYQFTXXoBlHUTmA0ipCPqXck7E/edit?usp=sharing") {
                    AppState.shared.openInAppBrowser(url: url, title: "ベースパック通帳")
                }
            }) {
                HStack {
                    Image(systemName: "safari")
                    Text("ブラウザで確認（ベースパック通帳を内部ブラウザで開く）")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.blue)
            }
            .buttonStyle(.plain)

            Button(action: {
                if let url = URL(string: "https://forms.gle/RV6Sy3qyuf7DMxde9") {
                    AppState.shared.openInAppBrowser(url: url, title: "明細不備の報告フォーム")
                }
            }) {
                Text(isOfficial ? "見覚えのない明細を見かけた場合…" : "見覚えのない明細が載っている場合…")
                    .font(.system(size: 12))
                    .foregroundColor(Color.red.opacity(0.85))
            }
            .buttonStyle(.plain)

            Button(action: {
                if let url = URL(string: "https://forms.gle/RV6Sy3qyuf7DMxde9") {
                    AppState.shared.openInAppBrowser(url: url, title: "購入内容・日付・金額の食い違い報告フォーム")
                }
            }) {
                Text(isOfficial ? "金額と購入日が食い違っている場合…" : "購入内容・日付・金額が食い違っている場合…")
                    .font(.system(size: 12))
                    .foregroundColor(Color.orange.opacity(0.9))
            }
            .buttonStyle(.plain)

            HStack(spacing: 20) {
                Button("お支払い方法に関するドキュメントを見る") {
                    // Open documentation
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)

                Button("ヘルプとサポート") {
                    // Open support
                }
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }
        .padding(.top, 8)
    }

    // MARK: - Usage View (メモリの利用量と容量 / ストレージ容量)
    private var usageView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header with Paging Arrows (◀ / ▶)
                HStack {
                    Button(action: {
                        usageViewType = (usageViewType == .memory) ? .storage : .memory
                    }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .padding(6)
                            .background(Circle().fill(Color.gray.opacity(0.15)))
                    }
                    .buttonStyle(.plain)

                    Text(usageViewType.rawValue)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

                    Button(action: {
                        usageViewType = (usageViewType == .memory) ? .storage : .memory
                    }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .bold))
                            .padding(6)
                            .background(Circle().fill(Color.gray.opacity(0.15)))
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }

                if usageViewType == .memory {
                    memoryUsageContent
                } else {
                    storageUsageContent
                }
            }
            .padding(24)
        }
    }

    private var memoryUsageContent: some View {
        let sampleMemory: [ProcessMemoryUsage] = [
            ProcessMemoryUsage(processName: "ムービーメーカー", memoryGB: 1.2, percentage: 13.0, color: Color.blue),
            ProcessMemoryUsage(processName: "サウンドメーカー", memoryGB: 0.8, percentage: 13.0, color: Color.teal),
            ProcessMemoryUsage(processName: "Googleドライブ", memoryGB: 0.4, percentage: 6.0, color: Color.green),
            ProcessMemoryUsage(processName: "Gemini", memoryGB: 1.6, percentage: 26.0, color: Color.purple),
            ProcessMemoryUsage(processName: "Chrome", memoryGB: 0.5, percentage: 1.0, color: Color.orange),
            ProcessMemoryUsage(processName: "システムとOS", memoryGB: 2.5, percentage: 13.0, color: Color.gray),
            ProcessMemoryUsage(processName: "その他", memoryGB: 2.0, percentage: 28.0, color: Color.cyan)
        ]

        return VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 30) {
                VStack {
                    Text("メモリ占有率")
                        .font(.system(size: 13, weight: .bold))
                    SettingsPieChartView(items: sampleMemory)
                        .frame(width: 150, height: 150)
                        .padding(10)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("メモリ占有プロセス")
                        .font(.system(size: 13, weight: .bold))
                    SettingsBarChartView(items: sampleMemory, maxVal: 3.0)
                        .frame(width: 260)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

            KeynoteAnnotationBubble("ストレージの使用量のグラフに加え、追加機能の利用上限などが確認できます。")
        }
    }

    private var storageUsageContent: some View {
        let sampleStorage: [ProcessMemoryUsage] = [
            ProcessMemoryUsage(processName: "作品・素材データ", memoryGB: 45.0, percentage: 22.0, color: Color.blue),
            ProcessMemoryUsage(processName: "キャッシュ・一時ファイル", memoryGB: 8.0, percentage: 4.0, color: Color.orange),
            ProcessMemoryUsage(processName: "システム及び他アプリ", memoryGB: 120.0, percentage: 58.0, color: Color.gray),
            ProcessMemoryUsage(processName: "空き容量", memoryGB: 339.0, percentage: 16.0, color: Color.green)
        ]

        return VStack(alignment: .leading, spacing: 20) {
            HStack(alignment: .top, spacing: 30) {
                VStack {
                    Text("ストレージ占有率 (合計 512GB)")
                        .font(.system(size: 13, weight: .bold))
                    SettingsPieChartView(items: sampleStorage)
                        .frame(width: 150, height: 150)
                        .padding(10)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Text("内訳と使用状況")
                        .font(.system(size: 13, weight: .bold))

                    ForEach(sampleStorage) { item in
                        HStack {
                            Circle().fill(item.color).frame(width: 8, height: 8)
                            Text(item.processName).font(.system(size: 11))
                            Spacer()
                            Text(String(format: "%.0f GB", item.memoryGB))
                                .font(.system(size: 11, weight: .bold))
                        }
                    }

                    Divider()

                    Text("有料機能の利用上限ステータス")
                        .font(.system(size: 12, weight: .bold))
                        .padding(.top, 4)

                    HStack {
                        Text("AIプロンプト利用数:").font(.system(size: 11))
                        Spacer()
                        Text("8,420 / 10,000回").font(.system(size: 11, weight: .bold))
                    }
                    HStack {
                        Text("クラウドバックアップ容量:").font(.system(size: 11))
                        Spacer()
                        Text("12.4 GB / 50.0 GB").font(.system(size: 11, weight: .bold))
                    }
                }
                .frame(width: 260)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

            KeynoteAnnotationBubble("有料機能に利用上限がある場合、ここで残量や上限ステータスがリアルタイムで確認できます。")
        }
    }
}
