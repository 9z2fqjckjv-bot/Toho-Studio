import SwiftUI

public struct CommonModalContainer<Content: View>: View {
    let title: String
    let subtitle: String?
    let icon: String
    @Binding var isPresented: Bool
    @ViewBuilder let content: Content

    public init(title: String, subtitle: String? = nil, icon: String, isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self._isPresented = isPresented
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    if let sub = subtitle {
                        Text(sub)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button(action: { isPresented = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.8))

            Divider()

            // Content
            ScrollView {
                content
                    .padding()
            }
        }
        .frame(minWidth: 560, minHeight: 440)
        .background(VisualEffectBackground())
        .cornerRadius(12)
        .shadow(radius: 20)
    }
}

public struct VisualEffectBackground: NSViewRepresentable {
    public func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .hudWindow
        return view
    }

    public func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

// MARK: - Status Comparison View (Slide 29, 30 & 仕様書補足事項 180行目)
public struct StatusComparisonModalView: View {
    @ObservedObject var appState = AppState.shared

    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("システムステータスおよびリソース比較表")
                .font(.title3)
                .bold()

            GroupBox(label: Label("メモリ消費量とMacの空き容量", systemImage: "memorychip")) {
                VStack(spacing: 12) {
                    HStack {
                        Text("Toho-Studio メモリ使用量:")
                        Spacer()
                        Text("412 MB").bold().foregroundColor(.blue)
                    }
                    ProgressView(value: 0.25)
                        .accentColor(.blue)

                    HStack {
                        Text("Mac 空きメモリ容量:")
                        Spacer()
                        Text("12.4 GB / 16.0 GB").bold().foregroundColor(.green)
                    }
                    ProgressView(value: 0.77)
                        .accentColor(.green)
                }
                .padding(8)
            }

            GroupBox(label: Label("ストレージ使用量と外部メモリの比較", systemImage: "internaldrive")) {
                VStack(spacing: 12) {
                    HStack {
                        Text("Toho-Studio プロジェクトデータ:")
                        Spacer()
                        Text("3.8 GB").bold().foregroundColor(.orange)
                    }
                    ProgressView(value: 0.08)
                        .accentColor(.orange)

                    HStack {
                        Text("作業ドライブ (ZSSD) 空き容量:")
                        Spacer()
                        Text("412.5 GB / 500.0 GB").bold().foregroundColor(.purple)
                    }
                    ProgressView(value: 0.82)
                        .accentColor(.purple)
                }
                .padding(8)
            }

            GroupBox(label: Label("バックグラウンド処理とフレームレート", systemImage: "speedometer")) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("現在のフレームレート制御:")
                        Text(appState.targetFpsMode).font(.headline).foregroundColor(.accentColor)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text("GPUレンダリング負荷:")
                        Text("14% (安定)").font(.headline).foregroundColor(.green)
                    }
                }
                .padding(8)
            }
        }
    }
}

// MARK: - Logs and Achievements Modal View
public struct LogsAndAchievementsModalView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selectedTab = 0

    public var body: some View {
        VStack(spacing: 16) {
            Picker("", selection: $selectedTab) {
                Text("システムログ").tag(0)
                Text("実績一覧").tag(1)
            }
            .pickerStyle(.segmented)

            if selectedTab == 0 {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(appState.logs) { item in
                        HStack(alignment: .top) {
                            Text(item.level)
                                .font(.caption)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(item.level == "ERROR" ? Color.red.opacity(0.2) : Color.blue.opacity(0.2))
                                .foregroundColor(item.level == "ERROR" ? .red : .blue)
                                .cornerRadius(4)
                            Text(item.message)
                                .font(.callout)
                            Spacer()
                            Text(item.timestamp, style: .time)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Divider()
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(appState.achievements) { ach in
                        HStack {
                            Image(systemName: ach.isUnlocked ? "trophy.fill" : "lock.fill")
                                .foregroundColor(ach.isUnlocked ? .yellow : .secondary)
                                .font(.title3)
                            VStack(alignment: .leading) {
                                Text(ach.title).font(.headline)
                                Text(ach.description).font(.caption).foregroundColor(.secondary)
                            }
                            Spacer()
                            if let date = ach.unlockedAt {
                                Text("解除済: \(date, style: .date)")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            } else {
                                Text("未解除")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Divider()
                    }
                }
            }
        }
    }
}

// MARK: - Policy Check Modal View
public struct PolicyCheckModalView: View {
    @ObservedObject var complianceService = ComplianceService.shared
    @State private var checkText: String = "霊夢「また異変の気配がするわね。早くあの妖怪たちを懲らしめに行きましょう！」"
    @State private var autoSanitizeApplied: Bool = false

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("プラットフォームポリシー照合と修正")
                .font(.headline)
            Text("YouTube、ニコニコ動画、Steam、Roblox、Epic Gamesおよび東方二次創作ガイドラインとリアルタイム照合します。")
                .font(.caption)
                .foregroundColor(.secondary)

            TextEditor(text: $checkText)
                .font(.system(.body, design: .monospaced))
                .frame(height: 100)
                .padding(4)
                .border(Color.secondary.opacity(0.3))

            HStack {
                Button(action: {
                    _ = complianceService.scanText(checkText)
                }) {
                    Label("ポリシー照合を実行", systemImage: "magnifyingglass.shield")
                }
                .buttonStyle(.borderedProminent)

                Button(action: {
                    checkText = complianceService.sanitizeText(checkText)
                    autoSanitizeApplied = true
                    _ = complianceService.scanText(checkText)
                }) {
                    Label("安全な単語へ一括置換", systemImage: "wand.and.stars")
                }
                .buttonStyle(.bordered)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                ForEach(complianceService.lastCheckResults) { result in
                    HStack {
                        Image(systemName: result.isCompliant ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(result.isCompliant ? .green : .orange)
                        VStack(alignment: .leading) {
                            Text(result.targetPlatform).bold()
                            Text(result.message).font(.caption).foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(6)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                }
            }
        }
    }
}
