import Foundation
import SwiftUI
import AppKit

public enum AdType: String, CaseIterable, Identifiable {
    case fileProcessing = "ファイル処理広告"
    case longProcessing = "長時間処理広告"
    case trialVideo = "お試し動画広告"
    case specBanner = "仕様書指定枠広告"

    public var id: String { rawValue }
}

/// Google AdSense / Google Ads 広告アイテム定義
public struct GoogleAdItem: Identifiable {
    public var id: UUID = UUID()
    public var title: String
    public var headline: String
    public var bodyText: String
    public var sponsorName: String
    public var callToAction: String
    public var targetURL: URL
    public var iconSystemName: String
    public var accentColor: Color
    public var secondaryColor: Color
    public var badge: String

    public init(
        title: String,
        headline: String,
        bodyText: String,
        sponsorName: String,
        callToAction: String,
        targetURL: URL,
        iconSystemName: String,
        accentColor: Color,
        secondaryColor: Color,
        badge: String = "広告"
    ) {
        self.title = title
        self.headline = headline
        self.bodyText = bodyText
        self.sponsorName = sponsorName
        self.callToAction = callToAction
        self.targetURL = targetURL
        self.iconSystemName = iconSystemName
        self.accentColor = accentColor
        self.secondaryColor = secondaryColor
        self.badge = badge
    }
}

public final class AdManager: ObservableObject {
    public static let shared = AdManager()

    // 広告オーバーレイ状態
    @Published public var isFileAdActive: Bool = false
    @Published public var isLongProcessingAdActive: Bool = false
    @Published public var isTrialVideoAdActive: Bool = false

    // Google AdSense 設定
    @Published public var googleAdSensePublisherId: String = "ca-pub-3501161675080001"
    @Published public var leftAdSlotId: String = "9823471029"
    @Published public var rightAdSlotId: String = "4810293847"
    @Published public var isGoogleAdsEnabled: Bool = true
    @Published public var isForceShowAdsForTesting: Bool = false // 広告フリー状態でもテストで広告枠を表示

    // 広告インプレッション・クリック統計
    @Published public var adImpressionsCount: Int = 128
    @Published public var adClicksCount: Int = 14
    @Published public var lastAdClickedTitle: String = ""

    // 広告ローテーションインデックス
    @Published public var currentLeftAdIndex: Int = 0
    @Published public var currentRightAdIndex: Int = 1

    // 既存プロパティ
    @Published public var currentAdTitle: String = "Google AdSense 広告配信枠"
    @Published public var currentAdSponsor: String = "Google Cloud & 東方Project公認パートナー"
    @Published public var trialAdCountdown: Int = 15 // 15s video ad
    @Published public var trialAdMaxPerDay: Int = 5
    @Published public var trialAdUsedToday: Int = 1

    private var trialTimer: Timer? = nil
    private var onTrialCompleted: (() -> Void)? = nil
    private var rotationTimer: Timer? = nil

    /// Google Ads プリセット広告リスト（クリエイター・クラウド・東方制作支援パートナー）
    @Published public var sampleAds: [GoogleAdItem] = [
        GoogleAdItem(
            title: "Google Cloud Platform",
            headline: "クリエイター向け高性能GPUインスタンス",
            bodyText: "Vertex AI & Compute Engineで大容量動画エンコードとAI音声合成を24時間高速稼働。$300無料クレジット配布中。",
            sponsorName: "Google Cloud Japan",
            callToAction: "無料で試す ↗",
            targetURL: URL(string: "https://cloud.google.com")!,
            iconSystemName: "cloud.fill",
            accentColor: Color.blue,
            secondaryColor: Color.cyan,
            badge: "Google Ads"
        ),
        GoogleAdItem(
            title: "NanndemoyaCloud 超高速ストレージ",
            headline: "東方二次創作のための大容量クラウド",
            bodyText: "動画素材・スライド・PSD立ち絵を複数Mac間で自動同期＆安全バックアップ。最高水準の暗号化を完備。",
            sponsorName: "Nanndemoya Inc.",
            callToAction: "プランを見る ↗",
            targetURL: URL(string: "https://www.nanndemoya.net")!,
            iconSystemName: "externaldrive.fill.badge.icloud",
            accentColor: Color.purple,
            secondaryColor: Color.indigo,
            badge: "Google AdSense"
        ),
        GoogleAdItem(
            title: "Google Workspace & Gemini",
            headline: "シナリオ執筆・台本作成をAIで劇的加速",
            bodyText: "Googleドキュメントとスライドに組み込まれたGeminiで、東方キャラの掛け合いセリフやプロットをスムーズ自動生成。",
            sponsorName: "Google LLC",
            callToAction: "詳細はこちら ↗",
            targetURL: URL(string: "https://workspace.google.com")!,
            iconSystemName: "sparkles",
            accentColor: Color.green,
            secondaryColor: Color.teal,
            badge: "Google Ads"
        ),
        GoogleAdItem(
            title: "VOICEVOX & 音声合成ソリューション",
            headline: "高品質なキャラクターボイス制作環境",
            bodyText: "東方動画制作を強力に支援する商用可能エンジン。高速なピッチ・イントネーション調整ツールを体験しよう。",
            sponsorName: "Voice Studio Partner",
            callToAction: "公式サイトへ ↗",
            targetURL: URL(string: "https://voicevox.hiroshiba.jp")!,
            iconSystemName: "waveform",
            accentColor: Color.orange,
            secondaryColor: Color.red,
            badge: "Google AdSense"
        ),
        GoogleAdItem(
            title: "CLIP STUDIO PAINT 公式",
            headline: "立ち絵・背景・エフェクト制作の定番ソフト",
            bodyText: "PSD差分書き出しやレイヤー管理がToho-Studioとシームレス連携。今なら最大3ヶ月無料キャンペーン中！",
            sponsorName: "CELSYS Inc.",
            callToAction: "無料体験版 ↗",
            targetURL: URL(string: "https://www.clipstudio.net")!,
            iconSystemName: "paintbrush.pointed.fill",
            accentColor: Color.pink,
            secondaryColor: Color.purple,
            badge: "Google Ads"
        ),
        GoogleAdItem(
            title: "Logic Pro for Mac",
            headline: "東方BGMアレンジ・SE編集プロフェッショナルDAW",
            bodyText: "Dolby Atmos立体音響、高品位音源プラグインを内蔵。Toho-Studio SoundMakerとのトラック連携に対応。",
            sponsorName: "Apple Inc. (Google Ad Network)",
            callToAction: "App Storeで確認 ↗",
            targetURL: URL(string: "https://www.apple.com/logic-pro/")!,
            iconSystemName: "music.note.list",
            accentColor: Color.indigo,
            secondaryColor: Color.blue,
            badge: "Google Ads"
        )
    ]

    public var hasActiveAd: Bool {
        isFileAdActive || isLongProcessingAdActive || isTrialVideoAdActive
    }

    private init() {
        startAdRotationTimer()
    }

    /// 広告の自動ローテーション（45秒ごと）
    public func startAdRotationTimer() {
        rotationTimer?.invalidate()
        rotationTimer = Timer.scheduledTimer(withTimeInterval: 45.0, repeats: true) { [weak self] _ in
            self?.rotateAds()
        }
    }

    public func rotateAds() {
        guard !sampleAds.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.5)) {
            currentLeftAdIndex = (currentLeftAdIndex + 1) % sampleAds.count
            currentRightAdIndex = (currentRightAdIndex + 1) % sampleAds.count
            if currentRightAdIndex == currentLeftAdIndex {
                currentRightAdIndex = (currentRightAdIndex + 1) % sampleAds.count
            }
            adImpressionsCount += 2
        }
    }

    /// 指定広告スロットの広告アイテムを取得
    public func adItem(for slot: AdSlot) -> GoogleAdItem {
        guard !sampleAds.isEmpty else {
            return GoogleAdItem(
                title: "Google AdSense",
                headline: "スポンサー募集枠",
                bodyText: "Google広告ネットワーク配信中",
                sponsorName: "Google",
                callToAction: "広告掲載について",
                targetURL: URL(string: "https://adsense.google.com")!,
                iconSystemName: "megaphone.fill",
                accentColor: .blue,
                secondaryColor: .cyan
            )
        }
        let index = slot == .left ? (currentLeftAdIndex % sampleAds.count) : (currentRightAdIndex % sampleAds.count)
        return sampleAds[index]
    }

    /// 広告クリック処理
    public func recordAdClick(ad: GoogleAdItem) {
        adClicksCount += 1
        lastAdClickedTitle = ad.title
        AppState.shared.addSystemLog(level: "INFO", message: "Google広告をクリックしました: [\(ad.title)] (\(ad.sponsorName))")
        // 内部ブラウザまたはSafariで広告先URLを開く
        AppState.shared.openInAppBrowser(url: ad.targetURL, title: ad.title)
    }

    /// 広告枠の表示可否（広告フリー券の有効性チェック）
    public func shouldShowAds() -> Bool {
        if isForceShowAdsForTesting {
            return true
        }
        let appState = AppState.shared
        // 広告フリー券の残り時間があれば非表示
        if appState.adFreeRemainingHours > 0 {
            return false
        }
        return isGoogleAdsEnabled
    }

    /// Checks if a specific ad type is exempted by a purchased ad-free pass
    public func isExempted(type: AdType) -> Bool {
        if isForceShowAdsForTesting {
            return false
        }
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

    /// Google AdSense の埋め込み HTML を生成（WKWebView表示用）
    public func generateAdSenseHTML(slot: AdSlot, width: Int = 300, height: Int = 600) -> String {
        let slotId = slot == .left ? leftAdSlotId : rightAdSlotId
        let ad = adItem(for: slot)

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <style>
                * { box-sizing: border-box; margin: 0; padding: 0; user-select: none; }
                body {
                    background-color: #0d1117;
                    color: #c9d1d9;
                    font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
                    height: 100vh;
                    display: flex;
                    flex-direction: column;
                    justify-content: space-between;
                    padding: 14px;
                    border: 1px solid #30363d;
                    border-radius: 8px;
                    overflow: hidden;
                }
                .header {
                    display: flex;
                    justify-content: space-between;
                    align-items: center;
                    border-bottom: 1px solid #21262d;
                    padding-bottom: 8px;
                }
                .badge {
                    font-size: 10px;
                    background: #1f6feb;
                    color: white;
                    padding: 2px 6px;
                    border-radius: 4px;
                    font-weight: 600;
                    letter-spacing: 0.5px;
                }
                .ad-choices {
                    font-size: 11px;
                    color: #8b949e;
                    text-decoration: none;
                    cursor: pointer;
                }
                .content {
                    margin-top: 12px;
                    display: flex;
                    flex-direction: column;
                    gap: 10px;
                }
                .sponsor {
                    font-size: 11px;
                    color: #58a6ff;
                    font-weight: 500;
                }
                .headline {
                    font-size: 15px;
                    font-weight: 700;
                    color: #f0f6fc;
                    line-height: 1.3;
                }
                .desc {
                    font-size: 12px;
                    color: #8b949e;
                    line-height: 1.45;
                }
                .cta-btn {
                    margin-top: 14px;
                    display: inline-block;
                    background: linear-gradient(135deg, #238636, #2ea043);
                    color: #ffffff;
                    text-align: center;
                    padding: 10px 14px;
                    border-radius: 6px;
                    font-size: 13px;
                    font-weight: 600;
                    text-decoration: none;
                    box-shadow: 0 2px 6px rgba(0,0,0,0.3);
                }
                .footer {
                    border-top: 1px solid #21262d;
                    padding-top: 8px;
                    font-size: 10px;
                    color: #6e7681;
                    display: flex;
                    justify-content: space-between;
                }
            </style>
        </head>
        <body>
            <div>
                <div class="header">
                    <span class="badge">\(ad.badge)</span>
                    <a class="ad-choices" href="https://adssettings.google.com" target="_blank">Google 広告設定 ⓘ</a>
                </div>
                <div class="content">
                    <div class="sponsor">提供: \(ad.sponsorName)</div>
                    <div class="headline">\(ad.headline)</div>
                    <div class="desc">\(ad.bodyText)</div>
                    <a class="cta-btn" href="\(ad.targetURL.absoluteString)" target="_blank">\(ad.callToAction)</a>
                </div>
            </div>
            <div class="footer">
                <span>Google AdSense #\(slotId)</span>
                <span>Toho-Studio Certified</span>
            </div>
        </body>
        </html>
        """
    }
}

public enum AdSlot {
    case left
    case right
}
