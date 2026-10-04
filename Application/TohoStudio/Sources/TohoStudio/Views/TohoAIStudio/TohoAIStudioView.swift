import SwiftUI
import AppKit

/// 仕様書「TohoAIStudio」内蔵ソフトメイン画面
public struct TohoAIStudioView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var tohoAIService = TohoAIService.shared
    @ObservedObject var cloudLinuxService = CloudVirtualLinuxService.shared
    @State private var isShowingHomeWithAds: Bool = false

    public init() {}

    public var body: some View {
        Group {
            if isShowingHomeWithAds {
                tohoAIStudioHomeWithAdsView
            } else {
                tohoAIStudioWorkspaceView
            }
        }
    }

    // MARK: - ホーム画面 (仕様書準拠 左右Google広告枠あり)
    private var tohoAIStudioHomeWithAdsView: some View {
        SpecScreenWithAds(screenTitle: "ホーム画面 (TohoAIStudio)") {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)

                VStack(spacing: 8) {
                    Text("TohoAIStudio")
                        .font(.system(size: 32, weight: .bold))

                    Text("GCP仮想LinuxVM (DeepSeek/Gemma) & 外部API (Gemini/ChatGPT/Claude) 統合環境")
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
            // 上部プログラムタブバー
            programNavigationBar

            Divider()

            // アクティブなプログラム画面
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
        HStack(spacing: 12) {
            // タイトル
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.headline)
                    .foregroundColor(.blue)
                Text("TohoAIStudio")
                    .font(.headline)
                    .bold()
            }

            Spacer()

            // 6大プログラム切り替えセグメント
            HStack(spacing: 4) {
                ForEach(TohoAIProgramTab.allCases) { tab in
                    let isSelected = tohoAIService.activeProgramTab == tab
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            tohoAIService.activeProgramTab = tab
                        }
                    }) {
                        HStack(spacing: 6) {
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

            Spacer()

            // ホーム画面（広告枠）切り替え
            Button(action: {
                withAnimation { isShowingHomeWithAds = true }
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "house")
                    Text("ホーム画面")
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
