import SwiftUI
import AppKit

/// 仕様書「外部APIの起動・運用管理 & メディア生成専用AI APIキー登録 & Nanndemoya独自API認証」プログラム
public struct ExternalAPIManagementProgramView: View {
    @ObservedObject var tohoAIService = TohoAIService.shared
    @ObservedObject var imageService = AIImageGeneratorService.shared
    @ObservedObject var soundService = AISoundGeneratorService.shared

    @State private var testingLLMProvider: AIProviderType? = nil
    @State private var testingMediaProvider: AIMediaProviderType? = nil
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

                // 1. メディア生成 デフォルト専用モデル割り当て（画像・動画・SE・BGM）
                defaultMediaRoutingCard

                Divider()

                // 2. Nanndemoya独自API（ライセンスキー認証）
                nanndemoyaLicenseCard

                Divider()

                // 3. メディア生成特化 外部AI APIキー連携（ElevenLabs / Stability AI / fal.ai / Replicate / Runway / Luma）
                VStack(alignment: .leading, spacing: 4) {
                    Text("メディア生成専用 外部AI APIキー登録（画像・動画・SE・BGM）")
                        .font(.headline)
                    Text("登録・有効化したAPIキーから、AI画像・動画生成およびAI音楽・SE生成スタジオで各社専用モデルを直接呼び出せます。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                mediaProviderCard(
                    provider: .elevenLabs,
                    color: .pink,
                    keyPlaceholder: "sk_... (ElevenLabs API Key)",
                    config: $tohoAIService.elevenLabsConfig
                )
                mediaProviderCard(
                    provider: .stabilityAI,
                    color: .indigo,
                    keyPlaceholder: "sk-... (Stability AI API Key)",
                    config: $tohoAIService.stabilityConfig
                )
                mediaProviderCard(
                    provider: .falAI,
                    color: .cyan,
                    keyPlaceholder: "key_id:key_secret (fal.ai API Key)",
                    config: $tohoAIService.falAIConfig
                )
                mediaProviderCard(
                    provider: .replicate,
                    color: .mint,
                    keyPlaceholder: "r8_... (Replicate API Token)",
                    config: $tohoAIService.replicateConfig
                )
                mediaProviderCard(
                    provider: .runway,
                    color: .red,
                    keyPlaceholder: "key_... (Runway API Secret)",
                    config: $tohoAIService.runwayConfig
                )
                mediaProviderCard(
                    provider: .luma,
                    color: .yellow,
                    keyPlaceholder: "luma-... (Luma Dream Machine Key)",
                    config: $tohoAIService.lumaConfig
                )

                Divider()

                // 4. 5大LLM & マルチモーダル外部APIカード（Gemini / OpenAI / Grok は画像・動画専用モデルも共用可能）
                VStack(alignment: .leading, spacing: 4) {
                    Text("LLMチャット・編集 ＆ マルチモーダル外部APIキー連携（Gemini / OpenAI / Claude / Grok / Mistral）")
                        .font(.headline)
                    Text("Google Gemini（Imagen 3/4・Veo 2/3）、OpenAI（GPT Image 1・DALL-E 3・Sora 2）、xAI Grok（Grok Imagine 2.0）はここで登録したAPIキーを画像・動画生成でも共用できます。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                apiProviderCard(
                    title: "Google Gemini API",
                    subtitle: "Google AI Studio (LLM: Gemini 2.5 / 画像: Imagen 3・4, Flash Image / 動画: Veo 2・3)",
                    mediaBadges: ["画像: Imagen 3/4", "動画: Veo 2/3"],
                    mediaLinkProvider: .gemini,
                    icon: "sparkles",
                    color: .blue,
                    provider: .gemini,
                    config: $tohoAIService.geminiConfig
                )
                apiProviderCard(
                    title: "OpenAI API (ChatGPT / Image / Sora)",
                    subtitle: "OpenAI Platform (LLM: GPT-4o, o3-mini / 画像: GPT Image 1, DALL-E 3 / 動画: Sora 2)",
                    mediaBadges: ["画像: GPT Image 1 / DALL-E 3", "動画: Sora 2"],
                    mediaLinkProvider: .openAI,
                    icon: "brain",
                    color: .green,
                    provider: .chatGPT,
                    config: $tohoAIService.chatGPTConfig
                )
                apiProviderCard(
                    title: "xAI Grok API",
                    subtitle: "xAI Console (LLM: Grok 3 / 画像: Grok Imagine Image 2.0)",
                    mediaBadges: ["画像: Grok Imagine 2.0"],
                    mediaLinkProvider: .grok,
                    icon: "bolt.horizontal.circle.fill",
                    color: .orange,
                    provider: .grok,
                    config: $tohoAIService.grokConfig
                )
                apiProviderCard(
                    title: "Anthropic Claude API",
                    subtitle: "Anthropic Console (Claude 3.7 Sonnet / 3.5 Haiku — チャット・推敲・プロンプト英訳連携)",
                    mediaBadges: [],
                    mediaLinkProvider: nil,
                    icon: "cpu",
                    color: .purple,
                    provider: .claude,
                    config: $tohoAIService.claudeConfig
                )
                apiProviderCard(
                    title: "Mistral Large API",
                    subtitle: "Mistral AI La Plateforme (Mistral Large / Small — チャット・推敲連携)",
                    mediaBadges: [],
                    mediaLinkProvider: nil,
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
                    Text("外部AI APIキー登録 & 専用メディアモデル運用管理")
                        .font(.title2)
                        .bold()
                }
                Text("事前にAPIキーを登録しておくと、画像・動画・SE・BGM生成およびAIチャットで各社の専用モデルを直接呼び出せます（定額プラン枠は消費されません）。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - Default Media Model Assignment Card (画像 / 動画 / SE / BGM)
    private var defaultMediaRoutingCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "slider.horizontal.2.square.on.square")
                    .font(.title3)
                    .foregroundColor(.indigo)
                VStack(alignment: .leading, spacing: 2) {
                    Text("メディア種別ごとのデフォルト専用モデル設定（画像・動画・SE・BGM）")
                        .font(.headline)
                    Text("各メディア生成スタジオで標準使用するプロバイダーと専用モデルを指定できます。")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("AI画像・動画生成を開く") {
                    tohoAIService.activeProgramTab = .aiImageGenerator
                }
                .font(.caption)
                .buttonStyle(.bordered)

                Button("AI音楽・SE生成を開く") {
                    tohoAIService.activeProgramTab = .aiSoundGenerator
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }

            Divider()

            modalityAssignmentRow(
                modality: .image,
                providerBinding: Binding(
                    get: { tohoAIService.preferredImageProvider },
                    set: {
                        tohoAIService.preferredImageProvider = $0
                        imageService.syncFromTohoAIPreferences()
                    }
                ),
                modelBinding: Binding(
                    get: { tohoAIService.preferredImageModel },
                    set: {
                        tohoAIService.preferredImageModel = $0
                        imageService.syncFromTohoAIPreferences()
                    }
                )
            )

            modalityAssignmentRow(
                modality: .video,
                providerBinding: Binding(
                    get: { tohoAIService.preferredVideoProvider },
                    set: {
                        tohoAIService.preferredVideoProvider = $0
                        imageService.syncFromTohoAIPreferences()
                    }
                ),
                modelBinding: Binding(
                    get: { tohoAIService.preferredVideoModel },
                    set: {
                        tohoAIService.preferredVideoModel = $0
                        imageService.syncFromTohoAIPreferences()
                    }
                )
            )

            modalityAssignmentRow(
                modality: .se,
                providerBinding: Binding(
                    get: { tohoAIService.preferredSEProvider },
                    set: {
                        tohoAIService.preferredSEProvider = $0
                        soundService.syncFromTohoAIPreferences()
                    }
                ),
                modelBinding: Binding(
                    get: { tohoAIService.preferredSEModel },
                    set: {
                        tohoAIService.preferredSEModel = $0
                        soundService.syncFromTohoAIPreferences()
                    }
                )
            )

            modalityAssignmentRow(
                modality: .bgm,
                providerBinding: Binding(
                    get: { tohoAIService.preferredBGMProvider },
                    set: {
                        tohoAIService.preferredBGMProvider = $0
                        soundService.syncFromTohoAIPreferences()
                    }
                ),
                modelBinding: Binding(
                    get: { tohoAIService.preferredBGMModel },
                    set: {
                        tohoAIService.preferredBGMModel = $0
                        soundService.syncFromTohoAIPreferences()
                    }
                )
            )
        }
        .padding(16)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.indigo.opacity(0.35), lineWidth: 1.5))
    }

    private func modalityAssignmentRow(
        modality: AIMediaModality,
        providerBinding: Binding<AIMediaProviderType>,
        modelBinding: Binding<String>
    ) -> some View {
        let currentProvider = providerBinding.wrappedValue
        let isReady = tohoAIService.isMediaProviderConfigured(currentProvider)
        let models = currentProvider.models(for: modality)

        return HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: modality.iconName)
                    .foregroundColor(.indigo)
                    .frame(width: 20)
                Text(modality.rawValue)
                    .font(.subheadline)
                    .bold()
            }
            .frame(width: 110, alignment: .leading)

            Picker("プロバイダー", selection: providerBinding) {
                ForEach(AIMediaProviderType.providers(for: modality)) { prov in
                    let mark = (prov != .localBuiltIn && tohoAIService.isMediaProviderConfigured(prov)) ? "✓ " : ""
                    Text("\(mark)\(prov.rawValue)").tag(prov)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(width: 220)

            Picker("専用モデル", selection: modelBinding) {
                ForEach(models) { spec in
                    Text(spec.displayName).tag(spec.id)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .frame(minWidth: 240, maxWidth: 320)

            Spacer()

            HStack(spacing: 5) {
                Circle()
                    .fill(currentProvider == .localBuiltIn ? Color.blue : (isReady ? Color.green : Color.orange))
                    .frame(width: 7, height: 7)
                Text(currentProvider == .localBuiltIn ? "内蔵オフライン" : (isReady ? "APIキー有効" : "APIキー未設定"))
                    .font(.caption2)
                    .bold()
                    .foregroundColor(currentProvider == .localBuiltIn ? .blue : (isReady ? .green : .orange))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.08))
            .cornerRadius(6)
        }
    }

    // MARK: - Dedicated Media API Card
    private func mediaProviderCard(
        provider: AIMediaProviderType,
        color: Color,
        keyPlaceholder: String,
        config: Binding<ExternalAPIConfig>
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: provider.iconName)
                    .font(.title2)
                    .foregroundColor(color)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(provider.rawValue)
                            .font(.headline)
                        ForEach(provider.supportedModalities) { mod in
                            Text(mod.rawValue)
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(color.opacity(0.16))
                                .foregroundColor(color)
                                .cornerRadius(4)
                        }
                    }
                    Text(provider.subtitle)
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
                        Text("API Key / Token:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        SecureField(keyPlaceholder, text: config.apiKey)
                            .textFieldStyle(.roundedBorder)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("疎通・認証確認:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Button(action: {
                            runMediaAPITest(provider: provider)
                        }) {
                            HStack(spacing: 4) {
                                if testingMediaProvider == provider {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "waveform.path.ecg")
                                }
                                Text("接続テスト")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(testingMediaProvider != nil || testingLLMProvider != nil)
                    }
                }

                // 対応専用モデル一覧プレビュー
                VStack(alignment: .leading, spacing: 4) {
                    Text("呼び出し可能な専用モデル:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(provider.supportedModalities) { mod in
                                ForEach(provider.models(for: mod)) { spec in
                                    Text("[\(mod.rawValue)] \(spec.displayName)")
                                        .font(.system(size: 10))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(Color.secondary.opacity(0.1))
                                        .cornerRadius(4)
                                }
                            }
                        }
                    }
                }

                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(config.wrappedValue.isConnected ? Color.green : Color.secondary)
                            .frame(width: 8, height: 8)
                        Text(config.wrappedValue.isConnected ? "正常接続 (\(config.wrappedValue.latencyMs)ms)" : "未検証")
                            .font(.caption)
                            .foregroundColor(config.wrappedValue.isConnected ? .green : .secondary)
                    }

                    Spacer()

                    if !config.wrappedValue.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if provider.supportedModalities.contains(.image) || provider.supportedModalities.contains(.video) {
                            Button("画像・動画生成に設定して開く") {
                                if provider.supportedModalities.contains(.image) {
                                    tohoAIService.preferredImageProvider = provider
                                }
                                if provider.supportedModalities.contains(.video) {
                                    tohoAIService.preferredVideoProvider = provider
                                }
                                imageService.syncFromTohoAIPreferences()
                                tohoAIService.activeProgramTab = .aiImageGenerator
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }

                        if provider.supportedModalities.contains(.bgm) || provider.supportedModalities.contains(.se) {
                            Button("音楽・SE生成に設定して開く") {
                                if provider.supportedModalities.contains(.bgm) {
                                    tohoAIService.preferredBGMProvider = provider
                                }
                                if provider.supportedModalities.contains(.se) {
                                    tohoAIService.preferredSEProvider = provider
                                }
                                soundService.syncFromTohoAIPreferences()
                                tohoAIService.activeProgramTab = .aiSoundGenerator
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }
                    }

                    Button(action: {
                        if let url = URL(string: config.wrappedValue.billingURLString) {
                            AppState.shared.openInAppBrowser(url: url, title: "\(provider.rawValue) 請求・使用量確認")
                        }
                    }) {
                        Label("専用ブラウザで請求確認", systemImage: "safari")
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
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.28), lineWidth: 1))
    }

    // MARK: - NanndemoyaAPI 専用カード
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
                    Text("「何でも屋」側で取得・管理するAPIキーを1つのライセンスキーで中継利用します。")
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
                            runLLMAPITest(provider: .nanndemoya)
                        }) {
                            HStack(spacing: 4) {
                                if testingLLMProvider == .nanndemoya {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "checkmark.seal.fill")
                                }
                                Text("ライセンス認証")
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                        .disabled(testingLLMProvider != nil || testingMediaProvider != nil)
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

    // MARK: - Reusable LLM & Multimodal External API Card
    private func apiProviderCard(
        title: String,
        subtitle: String,
        mediaBadges: [String],
        mediaLinkProvider: AIMediaProviderType?,
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
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.headline)
                        ForEach(mediaBadges, id: \.self) { badge in
                            Text(badge)
                                .font(.system(size: 9, weight: .bold))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(color.opacity(0.15))
                                .foregroundColor(color)
                                .cornerRadius(4)
                        }
                    }
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
                        Text("チャット標準モデル:")
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
                            runLLMAPITest(provider: provider)
                        }) {
                            HStack(spacing: 4) {
                                if testingLLMProvider == provider {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "waveform.path.ecg")
                                }
                                Text("接続テスト")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(testingLLMProvider != nil || testingMediaProvider != nil)
                    }
                }

                HStack(spacing: 12) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(config.wrappedValue.isConnected ? Color.green : Color.secondary)
                            .frame(width: 8, height: 8)
                        Text(config.wrappedValue.isConnected ? "正常接続 (レイテンシ: \(config.wrappedValue.latencyMs)ms)" : "未検証")
                            .font(.caption)
                            .foregroundColor(config.wrappedValue.isConnected ? .green : .secondary)
                    }

                    Spacer()

                    if !config.wrappedValue.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        if let mediaProv = mediaLinkProvider {
                            Button("画像・動画生成で使う") {
                                if mediaProv.supportedModalities.contains(.image) {
                                    tohoAIService.preferredImageProvider = mediaProv
                                }
                                if mediaProv.supportedModalities.contains(.video) {
                                    tohoAIService.preferredVideoProvider = mediaProv
                                }
                                imageService.syncFromTohoAIPreferences()
                                tohoAIService.activeProgramTab = .aiImageGenerator
                            }
                            .font(.caption)
                            .buttonStyle(.bordered)
                        }

                        Button("AIチャットで使う") {
                            tohoAIService.activeProvider = provider
                            tohoAIService.selectedModel = config.wrappedValue.selectedModel
                            tohoAIService.activeProgramTab = .aiChat
                        }
                        .font(.caption)
                        .buttonStyle(.bordered)
                    }

                    Button(action: {
                        if let url = URL(string: config.wrappedValue.billingURLString) {
                            AppState.shared.openInAppBrowser(url: url, title: "\(title) 請求・使用量確認")
                        }
                    }) {
                        Label("専用ブラウザで請求確認", systemImage: "safari")
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
            Text("登録した外部AI APIキーは端末ローカルのみに保存され、各AI提供会社（Google / OpenAI / ElevenLabs / Stability AI / fal.ai / Replicate / xAI / Runway / Luma 等）の公式HTTPSエンドポイントとの直接通信にのみ使用されます。")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.green.opacity(0.06))
        .cornerRadius(10)
    }

    private func runLLMAPITest(provider: AIProviderType) {
        testingLLMProvider = provider
        tohoAIService.testAPIConnection(provider: provider) { ok, msg in
            testingLLMProvider = nil
            feedbackBanner = "[\(provider.rawValue)] \(msg)"
            imageService.syncFromTohoAIPreferences()
            AppState.shared.addSystemLog(level: ok ? "INFO" : "WARN", message: "[\(provider.rawValue)] \(msg)")
        }
    }

    private func runMediaAPITest(provider: AIMediaProviderType) {
        testingMediaProvider = provider
        tohoAIService.testMediaAPIConnection(provider: provider) { ok, msg in
            testingMediaProvider = nil
            feedbackBanner = "[\(provider.rawValue)] \(msg)"
            imageService.syncFromTohoAIPreferences()
            soundService.syncFromTohoAIPreferences()
            AppState.shared.addSystemLog(level: ok ? "INFO" : "WARN", message: "[\(provider.rawValue)] \(msg)")
        }
    }
}
