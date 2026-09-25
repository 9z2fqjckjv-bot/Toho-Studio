import SwiftUI

public struct CharacterMakerView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selectedPartIndex: Int = 0
    @State private var showExportDialog: Bool = false
    @State private var exportImageFormat: String = "PNG (透過立ち絵)"

    public var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack(spacing: 14) {
                Label("キャラクターメーカー", systemImage: "person.crop.artframe")
                    .font(.headline)
                Text("(ベース: Google図形描画)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // Extension Badges
                HStack(spacing: 6) {
                    extensionBadge(title: "Photoshop機能", isUnlocked: appState.unlockedExtensions.contains("Photoshop非搭載機能"))
                    extensionBadge(title: "Pixelmator機能", isUnlocked: appState.unlockedExtensions.contains("PixelmatorPro非搭載機能"))
                }

                Divider().frame(height: 18)

                Button(action: { showExportDialog = true }) {
                    Label("立ち絵を書き出し", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Main Editor (Canvas + Parts Tree)
            HSplitView {
                // Character Canvas
                characterPreviewCanvas
                    .frame(minWidth: 400, maxWidth: .infinity)
                    .padding()

                // Parts Inspector
                partsInspectorView
                    .frame(width: 320)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }
        }
        .sheet(isPresented: $showExportDialog) {
            exportDialogView
        }
    }

    private func extensionBadge(title: String, isUnlocked: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isUnlocked ? Color.green : Color.secondary)
                .frame(width: 6, height: 6)
            Text(title).font(.caption2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(4)
    }

    // MARK: - Character Canvas
    private var characterPreviewCanvas: some View {
        VStack(spacing: 12) {
            HStack {
                Text("キャラクター: \(appState.currentCharacter.name)")
                    .font(.headline)
                Spacer()
                Picker("表情", selection: $appState.currentCharacter.expression) {
                    Text("通常").tag("通常")
                    Text("笑顔").tag("笑顔")
                    Text("怒り").tag("怒り")
                    Text("驚き").tag("驚き")
                    Text("困惑").tag("困惑")
                }
                .pickerStyle(.segmented)
                .frame(width: 240)
            }

            ZStack {
                // Background grid for transparency
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(NSColor.controlBackgroundColor))

                // Multi-layer Composite Representation
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.fill")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 180, height: 180)
                        .foregroundColor(.accentColor.opacity(0.8))

                    Text("レイヤー合成プレビュー: [\(appState.currentCharacter.parts.filter({ $0.isVisible }).map({ $0.name }).joined(separator: " + "))]")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxHeight: .infinity)
        }
    }

    // MARK: - Parts Inspector
    private var partsInspectorView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("パーツ分割・構成レイヤー")
                .font(.headline)

            List {
                ForEach(0..<appState.currentCharacter.parts.count, id: \.self) { idx in
                    let part = appState.currentCharacter.parts[idx]
                    HStack {
                        Button(action: {
                            appState.currentCharacter.parts[idx].isVisible.toggle()
                        }) {
                            Image(systemName: part.isVisible ? "eye.fill" : "eye.slash")
                                .foregroundColor(part.isVisible ? .accentColor : .secondary)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading) {
                            Text(part.name).bold().font(.subheadline)
                            Text(part.assetPath).font(.caption2).foregroundColor(.secondary)
                        }

                        Spacer()

                        if selectedPartIndex == idx {
                            Image(systemName: "checkmark")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedPartIndex = idx
                    }
                }
            }
            .frame(height: 180)

            if selectedPartIndex < appState.currentCharacter.parts.count {
                let part = appState.currentCharacter.parts[selectedPartIndex]
                GroupBox(label: Text("【\(part.name)】プロパティ調整")) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("水平位置 (X):")
                            Spacer()
                            Text("\(Int(part.offsetX)) px")
                        }
                        .font(.caption)
                        Slider(value: Binding(
                            get: { part.offsetX },
                            set: { appState.currentCharacter.parts[selectedPartIndex].offsetX = $0 }
                        ), in: -100...100)

                        HStack {
                            Text("垂直位置 (Y):")
                            Spacer()
                            Text("\(Int(part.offsetY)) px")
                        }
                        .font(.caption)
                        Slider(value: Binding(
                            get: { part.offsetY },
                            set: { appState.currentCharacter.parts[selectedPartIndex].offsetY = $0 }
                        ), in: -100...100)

                        HStack {
                            Text("拡大縮小 (Scale):")
                            Spacer()
                            Text("\(String(format: "%.2f", part.scale))x")
                        }
                        .font(.caption)
                        Slider(value: Binding(
                            get: { part.scale },
                            set: { appState.currentCharacter.parts[selectedPartIndex].scale = $0 }
                        ), in: 0.5...2.0)
                    }
                    .padding(6)
                }
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Export Dialog
    private var exportDialogView: some View {
        VStack(spacing: 18) {
            Text("立ち絵画像の書き出し")
                .font(.headline)
            Picker("画像フォーマット", selection: $exportImageFormat) {
                Text("PNG (透過立ち絵)").tag("PNG (透過立ち絵)")
                Text("JPG (高解像度背景付き)").tag("JPG (高解像度背景付き)")
                Text("SVG (ベクター図形)").tag("SVG (ベクター図形)")
                Text("PSD (Photoshopレイヤー別)").tag("PSD (Photoshopレイヤー別)")
                Text("PXD (Pixelmatorプロジェクト)").tag("PXD (Pixelmatorプロジェクト)")
                Text("GDRAW (Google図形互換)").tag("GDRAW (Google図形互換)")
            }
            .pickerStyle(.menu)

            HStack {
                Button("キャンセル") { showExportDialog = false }
                Spacer()
                Button("書き出し実行") {
                    showExportDialog = false
                    appState.log("立ち絵画像を書き出しました: \(exportImageFormat)")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 400)
    }
}
