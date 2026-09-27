import SwiftUI

public struct PolicySettingsDetailView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selectedPolicyTab: PolicyTab = .terms

    public enum PolicyTab: String, CaseIterable, Identifiable {
        case terms = "利用規約"
        case privacy = "個人情報に関して"
        case commercial = "特定商取引法に基づく表記"
        public var id: String { rawValue }
    }

    public var body: some View {
        HStack(spacing: 0) {
            // Column 3: Policy Tabs
            VStack(spacing: 12) {
                ReturnArrowButton {}
                    .frame(maxWidth: .infinity, alignment: .center)

                ForEach(PolicyTab.allCases) { tab in
                    KeynoteColumnButton(
                        title: tab.rawValue,
                        isSelected: selectedPolicyTab == tab
                    ) {
                        selectedPolicyTab = tab
                    }
                }
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 16)
            .frame(width: 180)
            .background(Color(red: 0.85, green: 0.91, blue: 0.96))
            .overlay(
                Rectangle()
                    .fill(Color(red: 0.22, green: 0.58, blue: 0.88))
                    .frame(width: 2),
                alignment: .trailing
            )

            // Column 4: Policy Content Pane
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedPolicyTab {
                    case .terms:
                        termsView
                    case .privacy:
                        privacyView
                    case .commercial:
                        commercialView
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var termsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Toho-Studio 利用規約")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

            Group {
                Text("第1条（総則および目的）")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.16, green: 0.22, blue: 0.30))
                Text("本規約は、Toho-Studio（以下「本アプリケーション」）の利用条件を定めるものです。本アプリケーションは東方Projectの二次創作活動を促進・支援するためのマルチメディアクリエイティブ統合ツールであり、利用者は上海アリス幻樂団様の定める「東方Project二次創作ガイドライン」を完全に遵守して利用するものとします。")
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.25, green: 0.28, blue: 0.35))

                Text("第2条（内蔵ソフトおよび機能の利用）")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.16, green: 0.22, blue: 0.30))
                Text("利用者は、ムービーメーカー、キャラクターメーカー、サウンドメーカー、スライド＆シナリオメーカー、ゲームメーカー、素材スタジオの各ソフトを無償または有償プランに基づき利用できます。制作された二次創作作品の権利は原則として制作者に帰属しますが、東方Projectの原著作権は上海アリス幻樂団様に帰属します。")
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.25, green: 0.28, blue: 0.35))

                Text("第3条（禁止事項）")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.16, green: 0.22, blue: 0.30))
                Text("利用者は以下の行為を行ってはなりません。\n1. 原作者・上海アリス幻樂団様および関係者の名誉を毀損する行為\n2. 公式作品と誤認・混同させるような態様での公開・販売行為\n3. 東方Projectの二次創作ガイドラインに明確に違反する過激な表現の無制限配信\n4. 不正なクラッキング、リバースエンジニアリング、ライセンス認証の回避")
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.25, green: 0.28, blue: 0.35))

                Text("第4条（免責事項）")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.16, green: 0.22, blue: 0.30))
                Text("本アプリケーションの利用によって生じたいかなる損害についても、重大な過失がある場合を除き、開発者および提供者は責任を負いかねます。")
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.25, green: 0.28, blue: 0.35))
            }
        }
    }

    private var privacyView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Toho-Studio プライバシーポリシー")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

            Group {
                Text("第1条（個人情報の収集）")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.16, green: 0.22, blue: 0.30))
                Text("本アプリケーションは、アカウント認証、クラウド同期、素材ストアおよびライセンス管理のため、必要な範囲でユーザーのメールアドレス、氏名、利用環境情報を収集・保存します。")
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.25, green: 0.28, blue: 0.35))

                Text("第2条（利用目的）")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.16, green: 0.22, blue: 0.30))
                Text("収集した情報は、以下の目的のみに使用されます。\n・NanndemoyaCloudおよびGoogleアカウントとの連携認証\n・ストア購入明細およびライセンスキーの適用状態の確認\n・アプリケーションのクラッシュログ・バグレポートの集計と品質改善")
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.25, green: 0.28, blue: 0.35))

                Text("第3条（第三者提供の制限）")
                    .font(.headline)
                    .foregroundColor(Color(red: 0.16, green: 0.22, blue: 0.30))
                Text("法令に基づく場合を除き、利用者の同意なく個人情報を第三者に提供・開示することはありません。")
                    .font(.system(size: 13))
                    .foregroundColor(Color(red: 0.25, green: 0.28, blue: 0.35))
            }
        }
    }

    private var commercialView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("特定商取引法に基づく表記")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

            VStack(alignment: .leading, spacing: 10) {
                commercialRow(title: "販売事業者名", value: "何でも屋 / Toho-Studio プロジェクト")
                commercialRow(title: "運営統括責任者", value: "ズヤシ (zuyasi)")
                commercialRow(title: "所在地", value: "埼玉県さいたま市桜区田島1丁目16番15-2号 (〒338-0837)")
                commercialRow(title: "電話番号", value: "070-9075-8210")
                commercialRow(title: "連絡先メール", value: "japan.saitama.nanndemoya@gmail.com")
                commercialRow(title: "販売価格", value: "各製品・プランごとに画面表示（表示価格は消費税込み）")
                commercialRow(title: "お支払い方法", value: "ベースパック（事前デポジット）、PayPal、クレジットカード")
                commercialRow(title: "役務提供時期", value: "決済完了後、即時（NanndemoyaAI申請書等は手動審査・反映）")
                commercialRow(title: "キャンセル・返品規定", value: "デジタルコンテンツの性質上、購入完了後の返品・返金は原則不可。身に覚えのない明細や金額相違時は専用フォームより受付。")
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white).shadow(color: Color.black.opacity(0.05), radius: 2))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(red: 0.82, green: 0.88, blue: 0.94), lineWidth: 1)
            )

            Link("特定商取引法に基づく表記 (Webページ) ↗️", destination: URL(string: "https://www.nanndemoya.net/policy/act-on-specified-commercial-transactions")!)
                .font(.system(size: 12))
                .padding(.top, 6)
        }
    }

    private func commercialRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .frame(width: 140, alignment: .leading)
            Text(value)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Spacer()
        }
    }
}
