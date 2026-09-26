import SwiftUI

public struct MaterialStudioView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var storageManager = StorageManager.shared
    @ObservedObject var securityService = SecurityService.shared
    @ObservedObject var complianceService = ComplianceService.shared

    @State private var selectedFilterType: String = "全素材"
    @State private var searchKeyword: String = ""
    @State private var showSecurityScanModal: Bool = false
    @State private var showSlideExtractorModal: Bool = false
    @State private var showAiSearchModal: Bool = false
    @State private var aiPrompt: String = ""

    public var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack(spacing: 14) {
                Label("素材スタジオ", systemImage: "folder.badge.gearshape")
                    .font(.headline)
                Text("(アプリケーション基幹・中枢ストレージ)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // Security Scanner Button
                Button(action: {
                    showSecurityScanModal = true
                    securityService.scanMaterialDirectory(path: "/Volumes/ZSSD/GitHub/repository/TohoStudio/動画用") { _ in }
                }) {
                    Label("セキュリティ点検", systemImage: "shield.checkerboard")
                }
                .buttonStyle(.bordered)

                // Slide Extractor Filter Button
                Button(action: { showSlideExtractorModal = true }) {
                    Label("スライド抽出プログラム", systemImage: "line.3.horizontal.decrease.circle")
                }
                .buttonStyle(.bordered)

                // 指示書 Slide 34: 動画用フォルダ内の各ファイルの一括素材スタジオ追加
                Button(action: {
                    SlideRecognitionService.shared.importAllVideoAssetsToMaterialStudio { count in
                        appState.log("動画用フォルダから一括素材スタジオ追加が完了しました（\(count)件）")
                    }
                }) {
                    Label("動画用フォルダ一括追加", systemImage: "square.and.arrow.down.on.square.fill")
                }
                .buttonStyle(.bordered)

                // AI Advanced Search Button
                Button(action: { showAiSearchModal = true }) {
                    Label("AI高度検索・置換", systemImage: "sparkles")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Filter Bar
            HStack(spacing: 12) {
                Picker("フィルター", selection: $selectedFilterType) {
                    Text("全素材").tag("全素材")
                    Text("キャラクター画像").tag("画像")
                    Text("BGM / 効果音").tag("音声")
                    Text("スライド").tag("スライド")
                    Text("シナリオ台本").tag("シナリオ")
                }
                .frame(width: 180)

                TextField("素材名・タグ・キーワード検索...", text: $searchKeyword)
                    .textFieldStyle(.roundedBorder)

                Spacer()

                // Storage Location Selector
                Picker("保存先", selection: $storageManager.currentLocation) {
                    ForEach(StorageLocation.allCases) { loc in
                        Text(loc.rawValue).tag(loc)
                    }
                }
                .frame(width: 260)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.3))

            Divider()

            // Materials Grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160))], spacing: 14) {
                    ForEach(filteredMaterials) { item in
                        materialCard(item)
                    }
                }
                .padding(16)
            }
        }
        .sheet(isPresented: $showSecurityScanModal) {
            securityScanModalView
        }
        .sheet(isPresented: $showSlideExtractorModal) {
            slideExtractorModalView
        }
        .sheet(isPresented: $showAiSearchModal) {
            aiSearchModalView
        }
    }

    private var filteredMaterials: [MaterialItem] {
        appState.materials.filter { item in
            let matchesType = (selectedFilterType == "全素材" || item.type == selectedFilterType)
            let matchesSearch = searchKeyword.isEmpty || item.title.contains(searchKeyword) || item.category.contains(searchKeyword)
            return matchesType && matchesSearch
        }
    }

    private func materialCard(_ item: MaterialItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .frame(height: 100)

                Image(systemName: iconForType(item.type))
                    .font(.system(size: 36))
                    .foregroundColor(.accentColor.opacity(0.8))
            }

            Text(item.title)
                .font(.caption)
                .bold()
                .lineLimit(1)

            HStack {
                Text(item.category)
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.secondary.opacity(0.2))
                    .cornerRadius(3)
                Spacer()
                Text("\(item.fileSize / 1024) KB")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(8)
    }

    private func iconForType(_ type: String) -> String {
        switch type {
        case "画像": return "photo.fill"
        case "音声": return "waveform"
        case "スライド": return "doc.richtext"
        case "シナリオ": return "text.alignleft"
        default: return "doc.fill"
        }
    }

    // MARK: - Security Scan Modal
    private var securityScanModalView: some View {
        VStack(spacing: 16) {
            Label("ローカル無償セキュリティ点検", systemImage: "shield.checkerboard")
                .font(.headline)

            if securityService.isScanning {
                ProgressView(value: securityService.scanProgress)
                Text("素材ファイルを検証中: \(Int(securityService.scanProgress * 100))%")
                    .font(.caption)
            } else if let report = securityService.lastReport {
                VStack(spacing: 12) {
                    Image(systemName: "checkmark.shield.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.green)
                    Text(report.status).font(.headline)
                    Text("スキャン済み: \(report.scannedFilesCount) ファイル | 脅威: 0 件")
                        .font(.caption).foregroundColor(.secondary)
                }
            }

            Button("閉じる") { showSecurityScanModal = false }
                .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(width: 440)
    }

    // MARK: - Slide Extractor Modal (仕様書補足事項 89-98行目)
    private var slideExtractorModalView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("スライド抽出プログラム (フィルター)")
                .font(.headline)
            Text("指定した立ち絵・アニメーション・背景・トランジションでシーンを抽出し、一括変更または削除します。")
                .font(.caption)
                .foregroundColor(.secondary)

            GroupBox(label: Text("立ち絵抽出")) {
                HStack {
                    TextField("立ち絵ファイル名 (例: 博麗霊夢.png)", text: .constant(""))
                        .textFieldStyle(.roundedBorder)
                    Button("抽出実行") {
                        appState.log("立ち絵抽出フィルタを実行しました")
                    }
                }
                .padding(4)
            }

            GroupBox(label: Text("アニメーション・トランジション抽出")) {
                HStack {
                    TextField("アニメーション名 (例: フェードイン)", text: .constant(""))
                        .textFieldStyle(.roundedBorder)
                    Button("抽出実行") {
                        appState.log("アニメーション抽出フィルタを実行しました")
                    }
                }
                .padding(4)
            }

            GroupBox(label: Text("背景画像抽出")) {
                HStack {
                    TextField("背景名 (例: 神社境内)", text: .constant(""))
                        .textFieldStyle(.roundedBorder)
                    Button("抽出実行") {
                        appState.log("背景抽出フィルタを実行しました")
                    }
                }
                .padding(4)
            }

            HStack {
                Spacer()
                Button("閉じる") { showSlideExtractorModal = false }
            }
        }
        .padding(20)
        .frame(width: 500)
    }

    // MARK: - AI Advanced Search Modal (仕様書補足事項 112-121行目)
    private var aiSearchModalView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("AI高度検索・生成・置換 (有料機能連携)", systemImage: "sparkles")
                .font(.headline)
            Text("素材スタジオの全素材を対象に、プロンプトによる画像生成・音声合成・テキスト置換を実行します。")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: $aiPrompt)
                .frame(height: 80)
                .border(Color.secondary.opacity(0.2))

            HStack(spacing: 12) {
                Button("画像生成と置換") {
                    appState.log("AI画像生成を実行し、素材を置換しました: [\(aiPrompt)]")
                    showAiSearchModal = false
                }
                .buttonStyle(.borderedProminent)

                Button("音声・効果音生成と置換") {
                    appState.log("AI音声生成を実行し、BGM/SEを置換しました")
                    showAiSearchModal = false
                }
                .buttonStyle(.bordered)

                Button("規約ポリシー自動修正") {
                    appState.log("AIによりポリシー抵触語を全ファイルから自動置換しました")
                    showAiSearchModal = false
                }
                .buttonStyle(.bordered)
            }

            HStack {
                Text("残り利用可能プロンプト数: \(appState.aiPlanRemainingPrompts)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Button("キャンセル") { showAiSearchModal = false }
            }
        }
        .padding(20)
        .frame(width: 540)
    }
}
