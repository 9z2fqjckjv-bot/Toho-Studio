import SwiftUI

public struct CloudSettingsDetailView: View {
    @State private var selectedSubCategory: SubCategory = .nanndemoya
    @State private var selectedNanndemoyaOption: NanndemoyaOption = .cloudSave
    @State private var showingDisconnectAlert = false
    @State private var defaultSavePath: String = "マイドライブ/Toho-Studio"

    public enum SubCategory: String, CaseIterable {
        case nanndemoya = "NanndemoyaCloud"
        case google = "Googleアカウント"
    }

    public enum NanndemoyaOption: String, CaseIterable {
        case cloudSave = "クラウド保存"
        case migration = "データ移行"
    }

    public enum GoogleOption: String, CaseIterable {
        case cloudOptions = "クラウドオプション"
        case disconnect = "連携の解除"
    }

    @State private var selectedGoogleOption: GoogleOption = .cloudOptions

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // Column 3: Subcategory Selector (NanndemoyaCloud / Googleアカウント)
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

            if selectedSubCategory == .nanndemoya {
                nanndemoyaSection
            } else {
                googleSection
            }
        }
        .alert(isPresented: $showingDisconnectAlert) {
            Alert(
                title: Text("Googleアカウント連携の解除"),
                message: Text("Googleアカウントとの連携を解除し、クラウド保存などのサービスの利用を中止します。\n連携解除後はデータロスに注意してください。また、解除後は自動で再起動がかかります。実行しますか？"),
                primaryButton: .destructive(Text("解除して再起動"), action: {
                    // Disconnect action
                }),
                secondaryButton: .cancel(Text("キャンセル"))
            )
        }
    }

    // MARK: - NanndemoyaCloud Section
    private var nanndemoyaSection: some View {
        HStack(spacing: 0) {
            // Column 4: Nanndemoya Options
            VStack(spacing: 8) {
                ForEach(NanndemoyaOption.allCases, id: \.self) { opt in
                    KeynoteColumnButton(
                        title: opt.rawValue,
                        isSelected: selectedNanndemoyaOption == opt
                    ) {
                        selectedNanndemoyaOption = opt
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
                    if selectedNanndemoyaOption == .cloudSave {
                        nanndemoyaCloudSaveContent
                    } else {
                        nanndemoyaMigrationContent
                    }
                }
                .padding(24)
            }
        }
    }

    private var nanndemoyaCloudSaveContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("NanndemoyaCloud クラウド保存設定")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

            KeynoteAnnotationBubble("これを選択すると、NanndemoyaCloudの画面がブラウザで開き、認証することで、指定した場所にデータを保存できます。この機能は無料だが、NanndemoyaCloud自体は有料。")

            VStack(alignment: .leading, spacing: 8) {
                Text("自動作成されるフォルダ構成")
                    .font(.system(size: 13, weight: .bold))

                VStack(alignment: .leading, spacing: 4) {
                    folderRow(icon: "folder.fill", text: "マイドライブ", level: 0)
                    folderRow(icon: "folder.fill", text: "Toho-Studio", level: 1)
                    folderRow(icon: "folder.fill", text: "Cloud-Saving", level: 2)
                    folderRow(icon: "folder.fill", text: "SoftWare", level: 3)
                    folderRow(icon: "doc.fill", text: "Movie (ムービーメーカー編集ファイル .tsvm)", level: 4)
                    folderRow(icon: "doc.fill", text: "Sound (サウンドメーカー編集ファイル .tssm)", level: 4)
                    folderRow(icon: "doc.fill", text: "Character (キャラクターメーカー編集ファイル .tscm)", level: 4)
                    folderRow(icon: "doc.fill", text: "Slides&Scenario (スライド＆シナリオ編集ファイル .tspm)", level: 4)
                    folderRow(icon: "doc.fill", text: "GameMarker (ゲームメーカー編集ファイル .tsgm)", level: 4)
                    folderRow(icon: "folder.fill", text: "MaterialStudio (素材スタジオの全ファイル)", level: 4)
                }
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))
            }

            Button(action: {
                if let url = URL(string: "https://www.nanndemoya.net/service-guide/subscription/nanndemoya-cloud") {
                    AppState.shared.openInAppBrowser(url: url, title: "NanndemoyaCloud 認証・設定")
                }
            }) {
                HStack {
                    Image(systemName: "cloud.fill")
                    Text("NanndemoyaCloudで認証してクラウド保存を設定する（内部ブラウザ）")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color(red: 0.12, green: 0.45, blue: 0.75)))
            }
            .buttonStyle(.plain)
        }
    }

    private func folderRow(icon: String, text: String, level: Int) -> some View {
        HStack(spacing: 6) {
            ForEach(0..<level, id: \.self) { _ in
                Text("    ")
            }
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(icon.contains("folder") ? .blue : .secondary)
            Text(text)
                .font(.system(size: 11))
        }
    }

    private var nanndemoyaMigrationContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Googleアカウントへのデータ移行")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

            KeynoteAnnotationBubble("NanndemoyaCloud上のToho-Studioのデータを個人向けのGoogleアカウントに丸ごと移行する。（NanndemoyaCloudの解約は別途必要。）")

            Text("移行対象データ：SoftWareフォルダ配下の全ての作品ファイル、音声・キャラクターデータ、素材スタジオの素材一式。")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Button(action: {
                // Migration action
            }) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Googleアカウントへデータ移行を開始する")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Google Account Section
    private var googleSection: some View {
        HStack(spacing: 0) {
            // Column 4: Google Options
            VStack(spacing: 8) {
                ForEach(GoogleOption.allCases, id: \.self) { opt in
                    KeynoteColumnButton(
                        title: opt.rawValue,
                        isSelected: selectedGoogleOption == opt,
                        isDanger: opt == .disconnect
                    ) {
                        selectedGoogleOption = opt
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
                    if selectedGoogleOption == .cloudOptions {
                        googleCloudOptionsContent
                    } else {
                        googleDisconnectContent
                    }
                }
                .padding(24)
            }
        }
    }

    private var googleCloudOptionsContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Googleアカウント クラウドオプション")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

            // 保存先のデフォルト
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("保存先のデフォルト")
                            .font(.system(size: 13, weight: .bold))
                        HStack {
                            Text(defaultSavePath)
                                .font(.system(size: 12))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(4)
                            Button("変更...") {
                                if let url = URL(string: "https://drive.google.com") {
                                    AppState.shared.openInAppBrowser(url: url, title: "Googleドライブ - デフォルト保存先の指定")
                                }
                            }
                            .font(.system(size: 11))
                        }
                    }

                    KeynoteAnnotationBubble("保存先を事前に指定する")
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

            // バックアップと同期（有料機能）
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("バックアップと同期（有料機能）")
                            .font(.system(size: 13, weight: .bold))
                        Text("複数の端末で作品や素材データを自動共有します。")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    KeynoteAnnotationBubble("別スライドに掲載\n（有料機能メニューより購入可能）")
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

            // External Links with Annotations conforming to Slide 63 and 仕様書補足事項
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 12) {
                    Button(action: {
                        if let url = URL(string: "https://console.cloud.google.com") {
                            AppState.shared.openInAppBrowser(url: url, title: "Google Cloud Console")
                        }
                    }) {
                        HStack {
                            Text("GoogleCloudとの関連付け ↗️")
                            Image(systemName: "safari")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)

                    KeynoteAnnotationBubble("CloudStorageなどの機能を関連づける（内部ブラウザで開く）")
                }

                HStack(alignment: .top, spacing: 12) {
                    Button(action: {
                        if let url = URL(string: "https://one.google.com") {
                            AppState.shared.openInAppBrowser(url: url, title: "Google One ストレージ管理")
                        }
                    }) {
                        HStack {
                            Text("ストレージ管理 ↗️")
                            Image(systemName: "safari")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)

                    KeynoteAnnotationBubble("GoogleOneを開く（内部ブラウザで開く）")
                }

                HStack(alignment: .top, spacing: 12) {
                    Button(action: {
                        if let url = URL(string: "https://myaccount.google.com") {
                            AppState.shared.openInAppBrowser(url: url, title: "Google アカウント管理")
                        }
                    }) {
                        HStack {
                            Text("アカウント管理 ↗️")
                            Image(systemName: "safari")
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)

                    KeynoteAnnotationBubble("Googleアカウントを開く（内部ブラウザで開く）")
                }
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))
        }
    }

    private var googleDisconnectContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Googleアカウント 連携の解除")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color.red)

            KeynoteAnnotationBubble("Googleアカウントとの連携を解除し、クラウド保存などのサービスの利用を中止する。（データロス注意）\n連携の解除後は自動で再起動がかかる。")

            Button(action: {
                showingDisconnectAlert = true
            }) {
                HStack {
                    Image(systemName: "xmark.circle.fill")
                    Text("連携を解除してアプリを再起動する")
                }
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.red))
            }
            .buttonStyle(.plain)
        }
    }
}
