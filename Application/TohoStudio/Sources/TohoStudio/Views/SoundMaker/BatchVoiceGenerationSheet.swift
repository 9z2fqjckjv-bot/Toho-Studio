import SwiftUI
import AppKit

public struct BatchVoiceGenerationSheet: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var batchService = SlideVoiceBatchService.shared
    @ObservedObject var aquesTalk = AquesTalkBridge.shared

    @Environment(\.presentationMode) var presentationMode

    // Source selection
    @State private var sourceOption: String = "current" // "current" or "file"
    @State private var loadedFileName: String = ""

    // Global Audio Settings (ゆっくりボイスメーカー準拠)
    @State private var globalQuality: AudioQualitySetting = .enhanced
    @State private var globalEffect: AudioEffectType = .none

    // Speed Mode: "template" (テンプレート固有速度を使用), "uniform" (一律固定速度)
    @State private var speedMode: String = "template"
    @State private var uniformSpeed: Int = 100

    // Extracted Items
    @State private var batchItems: [BatchVoiceItem] = []
    @State private var previewPlayingItemId: UUID? = nil
    @State private var autoPlaceTimeline: Bool = true
    @State private var showCompleteAlert: Bool = false
    @State private var speakerTemplateFeedback: String? = nil

    // Expanded custom editors for speakers: Set of speaker names
    @State private var expandedCustomSpeakers: Set<String> = []

    // Custom template save prompt state
    @State private var showSaveCustomTemplateAlert: Bool = false
    @State private var customTemplateSpeakerTarget: String = ""
    @State private var customTemplateNameInput: String = ""

    // Extracted Unique Speakers
    private var uniqueSpeakers: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for item in batchItems {
            if !seen.contains(item.characterName) {
                seen.insert(item.characterName)
                result.append(item.characterName)
            }
        }
        return result
    }

    private var activeItemCount: Int {
        batchItems.filter { !$0.isSkipped }.count
    }

    private var skippedItemCount: Int {
        batchItems.filter { $0.isSkipped }.count
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Main Content Area
            HStack(spacing: 0) {
                // Left Configuration & Speaker Template Sidebar
                sidebarConfigView
                    .frame(width: 360)
                    .background(Color(red: 0.16, green: 0.17, blue: 0.19))

                Divider()

                // Right: Extracted Dialogue Table & Preview
                dialogueTableView
                    .background(Color(red: 0.12, green: 0.13, blue: 0.15))
            }

            Divider()

            // Bottom Control & Progress Bar
            bottomControlView
        }
        .frame(width: 1180, height: 720)
        .background(Color(red: 0.14, green: 0.15, blue: 0.17))
        .onAppear {
            loadInitialItems()
        }
        .alert(isPresented: $showCompleteAlert) {
            Alert(
                title: Text("一括音声生成完了"),
                message: Text("対象 \(activeItemCount) 件のスライド音声を話者設定に合わせて生成しました。\n(スキップ: \(skippedItemCount) 件)\nタイムラインの波形トラックに配置されました。"),
                dismissButton: .default(Text("OK")) {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "sparkles.rectangle.stack.fill")
                .font(.system(size: 20))
                .foregroundColor(.cyan)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("スライド＆シナリオから全音声一括生成")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("カスタムテンプレート＆見出しスキップ対応")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.cyan.opacity(0.2))
                        .foregroundColor(.cyan)
                        .cornerRadius(3)
                }
                Text("話者ごとに声種・速度・音程をカスタマイズ変更して一括生成。セクション見出しとタイトルスライドは自動でスキップされます。")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action: { presentationMode.wrappedValue.dismiss() }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color(red: 0.18, green: 0.19, blue: 0.22))
    }

    // MARK: - Sidebar Config
    private var sidebarConfigView: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                // 1. Data Source Selection
                VStack(alignment: .leading, spacing: 8) {
                    Label("スライドソース", systemImage: "doc.text.magnifyingglass")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)

                    Picker("", selection: $sourceOption) {
                        Text("現在のスライド (\(appState.slides.count)枚)").tag("current")
                        Text("外部ファイル (.tspm / .key)").tag("file")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: sourceOption) { val in
                        if val == "current" {
                            loadInitialItems()
                        } else {
                            selectExternalFile()
                        }
                    }

                    if sourceOption == "file" && !loadedFileName.isEmpty {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text(loadedFileName)
                                .font(.caption2)
                                .lineLimit(1)
                            Spacer()
                            Button("変更...") {
                                selectExternalFile()
                            }
                            .font(.caption2)
                        }
                        .padding(6)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(4)
                    }
                }

                Divider().background(Color.white.opacity(0.1))

                // 2. 話者別音声テンプレート一括設定 & カスタマイズ (Speaker-to-Template Mapping & Customizer)
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("話者別テンプレート ＆ カスタム設定", systemImage: "person.2.badge.gearshape.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Text("\(uniqueSpeakers.count)名")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.cyan)
                    }

                    Text("既存テンプレートをベースに、声種（例: 機械1→女性1）や速度・音程を自由にカスタム変更できます。")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let feedback = speakerTemplateFeedback {
                        Text(feedback)
                            .font(.system(size: 10))
                            .foregroundColor(.green)
                            .transition(.opacity)
                    }

                    VStack(spacing: 10) {
                        ForEach(uniqueSpeakers, id: \.self) { speaker in
                            speakerTemplateCard(speaker: speaker)
                        }
                    }
                }

                Divider().background(Color.white.opacity(0.1))

                // 3. ゆっくりボイスメーカー準拠 音質改善設定
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("音質改善", systemImage: "waveform.badge.magnifyingglass")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                        Text("ゆっくりボイスメーカー準拠")
                            .font(.system(size: 8))
                            .foregroundColor(.cyan)
                    }

                    Picker("", selection: $globalQuality) {
                        ForEach(AudioQualitySetting.allCases) { q in
                            Text(q.displayName).tag(q)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(globalQuality.isEnabled
                         ? "44.1kHzアップサンプリング・高域明瞭化イコライザーにより、こもりのないクリアな音質で生成します。"
                         : "AquesTalk1の原音 (8kHz PCM) のまま出力します (ゆくも！風レトロ音質)。")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider().background(Color.white.opacity(0.1))

                // 4. ゆっくりボイスメーカー準拠 エフェクト設定
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("効果指定 (Effect)", systemImage: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                    }

                    Picker("", selection: $globalEffect) {
                        ForEach(AudioEffectType.allCases) { eff in
                            Text(eff.displayName).tag(eff)
                        }
                    }
                    .pickerStyle(.menu)

                    Text(globalEffect == .echo
                         ? "ディレイ残響を適用し、ゆっくり実況でおなじみの反響エコーサウンドを付加します。"
                         : "エフェクトをかけずに素直なストレート音声を出力します。")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Divider().background(Color.white.opacity(0.1))

                // 5. 発話速度モード設定
                VStack(alignment: .leading, spacing: 8) {
                    Label("発話速度設定", systemImage: "speedometer")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)

                    Picker("", selection: $speedMode) {
                        Text("テンプレート/カスタム速度を使用 (推奨)").tag("template")
                        Text("全スライド一律固定").tag("uniform")
                    }
                    .pickerStyle(.radioGroup)
                    .font(.caption)

                    if speedMode == "uniform" {
                        HStack {
                            Text("固定速度: \(uniformSpeed)%")
                                .font(.caption2)
                                .foregroundColor(.cyan)
                            Spacer()
                        }
                        Slider(value: Binding(
                            get: { Double(uniformSpeed) },
                            set: { uniformSpeed = Int($0) }
                        ), in: 50...200, step: 5)
                    } else {
                        Text("各話者・スライドに設定された固有の速度（例: こいし50%, 妖夢115%, 早苗90%など）をそのまま尊重して生成します。")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                Divider().background(Color.white.opacity(0.1))

                // 6. タイムライン配置設定
                VStack(alignment: .leading, spacing: 6) {
                    Toggle("生成音声をタイムラインに自動配置", isOn: $autoPlaceTimeline)
                        .font(.caption)
                        .toggleStyle(.checkbox)

                    Text("スキップされていないスライドの音声を話者別トラックに自動配置します。")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
            .padding(14)
        }
    }

    // MARK: - Speaker Template Card (With Custom Voice & Skip)
    private func speakerTemplateCard(speaker: String) -> some View {
        let isExpanded = expandedCustomSpeakers.contains(speaker)
        let speakerItems = batchItems.filter { $0.characterName == speaker }
        let currentItem = speakerItems.first
        let currentTplId = currentItem?.selectedTemplateId
        let isAllSkipped = !speakerItems.isEmpty && speakerItems.allSatisfy { $0.isSkipped }

        return VStack(alignment: .leading, spacing: 6) {
            // Header: Speaker Name + Count + Skip Button
            HStack {
                Circle()
                    .fill(colorForCharacter(speaker))
                    .frame(width: 8, height: 8)
                Text(speaker)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(isAllSkipped ? .secondary : .white)

                Spacer()

                Text("\(speakerItems.count)件")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)

                // Speaker-wide Skip toggle
                Button(action: {
                    toggleSkipForSpeaker(speaker: speaker)
                }) {
                    HStack(spacing: 2) {
                        Image(systemName: isAllSkipped ? "eye.slash.fill" : "checkmark.circle.fill")
                        Text(isAllSkipped ? "スキップ中" : "生成対象")
                    }
                    .font(.system(size: 9, weight: .semibold))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(isAllSkipped ? Color.orange.opacity(0.2) : Color.green.opacity(0.2))
                    .foregroundColor(isAllSkipped ? .orange : .green)
                    .cornerRadius(3)
                }
                .buttonStyle(.plain)
                .help(isAllSkipped ? "この話者の全スライドのスキップを解除" : "この話者の全スライドを一括スキップ")
            }

            // Template Picker (ベーステンプレート選択)
            HStack(spacing: 6) {
                Text("ベース:")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)

                Picker("", selection: Binding(
                    get: { currentTplId ?? UUID() },
                    set: { newId in
                        if let tpl = appState.voiceTemplates.first(where: { $0.id == newId }) {
                            applyTemplateToSpeaker(speaker: speaker, template: tpl)
                        }
                    }
                )) {
                    // Custom category
                    let customTemplates = appState.voiceTemplates.filter { $0.isCustom }
                    if !customTemplates.isEmpty {
                        Section(header: Text("カスタム設定")) {
                            ForEach(customTemplates) { tpl in
                                Text("★ [カスタム] \(tpl.name)").tag(tpl.id)
                            }
                        }
                    }

                    // Predefined templates
                    let standardTemplates = appState.voiceTemplates.filter { !$0.isCustom }
                    Section(header: Text("標準テンプレート (コゲの日記・Gスカ・独自)")) {
                        ForEach(standardTemplates) { tpl in
                            Text("\(tpl.name) [\(tpl.voiceType.displayShortName)]").tag(tpl.id)
                        }
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            // Current Settings Summary & Customize Toggle
            if let item = currentItem {
                HStack(spacing: 6) {
                    Text("\(item.voiceType.displayShortName)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.cyan)
                    Text("速:\(item.speed)%")
                        .font(.system(size: 9, design: .monospaced))
                    Text("音:\(item.pitch)")
                        .font(.system(size: 9, design: .monospaced))

                    Spacer()

                    // Expand/Collapse Customization
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isExpanded {
                                expandedCustomSpeakers.remove(speaker)
                            } else {
                                expandedCustomSpeakers.insert(speaker)
                            }
                        }
                    }) {
                        HStack(spacing: 3) {
                            Image(systemName: isExpanded ? "chevron.up.circle.fill" : "slider.horizontal.3")
                            Text(isExpanded ? "閉じる" : "設定変更...")
                        }
                        .font(.system(size: 9))
                        .foregroundColor(.cyan)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 2)
            }

            // Expanded Custom Settings Panel (既存設定をベースに自由に変更)
            if isExpanded, let item = currentItem {
                VStack(alignment: .leading, spacing: 6) {
                    Divider().background(Color.white.opacity(0.1))

                    // 1. 声種変更 (VoiceType Change: e.g. 機械1 -> 女声1)
                    HStack {
                        Text("声種変更:")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundColor(.white)
                        Spacer()
                        Picker("", selection: Binding(
                            get: { item.voiceType },
                            set: { newVoice in
                                updateSpeakerVoiceType(speaker: speaker, voiceType: newVoice)
                            }
                        )) {
                            ForEach(VoiceType.allCases) { v in
                                Text(v.displayShortName).tag(v)
                            }
                        }
                        .frame(width: 140)
                    }

                    // 2. 発話速度 (Speed)
                    HStack {
                        Text("発話速度:")
                            .font(.system(size: 10))
                        Spacer()
                        Text("\(item.speed)%")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    Slider(value: Binding(
                        get: { Double(item.speed) },
                        set: { updateSpeakerSpeed(speaker: speaker, speed: Int($0)) }
                    ), in: 50...200, step: 5)

                    // 3. 音程 (Pitch)
                    HStack {
                        Text("音程:")
                            .font(.system(size: 10))
                        Spacer()
                        Text("\(item.pitch)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    Slider(value: Binding(
                        get: { Double(item.pitch) },
                        set: { updateSpeakerPitch(speaker: speaker, pitch: Int($0)) }
                    ), in: 50...200, step: 1)

                    // 4. カスタムテンプレートとして保存ボタン
                    Button(action: {
                        saveAsCustomTemplate(speaker: speaker, item: item)
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "plus.square.fill")
                            Text("この設定を『カスタムテンプレート』として保存")
                        }
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.yellow)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(8)
                .background(Color.black.opacity(0.35))
                .cornerRadius(5)
            }
        }
        .padding(8)
        .background(Color.white.opacity(isAllSkipped ? 0.02 : 0.05))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isExpanded ? Color.cyan.opacity(0.5) : Color.clear, lineWidth: 1)
        )
    }

    // MARK: - Dialogue Table View
    private var dialogueTableView: some View {
        VStack(spacing: 0) {
            // Table Header Bar with Select/Skip All Buttons
            HStack(spacing: 12) {
                // Generate/Skip Check Header
                HStack(spacing: 4) {
                    Button(action: { toggleAllSkip() }) {
                        Image(systemName: skippedItemCount == 0 ? "checkmark.square.fill" : (activeItemCount == 0 ? "square" : "minus.square.fill"))
                            .foregroundColor(.cyan)
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.plain)
                    .help("全スライドの生成対象/スキップを一括切り替え")
                    Text("対象")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.secondary)
                }
                .frame(width: 50, alignment: .leading)

                Text("#")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 24, alignment: .center)

                Text("話者")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .leading)

                Text("セリフ・読み上げテキスト")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("声種・テンプレート変更")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 220, alignment: .leading)

                Text("表示時間 / アニメ")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 130, alignment: .leading)

                Text("試聴")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 44, alignment: .center)

                Text("状態")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 48, alignment: .center)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.4))

            // Table Rows
            if batchItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "text.badge.xmark")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("抽出されたスライドのセリフがありません")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("スライド＆シナリオメーカーにスライドを作成するか、外部ファイルを選択してください")
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.8))
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(spacing: 1) {
                        ForEach(Array(batchItems.enumerated()), id: \.element.id) { index, item in
                            dialogueTableRow(index: index, item: item)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func dialogueTableRow(index: Int, item: BatchVoiceItem) -> some View {
        HStack(spacing: 12) {
            // Generate/Skip Checkbox
            Button(action: {
                batchItems[index].isSkipped.toggle()
            }) {
                Image(systemName: item.isSkipped ? "square" : "checkmark.square.fill")
                    .font(.system(size: 14))
                    .foregroundColor(item.isSkipped ? .secondary.opacity(0.6) : .green)
            }
            .buttonStyle(.plain)
            .frame(width: 50, alignment: .center)
            .help(item.isTitleOrSectionHeader ? "タイトル・セクション見出しは音声スキップ設定です" : (item.isSkipped ? "クリックして生成対象にする" : "クリックして音声生成をスキップ"))

            // Slide Number
            Text("\(item.slideIndex)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundColor(item.isSkipped ? .secondary.opacity(0.5) : .secondary)
                .frame(width: 24, alignment: .center)

            // Speaker Badge
            HStack(spacing: 4) {
                Circle()
                    .fill(item.isSkipped ? Color.gray : colorForCharacter(item.characterName))
                    .frame(width: 7, height: 7)
                Text(item.characterName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(item.isSkipped ? .secondary : .white)
                    .lineLimit(1)
            }
            .frame(width: 80, alignment: .leading)

            // Dialogue Text & Type Badge
            HStack(spacing: 6) {
                // スライド種別バッジ（タイトル / セクション見出し）
                if item.slideType == "title" || item.slideIndex == 1 {
                    Text("タイトル")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.blue.opacity(0.35))
                        .foregroundColor(.cyan)
                        .cornerRadius(3)
                } else if item.slideType == "sectionHeader" || item.isTitleOrSectionHeader {
                    Text("中扉・見出し")
                        .font(.system(size: 8, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.purple.opacity(0.35))
                        .foregroundColor(Color(hex: "#DDA0DD"))
                        .cornerRadius(3)
                }

                if item.isSkipped {
                    Text(item.skipReason ?? "[スキップ]")
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.orange.opacity(0.2))
                        .foregroundColor(.orange)
                        .cornerRadius(3)
                }
                Text(SlideItem.cleanDialogueText(from: item.text))
                    .font(.system(size: 12))
                    .foregroundColor(item.isSkipped ? .secondary.opacity(0.6) : .white)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Individual Template & VoiceType Customizer for this specific slide
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    // VoiceType Quick Switcher (e.g. f1, f2, m1, jgr)
                    Picker("", selection: Binding(
                        get: { item.voiceType },
                        set: { newVoice in
                            batchItems[index].voiceType = newVoice
                        }
                    )) {
                        ForEach(VoiceType.allCases) { v in
                            Text(v.displayShortName).tag(v)
                        }
                    }
                    .frame(width: 100)

                    // Template Name / Base Picker
                    Picker("", selection: Binding(
                        get: { item.selectedTemplateId ?? UUID() },
                        set: { newId in
                            if let tpl = appState.voiceTemplates.first(where: { $0.id == newId }) {
                                applyTemplateToItem(index: index, template: tpl)
                            }
                        }
                    )) {
                        ForEach(appState.voiceTemplates) { tpl in
                            Text(tpl.name).tag(tpl.id)
                        }
                    }
                    .frame(width: 110)
                }
                .labelsHidden()

                HStack(spacing: 6) {
                    Text("速:\(item.speed)%")
                    Text("音:\(item.pitch)")
                }
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(item.isSkipped ? .secondary.opacity(0.5) : .cyan)
            }
            .frame(width: 220, alignment: .leading)

            // 表示時間 / アニメーション演出
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Image(systemName: item.animationDuration != nil ? "film.stack.fill" : "clock")
                        .font(.system(size: 8))
                        .foregroundColor(item.animationDuration != nil ? .yellow : .cyan)
                    Text(String(format: "%.1f秒", item.effectiveSceneDuration))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundColor(item.isSkipped ? .secondary : .white)
                }
                if let note = item.animationNote {
                    Text("🎬 \(note)")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.yellow)
                        .lineLimit(1)
                } else if let animDur = item.animationDuration {
                    Text("🎬 アニメ: \(String(format: "%.1f", animDur))秒")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundColor(.yellow)
                        .lineLimit(1)
                } else {
                    Text("通常シーン")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary.opacity(0.7))
                }
            }
            .frame(width: 130, alignment: .leading)

            // Preview Play Button (Respects this item's specific template/custom settings)
            Button(action: {
                previewItem(item)
            }) {
                Image(systemName: previewPlayingItemId == item.id ? "stop.fill" : "play.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(previewPlayingItemId == item.id ? .green : (item.isSkipped ? .secondary : .cyan))
            }
            .buttonStyle(.plain)
            .frame(width: 44, alignment: .center)
            .help("このスライドのセリフを設定パラメータで試聴 (スキップ設定でも試聴可能)")

            // Status Badge
            Group {
                if item.isSkipped {
                    Text("除外")
                        .font(.system(size: 9))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .foregroundColor(.orange.opacity(0.8))
                        .cornerRadius(3)
                } else if item.isGenerated {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                        Text("済")
                            .font(.system(size: 9))
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(3)
                } else {
                    Text("待機")
                        .font(.system(size: 9))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.2))
                        .foregroundColor(.secondary)
                        .cornerRadius(3)
                }
            }
            .frame(width: 48, alignment: .center)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(index % 2 == 0 ? Color.white.opacity(item.isSkipped ? 0.01 : 0.02) : Color.white.opacity(item.isSkipped ? 0.02 : 0.04))
        .opacity(item.isSkipped ? 0.55 : 1.0)
    }

    // MARK: - Bottom Control View & Progress Bar
    private var bottomControlView: some View {
        VStack(spacing: 8) {
            // Progress Bar (Generating State)
            if batchService.isGenerating {
                VStack(spacing: 4) {
                    HStack {
                        ProgressView(value: Double(batchService.progressCurrent), total: Double(max(1, batchService.progressTotal)))
                            .progressViewStyle(.linear)
                        Text("\(batchService.progressCurrent) / \(batchService.progressTotal)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    Text(batchService.currentProcessingMessage)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 18)
                .padding(.top, 4)
            }

            // Bottom Buttons
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 8) {
                        Text("生成対象: \(activeItemCount) 件")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundColor(.white)
                        if skippedItemCount > 0 {
                            Text("(スキップ: \(skippedItemCount) 件)")
                                .font(.system(size: 11))
                                .foregroundColor(.orange)
                        }
                        Text("(\(uniqueSpeakers.count)名)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    Text("話者別カスタム設定・音質改善(\(globalQuality.displayName))・効果(\(globalEffect.displayName))が適用されます")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("キャンセル") {
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button(action: {
                    startBatchGeneration()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: batchService.isGenerating ? "arrow.triangle.2.circlepath" : "waveform.badge.plus")
                        Text(batchService.isGenerating ? "生成中..." : "対象スライドを一括生成 (\(activeItemCount)件)")
                    }
                    .font(.system(size: 12, weight: .bold))
                }
                .buttonStyle(.borderedProminent)
                .disabled(activeItemCount == 0 || batchService.isGenerating)
            }
            .padding(.horizontal, 18)
            .padding(.bottom, 12)
            .padding(.top, 4)
        }
        .background(Color(red: 0.16, green: 0.17, blue: 0.20))
    }

    // MARK: - Helpers & Template Logic
    private func loadInitialItems() {
        if !appState.slides.isEmpty {
            batchItems = batchService.extractBatchItems(
                from: appState.slides,
                defaultEffect: globalEffect,
                defaultQuality: globalQuality
            )
        } else {
            // デモ用またはスライドがない場合のデフォルトサンプル（タイトル・セクション見出しスキップ対応）
            let sampleSlides = [
                SlideItem(slideIndex: 1, title: "第1話：幻想郷の異変", telop: "東方Project二次創作", presenterNote: "(ナレーション) 第1話：幻想郷の異変", characterName: "ナレーション", slideType: "title"),
                SlideItem(slideIndex: 2, title: "セクション見出し", telop: "その頃、博麗神社では――", presenterNote: "(ナレーション) その頃、博麗神社では――", characterName: "ナレーション", slideType: "sectionHeader"),
                SlideItem(slideIndex: 3, title: "博麗神社", telop: "ゆっくりしていってね！", presenterNote: "(博麗霊夢) ゆっくりしていってね！", characterName: "博麗霊夢", slideType: "content"),
                SlideItem(slideIndex: 4, title: "調査開始", telop: "よし、魔理沙様がひとっ走り解決してくるぜ！", presenterNote: "(霧雨魔理沙) よし、魔理沙様がひとっ走り解決してくるぜ！", characterName: "霧雨魔理沙", slideType: "content"),
                SlideItem(slideIndex: 5, title: "にとりの工房", telop: "河城にとりだよ！何か作ろうか？", presenterNote: "(河城にとり) 河城にとりだよ！何か作ろうか？", characterName: "河城にとり", slideType: "content")
            ]
            batchItems = batchService.extractBatchItems(
                from: sampleSlides,
                defaultEffect: globalEffect,
                defaultQuality: globalQuality
            )
        }
    }

    private func selectExternalFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = []
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.message = "スライド＆シナリオファイル (.tspm / .key) を選択してください"

        if panel.runModal() == .OK, let url = panel.url {
            loadedFileName = url.lastPathComponent
            batchService.extractBatchItemsFromFile(
                url: url,
                defaultEffect: globalEffect,
                defaultQuality: globalQuality
            ) { items in
                self.batchItems = items
                self.appState.log("外部ファイル \(url.lastPathComponent) から \(items.count) 件のセリフを抽出しました")
            }
        }
    }

    /// 話者に音声テンプレートを一括適用
    private func applyTemplateToSpeaker(speaker: String, template: VoiceTemplate) {
        batchService.applyTemplateToSpeaker(speaker: speaker, template: template, items: &batchItems)
        let affectedCount = batchItems.filter { $0.characterName == speaker }.count
        speakerTemplateFeedback = "話者『\(speaker)』に『\(template.name)』を適用しました (\(affectedCount)件)"
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            if self.speakerTemplateFeedback?.contains(speaker) == true {
                self.speakerTemplateFeedback = nil
            }
        }
    }

    /// 話者の声種を一括変更 (例: にとりの機械1 -> 女性1)
    private func updateSpeakerVoiceType(speaker: String, voiceType: VoiceType) {
        for i in 0..<batchItems.count {
            if batchItems[i].characterName == speaker {
                batchItems[i].voiceType = voiceType
            }
        }
        speakerTemplateFeedback = "話者『\(speaker)』の声を [\(voiceType.displayShortName)] に変更しました"
    }

    /// 話者の速度を一括変更
    private func updateSpeakerSpeed(speaker: String, speed: Int) {
        for i in 0..<batchItems.count {
            if batchItems[i].characterName == speaker {
                batchItems[i].speed = speed
            }
        }
    }

    /// 話者の音程を一括変更
    private func updateSpeakerPitch(speaker: String, pitch: Int) {
        for i in 0..<batchItems.count {
            if batchItems[i].characterName == speaker {
                batchItems[i].pitch = pitch
            }
        }
    }

    /// 話者のスキップ一括トグル
    private func toggleSkipForSpeaker(speaker: String) {
        let speakerItems = batchItems.filter { $0.characterName == speaker }
        let shouldSkip = !speakerItems.allSatisfy { $0.isSkipped }
        for i in 0..<batchItems.count {
            if batchItems[i].characterName == speaker {
                batchItems[i].isSkipped = shouldSkip
            }
        }
    }

    /// 全アイテムのスキップ一括トグル（セクション見出し・タイトルスライドは必ずスキップを維持）
    private func toggleAllSkip() {
        // 通常スライド（タイトル・セクション見出し以外）の有効状態を確認
        let activeRegularCount = batchItems.filter { !$0.isSkipped && !$0.isTitleOrSectionHeader }.count
        let shouldSkipRegular = (activeRegularCount > 0)
        for i in 0..<batchItems.count {
            if batchItems[i].isTitleOrSectionHeader {
                batchItems[i].isSkipped = true // セクション見出しとタイトルスライドは必ずスキップ
            } else {
                batchItems[i].isSkipped = shouldSkipRegular
            }
        }
    }

    /// 現在の設定をカスタムテンプレートとして新規保存
    private func saveAsCustomTemplate(speaker: String, item: BatchVoiceItem) {
        let customName = "\(speaker) (カスタム: \(item.voiceType.dylibSuffix))"
        let savedTpl = appState.saveCustomVoiceTemplate(
            name: customName,
            characterName: speaker,
            voiceType: item.voiceType,
            speed: item.speed,
            pitch: item.pitch,
            baseTemplateName: item.templateName
        )
        // 話者のテンプレートIDを新規保存したカスタムに更新
        applyTemplateToSpeaker(speaker: speaker, template: savedTpl)
        speakerTemplateFeedback = "カスタムテンプレート『\(customName)』を保存・適用しました！"
    }

    /// 特定のスライド行にテンプレートを適用
    private func applyTemplateToItem(index: Int, template: VoiceTemplate) {
        guard index < batchItems.count else { return }
        batchItems[index].selectedTemplateId = template.id
        batchItems[index].templateName = template.name
        batchItems[index].voiceType = template.voiceType
        batchItems[index].speed = template.speed
        batchItems[index].pitch = template.pitch
    }

    /// 個別試聴（そのスライドのテンプレート/カスタムパラメータで再生）
    private func previewItem(_ item: BatchVoiceItem) {
        if previewPlayingItemId == item.id {
            previewPlayingItemId = nil
            return
        }

        previewPlayingItemId = item.id
        let effectiveSpeed = (speedMode == "uniform") ? uniformSpeed : item.speed

        aquesTalk.synthesizeAndPlay(
            text: SlideItem.cleanDialogueText(from: item.text),
            speed: effectiveSpeed,
            voice: item.voiceType,
            pitch: item.pitch,
            quality: globalQuality,
            effect: globalEffect
        ) {
            DispatchQueue.main.async {
                if self.previewPlayingItemId == item.id {
                    self.previewPlayingItemId = nil
                }
            }
        }
    }

    /// 話者テンプレート・カスタム設定を反映した状態で一括生成を実行
    private func startBatchGeneration() {
        var itemsToProcess = batchItems

        // 速度モードの反映
        if speedMode == "uniform" {
            for i in 0..<itemsToProcess.count {
                itemsToProcess[i].speed = uniformSpeed
            }
        }

        batchService.synthesizeAll(
            items: itemsToProcess,
            globalEffect: globalEffect,
            globalQuality: globalQuality
        ) { completedItems in
            self.batchItems = completedItems
            if self.autoPlaceTimeline {
                self.batchService.applyToSoundMakerTimeline(items: completedItems)
            }
            self.showCompleteAlert = true
        }
    }

    private func colorForCharacter(_ name: String) -> Color {
        if name.contains("霊夢") { return Color(hex: "#E74C3C") }
        if name.contains("魔理沙") { return Color(hex: "#F1C40F") }
        if name.contains("咲夜") { return Color(hex: "#3498DB") }
        if name.contains("妖夢") { return Color(hex: "#2ECC71") }
        if name.contains("紫") { return Color(hex: "#9B59B6") }
        if name.contains("早苗") { return Color(hex: "#1ABC9C") }
        if name.contains("にとり") { return Color(hex: "#00B894") }
        return .cyan
    }
}

// MARK: - Color Hex Helper
private extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted))
        var int: UInt64 = 0
        scanner.scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
