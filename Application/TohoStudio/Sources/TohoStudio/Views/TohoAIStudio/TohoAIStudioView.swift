import SwiftUI
import AppKit

/// 仕様書「TohoAIStudio」内蔵ソフトメイン画面 (V3.0 一般配布・外部公開対応版)
public struct TohoAIStudioView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var tohoAIService = TohoAIService.shared
    @ObservedObject var cloudLinuxService = CloudVirtualLinuxService.shared
    @State private var isShowingHomeWithAds: Bool = false

    public init() {}

    public var body: some View {
        if isShowingHomeWithAds {
            tohoAIStudioHomeWithAdsView
        } else {
            tohoAIStudioWorkspaceView
        }
    }

    // MARK: - ホーム画面 (仕様書準拠 左右Google広告枠あり)
    private var tohoAIStudioHomeWithAdsView: some View {
        SpecScreenWithAds(screenTitle: "ホーム画面 (TohoAIStudio V3.0)") {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)

                VStack(spacing: 8) {
                    Text("TohoAIStudio")
                        .font(.system(size: 32, weight: .bold))

                    Text("定額プラン内蔵LLMゲートウェイ ・ Nanndemoya独自API ・ 5大外部API 統合環境")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                HStack(spacing: 16) {
                    Button(action: {
                        withAnimation { isShowingHomeWithAds = false }
                    }) {
                        Label("AIスタジオ 作業画面を開く (広告なし)", systemImage: "sparkles")
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: {
                        withAnimation { appState.isShowingAppTop = true }
                    }) {
                        Label("アプリトップに戻る", systemImage: "square.grid.2x2")
                            .font(.headline)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(NSColor.windowBackgroundColor))
        }
    }

    // MARK: - ワークスペース画面 (スライド246方針: 編集画面上には一切広告なし)
    private var tohoAIStudioWorkspaceView: some View {
        VStack(spacing: 0) {
            programNavigationBar

            // NanndemoyaCloud未ログイン時の案内バー (仕様書: 未認証時は外部APIのみ利用可能)
            if !appState.isLoggedIn || appState.currentAccountType != "NanndemoyaCloud" {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)
                    Text("現在 NanndemoyaCloud 以外のアカウントでログイン中です。定額プラン・Nanndemoya独自APIのご利用には NanndemoyaCloud 認証を推奨します（ご自身の外部APIキーはそのまま利用可能です）。")
                        .font(.caption)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.12))
            }

            Divider()

            switch tohoAIService.activeProgramTab {
            case .virtualLinuxVM:
                VirtualLinuxVMProgramView()
            case .aiChat:
                AIChatProgramView()
            case .aiEditor:
                AIEditorProgramView()
            case .aiImageGenerator:
                AIImageGeneratorProgramView()
            case .aiSoundGenerator:
                AISoundGeneratorProgramView()
            case .usageBilling:
                UsageBillingProgramView()
            case .externalAPI:
                ExternalAPIManagementProgramView()
            case .inAppBrowser:
                InAppBillingBrowserProgramView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Program Navigation Bar
    private var programNavigationBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.headline)
                    .foregroundColor(.blue)
                Text("TohoAIStudio")
                    .font(.headline)
                    .bold()
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    ForEach(TohoAIProgramTab.allCases) { tab in
                        let isSelected = tohoAIService.activeProgramTab == tab
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                tohoAIService.activeProgramTab = tab
                            }
                        }) {
                            HStack(spacing: 5) {
                                Image(systemName: tab.iconName)
                                    .font(.caption)
                                Text(tab.rawValue)
                                    .font(.caption)
                                    .bold()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(isSelected ? Color.blue : Color.secondary.opacity(0.1))
                            .foregroundColor(isSelected ? .white : .primary)
                            .cornerRadius(8)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer(minLength: 4)

            Button(action: {
                withAnimation { isShowingHomeWithAds = true }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "house")
                    Text("ホーム")
                }
                .font(.caption)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }
}
