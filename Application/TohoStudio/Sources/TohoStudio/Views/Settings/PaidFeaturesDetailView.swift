import SwiftUI

public struct PaidFeaturesDetailView: View {
    @ObservedObject var paidService = PaidFeatureService.shared
    @State private var selectedSubCategory: SubCategory = .ad
    @State private var selectedAdOption: AdOption = .fileProcessing
    @State private var selectedCloudOption: CloudOption = .backupSync
    @State private var selectedAIOption: AIOption = .flatRate
    @State private var selectedAppOption: AppOption = .superBundle
    @State private var statusMessage: String = ""

    public enum SubCategory: String, CaseIterable {
        case ad = "広告"
        case cloud = "クラウド機能"
        case ai = "AI機能"
        case appExtension = "アプリ拡張"
    }

    public enum AdOption: String, CaseIterable {
        case fileProcessing = "ファイル処理広告"
        case longProcessing = "長時間処理広告"
        case trialAd = "お試し広告"
        case bulkAdFree = "3種類広告まとめてフリー券"
    }

    public enum CloudOption: String, CaseIterable {
        case backupSync = "バックアップと同期"
        case extensions = "対応拡張子の追加"
    }

    public enum AIOption: String, CaseIterable {
        case flatRate = "定額式プラン"
        case payAsYouGo = "都度課金式プラン"
    }

    public enum AppOption: String, CaseIterable {
        case movieMaker = "ムービーメーカー"
        case characterMaker = "キャラクターメーカー"
        case soundMaker = "サウンドメーカー"
        case slideScenario = "スライド＆シナリオメーカー"
        case materialStudio = "素材スタジオ"
        case superBundle = "スーパーバンドル"
    }

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // Column 3: Subcategory Selector (広告 / クラウド機能 / AI機能 / アプリ拡張)
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

            switch selectedSubCategory {
            case .ad:
                adSection
            case .cloud:
                cloudSection
            case .ai:
                aiSection
            case .appExtension:
                appExtensionSection
            }
        }
    }

    // MARK: - Ad Section (Slide 64, 80)
    private var adSection: some View {
        HStack(spacing: 0) {
            VStack(spacing: 8) {
                ForEach(AdOption.allCases, id: \.self) { opt in
                    KeynoteColumnButton(
                        title: opt.rawValue,
                        isSelected: selectedAdOption == opt
                    ) {
                        selectedAdOption = opt
                    }
                }
                Spacer()
            }
            .frame(width: 160)
            .padding(.horizontal, 10)
            .padding(.vertical, 16)
            .background(Color(red: 0.92, green: 0.95, blue: 0.98))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        Text(selectedAdOption.rawValue + "（最新CSV連携）")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))
                        Spacer()
                        if !statusMessage.isEmpty {
                            Text(statusMessage)
                                .font(.caption2)
                                .foregroundColor(.blue)
                        }
                    }

                    switch selectedAdOption {
                    case .fileProcessing:
                        Text("ファイルの読込、書き出し、保存などの作業時に、作業進捗と共に広告を表示します。")
                            .font(.system(size: 13))
                    case .longProcessing:
                        Text("長時間処理時に、作業進捗と共に、広告を表示します。")
                            .font(.system(size: 13))
                    case .trialAd:
                        Text("その都度、動画広告（視聴中は他の機能の利用はできません）を見ることで、広告以外の有料機能を利用できます。ただし、機能によって、制作者が上限を設定することができます。")
                            .font(.system(size: 13))
                    case .bulkAdFree:
                        Text("ファイル処理広告、長時間処理広告、お試し広告の3種類をすべて一括で非表示にできるお得なチケットです。")
                            .font(.system(size: 13))
                    }

                    // Price & Duration Table synced with CSV
                    VStack(alignment: .leading, spacing: 8) {
                        Text("フリー券プラン一覧 (最新CSV Sellingステータス連動)")
                            .font(.system(size: 13, weight: .bold))

                        VStack(spacing: 0) {
                            HStack {
                                Text("チケット種別").frame(width: 110, alignment: .leading)
                                Text("期間").frame(width: 90, alignment: .leading)
                                Text("価格（単体 / 3種まとめ）").frame(maxWidth: .infinity, alignment: .leading)
                                Text("残高(User)").frame(width: 80, alignment: .center)
                                Text("スイッチ / 操作").frame(width: 110, alignment: .center)
                            }
                            .font(.system(size: 11, weight: .bold))
                            .padding(8)
                            .background(Color(red: 0.88, green: 0.92, blue: 0.96))

                            Divider()
                            adPriceRow(type: "時間券", duration: "1 時間", price: "¥100 / ¥250", targetPlan: "時間券")
                            Divider()
                            adPriceRow(type: "日券", duration: "24 時間", price: "¥300 / ¥750", targetPlan: "日券")
                            Divider()
                            adPriceRow(type: "週間券", duration: "7 日間", price: "¥1,000 / ¥2,500", targetPlan: "週間券")
                            Divider()
                            adPriceRow(type: "月間券", duration: "30 日間", price: "¥2,500 / ¥6,250", targetPlan: "月間券")
                            Divider()
                            adPriceRow(type: "年間券", duration: "12 年間（実質無期限）", price: "1日あたり約662円！", targetPlan: "年間券")
                        }
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))
                    }

                    KeynoteAnnotationBubble("※広告フリー券は広告の種類ごとに必要です。\n※3種類広告まとめてフリー券は2.5倍でお得になります。\n※最新CSVデータにより、現在販売ステータスが休止中のプランはオフに固定されます。")

                    // Warning regarding unauthorized CSV manipulation
                    VStack(alignment: .leading, spacing: 4) {
                        Text("不正に関するご注意事項")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.red)
                        Text("上記の値はシステム上で計算され、記録されています。CSVファイルを直接編集した場合、不正行為とみなされ、以後のアプリケーション利用に多大なる悪影響を及ぼす可能性があります。必ず本画面からご購入・設定を行ってください。")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.red.opacity(0.05)))
                }
                .padding(24)
            }
        }
    }

    private func adPriceRow(type: String, duration: String, price: String, targetPlan: String) -> some View {
        let matchingItem = paidService.featureItems.first { item in
            item.csvFileName.contains(selectedAdOption.rawValue) && item.planName == targetPlan
        } ?? paidService.featureItems.first { item in
            item.category.contains("広告") && item.planName == targetPlan
        }

        let userVal = matchingItem?.userValue ?? "0"
        let isAvail = matchingItem?.isAvailableForPurchase ?? false
        let isEnabled = matchingItem?.isEnabledByUser ?? false

        return HStack {
            Text(type).font(.system(size: 11, weight: .medium)).frame(width: 110, alignment: .leading)
            Text(duration).font(.system(size: 11)).frame(width: 90, alignment: .leading)
            Text(price).font(.system(size: 11, weight: .bold)).foregroundColor(.blue).frame(maxWidth: .infinity, alignment: .leading)
            Text("\(userVal)").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary).frame(width: 80, alignment: .center)

            if let item = matchingItem {
                if isEnabled {
                    Button("スイッチ OFF") {
                        paidService.purchaseOrToggleFeature(item: item) { _, msg in statusMessage = msg }
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.bordered)
                    .frame(width: 110, alignment: .center)
                } else if isAvail {
                    Button("購入・ON") {
                        paidService.purchaseOrToggleFeature(item: item) { _, msg in statusMessage = msg }
                    }
                    .font(.system(size: 10, weight: .bold))
                    .buttonStyle(.borderedProminent)
                    .frame(width: 110, alignment: .center)
                } else {
                    Text("販売休止(OFF)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(4)
                        .frame(width: 110, alignment: .center)
                }
            } else {
                Text("販売休止(OFF)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 110, alignment: .center)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    // MARK: - Cloud Section (Slide 65, 81, 82)
    private var cloudSection: some View {
        HStack(spacing: 0) {
            VStack(spacing: 8) {
                ForEach(CloudOption.allCases, id: \.self) { opt in
                    KeynoteColumnButton(
                        title: opt.rawValue,
                        isSelected: selectedCloudOption == opt
                    ) {
                        selectedCloudOption = opt
                    }
                }
                Spacer()
            }
            .frame(width: 150)
            .padding(.horizontal, 10)
            .padding(.vertical, 16)
            .background(Color(red: 0.92, green: 0.95, blue: 0.98))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if selectedCloudOption == .backupSync {
                        Text("バックアップと同期（クラウド機能 - 最新CSV連携）")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

                        Text("複数の端末で作品や素材データをシームレスに共有・自動同期します。")
                            .font(.system(size: 13))

                        VStack(spacing: 0) {
                            HStack {
                                Text("機能名").frame(width: 110, alignment: .leading)
                                Text("期間プラン").frame(width: 90, alignment: .leading)
                                Text("価格").frame(maxWidth: .infinity, alignment: .leading)
                                Text("残高(User)").frame(width: 80, alignment: .center)
                                Text("スイッチ / 操作").frame(width: 110, alignment: .center)
                            }
                            .font(.system(size: 11, weight: .bold))
                            .padding(8)
                            .background(Color(red: 0.88, green: 0.92, blue: 0.96))

                            Divider()
                            backupSyncRow(fn: "バックアップ", plan: "月間券", duration: "1 ヶ月", price: "¥1,200")
                            Divider()
                            backupSyncRow(fn: "バックアップ", plan: "年間券", duration: "12 年間", price: "1日あたり約66円！")
                            Divider()
                            backupSyncRow(fn: "同期", plan: "月間券", duration: "1 ヶ月", price: "¥1,200")
                            Divider()
                            backupSyncRow(fn: "同期", plan: "年間券", duration: "12 年間", price: "1日あたり約66円！")
                        }
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

                        KeynoteAnnotationBubble("1種類の機能につき、1つのサービス利用券が必要です。\n最新CSVにて販売休止中のプランはスイッチがオフに固定されます。")
                    } else {
                        Text("対応拡張子の追加（最新CSV: 対応拡張子の追加-Status.csv）")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

                        Text("読み込み・書き出し可能なファイル拡張子を追加します。CSVのUser設定値に基づき制御されます。")
                            .font(.system(size: 13))

                        VStack(spacing: 0) {
                            HStack {
                                Text("プラン名").frame(width: 110, alignment: .leading)
                                Text("対応拡張子一覧").frame(maxWidth: .infinity, alignment: .leading)
                                Text("販売状態").frame(width: 90, alignment: .center)
                                Text("スイッチ / 設定").frame(width: 120, alignment: .center)
                            }
                            .font(.system(size: 11, weight: .bold))
                            .padding(8)
                            .background(Color(red: 0.88, green: 0.92, blue: 0.96))

                            Divider()
                            dynamicExtensionPlanRow(planKey: "0", name: "無料プラン", exts: "標準形式 (.tsvm, .tssm, .tscm, .tspm, .tsgm, .mp4, .png, .jpg)")
                            Divider()
                            dynamicExtensionPlanRow(planKey: "100", name: "月額100円プラン", exts: "mov, wav, png")
                            Divider()
                            dynamicExtensionPlanRow(planKey: "200", name: "月額200円プラン", exts: "svg, aac, m4a, aif")
                            Divider()
                            dynamicExtensionPlanRow(planKey: "300", name: "月額300円プラン", exts: "pxd, psd, logicx, sesx, fcpbundle, prproj")
                        }
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

                        KeynoteAnnotationBubble("※販売休止中のプラン（Selling: no）は設定がオフに固定されます。\n無料プラン（0）は標準で常時有効（ON）として保護されます。")
                    }
                }
                .padding(24)
            }
        }
    }

    private func backupSyncRow(fn: String, plan: String, duration: String, price: String) -> some View {
        let matching = paidService.featureItems.first { item in
            item.category.contains(fn) && item.planName == plan
        }
        let userVal = matching?.userValue ?? "0"
        let isAvail = matching?.isAvailableForPurchase ?? false
        let isEnabled = matching?.isEnabledByUser ?? false

        return HStack {
            Text("\(fn) (\(plan))").font(.system(size: 11, weight: .medium)).frame(width: 110, alignment: .leading)
            Text(duration).font(.system(size: 11)).frame(width: 90, alignment: .leading)
            Text(price).font(.system(size: 11, weight: .bold)).foregroundColor(.blue).frame(maxWidth: .infinity, alignment: .leading)
            Text("\(userVal)").font(.system(size: 10, design: .monospaced)).foregroundColor(.secondary).frame(width: 80, alignment: .center)

            if let item = matching {
                if isEnabled {
                    Button("スイッチ OFF") {
                        paidService.purchaseOrToggleFeature(item: item) { _, msg in statusMessage = msg }
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.bordered)
                    .frame(width: 110, alignment: .center)
                } else if isAvail {
                    Button("購入・ON") {
                        paidService.purchaseOrToggleFeature(item: item) { _, msg in statusMessage = msg }
                    }
                    .font(.system(size: 10, weight: .bold))
                    .buttonStyle(.borderedProminent)
                    .frame(width: 110, alignment: .center)
                } else {
                    Text("販売休止(OFF)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(4)
                        .frame(width: 110, alignment: .center)
                }
            } else {
                Text("販売休止(OFF)")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 110, alignment: .center)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func dynamicExtensionPlanRow(planKey: String, name: String, exts: String) -> some View {
        let item = paidService.featureItems.first { $0.csvFileName.contains("対応拡張子の追加") && $0.planName == planKey }
        let isFree = item?.isFreeDefaultPlan ?? (planKey == "0")
        let isEnabled = item?.isEnabledByUser ?? isFree
        let isAvail = item?.isAvailableForPurchase ?? false

        return HStack {
            Text(name).font(.system(size: 11, weight: .medium)).frame(width: 110, alignment: .leading)
            Text(exts).font(.system(size: 11)).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)

            Text(isFree ? "標準提供" : (isAvail ? "販売中" : "販売休止中"))
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(isFree ? .green : (isAvail ? .blue : .secondary))
                .frame(width: 90, alignment: .center)

            if isFree {
                Text("利用中 (ON)")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.green)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.green.opacity(0.12))
                    .cornerRadius(4)
                    .frame(width: 120, alignment: .center)
            } else if let it = item {
                if isEnabled {
                    Button("スイッチ OFF") {
                        paidService.purchaseOrToggleFeature(item: it) { _, msg in statusMessage = msg }
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.bordered)
                    .frame(width: 120, alignment: .center)
                } else if isAvail {
                    Button("購入・スイッチ ON") {
                        paidService.purchaseOrToggleFeature(item: it) { _, msg in statusMessage = msg }
                    }
                    .font(.system(size: 10, weight: .bold))
                    .buttonStyle(.borderedProminent)
                    .frame(width: 120, alignment: .center)
                } else {
                    Text("休止中 (OFF固定)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(4)
                        .frame(width: 120, alignment: .center)
                }
            } else {
                Text("オフ (OFF)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .frame(width: 120, alignment: .center)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    // MARK: - AI Section (Slide 66, 67, 86-90)
    private var aiSection: some View {
        HStack(spacing: 0) {
            VStack(spacing: 8) {
                ForEach(AIOption.allCases, id: \.self) { opt in
                    KeynoteColumnButton(
                        title: opt.rawValue,
                        isSelected: selectedAIOption == opt
                    ) {
                        selectedAIOption = opt
                    }
                }
                Spacer()
            }
            .frame(width: 140)
            .padding(.horizontal, 10)
            .padding(.vertical, 16)
            .background(Color(red: 0.92, green: 0.95, blue: 0.98))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if selectedAIOption == .flatRate {
                        Text("AI機能 定額プラン（最新CSV: AI機能-定額式プラン.csv）")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

                        Text("使用モデルは、サーバーや通信環境によって自動選択されます。")
                            .font(.system(size: 13))

                        VStack(spacing: 0) {
                            HStack {
                                Text("プラン名").frame(width: 130, alignment: .leading)
                                Text("プロンプト上限目安").frame(maxWidth: .infinity, alignment: .leading)
                                Text("月額価格").frame(width: 90, alignment: .trailing)
                                Text("スイッチ / ステータス").frame(width: 120, alignment: .center)
                            }
                            .font(.system(size: 11, weight: .bold))
                            .padding(8)
                            .background(Color(red: 0.88, green: 0.92, blue: 0.96))

                            Divider()
                            dynamicAIPlanRow(planKey: "0", name: "無料プラン", limit: "月1,000回 (広告付)", price: "¥0")
                            Divider()
                            dynamicAIPlanRow(planKey: "1000", name: "1,000円プラン", limit: "月2,500回 (2.5倍)", price: "¥1,000")
                            Divider()
                            dynamicAIPlanRow(planKey: "2000", name: "2,000円プラン", limit: "月5,000回 (5倍)", price: "¥2,000")
                            Divider()
                            dynamicAIPlanRow(planKey: "3000", name: "3,000円プラン", limit: "月10,000回 (10倍)", price: "¥3,000")
                            Divider()
                            dynamicAIPlanRow(planKey: "5000", name: "5,000円プラン", limit: "月20,000回 (20倍)", price: "¥5,000")
                            Divider()
                            dynamicAIPlanRow(planKey: "10000", name: "10,000円プラン", limit: "月50,000回 (50倍)", price: "¥10,000")
                        }
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

                        KeynoteAnnotationBubble("定額プラン（販売休止中のプランは設定がオフに固定されます。）")
                    } else {
                        Text("AI機能 都度課金式プラン（最新CSV: AI機能-都度課金式プラン.csv）")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

                        Text("OpenAI、Claude、Gemini、NanndemoyaAIなどの各プロバイダAPIを利用し、利用した分だけ請求されます。")
                            .font(.system(size: 13))

                        VStack(spacing: 8) {
                            ForEach(paidService.featureItems.filter { $0.csvFileName.contains("都度課金") }) { item in
                                HStack {
                                    Text(item.planName)
                                        .font(.system(size: 12, weight: .bold))
                                        .frame(width: 180, alignment: .leading)
                                    Text(item.details)
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Text(item.isAvailableForPurchase ? "販売中" : "販売休止中(OFF固定)")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(item.isAvailableForPurchase ? .blue : .secondary)
                                        .frame(width: 120, alignment: .center)
                                }
                                .padding(8)
                                .background(Color.white)
                                .cornerRadius(6)
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("申請書チャージ金額")
                                .font(.system(size: 13, weight: .bold))
                            HStack(spacing: 12) {
                                Button("¥3,000 チャージ") {}
                                Button("¥5,000 チャージ") {}
                                Button("¥10,000 チャージ") {}
                                Button("¥30,000 チャージ") {}
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            Text("現在のプロンプト残量")
                                .font(.system(size: 12, weight: .bold))
                            ProgressView(value: 0.84, total: 1.0)
                                .accentColor(.blue)
                            Text("8,420 / 10,000 トークン（残量20%以下になると自動で警告通知が送信されます）")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        .padding(12)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))
                    }
                }
                .padding(24)
            }
        }
    }

    private func dynamicAIPlanRow(planKey: String, name: String, limit: String, price: String) -> some View {
        let item = paidService.featureItems.first { $0.csvFileName.contains("定額式プラン") && $0.planName == planKey }
        let isEnabled = item?.isEnabledByUser ?? false
        let isAvail = item?.isAvailableForPurchase ?? false

        return HStack {
            Text(name).font(.system(size: 11, weight: .medium)).frame(width: 130, alignment: .leading)
            Text(limit).font(.system(size: 11)).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            Text(price).font(.system(size: 11, weight: .bold)).foregroundColor(.blue).frame(width: 90, alignment: .trailing)

            if let it = item {
                if isEnabled {
                    Button("スイッチ OFF") {
                        paidService.purchaseOrToggleFeature(item: it) { _, msg in statusMessage = msg }
                    }
                    .font(.system(size: 10))
                    .buttonStyle(.bordered)
                    .frame(width: 120, alignment: .center)
                } else if isAvail {
                    Button("購入・スイッチ ON") {
                        paidService.purchaseOrToggleFeature(item: it) { _, msg in statusMessage = msg }
                    }
                    .font(.system(size: 10, weight: .bold))
                    .buttonStyle(.borderedProminent)
                    .frame(width: 120, alignment: .center)
                } else {
                    Text("休止中 (OFF固定)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.secondary.opacity(0.12))
                        .cornerRadius(4)
                        .frame(width: 120, alignment: .center)
                }
            } else {
                Text("オフ (OFF)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .frame(width: 120, alignment: .center)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    // MARK: - App Extension Section (Slides 68-79, 91)
    private var appExtensionSection: some View {
        HStack(spacing: 0) {
            VStack(spacing: 8) {
                ForEach(AppOption.allCases, id: \.self) { opt in
                    KeynoteColumnButton(
                        title: opt.rawValue,
                        isSelected: selectedAppOption == opt
                    ) {
                        selectedAppOption = opt
                    }
                }
                Spacer()
            }
            .frame(width: 160)
            .padding(.horizontal, 10)
            .padding(.vertical, 16)
            .background(Color(red: 0.92, green: 0.95, blue: 0.98))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text(selectedAppOption.rawValue + " の機能追加とバンドル（最新CSV連携）")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

                    switch selectedAppOption {
                    case .movieMaker:
                        appDetailBoxForCSV(csvName: "ムービーメーカー")
                    case .characterMaker:
                        appDetailBoxForCSV(csvName: "キャラクターメーカー")
                    case .soundMaker:
                        appDetailBoxForCSV(csvName: "サウンドメーカー")
                    case .slideScenario:
                        appDetailBoxForCSV(csvName: "スライド&シナリオメーカー")
                    case .materialStudio:
                        appDetailBox(title: "素材スタジオ拡張機能", items: [
                            "東方Project公認素材ライブラリ無制限アクセス: ¥1,500",
                            "クラウド素材自動同期パック: ¥1,000"
                        ])
                    case .superBundle:
                        bundlePriceTableDynamic
                    }

                    KeynoteAnnotationBubble("有料機能の有効期間：広告フリーとバックアップと同期を除き、1ヶ月間有効です。\n販売休止中のプランはCSVの仕様に基づきオフに固定されます。")
                }
                .padding(24)
            }
        }
    }

    private func appDetailBoxForCSV(csvName: String) -> some View {
        let items = paidService.featureItems.filter { $0.csvFileName.contains(csvName) }
        return VStack(alignment: .leading, spacing: 10) {
            Text("\(csvName) 拡張機能 (最新CSVステータス)")
                .font(.system(size: 14, weight: .bold))

            ForEach(items) { item in
                HStack {
                    Circle()
                        .fill(item.isEnabledByUser ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 8, height: 8)
                    Text(item.planName)
                        .font(.system(size: 12, weight: .bold))
                        .frame(width: 140, alignment: .leading)
                    Text(item.details)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if item.isEnabledByUser {
                        Button("スイッチ OFF") {
                            paidService.purchaseOrToggleFeature(item: item) { _, msg in statusMessage = msg }
                        }
                        .font(.system(size: 10))
                        .buttonStyle(.bordered)
                    } else if item.isAvailableForPurchase {
                        Button("購入・スイッチ ON") {
                            paidService.purchaseOrToggleFeature(item: item) { _, msg in statusMessage = msg }
                        }
                        .font(.system(size: 10, weight: .bold))
                        .buttonStyle(.borderedProminent)
                    } else {
                        Text("販売休止(OFF固定)")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.12))
                            .cornerRadius(4)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))
    }

    private func appDetailBox(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.system(size: 14, weight: .bold))
            ForEach(items, id: \.self) { item in
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(item).font(.system(size: 12))
                    Spacer()
                    Button("購入する") {}
                        .font(.system(size: 11))
                        .buttonStyle(.bordered)
                }
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))
    }

    private var bundlePriceTableDynamic: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("スーパーバンドル 一覧 (最新CSV: アプリ拡張-スーパーバンドル.csv)")
                .font(.system(size: 13, weight: .bold))

            VStack(spacing: 0) {
                HStack {
                    Text("バンドル名").frame(width: 180, alignment: .leading)
                    Text("価格").frame(width: 90, alignment: .trailing)
                    Text("内容・特典").frame(maxWidth: .infinity, alignment: .leading)
                    Text("スイッチ / 操作").frame(width: 120, alignment: .center)
                }
                .font(.system(size: 11, weight: .bold))
                .padding(8)
                .background(Color(red: 0.88, green: 0.92, blue: 0.96))

                Divider()
                ForEach(paidService.featureItems.filter { $0.csvFileName.contains("スーパーバンドル") }) { item in
                    HStack {
                        Text(item.planName).font(.system(size: 11, weight: .bold)).frame(width: 180, alignment: .leading)
                        Text(item.priceDescription).font(.system(size: 11, weight: .bold)).foregroundColor(.blue).frame(width: 90, alignment: .trailing)
                        Text(item.details).font(.system(size: 11)).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)

                        if item.isEnabledByUser {
                            Button("スイッチ OFF") {
                                paidService.purchaseOrToggleFeature(item: item) { _, msg in statusMessage = msg }
                            }
                            .font(.system(size: 10))
                            .buttonStyle(.bordered)
                            .frame(width: 120, alignment: .center)
                        } else if item.isAvailableForPurchase {
                            Button("購入・スイッチ ON") {
                                paidService.purchaseOrToggleFeature(item: item) { _, msg in statusMessage = msg }
                            }
                            .font(.system(size: 10, weight: .bold))
                            .buttonStyle(.borderedProminent)
                            .frame(width: 120, alignment: .center)
                        } else {
                            Text("販売休止(OFF固定)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(Color.secondary.opacity(0.12))
                                .cornerRadius(4)
                                .frame(width: 120, alignment: .center)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    Divider()
                }
            }
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))
        }
    }
}
