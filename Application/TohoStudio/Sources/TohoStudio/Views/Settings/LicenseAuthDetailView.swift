import SwiftUI
import AppKit

public struct LicenseAuthDetailView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var licenseManager = AquesTalkLicenseManager.shared

    @State private var selectedSubCategory: SubCategory = .aquesTalk
    @State private var selectedAquesTab: AquesTab = .aquesTalk1
    @State private var selectedNanndemoyaTab: NanndemoyaTab = .nanndemoyaDomain
    @State private var selectedNanndemoyaDomainPlan: NanndemoyaDomainPlan = .lite
    @State private var selectedCustomDomainPlan: CustomDomainPlan = .pro

    // Direct Inline Key Editor State
    @State private var inputRegularKeys: [AquesTalkTargetLibrary: String] = [:]
    @State private var inputDevKeys: [AquesTalkTargetLibrary: String] = [:]
    @State private var inputInclusiveDevKey: String = ""

    @State private var showPlainRegularKeys: [AquesTalkTargetLibrary: Bool] = [:]
    @State private var showPlainDevKeys: [AquesTalkTargetLibrary: Bool] = [:]
    @State private var showPlainInclusiveDevKey: Bool = false

    @State private var saveSuccessMessage: String? = nil
    @State private var showTroubleshootAlert: Bool = false

    public enum SubCategory: String, CaseIterable {
        case aquesTalk = "AquesTalk"
        case nanndemoyaCloud = "NanndemoyaCloud"
        case googleAccount = "Googleアカウント"
    }

    public enum AquesTab: String, CaseIterable, Identifiable {
        case aquesTalk1 = "AquesTalk1"
        case aquesTalk2 = "AquesTalk2"
        case aquesTalk10 = "AquesTalk10"
        case aquesTalk2KanjiKoe = "AquesTalk2KanjiKoe"
        case commercial = "使用ライセンス（まとめ）"
        case dev = "開発ライセンス（複数対応）"
        case aquesTalkPi = "AquesTalk Pi"
        case aquesTalkESP32 = "AquesTalk ESP32"
        case allOverview = "ライセンス一覧（全体確認）"
        case products = "関連製品の購入とお届け"

        public var id: String { rawValue }

        public var targetLibrary: AquesTalkTargetLibrary? {
            switch self {
            case .aquesTalk1: return .aquesTalk1
            case .aquesTalk2: return .aquesTalk2
            case .aquesTalk10: return .aquesTalk10
            case .aquesTalk2KanjiKoe: return .aquesTalk2KanjiKoe
            case .commercial: return .commercialUse
            case .dev: return .development
            case .aquesTalkPi: return .aquesTalkPi
            case .aquesTalkESP32: return .aquesTalkESP32
            default: return nil
            }
        }
    }

    public enum NanndemoyaTab: String, CaseIterable {
        case nanndemoyaDomain = "nanndemoyaドメイン"
        case customDomain = "独自ドメイン"
    }

    public enum NanndemoyaDomainPlan: String, CaseIterable {
        case lite = "Lite（.online）"
        case normal = "Normal（.net）"
        case plus = "Plus（.site）"
        case superPlus = "SuperPlus（.jp）"
        case superPremium = "SuperPremium（.org）"
    }

    public enum CustomDomainPlan: String, CaseIterable {
        case mini = "Mini"
        case standard = "Standard"
        case pro = "Pro"
        case superPro = "SuperPro"
        case superPremiumPro = "SuperPremiumPro"
    }

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // Column 3: Subcategory Selector (AquesTalk / NanndemoyaCloud / Googleアカウント)
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
            .frame(width: 150)
            .padding(.horizontal, 10)
            .padding(.vertical, 16)
            .background(Color(red: 0.88, green: 0.92, blue: 0.96))

            Divider()

            switch selectedSubCategory {
            case .aquesTalk:
                aquesTalkSection
            case .nanndemoyaCloud:
                nanndemoyaCloudSection
            case .googleAccount:
                googleAccountSection
            }
        }
        .onAppear {
            initializeInputKeys()
        }
        .alert(isPresented: $showTroubleshootAlert) {
            Alert(
                title: Text("通信状況に関するトラブルシューティング"),
                message: Text("AquesTalkの通信状況は正常にローカル動作しています。\n\nもし音声が再生されない場合：\n1. ライセンスキーが正しく入力されているか確認してください。\n2. 「SoundMaker」画面で別の声種（例: 女性1, 女性2）に切り替えてテストしてください。\n3. macOSの音声出力デバイスがミュートになっていないか確認してください。"),
                dismissButton: .default(Text("了解"))
            )
        }
    }

    private func initializeInputKeys() {
        for lib in AquesTalkTargetLibrary.allCases {
            inputRegularKeys[lib] = licenseManager.getRegularKey(for: lib)
            inputDevKeys[lib] = licenseManager.getDevKey(for: lib)
            showPlainRegularKeys[lib] = false
            showPlainDevKeys[lib] = false
        }
        inputInclusiveDevKey = licenseManager.getInclusiveDevKey()
        showPlainInclusiveDevKey = false
    }

    // MARK: - AquesTalk Section (Slides 120-130)
    private var aquesTalkSection: some View {
        HStack(spacing: 0) {
            // Column 4: Sub-tabs
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(AquesTab.allCases) { tab in
                        KeynoteColumnButton(
                            title: tab.rawValue,
                            isSelected: selectedAquesTab == tab
                        ) {
                            selectedAquesTab = tab
                            saveSuccessMessage = nil
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 14)
            }
            .frame(width: 175)
            .background(Color(red: 0.92, green: 0.95, blue: 0.98))

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if let msg = saveSuccessMessage {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(msg)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.green)
                            Spacer()
                            Button("閉じる") {
                                saveSuccessMessage = nil
                            }
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(6)
                    }

                    if selectedAquesTab == .products {
                        aquesProductsContent
                    } else if selectedAquesTab == .allOverview {
                        aquesAllOverviewContent
                    } else if selectedAquesTab == .dev {
                        aquesMultiDevLicenseContent
                    } else if selectedAquesTab == .commercial {
                        commercialUsageContent
                    } else if let target = selectedAquesTab.targetLibrary {
                        singleLibraryDetailContent(for: target)
                    }
                }
                .padding(24)
            }
        }
    }

    // MARK: - Dedicated Multi-Library Dev License Management View (開発ライセンス管理)
    private var aquesMultiDevLicenseContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Title & Description
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Image(systemName: "hammer.fill")
                        .foregroundColor(Color(red: 0.12, green: 0.35, blue: 0.65))
                    Text("開発ライセンス管理（複数ライブラリ個別対応）")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))
                }
                Text("AquesTalk音声合成エンジンを組み込んで開発・製品配布する際に必要な開発ライセンスキーを設定します。ライブラリごとの個別開発キー、または全ライブラリ共通の包括開発キーのどちらでも登録可能です。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            // 1. 包括開発ライセンスカード
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("包括開発ライセンス（全ライブラリ共通開発キー）")
                            .font(.system(size: 14, weight: .bold))
                        Text("全AquesTalkライブラリ（AquesTalk1, 2, 10, 2KanjiKoe, Pi, ESP32）に一括適用されます。")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    let hasInc = !licenseManager.getInclusiveDevKey().isEmpty
                    HStack(spacing: 4) {
                        Image(systemName: hasInc ? "checkmark.seal.fill" : "exclamationmark.circle")
                        Text(hasInc ? "包括開発キー登録済み" : "包括キー未設定")
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(hasInc ? .green : .secondary)
                }

                HStack(spacing: 8) {
                    let binding = Binding<String>(
                        get: { inputInclusiveDevKey.isEmpty ? licenseManager.getInclusiveDevKey() : inputInclusiveDevKey },
                        set: { inputInclusiveDevKey = $0 }
                    )

                    if showPlainInclusiveDevKey {
                        TextField("包括開発ライセンスキーを入力", text: binding)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 13, design: .monospaced))
                    } else {
                        SecureField("包括開発ライセンスキーを入力", text: binding)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 13, design: .monospaced))
                    }

                    Button(action: { showPlainInclusiveDevKey.toggle() }) {
                        Image(systemName: showPlainInclusiveDevKey ? "eye.slash" : "eye")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        if let clip = NSPasteboard.general.string(forType: .string) {
                            inputInclusiveDevKey = clip.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.clipboard")
                            Text("ペースト")
                        }
                        .font(.system(size: 11))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        let keyToSave = inputInclusiveDevKey.isEmpty ? licenseManager.getInclusiveDevKey() : inputInclusiveDevKey
                        licenseManager.setInclusiveDevKey(keyToSave)
                        saveSuccessMessage = "✓ 包括開発ライセンスキーを設定・保存しました。"
                    }) {
                        Text("設定 / 保存")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.12, green: 0.45, blue: 0.75))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    if !licenseManager.getInclusiveDevKey().isEmpty {
                        Button(action: {
                            licenseManager.removeInclusiveDevKey()
                            inputInclusiveDevKey = ""
                            saveSuccessMessage = "✓ 包括開発ライセンスキーを削除しました。"
                        }) {
                            Text("削除")
                                .font(.system(size: 11))
                                .foregroundColor(.red)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Button(action: {
                    if let url = URL(string: "https://store.a-quest.com") {
                        appState.openInAppBrowser(url: url, title: "AquesTalk 開発ライセンス購入")
                    }
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "safari")
                        Text("公式ストアで開発ライセンス（包括/個人/商用）を確認・購入 ↗️")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

            // 2. 各ライブラリ個別の開発ライセンス登録カード一覧
            VStack(alignment: .leading, spacing: 14) {
                Text("複数ライブラリの個別開発ライセンス登録")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

                Text("AquesTalk1, 2, 10, AqKanji2Koe などの各エンジンごとに個別の開発ライセンス証をお持ちの場合は、こちらでそれぞれの開発キーを登録できます。")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)

                ForEach(AquesTalkTargetLibrary.voiceLibraries) { lib in
                    libraryDevKeyRowCard(for: lib)
                }
            }

            KeynoteAnnotationBubble("各ライブラリの開発キーを設定すると、AquesTalkBridgeを通じて AquesTalk_SetDevKey および AqKanji2Koe_SetDevKey などの内部APIへ自動で注入されます。")
        }
    }

    private func libraryDevKeyRowCard(for lib: AquesTalkTargetLibrary) -> some View {
        let directKey = licenseManager.getDevKey(for: lib)
        let isDirect = !directKey.isEmpty
        let isInc = !licenseManager.getInclusiveDevKey().isEmpty
        let isDevAuth = isDirect || isInc
        let isPlain = showPlainDevKeys[lib] ?? false

        let binding = Binding<String>(
            get: { inputDevKeys[lib] ?? licenseManager.getDevKey(for: lib) },
            set: { inputDevKeys[lib] = $0 }
        )

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(lib.rawValue) 開発ライセンス")
                        .font(.system(size: 13, weight: .bold))
                    Text(lib.dylibDescription)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                Spacer()
                HStack(spacing: 4) {
                    Image(systemName: isDevAuth ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                    if isDirect {
                        Text("認証済み（個別キー適用）")
                    } else if isInc {
                        Text("認証済み（包括キー適用中）")
                    } else {
                        Text("未認証")
                    }
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(isDevAuth ? .green : .orange)
            }

            HStack(spacing: 8) {
                if isPlain {
                    TextField("\(lib.rawValue) 開発ライセンスキーを入力", text: binding)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 12, design: .monospaced))
                } else {
                    SecureField("\(lib.rawValue) 開発ライセンスキーを入力", text: binding)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.system(size: 12, design: .monospaced))
                }

                Button(action: { showPlainDevKeys[lib] = !isPlain }) {
                    Image(systemName: isPlain ? "eye.slash" : "eye")
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)

                Button(action: {
                    if let clip = NSPasteboard.general.string(forType: .string) {
                        inputDevKeys[lib] = clip.trimmingCharacters(in: .whitespacesAndNewlines)
                    }
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: "doc.on.clipboard")
                        Text("ペースト")
                    }
                    .font(.system(size: 10))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.gray.opacity(0.15))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)

                Button(action: {
                    let keyToSave = inputDevKeys[lib] ?? ""
                    licenseManager.setDevKey(keyToSave, for: lib)
                    saveSuccessMessage = "✓ \(lib.rawValue) の開発ライセンスキーを設定・保存しました。"
                }) {
                    Text("設定 / 保存")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color(red: 0.12, green: 0.45, blue: 0.75))
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)

                if isDirect {
                    Button(action: {
                        licenseManager.removeDevKey(for: lib)
                        inputDevKeys[lib] = ""
                        saveSuccessMessage = "✓ \(lib.rawValue) の個別開発キーを削除しました。"
                    }) {
                        Text("削除")
                            .font(.system(size: 10))
                            .foregroundColor(.red)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 5)
                    }
                    .buttonStyle(.plain)
                }

                Button(action: {
                    appState.openInAppBrowser(
                        url: lib.devPurchaseURL,
                        title: "\(lib.rawValue) 開発ライセンス購入"
                    )
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: "safari")
                        Text("購入 ↗️")
                    }
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.15, green: 0.55, blue: 0.35)))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.04), radius: 2))
    }

    // MARK: - Commercial Usage Inclusive Content (使用ライセンス（まとめ）)
    private var commercialUsageContent: some View {
        let lib = AquesTalkTargetLibrary.commercialUse
        let isAuth = !licenseManager.getRegularKey(for: lib).isEmpty
        let binding = Binding<String>(
            get: { inputRegularKeys[lib] ?? licenseManager.getRegularKey(for: lib) },
            set: { inputRegularKeys[lib] = $0 }
        )
        let isPlain = showPlainRegularKeys[lib] ?? false

        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(lib.displayName)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))
                Text(lib.dylibDescription)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("ライセンス状況:").font(.system(size: 14, weight: .bold))
                    HStack(spacing: 6) {
                        Image(systemName: isAuth ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(isAuth ? .green : .orange)
                        Text(isAuth ? "認証済み（全対象ライブラリに包括適用中）" : "未認証")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(isAuth ? .green : .orange)
                    }
                    Spacer()
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("商用向け使用ライセンスキーの設定と変更:")
                        .font(.system(size: 13, weight: .bold))

                    HStack(spacing: 8) {
                        if isPlain {
                            TextField("使用ライセンスキーを入力", text: binding)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 13, design: .monospaced))
                        } else {
                            SecureField("使用ライセンスキーを入力", text: binding)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(size: 13, design: .monospaced))
                        }

                        Button(action: { showPlainRegularKeys[lib] = !isPlain }) {
                            Image(systemName: isPlain ? "eye.slash" : "eye")
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            if let clip = NSPasteboard.general.string(forType: .string) {
                                inputRegularKeys[lib] = clip.trimmingCharacters(in: .whitespacesAndNewlines)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.on.clipboard")
                                Text("ペースト")
                            }
                            .font(.system(size: 11))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.gray.opacity(0.15))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            let keyToSave = inputRegularKeys[lib] ?? ""
                            licenseManager.setRegularKey(keyToSave, for: lib)
                            saveSuccessMessage = "✓ 使用ライセンスキーを設定・保存しました。"
                        }) {
                            Text("設定 / 保存")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Color(red: 0.12, green: 0.45, blue: 0.75))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)

                        if isAuth {
                            Button(action: {
                                licenseManager.removeRegularKey(for: lib)
                                inputRegularKeys[lib] = ""
                                saveSuccessMessage = "✓ 使用ライセンスキーを削除しました。"
                            }) {
                                Text("キーを削除")
                                    .font(.system(size: 11))
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    Text("※「使用ライセンス」を設定すると、AquesTalk1, 2, 10, 2KanjiKoe の各音声合成ライブラリがまとめて商用認証状態になります。")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Divider()

                HStack {
                    Button(action: {
                        appState.openInAppBrowser(
                            url: lib.regularPurchaseURL,
                            title: "\(lib.displayName) - 公式ストア"
                        )
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "safari")
                            Text("使用ライセンス（まとめて利用）を購入 ↗️")
                                .font(.system(size: 13, weight: .bold))
                            Text("（内部ブラウザで開く）")
                                .font(.system(size: 10))
                                .opacity(0.8)
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.15, green: 0.55, blue: 0.35)))
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }

                Divider()

                HStack {
                    Text("通信状況:").font(.system(size: 13, weight: .bold))
                    Text("正常").font(.system(size: 13, weight: .bold)).foregroundColor(.green)
                    Spacer()
                    Button("通信状況が正常ではない場合...") {
                        showTroubleshootAlert = true
                    }
                    .font(.system(size: 11))
                    .foregroundColor(.blue)
                    .buttonStyle(.plain)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))
        }
    }

    // MARK: - Single Library Detail Content (Slide 120: 開発ライセンスと通常ライセンスの両方を設定)
    private func singleLibraryDetailContent(for lib: AquesTalkTargetLibrary) -> some View {
        let isRegAuth = licenseManager.isRegularCertified(lib: lib)
        let isDevAuth = licenseManager.isDevCertified(lib: lib)
        let regStatusText = licenseManager.regularStatusText(for: lib)
        let devStatusText = licenseManager.devStatusText(for: lib)

        let regBinding = Binding<String>(
            get: { inputRegularKeys[lib] ?? licenseManager.getRegularKey(for: lib) },
            set: { inputRegularKeys[lib] = $0 }
        )
        let isRegPlain = showPlainRegularKeys[lib] ?? false

        let devBinding = Binding<String>(
            get: { inputDevKeys[lib] ?? licenseManager.getDevKey(for: lib) },
            set: { inputDevKeys[lib] = $0 }
        )
        let isDevPlain = showPlainDevKeys[lib] ?? false

        return VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(lib.displayName)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))
                    Spacer()
                    Text("Slide 120 準拠：開発と通常の両方を設定")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                }
                Text(lib.dylibDescription)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            // 1. 通常ライセンス設定セクション
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("① 通常ライセンス（使用ライセンス）設定")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: isRegAuth ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(isRegAuth ? .green : .orange)
                        Text(regStatusText)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isRegAuth ? .green : .orange)
                    }
                }

                HStack(spacing: 8) {
                    if isRegPlain {
                        TextField("\(lib.rawValue) 通常ライセンスキーを入力", text: regBinding)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 13, design: .monospaced))
                    } else {
                        SecureField("\(lib.rawValue) 通常ライセンスキーを入力", text: regBinding)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 13, design: .monospaced))
                    }

                    Button(action: { showPlainRegularKeys[lib] = !isRegPlain }) {
                        Image(systemName: isRegPlain ? "eye.slash" : "eye")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        if let clip = NSPasteboard.general.string(forType: .string) {
                            inputRegularKeys[lib] = clip.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.clipboard")
                            Text("ペースト")
                        }
                        .font(.system(size: 11))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        let keyToSave = inputRegularKeys[lib] ?? ""
                        licenseManager.setRegularKey(keyToSave, for: lib)
                        saveSuccessMessage = "✓ \(lib.rawValue) の通常ライセンスキーを設定・保存しました。"
                    }) {
                        Text("設定 / 保存")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.12, green: 0.45, blue: 0.75))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    if !licenseManager.getRegularKey(for: lib).isEmpty {
                        Button(action: {
                            licenseManager.removeRegularKey(for: lib)
                            inputRegularKeys[lib] = ""
                            saveSuccessMessage = "✓ \(lib.rawValue) の通常ライセンスキーを削除しました。"
                        }) {
                            Text("キーを削除")
                                .font(.system(size: 11))
                                .foregroundColor(.red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !licenseManager.getRegularKey(for: .commercialUse).isEmpty && licenseManager.getRegularKey(for: lib).isEmpty {
                    Text("※現在「使用ライセンス（まとめて利用）」が設定されているため、単体キーが未設定でも本ライブラリは商用認証済みとして動作します。")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                }

                Button(action: {
                    appState.openInAppBrowser(
                        url: lib.regularPurchaseURL,
                        title: "\(lib.displayName) 通常ライセンス購入"
                    )
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "safari")
                        Text(lib.purchaseButtonTitle)
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.15, green: 0.55, blue: 0.35)))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

            // 2. 開発ライセンス設定セクション
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("② 開発ライセンス設定")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))
                    Spacer()
                    HStack(spacing: 4) {
                        Image(systemName: isDevAuth ? "checkmark.seal.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(isDevAuth ? .green : .orange)
                        Text(devStatusText)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(isDevAuth ? .green : .orange)
                    }
                }

                HStack(spacing: 8) {
                    if isDevPlain {
                        TextField("\(lib.rawValue) 開発ライセンスキーを入力", text: devBinding)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 13, design: .monospaced))
                    } else {
                        SecureField("\(lib.rawValue) 開発ライセンスキーを入力", text: devBinding)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 13, design: .monospaced))
                    }

                    Button(action: { showPlainDevKeys[lib] = !isDevPlain }) {
                        Image(systemName: isDevPlain ? "eye.slash" : "eye")
                            .frame(width: 24, height: 24)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        if let clip = NSPasteboard.general.string(forType: .string) {
                            inputDevKeys[lib] = clip.trimmingCharacters(in: .whitespacesAndNewlines)
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "doc.on.clipboard")
                            Text("ペースト")
                        }
                        .font(.system(size: 11))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.15))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        let keyToSave = inputDevKeys[lib] ?? ""
                        licenseManager.setDevKey(keyToSave, for: lib)
                        saveSuccessMessage = "✓ \(lib.rawValue) の開発ライセンスキーを設定・保存しました。"
                    }) {
                        Text("設定 / 保存")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(Color(red: 0.12, green: 0.45, blue: 0.75))
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    if !licenseManager.getDevKey(for: lib).isEmpty {
                        Button(action: {
                            licenseManager.removeDevKey(for: lib)
                            inputDevKeys[lib] = ""
                            saveSuccessMessage = "✓ \(lib.rawValue) の開発ライセンスキーを削除しました。"
                        }) {
                            Text("キーを削除")
                                .font(.system(size: 11))
                                .foregroundColor(.red)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !licenseManager.getInclusiveDevKey().isEmpty && licenseManager.getDevKey(for: lib).isEmpty {
                    Text("※現在「包括開発ライセンス」が設定されているため、個別キーが未設定でも本ライブラリは開発認証済みとして動作します。")
                        .font(.system(size: 11))
                        .foregroundColor(.blue)
                }

                Button(action: {
                    appState.openInAppBrowser(
                        url: lib.devPurchaseURL,
                        title: "\(lib.displayName) 開発ライセンス購入"
                    )
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "safari")
                        Text(lib.devPurchaseButtonTitle)
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.2, green: 0.4, blue: 0.6)))
                }
                .buttonStyle(.plain)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

            // 3. 通信状況
            HStack {
                Text("通信状況:").font(.system(size: 13, weight: .bold))
                Text("正常").font(.system(size: 13, weight: .bold)).foregroundColor(.green)
                Spacer()
                Button("通信状況が正常ではない場合...") {
                    showTroubleshootAlert = true
                }
                .font(.system(size: 11))
                .foregroundColor(.blue)
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

            KeynoteAnnotationBubble("アクエスト社から発行された通常ライセンスキー・開発ライセンスキーを入力し「設定 / 保存」を押すと、直ちにシステムに記録され、音声合成エンジンに適用されます。")
        }
    }

    // MARK: - All Overview Table (Slide 129)
    private var aquesAllOverviewContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("AquesTalk 全ライセンス設定一覧（Slide 129）")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

            VStack(spacing: 0) {
                HStack {
                    Text("ライブラリ名").frame(width: 130, alignment: .leading)
                    Text("通常ライセンス").frame(width: 140, alignment: .leading)
                    Text("開発ライセンス").frame(width: 140, alignment: .leading)
                    Text("設定・変更").frame(width: 80, alignment: .center)
                    Text("公式ストア").frame(width: 90, alignment: .center)
                }
                .font(.system(size: 11, weight: .bold))
                .padding(8)
                .background(Color(red: 0.88, green: 0.92, blue: 0.96))

                Divider()

                ForEach(AquesTalkTargetLibrary.voiceLibraries) { lib in
                    overviewVoiceRow(lib: lib)
                    Divider()
                }

                overviewSpecialRow(lib: .commercialUse, title: "使用ライセンス（まとめ）", key: licenseManager.maskedRegularKey(for: .commercialUse), isAuth: !licenseManager.getRegularKey(for: .commercialUse).isEmpty)
                Divider()
                overviewSpecialRow(lib: .development, title: "包括開発ライセンス", key: licenseManager.maskedDevKey(for: .development), isAuth: !licenseManager.getInclusiveDevKey().isEmpty)
            }
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

            KeynoteAnnotationBubble("名称をクリックすると詳細画面へ移動し、直接キーの入力・編集・保存が可能です。「購入↗️」を押すとアプリケーション内ブラウザで公式ストアが開きます。")
        }
    }

    private func overviewVoiceRow(lib: AquesTalkTargetLibrary) -> some View {
        let isReg = licenseManager.isRegularCertified(lib: lib)
        let isDev = licenseManager.isDevCertified(lib: lib)

        return HStack {
            Button(action: {
                if let tab = AquesTab.allCases.first(where: { $0.targetLibrary == lib }) {
                    selectedAquesTab = tab
                }
            }) {
                Text(lib.rawValue)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.blue)
                    .frame(width: 130, alignment: .leading)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 2) {
                Text(isReg ? "✓ 認証済み" : "未認証")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isReg ? .green : .secondary)
                Text(licenseManager.maskedRegularKey(for: lib))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(width: 140, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(isDev ? "✓ 開発認証" : "未認証")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isDev ? .green : .secondary)
                Text(licenseManager.maskedDevKey(for: lib))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(width: 140, alignment: .leading)

            Button("設定・変更") {
                if let tab = AquesTab.allCases.first(where: { $0.targetLibrary == lib }) {
                    selectedAquesTab = tab
                }
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.12, green: 0.45, blue: 0.75)))
            .frame(width: 80, alignment: .center)
            .buttonStyle(.plain)

            Button(action: {
                appState.openInAppBrowser(
                    url: lib.regularPurchaseURL,
                    title: "\(lib.displayName) - 公式ストア"
                )
            }) {
                HStack(spacing: 2) {
                    Image(systemName: "safari")
                    Text("購入 ↗️")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.15, green: 0.55, blue: 0.35)))
            }
            .frame(width: 90, alignment: .center)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func overviewSpecialRow(lib: AquesTalkTargetLibrary, title: String, key: String, isAuth: Bool) -> some View {
        return HStack {
            Button(action: {
                if lib == .commercialUse {
                    selectedAquesTab = .commercial
                } else {
                    selectedAquesTab = .dev
                }
            }) {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.blue)
                    .frame(width: 130, alignment: .leading)
            }
            .buttonStyle(.plain)

            HStack {
                Text(isAuth ? "✓ 包括適用中" : "未設定")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(isAuth ? .green : .secondary)
                Text(key)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            .frame(width: 280, alignment: .leading)

            Button("設定・変更") {
                if lib == .commercialUse {
                    selectedAquesTab = .commercial
                } else {
                    selectedAquesTab = .dev
                }
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.12, green: 0.45, blue: 0.75)))
            .frame(width: 80, alignment: .center)
            .buttonStyle(.plain)

            Button(action: {
                appState.openInAppBrowser(
                    url: lib.purchaseURL,
                    title: "\(lib.displayName) - 公式ストア"
                )
            }) {
                HStack(spacing: 2) {
                    Image(systemName: "safari")
                    Text("購入 ↗️")
                }
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color(red: 0.15, green: 0.55, blue: 0.35)))
            }
            .frame(width: 90, alignment: .center)
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(red: 0.95, green: 0.97, blue: 1.0))
    }

    // MARK: - Products Content (Slide 130)
    private var aquesProductsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("関連製品の購入とお届け（Slide 130）")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

            Text("AquesTalkOnlineStore上に掲載しているライセンス以外の製品をお届けします。\n「何でも屋」のオーナー宅に郵送後、お客様の元にお運びするため、お届けまでに数日から1週間程度かかります。なお、製品への組み立て作業などは各自でお願いします。\nなお、Toho-Studio内のストアにて購入となります。購入には、NanndemoyaCloudの認証が必要です。また、ベースパック残高が製品の購入代金を上回る必要があります。なお、製品を購入すると、ベースパッククレジットのキャッシュバックを受け取れます。お届けには、製品代金に加え、移動代金も必要です。")
                .font(.system(size: 13))
                .lineSpacing(4)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

            HStack(spacing: 14) {
                Button(action: {
                    appState.activeModal = .store
                }) {
                    HStack {
                        Image(systemName: "cart.fill")
                        Text("ストアを開く")
                    }
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.12, green: 0.45, blue: 0.75)))
                }
                .buttonStyle(.plain)

                Button(action: {
                    if let url = URL(string: "https://store.a-quest.com") {
                        appState.openInAppBrowser(url: url, title: "AquesTalk 公式オンラインストア")
                    }
                }) {
                    HStack {
                        Image(systemName: "safari")
                        Text("AquesTalk公式ストアを内部ブラウザで開く ↗️")
                    }
                    .font(.system(size: 13))
                    .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - NanndemoyaCloud Section (Slides 121, 131-136)
    private var nanndemoyaCloudSection: some View {
        HStack(spacing: 0) {
            VStack(spacing: 8) {
                ForEach(NanndemoyaTab.allCases, id: \.self) { tab in
                    KeynoteColumnButton(
                        title: tab.rawValue,
                        isSelected: selectedNanndemoyaTab == tab
                    ) {
                        selectedNanndemoyaTab = tab
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
                VStack(alignment: .leading, spacing: 20) {
                    if selectedNanndemoyaTab == .nanndemoyaDomain {
                        nanndemoyaDomainContent
                    } else {
                        customDomainContent
                    }
                }
                .padding(24)
            }
        }
    }

    private var nanndemoyaDomainContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("NanndemoyaCloud - nanndemoyaドメイン")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

            // Domain plans
            HStack(spacing: 8) {
                ForEach(NanndemoyaDomainPlan.allCases, id: \.self) { plan in
                    Button(action: { selectedNanndemoyaDomainPlan = plan }) {
                        Text(plan.rawValue)
                            .font(.system(size: 11, weight: selectedNanndemoyaDomainPlan == plan ? .bold : .regular))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(selectedNanndemoyaDomainPlan == plan ? Color(red: 0.12, green: 0.32, blue: 0.53) : Color.gray.opacity(0.15))
                            .foregroundColor(selectedNanndemoyaDomainPlan == plan ? .white : .primary)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }

            // User Info Card
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color(red: 0.2, green: 0.5, blue: 0.8))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("東方 博麗")
                            .font(.system(size: 14, weight: .bold))
                        Text("hakurei_reimu@nanndemoya.online")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                HStack(spacing: 12) {
                    Button("ライセンスと認証情報") {}
                    Button("ブラウザで閲覧") {
                        if let url = URL(string: "https://www.nanndemoya.net") {
                            appState.openInAppBrowser(url: url, title: "NanndemoyaCloud")
                        }
                    }
                    Button("ログアウト") {}
                    Button("情報を更新") {}
                }
                .font(.system(size: 11))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))
        }
    }

    private var customDomainContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("NanndemoyaCloud - 独自ドメイン")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

            // Custom domain plans
            HStack(spacing: 8) {
                ForEach(CustomDomainPlan.allCases, id: \.self) { plan in
                    Button(action: { selectedCustomDomainPlan = plan }) {
                        Text(plan.rawValue)
                            .font(.system(size: 11, weight: selectedCustomDomainPlan == plan ? .bold : .regular))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selectedCustomDomainPlan == plan ? Color(red: 0.12, green: 0.32, blue: 0.53) : Color.gray.opacity(0.15))
                            .foregroundColor(selectedCustomDomainPlan == plan ? .white : .primary)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 16) {
                    Image(systemName: "building.2.crop.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(Color(red: 0.2, green: 0.6, blue: 0.4))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("博麗神社スタジオ")
                            .font(.system(size: 14, weight: .bold))
                        Text("studio@hakurei-shrine.jp")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        Text("プラン名: " + selectedCustomDomainPlan.rawValue)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.blue)
                    }
                }

                Divider()

                HStack(spacing: 12) {
                    Button("ライセンスと認証情報") {}
                    Button("ブラウザで閲覧") {
                        if let url = URL(string: "https://www.nanndemoya.net") {
                            appState.openInAppBrowser(url: url, title: "NanndemoyaCloud 独自ドメイン")
                        }
                    }
                    Button("ログアウト") {}
                    Button("情報を更新") {}
                }
                .font(.system(size: 11))
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

            KeynoteAnnotationBubble("Mini, Standard, Pro, SuperPro, SuperPremiumProのいずれかを選択可能です。")
        }
    }

    // MARK: - Google Account Section (Slide 137)
    private var googleAccountSection: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Googleアカウント 認証情報")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 16) {
                        Image(systemName: "g.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.red)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("霧雨 魔理沙")
                                .font(.system(size: 14, weight: .bold))
                            Text("marisa.kirisame@gmail.com")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        }
                    }

                    Divider()

                    HStack(spacing: 12) {
                        Button("アカウント情報") {}
                        Button("認証情報") {}
                        Button("ブラウザで閲覧") {
                            if let url = URL(string: "https://myaccount.google.com") {
                                appState.openInAppBrowser(url: url, title: "Google アカウント管理")
                            }
                        }
                        Button("ログアウト") {}
                        Button("情報を更新") {}
                    }
                    .font(.system(size: 11))
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))
            }
            .padding(24)
        }
    }
}
