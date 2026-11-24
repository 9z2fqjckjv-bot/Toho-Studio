import SwiftUI
import AppKit
import AVKit

/// 仕様書「AI画像・動画生成機能」プログラム (外部AI API専用モデル直結版)
public struct AIImageGeneratorProgramView: View {
    @ObservedObject var imageService = AIImageGeneratorService.shared
    @ObservedObject var tohoAIService = TohoAIService.shared
    @ObservedObject var appState = AppState.shared

    @State private var showSaveAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var activeVideoPlayer: AVPlayer? = nil

    public init() {}

    private var activeModality: AIMediaModality {
        imageService.selectedOutputType == .video ? .video : .image
    }

    private var currentProviderBinding: Binding<AIMediaProviderType> {
        imageService.selectedOutputType == .video ? $imageService.videoProvider : $imageService.imageProvider
    }

    private var currentModelBinding: Binding<String> {
        imageService.selectedOutputType == .video ? $imageService.videoModelId : $imageService.imageModelId
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider()

            HStack(spacing: 0) {
                leftControlPanel
                    .frame(width: 370)

                Divider()

                rightPreviewPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            if let videoURL = imageService.generatedVideoURL,
               let first = imageService.generatedImagesHistory.first, first.isVideo {
                activeVideoPlayer = AVPlayer(url: videoURL)
            }
        }
        .onChange(of: imageService.generatedVideoURL) { newURL in
            if let url = newURL {
                activeVideoPlayer = AVPlayer(url: url)
            } else {
                activeVideoPlayer = nil
            }
        }
        .alert(isPresented: $showSaveAlert) {
            Alert(
                title: Text("メディア出力・転送完了"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Header Bar (事前登録された外部AIプロバイダー ＆ 専用モデル選択)
    private var headerBar: some View {
        let currentProvider = currentProviderBinding.wrappedValue
        let availableModels = currentProvider.models(for: activeModality)

        return HStack(spacing: 12) {
            Picker("プロバイダー", selection: currentProviderBinding) {
                ForEach(AIMediaProviderType.providers(for: activeModality)) { provider in
                    let prefix = (provider != .localBuiltIn && tohoAIService.isMediaProviderConfigured(provider)) ? "✓ " : ""
                    Label("\(prefix)\(provider.rawValue)", systemImage: provider.iconName).tag(provider)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 240)

            Picker("専用モデル", selection: currentModelBinding) {
                ForEach(availableModels) { spec in
                    Text(spec.displayName).tag(spec.id)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 260)

            providerStatusBadge(for: currentProvider)

            Spacer()

            Button(action: {
                tohoAIService.activeProgramTab = .externalAPI
            }) {
                Label("APIキー管理", systemImage: "key.fill")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func providerStatusBadge(for provider: AIMediaProviderType) -> some View {
        let isLocal = provider == .localBuiltIn
        let isReady = tohoAIService.isMediaProviderConfigured(provider)
        let autoFallbackList = tohoAIService.configuredMediaProviders(for: activeModality)

        let badgeColor: Color
        let labelText: String
        if isLocal {
            badgeColor = .blue
            labelText = "内蔵オフラインモード (APIキー不要)"
        } else if isReady {
            badgeColor = .green
            labelText = "APIキー有効・定額枠消費なし"
        } else if let alt = autoFallbackList.first {
            badgeColor = .teal
            labelText = "未登録（実行時に \(alt.rawValue) へ自動切替）"
        } else {
            badgeColor = .orange
            labelText = "APIキー未登録（「APIキー管理」で設定）"
        }

        return HStack(spacing: 5) {
            Circle()
                .fill(badgeColor)
                .frame(width: 7, height: 7)
            Text(labelText)
                .font(.caption2)
                .bold()
                .foregroundColor(badgeColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(badgeColor.opacity(0.1))
        .cornerRadius(6)
    }

    // MARK: - Left Control Panel
    private var leftControlPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.title2)
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("AI画像・動画ジェネレーター")
                            .font(.headline)
                        Text("登録済みの外部AI APIから画像・動画の専用モデルを呼び出し")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                Divider()

                // 出力メディア種別 (画像 / AI動画)
                VStack(alignment: .leading, spacing: 6) {
                    Text("出力メディア種別:")
                        .font(.caption)
                        .bold()

                    Picker("", selection: $imageService.selectedOutputType) {
                        ForEach(AIImageGeneratorService.MediaOutputType.allCases) { type in
                            Label(type.rawValue, systemImage: type.iconName).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // 専用APIモデル状態カード
                externalMediaModelCard

                // プロンプト入力エリア
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("生成プロンプト:")
                            .font(.caption)
                            .bold()
                        Spacer()
                        Text("日本語・英語両対応")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    TextEditor(text: $imageService.prompt)
                        .font(.system(.body, design: .default))
                        .frame(height: 115)
                        .padding(6)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            promptTagButton("古明地こいし 笑顔 サードアイ 帽子")
                            promptTagButton("古明地さとり 読心術 サードアイ")
                            promptTagButton("博麗霊夢 笑顔 巫女服 桜吹雪")
                            promptTagButton("霧雨魔理沙 魔法の森 星空 マスタースパーク")
                            promptTagButton("十六夜咲夜 紅魔館 懐中時計 ナイフ")
                            promptTagButton("学校の中庭が窓から見える保健室のイラスト")
                            promptTagButton("夕暮れの現代都市と摩天楼")
                            promptTagButton("サイバーパンクのネオン街")
                        }
                    }
                }

                // アスペクト比選択
                VStack(alignment: .leading, spacing: 6) {
                    Text("アスペクト比:")
                        .font(.caption)
                        .bold()
                    Picker("", selection: $imageService.selectedAspectRatio) {
                        ForEach(AIImageGeneratorService.ImageAspectRatio.allCases) { aspect in
                            Text(aspect.rawValue).tag(aspect)
                        }
                    }
                    .pickerStyle(.menu)
                }

                if imageService.selectedOutputType == .image {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("生成ソース優先度:")
                            .font(.caption)
                            .bold()
                        Picker("", selection: $imageService.generationSourceMode) {
                            ForEach(AIImageGeneratorService.GenerationSourceMode.allCases) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                // ネガティブプロンプト
                VStack(alignment: .leading, spacing: 6) {
                    Text("除外したい要素 (ネガティブプロンプト):")
                        .font(.caption)
                        .bold()
                    TextField("除外キーワード（例: 低解像度, 崩れた構図, ノイズ）", text: $imageService.negativePrompt)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                }

                if imageService.selectedOutputType == .image {
                    HStack {
                        Text("シード値:")
                            .font(.caption)
                        Spacer()
                        TextField("-1", value: $imageService.seed, formatter: NumberFormatter())
                            .frame(width: 80)
                            .textFieldStyle(.roundedBorder)
                        Button("ランダム") {
                            imageService.seed = -1
                        }
                        .font(.caption2)
                        .buttonStyle(.bordered)
                    }
                }

                Divider()

                // 生成アクションセクション
                VStack(spacing: 8) {
                    if imageService.selectedOutputType == .image,
                       let refMatch = imageService.detectReferenceAsset(for: imageService.prompt) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 6) {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.blue)
                                Text("公式参考資料を検出:")
                                    .font(.caption2)
                                    .bold()
                                    .foregroundColor(.secondary)
                            }
                            Text(refMatch.description)
                                .font(.caption)
                                .bold()
                                .lineLimit(2)

                            Button(action: {
                                imageService.applyReferenceAssetDirectly(match: refMatch)
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.seal.fill")
                                    Text("公式原画素材をそのまま適用 (エフェクトなし)")
                                        .font(.caption2)
                                        .bold()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 5)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.blue)
                        }
                        .padding(8)
                        .background(Color.blue.opacity(0.08))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.blue.opacity(0.2), lineWidth: 1))
                    }

                    Button(action: {
                        imageService.generateImage(forceAI: imageService.generationSourceMode == .aiGeneration)
                    }) {
                        let currentProv = currentProviderBinding.wrappedValue
                        let modelTitle = currentProv.displayName(forModelId: currentModelBinding.wrappedValue, modality: activeModality)
                        HStack(spacing: 8) {
                            if imageService.isGenerating {
                                ProgressView().controlSize(.small)
                                Text("専用モデル呼び出し中...")
                                    .bold()
                            } else if imageService.selectedOutputType == .image && imageService.generationSourceMode == .referenceAsset {
                                Image(systemName: "folder.fill")
                                Text("公式参考資料の原画を適用")
                                    .bold()
                            } else {
                                Image(systemName: imageService.selectedOutputType == .video ? "film.stack.fill" : "sparkles")
                                Text(imageService.selectedOutputType == .video
                                     ? "AI動画を生成 (\(modelTitle))"
                                     : "AI画像を生成 (\(modelTitle))")
                                    .bold()
                                    .lineLimit(1)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .foregroundColor(.white)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(
                                    LinearGradient(
                                        colors: imageService.selectedOutputType == .video
                                            ? [Color.pink, Color.purple]
                                            : [Color.indigo, Color.blue],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(imageService.isGenerating)
                }

                Spacer()
            }
            .padding(16)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Dedicated External API Model Card
    private var externalMediaModelCard: some View {
        let configuredList = tohoAIService.configuredMediaProviders(for: activeModality)
        let currentProv = currentProviderBinding.wrappedValue
        let currentModName = currentProv.displayName(forModelId: currentModelBinding.wrappedValue, modality: activeModality)

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "key.radiowaves.forward.fill")
                    .foregroundColor(.indigo)
                Text(activeModality == .video ? "動画生成 専用AIモデル連携" : "画像生成 専用AIモデル連携")
                    .font(.caption)
                    .bold()
                Spacer()
                Text("登録済API: \(configuredList.count)社")
                    .font(.caption2)
                    .bold()
                    .foregroundColor(configuredList.isEmpty ? .orange : .green)
            }

            Text("選択中: \(currentProv.rawValue) / \(currentModName)")
                .font(.caption2)
                .foregroundColor(.secondary)
                .lineLimit(2)

            Toggle("API未登録時にローカル参考資料・演出動画へフォールバック", isOn: $imageService.allowOfflineFallback)
                .font(.caption2)

            if configuredList.isEmpty && currentProv != .localBuiltIn {
                Button(action: {
                    tohoAIService.activeProgramTab = .externalAPI
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle.fill")
                        Text("外部APIキーを登録して専用モデルを有効化...")
                            .font(.caption2)
                            .bold()
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.indigo))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .background(Color.indigo.opacity(0.07))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.indigo.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Right Preview Panel
    private var rightPreviewPanel: some View {
        VStack(spacing: 0) {
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(imageService.isGenerating ? Color.orange : (imageService.currentStatusMessage.hasPrefix("⚠️") ? Color.red : Color.green))
                        .frame(width: 8, height: 8)
                    Text(imageService.currentStatusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                if let current = imageService.generatedImagesHistory.first {
                    HStack(spacing: 6) {
                        Menu {
                            if !current.isVideo {
                                Button(action: {
                                    imageService.sendToCharacterMakerAsPart(item: current)
                                    alertMessage = "『\(current.title)』をキャラクターメーカーの立ち絵パーツとして登録しました！"
                                    showSaveAlert = true
                                }) {
                                    Label("立ち絵パーツとして転送", systemImage: "person.crop.rectangle.badge.plus")
                                }

                                Button(action: {
                                    imageService.sendToCharacterMakerAsBackground(item: current)
                                    alertMessage = "『\(current.title)』をキャラクターメーカーの背景に設定しました！"
                                    showSaveAlert = true
                                }) {
                                    Label("立ち絵の背景に設定", systemImage: "photo.stack")
                                }

                                Button(action: {
                                    imageService.sendToSlideScenarioMaker(item: current)
                                    alertMessage = "『\(current.title)』をスライドシナリオメーカーに挿入しました！"
                                    showSaveAlert = true
                                }) {
                                    Label("スライドへ挿入", systemImage: "rectangle.inset.filled.and.person.filled")
                                }
                            }

                            Button(action: {
                                imageService.applyToMovieMakerBackground(item: current)
                                alertMessage = "『\(current.title)』をムービーメーカーの背景に設定しました！"
                                showSaveAlert = true
                            }) {
                                Label("ムービー背景に設定", systemImage: "film")
                            }

                            Divider()

                            Button(action: {
                                imageService.saveToMaterialStudio(item: current)
                                alertMessage = "『\(current.title)』を素材スタジオに登録しました！"
                                showSaveAlert = true
                            }) {
                                Label("素材スタジオへ保存", systemImage: "folder.badge.plus")
                            }
                        } label: {
                            Label("他ツールへ転送", systemImage: "square.and.arrow.up")
                                .font(.caption)
                        }
                        .menuStyle(.borderedButton)

                        if !current.isVideo {
                            Button(action: {
                                imageService.sendToCharacterMakerAsPart(item: current)
                                alertMessage = "『\(current.title)』をキャラクターメーカーの立ち絵パーツに追加しました！"
                                showSaveAlert = true
                            }) {
                                Label("立ち絵パーツ化", systemImage: "person.crop.rectangle.badge.plus")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button(action: {
                                NSWorkspace.shared.open(current.fileURL)
                            }) {
                                Label("動画を開く", systemImage: "play.rectangle.fill")
                                    .font(.caption)
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        Button(action: {
                            NSWorkspace.shared.activateFileViewerSelecting([current.fileURL])
                        }) {
                            Label("Finder", systemImage: "arrow.up.right.square")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))

            Divider()

            // メインプレビュー領域
            VStack {
                if imageService.isGenerating {
                    VStack(spacing: 16) {
                        Spacer()
                        ProgressView(value: imageService.generationProgress)
                            .progressViewStyle(.linear)
                            .frame(width: 300)
                        Text(imageService.currentStatusMessage)
                            .font(.headline)
                            .multilineTextAlignment(.center)
                        Text(imageService.selectedOutputType == .video
                             ? "外部AI動画専用モデル（Veo / Sora / Wan / Kling / Runway / Luma）でMP4動画をレンダリング中..."
                             : "外部AI画像専用モデル（Imagen 3/4 / GPT Image 1 / Stable Image / FLUX / Grok）で高精細画像を生成中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding()
                } else if let first = imageService.generatedImagesHistory.first,
                          first.isVideo,
                          first.fileURL == imageService.generatedVideoURL,
                          let player = activeVideoPlayer {
                    VStack(spacing: 10) {
                        VideoPlayer(player: player)
                            .cornerRadius(12)
                            .padding(20)
                            .onAppear {
                                player.play()
                            }
                    }
                } else if let img = imageService.generatedImage {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(nsImage: img)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .cornerRadius(12)
                            .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                            .padding(20)
                        Spacer()
                    }
                } else {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "sparkles.rectangle.stack")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("事前に登録した外部AI APIキーから、画像生成モデル（Imagen 3/4・GPT Image 1・Stable Image・FLUX・Grok）や\n動画生成モデル（Veo 2/3・Sora 2・Wan 2.1・Kling・Runway Gen-4・Luma Ray 2）を直接呼び出して生成できます。")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                    .padding()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.15))

            Divider()

            bottomHistoryBar
        }
    }

    // MARK: - Prompt Quick Tag Button
    private func promptTagButton(_ tag: String) -> some View {
        Button(action: {
            imageService.prompt = tag
        }) {
            Text(tag)
                .font(.system(size: 10))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.blue.opacity(0.12))
                .foregroundColor(.blue)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Bottom History Bar
    private var bottomHistoryBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("生成履歴 (\(imageService.generatedImagesHistory.count)件):")
                .font(.caption2)
                .bold()
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)
                .padding(.top, 8)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(imageService.generatedImagesHistory) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Button(action: {
                                imageService.generatedImage = item.image
                                if item.isVideo {
                                    imageService.generatedVideoURL = item.fileURL
                                    activeVideoPlayer = AVPlayer(url: item.fileURL)
                                } else {
                                    imageService.generatedImageURL = item.fileURL
                                    imageService.generatedVideoURL = nil
                                }
                            }) {
                                ZStack(alignment: .bottomTrailing) {
                                    Image(nsImage: item.image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 100, height: 60)
                                        .cornerRadius(6)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 6)
                                                .stroke((imageService.generatedImageURL == item.fileURL || imageService.generatedVideoURL == item.fileURL) ? Color.blue : Color.clear, lineWidth: 2)
                                        )
                                    if item.isVideo {
                                        Image(systemName: "film.fill")
                                            .font(.system(size: 9))
                                            .foregroundColor(.white)
                                            .padding(3)
                                            .background(Color.black.opacity(0.7))
                                            .cornerRadius(4)
                                            .padding(3)
                                    }
                                }
                            }
                            .buttonStyle(.plain)

                            Text(item.title)
                                .font(.system(size: 9))
                                .lineLimit(1)
                                .frame(width: 100, alignment: .leading)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
            }
        }
        .frame(height: 110)
        .background(Color(NSColor.controlBackgroundColor))
    }
}
