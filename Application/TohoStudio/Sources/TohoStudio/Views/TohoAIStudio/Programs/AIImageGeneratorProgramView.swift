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
        HStack(spacing: 0) {
            // 左側: パラメータ設定コントロールパネル
            leftControlPanel
                .frame(width: 360)

            Divider()

            // 右側: プレビュー＆生成履歴
            rightPreviewPanel
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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

    // MARK: - Left Control Panel
    private var leftControlPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // タイトル
                HStack(spacing: 8) {
                    Image(systemName: "photo.artframe")
                        .font(.title2)
                        .foregroundColor(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("東方AI画像ジェネレーター")
                            .font(.headline)
                        Text("東方名所・キャラクター立ち絵・弾幕CG生成")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }

                Divider()

                // プロンプト入力
                VStack(alignment: .leading, spacing: 6) {
                    Text("プロンプト (呪文):")
                        .font(.caption)
                        .bold()
                    TextEditor(text: $imageService.prompt)
                        .font(.system(.caption, design: .monospaced))
                        .frame(height: 70)
                        .padding(4)
                        .background(Color(NSColor.textBackgroundColor))
                        .cornerRadius(6)
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                }

                // 東方キャラクター選択
                VStack(alignment: .leading, spacing: 6) {
                    Text("登場キャラクター:")
                        .font(.caption)
                        .bold()
                    Picker("", selection: $imageService.selectedCharacter) {
                        ForEach(["博麗霊夢", "霧雨魔理沙", "十六夜咲夜", "魂魄妖夢", "レミリア", "フランドール", "チルノ", "東風谷早苗", "射命丸文", "鈴仙", "アリス", "パチュリー", "西行寺幽々子"], id: \.self) { c in
                            Text(c).tag(c)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // 幻想郷背景シーンプリセット
                VStack(alignment: .leading, spacing: 6) {
                    Text("背景・ステージ選択:")
                        .font(.caption)
                        .bold()
                    Picker("", selection: $imageService.selectedScene) {
                        ForEach(AIImageGeneratorService.ImageScenePreset.allCases) { scene in
                            Text(scene.rawValue).tag(scene)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // アートスタイル
                VStack(alignment: .leading, spacing: 6) {
                    Text("描画スタイル:")
                        .font(.caption)
                        .bold()
                    Picker("", selection: $imageService.selectedStyle) {
                        ForEach(AIImageGeneratorService.ImageStylePreset.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // アスペクト比
                VStack(alignment: .leading, spacing: 6) {
                    Text("アスペクト比 / 解像度:")
                        .font(.caption)
                        .bold()
                    Picker("", selection: $imageService.selectedAspectRatio) {
                        ForEach(AIImageGeneratorService.ImageAspectRatio.allCases) { ratio in
                            Text(ratio.rawValue).tag(ratio)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // シード値
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("シード値 (ランダム: -1):")
                            .font(.caption)
                        Spacer()
                        Button("ランダム化") {
                            imageService.seed = -1
                        }
                        .font(.caption2)
                        .buttonStyle(.plain)
                        .foregroundColor(.blue)
                    }
                    TextField("-1", value: $imageService.seed, formatter: NumberFormatter())
                        .textFieldStyle(.roundedBorder)
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
                    HStack(spacing: 8) {
                        Button(action: {
                            imageService.saveToMaterialStudio(item: current)
                            alertMessage = "『\(current.title)』を素材スタジオに登録しました！"
                            showSaveAlert = true
                        }) {
                            Label("素材スタジオへ保存", systemImage: "folder.badge.plus")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)

                        Button(action: {
                            imageService.applyToMovieMakerBackground(item: current)
                            alertMessage = "『\(current.title)』をムービーメーカーの背景に設定しました！"
                            showSaveAlert = true
                        }) {
                            Label("ムービー背景に設定", systemImage: "film")
                                .font(.caption)
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: {
                            NSWorkspace.shared.activateFileViewerSelecting([current.fileURL])
                        }) {
                            Label("Finderで表示", systemImage: "arrow.up.right.square")
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
                        Text("東方Projectの幻想郷シーンをCoreGraphics高精度レンダリング中...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
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
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 64))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("左側のパネルでシーン・キャラクターを選択し、\n「AI画像を生成」をクリックしてください。")
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
