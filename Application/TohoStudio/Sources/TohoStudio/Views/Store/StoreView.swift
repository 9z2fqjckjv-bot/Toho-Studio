import SwiftUI

public struct StoreView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selectedTab: Int = 0

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 14) {
                Label("Toho-Studio ストア", systemImage: "bag.fill")
                    .font(.title2)
                    .bold()
                Spacer()
                Text("利用可能残高: ¥ 24,500 (ベースパック)")
                    .font(.caption)
                    .padding(6)
                    .background(Color.accentColor.opacity(0.15))
                    .cornerRadius(6)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Store Tabs
            Picker("", selection: $selectedTab) {
                Text("新作＆おすすめ").tag(0)
                Text("アプリ拡張＆バンドル").tag(1)
                Text("東方素材＆テンプレート").tag(2)
                Text("販売・出品管理").tag(3)
                Text("ストア用語定義・審査規約").tag(4)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if selectedTab == 0 {
                        storeFeaturedTab
                    } else if selectedTab == 1 {
                        storeExtensionsTab
                    } else if selectedTab == 2 {
                        storeMaterialsTab
                    } else if selectedTab == 3 {
                        storeSellerManagementTab
                    } else {
                        storeTermsDefinitionTab
                    }
                }
                .padding(20)
            }
        }
        .frame(width: 820, height: 580)
    }

    // MARK: - 1. 新作＆おすすめ
    private var storeFeaturedTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("注目のおすすめパック＆拡張機能").font(.headline)

            bannerCard(
                title: "おまとめスーパーバンドルセット",
                subtitle: "全内蔵ソフト拡張 + 拡張子フル解放 + 広告フリー券 + クラウド同期 + AI最強利用券",
                price: "¥ 12,800 / 月",
                badge: "最強パック"
            )

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                bundleCard(title: "ムービーメーカー拡張バンドル", desc: "FCP & Premiere機能追加 + リモートサポート", price: "¥ 1,500")
                bundleCard(title: "サウンドメーカー拡張バンドル", desc: "Audition & Logic機能追加 + 高音質リバーブ", price: "¥ 1,200")
                bundleCard(title: "キャラクターメーカー拡張バンドル", desc: "Photoshop & Pixelmator機能追加 + 自動パーツ切り出し", price: "¥ 1,200")
                bundleCard(title: "スライド＆シナリオ拡張バンドル", desc: "Keynote & PPT機能追加 + 高精度認識アドオン", price: "¥ 1,500")
            }
        }
    }

    // MARK: - 2. アプリ拡張＆バンドル (仕様書補足事項 447-494行目)
    private var storeExtensionsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("アプリ拡張とスーパーバンドル一覧").font(.headline)

            VStack(spacing: 10) {
                extensionItemRow(title: "スーパーバンドル単品", desc: "4つの内蔵ソフトの全アプリ拡張を利用可能", price: "¥ 3,800")
                extensionItemRow(title: "スーパーバンドル＆拡張子セット", desc: "全アプリ拡張 + 拡張子300円プラン（全形式解放）", price: "¥ 4,100")
                extensionItemRow(title: "バンドルセット＆月間広告利用権", desc: "全アプリ拡張 + 拡張子プラン + 3広告フリー券（1ヶ月）", price: "¥ 4,800")
                extensionItemRow(title: "バンドルセット＆月間フリー券セット", desc: "全アプリ拡張 + クラウド自動バックアップ＆同期券（1ヶ月）", price: "¥ 4,800")
                extensionItemRow(title: "バンドルセット＆AI最強利用券", desc: "全アプリ拡張 + 1万円分のAIプロンプト利用券（50,000回）", price: "¥ 12,000")
            }
        }
    }

    // MARK: - 3. 素材＆テンプレート
    private var storeMaterialsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("東方Project 二次創作素材・スライドテンプレート").font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                materialStoreCard(name: "紅魔館 室内背景高解像度10選", creator: "東方スタジオ公式", type: "背景画像", price: "無料")
                materialStoreCard(name: "博麗霊夢 表情差分32種セット", creator: "何でも屋素材工房", type: "立ち絵", price: "¥ 500")
                materialStoreCard(name: "妖々夢風 和風オーケストラBGM集", creator: "Studio Phantasm", type: "音楽BGM", price: "¥ 800")
                materialStoreCard(name: "RPG会話スライドテンプレート20選", creator: "東方スタジオ公式", type: "テンプレート", price: "無料")
            }
        }
    }

    // MARK: - 4. 販売・出品管理
    private var storeSellerManagementTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("素材・作品の販売・出品管理").font(.headline)
            Text("自作の立ち絵、BGM、スライドテンプレートをストアに出品し、無料配信または販売できます。").font(.caption).foregroundColor(.secondary)

            GroupBox(label: Text("出品中の素材ステータス")) {
                VStack(spacing: 8) {
                    HStack {
                        Text("現在出品中のアイテム:")
                        Spacer()
                        Text("2 件 (審査承認済み)").bold().foregroundColor(.green)
                    }
                    HStack {
                        Text("今月の販売売上収益:")
                        Spacer()
                        Text("¥ 6,400").bold()
                    }
                }
                .padding(6)
            }

            Button(action: {
                appState.log("新規素材のストア審査申請を送信しました")
            }) {
                Label("新しい素材・作品を出品審査に提出", systemImage: "arrow.up.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Helper UI Components
    private func bannerCard(title: String, subtitle: String, price: String, badge: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text(badge)
                    .font(.caption2)
                    .bold()
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.yellow)
                    .foregroundColor(.black)
                    .cornerRadius(4)
                Text(title).font(.title3).bold()
                Text(subtitle).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(price).font(.title3).bold().foregroundColor(.accentColor)
                Button("購入する") {
                    appState.log("ストアにて「\(title)」を購入しました")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(14)
        .background(Color.accentColor.opacity(0.1))
        .cornerRadius(10)
    }

    private func bundleCard(title: String, desc: String, price: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline).bold()
            Text(desc).font(.caption2).foregroundColor(.secondary)
            Spacer()
            HStack {
                Text(price).bold().font(.callout)
                Spacer()
                Button("購入") {
                    appState.log("ストアにて「\(title)」を購入しました")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .frame(height: 110)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(8)
    }

    private func extensionItemRow(title: String, desc: String, price: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline).bold()
                Text(desc).font(.caption).foregroundColor(.secondary)
            }
            Spacer()
            Text(price).bold().font(.callout)
            Button("購入") {
                appState.log("ストアにて「\(title)」を購入しました")
            }
            .buttonStyle(.bordered)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(6)
    }

    private func materialStoreCard(name: String, creator: String, type: String, price: String) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.caption).bold()
                Text("\(creator) | \(type)").font(.caption2).foregroundColor(.secondary)
            }
            Spacer()
            Text(price).font(.caption).bold()
            Button("入手") {
                appState.log("素材「\(name)」を素材スタジオにダウンロードしました")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)
    }

    // MARK: - 5. ストア用語定義・審査規約 (アプリ改善指示書 実施事項)
    private var storeTermsDefinitionTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Label("Toho-Studio ストア関連用語の定義と掲載規約", systemImage: "text.book.closed.fill")
                    .font(.headline)
                    .foregroundColor(.accentColor)
                Spacer()
            }

            Text("ストアにおける取引、出品、二次創作作品および素材の流通に関する公式定義です。出品・購入・配信前に必ずご確認ください。")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(spacing: 12) {
                termDefinitionCard(
                    term: "作品",
                    reading: "さくひん",
                    definition: "このアプリケーション（Toho-Studio）を用いて、利用者（開発者を含む）が作成した完成動画、ゲームプログラム、スライド作品などを指します。"
                )

                termDefinitionCard(
                    term: "素材",
                    reading: "そざい",
                    definition: "作品を作成する際に利用した、動画、画像、立ち絵、スライド、音声ファイル、テキストファイルなど、作品の制作に使用したすべてのファイルを指します。"
                )

                termDefinitionCard(
                    term: "配信（配布）",
                    reading: "はいしん / はいふ",
                    definition: "完成した作品あるいは素材を、非営利目的かつ利用料無料（¥0）で他の利用者が利用できるように公開することを指します。"
                )

                termDefinitionCard(
                    term: "販売",
                    reading: "はんばい",
                    definition: "完成した作品あるいは素材を、非営利目的かつ有料（ストアポイント/ベースパック決済）で利用できるように公開することを指します。"
                )

                termDefinitionCard(
                    term: "商用",
                    reading: "しょうよう",
                    definition: "完成した作品あるいは素材を、営利目的（企業プロモーション、商用ライセンス、収益化プロジェクト等）かつ有料利用できるように公開することを指します。"
                )

                termDefinitionCard(
                    term: "審査",
                    reading: "しんさ",
                    definition: "完成した作品あるいは素材をストアに掲載する前には、必ず「何でも屋」側に作品あるいは素材を送付して審査を受ける必要があります。審査で拒絶された場合はストア上への掲載はできません。また、ストア掲載には「何でも屋」のパートナー規約に合意しパートナー登録を完了している必要があります。"
                )
            }

            GroupBox(label: Label("「何でも屋」パートナー規約と審査窓口", systemImage: "person.2.badge.gearshape.fill")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("ストアへの素材・作品の掲載および有料販売には、「何でも屋」公式パートナー契約が必要です。ガイドライン・パートナー契約書は以下のリンクよりアプリ内ブラウザで閲覧できます。")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    HStack(spacing: 16) {
                        Button(action: {
                            if let url = URL(string: "https://docs.google.com/document/d/1ub4_g_pOUCQjDzUXKBBmzWqC6zexBFOltoHFabZo-HU/edit?usp=sharing") {
                                appState.openInAppBrowser(url: url, title: "「何でも屋」パートナー利用規定・審査ガイド")
                            }
                        }) {
                            HStack {
                                Image(systemName: "safari")
                                Text("パートナー利用規定を開く (内部ブラウザ) ↗️")
                            }
                            .font(.caption)
                            .bold()
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: {
                            appState.log("ストア審査申請フォームを開きました")
                            if let url = URL(string: "https://forms.gle/hJ9EuapUVQik4qgG9") {
                                appState.openInAppBrowser(url: url, title: "ストア審査申請フォーム")
                            }
                        }) {
                            Text("審査申請フォームを開く ↗️")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(8)
            }
        }
    }

    private func termDefinitionCard(term: String, reading: String, definition: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text(term)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.primary)
                Text(reading)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .frame(width: 100, alignment: .leading)

            Divider()

            Text(definition)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.06))
        .cornerRadius(6)
    }
}
