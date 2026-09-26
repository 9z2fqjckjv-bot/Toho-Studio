import SwiftUI

public struct PaidFeaturesDetailView: View {
    @State private var selectedSubCategory: SubCategory = .ad
    @State private var selectedAdOption: AdOption = .fileProcessing
    @State private var selectedCloudOption: CloudOption = .backupSync
    @State private var selectedAIOption: AIOption = .flatRate
    @State private var selectedAppOption: AppOption = .superBundle

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
                    Text(selectedAdOption.rawValue + "（有料機能でオフにできます）")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

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

                    // Price & Duration Table
                    VStack(alignment: .leading, spacing: 8) {
                        Text("フリー券プラン一覧")
                            .font(.system(size: 13, weight: .bold))

                        VStack(spacing: 0) {
                            HStack {
                                Text("チケット種別").frame(width: 120, alignment: .leading)
                                Text("期間").frame(width: 100, alignment: .leading)
                                Text("価格（単体 / 3種まとめ）").frame(maxWidth: .infinity, alignment: .leading)
                                Text("購入").frame(width: 90, alignment: .center)
                            }
                            .font(.system(size: 11, weight: .bold))
                            .padding(8)
                            .background(Color(red: 0.88, green: 0.92, blue: 0.96))

                            Divider()
                            adPriceRow(type: "時間券", duration: "1 時間", price: "¥100 / ¥250")
                            Divider()
                            adPriceRow(type: "日券", duration: "24 時間", price: "¥300 / ¥750")
                            Divider()
                            adPriceRow(type: "週間券", duration: "7 日間", price: "¥1,000 / ¥2,500")
                            Divider()
                            adPriceRow(type: "月間券", duration: "30 日間", price: "¥2,500 / ¥6,250")
                            Divider()
                            adPriceRow(type: "12年券", duration: "12 年間（実質無期限）", price: "1日あたり約662円！")
                        }
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))
                    }

                    KeynoteAnnotationBubble("※広告フリー券は広告の種類ごとに必要です。\n※3種類広告まとめてフリー券は2.5倍でお得になります。\n※12年券の場合は1日あたり約662円でご利用いただけます。")

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

    private func adPriceRow(type: String, duration: String, price: String) -> some View {
        HStack {
            Text(type).font(.system(size: 11, weight: .medium)).frame(width: 120, alignment: .leading)
            Text(duration).font(.system(size: 11)).frame(width: 100, alignment: .leading)
            Text(price).font(.system(size: 11, weight: .bold)).foregroundColor(.blue).frame(maxWidth: .infinity, alignment: .leading)
            Button("購入する") {}
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.12, green: 0.45, blue: 0.75)))
                .frame(width: 90, alignment: .center)
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
                        Text("バックアップと同期（クラウド機能）")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

                        Text("複数の端末で作品や素材データをシームレスに共有・自動同期します。")
                            .font(.system(size: 13))

                        VStack(spacing: 0) {
                            HStack {
                                Text("プラン").frame(width: 120, alignment: .leading)
                                Text("期間").frame(width: 120, alignment: .leading)
                                Text("価格").frame(maxWidth: .infinity, alignment: .leading)
                                Text("操作").frame(width: 90, alignment: .center)
                            }
                            .font(.system(size: 11, weight: .bold))
                            .padding(8)
                            .background(Color(red: 0.88, green: 0.92, blue: 0.96))

                            Divider()
                            adPriceRow(type: "月間利用券", duration: "1 ヶ月", price: "¥1,200")
                            Divider()
                            adPriceRow(type: "12年利用券", duration: "12 年間", price: "1日あたり約66円！")
                        }
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

                        KeynoteAnnotationBubble("1種類の機能につき、1つのサービス利用券が必要です。\n12年券の場合は1日あたり約66円でお使いいただけます。")
                    } else {
                        Text("対応拡張子の追加")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

                        Text("読み込み・書き出し可能なファイル拡張子を追加します。")
                            .font(.system(size: 13))

                        VStack(spacing: 0) {
                            HStack {
                                Text("プラン名").frame(width: 120, alignment: .leading)
                                Text("対応拡張子一覧").frame(maxWidth: .infinity, alignment: .leading)
                                Text("ステータス").frame(width: 90, alignment: .center)
                            }
                            .font(.system(size: 11, weight: .bold))
                            .padding(8)
                            .background(Color(red: 0.88, green: 0.92, blue: 0.96))

                            Divider()
                            extensionPlanRow(name: "無料プラン", exts: "標準形式 (.tsvm, .tssm, .tscm, .tspm, .tsgm, .mp4, .png, .jpg)", status: "利用中", isEnabled: true)
                            Divider()
                            extensionPlanRow(name: "月額100円プラン", exts: "mov, wav, png, prproj", status: "販売休止中", isEnabled: false)
                            Divider()
                            extensionPlanRow(name: "月額200円プラン", exts: "svg, aac, m4a, aif", status: "販売休止中", isEnabled: false)
                            Divider()
                            extensionPlanRow(name: "月額300円プラン", exts: "pxd, psd, logicx, sesh, fcpbundle", status: "販売休止中", isEnabled: false)
                        }
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

                        KeynoteAnnotationBubble("※販売休止中のプランは設定がオフに固定されます。\n直接CSVファイルを書き換えるとエラーレポートが出力されます。")
                    }
                }
                .padding(24)
            }
        }
    }

    private func extensionPlanRow(name: String, exts: String, status: String, isEnabled: Bool) -> some View {
        HStack {
            Text(name).font(.system(size: 11, weight: .medium)).frame(width: 120, alignment: .leading)
            Text(exts).font(.system(size: 11)).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            Text(status)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(isEnabled ? .green : .secondary)
                .frame(width: 90, alignment: .center)
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
                        Text("AI機能 定額プラン")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

                        Text("使用モデルは、サーバーや通信環境によって自動選択されます。")
                            .font(.system(size: 13))

                        VStack(spacing: 0) {
                            HStack {
                                Text("プラン名").frame(width: 140, alignment: .leading)
                                Text("プロンプト上限目安").frame(maxWidth: .infinity, alignment: .leading)
                                Text("月額価格").frame(width: 100, alignment: .trailing)
                                Text("契約").frame(width: 90, alignment: .center)
                            }
                            .font(.system(size: 11, weight: .bold))
                            .padding(8)
                            .background(Color(red: 0.88, green: 0.92, blue: 0.96))

                            Divider()
                            aiPlanRow(name: "無料プラン", limit: "月100回", price: "¥0", isCurrent: true)
                            Divider()
                            aiPlanRow(name: "エントリープラン", limit: "月1,000回", price: "¥1,000", isCurrent: false)
                            Divider()
                            aiPlanRow(name: "スタンダードプラン", limit: "月2,500回", price: "¥2,000", isCurrent: false)
                            Divider()
                            aiPlanRow(name: "プロプラン", limit: "月5,000回", price: "¥3,000", isCurrent: false)
                            Divider()
                            aiPlanRow(name: "ビジネスプラン", limit: "月10,000回", price: "¥5,000", isCurrent: false)
                            Divider()
                            aiPlanRow(name: "AI最強利用券", limit: "無制限優先", price: "¥10,000", isCurrent: false)
                        }
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

                        KeynoteAnnotationBubble("定額プラン（使用モデルは、サーバーや通信環境によって自動選択されます。）")
                    } else {
                        Text("AI機能 都度課金式プラン")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

                        Text("OpenAI、Claude、Gemini、NanndemoyaAIなどの各プロバイダAPIを利用し、利用した分だけ請求されます。")
                            .font(.system(size: 13))

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

    private func aiPlanRow(name: String, limit: String, price: String, isCurrent: Bool) -> some View {
        HStack {
            Text(name).font(.system(size: 11, weight: .medium)).frame(width: 140, alignment: .leading)
            Text(limit).font(.system(size: 11)).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            Text(price).font(.system(size: 11, weight: .bold)).foregroundColor(.blue).frame(width: 100, alignment: .trailing)
            Button(isCurrent ? "利用中" : "選択") {}
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isCurrent ? .secondary : .white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 4).fill(isCurrent ? Color.gray.opacity(0.2) : Color(red: 0.12, green: 0.45, blue: 0.75)))
                .disabled(isCurrent)
                .frame(width: 90, alignment: .center)
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
                    Text(selectedAppOption.rawValue + " の機能追加とバンドル")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

                    switch selectedAppOption {
                    case .movieMaker:
                        appDetailBox(title: "ムービーメーカー拡張機能", items: [
                            "独自機能を追加（4K/60fps高画質書き出し、マルチトラック拡張）: ¥1,000",
                            "FinalCutPro非搭載機能追加（高度なカラーグレーディング、AIモーショントラッキング）: ¥1,500",
                            "バンドルで機能追加: ¥500",
                            "ムービーメーカーフルパック: ¥2,500"
                        ])
                    case .characterMaker:
                        appDetailBox(title: "キャラクターメーカー拡張機能", items: [
                            "独自機能を追加（立ち絵自動差分生成、レイヤー無限拡張）: ¥1,000",
                            "Live2D連携・高度物理演算追加: ¥1,500",
                            "バンドルで機能追加: ¥500",
                            "キャラクターメーカーフルパック: ¥2,500"
                        ])
                    case .soundMaker:
                        appDetailBox(title: "サウンドメーカー拡張機能", items: [
                            "独自機能を追加（Logic Pro連携、VST3プラグイン対応）: ¥1,000",
                            "音声合成AquesTalk連携強化パック: ¥1,000",
                            "バンドルで機能追加: ¥500",
                            "サウンドメーカーフルパック: ¥2,000"
                        ])
                    case .slideScenario:
                        appDetailBox(title: "スライド＆シナリオメーカー拡張機能", items: [
                            "Keynote/PowerPoint双方向変換機能: ¥1,000",
                            "AI台本自動生成・校正エンジン連携: ¥1,500",
                            "スライド＆シナリオフルパック: ¥2,000"
                        ])
                    case .materialStudio:
                        appDetailBox(title: "素材スタジオ拡張機能", items: [
                            "東方Project公認素材ライブラリ無制限アクセス: ¥1,500",
                            "クラウド素材自動同期パック: ¥1,000"
                        ])
                    case .superBundle:
                        bundlePriceTable
                    }

                    KeynoteAnnotationBubble("有料機能の有効期間：広告フリーとバックアップと同期を除き、1ヶ月間有効です。")
                }
                .padding(24)
            }
        }
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

    private var bundlePriceTable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("スーパーバンドル 一覧（Slide 91）")
                .font(.system(size: 13, weight: .bold))

            VStack(spacing: 0) {
                HStack {
                    Text("バンドル名").frame(width: 180, alignment: .leading)
                    Text("価格").frame(width: 90, alignment: .trailing)
                    Text("内容・特典").frame(maxWidth: .infinity, alignment: .leading)
                    Text("操作").frame(width: 80, alignment: .center)
                }
                .font(.system(size: 11, weight: .bold))
                .padding(8)
                .background(Color(red: 0.88, green: 0.92, blue: 0.96))

                Divider()
                bundleRow(name: "スーパーバンドル", price: "¥8,000", desc: "MM, CM, SM, SSM, 素材スタジオ全機能パック")
                Divider()
                bundleRow(name: "スーパーバンドル＆拡張子セット", price: "¥8,150", desc: "スーパーバンドル ＋ 300円拡張子プラン")
                Divider()
                bundleRow(name: "バンドルセット＆月間広告利用券", price: "¥16,000", desc: "バンドルセット ＋ 3種類の広告が1ヶ月間フリー")
                Divider()
                bundleRow(name: "バンドルセット＆月間フリー券", price: "¥12,000", desc: "バンドルセット ＋ バックアップと同期が1ヶ月間フリー")
                Divider()
                bundleRow(name: "バンドルセット＆AI最強利用券", price: "¥15,000", desc: "バンドルセット ＋ 1万円定額AIプラン")
                Divider()
                bundleRow(name: "おまとめスーパーバンドルセット", price: "¥20,000", desc: "全ての拡張機能・全広告フリー・全クラウド・AI最強セット")
            }
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))
        }
    }

    private func bundleRow(name: String, price: String, desc: String) -> some View {
        HStack {
            Text(name).font(.system(size: 11, weight: .bold)).frame(width: 180, alignment: .leading)
            Text(price).font(.system(size: 11, weight: .bold)).foregroundColor(.blue).frame(width: 90, alignment: .trailing)
            Text(desc).font(.system(size: 11)).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            Button("購入") {}
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.12, green: 0.45, blue: 0.75)))
                .frame(width: 80, alignment: .center)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }
}
