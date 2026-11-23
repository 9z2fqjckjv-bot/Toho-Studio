import Foundation
import SwiftUI

public enum ServerConnectionStatus: String, Codable {
    case connected = "常時接続中 (正常)"
    case lowLatency = "高速通信中"
    case suspendedPromptZero = "通信遮断 (プロンプト残数0 / 上限到達)"
    case energySaving = "自動運転省電力モード"
    case disconnected = "オフライン (ローカルフォールバック待機)"
}

// MARK: - V3.0 新・定額プラン料金モデル (一般配布・外部公開対応)
public struct FlatRatePlanInfo: Identifiable, Codable, Equatable {
    public var id: String { plan_id }
    public var plan_id: String
    public var name: String
    public var price_jpy: Int
    public var base_monthly_prompts: Int
    public var ad_bonus_monthly_cap: Int
    public var max_monthly_total: Int
    public var limit_5hour: Int
    public var limit_weekly: Int
    public var rollover_days: Int
    public var model_tier: String
    public var requires_trial_ad: Bool
    public var trial_ad_seconds_per_prompt: Int
    public var description: String

    public static let defaultPlans: [FlatRatePlanInfo] = [
        FlatRatePlanInfo(
            plan_id: "free",
            name: "無料プラン (Starter)",
            price_jpy: 0,
            base_monthly_prompts: 30,
            ad_bonus_monthly_cap: 270,
            max_monthly_total: 300,
            limit_5hour: 15,
            limit_weekly: 80,
            rollover_days: 180,
            model_tier: "economy",
            requires_trial_ad: true,
            trial_ad_seconds_per_prompt: 15,
            description: "毎月基本30回＋お試し広告視聴で最大月300回まで無料利用可能（半年繰越対応）"
        ),
        FlatRatePlanInfo(
            plan_id: "lite_980",
            name: "ライトプラン",
            price_jpy: 980,
            base_monthly_prompts: 800,
            ad_bonus_monthly_cap: 200,
            max_monthly_total: 1000,
            limit_5hour: 60,
            limit_weekly: 300,
            rollover_days: 365,
            model_tier: "standard",
            requires_trial_ad: false,
            trial_ad_seconds_per_prompt: 10,
            description: "日常のセリフ推敲・キャラ口調変換に最適（基本800回＋広告200回＝月最大1,000回）"
        ),
        FlatRatePlanInfo(
            plan_id: "standard_1980",
            name: "スタンダードプラン",
            price_jpy: 1980,
            base_monthly_prompts: 2000,
            ad_bonus_monthly_cap: 500,
            max_monthly_total: 2500,
            limit_5hour: 150,
            limit_weekly: 750,
            rollover_days: 365,
            model_tier: "standard",
            requires_trial_ad: false,
            trial_ad_seconds_per_prompt: 10,
            description: "【推奨主力】週1〜2本の動画・スライド制作向け（基本2,000回＋広告500回＝月最大2,500回）"
        ),
        FlatRatePlanInfo(
            plan_id: "creator_2980",
            name: "クリエイタープラン",
            price_jpy: 2980,
            base_monthly_prompts: 3500,
            ad_bonus_monthly_cap: 1000,
            max_monthly_total: 4500,
            limit_5hour: 250,
            limit_weekly: 1300,
            rollover_days: 365,
            model_tier: "high",
            requires_trial_ad: false,
            trial_ad_seconds_per_prompt: 10,
            description: "長編シリーズ・絵コンテ自動生成・ゲームスクリプト制作向け（基本3,500回＋広告1,000回）"
        ),
        FlatRatePlanInfo(
            plan_id: "pro_4980",
            name: "プロスタジオプラン",
            price_jpy: 4980,
            base_monthly_prompts: 6500,
            ad_bonus_monthly_cap: 1500,
            max_monthly_total: 8000,
            limit_5hour: 450,
            limit_weekly: 2400,
            rollover_days: 365,
            model_tier: "high",
            requires_trial_ad: false,
            trial_ad_seconds_per_prompt: 10,
            description: "高頻度投稿者・複数作品並行制作・思考モード優先（基本6,500回＋広告1,500回）"
        ),
        FlatRatePlanInfo(
            plan_id: "ultra_9800",
            name: "アルティメットプラン",
            price_jpy: 9800,
            base_monthly_prompts: 15000,
            ad_bonus_monthly_cap: 3000,
            max_monthly_total: 18000,
            limit_5hour: 1000,
            limit_weekly: 5500,
            rollover_days: 365,
            model_tier: "ultra",
            requires_trial_ad: false,
            trial_ad_seconds_per_prompt: 5,
            description: "サークル共同制作・大規模開発向け最上位プラン（基本15,000回＋広告3,000回＝月最大18,000回）"
        )
    ]
}

public struct AddonPackInfo: Identifiable, Codable, Equatable {
    public var id: String { pack_id }
    public var pack_id: String
    public var name: String
    public var prompts: Int
    public var price_jpy: Int
    public var unit_price_jpy: Double

    public static let defaultPacks: [AddonPackInfo] = [
        AddonPackInfo(pack_id: "pack_10", name: "追加 10 プロンプト", prompts: 10, price_jpy: 100, unit_price_jpy: 10.0),
        AddonPackInfo(pack_id: "pack_100", name: "追加 100 プロンプト", prompts: 100, price_jpy: 500, unit_price_jpy: 5.0),
        AddonPackInfo(pack_id: "pack_500", name: "追加 500 プロンプト", prompts: 500, price_jpy: 1800, unit_price_jpy: 3.6),
        AddonPackInfo(pack_id: "pack_1000", name: "追加 1,000 プロンプト", prompts: 1000, price_jpy: 3000, unit_price_jpy: 3.0)
    ]
}

public struct UserQuotaBreakdown: Codable, Equatable {
    public var base_remaining: Int = 30
    public var base_monthly_allocation: Int = 30
    public var ad_bonus_remaining: Int = 0
    public var ad_bonus_earned_month: Int = 0
    public var ad_bonus_monthly_cap: Int = 270
    public var rollover_remaining: Int = 0
    public var rollover_expires_at: String? = nil
    public var addon_remaining: Int = 0
}

public struct UserQuotaWindows: Codable, Equatable {
    public var limit_5hour: Int = 15
    public var used_5hour: Int = 0
    public var remaining_5hour: Int = 15
    public var limit_weekly: Int = 80
    public var used_weekly: Int = 0
    public var remaining_weekly: Int = 80
    public var used_monthly: Int = 0
}

public struct UserQuotaStatus: Codable, Equatable {
    public var user_id: String = "zuyasi"
    public var account_type: String = "NanndemoyaCloud"
    public var plan_id: String = "free"
    public var plan_name: String = "無料プラン (Starter)"
    public var price_jpy: Int = 0
    public var plan_enabled: Bool = true
    public var is_banned: Bool = false
    public var ban_reason: String? = nil
    public var remaining_prompts: Int = 30
    public var total_monthly_cap: Int = 300
    public var breakdown: UserQuotaBreakdown = UserQuotaBreakdown()
    public var windows: UserQuotaWindows = UserQuotaWindows()
    public var cycle_started_at: String = ""
    public var next_renewal_at: String = ""
    public var requires_trial_ad: Bool = true
}

public struct NanndemoyaLicenseVerification: Codable, Equatable {
    public struct UsageSummary: Codable, Equatable {
        public var total_requests: Int = 0
        public var total_prompt_tokens: Int = 0
        public var total_completion_tokens: Int = 0
        public var last_used_at: String? = nil
    }
    public var valid: Bool
    public var license_key: String
    public var owner_user_id: String
    public var label: String
    public var preferred_provider: String
    public var status: String
    public var usage: UsageSummary
}

public struct VirtualLinuxMachineStatus: Codable {
    public var hostIP: String = "debian.local"
    public var gcpZone: String = "nanndemoya-edge-jp"
    public var machineType: String = "Debian 13 Gateway (MacMini + Hybrid LLM Router)"
    public var llmModel: String = "Hybrid Router (Gemini / DeepSeek / Ollama)"
    public var uptimeHours: Double = 999.0
    public var cpuUsagePercent: Double = 14.0
    public var memoryUsagePercent: Double = 48.0
    public var gpuUsagePercent: Double = 10.0
    public var monthlyAllocatedCreditUSD: Double = 0.0
    public var monthlyUsedCreditUSD: Double = 0.0
    public var creditRemainingUSD: Double {
        return max(0.0, monthlyAllocatedCreditUSD - monthlyUsedCreditUSD)
    }
    public var activeLocalAccountsCount: Int = 1
}

public struct ColabGPUBridgeInfo: Codable {
    public var notebookUrl: String = "https://colab.research.google.com/drive/1OCq2X8eLWBe6asIWuaC5RR_TFsUhFKiY?usp=sharing"
    public var endpoint: String = ""
    public var isOnline: Bool = false
    public var gpuName: String = "NVIDIA L4 (24GB VRAM)"
    public var capabilities: [String] = ["image", "video", "bgm", "se"]
}

public struct ChatCompletionResponse: Codable {
    public var response: String
    public var thinking: String?
    public var engine: String?
    public var media_type: String?
    public var media_url: String?
    public var local_filename: String?
    public var colab_online: Bool?
    public var remaining_prompts: Int?
}

public final class CloudVirtualLinuxService: ObservableObject {
    public static let shared = CloudVirtualLinuxService()

    private static let serverURLDefaultsKey = "TohoAIStudio.ServerBaseURL"

    /// 公開ゲートウェイまたはLAN内MacMiniゲートウェイURL (外部公開時は https://ai.nanndemoya.net 等に変更可能)
    @Published public var serverBaseURL: String {
        didSet {
            UserDefaults.standard.set(serverBaseURL, forKey: Self.serverURLDefaultsKey)
            if let url = URL(string: serverBaseURL), let host = url.host {
                machineStatus.hostIP = host
            }
        }
    }

    @Published public var currentUserId: String = "zuyasi"
    @Published public var isConnected: Bool = false

    @Published public var machineStatus: VirtualLinuxMachineStatus = VirtualLinuxMachineStatus()
    @Published public var colabBridge: ColabGPUBridgeInfo = ColabGPUBridgeInfo()
    @Published public var connectionStatus: ServerConnectionStatus = .connected
    @Published public var lastHeartbeatAt: Date = Date()
    @Published public var latencyMs: Int = 3

    // V3.0 AI Prompt Subscription Quota & Plans
    @Published public var availablePlans: [FlatRatePlanInfo] = FlatRatePlanInfo.defaultPlans
    @Published public var addonPacks: [AddonPackInfo] = AddonPackInfo.defaultPacks
    @Published public var adRewardPromptsPerView: Int = 5
    @Published public var quotaStatus: UserQuotaStatus = UserQuotaStatus()

    @Published public var totalPromptsMonthly: Int = 300
    @Published public var remainingPrompts: Int = 30
    @Published public var lastNotificationSentThreshold: Int? = nil
    @Published public var latestNotificationMessage: String? = nil
    @Published public var lastGeneratedMediaUrl: String? = nil
    @Published public var isMusicTranscriptionSupported: Bool = false

    private var heartbeatTimer: Timer? = nil
    private var colabCheckCounter: Int = 0

    private init() {
        let savedURL = UserDefaults.standard.string(forKey: Self.serverURLDefaultsKey) ?? "http://debian.local:8095"
        self.serverBaseURL = savedURL
        if let url = URL(string: savedURL), let host = url.host {
            self.machineStatus.hostIP = host
        }
        let appUser = AppState.shared.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !appUser.isEmpty {
            self.currentUserId = appUser
        }

        startContinuousHeartbeat()
        fetchServerPlans()
        syncUserStatusFromServer()
    }

    // MARK: - Health & Catalog Sync
    public func checkHealth(completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(serverBaseURL)/health") else {
            completion(false)
            return
        }

        let start = Date()
        var req = URLRequest(url: url)
        req.timeoutInterval = 4.0

        URLSession.shared.dataTask(with: req) { [weak self] data, response, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200 {
                    let elapsed = Int(Date().timeIntervalSince(start) * 1000)
                    self.latencyMs = max(1, elapsed)
                    self.lastHeartbeatAt = Date()
                    self.isConnected = true
                    self.connectionStatus = .connected

                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let mType = json["machine_type"] as? String {
                            self.machineStatus.machineType = mType
                        }
                        if let zone = json["zone"] as? String {
                            self.machineStatus.gcpZone = zone
                        }
                        if let eng = json["engine"] as? String {
                            self.machineStatus.llmModel = eng
                        }
                        if let users = json["active_local_users"] as? Int {
                            self.machineStatus.activeLocalAccountsCount = users
                        }
                    }
                    completion(true)
                } else {
                    self.isConnected = false
                    self.connectionStatus = .disconnected
                    completion(false)
                }
            }
        }.resume()
    }

    public func fetchServerPlans() {
        guard let url = URL(string: "\(serverBaseURL)/v1/plans") else { return }
        URLSession.shared.dataTask(with: url) { [weak self] data, response, _ in
            guard let data = data,
                  let httpRes = response as? HTTPURLResponse,
                  httpRes.statusCode == 200 else { return }

            struct PlansResponse: Codable {
                var plans: [FlatRatePlanInfo]
                var addon_packs: [AddonPackInfo]
                var ad_reward_prompts_per_view: Int?
            }

            if let decoded = try? JSONDecoder().decode(PlansResponse.self, from: data) {
                DispatchQueue.main.async {
                    if !decoded.plans.isEmpty {
                        self?.availablePlans = decoded.plans
                    }
                    if !decoded.addon_packs.isEmpty {
                        self?.addonPacks = decoded.addon_packs
                    }
                    if let reward = decoded.ad_reward_prompts_per_view {
                        self?.adRewardPromptsPerView = reward
                    }
                }
            }
        }.resume()
    }

    public func applyQuotaStatus(_ status: UserQuotaStatus) {
        self.quotaStatus = status
        self.remainingPrompts = status.remaining_prompts
        self.totalPromptsMonthly = max(status.total_monthly_cap, status.remaining_prompts)
        AppState.shared.aiPlanRemainingPrompts = status.remaining_prompts

        if status.is_banned || status.remaining_prompts <= 0 {
            self.connectionStatus = .suspendedPromptZero
        } else if self.isConnected {
            self.connectionStatus = .connected
        }
    }

    public func syncUserStatusFromServer(completion: ((UserQuotaStatus?) -> Void)? = nil) {
        let uid = currentUserId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? currentUserId
        guard let url = URL(string: "\(serverBaseURL)/v1/user/status/\(uid)") else {
            completion?(nil)
            return
        }

        URLSession.shared.dataTask(with: url) { [weak self] data, response, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200,
                   let data = data,
                   let decoded = try? JSONDecoder().decode(UserQuotaStatus.self, from: data) {
                    self.applyQuotaStatus(decoded)
                    completion?(decoded)
                } else {
                    completion?(nil)
                }
            }
        }.resume()
    }

    /// 後方互換メソッド: 最新のプロンプト残数を同期
    public func syncUserPromptsFromServer(completion: ((Int?) -> Void)? = nil) {
        syncUserStatusFromServer { status in
            completion?(status?.remaining_prompts)
        }
    }

    // MARK: - Plan Selection, Refresh, Ad Bonus & Addon Packs
    public func selectPlan(planId: String, completion: @escaping (Result<UserQuotaStatus, Error>) -> Void) {
        guard let url = URL(string: "\(serverBaseURL)/v1/user/plan/select") else {
            completion(.failure(URLError(.badURL)))
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "user_id": currentUserId,
            "plan_id": planId,
            "account_type": AppState.shared.currentAccountType
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let data = data, let http = response as? HTTPURLResponse else {
                    completion(.failure(URLError(.badServerResponse)))
                    return
                }
                if http.statusCode == 200, let status = try? JSONDecoder().decode(UserQuotaStatus.self, from: data) {
                    self?.applyQuotaStatus(status)
                    completion(.success(status))
                } else {
                    let msg = Self.extractErrorDetail(from: data) ?? "プラン変更に失敗しました"
                    completion(.failure(NSError(domain: "TohoAIStudio", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])))
                }
            }
        }.resume()
    }

    /// 仕様書『利用枠の再購入』: 次回更新日を1ヶ月後に再設定し基本枠を即時フル回復
    public func refreshCurrentPlan(completion: @escaping (Result<UserQuotaStatus, Error>) -> Void) {
        guard let url = URL(string: "\(serverBaseURL)/v1/user/plan/refresh") else {
            completion(.failure(URLError(.badURL)))
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: ["user_id": currentUserId])

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let data = data, let http = response as? HTTPURLResponse else {
                    completion(.failure(URLError(.badServerResponse)))
                    return
                }
                if http.statusCode == 200, let status = try? JSONDecoder().decode(UserQuotaStatus.self, from: data) {
                    self?.applyQuotaStatus(status)
                    completion(.success(status))
                } else {
                    let msg = Self.extractErrorDetail(from: data) ?? "利用枠の再購入リセットに失敗しました"
                    completion(.failure(NSError(domain: "TohoAIStudio", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])))
                }
            }
        }.resume()
    }

    /// お試し広告視聴完了時のボーナス付与
    public func addPrompts(count: Int, completion: @escaping (Bool) -> Void) {
        guard let url = URL(string: "\(serverBaseURL)/v1/user/prompts") else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "user_id": currentUserId,
            "add_prompts": count,
            "source": "trial_ad"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { [weak self] data, response, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let httpRes = response as? HTTPURLResponse, httpRes.statusCode == 200,
                   let data = data,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let statusObj = json["status"],
                       let statusData = try? JSONSerialization.data(withJSONObject: statusObj),
                       let decoded = try? JSONDecoder().decode(UserQuotaStatus.self, from: statusData) {
                        self.applyQuotaStatus(decoded)
                    } else if let newPrompts = json["remaining_prompts"] as? Int {
                        self.remainingPrompts = newPrompts
                        AppState.shared.aiPlanRemainingPrompts = newPrompts
                    }
                    completion(true)
                } else {
                    if let data = data, let msg = Self.extractErrorDetail(from: data) {
                        self.latestNotificationMessage = msg
                    }
                    completion(false)
                }
            }
        }.resume()
    }

    /// 追加プロンプトパックの適用
    public func addAddonPack(packId: String, completion: @escaping (Result<UserQuotaStatus, Error>) -> Void) {
        guard let url = URL(string: "\(serverBaseURL)/v1/user/prompts") else {
            completion(.failure(URLError(.badURL)))
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = [
            "user_id": currentUserId,
            "pack_id": packId,
            "source": "addon_pack"
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let data = data, let http = response as? HTTPURLResponse else {
                    completion(.failure(URLError(.badServerResponse)))
                    return
                }
                if http.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let statusDict = json["status"],
                   let statusData = try? JSONSerialization.data(withJSONObject: statusDict),
                   let decoded = try? JSONDecoder().decode(UserQuotaStatus.self, from: statusData) {
                    self?.applyQuotaStatus(decoded)
                    completion(.success(decoded))
                } else {
                    let msg = Self.extractErrorDetail(from: data) ?? "追加パックの反映に失敗しました"
                    completion(.failure(NSError(domain: "TohoAIStudio", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])))
                }
            }
        }.resume()
    }

    // MARK: - NanndemoyaAPI License Key Verification (課金基盤なし・ライセンスキー認証のみ)
    public func verifyNanndemoyaLicense(
        licenseKey: String,
        completion: @escaping (Result<NanndemoyaLicenseVerification, Error>) -> Void
    ) {
        guard let url = URL(string: "\(serverBaseURL)/v1/nanndemoya/verify") else {
            completion(.failure(URLError(.badURL)))
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 10.0
        let body: [String: Any] = [
            "license_key": licenseKey.trimmingCharacters(in: .whitespacesAndNewlines),
            "user_id": currentUserId
        ]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: req) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(.failure(error))
                    return
                }
                guard let data = data, let http = response as? HTTPURLResponse else {
                    completion(.failure(URLError(.badServerResponse)))
                    return
                }
                if http.statusCode == 200,
                   let verified = try? JSONDecoder().decode(NanndemoyaLicenseVerification.self, from: data) {
                    completion(.success(verified))
                } else {
                    let msg = Self.extractErrorDetail(from: data) ?? "ライセンスキー認証に失敗しました"
                    completion(.failure(NSError(domain: "NanndemoyaAPI", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: msg])))
                }
            }
        }.resume()
    }

    // MARK: - Completion Request
    public func requestCompletion(
        userPrompt: String,
        systemPrompt: String = "あなたは東方Projectの二次創作支援AIです。",
        model: String = "qwen2.5:3b",
        nanndemoyaLicenseKey: String? = nil,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let url = URL(string: "\(serverBaseURL)/v1/chat/completions") else {
            completion(.failure(URLError(.badURL)))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120

        var body: [String: Any] = [
            "user_id": currentUserId,
            "account_type": AppState.shared.currentAccountType,
            "system_prompt": systemPrompt,
            "user_prompt": userPrompt,
            "model": model
        ]
        if let lic = nanndemoyaLicenseKey, !lic.isEmpty {
            body["nanndemoya_license_key"] = lic
        }

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }

        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            if let error = error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            guard let httpRes = response as? HTTPURLResponse else {
                DispatchQueue.main.async { completion(.failure(URLError(.badServerResponse))) }
                return
            }

            if httpRes.statusCode == 403 || httpRes.statusCode == 429 || httpRes.statusCode == 401 {
                let errMsg = Self.extractErrorDetail(from: data) ?? "プロンプト上限または認証制限に達しました。"
                DispatchQueue.main.async {
                    if httpRes.statusCode == 403 {
                        self?.connectionStatus = .suspendedPromptZero
                    }
                    completion(.failure(NSError(domain: "TohoStudio", code: httpRes.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: errMsg
                    ])))
                }
                return
            }

            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                DispatchQueue.main.async { completion(.failure(URLError(.cannotParseResponse))) }
                return
            }

            let responseText = json["response"] as? String ?? ""
            DispatchQueue.main.async {
                if let quotaDict = json["quota"],
                   let qData = try? JSONSerialization.data(withJSONObject: quotaDict),
                   let qDecoded = try? JSONDecoder().decode(UserQuotaStatus.self, from: qData) {
                    self?.applyQuotaStatus(qDecoded)
                } else if let updatedPrompts = json["remaining_prompts"] as? Int {
                    self?.remainingPrompts = updatedPrompts
                    AppState.shared.aiPlanRemainingPrompts = updatedPrompts
                }
                self?.connectionStatus = .connected
                completion(.success(responseText))
            }
        }.resume()
    }

    public static func extractErrorDetail(from data: Data?) -> String? {
        guard let data = data,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return json["detail"] as? String
    }

    // MARK: - Continuous Heartbeat
    public func startContinuousHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.performHeartbeat()
        }
    }

    public func performHeartbeat() {
        colabCheckCounter += 1
        if colabCheckCounter % 3 == 0 && !colabBridge.endpoint.isEmpty && colabBridge.isOnline {
            performDirectColabHeartbeat()
        }

        checkHealth { _ in }
    }

    // MARK: - Colab GPU Bridge Helpers
    public static func sanitizeColabEndpoint(_ raw: String) -> String {
        var str = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.isEmpty { return "" }
        if !str.hasPrefix("http://") && !str.hasPrefix("https://") {
            str = "https://" + str
        }
        if !str.contains(".trycloudflare.com") && !str.contains("localhost") && !str.contains("127.0.0.1") && !str.contains("ngrok") && !str.contains("loca.lt") {
            str = str + ".trycloudflare.com"
        }
        if str.hasSuffix("/") {
            str.removeLast()
        }
        return str
    }

    public func syncColabEndpointToLocalVM(endpoint: String) {
        guard !endpoint.isEmpty, let url = URL(string: "\(serverBaseURL)/v1/colab/endpoint") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 3.0
        let body = ["colab_url": endpoint]
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req).resume()
    }

    public func performDirectColabHeartbeat() {
        guard !colabBridge.endpoint.isEmpty else { return }
        let cleanEndpoint = Self.sanitizeColabEndpoint(colabBridge.endpoint)
        guard let url = URL(string: "\(cleanEndpoint)/health") else { return }

        var req = URLRequest(url: url)
        req.timeoutInterval = 8.0

        URLSession.shared.dataTask(with: req) { [weak self] data, response, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let http = response as? HTTPURLResponse, http.statusCode == 200, let data = data {
                    self.colabBridge.isOnline = true
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let gpu = json["gpu"] as? String {
                        self.colabBridge.gpuName = gpu
                    }
                }
            }
        }.resume()
    }

    public func testColabBridgeConnection(completion: @escaping (Bool, String) -> Void) {
        let cleanEndpoint = Self.sanitizeColabEndpoint(colabBridge.endpoint)
        self.colabBridge.endpoint = cleanEndpoint
        guard let url = URL(string: "\(cleanEndpoint)/health") else {
            completion(false, "無効なURL形式です")
            return
        }

        var req = URLRequest(url: url)
        req.timeoutInterval = 10.0

        URLSession.shared.dataTask(with: req) { [weak self] data, response, error in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let http = response as? HTTPURLResponse, http.statusCode == 200, let data = data {
                    self.colabBridge.isOnline = true
                    if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let gpu = json["gpu"] as? String {
                        self.colabBridge.gpuName = gpu
                    }
                    self.syncColabEndpointToLocalVM(endpoint: cleanEndpoint)
                    completion(true, "Colab GPUオンライン (\(self.colabBridge.gpuName))")
                } else {
                    self.colabBridge.isOnline = false
                    completion(false, error?.localizedDescription ?? "サーバー応答なし (Colabのすべてのセルを実行してURLを入力してください)")
                }
            }
        }.resume()
    }

    /// クライアント側事前チェック (オンライン時はサーバー側で厳密減算・バースト検証)
    public func consumePrompt(count: Int = 1, purpose: String = "AI生成リクエスト") -> Bool {
        if quotaStatus.is_banned {
            connectionStatus = .suspendedPromptZero
            latestNotificationMessage = "不正利用制限中のため定額プランを利用できません。"
            return false
        }
        guard remainingPrompts > 0 else {
            connectionStatus = .suspendedPromptZero
            latestNotificationMessage = "利用可能なプロンプト数が0のため、定額プラン通信が遮断されています。お試し広告視聴または追加チャージを行ってください。"
            return false
        }
        if !isConnected {
            // オフラインフォールバック時のみローカルデクリメント
            remainingPrompts = max(0, remainingPrompts - count)
            AppState.shared.aiPlanRemainingPrompts = remainingPrompts
        }
        return true
    }

    public func sendPromptToLLM(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        requestCompletion(userPrompt: prompt, completion: completion)
    }

    // MARK: - メディア生成用プロンプト英文化エンジン (クォータ非消費補助通信)
    public enum LocalLLMMediaType: String {
        case image = "画像生成 (SDXL 1.0)"
        case video = "動画生成 (AnimateDiff / Video)"
        case music = "BGM音楽生成 (MusicGen Medium)"
        case soundEffect = "効果音生成 (AudioLDM 2)"

        var systemPrompt: String {
            switch self {
            case .image:
                return "You are a professional prompt engineer for text-to-image AI (Stable Diffusion XL). Translate the user's Japanese prompt into concise, highly accurate English descriptive tags separated by commas. ALWAYS begin the output with: 'anime style, cel shaded anime illustration, 2D anime art, clean lineart, Japanese animation aesthetic'. NEVER generate photorealistic, photograph, 3D, or real-life humans! Accurately identify Touhou characters and their iconic visual traits: '古明地こいし' or 'こいし' -> 'Komeiji Koishi, touhou project, 1girl, short green wavy hair, green eyes, black hat with yellow ribbon, yellow collared shirt with blue diamonds, green frilled skirt, closed third eye with blue cord looping around torso, Mary Jane shoes', '古明地さとり' or 'さとり' -> 'Komeiji Satori, touhou project, 1girl, short lavender hair, open red third eye on chest', '博麗霊夢' or '霊夢' -> 'Hakurei Reimu, touhou project, 1girl, red hair ribbon, miko shrine maiden dress', '霧雨魔理沙' or '魔理沙' -> 'Kirisame Marisa, touhou project, 1girl, witch hat, blonde braid, apron dress', '十六夜咲夜' -> 'Izayoi Sakuya, touhou project, maid outfit, pocket watch', 'レミリア' -> 'Remilia Scarlet, touhou project, bat wings, mob cap', 'フランドール' or 'フラン' -> 'Flandre Scarlet, touhou project, rainbow crystal wings', '魂魄妖夢' or '妖夢' -> 'Konpaku Youmu, touhou project, phantom myon, dual swords'. Output ONLY the English tags."
            case .video:
                return "You are an expert prompt engineer for video generation. Translate the user's Japanese animation or video prompt into a descriptive English motion prompt. Specify the subject, action, motion dynamics, camera movement, and aesthetic style. Output ONLY the English prompt."
            case .music:
                return "You are an expert prompt engineer for Meta MusicGen. Translate the user's Japanese music request into a descriptive English music prompt specifying musical genre, instruments, tempo (BPM), mood, and audio textures. Output ONLY the English prompt."
            case .soundEffect:
                return "You are an expert prompt engineer for AudioLDM 2 sound effect generation. Translate the user's Japanese sound effect request into a clean, concise English sound effect prompt. Output ONLY the English prompt."
            }
        }
    }

    public static func containsJapanese(_ text: String) -> Bool {
        return text.unicodeScalars.contains { scalar in
            (0x3040...0x309F).contains(scalar.value) ||
            (0x30A0...0x30FF).contains(scalar.value) ||
            (0x4E00...0x9FAF).contains(scalar.value)
        }
    }

    public func translateAndOptimizePromptWithLocalLLM(
        prompt: String,
        mediaType: LocalLLMMediaType,
        completion: @escaping (String) -> Void
    ) {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            completion(trimmed)
            return
        }
        if !Self.containsJapanese(trimmed) {
            completion(trimmed)
            return
        }

        if let url = URL(string: "\(serverBaseURL)/v1/chat/completions") {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.timeoutInterval = 12.0

            let body: [String: Any] = [
                "user_id": "tohostudio-prompt-translator",
                "task_type": "prompt_translate",
                "system_prompt": mediaType.systemPrompt,
                "user_prompt": "Request: \(trimmed)\nEnglish Prompt:",
                "model": "qwen2.5:3b"
            ]

            if let bodyData = try? JSONSerialization.data(withJSONObject: body) {
                req.httpBody = bodyData
                URLSession.shared.dataTask(with: req) { data, _, _ in
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let responseText = json["response"] as? String,
                       !responseText.isEmpty {
                        let cleaned = Self.cleanLLMPromptOutput(responseText, originalPrompt: trimmed)
                        DispatchQueue.main.async {
                            completion(cleaned)
                        }
                        return
                    }
                    Self.tryOllamaDirect(prompt: trimmed, mediaType: mediaType, completion: completion)
                }.resume()
                return
            }
        }

        Self.tryOllamaDirect(prompt: trimmed, mediaType: mediaType, completion: completion)
    }

    private static func tryOllamaDirect(
        prompt: String,
        mediaType: LocalLLMMediaType,
        completion: @escaping (String) -> Void
    ) {
        let hostIP = CloudVirtualLinuxService.shared.machineStatus.hostIP
        let urlStrings = [
            "http://127.0.0.1:11434/api/generate",
            "http://\(hostIP):11434/api/generate"
        ]
        tryOllamaGenerateEndpoints(urls: urlStrings, prompt: prompt, mediaType: mediaType, completion: completion)
    }

    private static func tryOllamaGenerateEndpoints(
        urls: [String],
        prompt: String,
        mediaType: LocalLLMMediaType,
        completion: @escaping (String) -> Void
    ) {
        guard let urlStr = urls.first, let url = URL(string: urlStr) else {
            completion(prompt)
            return
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 30.0

        let payload: [String: Any] = [
            "model": "qwen2.5:3b",
            "prompt": "\(mediaType.systemPrompt)\n\nUser Request: \(prompt)\nEnglish Prompt:",
            "stream": false
        ]

        guard let bodyData = try? JSONSerialization.data(withJSONObject: payload) else {
            completion(prompt)
            return
        }
        req.httpBody = bodyData

        URLSession.shared.dataTask(with: req) { data, _, _ in
            if let data = data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let resText = json["response"] as? String,
               !resText.isEmpty {
                let cleaned = cleanLLMPromptOutput(resText, originalPrompt: prompt)
                DispatchQueue.main.async {
                    completion(cleaned)
                }
                return
            }

            let next = Array(urls.dropFirst())
            if !next.isEmpty {
                tryOllamaGenerateEndpoints(urls: next, prompt: prompt, mediaType: mediaType, completion: completion)
            } else {
                DispatchQueue.main.async {
                    completion(prompt)
                }
            }
        }.resume()
    }

    private static func cleanLLMPromptOutput(_ raw: String, originalPrompt: String = "") -> String {
        var str = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if str.hasPrefix("```") {
            let lines = str.components(separatedBy: "\n")
            str = lines.filter { !$0.hasPrefix("```") }.joined(separator: " ")
        }
        str = str.replacingOccurrences(of: "\"", with: "")
        str = str.replacingOccurrences(of: "English Prompt:", with: "")
        str = str.replacingOccurrences(of: "Prompt:", with: "")
        str = str.replacingOccurrences(of: "User Request:", with: "")
        str = str.replacingOccurrences(of: "Japanese:", with: "")
        str = str.replacingOccurrences(of: "English:", with: "")

        let origLower = originalPrompt.lowercased()
        let hasChar = AIImageGeneratorService.hasExplicitCharacterOrPerson(originalPrompt)
        let isOutdoor = !hasChar && (origLower.contains("校庭") || origLower.contains("グラウンド") || origLower.contains("運動場") ||
                        origLower.contains("屋外") || origLower.contains("空") || origLower.contains("海") ||
                        origLower.contains("公園") || origLower.contains("屋上") || origLower.contains("中庭"))

        if isOutdoor {
            let forbidden = ["architectural interior", "interior architecture", "classroom interior", "classroom", "interior", "indoor"]
            for term in forbidden {
                str = str.replacingOccurrences(of: term, with: "", options: .caseInsensitive)
            }
            if !str.lowercased().contains("outdoor") {
                str = "outdoor schoolyard athletic field, " + str
            }
        }

        return str.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
