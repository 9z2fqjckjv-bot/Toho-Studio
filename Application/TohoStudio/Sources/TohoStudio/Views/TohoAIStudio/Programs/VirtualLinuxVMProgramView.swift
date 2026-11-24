import SwiftUI
import AppKit

/// 仕様書「LLM入り仮想LinuxVM / 公開ゲートウェイとの通信確認」プログラム (V3.0対応版)
public struct VirtualLinuxVMProgramView: View {
    @ObservedObject var cloudLinuxService = CloudVirtualLinuxService.shared
    @ObservedObject var tohoAIService = TohoAIService.shared
    @State private var isRunningPingTest: Bool = false
    @State private var pingTestLogs: [String] = []
    @State private var editableServerURL: String = ""

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection
                endpointConfigCard
                connectionStatusCard
                vmSpecsCard
                diagnosticsCard
            }
            .padding(24)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            editableServerURL = cloudLinuxService.serverBaseURL
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "server.rack")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("TohoAIStudio 公開LLMゲートウェイ & 外部AI連携モニター")
                        .font(.title2)
                        .bold()
                }
                Text("Debian 13 ゲートウェイサーバ（MacMini / Cloudflare Tunnel 外部公開対応）と常時通信し、定額プランの3段階レート制御・NanndemoyaAPI中継・外部AIメディアAPI連携状況を管理します。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()

            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(cloudLinuxService.connectionStatus.rawValue)
                    .font(.subheadline)
                    .bold()
                    .foregroundColor(statusColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(statusColor.opacity(0.12))
            .cornerRadius(20)
        }
    }

    // MARK: - Endpoint Configuration Card (LAN開発 & 一般配布外部公開切替)
    private var endpointConfigCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "globe.asia.australia.fill")
                    .foregroundColor(.blue)
                Text("接続先ゲートウェイURL設定（LAN内開発 / 一般配布HTTPS公開エンドポイント）")
                    .font(.headline)
                Spacer()
            }

            HStack(spacing: 10) {
                TextField("例: https://ai.nanndemoya.net または http://debian.local:8095", text: $editableServerURL)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))

                Button("適用して再接続") {
                    var cleaned = editableServerURL.trimmingCharacters(in: .whitespacesAndNewlines)
                    if cleaned.hasSuffix("/") { cleaned.removeLast() }
                    if !cleaned.isEmpty {
                        cloudLinuxService.serverBaseURL = cleaned
                        cloudLinuxService.fetchServerPlans()
                        cloudLinuxService.syncUserStatusFromServer()
                        runDiagnosticPing()
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            HStack(spacing: 8) {
                Text("クイック切替:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                presetURLButton(label: "MacMini LAN (debian.local)", url: "http://debian.local:8095")
                presetURLButton(label: "MacMini IP (192.168.3.184)", url: "http://192.168.3.184:8095")
                presetURLButton(label: "外部公開ドメイン例 (HTTPS)", url: "https://ai.nanndemoya.net")
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }

    private func presetURLButton(label: String, url: String) -> some View {
        Button(label) {
            editableServerURL = url
            cloudLinuxService.serverBaseURL = url
            cloudLinuxService.fetchServerPlans()
            cloudLinuxService.syncUserStatusFromServer()
            runDiagnosticPing()
        }
        .font(.caption)
        .buttonStyle(.bordered)
    }

    // MARK: - Connection Status Card
    private var connectionStatusCard: some View {
        let q = cloudLinuxService.quotaStatus
        return VStack(alignment: .leading, spacing: 14) {
            Text("リアルタイム通信・レート枠ステータス")
                .font(.headline)

            HStack(spacing: 16) {
                statTile(
                    title: "レイテンシ (Ping)",
                    value: "\(cloudLinuxService.latencyMs) ms",
                    subtext: cloudLinuxService.isConnected ? "ゲートウェイ応答正常" : "未接続",
                    icon: "antenna.radiowaves.left.and.right",
                    color: cloudLinuxService.isConnected ? .green : .gray
                )

                statTile(
                    title: "契約中定額プラン",
                    value: q.plan_name,
                    subtext: "月額 ¥\(q.price_jpy)",
                    icon: "crown.fill",
                    color: .blue
                )

                statTile(
                    title: "総利用可能プロンプト",
                    value: "\(cloudLinuxService.remainingPrompts) 回",
                    subtext: "5時間残: \(q.windows.remaining_5hour) / 週残: \(q.windows.remaining_weekly)",
                    icon: "sparkles",
                    color: cloudLinuxService.remainingPrompts < 20 ? .orange : .green
                )

                statTile(
                    title: "最終ハートビート",
                    value: DateFormatter.localizedString(from: cloudLinuxService.lastHeartbeatAt, dateStyle: .none, timeStyle: .medium),
                    subtext: "5秒間隔自動同期",
                    icon: "heart.fill",
                    color: .red
                )
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }

    // MARK: - VM Specs Card
    private var vmSpecsCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Linuxゲートウェイ & 推論ルーター仕様")
                .font(.headline)

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
                GridRow {
                    Text("接続先エンドポイント:").foregroundColor(.secondary)
                    Text(cloudLinuxService.serverBaseURL).bold()

                    Text("リージョン/ゾーン:").foregroundColor(.secondary)
                    Text(cloudLinuxService.machineStatus.gcpZone).bold()
                }

                GridRow {
                    Text("システム構成:").foregroundColor(.secondary)
                    Text(cloudLinuxService.machineStatus.machineType)

                    Text("稼働推論エンジン:").foregroundColor(.secondary)
                    Text(cloudLinuxService.machineStatus.llmModel).bold().foregroundColor(.blue)
                }
            }
            .font(.subheadline)

            Divider()

            HStack(spacing: 24) {
                resourceBar(label: "CPU 使用率", percent: cloudLinuxService.machineStatus.cpuUsagePercent, color: .blue)
                resourceBar(label: "メモリ 使用率", percent: cloudLinuxService.machineStatus.memoryUsagePercent, color: .orange)
                let configuredCount = tohoAIService.configuredMediaProviderCount()
                let totalExternalProviders = AIMediaProviderType.externalProviders.count
                let ratio = totalExternalProviders > 0 ? (Double(configuredCount) / Double(totalExternalProviders)) * 100.0 : 0.0
                resourceBar(label: "外部メディアAPI登録率 (\(configuredCount)/\(totalExternalProviders))", percent: ratio, color: .green)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Diagnostics Card
    private var diagnosticsCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("通信確認・クォータ同期テスト")
                    .font(.headline)
                Spacer()

                Button(action: runDiagnosticPing) {
                    HStack(spacing: 6) {
                        if isRunningPingTest {
                            ProgressView().controlSize(.small)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                        Text("通信疎通テストを実行")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isRunningPingTest)
            }

            VStack(alignment: .leading, spacing: 6) {
                if pingTestLogs.isEmpty {
                    Text("※「通信疎通テストを実行」をクリックすると、ゲートウェイへのヘルスチェック、新料金プランカタログ取得、およびプロンプト残数同期を実行します。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    ForEach(pingTestLogs, id: \.self) { log in
                        Text(log)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(log.contains("SUCCESS") ? .green : (log.contains("ERROR") ? .red : .white))
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.black.opacity(0.85))
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }

    private var statusColor: Color {
        switch cloudLinuxService.connectionStatus {
        case .connected, .lowLatency: return .green
        case .suspendedPromptZero: return .red
        case .energySaving: return .orange
        case .disconnected: return .gray
        }
    }

    private func statTile(title: String, value: String, subtext: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.headline)
                .bold()
                .lineLimit(1)
            Text(subtext)
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }

    private func resourceBar(label: String, percent: Double, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(String(format: "%.0f", percent))%")
                    .font(.caption)
                    .bold()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: geo.size.width * CGFloat(min(1.0, max(0.0, percent / 100.0))))
                }
            }
            .frame(height: 8)
        }
    }

    private func runDiagnosticPing() {
        isRunningPingTest = true
        pingTestLogs = ["[\(DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium))] ゲートウェイ (\(cloudLinuxService.serverBaseURL)) 疎通テストを開始..."]

        cloudLinuxService.checkHealth { success in
            if success {
                pingTestLogs.append("GET /health -> 200 OK (latency=\(cloudLinuxService.latencyMs) ms)")
                pingTestLogs.append("Engine: \(cloudLinuxService.machineStatus.llmModel)")
                cloudLinuxService.syncUserStatusFromServer { status in
                    if let st = status {
                        pingTestLogs.append("Active Plan: \(st.plan_name) | 残プロンプト合計: \(st.remaining_prompts)回 (5h残:\(st.windows.remaining_5hour) / 週残:\(st.windows.remaining_weekly))")
                    }
                    let mediaCount = tohoAIService.configuredMediaProviderCount()
                    pingTestLogs.append("External Media AI Providers Configured: \(mediaCount)社")
                    pingTestLogs.append(">>> SUCCESS: 公開ゲートウェイおよびクォータ管理DBとの通信は全て正常です。")
                    isRunningPingTest = false
                }
            } else {
                pingTestLogs.append(">>> ERROR: ゲートウェイ (\(cloudLinuxService.serverBaseURL)) に接続できませんでした。URLまたはサーバ稼働状態を確認してください。")
                isRunningPingTest = false
            }
        }
    }
}
