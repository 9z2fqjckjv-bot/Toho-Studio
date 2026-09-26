import SwiftUI

public struct PublishingDefaultsDetailView: View {
    @State private var selectedSubCategory: SubCategory = .newWork
    @State private var newWorkScope: String = "非公開"
    @State private var inProgressScope: String = "非公開"
    @State private var completedScope: String = "非公開"

    public enum SubCategory: String, CaseIterable {
        case newWork = "新規作成時の公開範囲"
        case inProgress = "作成中の作品の公開範囲"
        case completed = "完成済み作品の公開範囲"
    }

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // Column 3: Subcategory Selector (新規作成時 / 作成中 / 完成済み)
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
                    case .newWork:
                        newWorkContent
                    case .inProgress:
                        inProgressContent
                    case .completed:
                        completedContent
                    }
                }
                .padding(24)
            }
        }
    }

    // MARK: - New Work Scope (Slide 117)
    private var newWorkContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("現在のデフォルト公開範囲:").font(.system(size: 13, weight: .bold))
                    Text(newWorkScope).font(.system(size: 13, weight: .bold)).foregroundColor(.blue)
                }

                HStack(spacing: 12) {
                    Picker("公開範囲の変更", selection: $newWorkScope) {
                        Text("非公開（ローカルストレージ保存）").tag("非公開")
                        Text("限定公開（URL共有）").tag("限定公開")
                        Text("下書き（非公開下書き）").tag("下書き")
                        Text("公開（全体公開）").tag("公開")
                        Text("クラウド（クラウドストレージ保存）").tag("クラウド")
                    }
                    .frame(width: 260)

                    Button("デフォルトに戻す") {
                        newWorkScope = "非公開"
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

            KeynoteAnnotationBubble("非公開、限定公開、下書き、公開、クラウドのいずれかを設定できます。\n「非公開」にすると、ローカルストレージにのみ保存されます。")

            commonActionButtons
        }
    }

    // MARK: - In Progress Scope (Slide 118)
    private var inProgressContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("現在のデフォルト公開範囲:").font(.system(size: 13, weight: .bold))
                    Text(inProgressScope).font(.system(size: 13, weight: .bold)).foregroundColor(.blue)
                }

                HStack(spacing: 12) {
                    Picker("公開範囲の変更", selection: $inProgressScope) {
                        Text("非公開").tag("非公開")
                        Text("限定公開").tag("限定公開")
                        Text("公開").tag("公開")
                        Text("クラウド").tag("クラウド")
                    }
                    .frame(width: 220)

                    Button("デフォルトに戻す") {
                        inProgressScope = "非公開"
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

            KeynoteAnnotationBubble("非公開、限定公開、公開、クラウドのいずれかを設定できます。")

            commonActionButtons
        }
    }

    // MARK: - Completed Work Scope (Slide 119)
    private var completedContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("現在のデフォルト公開範囲:").font(.system(size: 13, weight: .bold))
                    Text(completedScope).font(.system(size: 13, weight: .bold)).foregroundColor(.blue)
                }

                HStack(spacing: 12) {
                    Picker("公開範囲の変更", selection: $completedScope) {
                        Text("非公開").tag("非公開")
                        Text("限定公開").tag("限定公開")
                        Text("投稿（SNS・動画サイトへ自動投稿）").tag("投稿")
                        Text("公開").tag("公開")
                        Text("クラウド").tag("クラウド")
                    }
                    .frame(width: 280)

                    Button("デフォルトに戻す") {
                        completedScope = "非公開"
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

            HStack(alignment: .top, spacing: 12) {
                Button("投稿サイト及びSNSの連携設定") {}
                    .buttonStyle(.borderedProminent)

                KeynoteAnnotationBubble("公開範囲を「投稿」にするには、先に連携設定をしてください。")
            }

            commonActionButtons

            // Supported Platform Lists
            VStack(alignment: .leading, spacing: 10) {
                Text("投稿サイトおよびSNSの連携設定に対応予定のサービス")
                    .font(.system(size: 12, weight: .bold))
                Text("YouTube、ニコニコ動画、X、Instagram、Facebook")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)

                Divider()

                Text("※ゲームメーカーの作品公開限定の連携設定に対応予定のサービス")
                    .font(.system(size: 12, weight: .bold))
                Text("Steam、Roblox、EpicGames")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.gray.opacity(0.06)))
        }
    }

    private var commonActionButtons: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                Button("クラウドへの保存設定") {}
                    .buttonStyle(.bordered)

                KeynoteAnnotationBubble("クラウド連携の設定が開きます。")
            }

            HStack(alignment: .top, spacing: 12) {
                Button("クラウド自動保存とバックアップ及び同期の設定（有料）") {}
                    .buttonStyle(.bordered)

                KeynoteAnnotationBubble("クラウド機能の設定が開きます。")
            }
        }
    }
}
