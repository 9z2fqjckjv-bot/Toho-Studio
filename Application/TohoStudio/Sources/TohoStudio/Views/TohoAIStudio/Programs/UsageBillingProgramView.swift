import SwiftUI
import AppKit

/// 仕様書「使用量の確認と請求確認」プログラム
public struct UsageBillingProgramView: View {
    @ObservedObject var cloudLinuxService = CloudVirtualLinuxService.shared
    @ObservedObject var tohoAIService = TohoAIService.shared
    @State private var selectedPlanType: String = "定額式プラン (月額4,980円 / 10,000回)"
    @State private var showChargeSheet: Bool = false

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // ヘッダー
                headerSection

                // プロンプト月間枠モニター
                promptQuotaCard

                // Google Cloud Platform $100クレジット残高 & 仮想VMインフラ費用
                gcpCreditCard

                // 外部API使用料金一覧
                externalAPICostCard

                // 請求プラン設定 & 請求履歴
                billingPlanCard
            }
            .padding(24)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header Section
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "creditcard.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("AI使用量・請求・クォータ管理")
                        .font(.title2)
                        .bold()
                }
                Text("AIプロンプト利用実績、Google Cloud $100クレジット残額、外部API請求状況を一元管理します。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()

            Button(action: {
                showChargeSheet = true
            }) {
                Label("プロンプト追加チャージ / プラン変更", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Prompt Quota Card
    private var promptQuotaCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("AIプロンプト 月間利用状況 (定額プラン)")
                .font(.headline)

            let total = cloudLinuxService.totalPromptsMonthly
            let remaining = cloudLinuxService.remainingPrompts
            let used = total - remaining
            let usageRate = Double(used) / Double(max(1, total))

            VStack(spacing: 8) {
                HStack {
                    Text("今月の消費プロンプト:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(used) 回")
                        .font(.title3)
                        .bold()

                    Spacer()

                    Text("残りプロンプト:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text("\(remaining) 回")
                        .font(.title3)
                        .bold()
                        .foregroundColor(remaining < 500 ? .orange : .green)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.secondary.opacity(0.15))
                        RoundedRectangle(cornerRadius: 6)
                            .fill(usageRate > 0.9 ? Color.red : (usageRate > 0.75 ? Color.orange : Color.blue))
                            .frame(width: geo.size.width * CGFloat(min(1.0, usageRate)))
                    }
                }
                .frame(height: 12)

                HStack {
                    Text("0回")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("警告ライン: 1,000回 / 500回 / 100回 (段階アラート通知)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(total)回 (上限)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)

            // アラートステータス
            if remaining < 100 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("【警告】残りプロンプトが100件未満です。通信遮断を避けるため、都度課金式への移行または追加購入を推奨します。")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            } else if remaining < 500 {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)
                    Text("残りプロンプトが500件未満です。更新日まで計画的にご利用ください。")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }

    // MARK: - GCP Credit Card
    private var gcpCreditCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Google Cloud 仮想LinuxVM クレジット残高")
                    .font(.headline)
                Spacer()
                Text("Google AI Pro Ultra $100 Credit 特典")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.blue)
            }

            let status = cloudLinuxService.machineStatus

            HStack(spacing: 20) {
                creditBlock(
                    title: "月間クレジット枠",
                    amount: "$\(String(format: "%.2f", status.monthlyAllocatedCreditUSD))",
                    icon: "giftcard.fill",
                    color: .blue
                )
                creditBlock(
                    title: "今月のVM使用料金",
                    amount: "$\(String(format: "%.2f", status.monthlyUsedCreditUSD))",
                    icon: "chart.bar.fill",
                    color: .orange
                )
                creditBlock(
                    title: "クレジット残高",
                    amount: "$\(String(format: "%.2f", status.creditRemainingUSD))",
                    icon: "checkmark.seal.fill",
                    color: .green
                )
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                GridRow {
                    Text("Compute Engine (e2-standard-2):").font(.caption).foregroundColor(.secondary)
                    Text("$52.80").font(.caption).bold()

                    Text("GPU Accelerator (T4 16GB):").font(.caption).foregroundColor(.secondary)
                    Text("$24.50").font(.caption).bold()
                }
                GridRow {
                    Text("Cloud Storage & SSD (200GB):").font(.caption).foregroundColor(.secondary)
                    Text("$4.90").font(.caption).bold()

                    Text("Network Egress (外部通信):").font(.caption).foregroundColor(.secondary)
                    Text("$2.00").font(.caption).bold()
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }

    // MARK: - External API Cost Card
    private var externalAPICostCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("外部API 概算使用料金 (今月)")
                    .font(.headline)
                Spacer()
                Text("※各プラットフォームの公式ダッシュボードで詳細を確認可能")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 16) {
                apiCostTile(provider: "Google Gemini", amount: tohoAIService.externalAPICostUSD[.gemini] ?? 0, icon: "sparkles", color: .blue)
                apiCostTile(provider: "OpenAI ChatGPT", amount: tohoAIService.externalAPICostUSD[.chatGPT] ?? 0, icon: "brain", color: .green)
                apiCostTile(provider: "Anthropic Claude", amount: tohoAIService.externalAPICostUSD[.claude] ?? 0, icon: "cpu", color: .purple)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Billing Plan Card
    private var billingPlanCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("契約プラン＆請求設定")
                .font(.headline)

            Picker("有効なプラン", selection: $selectedPlanType) {
                Text("定額式プラン (月額4,980円 / 10,000回)").tag("定額式プラン (月額4,980円 / 10,000回)")
                Text("都度課金式プラン (1回 0.8円 / 使った分だけ請求)").tag("都度課金式プラン (1回 0.8円 / 使った分だけ請求)")
            }
            .pickerStyle(.radioGroup)

            Divider()

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("次回更新日: 2026年10月28日")
                        .font(.caption)
                    Text("ご登録のお支払い方法: クレジットカード (•••• 4242)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()

                Button(action: {
                    AppState.shared.addSystemLog(level: "INFO", message: "請求書PDFを書き出しました。")
                }) {
                    Label("最新の請求書・領収書を保存", systemImage: "arrow.down.doc")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Subcomponents
    private func creditBlock(title: String, amount: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(amount)
                    .font(.title3)
                    .bold()
            }
            Spacer()
        }
        .padding(12)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }

    private func apiCostTile(provider: String, amount: Double, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(provider)
                    .font(.caption)
                    .bold()
            }
            Text("$\(String(format: "%.2f", amount))")
                .font(.title3)
                .bold()
            Text("概算利用額 (当月)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }
}
