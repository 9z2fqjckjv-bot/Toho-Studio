import Foundation
import SwiftUI

public enum AdType: String, CaseIterable, Identifiable {
    case fileProcessing = "ファイル処理広告"
    case longProcessing = "長時間処理広告"
    case trialVideo = "お試し動画広告"

    public var id: String { rawValue }
}

public final class AdManager: ObservableObject {
    public static let shared = AdManager()

    @Published public var isFileAdActive: Bool = false
    @Published public var isLongProcessingAdActive: Bool = false
    @Published public var isTrialVideoAdActive: Bool = false

    public var hasActiveAd: Bool {
        isFileAdActive || isLongProcessingAdActive || isTrialVideoAdActive
    }

    @Published public var currentAdTitle: String = "Google AdSense 広告配信枠"
    @Published public var currentAdSponsor: String = "東方Project公認クリエイター支援パートナー"
    @Published public var trialAdCountdown: Int = 15 // 15s video ad
    @Published public var trialAdMaxPerDay: Int = 5
    @Published public var trialAdUsedToday: Int = 1

    private var trialTimer: Timer? = nil
    private var onTrialCompleted: (() -> Void)? = nil

    private init() {}

    /// Checks if a specific ad type is exempted by a purchased ad-free pass
    public func isExempted(type: AdType) -> Bool {
        let appState = AppState.shared
        if appState.adFreeRemainingHours > 0 {
            return true
        }
        return false
    }

    /// Shows file processing ad banner/dialog
    public func triggerFileProcessingAd(actionName: String = "ファイル読み込み") {
        guard !isExempted(type: .fileProcessing) else { return }
        isFileAdActive = true
    }

    public func dismissFileProcessingAd() {
        isFileAdActive = false
    }

    /// Triggers long processing ad (for tasks taking >= 1 minute)
    public func triggerLongProcessingAd() {
        guard !isExempted(type: .longProcessing) else { return }
        isLongProcessingAdActive = true
    }

    public func dismissLongProcessingAd() {
        isLongProcessingAdActive = false
    }

    /// Triggers trial video ad to temporarily unlock a paid feature for 1 free use
    public func triggerTrialAd(featureName: String, onComplete: @escaping () -> Void) {
        guard trialAdUsedToday < trialAdMaxPerDay else {
            AppState.shared.addSystemLog(level: "WARN", message: "本日の「お試し広告」による無料利用枠上限(\(trialAdMaxPerDay)回)に達しました。")
            return
        }

        self.onTrialCompleted = onComplete
        self.trialAdCountdown = 10
        self.isTrialVideoAdActive = true

        trialTimer?.invalidate()
        trialTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else { return }
            if self.trialAdCountdown > 0 {
                self.trialAdCountdown -= 1
            } else {
                timer.invalidate()
                self.isTrialVideoAdActive = false
                self.trialAdUsedToday += 1
                AppState.shared.addSystemLog(level: "INFO", message: "お試し広告の視聴が完了し、有料機能 [\(featureName)] が1回解放されました。")
                self.onTrialCompleted?()
                self.onTrialCompleted = nil
            }
        }
    }
}
