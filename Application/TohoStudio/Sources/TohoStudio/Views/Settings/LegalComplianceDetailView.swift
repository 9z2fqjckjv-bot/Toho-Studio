import SwiftUI

public struct LegalComplianceDetailView: View {
    @State private var selectedSubCategory: SubCategory = .legal
    @State private var selectedLegalOption: LegalOption = .tokusho
    @State private var selectedComplianceOption: ComplianceOption = .regulatory

    public enum SubCategory: String, CaseIterable {
        case legal = "法規制"
        case compliance = "コンプライアンス"
    }

    public enum LegalOption: String, CaseIterable {
        case tokusho = "特商表記の管理"
        case rights = "権利の管理"
    }

    public enum ComplianceOption: String, CaseIterable {
        case regulatory = "法令遵守の確認"
        case policyCheck = "ポリシー照合"
    }

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // Column 3: Subcategory Selector (法規制 / コンプライアンス)
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

            if selectedSubCategory == .legal {
                legalSection
            } else {
                complianceSection
            }
        }
    }

    // MARK: - Legal Section (Slides 110, 111)
    private var legalSection: some View {
        HStack(spacing: 0) {
            VStack(spacing: 8) {
                ForEach(LegalOption.allCases, id: \.self) { opt in
                    KeynoteColumnButton(
                        title: opt.rawValue,
                        isSelected: selectedLegalOption == opt
                    ) {
                        selectedLegalOption = opt
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
                VStack(alignment: .leading, spacing: 20) {
                    if selectedLegalOption == .tokusho {
                        tokushoContent
                    } else {
                        rightsContent
                    }
                }
                .padding(24)
            }
        }
    }

    private var tokushoContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("特商表記の管理（特定商取引法に基づく表記）")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("設定状況:").font(.system(size: 13, weight: .bold))
                    Text("設定済み").font(.system(size: 13)).foregroundColor(.green)
                    Spacer()
                    Button("内容の確認と変更") {}
                        .buttonStyle(.bordered)
                }

                Divider()

                HStack {
                    Text("認定状況:").font(.system(size: 13, weight: .bold))
                    Text("認定審査中").font(.system(size: 13)).foregroundColor(.orange)
                    Spacer()
                    Text("審査申請日: 2026/09/24").font(.system(size: 11)).foregroundColor(.secondary)
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

            KeynoteAnnotationBubble("特商表記を変更すると、自動で「何でも屋」のシステム上に、認定審査の申請通知が行き、認定済みになると、反映され、利用者の作品と素材に表示されます。")

            HStack(spacing: 16) {
                Button("ヘルプを開く") {}
                Button("ドキュメントを開く") {}
                Button("サポートを開く") {}
            }
            .font(.system(size: 12))
            .foregroundColor(.blue)
        }
    }

    private var rightsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("権利の管理（Slide 111）")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

            // 公開範囲と権利一覧表
            VStack(alignment: .leading, spacing: 8) {
                Text("公開範囲と権利一覧表")
                    .font(.system(size: 13, weight: .bold))

                VStack(spacing: 0) {
                    HStack {
                        Text("作品No").frame(width: 60, alignment: .center)
                        Text("公開範囲").frame(width: 80, alignment: .center)
                        Text("利用形態").frame(width: 80, alignment: .center)
                        Text("収益化").frame(width: 80, alignment: .center)
                        Text("商業利用").frame(width: 80, alignment: .center)
                        Spacer()
                    }
                    .font(.system(size: 11, weight: .bold))
                    .padding(8)
                    .background(Color(red: 0.88, green: 0.92, blue: 0.96))

                    Divider()
                    rightsTableRow(no: 1, p: "○", u: "○", m: "○", c: "○")
                    Divider()
                    rightsTableRow(no: 2, p: "△", u: "△", m: "△", c: "△")
                    Divider()
                    rightsTableRow(no: 3, p: "×", u: "×", m: "×", c: "×")
                }
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))
            }

            // ステータス一覧表
            VStack(alignment: .leading, spacing: 8) {
                Text("ステータス一覧表（記号の意味）")
                    .font(.system(size: 13, weight: .bold))

                VStack(spacing: 0) {
                    HStack {
                        Text("カテゴリ").frame(width: 100, alignment: .leading)
                        Text("記号").frame(width: 50, alignment: .center)
                        Text("内容・利用規約").frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .font(.system(size: 11, weight: .bold))
                    .padding(8)
                    .background(Color(red: 0.88, green: 0.92, blue: 0.96))

                    Divider()
                    statusTableRow(cat: "公開範囲", sym: "○", desc: "公開…誰でも閲覧可能")
                    statusTableRow(cat: "公開範囲", sym: "△", desc: "限定公開…リンク共有者のみ")
                    statusTableRow(cat: "公開範囲", sym: "×", desc: "非公開…自分だけ閲覧可能")
                    Divider()
                    statusTableRow(cat: "利用形態", sym: "○", desc: "法人・個人を問わず自由に利用可能")
                    statusTableRow(cat: "利用形態", sym: "△", desc: "個人利用のみ可能（非商用）")
                    statusTableRow(cat: "利用形態", sym: "×", desc: "自分だけ利用可能（複製・転載禁止）")
                    Divider()
                    statusTableRow(cat: "収益化", sym: "○", desc: "誰でも収益化可能")
                    statusTableRow(cat: "収益化", sym: "△", desc: "作成者に事前通告またはクレジットで○")
                    statusTableRow(cat: "収益化", sym: "×", desc: "収益化不可")
                    Divider()
                    statusTableRow(cat: "商業利用", sym: "○", desc: "誰でも商業利用可能")
                    statusTableRow(cat: "商業利用", sym: "△", desc: "作成者と事前に個別相談が必要")
                    statusTableRow(cat: "商業利用", sym: "×", desc: "商業利用不可")
                }
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))
            }

            HStack(spacing: 16) {
                Button("ヘルプ") {}
                Button("ドキュメント") {}
                Button("お困りの場合（サポート）") {}
            }
            .font(.system(size: 12))
            .foregroundColor(.blue)
        }
    }

    private func rightsTableRow(no: Int, p: String, u: String, m: String, c: String) -> some View {
        HStack {
            Text("\(no)").frame(width: 60, alignment: .center)
            Text(p).frame(width: 80, alignment: .center).foregroundColor(colorForSymbol(p))
            Text(u).frame(width: 80, alignment: .center).foregroundColor(colorForSymbol(u))
            Text(m).frame(width: 80, alignment: .center).foregroundColor(colorForSymbol(m))
            Text(c).frame(width: 80, alignment: .center).foregroundColor(colorForSymbol(c))
            Spacer()
        }
        .font(.system(size: 12, weight: .bold))
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func statusTableRow(cat: String, sym: String, desc: String) -> some View {
        HStack {
            Text(cat).font(.system(size: 11)).frame(width: 100, alignment: .leading)
            Text(sym).font(.system(size: 12, weight: .bold)).frame(width: 50, alignment: .center).foregroundColor(colorForSymbol(sym))
            Text(desc).font(.system(size: 11)).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private func colorForSymbol(_ sym: String) -> Color {
        switch sym {
        case "○": return .green
        case "△": return .orange
        case "×": return .red
        default: return .primary
        }
    }

    // MARK: - Compliance Section (Slides 112, 113)
    private var complianceSection: some View {
        HStack(spacing: 0) {
            VStack(spacing: 8) {
                ForEach(ComplianceOption.allCases, id: \.self) { opt in
                    KeynoteColumnButton(
                        title: opt.rawValue,
                        isSelected: selectedComplianceOption == opt
                    ) {
                        selectedComplianceOption = opt
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
                VStack(alignment: .leading, spacing: 20) {
                    Text(selectedComplianceOption.rawValue)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("前回実施時の状況:").font(.system(size: 13, weight: .bold))
                            Text("OK（問題なし）").font(.system(size: 13)).foregroundColor(.green)
                            Spacer()
                            Text("実施日時: 2026/09/25 10:15").font(.system(size: 11)).foregroundColor(.secondary)
                        }

                        Divider()

                        HStack {
                            Text("認定状況:").font(.system(size: 13, weight: .bold))
                            Text("認定済み").font(.system(size: 13)).foregroundColor(.blue)
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

                    KeynoteAnnotationBubble("OKか、NG（利用者の端末上でローカル確認後、「何でも屋」側で審査）\nバックグラウンドでの確認は、今現在の作業が中断されないため、作業を続行できます。確認状況は確認終了時に通知されます。")

                    VStack(alignment: .leading, spacing: 12) {
                        Button("今すぐ確認する") {}
                            .buttonStyle(.borderedProminent)

                        Button("バックグラウンドで確認する") {}
                            .buttonStyle(.bordered)

                        Button(action: {
                            if let url = URL(string: "x-apple.systempreferences:") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Text("定期的な確認を追加する（Macのシステム設定を開く）")
                                .underline()
                                .font(.system(size: 12))
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 16) {
                        Button("ヘルプ") {}
                        Button("ドキュメント") {}
                        Button("サポート") {}
                    }
                    .font(.system(size: 12))
                    .foregroundColor(.blue)
                }
                .padding(24)
            }
        }
    }
}
