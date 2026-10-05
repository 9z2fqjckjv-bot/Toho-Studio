import SwiftUI
import AppKit

/// 仕様書「AI画像生成機能」プログラム
/// 東方Project専用のプロシージャルCoreGraphics高品位描画 ＆ 外部API連携
public struct AIImageGeneratorProgramView: View {
    @ObservedObject var imageService = AIImageGeneratorService.shared
    @ObservedObject var tohoAIService = TohoAIService.shared
    @ObservedObject var cloudLinuxService = CloudVirtualLinuxService.shared
    @ObservedObject var appState = AppState.shared

    @State private var showSaveAlert: Bool = false
    @State private var alertMessage: String = ""

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // 上部ツールバー (AIチャットと同様のエンジン・モデル選択)
            headerBar

            Divider()

            HStack(spacing: 0) {
                // 左側: パラメータ設定コントロールパネル
                leftControlPanel
                    .frame(width: 360)

                Divider()

                // 右側: プレビュー＆生成履歴
                rightPreviewPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .alert(isPresented: $showSaveAlert) {
            Alert(
                title: Text("画像出力・転送完了"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Header Bar (AIチャットと同様のエンジン・モデル選択)
    private var headerBar: some View {
        HStack(spacing: 12) {
            // プロバイダー選択
            Picker("エンジン", selection: $imageService.selectedProvider) {
                ForEach(AIProviderType.allCases) { provider in
                    Label(provider.rawValue, systemImage: provider.iconName).tag(provider)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 220)

            // モデル選択
            Picker("モデル", selection: $imageService.selectedModel) {
                ForEach(imageService.selectedProvider.availableModels, id: \.self) { model in
                    Text(model).tag(model)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 200)

            // 接続ステータスバッジ
            apiStatusBadge(for: imageService.selectedProvider)

            Spacer()

            // プロンプト残数バッジ
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .foregroundColor(.yellow)
                Text("残プロンプト: \(cloudLinuxService.remainingPrompts) / \(cloudLinuxService.totalPromptsMonthly)")
                    .font(.caption)
                    .bold()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.12))
            .cornerRadius(8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func apiStatusBadge(for provider: AIProviderType) -> some View {
        let isConfigured: Bool
        let labelText: String

        switch provider {
        case .chatGPT:
            isConfigured = !tohoAIService.chatGPTConfig.apiKey.isEmpty
            labelText = isConfigured ? "OpenAI連携中 (DALL-E 3)" : "ChatGPT推論＋高精細拡散"
        case .gemini:
            isConfigured = !tohoAIService.geminiConfig.apiKey.isEmpty
            labelText = isConfigured ? "Gemini連携中 (Imagen 3)" : "Gemini推論＋高精細拡散"
        case .claude:
            isConfigured = !tohoAIService.claudeConfig.apiKey.isEmpty
            labelText = isConfigured ? "Claude連携中" : "Claude推論＋高精細拡散"
        case .virtualLinuxVM:
            if cloudLinuxService.colabBridge.isOnline && !cloudLinuxService.colabBridge.endpoint.isEmpty {
                isConfigured = true
                labelText = "⚡️ Colab GPU ブリッジ接続中 (\(cloudLinuxService.colabBridge.gpuName))"
            } else {
                isConfigured = (cloudLinuxService.connectionStatus == .connected || cloudLinuxService.connectionStatus == .lowLatency)
                labelText = isConfigured ? "仮想LinuxVM接続中 (DeepSeek-R1/Gemma)" : "スタンドアロン推論"
            }
        }

        return HStack(spacing: 4) {
            Circle()
                .fill(isConfigured ? Color.green : Color.blue)
                .frame(width: 7, height: 7)
            Text(labelText)
                .font(.caption2)
                .bold()
                .foregroundColor(isConfigured ? .primary : .secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.08))
        .cornerRadius(6)
    }

    // MARK: - Left Control Panel
    private var leftControlPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // タイトル
                HStack(spacing: 8) {
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.title2)
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("本格AI画像・動画ジェネレーター")
                            .font(.headline)
                        Text("プロンプト1つで高精細AIイラストやMP4アニメ動画を生成")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                Divider()

                // 出力メディア種別 (画像 / アニメーション動画)
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

                    if imageService.selectedOutputType == .video {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .foregroundColor(.yellow)
                            Text("Google Colab GPU (AnimateDiff) による16フレームループMP4動画")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 2)
                    }
                }

                // プロンプト入力エリア (メイン)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("生成プロンプト:")
                            .font(.caption)
                            .bold()
                        Spacer()
                        Text("自由記述（被写体・構図・照明・雰囲気）")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    TextEditor(text: $imageService.prompt)
                        .font(.system(.body, design: .default))
                        .frame(height: 120)
                        .padding(6)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))

                    // クイック入力サジェストタグ
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
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

                // ネガティブプロンプト
                VStack(alignment: .leading, spacing: 6) {
                    Text("除外したい要素 (ネガティブプロンプト):")
                        .font(.caption)
                        .bold()
                    TextField("除外キーワード（例: 低解像度, 崩れた構図, ノイズ）", text: $imageService.negativePrompt)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                }

                // シード値（ランダム設定）
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

                Divider()

                // プロンプト消費と生成ボタン
                VStack(spacing: 8) {
                    HStack {
                        Text("残プロンプト:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("\(cloudLinuxService.remainingPrompts) / \(cloudLinuxService.totalPromptsMonthly)")
                            .font(.caption)
                            .bold()
                    }

                    Button(action: {
                        imageService.generateImage()
                    }) {
                        HStack(spacing: 8) {
                            if imageService.isGenerating {
                                ProgressView().controlSize(.small)
                            } else {
                                Image(systemName: "sparkles")
                            }
                            Text(imageService.isGenerating ? "生成中..." : "AI画像を生成 (1プロンプト消費)")
                                .bold()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(imageService.isGenerating)
                }

                Spacer()
            }
            .padding(16)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Right Preview Panel
    private var rightPreviewPanel: some View {
        VStack(spacing: 0) {
            // ステータスヘッダー
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(imageService.isGenerating ? Color.orange : Color.green)
                        .frame(width: 8, height: 8)
                    Text(imageService.currentStatusMessage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if let current = imageService.generatedImagesHistory.first {
                    HStack(spacing: 6) {
                        Menu {
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

                        Button(action: {
                            imageService.sendToCharacterMakerAsPart(item: current)
                            alertMessage = "『\(current.title)』をキャラクターメーカーの立ち絵パーツに追加しました！"
                            showSaveAlert = true
                        }) {
                            Label("立ち絵パーツ化", systemImage: "person.crop.rectangle.badge.plus")
                                .font(.caption)
                        }
                        .buttonStyle(.borderedProminent)

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
                            .frame(width: 280)
                        Text(imageService.currentStatusMessage)
                            .font(.headline)
                        Text(imageService.selectedOutputType == .video ? "Google Colab GPU (AnimateDiff) によるアニメーション動画生成中..." : "最新AI拡散モデル（Colab GPU / Gemini / Imagen 3 / DALL-E）による高精細ピクセル生成中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                } else if let img = imageService.generatedImage {
                    VStack(spacing: 12) {
                        Spacer()
                        ZStack(alignment: .topTrailing) {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .cornerRadius(12)
                                .shadow(color: Color.black.opacity(0.3), radius: 10, x: 0, y: 5)
                                .padding(20)

                            if let first = imageService.generatedImagesHistory.first, first.isVideo {
                                HStack(spacing: 4) {
                                    Image(systemName: "film.fill")
                                    Text("MP4アニメ動画")
                                }
                                .font(.caption2)
                                .bold()
                                .foregroundColor(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.red.opacity(0.85))
                                .cornerRadius(8)
                                .padding(30)
                            }
                        }
                        Spacer()
                    }
                } else {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "sparkles.rectangle.stack")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("Google Geminiアプリ同様、自由なプロンプト1つで高精細イラストやアニメ動画を生成できます。\nGoogle Colab GPUブリッジ接続時は最先端SD-Turbo / AnimateDiffにより1〜2秒で即座に手元に届きます。")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.15))

            Divider()

            // 下部生成履歴サムネイル
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
                                imageService.generatedImageURL = item.fileURL
                            }) {
                                Image(nsImage: item.image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 60)
                                    .cornerRadius(6)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 6)
                                            .stroke(imageService.generatedImageURL == item.fileURL ? Color.blue : Color.clear, lineWidth: 2)
                                    )
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
