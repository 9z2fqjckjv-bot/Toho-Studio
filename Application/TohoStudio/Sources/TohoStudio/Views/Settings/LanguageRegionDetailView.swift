import SwiftUI
import AppKit

public struct LanguageRegionDetailView: View {
    @State private var selectedSubCategory: SubCategory = .language
    @State private var selectedLangOption: LangOption = .media
    @State private var selectedRegionOption: RegionOption = .gensokyoMap

    // Map image state (仕様書補足事項 527行目)
    @State private var mapImagePath: String = "/Volumes/ZSSD/GitHub/repository/TohoStudio/幻想郷マップ.jpeg"

    public enum SubCategory: String, CaseIterable {
        case language = "言語"
        case region = "地域"
    }

    public enum LangOption: String, CaseIterable {
        case media = "メディア"
        case app = "アプリ"
        case document = "ドキュメント"
        case proofreading = "校正"
        case reset = "リセット"
    }

    public enum RegionOption: String, CaseIterable {
        case country = "国または地域"
        case timeZone = "タイムゾーン"
        case workSettings = "作品設定"
        case constraints = "制約と表現方法"
        case gensokyoMap = "幻想郷の地図"
    }

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // Column 3: Subcategory Selector (言語 / 地域)
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
            .frame(width: 130)
            .padding(.horizontal, 10)
            .padding(.vertical, 16)
            .background(Color(red: 0.88, green: 0.92, blue: 0.96))

            Divider()

            if selectedSubCategory == .language {
                languageSection
            } else {
                regionSection
            }
        }
    }

    // MARK: - Language Section (Slides 92-98)
    private var languageSection: some View {
        HStack(spacing: 0) {
            VStack(spacing: 8) {
                ForEach(LangOption.allCases, id: \.self) { opt in
                    KeynoteColumnButton(
                        title: opt.rawValue,
                        isSelected: selectedLangOption == opt,
                        isDanger: opt == .reset
                    ) {
                        selectedLangOption = opt
                    }
                }
                Spacer()
            }
            .frame(width: 130)
            .padding(.horizontal, 10)
            .padding(.vertical, 16)
            .background(Color(red: 0.92, green: 0.95, blue: 0.98))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch selectedLangOption {
                    case .media:
                        langConfigBox(title: "メディアの言語（動画・画像・音声）", first: "日本語", second: "英語（米国）")
                    case .app:
                        langConfigBox(title: "アプリのUI言語", first: "日本語", second: "英語（米国）")
                    case .document:
                        langConfigBox(title: "ドキュメント・ヘルプの言語", first: "日本語", second: "英語（米国）")
                    case .proofreading:
                        proofreadingBox
                    case .reset:
                        langResetBox
                    }

                    KeynoteAnnotationBubble("言語を変更すると自動で再起動します。\n対応言語はG8各国の主要言語を予定しています。")
                }
                .padding(24)
            }
        }
    }

    private func langConfigBox(title: String, first: String, second: String) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

            VStack(alignment: .leading, spacing: 8) {
                Text("第１言語（最優先）")
                    .font(.system(size: 13, weight: .bold))
                HStack {
                    Text(first)
                        .font(.system(size: 13))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                    Button("変更") {}
                        .font(.system(size: 11))
                    Button("言語ファイルの再インストールと更新") {}
                        .font(.system(size: 11))
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

            VStack(alignment: .leading, spacing: 8) {
                Text("第２言語（第１言語が使えない場合）")
                    .font(.system(size: 13, weight: .bold))
                HStack {
                    Text(second)
                        .font(.system(size: 13))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(4)
                    Button("変更") {}
                        .font(.system(size: 11))
                    Button("言語ファイルの再インストールと更新") {}
                        .font(.system(size: 11))
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))
        }
    }

    private var proofreadingBox: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("校正機能の言語設定")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

            VStack(alignment: .leading, spacing: 10) {
                Toggle("東方Project専用固有名詞辞書を適用", isOn: .constant(true))
                Toggle("現代仮名遣いによる表記ゆれ自動チェック", isOn: .constant(true))
                Toggle("伏字・倫理チェック校正エンジンの有効化", isOn: .constant(true))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))
        }
    }

    private var langResetBox: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("言語設定のリセット")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.red)

            Text("全ての言語設定を以下のデフォルト設定にリセットします。\n・第1言語：日本語\n・第2言語：英語（米国）")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            Button("言語設定をデフォルトにリセット") {}
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.red))
                .buttonStyle(.plain)
        }
    }

    // MARK: - Region Section (Slides 99-108)
    private var regionSection: some View {
        HStack(spacing: 0) {
            VStack(spacing: 8) {
                ForEach(RegionOption.allCases, id: \.self) { opt in
                    KeynoteColumnButton(
                        title: opt.rawValue,
                        isSelected: selectedRegionOption == opt
                    ) {
                        selectedRegionOption = opt
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
                    switch selectedRegionOption {
                    case .country:
                        countryBox
                    case .timeZone:
                        timeZoneBox
                    case .workSettings:
                        workSettingsBox
                    case .constraints:
                        constraintsBox
                    case .gensokyoMap:
                        gensokyoMapBox
                    }
                }
                .padding(24)
            }
        }
    }

    private var countryBox: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("国または地域")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

            HStack {
                Text("現在の設定: 日本 (Japan)")
                    .font(.system(size: 13))
                Button("変更...") {}
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

            KeynoteAnnotationBubble("国名あるいは地域名の選択と変更を行います。")
        }
    }

    private var timeZoneBox: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("タイムゾーンと時計表示")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("タイムゾーン: 日本標準時 (JST, UTC+9)")
                        .font(.system(size: 13))
                    Button("変更...") {}
                }
                Divider()
                HStack {
                    Text("アプリ時計の表示形式: 24時間表記 (hh:mm)")
                        .font(.system(size: 13))
                    Button("変更（12時間/24時間）") {}
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

            KeynoteAnnotationBubble("タイムゾーンはG8の中から選択できます。\n時計表示は「AM(PM)hh:mm」または「hh:mm」形式で表示します。")
        }
    }

    private var workSettingsBox: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("作品設定テンプレート")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("地域観: 東方Projectの原作に基づく")
                        .font(.system(size: 13))
                    Spacer()
                    Button("編集") {}
                }
                Divider()
                HStack {
                    Text("世界観: 東方Projectの原作に基づく")
                        .font(.system(size: 13))
                    Spacer()
                    Button("編集") {}
                }
                Divider()
                HStack {
                    Text("作品制作クレジット: 未設定")
                        .font(.system(size: 13))
                    Spacer()
                    Button("編集") {}
                }
                Divider()
                HStack {
                    Text("制作ソフト表記: Toho-Studio")
                        .font(.system(size: 13))
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

            VStack(alignment: .leading, spacing: 8) {
                Text("プリセットテンプレート")
                    .font(.system(size: 13, weight: .bold))
                HStack(spacing: 12) {
                    Button("動画投稿サイト用テンプレート") {}
                    Button("SNS用テンプレート") {}
                    Button("テンプレートを新しく作成する") {}
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var constraintsBox: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("制約と表現方法（Slide 106）")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

            VStack(alignment: .leading, spacing: 12) {
                Toggle("性的描写の制約と自動伏字・ボカシフィルター", isOn: .constant(true))
                Toggle("暴力的描写・血液表現のフィルター（白黒化・警告テロップ）", isOn: .constant(true))
                Toggle("叡智表現・自主規制音の自動挿入", isOn: .constant(true))
                Toggle("投稿先プラットフォーム規約に基づく投稿リマインダー通知", isOn: .constant(true))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))
        }
    }

    // MARK: - Gensokyo Map (Slide 107)
    private var gensokyoMapBox: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("幻想郷の地図（Slide 107）")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

            VStack(alignment: .center, spacing: 12) {
                if let nsImg = NSImage(contentsOfFile: mapImagePath) {
                    Image(nsImage: nsImg)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 280)
                        .cornerRadius(6)
                        .shadow(color: .black.opacity(0.15), radius: 4)
                } else {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 200)
                        .overlay(Text("幻想郷マップ画像").foregroundColor(.secondary))
                }

                HStack(spacing: 20) {
                    Button("デフォルトに戻す") {
                        mapImagePath = "/Volumes/ZSSD/GitHub/repository/TohoStudio/幻想郷マップ.jpeg"
                    }
                    .buttonStyle(.bordered)

                    Button("画像を差し替え") {
                        let panel = NSOpenPanel()
                        panel.allowedContentTypes = [.jpeg, .png]
                        if panel.runModal() == .OK, let url = panel.url {
                            mapImagePath = url.path
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

            KeynoteAnnotationBubble("作品制作時に参照できる幻想郷全図です。お好みの地図画像に差し替えることも可能です。")
        }
    }
}
