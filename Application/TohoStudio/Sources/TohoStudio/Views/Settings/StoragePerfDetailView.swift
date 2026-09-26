import SwiftUI

public struct StoragePerfDetailView: View {
    @State private var selectedSubCategory: SubCategory = .storage
    @State private var selectedStorageOption: StorageOption = .details
    @State private var selectedPerfOption: PerfOption = .memoryStatus
    @State private var selectedFramerateMode: FramerateMode = .performancePriority
    @State private var showingQualityAlert = false
    @State private var showingCustomSheet = false

    public enum SubCategory: String, CaseIterable {
        case storage = "ストレージ"
        case performance = "パフォーマンス"
    }

    public enum StorageOption: String, CaseIterable {
        case details = "容量詳細"
        case reduction = "削減オプション"
    }

    public enum PerfOption: String, CaseIterable {
        case memoryStatus = "メモリステータス"
        case framerate = "フレームレート"
    }

    public enum FramerateMode: String, CaseIterable {
        case performancePriority = "パフォーマンス優先"
        case qualityPriority = "画質優先"
        case autoBalance = "バランス自動調整"
        case custom = "カスタム"
    }

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // Column 3: Subcategory Selector (ストレージ / パフォーマンス)
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

            if selectedSubCategory == .storage {
                storageSection
            } else {
                performanceSection
            }
        }
        .alert(isPresented: $showingQualityAlert) {
            Alert(
                title: Text("画質優先モードの確認"),
                message: Text("メディアを高品質の状態で表示、再生します。\nMacのスペックによっては、カクツキや処理落ちが起きる場合があります。この設定に変更しますか？"),
                primaryButton: .default(Text("変更する"), action: {
                    selectedFramerateMode = .qualityPriority
                }),
                secondaryButton: .cancel(Text("キャンセル"))
            )
        }
    }

    // MARK: - Storage Section (容量詳細 / 削減オプション)
    private var storageSection: some View {
        HStack(spacing: 0) {
            // Column 4: Storage Options
            VStack(spacing: 8) {
                ForEach(StorageOption.allCases, id: \.self) { opt in
                    KeynoteColumnButton(
                        title: opt.rawValue,
                        isSelected: selectedStorageOption == opt
                    ) {
                        selectedStorageOption = opt
                    }
                }
                Spacer()
            }
            .frame(width: 130)
            .padding(.horizontal, 10)
            .padding(.vertical, 16)
            .background(Color(red: 0.92, green: 0.95, blue: 0.98))

            Divider()

            // Main Details Area
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if selectedStorageOption == .details {
                        storageDetailsContent
                    } else {
                        storageReductionContent
                    }
                }
                .padding(24)
            }
        }
    }

    private var storageDetailsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("ストレージ容量詳細（機能別）")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

            // Storage Table conforming to Slide 57
            VStack(spacing: 0) {
                HStack {
                    Text("大分類").frame(width: 100, alignment: .leading)
                    Text("中分類").frame(width: 90, alignment: .leading)
                    Text("ファイル名").frame(width: 130, alignment: .leading)
                    Text("容量").frame(width: 60, alignment: .trailing)
                    Text("内容").frame(maxWidth: .infinity, alignment: .leading)
                }
                .font(.system(size: 11, weight: .bold))
                .padding(8)
                .background(Color(red: 0.88, green: 0.92, blue: 0.96))

                Divider()

                detailRow(major: "ムービーメーカー", middle: "プログラム", name: "起動.command", size: "100 MB", desc: "ムービーメーカーを起動するためのファイル")
                Divider()
                detailRow(major: "ムービーメーカー", middle: "作品", name: "東方操夢録第30話", size: "1 GB", desc: "編集ファイル")
                Divider()
                detailRow(major: "ムービーメーカー", middle: "アニメーション", name: "スライド01.mov", size: "60 MB", desc: "アニメーションムービー")
                Divider()
                detailRow(major: "サウンドメーカー", middle: "音声素材", name: "自主規制音.mp3", size: "10 MB", desc: "効果音ファイル")
                Divider()
                detailRow(major: "キャラクターメーカー", middle: "立ち絵", name: "霊夢表情差分.png", size: "25 MB", desc: "立ち絵グラフィック")
            }
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

            KeynoteAnnotationBubble("有料機能であるAIを入れると、各ファイルの詳細情報を見ることができます。")
        }
    }

    private func detailRow(major: String, middle: String, name: String, size: String, desc: String) -> some View {
        HStack {
            Text(major).font(.system(size: 11)).frame(width: 100, alignment: .leading)
            Text(middle).font(.system(size: 11)).frame(width: 90, alignment: .leading)
            Text(name).font(.system(size: 11, weight: .medium)).frame(width: 130, alignment: .leading)
            Text(size).font(.system(size: 11, weight: .bold)).frame(width: 60, alignment: .trailing)
            Text(desc).font(.system(size: 11)).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private var storageReductionContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("不要データの一括削減オプション")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

            // Reduction Table conforming to Slide 58
            VStack(spacing: 0) {
                HStack {
                    Text("削除候補のファイル").frame(width: 150, alignment: .leading)
                    Text("内容").frame(maxWidth: .infinity, alignment: .leading)
                    Text("解放可能な容量").frame(width: 100, alignment: .trailing)
                    Text("操作").frame(width: 70, alignment: .center)
                }
                .font(.system(size: 11, weight: .bold))
                .padding(8)
                .background(Color(red: 0.88, green: 0.92, blue: 0.96))

                Divider()

                reductionRow(name: "素材.zip", desc: "素材入りの圧縮ファイル（すでに展開済み）", size: "1 GB")
                Divider()
                reductionRow(name: "動画.mp4", desc: "YouTube投稿済み動画", size: "10 GB")
                Divider()
                reductionRow(name: "一時レンダリング.tmp", desc: "エフェクト展開キャッシュ", size: "3.2 GB")
            }
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))

            KeynoteAnnotationBubble("有料機能であるAIを入れると、各ファイルの詳細情報を見ることができます。また、アプリ拡張の有料機能を入れることで、ファイルの一括削除可能ファイルを増やし、無制限に実行することができます。")
        }
    }

    private func reductionRow(name: String, desc: String, size: String) -> some View {
        HStack {
            Text(name).font(.system(size: 11, weight: .medium)).frame(width: 150, alignment: .leading)
            Text(desc).font(.system(size: 11)).foregroundColor(.secondary).frame(maxWidth: .infinity, alignment: .leading)
            Text(size).font(.system(size: 11, weight: .bold)).foregroundColor(.blue).frame(width: 100, alignment: .trailing)
            Button("削除") {
                // Delete action
            }
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(RoundedRectangle(cornerRadius: 4).fill(Color.red.opacity(0.8)))
            .frame(width: 70, alignment: .center)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    // MARK: - Performance Section (メモリステータス / フレームレート)
    private var performanceSection: some View {
        HStack(spacing: 0) {
            // Column 4: Perf Options
            VStack(spacing: 8) {
                ForEach(PerfOption.allCases, id: \.self) { opt in
                    KeynoteColumnButton(
                        title: opt.rawValue,
                        isSelected: selectedPerfOption == opt
                    ) {
                        selectedPerfOption = opt
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
                    if selectedPerfOption == .memoryStatus {
                        perfMemoryContent
                    } else {
                        perfFramerateContent
                    }
                }
                .padding(24)
            }
        }
    }

    private var perfMemoryContent: some View {
        let sampleMemory: [ProcessMemoryUsage] = [
            ProcessMemoryUsage(processName: "ムービーメーカー", memoryGB: 1.2, percentage: 13.0, color: Color.blue),
            ProcessMemoryUsage(processName: "サウンドメーカー", memoryGB: 0.8, percentage: 13.0, color: Color.teal),
            ProcessMemoryUsage(processName: "Googleドライブ", memoryGB: 0.4, percentage: 6.0, color: Color.green),
            ProcessMemoryUsage(processName: "Gemini", memoryGB: 1.6, percentage: 26.0, color: Color.purple),
            ProcessMemoryUsage(processName: "Chrome", memoryGB: 0.5, percentage: 1.0, color: Color.orange),
            ProcessMemoryUsage(processName: "システムとOS", memoryGB: 2.5, percentage: 13.0, color: Color.gray),
            ProcessMemoryUsage(processName: "その他", memoryGB: 2.0, percentage: 28.0, color: Color.cyan)
        ]

        return VStack(alignment: .leading, spacing: 20) {
            Text("このソフトのメモリ利用状態")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

            HStack(alignment: .top, spacing: 30) {
                VStack {
                    Text("メモリ占有率")
                        .font(.system(size: 13, weight: .bold))
                    SettingsPieChartView(items: sampleMemory)
                        .frame(width: 160, height: 160)
                        .padding(10)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("メモリ占有プロセス")
                        .font(.system(size: 13, weight: .bold))
                    SettingsBarChartView(items: sampleMemory, maxVal: 3.0)
                        .frame(width: 270)
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))
        }
    }

    private var perfFramerateContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("フレームレートと画質設定")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(Color(red: 0.12, green: 0.28, blue: 0.45))

            // 4 modes conforming to Slide 60
            VStack(alignment: .leading, spacing: 14) {
                // 1. パフォーマンス優先
                HStack(alignment: .top, spacing: 12) {
                    Button(action: {
                        selectedFramerateMode = .performancePriority
                    }) {
                        HStack {
                            Image(systemName: selectedFramerateMode == .performancePriority ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(.blue)
                            Text("パフォーマンス優先")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .buttonStyle(.plain)

                    KeynoteAnnotationBubble("デフォルト設定")
                }

                // 2. 画質優先
                HStack(alignment: .top, spacing: 12) {
                    Button(action: {
                        showingQualityAlert = true
                    }) {
                        HStack {
                            Image(systemName: selectedFramerateMode == .qualityPriority ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(.blue)
                            Text("画質優先")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .buttonStyle(.plain)

                    KeynoteAnnotationBubble("選択時には、注意ポップアップを表示、確認後に選択する。")
                }

                // 3. バランス自動調整
                HStack(alignment: .top, spacing: 12) {
                    Button(action: {
                        selectedFramerateMode = .autoBalance
                    }) {
                        HStack {
                            Image(systemName: selectedFramerateMode == .autoBalance ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(.blue)
                            Text("バランス自動調整")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .buttonStyle(.plain)

                    KeynoteAnnotationBubble("有料機能のアプリ拡張を入れると選択可能。AIを入れるとスマートに。")
                }

                // 4. カスタム
                HStack(alignment: .top, spacing: 12) {
                    Button(action: {
                        selectedFramerateMode = .custom
                    }) {
                        HStack {
                            Image(systemName: selectedFramerateMode == .custom ? "largecircle.fill.circle" : "circle")
                                .foregroundColor(.blue)
                            Text("カスタム")
                                .font(.system(size: 14, weight: .bold))
                        }
                    }
                    .buttonStyle(.plain)

                    KeynoteAnnotationBubble("有料機能のアプリ拡張を入れると、利用可能。個別に条件分岐を設定。")
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white).shadow(color: .black.opacity(0.05), radius: 2))
        }
    }
}
