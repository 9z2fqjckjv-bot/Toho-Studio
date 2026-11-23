import SwiftUI
import AppKit

/// 仕様書「使用量の確認・新定額プラン管理・プロンプト追加」プログラム (V3.0 一般配布向け料金改定版)
public struct UsageBillingProgramView: View {
    @ObservedObject var cloudLinuxService = CloudVirtualLinuxService.shared
    @ObservedObject var tohoAIService = TohoAIService.shared
    @ObservedObject var appState = AppState.shared

    @State private var statusBanner: String? = nil
    @State private var isProcessingAction: Bool = false
    @State private var isPlayingTrialAd: Bool = false
    @State private var trialAdRemainingSec: Int = 0

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection

                if let banner = statusBanner {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundColor(.blue)
                        Text(banner)
                            .font(.caption)
                            .bold()
                        Spacer()
                        Button("閉じる") { statusBanner = nil }
                            .font(.caption2)
                            .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }

                // 1. 現在の残枠内訳 & 3段階レートウィンドウ (5時間 / 週次 / 月次)
                quotaOverviewCard

                // 2. お試し広告ボーナス獲得 & 追加プロンプトパック & 利用枠の再購入
                quickChargeAndRefreshCard

                // 3. 新・定額プラン料金体系一覧 (6段階プラン切替)
                flatRatePlansTableCard

                // 4. NanndemoyaAPI & 外部API 利用案内
                externalAndNanndemoyaNoteCard
            }
            .padding(24)
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            cloudLinuxService.fetchServerPlans()
            cloudLinuxService.syncUserStatusFromServer()
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "creditcard.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("TohoAIStudio 定額プラン・プロンプト残数管理 (V3.0 新料金体系)")
                        .font(.title2)
                        .bold()
                }
                Text("5時間枠・週次枠・月次枠の3段階バースト保護、未使用分の自動繰越（無料半年・有料1年）、およびお試し広告チャージを管理します。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()

            Button(action: {
                cloudLinuxService.syncUserStatusFromServer { st in
                    if st != nil {
                        statusBanner = "最新のサーバー残数・利用枠ステータスを同期しました。"
                    }
                }
            }) {
                Label("サーバーステータス更新", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)
        }
    }

    // MARK: - 1. Quota Overview & 3-Stage Windows Card
    private var quotaOverviewCard: some View {
        let q = cloudLinuxService.quotaStatus
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("現在の契約プラン: \(q.plan_name)")
                        .font(.headline)
                    Text("月額 ¥\(q.price_jpy) | 次回月次更新・繰越判定日: \(q.next_renewal_at.isEmpty ? "自動更新設定済" : String(q.next_renewal_at.prefix(10)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Text("合計残プロンプト: \(q.remaining_prompts) 回")
                    .font(.title3)
                    .bold()
                    .foregroundColor(q.remaining_prompts <= 10 ? .red : .green)
            }

            // 内訳4タイル
            HStack(spacing: 12) {
                breakdownTile(title: "今月の基本枠残", value: "\(q.breakdown.base_remaining) / \(q.breakdown.base_monthly_allocation) 回", color: .blue)
                breakdownTile(title: "お試し広告ボーナス残", value: "\(q.breakdown.ad_bonus_remaining) 回 (今月獲得 \(q.breakdown.ad_bonus_earned_month)/\(q.breakdown.ad_bonus_monthly_cap))", color: .orange)
                breakdownTile(title: "前月からの繰越枠", value: "\(q.breakdown.rollover_remaining) 回", color: .purple)
                breakdownTile(title: "追加パック残 (1年有効)", value: "\(q.breakdown.addon_remaining) 回", color: .green)
            }

            Divider()

            // 5時間枠・週次枠バーストモニター
            Text("時間窓レート上限（サーバー過負荷・ボット防止枠）")
                .font(.subheadline)
                .bold()

            HStack(spacing: 20) {
                windowBar(
                    label: "5時間バースト枠",
                    used: q.windows.used_5hour,
                    limit: q.windows.limit_5hour,
                    color: .blue
                )
                windowBar(
                    label: "週間 (7日) 利用枠",
                    used: q.windows.used_weekly,
                    limit: q.windows.limit_weekly,
                    color: .teal
                )
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }

    private func breakdownTile(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .bold()
                .foregroundColor(color)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(8)
    }

    private func windowBar(label: String, used: Int, limit: Int, color: Color) -> some View {
        let ratio = Double(used) / Double(max(1, limit))
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("消費 \(used) / 上限 \(limit) 回 (残り \(max(0, limit - used)) 回)")
                    .font(.caption)
                    .bold()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color.secondary.opacity(0.15))
                    RoundedRectangle(cornerRadius: 5)
                        .fill(ratio >= 0.9 ? Color.red : color)
                        .frame(width: geo.size.width * CGFloat(min(1.0, ratio)))
                }
            }
            .frame(height: 10)
        }
    }

    // MARK: - 2. Trial Ad Bonus, Addon Packs & Refresh Card
    private var quickChargeAndRefreshCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("プロンプトの獲得・追加パック・利用枠の再購入")
                .font(.headline)

            // お試し広告視聴チャージ
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("① お試し広告を視聴して無料プロンプトを獲得 (+\(cloudLinuxService.adRewardPromptsPerView)回 / 視聴)")
                        .font(.subheadline)
                        .bold()
                    Text("プランごとの月間広告ボーナス上限まで無料でプロンプトを加算できます。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()

                if isPlayingTrialAd {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small)
                        Text("PR動画再生中... 残り \(trialAdRemainingSec)秒")
                            .font(.caption)
                            .bold()
                            .foregroundColor(.orange)
                    }
                } else {
                    Button(action: startTrialAdReward) {
                        Label("お試し広告を見て +\(cloudLinuxService.adRewardPromptsPerView)回 獲得", systemImage: "play.rectangle.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .disabled(isProcessingAction)
                }
            }
            .padding(12)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(8)

            // 追加プロンプトパック4種
            VStack(alignment: .leading, spacing: 8) {
                Text("② 追加プロンプトパック（5時間・週次バースト制限を超えて即時利用可能・有効期限1年）")
                    .font(.subheadline)
                    .bold()

                HStack(spacing: 10) {
                    ForEach(cloudLinuxService.addonPacks) { pack in
                        Button(action: {
                            purchaseAddonPack(pack)
                        }) {
                            VStack(spacing: 3) {
                                Text("+\(pack.prompts) 回")
                                    .font(.subheadline)
                                    .bold()
                                Text("¥\(pack.price_jpy)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                Text("(¥\(String(format: "%.1f", pack.unit_price_jpy))/回)")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.bordered)
                        .disabled(isProcessingAction)
                    }
                }
            }
            .padding(12)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(8)

            // 利用枠の再購入（即時サイクル更新）
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("③ 利用枠の再購入（月途中の即時リセット回復）")
                        .font(.subheadline)
                        .bold()
                    Text("現在の定額プランの基本枠を今すぐ満額リセットし、次回更新日を今日から1ヶ月後に再設定します。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: executePlanRefresh) {
                    Label("利用枠を今すぐ再購入リセット", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                }
                .buttonStyle(.bordered)
                .disabled(isProcessingAction)
            }
            .padding(12)
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(8)
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }

    // MARK: - 3. New 6-Tier Flat-Rate Plans Table
    private var flatRatePlansTableCard: some View {
        let currentPlanId = cloudLinuxService.quotaStatus.plan_id
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("新・定額プラン料金一覧（一般配布・持続運用モデル）")
                    .font(.headline)
                Spacer()
                Text("※未使用の基本枠・広告枠は自動繰越（無料:半年 / 有料:1年）")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            VStack(spacing: 8) {
                ForEach(cloudLinuxService.availablePlans) { plan in
                    let isCurrent = (plan.plan_id == currentPlanId)
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(plan.name)
                                    .font(.subheadline)
                                    .bold()
                                if plan.plan_id == "standard_1980" {
                                    Text("おすすめ")
                                        .font(.system(size: 10, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.blue.opacity(0.15))
                                        .foregroundColor(.blue)
                                        .cornerRadius(4)
                                }
                            }
                            Text(plan.description)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 2) {
                            Text("基本 \(plan.base_monthly_prompts)回 + 広告 \(plan.ad_bonus_monthly_cap)回")
                                .font(.caption)
                                .bold()
                            Text("5時間上限: \(plan.limit_5hour)回 / 週上限: \(plan.limit_weekly)回")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(width: 220, alignment: .trailing)

                        Text(plan.price_jpy == 0 ? "無料" : "¥\(plan.price_jpy)/月")
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(.blue)
                            .frame(width: 90, alignment: .trailing)

                        if isCurrent {
                            Text("契約中")
                                .font(.caption)
                                .bold()
                                .foregroundColor(.green)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.green.opacity(0.12))
                                .cornerRadius(6)
                                .frame(width: 110)
                        } else {
                            Button("このプランに変更") {
                                changePlan(to: plan)
                            }
                            .font(.caption)
                            .buttonStyle(.borderedProminent)
                            .frame(width: 110)
                            .disabled(isProcessingAction)
                        }
                    }
                    .padding(12)
                    .background(isCurrent ? Color.blue.opacity(0.06) : Color(NSColor.windowBackgroundColor))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isCurrent ? Color.blue.opacity(0.5) : Color.secondary.opacity(0.15), lineWidth: 1)
                    )
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }

    // MARK: - 4. NanndemoyaAPI & External API Note
    private var externalAndNanndemoyaNoteCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "key.radiowaves.forward.fill")
                    .foregroundColor(.orange)
                Text("Nanndemoya独自API および 外部API ご利用時の料金について")
                    .font(.subheadline)
                    .bold()
            }
            Text("・Nanndemoya独自APIは、「何でも屋」側で取得したAPIキーを発行ライセンスキー経由で利用し、利用実績に応じた代金を「何でも屋」側で直接お受け取り・精算する方式のため、アプリ内課金登録なしでご利用いただけます（定額プランのプロンプト枠も消費しません）。\n・ご自身の Gemini / ChatGPT / Claude / Grok / Mistral APIキーを直接設定した場合も、TohoAIStudio側からの請求やプロンプト減算は一切発生しません。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.orange.opacity(0.06))
        .cornerRadius(10)
    }

    // MARK: - Actions
    private func startTrialAdReward() {
        isPlayingTrialAd = true
        trialAdRemainingSec = 3 // デモ・確認用に3秒カウントダウン後にサーバー付与
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            if trialAdRemainingSec > 1 {
                trialAdRemainingSec -= 1
            } else {
                timer.invalidate()
                isPlayingTrialAd = false
                isProcessingAction = true
                cloudLinuxService.addPrompts(count: cloudLinuxService.adRewardPromptsPerView) { ok in
                    isProcessingAction = false
                    if ok {
                        statusBanner = "お試し広告の視聴が完了し、+\(cloudLinuxService.adRewardPromptsPerView) プロンプトが付与されました！"
                    } else {
                        statusBanner = cloudLinuxService.latestNotificationMessage ?? "広告ボーナスの付与に失敗しました（月間上限到達または未接続）。"
                    }
                }
            }
        }
    }

    private func purchaseAddonPack(_ pack: AddonPackInfo) {
        isProcessingAction = true
        cloudLinuxService.addAddonPack(packId: pack.pack_id) { result in
            isProcessingAction = false
            switch result {
            case .success(let st):
                statusBanner = "『\(pack.name)』を適用しました（現在の合計残数: \(st.remaining_prompts)回）。"
            case .failure(let err):
                statusBanner = "エラー: \(err.localizedDescription)"
            }
        }
    }

    private func executePlanRefresh() {
        isProcessingAction = true
        cloudLinuxService.refreshCurrentPlan { result in
            isProcessingAction = false
            switch result {
            case .success(let st):
                statusBanner = "『\(st.plan_name)』の利用枠を再購入リセットしました（残数: \(st.remaining_prompts)回）。"
            case .failure(let err):
                statusBanner = "エラー: \(err.localizedDescription)"
            }
        }
    }

    private func changePlan(to plan: FlatRatePlanInfo) {
        isProcessingAction = true
        cloudLinuxService.selectPlan(planId: plan.plan_id) { result in
            isProcessingAction = false
            switch result {
            case .success(let st):
                statusBanner = "契約プランを『\(st.plan_name)』へ変更しました（残プロンプト合計: \(st.remaining_prompts)回）。"
            case .failure(let err):
                statusBanner = "プラン変更エラー: \(err.localizedDescription)"
            }
        }
    }
}
