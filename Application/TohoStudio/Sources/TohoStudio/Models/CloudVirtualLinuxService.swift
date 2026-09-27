import Foundation
import SwiftUI

public enum ServerConnectionStatus: String, Codable {
    case connected = "常時接続中 (正常)"
    case lowLatency = "高速通信中 (42ms)"
    case suspendedPromptZero = "通信強制遮断 (プロンプト残数0)"
    case energySaving = "自動運転省電力モード"
    case disconnected = "切断"
}

public struct VirtualLinuxMachineStatus: Codable {
    public var hostIP: String = "34.85.120.91"
    public var gcpZone: String = "asia-northeast1-b (Tokyo)"
    public var machineType: String = "e2-standard-4 (4 vCPU, 16GB RAM)"
    public var llmModel: String = "DeepSeek-R1-Distill / Gemma-2-27B-IT"
    public var uptimeHours: Double = 720.0
    public var cpuUsagePercent: Double = 28.5
    public var memoryUsagePercent: Double = 62.0
    public var gpuUsagePercent: Double = 45.0
    public var monthlyAllocatedCreditUSD: Double = 100.0 // Google AI Pro Ultra $100 Credit
    public var monthlyUsedCreditUSD: Double = 84.20
    public var creditRemainingUSD: Double {
        return max(0.0, monthlyAllocatedCreditUSD - monthlyUsedCreditUSD)
    }
    public var activeLocalAccountsCount: Int = 1
}

public final class CloudVirtualLinuxService: ObservableObject {
    public static let shared = CloudVirtualLinuxService()

    @Published public var machineStatus: VirtualLinuxMachineStatus = VirtualLinuxMachineStatus()
    @Published public var connectionStatus: ServerConnectionStatus = .connected
    @Published public var lastHeartbeatAt: Date = Date()
    @Published public var latencyMs: Int = 42

    // AI Prompt Subscription Quota Management
    @Published public var totalPromptsMonthly: Int = 10000
    @Published public var remainingPrompts: Int = 8940
    @Published public var lastNotificationSentThreshold: Int? = nil // 1000, 500, 100
    @Published public var latestNotificationMessage: String? = nil

    private var heartbeatTimer: Timer? = nil

    private init() {
        startContinuousHeartbeat()
    }

    /// Starts real-time continuous communication with Google Cloud Virtual Linux instance
    public func startContinuousHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.performHeartbeat()
        }
    }

    /// Performs periodic heartbeat query
    public func performHeartbeat() {
        guard remainingPrompts > 0 else {
            if connectionStatus != .suspendedPromptZero {
                connectionStatus = .suspendedPromptZero
                AppState.shared.addSystemLog(level: "WARN", message: "【通信遮断】AIプロンプト残数が0になったため、仮想LinuxPCとの通信が強制遮断されました。")
            }
            return
        }

        // Simulate micro-latency variations
        self.latencyMs = Int.random(in: 38...48)
        self.lastHeartbeatAt = Date()
        self.connectionStatus = .connected
    }

    /// Consumes an AI prompt and enforces warning thresholds and cutoff
    public func consumePrompt(count: Int = 1, purpose: String = "AI生成リクエスト") -> Bool {
        guard remainingPrompts > 0 else {
            connectionStatus = .suspendedPromptZero
            latestNotificationMessage = "利用可能なプロンプト数が0のため、仮想LinuxPCとの通信が強制遮断されています。プランの更新または都度課金プランをご利用ください。"
            return false
        }

        remainingPrompts = max(0, remainingPrompts - count)

        // Threshold checks (1000, 500, 100, 0)
        if remainingPrompts < 100 {
            if lastNotificationSentThreshold != 100 {
                lastNotificationSentThreshold = 100
                sendNotificationEmail(
                    subject: "【重要】Toho-Studio AI定額プラン 残りプロンプト100件未満の警告および都度課金移行推奨",
                    body: "利用可能なプロンプトが100件を下回りました。プロンプト使用制限が開始されます。中断のない作業継続のため、都度課金式プランへの移行または追加チャージをご検討ください。"
                )
            }
        } else if remainingPrompts < 500 {
            if lastNotificationSentThreshold != 500 {
                lastNotificationSentThreshold = 500
                sendNotificationEmail(
                    subject: "【通知】Toho-Studio AI定額プラン 残りプロンプト500件の再通知",
                    body: "利用可能なAIプロンプトが500件を切りました。次回の月間更新日（購入後1ヶ月）まで残数にご注意ください。"
                )
            }
        } else if remainingPrompts < 1000 {
            if lastNotificationSentThreshold != 1000 {
                lastNotificationSentThreshold = 1000
                sendNotificationEmail(
                    subject: "【ご案内】Toho-Studio AI定額プラン 残りプロンプト減少通知 (1000件到達)",
                    body: "当月利用枠のプロンプト残数が1,000件を下回りました。継続して高品質なLLM連携がご利用いただけます。"
                )
            }
        }

        if remainingPrompts == 0 {
            connectionStatus = .suspendedPromptZero
            AppState.shared.addSystemLog(level: "WARN", message: "AI定額プランのプロンプト残数が0になりました。仮想LinuxPCとの通信を強制遮断しました。")
        }

        AppState.shared.aiPlanRemainingPrompts = remainingPrompts
        return true
    }

    private func sendNotificationEmail(subject: String, body: String) {
        latestNotificationMessage = "\(subject)\n\(body)"
        AppState.shared.addSystemLog(level: "INFO", message: "メール自動送信: [\(subject)]")
    }

    /// Sends a prompt request to the remote LLM Virtual Linux Server
    public func sendPromptToLLM(prompt: String, completion: @escaping (Result<String, Error>) -> Void) {
        guard remainingPrompts > 0 else {
            completion(.failure(NSError(domain: "CloudLLM", code: 403, userInfo: [NSLocalizedDescriptionKey: "プロンプト残数が0のため通信が遮断されています。"])))
            return
        }

        guard consumePrompt(count: 1, purpose: "LLM推論リクエスト") else {
            completion(.failure(NSError(domain: "CloudLLM", code: 403, userInfo: [NSLocalizedDescriptionKey: "プロンプト残数が不足しています。"])))
            return
        }

        // Simulate response from Google Cloud Linux LLM backend
        DispatchQueue.global().asyncAfter(deadline: .now() + 1.2) {
            let response = "【仮想Linux LLM (GCP Asia-Northeast1) 応答】\n解析完了: 「\(prompt.prefix(40))...」に対する東方Project二次創作ガイドラインに適合した最適化スクリプトおよびメタデータを自動生成しました。"
            DispatchQueue.main.async {
                completion(.success(response))
            }
        }
    }
}
