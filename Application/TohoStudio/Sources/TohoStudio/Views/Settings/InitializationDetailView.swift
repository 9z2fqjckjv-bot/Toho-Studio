import SwiftUI

public struct InitializationDetailView: View {
    @State private var selectedSubCategory: SubCategory = .works
    @State private var worksList: [InitTargetItem] = [
        InitTargetItem(itemNo: 1, name: "東方録第1話", dataSize: "500 MB", isChecked: false),
        InitTargetItem(itemNo: 2, name: "学園生活", dataSize: "10 GB", isChecked: false),
        InitTargetItem(itemNo: 3, name: "総集編", dataSize: "1 GB", isChecked: false),
        InitTargetItem(itemNo: 4, name: "僕とこいしの恋物語", dataSize: "100 MB", isChecked: false),
        InitTargetItem(itemNo: 5, name: "紅魔館はなぜ爆発するのか", dataSize: "250 MB", isChecked: false)
    ]

    @State private var materialsList: [InitTargetItem] = [
        InitTargetItem(itemNo: 1, name: "こいしパジャマ微笑", dataSize: "50 MB", isChecked: false),
        InitTargetItem(itemNo: 2, name: "フラン後ろ手余裕", dataSize: "50 MB", isChecked: false),
        InitTargetItem(itemNo: 3, name: "霊夢の〇〇.mp3", dataSize: "1 GB", isChecked: false),
        InitTargetItem(itemNo: 4, name: "自主規制音.mp3", dataSize: "100 MB", isChecked: false)
    ]

    @State private var showingResetAlert = false
    @State private var showingAllInitAlert = false

    public enum SubCategory: String, CaseIterable {
        case works = "作品を選んで初期化"
        case materials = "素材を選んで初期化"
        case cookieCache = "Cookie及びキャッシュの削除"
        case history = "履歴データの削除"
        case resetSettings = "設定のリセット"
        case fullInit = "全初期化"
    }

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // Column 3: Subcategory Selector
            VStack(spacing: 8) {
                ForEach(SubCategory.allCases, id: \.self) { cat in
                    KeynoteColumnButton(
                        title: cat.rawValue,
                        isSelected: selectedSubCategory == cat,
                        isDanger: cat == .resetSettings || cat == .fullInit
                    ) {
                        selectedSubCategory = cat
                    }
                }
                Spacer()
            }
            .frame(width: 170)
            .padding(.horizontal, 10)
            .padding(.vertical, 16)
            .background(Color(red: 0.88, green: 0.92, blue: 0.96))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(selectedSubCategory.rawValue)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

                    switch selectedSubCategory {
                    case .works:
                        worksContent
                    case .materials:
                        materialsContent
                    case .cookieCache:
                        cookieCacheContent
                    case .history:
                        historyContent
                    case .resetSettings:
                        resetSettingsContent
                    case .fullInit:
                        fullInitContent
                    }
                }
                .padding(24)
            }
        }
        .alert(isPresented: $showingResetAlert) {
            Alert(
                title: Text("設定のリセット"),
                message: Text("全ての設定項目がデフォルトにリセットされます。ローカルアカウントをご利用の場合はアカウント情報が抹消され復元できません。実行しますか？"),
                primaryButton: .destructive(Text("リセットを実行")),
                secondaryButton: .cancel(Text("キャンセル"))
            )
        }
    }

    // MARK: - Works Content (Slide 139)
    private var worksContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 0) {
                HStack {
                    Text("選択").frame(width: 50, alignment: .center)
                    Text("作品No").frame(width: 60, alignment: .center)
                    Text("初期化作品の名称").frame(maxWidth: .infinity, alignment: .leading)
                    Text("データ量").frame(width: 90, alignment: .trailing)
                }
                .font(.system(size: 11, weight: .bold))
                .padding(8)
                .background(Color(red: 0.88, green: 0.92, blue: 0.96))

                Divider()

                ForEach($worksList) { $item in
                    HStack {
                        Toggle("", isOn: $item.isChecked)
                            .labelsHidden()
                            .frame(width: 50, alignment: .center)
                        Text("\(item.itemNo)").frame(width: 60, alignment: .center)
                        Text(item.name).frame(maxWidth: .infinity, alignment: .leading)
                        Text(item.dataSize).font(.system(size: 11, weight: .bold)).frame(width: 90, alignment: .trailing)
                    }
                    .font(.system(size: 11))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    Divider()
                }

                HStack {
                    Text("合計（全作品初期化）")
                        .font(.system(size: 11, weight: .bold))
                    Spacer()
                    Text("256 GB")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.blue)
                }
                .padding(10)
                .background(Color.gray.opacity(0.08))
            }
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

            HStack(spacing: 16) {
                Button("選択した作品を初期化") {}
                    .buttonStyle(.borderedProminent)

                Button("選択した作品を削除") {}
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
            }

            KeynoteAnnotationBubble("初期化をすると、編集記録や履歴が全て消えます。作品そのものを丸ごと消す場合は削除を選択します。\nまた、各ソフトの有料機能の独自機能追加を利用すると、より細かな項目の削除が可能になります。")
        }
    }

    // MARK: - Materials Content (Slide 140)
    private var materialsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 0) {
                HStack {
                    Text("選択").frame(width: 50, alignment: .center)
                    Text("素材No").frame(width: 60, alignment: .center)
                    Text("初期化素材の名称").frame(maxWidth: .infinity, alignment: .leading)
                    Text("データ量").frame(width: 90, alignment: .trailing)
                }
                .font(.system(size: 11, weight: .bold))
                .padding(8)
                .background(Color(red: 0.88, green: 0.92, blue: 0.96))

                Divider()

                ForEach($materialsList) { $item in
                    HStack {
                        Toggle("", isOn: $item.isChecked)
                            .labelsHidden()
                            .frame(width: 50, alignment: .center)
                        Text("\(item.itemNo)").frame(width: 60, alignment: .center)
                        Text(item.name).frame(maxWidth: .infinity, alignment: .leading)
                        Text(item.dataSize).font(.system(size: 11, weight: .bold)).frame(width: 90, alignment: .trailing)
                    }
                    .font(.system(size: 11))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    Divider()
                }

                HStack {
                    Text("合計（全素材初期化）")
                        .font(.system(size: 11, weight: .bold))
                    Spacer()
                    Text("256 GB")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.blue)
                }
                .padding(10)
                .background(Color.gray.opacity(0.08))
            }
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

            HStack(spacing: 16) {
                Button("選択した素材を初期化") {}
                    .buttonStyle(.borderedProminent)

                Button("選択した素材を削除") {}
                    .buttonStyle(.bordered)
                    .foregroundColor(.red)
            }

            KeynoteAnnotationBubble("初期化をすると、編集記録や履歴が全て消えます。素材そのものを丸ごと消す場合は削除を選択します。\nまた、各ソフトの有料機能の独自機能追加を利用すると、より細かな項目の削除が可能になります。")
        }
    }

    // MARK: - Cookie & Cache Content (Slide 141)
    private var cookieCacheContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("アプリ内ブラウザや作品や素材に紐づけられたCookie及びキャッシュ、一時保存データなどを全て削除します。\n削除内容によっては、アカウントの再ログインが必要となります。")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineSpacing(4)

            VStack(alignment: .leading, spacing: 12) {
                Button("アプリ内ブラウザのCookieとキャッシュを削除") {}
                    .buttonStyle(.bordered)
                Button("アプリ本体のCookieとキャッシュを削除") {}
                    .buttonStyle(.bordered)
                Button("アカウント関連のCookieとキャッシュを削除") {}
                    .buttonStyle(.bordered)
                Button("全てのCookieとキャッシュを削除") {}
                    .buttonStyle(.borderedProminent)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("カスタム設定（有料機能）")
                    .font(.system(size: 12, weight: .bold))
                Text("各ソフトの有料機能の独自機能追加を利用すると、個別に選択した項目の削除が可能になります。")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.08)))
        }
    }

    // MARK: - History Content (Slide 142)
    private var historyContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("アプリ内ブラウザ、アプリ本体、作品と素材などに紐づけられた履歴を全て削除します。")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                Button("アプリ内ブラウザに紐づく履歴を削除") {}
                    .buttonStyle(.bordered)
                Button("アプリ本体に紐づく履歴を削除") {}
                    .buttonStyle(.bordered)
                Button("作品と素材に紐づく履歴を削除") {}
                    .buttonStyle(.bordered)
                Button("全ての履歴を削除") {}
                    .buttonStyle(.borderedProminent)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("カスタム設定（有料機能）")
                    .font(.system(size: 12, weight: .bold))
                Text("各ソフトの有料機能の独自機能追加を利用すると、個別に選択した項目の削除が可能になります。")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.08)))
        }
    }

    // MARK: - Reset Settings Content (Slide 143)
    private var resetSettingsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("注意事項")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.red)

                Text("""
リセット前に以下の文章を必ずご一読ください。
本ソフトの設定リセットを行うと、全ての設定項目と内容がデフォルト設定になります。また、この仕様によって、これまでに作成してきた作品及び素材の履歴やCookie、キャッシュが消えてしまうことがあります。また、有料機能の利用ができなくなることもあり、アカウント、ライセンス情報、本人確認の情報も削除されます。アカウントからログアウトが実行されるため、設定リセット後、アカウントが必要な場合は、再ログインが必要です。また、ローカルアカウントをご利用の場合、アカウント情報が抹消され、再ログインはできません。この仕様により、そのアカウントに紐づく作品、素材などはアクセスができなくなる場合や、データが消える場合もございます。また、設定のリセットにはお時間がかかることがあります。エラーやバグ、データロスといったリスクを最小限に抑えるために、外部メモリーに作品や素材がある場合は、絶対に取り出さず、Macの電源を切る操作や、本アプリの終了（強制終了含む）は絶対におやめください。設定のリセットに関する詳細な内容などについては、実行前にヘルプガイドなどで必ずご確認ください。
""")
                .font(.system(size: 11))
                .lineSpacing(4)
                .foregroundColor(.secondary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.red.opacity(0.06)))

            Button(action: {
                showingResetAlert = true
            }) {
                Text("設定のリセットを実行する")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.red))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Full Init Content (Slide 144)
    private var fullInitContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("全初期化に関する最重要注意事項")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.red)

                Text("""
全初期化前に以下の文章を必ずご一読ください。
本ソフトの全初期化を行うと、以下のデータが抹消されます。
・アカウントデータ：ローカルアカウントのすべてのデータ
・作品と素材：ロックをかけた作品を除く、すべての作品と素材
・Cookie及びキャッシュ：アプリ本体やアプリ内ブラウザなど
・履歴：作品や素材の編集履歴、変更履歴、共有履歴などの履歴
・ライセンスデータ：すべてのライセンスと認証情報
・バグ及びログなどのレポート類：デバッグ用のすべての情報
・言語と地域：日本語、日本にリセット
""")
                .font(.system(size: 11))
                .lineSpacing(4)
                .foregroundColor(.secondary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.red.opacity(0.06)))

            Button(action: {
                showingResetAlert = true
            }) {
                Text("全初期化を実行する")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.8, green: 0.1, blue: 0.1)))
            }
            .buttonStyle(.plain)
        }
    }
}
