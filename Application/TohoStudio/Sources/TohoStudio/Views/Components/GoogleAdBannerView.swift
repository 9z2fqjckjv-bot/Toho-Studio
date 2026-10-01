import SwiftUI
import AppKit
import WebKit

/// 仕様書（スライド 179, 180, 193, 215-219, 229-231等）の指定箇所「広告枠」に表示されるGoogle広告バナービュー
public struct GoogleAdBannerView: View {
    @ObservedObject var adManager = AdManager.shared
    @ObservedObject var appState = AppState.shared
    public let slot: AdSlot
    public let bannerTitle: String

    @State private var isHovering: Bool = false
    @State private var showAdChoicesSheet: Bool = false
    @State private var useWebViewRender: Bool = false

    public init(slot: AdSlot, bannerTitle: String = "広告枠") {
        self.slot = slot
        self.bannerTitle = bannerTitle
    }

    public var body: some View {
        let shouldShow = adManager.shouldShowAds()

        VStack(spacing: 0) {
            if shouldShow {
                activeAdContentView
            } else {
                adFreePassActiveView
            }
        }
        .frame(minWidth: 200, maxWidth: 360)
        .frame(maxHeight: .infinity)
        .background(Color.black)
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .sheet(isPresented: $showAdChoicesSheet) {
            adChoicesInfoModal
        }
    }

    // MARK: - Active Google Ad View
    private var activeAdContentView: some View {
        let ad = adManager.adItem(for: slot)

        return VStack(spacing: 12) {
            // Ad Unit Header
            HStack(spacing: 6) {
                HStack(spacing: 4) {
                    Image(systemName: "megaphone.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.blue)
                    Text(ad.badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.blue)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.blue.opacity(0.15))
                .cornerRadius(4)

                Spacer()

                // Google Ad Choices / Info Button
                Button(action: { showAdChoicesSheet = true }) {
                    HStack(spacing: 2) {
                        Text("AdChoices")
                            .font(.system(size: 9))
                        Image(systemName: "info.circle")
                            .font(.system(size: 9))
                    }
                    .foregroundColor(.gray)
                }
                .buttonStyle(.plain)
                .help("Google 広告について・パーソナライズ設定")
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            Divider().background(Color.white.opacity(0.1))

            Spacer()

            // Ad Creative Card (Clickable)
            Button(action: {
                adManager.recordAdClick(ad: ad)
            }) {
                VStack(spacing: 14) {
                    // Creative Icon / Visual
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [ad.accentColor.opacity(0.35), ad.secondaryColor.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 72, height: 72)

                        Image(systemName: ad.iconSystemName)
                            .font(.system(size: 32))
                            .foregroundColor(ad.accentColor)
                    }
                    .shadow(color: ad.accentColor.opacity(0.3), radius: 8, x: 0, y: 4)

                    // Sponsor Info
                    Text(ad.sponsorName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(ad.secondaryColor)
                        .lineLimit(1)

                    // Headline
                    Text(ad.headline)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 8)

                    // Description Body
                    Text(ad.bodyText)
                        .font(.system(size: 11))
                        .foregroundColor(Color.gray.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, 10)

                    // Call To Action Button
                    HStack(spacing: 6) {
                        Text(ad.callToAction)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        LinearGradient(
                            colors: [ad.accentColor, ad.secondaryColor],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(6)
                    .shadow(color: ad.accentColor.opacity(0.4), radius: 6, x: 0, y: 3)
                }
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(isHovering ? 0.08 : 0.04))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isHovering ? ad.accentColor.opacity(0.6) : Color.white.opacity(0.08), lineWidth: 1)
                )
                .padding(.horizontal, 12)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    isHovering = hovering
                }
            }

            Spacer()

            Divider().background(Color.white.opacity(0.1))

            // Footer: Specification label & AdFree note
            VStack(spacing: 6) {
                HStack {
                    Text(bannerTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.gray)
                    Spacer()
                    Text("Slot: #\(slot == .left ? adManager.leftAdSlotId : adManager.rightAdSlotId)")
                        .font(.system(size: 9))
                        .foregroundColor(.gray.opacity(0.6))
                }

                HStack {
                    Button("広告を更新") {
                        adManager.rotateAds()
                    }
                    .font(.system(size: 9))
                    .buttonStyle(.borderless)

                    Spacer()

                    Button("広告フリー券を購入") {
                        appState.activeModal = .settings
                    }
                    .font(.system(size: 9))
                    .foregroundColor(.yellow.opacity(0.85))
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Ad-Free Pass Active State (広告フリー券適用時)
    private var adFreePassActiveView: some View {
        VStack(spacing: 14) {
            Spacer()

            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 40))
                .foregroundColor(.green)

            Text("広告フリー適用中")
                .font(.headline)
                .bold()
                .foregroundColor(.white)

            Text("月間広告フリー券が有効です。\n仕様書の広告枠は非表示になっています。")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            Button("テスト用に広告を表示") {
                adManager.isForceShowAdsForTesting = true
            }
            .font(.caption2)
            .buttonStyle(.bordered)
            .padding(.top, 8)

            Spacer()

            Text("Toho-Studio Clean Edition")
                .font(.system(size: 9))
                .foregroundColor(.gray.opacity(0.5))
                .padding(.bottom, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }

    // MARK: - AdChoices Info Modal
    private var adChoicesInfoModal: some View {
        VStack(spacing: 16) {
            HStack {
                Label("Google 広告について (AdChoices)", systemImage: "info.circle.fill")
                    .font(.headline)
                    .foregroundColor(.blue)
                Spacer()
                Button(action: { showAdChoicesSheet = false }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                Text("Toho-Studio では、無料ユーザー向けに Google AdSense および認定パートナーによるスポンサー広告を配信しています。")
                    .font(.body)

                Text("• 編集画面上には一切広告を表示しません（仕様書 原則方針 準拠）")
                    .font(.callout)
                    .foregroundColor(.secondary)

                Text("• パブリッシャーID: \(adManager.googleAdSensePublisherId)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text("• 広告フリー券を購入すると、すべての指定枠広告および処理広告を非表示にできます。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)

            HStack {
                Button("Google 広告設定 (Web)") {
                    if let url = URL(string: "https://adssettings.google.com") {
                        appState.openInAppBrowser(url: url, title: "Google 広告設定")
                        showAdChoicesSheet = false
                    }
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("閉じる") {
                    showAdChoicesSheet = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 480)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
