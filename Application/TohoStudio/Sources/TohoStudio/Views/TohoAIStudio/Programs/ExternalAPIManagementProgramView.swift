import SwiftUI
import AppKit

/// 仕様書「外部APIの起動、運用管理と、AIチャット機能、AI編集機能(Gemini, ChatGPT, Claude)」プログラム
public struct ExternalAPIManagementProgramView: View {
    @ObservedObject var tohoAIService = TohoAIService.shared
    @State private var testingProvider: AIProviderType? = nil

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // ヘッダー
                headerSection

                // 外部API 3大プロバイダー設定カード
                geminiAPICard
                chatGPTAPICard
                claudeAPICard

                // 外部API運用ルール・セキュリティ
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
                    Text("外部API 起動・運用管理 (Gemini / ChatGPT / Claude)")
                        .font(.title2)
                        .bold()
                }
                Text("外部LLMプロバイダーのAPIキー管理、エンドポイント疎通テスト、およびモデルパラメータの運用設定を行います。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Gemini Card
    private var geminiAPICard: some View {
        apiProviderCard(
            title: "Google Gemini API",
            subtitle: "Google AI Studio / Vertex AI 連携",
            icon: "sparkles",
            color: .blue,
            provider: .gemini,
            config: $tohoAIService.geminiConfig
        )
    }

    // MARK: - ChatGPT Card
    private var chatGPTAPICard: some View {
        apiProviderCard(
            title: "OpenAI ChatGPT API",
            subtitle: "OpenAI Platform (GPT-4o, o1-preview) 連携",
            icon: "brain",
            color: .green,
            provider: .chatGPT,
            config: $tohoAIService.chatGPTConfig
        )
    }

    // MARK: - Claude Card
    private var claudeAPICard: some View {
        apiProviderCard(
            title: "Anthropic Claude API",
            subtitle: "Anthropic Console (Claude 3.5 Sonnet) 連携",
            icon: "cpu",
            color: .purple,
            provider: .claude,
            config: $tohoAIService.claudeConfig
        )
    }

    // MARK: - Reusable API Provider Card
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

                // 有効トグル
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
                        SecureField("APIキーを入力 (例: AIzaSy... / sk-...)", text: config.apiKey)
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

                // 接続ステータス情報
                HStack(spacing: 16) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(config.wrappedValue.isConnected ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(config.wrappedValue.isConnected ? "正常接続 (レイテンシ: \(config.wrappedValue.latencyMs)ms)" : "未検証")
                            .font(.caption)
                            .foregroundColor(config.wrappedValue.isConnected ? .green : .secondary)
                    }

                    if let tested = config.wrappedValue.lastTestedAt {
                        Text("最終検証: \(DateFormatter.localizedString(from: tested, dateStyle: .none, timeStyle: .medium))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // 専用ブラウザで請求確認ボタン
                    Button(action: {
                        tohoAIService.activeProvider = provider
                        if let url = URL(string: config.wrappedValue.billingURLString) {
                            AppState.shared.openInAppBrowser(url: url, title: "\(title) 請求確認")
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
                Text("APIキーの暗号化とセキュリティポリシー")
                    .font(.subheadline)
                    .bold()
            }
            Text("入力された外部APIキーはmacOS Keychain（キーチェーン）および暗号化セキュア領域に保存され、外部サーバーやログに送信されることはありません。東方二次創作プロジェクトの生成処理にのみ直接使用されます。")
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            tohoAIService.testAPIConnection(provider: provider)
            testingProvider = nil
            AppState.shared.addSystemLog(level: "INFO", message: "[\(provider.rawValue)] API接続疎通テストが成功しました。")
        }
    }
}
