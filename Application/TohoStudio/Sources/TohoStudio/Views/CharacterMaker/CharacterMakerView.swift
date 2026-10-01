import SwiftUI
import AppKit

public struct CharacterMakerView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var imageService = CharacterImageService.shared
    @ObservedObject var psdService = PSDToolService.shared

    @State private var canvasViewMode: CanvasViewMode = .composite
    @State private var selectedPartIndex: Int = 0
    @State private var showExportDialog: Bool = false
    @State private var showLoadDialog: Bool = false
    @State private var showAddPartDialog: Bool = false
    @State private var showBottomTray: Bool = true
    @State private var exportImageFormat: String = "PNG (透過立ち絵)"

    // ツールモード
    @State private var activeTool: CharacterMakerTool = .select
    @State private var canvasZoom: Double = 1.0

    // トリミングモード (cmd+t)
    @State private var isTrimmingMode: Bool = false
    @State private var cropRectNorm: CGRect = CGRect(x: 0.2, y: 0.3, width: 0.6, height: 0.5)
    @State private var cropZoomFactor: Double = 1.5

    // インスペクタータブ (5タブ式)
    @State private var inspectorTab: InspectorTab = .layers

    public enum CanvasViewMode: String, CaseIterable {
        case composite = "キャンバス"
        case psdTool = "PSDTool"
        case split = "分割表示"
    }

    enum CharacterMakerTool: String, CaseIterable {
        case select = "選択"
        case move = "移動"
        case crop = "トリミング"
        case split = "パーツ分割"
    }

    enum InspectorTab: String, CaseIterable {
        case layers = "レイヤー"
        case transform = "変形"
        case color = "色変え"
        case psd = "PSD差分"
        case extensions = "拡張機能"
    }

    public var body: some View {
        VStack(spacing: 0) {
            // 1. 仕様書スライド準拠の統一コントロールバー
            specControlBar

            Divider()

            // 2. Google図形描画 & PSDTool 統一ツールバー
            characterToolbar

            Divider()

            // 3. メインエディタ領域 (HSplitView: キャンバス/PSDTool + インスペクター)
            HSplitView {
                integratedWorkspaceArea
                    .frame(minWidth: 460, maxWidth: .infinity)

                if appState.layoutMode != "キャンバス最大化" {
                    inspectorSidebar
                        .frame(minWidth: 320, idealWidth: inspectorWidthForLayout, maxWidth: 440)
                        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
                }
            }

            // 4. ボトムトレイ (他のソフトのタイムライン/スライドトレイと統一)
            if showBottomTray {
                Divider()
                bottomPartTray
                    .frame(height: bottomTrayHeightForLayout)
                    .background(Color(NSColor.windowBackgroundColor))
            }
        }
        .sheet(isPresented: $showExportDialog) {
            exportDialogView
        }
        .sheet(isPresented: $showLoadDialog) {
            loadDialogView
        }
        .sheet(isPresented: $showAddPartDialog) {
            addPartDialogView
        }
        .onAppear {
            if appState.currentCharacter.parts.isEmpty || appState.currentCharacter.baseImagePath.isEmpty {
                appState.loadCharacterPreset(name: appState.currentCharacter.name)
            }
        }
    }

    private var bottomTrayHeightForLayout: CGFloat {
        switch appState.layoutMode {
        case "タイムライン重視": return 190
        case "キャンバス最大化": return 110
        case "インスペクター重視": return 120
        default: return 140
        }
    }

    private var inspectorWidthForLayout: CGFloat {
        switch appState.layoutMode {
        case "インスペクター重視": return 400
        case "タイムライン重視": return 330
        case "PSDTool重視": return 380
        default: return 360
        }
    }


    // MARK: - 1. コントロールバー (仕様書 Slide-3467568 準拠)
    private var specControlBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "person.crop.artframe")
                    .foregroundColor(.accentColor)
                Text("キャラクターメーカー")
                    .font(.subheadline)
                    .bold()
                Text("(Google図形描画 × PSDTool)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // レイアウトモード切り替え (MovieMaker, SlideScenarioMaker と完全統一)
            HStack(spacing: 4) {
                Text("レイアウト:").font(.caption2).foregroundColor(.secondary)
                Picker("", selection: $appState.layoutMode) {
                    Text("標準").tag("標準")
                    Text("キャンバス最大化").tag("キャンバス最大化")
                    Text("インスペクター重視").tag("インスペクター重視")
                    Text("タイムライン重視").tag("タイムライン重視")
                }
                .pickerStyle(.menu)
                .frame(width: 130)
            }

            // パーツトレイ表示トグル
            Button(action: { showBottomTray.toggle() }) {
                HStack(spacing: 3) {
                    Image(systemName: showBottomTray ? "rectangle.bottomthird.inset.filled" : "rectangle")
                    Text("トレイ")
                }
                .font(.caption2)
            }
            .buttonStyle(.bordered)

            Spacer()

            // 日時 & アカウント & メモリ & ファイル情報
            Text("\(controlBarTimestamp) (zuyasi)  メモリ: 242MB / 16GB  ファイル: 1.4MB / 128MB")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)

            Divider().frame(height: 14)

            // アプリ拡張バッジ
            HStack(spacing: 6) {
                extensionBadge(title: "PSDTool機能", isUnlocked: true)
                extensionBadge(title: "Photoshop機能", isUnlocked: appState.unlockedExtensions.contains("Photoshop非搭載機能"))
                extensionBadge(title: "Pixelmator機能", isUnlocked: appState.unlockedExtensions.contains("PixelmatorPro非搭載機能"))
                extensionBadge(title: "独自機能", isUnlocked: appState.unlockedExtensions.contains("リモートサポート＆独自機能"))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
        .background(Color(NSColor.windowBackgroundColor))
    }

    private func extensionBadge(title: String, isUnlocked: Bool) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isUnlocked ? Color.green : Color.secondary.opacity(0.5))
                .frame(width: 6, height: 6)
            Text(title).font(.system(size: 10))
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Color.secondary.opacity(0.12))
        .cornerRadius(4)
    }

    private var controlBarTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        return formatter.string(from: Date())
    }

    // MARK: - 2. ツールバー (Google図形描画 & PSDTool 統一スタイル)
    private var characterToolbar: some View {
        HStack(spacing: 8) {
            // キャラクター選択・プリセット
            Menu {
                Button("博麗霊夢 (主人公)") { appState.loadCharacterPreset(name: "博麗霊夢") }
                Button("霧雨魔理沙 (箒・帽子パーツ付)") { appState.loadCharacterPreset(name: "霧雨魔理沙") }
                Button("古明地こいし (第3の目パーツ付)") { appState.loadCharacterPreset(name: "古明地こいし") }
                Button("十六夜咲夜 (紅魔館メイド)") { appState.loadCharacterPreset(name: "十六夜咲夜") }
                Button("魂魄妖夢 (半人半霊)") { appState.loadCharacterPreset(name: "魂魄妖夢") }
            } label: {
                HStack(spacing: 4) {
                    Text(appState.currentCharacter.name)
                        .bold()
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                }
            }
            .menuStyle(.borderlessButton)
            .frame(width: 130)

            Divider().frame(height: 18)

            // 表情差分ピッカー (リポジトリ実画像と連動)
            HStack(spacing: 4) {
                Text("表情:").font(.caption).foregroundColor(.secondary)
                Picker("", selection: Binding(
                    get: { appState.currentCharacter.expression },
                    set: { newExp in
                        appState.saveUndoSnapshot()
                        appState.currentCharacter.expression = newExp
                        let expressions = imageService.findCharacterExpressions(characterName: appState.currentCharacter.name)
                        if let path = expressions[newExp] {
                            appState.currentCharacter.baseImagePath = path
                            if let idx = appState.currentCharacter.parts.firstIndex(where: { $0.name.contains("本体") || $0.name.contains("ベース") }) {
                                appState.currentCharacter.parts[idx].assetPath = path
                            }
                            appState.log("表情を『\(newExp)』に変更しました: \(path)")
                        }
                    }
                )) {
                    Text("通常").tag("通常")
                    Text("微笑").tag("微笑")
                    Text("笑顔").tag("笑顔")
                    Text("怒り").tag("怒り")
                    Text("驚き").tag("驚き")
                    Text("泣く").tag("泣く")
                    Text("困惑").tag("困惑")
                    Text("不満").tag("不満")
                    Text("余裕").tag("余裕")
                }
                .pickerStyle(.menu)
                .frame(width: 80)
            }

            Divider().frame(height: 18)

            // ツール切り替えボタングループ
            HStack(spacing: 2) {
                toolButton(tool: .select, icon: "arrow.up.left", label: "選択")
                toolButton(tool: .move, icon: "hand.raised", label: "移動")

                Button(action: {
                    isTrimmingMode.toggle()
                    if isTrimmingMode {
                        appState.log("キャラクターメーカー: トリミングモードを開始しました。キャンバス上で切り取り枠を調整してください")
                    }
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "crop")
                        Text("トリミング")
                    }
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(isTrimmingMode ? Color.accentColor : Color.clear)
                    .foregroundColor(isTrimmingMode ? .white : .primary)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)

                Button(action: {
                    appState.performCharacterSplit()
                }) {
                    HStack(spacing: 3) {
                        Image(systemName: "scissors")
                        Text("パーツ分割")
                    }
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.12))
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
            }

            Divider().frame(height: 18)

            // ビュー表示切り替え (キャンバス / PSDTool / 分割表示)
            Picker("", selection: $canvasViewMode) {
                Label("キャンバス", systemImage: "paintbrush").tag(CanvasViewMode.composite)
                Label("PSDTool", systemImage: "photo.stack").tag(CanvasViewMode.psdTool)
                Label("分割表示", systemImage: "square.split.2x1").tag(CanvasViewMode.split)
            }
            .pickerStyle(.segmented)
            .frame(width: 220)

            Divider().frame(height: 18)

            // 東方PSDクイックメニュー
            Menu {
                ForEach(psdService.availablePresets) { preset in
                    Button("\(preset.name) (\(preset.detail))") {
                        psdService.loadPSD(filePath: preset.path)
                        if canvasViewMode == .composite {
                            canvasViewMode = .split
                        }
                    }
                }
                Divider()
                Button("外部PSD/ZIPファイルを開く...") {
                    psdService.openLocalPSDFileDialog()
                    if canvasViewMode == .composite {
                        canvasViewMode = .split
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "folder.badge.gearshape")
                    Text(psdService.currentPsdName.isEmpty ? "東方PSD選択" : psdService.currentPsdName)
                        .font(.caption)
                        .lineLimit(1)
                    Image(systemName: "chevron.down").font(.caption2)
                }
            }
            .menuStyle(.borderlessButton)
            .frame(maxWidth: 150)

            // ズーム
            HStack(spacing: 3) {
                Button(action: { canvasZoom = max(0.5, canvasZoom - 0.25) }) {
                    Image(systemName: "minus.magnifyingglass")
                }
                .buttonStyle(.plain)

                Text("\(Int(canvasZoom * 100))%")
                    .font(.system(size: 10, design: .monospaced))
                    .frame(width: 36)

                Button(action: { canvasZoom = min(2.5, canvasZoom + 0.25) }) {
                    Image(systemName: "plus.magnifyingglass")
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // アクションボタングループ
            HStack(spacing: 5) {
                // PSDToolで選んだ差分をキャンバスへ瞬時に取り込むボタン
                Button(action: {
                    psdService.requestExport(target: "characterMaker")
                }) {
                    Label("差分反映", systemImage: "arrow.down.doc.fill")
                        .foregroundColor(.green)
                }
                .buttonStyle(.borderedProminent)
                .help("PSDToolの現在の差分合成画像をキャラクターメーカーに取り込みます")

                Button(action: { showLoadDialog = true }) {
                    Label("読込", systemImage: "folder")
                }
                .buttonStyle(.bordered)

                Button(action: {
                    appState.performRegenerate()
                }) {
                    Label("再生成", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.bordered)

                Button(action: {
                    appState.performCreateMaterialFromCurrent()
                }) {
                    Label("素材保存", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.bordered)

                Button(action: { showExportDialog = true }) {
                    Label("書出", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.4))
    }

    private func toolButton(tool: CharacterMakerTool, icon: String, label: String) -> some View {
        Button(action: { activeTool = tool }) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(label)
            }
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(activeTool == tool ? Color.accentColor : Color.clear)
            .foregroundColor(activeTool == tool ? .white : .primary)
            .cornerRadius(5)
        }
        .buttonStyle(.plain)
    }

    // MARK: - 3. 統合ワークスペース領域 (キャンバス / PSDTool / 分割表示)
    private var integratedWorkspaceArea: some View {
        VStack(spacing: 0) {
            switch canvasViewMode {
            case .composite:
                mainCanvasArea

            case .psdTool:
                psdToolHostArea

            case .split:
                HSplitView {
                    mainCanvasArea
                        .frame(minWidth: 260, maxWidth: .infinity)

                    psdToolHostArea
                        .frame(minWidth: 320, maxWidth: .infinity)
                }
            }
        }
    }

    // PSDTool ホストエリア (上部インラインバー + WebKit)
    private var psdToolHostArea: some View {
        VStack(spacing: 0) {
            // PSDTool 上部インラインバー
            HStack(spacing: 8) {
                Image(systemName: "photo.stack")
                    .foregroundColor(.accentColor)
                Text(psdService.currentPsdName.isEmpty ? "PSDTool 立ち絵エディタ" : psdService.currentPsdName)
                    .font(.caption)
                    .bold()

                // Web版 / ローカル版 切り替え
                Picker("", selection: Binding(
                    get: { psdService.sourceMode },
                    set: { newMode in
                        psdService.sourceMode = newMode
                        psdService.loadPSDToolPage()
                    }
                )) {
                    ForEach(PSDToolService.PSDToolSourceMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 170)

                if psdService.sourceMode == .local {
                    Button(action: { psdService.openCustomHTMLFileDialog() }) {
                        HStack(spacing: 3) {
                            Image(systemName: "doc.badge.plus")
                            Text("再保存HTML選択")
                        }
                        .font(.caption2)
                    }
                    .buttonStyle(.bordered)
                    .help("ブラウザ等から再保存した PSDTool.html を指定して開きます")
                }

                if psdService.isLoadingPSD {
                    ProgressView().scaleEffect(0.6)
                }

                Text("(\(psdService.statusMessage))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                Spacer()

                Button(action: { psdService.reloadPSDTool() }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .help("PSDToolを再読み込み")

                Button(action: { psdService.openLocalPSDFileDialog() }) {
                    HStack(spacing: 3) {
                        Image(systemName: "folder")
                        Text("PSDを開く")
                    }
                    .font(.caption2)
                }
                .buttonStyle(.bordered)

                Button(action: { psdService.toggleAutoTrim() }) {
                    HStack(spacing: 3) {
                        Image(systemName: psdService.isAutoTrimEnabled ? "checkmark.circle.fill" : "circle")
                        Text("自動トリム")
                    }
                    .font(.caption2)
                }
                .buttonStyle(.bordered)

                Button(action: { psdService.toggleFlipX() }) {
                    HStack(spacing: 3) {
                        Image(systemName: psdService.isFlippedX ? "arrow.left.and.right.circle.fill" : "arrow.left.and.right.circle")
                        Text("左右反転")
                    }
                    .font(.caption2)
                }
                .buttonStyle(.bordered)

                Button(action: { psdService.requestExport(target: "characterMaker") }) {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.down.doc.fill")
                        Text("キャンバスに反映")
                    }
                    .font(.caption2)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            PSDToolHostView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - 3-1. メインキャンバス領域 (Google図形描画)
    private var mainCanvasArea: some View {
        GeometryReader { geo in
            ZStack {
                // 透過市松模様背景
                checkerboardBackground

                // レイヤー合成プレビュー (各パーツをリアルタイム描画)
                ZStack {
                    ForEach(0..<appState.currentCharacter.parts.count, id: \.self) { idx in
                        let part = appState.currentCharacter.parts[idx]
                        if part.isVisible {
                            partCanvasItemView(part: part, index: idx)
                        }
                    }
                }
                .scaleEffect(canvasZoom)
                .frame(width: geo.size.width, height: geo.size.height)

                // トリミングモード表示枠 (cmd+t)
                if isTrimmingMode {
                    cropOverlayView(canvasSize: geo.size)
                }

                // ガイド表示 (左上)
                VStack(alignment: .leading, spacing: 4) {
                    Text("💡 ガイド: パーツをクリックして選択・ドラッグ移動、右側パネルで変形や色変えができます")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(6)
                        .background(Color(NSColor.windowBackgroundColor).opacity(0.85))
                        .cornerRadius(6)
                    Spacer()
                }
                .padding(10)
            }
            .clipped()
        }
    }

    // 各パーツの描画アイテム
    private func partCanvasItemView(part: CharacterPart, index: Int) -> some View {
        let isSelected = (selectedPartIndex == index)

        return Group {
            if let nsImg = imageService.loadImage(from: part.assetPath) {
                let processed = imageService.applyAdjustments(
                    image: nsImg,
                    hue: part.hue,
                    saturation: part.saturation,
                    brightness: part.brightness,
                    contrast: part.contrast,
                    colorTintHex: part.colorTintHex,
                    blendMode: part.blendMode,
                    filterEffects: part.filterEffects
                )

                Image(nsImage: processed)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 320 * CGFloat(part.scale), height: 420 * CGFloat(part.scale))
                    .rotationEffect(.degrees(part.rotation))
                    .opacity(part.opacity)
                    .offset(x: CGFloat(part.offsetX), y: -CGFloat(part.offsetY))
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
                            .offset(x: CGFloat(part.offsetX), y: -CGFloat(part.offsetY))
                    )
                    .gesture(
                        DragGesture()
                            .onChanged { val in
                                if selectedPartIndex == index {
                                    appState.currentCharacter.parts[index].offsetX += Double(val.translation.width * 0.1)
                                    appState.currentCharacter.parts[index].offsetY -= Double(val.translation.height * 0.1)
                                }
                            }
                    )
                    .onTapGesture {
                        selectedPartIndex = index
                    }
            } else {
                // 画像未解決時のプレースホルダー表示
                VStack(spacing: 4) {
                    Image(systemName: "person.crop.rectangle.stack")
                        .font(.title)
                        .foregroundColor(.accentColor)
                    Text(part.name)
                        .font(.caption)
                }
                .frame(width: 140, height: 140)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
                .offset(x: CGFloat(part.offsetX), y: -CGFloat(part.offsetY))
                .onTapGesture {
                    selectedPartIndex = index
                }
            }
        }
    }

    // 市松模様背景 (透過チェッカー)
    private var checkerboardBackground: some View {
        Canvas { context, size in
            let step: CGFloat = 20
            let cols = Int(ceil(size.width / step))
            let rows = Int(ceil(size.height / step))

            for r in 0..<rows {
                for c in 0..<cols {
                    let isEven = (r + c) % 2 == 0
                    let rect = CGRect(x: CGFloat(c) * step, y: CGFloat(r) * step, width: step, height: step)
                    context.fill(Path(rect), with: .color(isEven ? Color(NSColor.controlBackgroundColor) : Color(NSColor.windowBackgroundColor)))
                }
            }
        }
    }

    // トリミング枠オーバーレイ (cmd+t)
    private func cropOverlayView(canvasSize: CGSize) -> some View {
        let cropW = max(100, canvasSize.width * cropRectNorm.size.width)
        let cropH = max(100, canvasSize.height * cropRectNorm.size.height)
        let cropX = canvasSize.width * cropRectNorm.origin.x - (canvasSize.width / 2.0) + (cropW / 2.0)
        let cropY = (canvasSize.height * cropRectNorm.origin.y) - (canvasSize.height / 2.0) + (cropH / 2.0)

        return ZStack {
            // 暗転マスク
            Color.black.opacity(0.35)

            // 切り抜き対象枠
            VStack {
                HStack {
                    Text("トリミング範囲 (拡大率: \(String(format: "%.1f", cropZoomFactor))x)")
                        .font(.caption2)
                        .bold()
                        .padding(4)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(3)
                    Spacer()
                }
                Spacer()

                HStack {
                    Button("キャンセル") {
                        isTrimmingMode = false
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("切り取り＆拡大を確定") {
                        appState.performCharacterCrop(normalizedRect: cropRectNorm, zoomFactor: cropZoomFactor)
                        isTrimmingMode = false
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(8)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.9))
            }
            .frame(width: cropW, height: cropH)
            .overlay(
                Rectangle()
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            )
            .offset(x: cropX, y: cropY)
        }
    }

    // MARK: - 4. インスペクターサイドバー (右側)
    private var inspectorSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            // タブピッカー
            Picker("", selection: $inspectorTab) {
                ForEach(InspectorTab.allCases, id: \.self) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(10)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch inspectorTab {
                    case .layers:
                        layersTabContent
                    case .transform:
                        transformTabContent
                    case .color:
                        colorTabContent
                    case .psd:
                        psdTabContent
                    case .extensions:
                        extensionsTabContent
                    }
                }
                .padding(12)
            }
        }
    }

    // MARK: - 4-1. レイヤータブ
    private var layersTabContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("パーツ・構成レイヤー")
                    .font(.headline)
                Spacer()
                Button(action: { showAddPartDialog = true }) {
                    Label("パーツ追加", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
            }

            // レイヤーリスト
            VStack(spacing: 4) {
                ForEach(0..<appState.currentCharacter.parts.count, id: \.self) { idx in
                    let part = appState.currentCharacter.parts[idx]
                    HStack(spacing: 8) {
                        Button(action: {
                            appState.currentCharacter.parts[idx].isVisible.toggle()
                        }) {
                            Image(systemName: part.isVisible ? "eye.fill" : "eye.slash")
                                .foregroundColor(part.isVisible ? .accentColor : .secondary)
                        }
                        .buttonStyle(.plain)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(part.name)
                                .font(.subheadline)
                                .bold(selectedPartIndex == idx)
                            Text((part.assetPath as NSString).lastPathComponent)
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        // 並び替えボタン
                        HStack(spacing: 2) {
                            Button(action: { movePart(from: idx, to: max(0, idx - 1)) }) {
                                Image(systemName: "chevron.up").font(.caption2)
                            }
                            .disabled(idx == 0)
                            .buttonStyle(.plain)

                            Button(action: { movePart(from: idx, to: min(appState.currentCharacter.parts.count - 1, idx + 1)) }) {
                                Image(systemName: "chevron.down").font(.caption2)
                            }
                            .disabled(idx == appState.currentCharacter.parts.count - 1)
                            .buttonStyle(.plain)
                        }

                        // 削除
                        Button(action: {
                            appState.saveUndoSnapshot()
                            appState.currentCharacter.parts.remove(at: idx)
                            selectedPartIndex = max(0, selectedPartIndex - 1)
                        }) {
                            Image(systemName: "trash").font(.caption2).foregroundColor(.red)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(8)
                    .background(selectedPartIndex == idx ? Color.accentColor.opacity(0.15) : Color(NSColor.controlBackgroundColor))
                    .cornerRadius(6)
                    .onTapGesture {
                        selectedPartIndex = idx
                    }
                }
            }

            Divider()

            // アクションボタン
            VStack(spacing: 8) {
                Button(action: { appState.performCharacterSplit() }) {
                    Label("立ち絵からパーツ分割 (cmd+e+c)", systemImage: "scissors")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button(action: {
                    isTrimmingMode = true
                }) {
                    Label("一部分を切り取り＆拡大 (cmd+t)", systemImage: "crop")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func movePart(from: Int, to: Int) {
        appState.saveUndoSnapshot()
        let item = appState.currentCharacter.parts.remove(at: from)
        appState.currentCharacter.parts.insert(item, at: to)
        selectedPartIndex = to
    }

    // MARK: - 4-2. 変形プロパティタブ (Google図形描画)
    private var transformTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if selectedPartIndex < appState.currentCharacter.parts.count {
                let part = appState.currentCharacter.parts[selectedPartIndex]
                Text("【\(part.name)】変形調整")
                    .font(.headline)

                GroupBox(label: Text("位置 (Position)")) {
                    VStack(spacing: 8) {
                        HStack {
                            Text("X (水平):")
                            Spacer()
                            Text("\(Int(part.offsetX)) px").monospacedDigit()
                        }
                        .font(.caption)
                        Slider(value: Binding(
                            get: { part.offsetX },
                            set: { appState.currentCharacter.parts[selectedPartIndex].offsetX = $0 }
                        ), in: -300...300)

                        HStack {
                            Text("Y (垂直):")
                            Spacer()
                            Text("\(Int(part.offsetY)) px").monospacedDigit()
                        }
                        .font(.caption)
                        Slider(value: Binding(
                            get: { part.offsetY },
                            set: { appState.currentCharacter.parts[selectedPartIndex].offsetY = $0 }
                        ), in: -300...300)
                    }
                    .padding(6)
                }

                GroupBox(label: Text("サイズ & 角度 (Scale & Rotation)")) {
                    VStack(spacing: 8) {
                        HStack {
                            Text("拡大縮小:")
                            Spacer()
                            Text("\(String(format: "%.2f", part.scale))x").monospacedDigit()
                        }
                        .font(.caption)
                        Slider(value: Binding(
                            get: { part.scale },
                            set: { appState.currentCharacter.parts[selectedPartIndex].scale = $0 }
                        ), in: 0.2...2.5)

                        HStack {
                            Text("回転角度:")
                            Spacer()
                            Text("\(Int(part.rotation))°").monospacedDigit()
                        }
                        .font(.caption)
                        Slider(value: Binding(
                            get: { part.rotation },
                            set: { appState.currentCharacter.parts[selectedPartIndex].rotation = $0 }
                        ), in: -180...180)
                    }
                    .padding(6)
                }

                GroupBox(label: Text("不透明度 (Opacity)")) {
                    VStack(spacing: 6) {
                        HStack {
                            Text("透明度:")
                            Spacer()
                            Text("\(Int(part.opacity * 100))%").monospacedDigit()
                        }
                        .font(.caption)
                        Slider(value: Binding(
                            get: { part.opacity },
                            set: { appState.currentCharacter.parts[selectedPartIndex].opacity = $0 }
                        ), in: 0.0...1.0)
                    }
                    .padding(6)
                }

                // クイック反転操作
                HStack {
                    Button("水平反転") {
                        appState.saveUndoSnapshot()
                        appState.currentCharacter.parts[selectedPartIndex].scale = -appState.currentCharacter.parts[selectedPartIndex].scale
                    }
                    .buttonStyle(.bordered)

                    Button("90° 回転") {
                        appState.saveUndoSnapshot()
                        appState.currentCharacter.parts[selectedPartIndex].rotation = (appState.currentCharacter.parts[selectedPartIndex].rotation + 90.0).truncatingRemainder(dividingBy: 360.0)
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("位置リセット") {
                        appState.saveUndoSnapshot()
                        appState.currentCharacter.parts[selectedPartIndex].offsetX = 0
                        appState.currentCharacter.parts[selectedPartIndex].offsetY = 0
                        appState.currentCharacter.parts[selectedPartIndex].scale = 1.0
                        appState.currentCharacter.parts[selectedPartIndex].rotation = 0
                    }
                    .buttonStyle(.borderless)
                    .font(.caption)
                }
            } else {
                Text("パーツを選択してください").foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 4-3. 色変え・カラー調整タブ (Google図形描画)
    private var colorTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            if selectedPartIndex < appState.currentCharacter.parts.count {
                let part = appState.currentCharacter.parts[selectedPartIndex]
                Text("【\(part.name)】色変え・カラー調整")
                    .font(.headline)

                GroupBox(label: Text("カラーティント (着色)")) {
                    VStack(spacing: 8) {
                        HStack {
                            Text("ティントカラー:")
                            Spacer()
                            ColorPicker("", selection: Binding(
                                get: { Color(charHex: part.colorTintHex) },
                                set: { appState.currentCharacter.parts[selectedPartIndex].colorTintHex = $0.toCharHex() }
                            ))
                        }
                        .font(.caption)

                        HStack {
                            Button("白 (標準)") { appState.currentCharacter.parts[selectedPartIndex].colorTintHex = "#FFFFFF" }
                            Button("赤") { appState.currentCharacter.parts[selectedPartIndex].colorTintHex = "#FF5555" }
                            Button("青") { appState.currentCharacter.parts[selectedPartIndex].colorTintHex = "#5555FF" }
                            Button("黄") { appState.currentCharacter.parts[selectedPartIndex].colorTintHex = "#FFFF55" }
                            Button("黒 (影)") { appState.currentCharacter.parts[selectedPartIndex].colorTintHex = "#333333" }
                        }
                        .font(.caption2)
                        .buttonStyle(.bordered)
                    }
                    .padding(6)
                }

                GroupBox(label: Text("色調補正 (Color Adjustments)")) {
                    VStack(spacing: 8) {
                        HStack {
                            Text("色相 (Hue):")
                            Spacer()
                            Text("\(Int(part.hue))°").monospacedDigit()
                        }
                        .font(.caption)
                        Slider(value: Binding(
                            get: { part.hue },
                            set: { appState.currentCharacter.parts[selectedPartIndex].hue = $0 }
                        ), in: -180...180)

                        HStack {
                            Text("彩度 (Saturation):")
                            Spacer()
                            Text("\(Int(part.saturation * 100))%").monospacedDigit()
                        }
                        .font(.caption)
                        Slider(value: Binding(
                            get: { part.saturation },
                            set: { appState.currentCharacter.parts[selectedPartIndex].saturation = $0 }
                        ), in: 0.0...2.0)

                        HStack {
                            Text("明度 (Brightness):")
                            Spacer()
                            Text("\(Int(part.brightness * 100))%").monospacedDigit()
                        }
                        .font(.caption)
                        Slider(value: Binding(
                            get: { part.brightness },
                            set: { appState.currentCharacter.parts[selectedPartIndex].brightness = $0 }
                        ), in: -0.8...0.8)

                        HStack {
                            Text("コントラスト:")
                            Spacer()
                            Text("\(Int(part.contrast * 100))%").monospacedDigit()
                        }
                        .font(.caption)
                        Slider(value: Binding(
                            get: { part.contrast },
                            set: { appState.currentCharacter.parts[selectedPartIndex].contrast = $0 }
                        ), in: 0.2...2.0)
                    }
                    .padding(6)
                }

                Button("色調を初期値に戻す") {
                    appState.saveUndoSnapshot()
                    appState.currentCharacter.parts[selectedPartIndex].colorTintHex = "#FFFFFF"
                    appState.currentCharacter.parts[selectedPartIndex].hue = 0.0
                    appState.currentCharacter.parts[selectedPartIndex].saturation = 1.0
                    appState.currentCharacter.parts[selectedPartIndex].brightness = 0.0
                    appState.currentCharacter.parts[selectedPartIndex].contrast = 1.0
                }
                .font(.caption)
                .buttonStyle(.bordered)
            } else {
                Text("パーツを選択してください").foregroundColor(.secondary)
            }
        }
    }

    // MARK: - 4-4. 拡張機能タブ (PSDTool / Photoshop / Pixelmator Pro / 独自機能)
    private var extensionsTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("アプリ拡張機能")
                .font(.headline)

            // PSDTool 拡張 (PSDTool_files完全統合)
            GroupBox(label: Label("PSDTool 立ち絵・差分エディタ (PSD/PSB/ZIP解析)", systemImage: "photo.stack.fill")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("PSDTool (HTML5+JS) ツール群を完全統合。レイヤーツリー展開、表情・ポーズ差分、お気に入り管理、シンプルビュー、自動トリミングが利用可能です。")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Button(action: { canvasViewMode = .split }) {
                            Label("🎨 PSDTool を開く (分割表示)", systemImage: "arrow.up.forward.app")
                        }
                        .buttonStyle(.borderedProminent)

                        Button("外部PSDを開く...") {
                            canvasViewMode = .split
                            psdService.openLocalPSDFileDialog()
                        }
                        .buttonStyle(.bordered)
                    }

                    Divider()

                    Text("東方Project 立ち絵PSDを開く:").font(.caption).bold()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(psdService.availablePresets.prefix(8)) { preset in
                                Button(preset.characterName) {
                                    canvasViewMode = .split
                                    psdService.loadPSD(filePath: preset.path)
                                }
                                .buttonStyle(.bordered)
                                .font(.caption2)
                            }
                        }
                    }
                }
                .padding(6)
            }

            // Photoshop拡張
            GroupBox(label: Label("Adobe Photoshop 拡張機能", systemImage: "sparkles")) {
                VStack(alignment: .leading, spacing: 8) {
                    if selectedPartIndex < appState.currentCharacter.parts.count {
                        let part = appState.currentCharacter.parts[selectedPartIndex]
                        Picker("合成モード (Blend Mode):", selection: Binding(
                            get: { part.blendMode },
                            set: { appState.currentCharacter.parts[selectedPartIndex].blendMode = $0 }
                        )) {
                            Text("通常 (Normal)").tag("通常")
                            Text("乗算 (Multiply)").tag("乗算")
                            Text("スクリーン (Screen)").tag("スクリーン")
                            Text("オーバーレイ (Overlay)").tag("オーバーレイ")
                            Text("ソフトライト (Soft Light)").tag("ソフトライト")
                        }
                        .pickerStyle(.menu)

                        Divider()

                        Text("レイヤースタイル:").font(.caption).bold()
                        HStack {
                            filterToggle(name: "ドロップシャドウ", targetIndex: selectedPartIndex)
                            filterToggle(name: "境界線", targetIndex: selectedPartIndex)
                        }
                    } else {
                        Text("パーツを選択すると適用できます").font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding(6)
            }

            // Pixelmator Pro拡張
            GroupBox(label: Label("Pixelmator Pro 拡張機能", systemImage: "wand.and.stars")) {
                VStack(alignment: .leading, spacing: 8) {
                    if selectedPartIndex < appState.currentCharacter.parts.count {
                        Text("スマートフィルター:").font(.caption).bold()
                        HStack {
                            filterToggle(name: "シャープ", targetIndex: selectedPartIndex)
                            filterToggle(name: "ぼかし", targetIndex: selectedPartIndex)
                        }
                        HStack {
                            filterToggle(name: "セピア", targetIndex: selectedPartIndex)
                            filterToggle(name: "モノクロ", targetIndex: selectedPartIndex)
                        }
                    } else {
                        Text("パーツを選択すると適用できます").font(.caption).foregroundColor(.secondary)
                    }
                }
                .padding(6)
            }

            // 独自機能 (仕様書補足事項: 箒跨り、第3の目等)
            GroupBox(label: Label("独自組み立てプリセット (仕様書補足事項)", systemImage: "star.fill")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("仕様書補足事項に記載の特殊組み立てアクション:")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Button("🧹 魔理沙: 箒に跨るポーズを自動組み立て") {
                        assembleMarisaBroomPose()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)

                    Button("👁️ こいし: 第3の目の開閉差分を追加") {
                        assembleKoishiEyePose()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                }
                .padding(6)
            }
        }
    }

    private func filterToggle(name: String, targetIndex: Int) -> some View {
        let isApplied = appState.currentCharacter.parts[targetIndex].filterEffects.contains(name)
        return Button(action: {
            appState.saveUndoSnapshot()
            if isApplied {
                appState.currentCharacter.parts[targetIndex].filterEffects.removeAll(where: { $0 == name })
            } else {
                appState.currentCharacter.parts[targetIndex].filterEffects.append(name)
            }
        }) {
            HStack(spacing: 4) {
                Image(systemName: isApplied ? "checkmark.square.fill" : "square")
                Text(name).font(.caption2)
            }
        }
        .buttonStyle(.plain)
    }

    // 仕様書補足事項の魔理沙の箒跨り組み立て
    private func assembleMarisaBroomPose() {
        appState.loadCharacterPreset(name: "霧雨魔理沙")
        appState.saveUndoSnapshot()
        // 箒パーツがなければ探索して追加
        let broomPath = "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/動画用/キャラクター/主人公たち/霧雨魔理沙/霧雨魔理沙（バトルっぽい）/箒.png"
        if !appState.currentCharacter.parts.contains(where: { $0.name.contains("箒") }) {
            let broomPart = CharacterPart(
                name: "箒 (跨りアイテム)",
                assetPath: broomPath,
                offsetX: -30.0,
                offsetY: -50.0,
                scale: 1.2,
                rotation: -30.0,
                isVisible: true
            )
            appState.currentCharacter.parts.insert(broomPart, at: 0) // 奥に配置
        }
        appState.log("独自機能: 魔理沙が箒に跨っている状態を自動組み立てしました (仕様書補足事項 614行目)")
    }

    // 仕様書補足事項のこいしの第3の目差分組み立て
    private func assembleKoishiEyePose() {
        appState.loadCharacterPreset(name: "古明地こいし")
        appState.saveUndoSnapshot()
        let eyePath = "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/動画用/手作り素材/psdtool/古明地姉妹/古明地こいし/帽子目なし目閉じ小口開け頬照り.png"
        if !appState.currentCharacter.parts.contains(where: { $0.name.contains("第3の目") }) {
            let eyePart = CharacterPart(
                name: "第3の目 (開閉差分)",
                assetPath: eyePath,
                offsetX: 110.0,
                offsetY: 70.0,
                scale: 0.5,
                rotation: 10.0,
                isVisible: true
            )
            appState.currentCharacter.parts.append(eyePart)
        }
        appState.log("独自機能: こいしの第3の目が開いている差分パーツを組み立てました (仕様書補足事項 614行目)")
    }

    // MARK: - 5. モーダルダイアログ群

    // パーツ追加ダイアログ
    private var addPartDialogView: some View {
        VStack(spacing: 16) {
            Text("新規パーツの追加")
                .font(.headline)

            VStack(spacing: 8) {
                Button("🧹 箒パーツを追加 (魔理沙用アイテム)") {
                    let broomPath = "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/動画用/キャラクター/主人公たち/霧雨魔理沙/霧雨魔理沙（バトルっぽい）/箒.png"
                    let part = CharacterPart(name: "箒パーツ", assetPath: broomPath, offsetX: -20, offsetY: -30, scale: 1.0)
                    appState.currentCharacter.parts.append(part)
                    showAddPartDialog = false
                }
                .buttonStyle(.bordered)

                Button("🎩 帽子パーツを追加 (魔理沙)") {
                    let hatPath = "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/動画用/キャラクター/主人公たち/霧雨魔理沙/霧雨魔理沙/霧雨魔理沙/帽子.png"
                    let part = CharacterPart(name: "帽子パーツ", assetPath: hatPath, offsetX: 0, offsetY: 220, scale: 1.0)
                    appState.currentCharacter.parts.append(part)
                    showAddPartDialog = false
                }
                .buttonStyle(.bordered)

                Button("👁️ 第3の目パーツを追加 (こいし)") {
                    let eyePath = "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/動画用/手作り素材/psdtool/古明地姉妹/古明地こいし/帽子目なし目閉じ小口開け頬照り.png"
                    let part = CharacterPart(name: "第3の目パーツ", assetPath: eyePath, offsetX: 90, offsetY: 60, scale: 0.5)
                    appState.currentCharacter.parts.append(part)
                    showAddPartDialog = false
                }
                .buttonStyle(.bordered)

                Divider()

                Button("ローカル画像ファイルからパーツ追加...") {
                    showAddPartDialog = false
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [.png, .jpeg]
                    if panel.runModal() == .OK, let url = panel.url {
                        let name = url.deletingPathExtension().lastPathComponent
                        let part = CharacterPart(name: name, assetPath: url.path, scale: 1.0)
                        appState.currentCharacter.parts.append(part)
                        appState.log("パーツを追加しました: \(name)")
                    }
                }
                .buttonStyle(.borderedProminent)
            }

            HStack {
                Spacer()
                Button("閉じる") { showAddPartDialog = false }
            }
        }
        .padding(20)
        .frame(width: 420)
    }

    // 読み込みダイアログ (仕様書 Slide-3463564 準拠)
    private var loadDialogView: some View {
        VStack(spacing: 16) {
            Text("キャラクター立ち絵の読み込み (Slide-3463564)")
                .font(.headline)

            VStack(spacing: 10) {
                Button("素材スタジオから読み込む") {
                    showLoadDialog = false
                    appState.currentModule = .materialStudio
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button("JPEG / PNG 画像を読み込む") {
                    showLoadDialog = false
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [.png, .jpeg]
                    if panel.runModal() == .OK, let url = panel.url {
                        appState.saveUndoSnapshot()
                        let name = url.deletingPathExtension().lastPathComponent
                        let part = CharacterPart(name: "ベース立ち絵", assetPath: url.path, scale: 1.0)
                        appState.currentCharacter = CharacterModel(
                            name: name,
                            baseImagePath: url.path,
                            parts: [part],
                            expression: "通常"
                        )
                        appState.log("立ち絵画像を読み込みました: \(url.lastPathComponent)")
                    }
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button("既存ファイル (.tscm) を読み込む") {
                    showLoadDialog = false
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [.json]
                    if panel.runModal() == .OK, let url = panel.url {
                        appState.loadCharacterProject(from: url)
                    }
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)

                Button("空のファイルを作成") {
                    showLoadDialog = false
                    appState.saveUndoSnapshot()
                    appState.currentCharacter = CharacterModel(name: "新規キャラクター", parts: [])
                    appState.log("空のキャラクター編集ファイルを作成しました")
                }
                .buttonStyle(.bordered)
                .frame(maxWidth: .infinity)
            }

            HStack {
                Spacer()
                Button("キャンセル") { showLoadDialog = false }
            }
        }
        .padding(24)
        .frame(width: 440)
    }

    // 書き出しダイアログ
    private var exportDialogView: some View {
        VStack(spacing: 18) {
            Text("立ち絵画像の書き出し (仕様書準拠)")
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
                    let panel = NSSavePanel()
                    let ext: String
                    switch exportImageFormat {
                    case "PNG (透過立ち絵)": ext = "png"
                    case "JPG (高解像度背景付き)": ext = "jpg"
                    case "SVG (ベクター図形)": ext = "svg"
                    case "PSD (Photoshopレイヤー別)": ext = "psd"
                    case "PXD (Pixelmatorプロジェクト)": ext = "pxd"
                    case "GDRAW (Google図形互換)": ext = "gdraw"
                    default: ext = "png"
                    }
                    panel.nameFieldStringValue = "\(appState.currentCharacter.name)_\(appState.currentCharacter.expression).\(ext)"

                    if panel.runModal() == .OK, let url = panel.url {
                        do {
                            try imageService.exportCharacterImage(
                                model: appState.currentCharacter,
                                format: exportImageFormat,
                                destinationURL: url
                            )
                            appState.log("立ち絵画像を書き出しました: \(url.lastPathComponent)")
                            appState.addHistory("書き出し: \(url.lastPathComponent)")
                        } catch {
                            appState.log("書き出しエラー: \(error.localizedDescription)", level: "ERROR")
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    // MARK: - 4-4. PSD差分タブ (PSDTool_files機能完全統合)
    private var psdTabContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("PSD立ち絵・差分設定")
                .font(.headline)

            // アプリケーション内ブラウザ起動コントロール
            GroupBox(label: Label("PSDTool アプリ内ブラウザ", systemImage: "macwindow")) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("PSDTool を TohoStudio 内蔵ブラウザで表示・操作します。")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    HStack(spacing: 8) {
                        Button(action: {
                            canvasViewMode = .psdTool
                            psdService.loadPSDToolPage()
                        }) {
                            Label("全画面で開く", systemImage: "arrow.up.left.and.arrow.down.right")
                        }
                        .buttonStyle(.borderedProminent)
                        .font(.caption)

                        Button(action: {
                            canvasViewMode = .split
                            psdService.loadPSDToolPage()
                        }) {
                            Label("分割表示", systemImage: "square.split.2x1")
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }

                    HStack(spacing: 8) {
                        Picker("", selection: Binding(
                            get: { psdService.sourceMode },
                            set: { newMode in
                                psdService.sourceMode = newMode
                                psdService.loadPSDToolPage()
                            }
                        )) {
                            ForEach(PSDToolService.PSDToolSourceMode.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        Button("再保存HTML...") {
                            psdService.openCustomHTMLFileDialog()
                        }
                        .buttonStyle(.bordered)
                        .font(.caption2)
                        .help("ブラウザで再保存した PSDTool.html を選択")
                    }
                }
                .padding(6)
            }

            // 現在のファイル
            GroupBox(label: Label("読み込み中のPSD", systemImage: "photo.stack")) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(psdService.currentPsdName.isEmpty ? "未選択 (プリセットから選択可)" : psdService.currentPsdName)
                            .font(.caption)
                            .bold()
                            .lineLimit(1)
                        Spacer()
                        if psdService.isLoadingPSD {
                            ProgressView().scaleEffect(0.6)
                        }
                    }

                    HStack(spacing: 8) {
                        Button("外部PSDを開く...") {
                            psdService.openLocalPSDFileDialog()
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)

                        Button("差分を反映") {
                            psdService.requestExport(target: "characterMaker")
                        }
                        .buttonStyle(.borderedProminent)
                        .font(.caption)
                    }
                }
                .padding(6)
            }

            // レンダリング設定
            GroupBox(label: Label("レンダリング設定", systemImage: "slider.horizontal.3")) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("自動トリミング (余白自動切り抜き)", isOn: Binding(
                        get: { psdService.isAutoTrimEnabled },
                        set: { _ in psdService.toggleAutoTrim() }
                    ))
                    .toggleStyle(.switch)
                    .font(.caption)

                    Toggle("左右反転", isOn: Binding(
                        get: { psdService.isFlippedX },
                        set: { _ in psdService.toggleFlipX() }
                    ))
                    .toggleStyle(.switch)
                    .font(.caption)

                    Divider()

                    HStack {
                        Button("タイムライン配置") {
                            psdService.requestExport(target: "timeline")
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)

                        Button("素材スタジオ保存") {
                            psdService.requestExport(target: "materialStudio")
                        }
                        .buttonStyle(.bordered)
                        .font(.caption)
                    }
                }
                .padding(6)
            }

            // 東方Project 立ち絵PSDプリセット (16種)
            GroupBox(label: Label("東方Project 立ち絵PSDプリセット (\(psdService.availablePresets.count)種)", systemImage: "person.2.fill")) {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(psdService.availablePresets) { preset in
                        Button(action: {
                            psdService.loadPSD(filePath: preset.path)
                            if canvasViewMode == .composite {
                                canvasViewMode = .split
                            }
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.name)
                                        .font(.caption)
                                        .bold()
                                    Text(preset.detail)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.right.circle")
                                    .font(.caption)
                                    .foregroundColor(.accentColor)
                            }
                            .padding(.vertical, 3)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
                .padding(6)
            }
        }
    }

    // MARK: - 5. ボトムトレイ: 表情差分 & パーツ構成ストリップ (MovieMaker等の下部UIと統一)
    private var bottomPartTray: some View {
        VStack(spacing: 0) {
            // トレイヘッダーバー
            HStack(spacing: 8) {
                Image(systemName: "square.grid.3x1.below.line.grid.1x2")
                    .foregroundColor(.accentColor)
                    .font(.caption)
                Text("表情差分 & パーツ構成ストリップ")
                    .font(.caption)
                    .bold()

                Spacer()

                // ステータス表示
                Text(psdService.statusMessage)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Divider().frame(height: 12)

                Button(action: { showAddPartDialog = true }) {
                    Label("パーツ追加", systemImage: "plus")
                        .font(.caption2)
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))

            Divider()

            // トレイコンテンツ (表情差分 + パーツ一覧)
            HStack(spacing: 12) {
                // 左: 表情差分クイックカード一覧
                VStack(alignment: .leading, spacing: 3) {
                    Text("表情プリセット")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    let expressions = ["通常", "微笑", "笑顔", "怒り", "驚き", "泣く", "困惑", "不満", "余裕"]
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(expressions, id: \.self) { exp in
                                let isSelected = (appState.currentCharacter.expression == exp)
                                Button(action: {
                                    appState.saveUndoSnapshot()
                                    appState.currentCharacter.expression = exp
                                    let dict = imageService.findCharacterExpressions(characterName: appState.currentCharacter.name)
                                    if let path = dict[exp] {
                                        appState.currentCharacter.baseImagePath = path
                                        if let idx = appState.currentCharacter.parts.firstIndex(where: { $0.name.contains("本体") || $0.name.contains("ベース") }) {
                                            appState.currentCharacter.parts[idx].assetPath = path
                                        }
                                        appState.log("表情を『\(exp)』に変更しました: \(path)")
                                    }
                                }) {
                                    VStack(spacing: 2) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(isSelected ? Color.accentColor.opacity(0.3) : Color.secondary.opacity(0.12))
                                            .frame(width: 46, height: 46)
                                            .overlay(
                                                Text(expressionEmoji(for: exp))
                                                    .font(.title3)
                                            )
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 4)
                                                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
                                            )
                                        Text(exp)
                                            .font(.system(size: 9))
                                            .foregroundColor(isSelected ? .accentColor : .primary)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .frame(width: 320)

                Divider()

                // 右: パーツ構成ストリップ
                VStack(alignment: .leading, spacing: 3) {
                    Text("構成パーツ・レイヤー (\(appState.currentCharacter.parts.count)個)")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(0..<appState.currentCharacter.parts.count, id: \.self) { idx in
                                let part = appState.currentCharacter.parts[idx]
                                let isSelected = (selectedPartIndex == idx)

                                HStack(spacing: 6) {
                                    // 目のアイコン (可視性)
                                    Button(action: {
                                        appState.saveUndoSnapshot()
                                        appState.currentCharacter.parts[idx].isVisible.toggle()
                                    }) {
                                        Image(systemName: part.isVisible ? "eye.fill" : "eye.slash")
                                            .foregroundColor(part.isVisible ? .primary : .secondary)
                                            .font(.caption2)
                                    }
                                    .buttonStyle(.plain)

                                    // パーツサムネイル & 名前
                                    Button(action: { selectedPartIndex = idx }) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(part.name)
                                                .font(.caption2)
                                                .bold()
                                                .lineLimit(1)
                                            Text("\(Int(part.opacity * 100))% | \(part.blendMode)")
                                                .font(.system(size: 9))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
                                )
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
    }

    private func expressionEmoji(for expression: String) -> String {
        switch expression {
        case "通常": return "😐"
        case "微笑": return "🙂"
        case "笑顔": return "😄"
        case "怒り": return "😠"
        case "驚き": return "😲"
        case "泣く": return "😢"
        case "困惑": return "😵"
        case "不満": return "😤"
        case "余裕": return "😏"
        default: return "🙂"
        }
    }
}

// MARK: - Color Hex Helper for CharacterMaker
fileprivate extension Color {
    init(charHex: String) {
        var hexSanitized = charHex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            self.init(.white)
            return
        }

        let r, g, b, a: Double
        if hexSanitized.count == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else if hexSanitized.count == 8 {
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            a = Double(rgb & 0x000000FF) / 255.0
        } else {
            self.init(.white)
            return
        }

        self.init(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    func toCharHex() -> String {
        guard let nsColor = NSColor(self).usingColorSpace(.sRGB) else { return "#FFFFFF" }
        let r = Int(nsColor.redComponent * 255)
        let g = Int(nsColor.greenComponent * 255)
        let b = Int(nsColor.blueComponent * 255)
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
