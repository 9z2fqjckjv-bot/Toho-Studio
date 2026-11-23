import SwiftUI
import AppKit

/// 仕様書「外部APIの起動・運用管理 & Nanndemoya独自APIライセンス認証」プログラム (V3.0対応版)
public struct ExternalAPIManagementProgramView: View {
    @ObservedObject var tohoAIService = TohoAIService.shared
    @State private var testingProvider: AIProviderType? = nil
    @State private var feedbackBanner: String? = nil

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                headerSection

                if let banner = feedbackBanner {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.blue)
                        Text(banner)
                            .font(.caption)
                            .bold()
                        Spacer()
                        Button("閉じる") { feedbackBanner = nil }
                            .font(.caption2)
                            .buttonStyle(.plain)
                    }
                    .padding(10)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }

                // 1. Nanndemoya独自API（ライセンスキー認証・課金基盤なし・直接精算モデル）
                nanndemoyaLicenseCard

                Divider()

                Text("利用者自身の外部プロバイダーAPIキー連携（ChatGPT / Gemini / Claude / Grok / Mistral）")
                    .font(.headline)

                // 2. 5大外部APIカード
                apiProviderCard(
                    title: "Google Gemini API",
                    subtitle: "Google AI Studio (Gemini 2.5 Flash / 2.5 Pro)",
                    icon: "sparkles",
                    color: .blue,
                    provider: .gemini,
                    config: $tohoAIService.geminiConfig
                )
                apiProviderCard(
                    title: "OpenAI ChatGPT API",
                    subtitle: "OpenAI Platform (GPT-4o / GPT-4o-mini / o3-mini)",
                    icon: "brain",
                    color: .green,
                    provider: .chatGPT,
                    config: $tohoAIService.chatGPTConfig
                )
                apiProviderCard(
                    title: "Anthropic Claude API",
                    subtitle: "Anthropic Console (Claude 3.7 Sonnet / 3.5 Haiku)",
                    icon: "cpu",
                    color: .purple,
                    provider: .claude,
                    config: $tohoAIService.claudeConfig
                )
                apiProviderCard(
                    title: "xAI Grok API",
                    subtitle: "xAI Console (Grok 3 / Grok 3 Mini)",
                    icon: "bolt.horizontal.circle.fill",
                    color: .orange,
                    provider: .grok,
                    config: $tohoAIService.grokConfig
                )
                apiProviderCard(
                    title: "Mistral Large API",
                    subtitle: "Mistral AI La Plateforme (Mistral Large / Small)",
                    icon: "wind",
                    color: .teal,
                    provider: .mistral,
                    config: $tohoAIService.mistralConfig
                )

                securityPolicyCard
            }
            .padding(24)
        }
        .background(Color(NSColor.windowBackgroundColor))
    }

    // MARK: - Header
    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "network.badge.shield.half.filled")
                        .font(.title2)
                        .foregroundColor(.blue)
                    Text("Nanndemoya独自API & 外部API 運用管理")
                        .font(.title2)
                        .bold()
                }
                Text("ここで有効化したAPIをAIチャット・AI編集で使用する場合、定額プランのプロンプト枠は消費されません。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - NanndemoyaAPI 専用カード（決済基盤不要・ライセンスキー方式）
    private var nanndemoyaLicenseCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "key.radiowaves.forward.fill")
                    .font(.title2)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("Nanndemoya 独自API（何でも屋 一括管理ライセンス）")
                            .font(.headline)
                        Text("決済登録不要")
                            .font(.caption2)
                            .bold()
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.orange.opacity(0.2))
                            .foregroundColor(.orange)
                            .cornerRadius(4)
                    }
                    Text("「何でも屋」側で取得・管理するAPIキーを1つのライセンスキーで中継利用します。代金は利用実績に基づき「何でも屋」側で直接受け取り・支払いを行うため、各AI提供会社へのカード登録は不要です。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("ライセンスを有効化", isOn: $tohoAIService.nanndemoyaConfig.isEnabled)
                    .toggleStyle(.switch)
            }

            if tohoAIService.nanndemoyaConfig.isEnabled {
                Divider()

                HStack(spacing: 14) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Nanndemoya ライセンスキー:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("例: NDM-OFFICIAL-DEV-2026", text: $tohoAIService.nanndemoyaConfig.apiKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(.body, design: .monospaced))
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("優先モデル:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: $tohoAIService.nanndemoyaConfig.selectedModel) {
                            ForEach(AIProviderType.nanndemoya.availableModels, id: \.self) { m in
                                Text(m).tag(m)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 230)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("認証・実績確認:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button(action: {
                            runAPITest(provider: .nanndemoya)
                        }) {
                            HStack(spacing: 4) {
                                if testingProvider == .nanndemoya {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "checkmark.seal.fill")
                                }
                                Text("ライセンス認証")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .disabled(testingProvider != nil)
                    }
                }

                if let info = tohoAIService.nanndemoyaLicenseInfo {
                    HStack(spacing: 20) {
                        Label("状態: \(info.status) (\(info.label))", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("累計リクエスト: \(info.usage.total_requests) 回")
                            .font(.caption)
                            .bold()
                        Text("累計トークン: \(info.usage.total_prompt_tokens + info.usage.total_completion_tokens) tok")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("AIチャットでこのライセンスを使う") {
                            tohoAIService.activeProvider = .nanndemoya
                            tohoAIService.selectedModel = tohoAIService.nanndemoyaConfig.selectedModel
                            tohoAIService.activeProgramTab = .aiChat
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }
                    .padding(10)
                    .background(Color.orange.opacity(0.08))
                    .cornerRadius(8)
                } else if !tohoAIService.nanndemoyaStatusMessage.isEmpty {
                    Text(tohoAIService.nanndemoyaStatusMessage)
                        .font(.caption)
                        .foregroundColor(tohoAIService.nanndemoyaConfig.isConnected ? .green : .red)
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.orange.opacity(0.45), lineWidth: 1.5))
    }

    // MARK: - Reusable External API Card
    private func apiProviderCard(
        title: String,
        subtitle: String,
        icon: String,
        color: Color,
        provider: AIProviderType,
        config: Binding<ExternalAPIConfig>
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle("APIを有効化", isOn: config.isEnabled)
                    .toggleStyle(.switch)
            }

            if config.wrappedValue.isEnabled {
                Divider()

                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("API Key:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        SecureField("APIキーを入力...", text: config.apiKey)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("使用モデル:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("", selection: config.selectedModel) {
                            ForEach(provider.availableModels, id: \.self) { m in
                                Text(m).tag(m)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 200)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("疎通・テスト:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button(action: {
                            runAPITest(provider: provider)
                        }) {
                            HStack(spacing: 4) {
                                if testingProvider == provider {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "waveform.path.ecg")
                                }
                                Text("接続テスト")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(testingProvider != nil)
                    }
                }

                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(config.wrappedValue.isConnected ? Color.green : Color.secondary)
                            .frame(width: 8, height: 8)
                        Text(config.wrappedValue.isConnected ? "正常接続 (レイテンシ: \(config.wrappedValue.latencyMs)ms)" : "未検証")
                            .font(.caption)
                            .foregroundColor(config.wrappedValue.isConnected ? .green : .secondary)
                    }

                    Spacer()

                    Button(action: {
                        if let url = URL(string: config.wrappedValue.billingURLString) {
                            AppState.shared.openInAppBrowser(url: url, title: "\(title) 請求・使用量確認")
                        }
                    }) {
                        Label("専用ブラウザで請求・使用量を確認", systemImage: "safari")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }
            }
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
    }

    // MARK: - Security Policy Card
    private var securityPolicyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield")
                    .foregroundColor(.green)
                Text("APIキーの保護と運用ポリシー")
                    .font(.subheadline)
                    .bold()
            }
            Text("利用者自身の外部APIキーは端末ローカルのみで各社エンドポイントとの直接通信に使用されます。Nanndemoya独自APIを利用する場合は、ライセンスキーのみがゲートウェイサーバで認証され、プロバイダー側のマスターAPIキーや決済情報がクライアント端末へ露出することはありません。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.06))
        .cornerRadius(10)
    }

    private func runAPITest(provider: AIProviderType) {
        testingProvider = provider
        tohoAIService.testAPIConnection(provider: provider) { ok, msg in
            testingProvider = nil
            feedbackBanner = "[\(provider.rawValue)] \(msg)"
            AppState.shared.addSystemLog(level: ok ? "INFO" : "WARN", message: "[\(provider.rawValue)] \(msg)")
        }
    }
}
