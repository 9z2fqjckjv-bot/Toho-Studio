import SwiftUI
import AppKit
import AVFoundation

public struct SpanAudioInsertSheet: View {
    @ObservedObject var appState = AppState.shared
    @Environment(\.presentationMode) var presentationMode

    // Audio Type
    @State private var audioType: String = "BGM" // "BGM" or "SE"

    // Scene Range
    @State private var startSceneIndex: Int = 1
    @State private var endSceneIndex: Int = 1

    // Sound Selection
    @State private var selectedPresetName: String = "少女綺想曲 〜 Dream Battle風"
    @State private var customAudioFilePath: String? = nil
    @State private var customAudioFileName: String = ""

    // Parameters
    @State private var volume: Double = 0.7
    @State private var fadeInDuration: Double = 1.5
    @State private var fadeOutDuration: Double = 2.0
    @State private var isLooping: Bool = true
    @State private var playbackRate: Double = 1.0
    @State private var isReversed: Bool = false

    // Preview
    @State private var isPreviewPlaying: Bool = false
    @State private var previewPlayer: AVAudioPlayer? = nil

    // Available scenes
    private var scenes: [MovieScene] {
        if !appState.movieScenes.isEmpty {
            return appState.movieScenes
        }
        if !appState.slides.isEmpty {
            return appState.slides.map { s in
                MovieScene(
                    title: "シーン \(s.slideIndex): \(s.title)",
                    duration: s.duration,
                    slideTitle: s.title,
                    backgroundName: s.backgroundName,
                    characterName: s.characterName,
                    telop: s.telop
                )
            }
        }
        return [
            MovieScene(title: "シーン 1: 霊夢と魔理沙の会話", duration: 15.0, slideTitle: "第1幕", backgroundName: "神社", characterName: "博麗霊夢", telop: "また異変の気配がするわね"),
            MovieScene(title: "シーン 2: 異変の兆候", duration: 12.0, slideTitle: "第2幕", backgroundName: "魔法の森", characterName: "霧雨魔理沙", telop: "よし、調査に出発だぜ！"),
            MovieScene(title: "シーン 3: 紅魔館前", duration: 18.0, slideTitle: "第3幕", backgroundName: "紅魔館", characterName: "十六夜咲夜", telop: "お嬢様がお待ちかねです")
        ]
    }

    // BGM Presets
    private let bgmPresets: [AudioPresetItem] = [
        AudioPresetItem(name: "少女綺想曲 〜 Dream Battle風", type: "BGM", category: "東方原曲風", description: "博麗神社・博麗霊夢のテーマ。躍動感あふれる和風オーケストラサウンド。", defaultDuration: 180.0, defaultVolume: 0.65),
        AudioPresetItem(name: "恋色マスタースパーク風", type: "BGM", category: "東方原曲風", description: "霧雨魔理沙のテーマ。疾走感あるアップテンポなロック調BGM。", defaultDuration: 190.0, defaultVolume: 0.65),
        AudioPresetItem(name: "フラワリングナイト風", type: "BGM", category: "東方原曲風", description: "十六夜咲夜のテーマ。緊迫感とスピード感に満ちたジャズロック。", defaultDuration: 175.0, defaultVolume: 0.65),
        AudioPresetItem(name: "幽雅に咲かせ、墨染の桜風", type: "BGM", category: "東方原曲風", description: "西行寺幽々子のテーマ。優美で荘厳な和風シンフォニー。", defaultDuration: 210.0, defaultVolume: 0.60),
        AudioPresetItem(name: "ほのぼの日常会話", type: "BGM", category: "日常・解説", description: "茶番劇やゆっくり解説に最適な明るく軽快なアコースティックBGM。", defaultDuration: 150.0, defaultVolume: 0.55),
        AudioPresetItem(name: "緊迫！異変の兆候", type: "BGM", category: "緊迫・戦闘", description: "ボス戦突入や対峙シーンを盛り上げる重厚なシンセストリングス。", defaultDuration: 160.0, defaultVolume: 0.70),
        AudioPresetItem(name: "夜の幻想郷", type: "BGM", category: "日常・解説", description: "夜の探索や静かな考察シーンに適した穏やかなピアノアンビエント。", defaultDuration: 200.0, defaultVolume: 0.50),
        AudioPresetItem(name: "勝利と宴", type: "BGM", category: "東方原曲風", description: "異変解決後の宴会やエンディングを飾る祝祭的なサウンド。", defaultDuration: 170.0, defaultVolume: 0.60)
    ]

    // SE Presets
    private let sePresets: [AudioPresetItem] = [
        AudioPresetItem(name: "スペルカード展開 (キラーン)", type: "SE", category: "演出", description: "必殺技やスペルカード宣言時の華やかなチャイム音。", defaultDuration: 2.2, defaultVolume: 0.85, isLoopable: false),
        AudioPresetItem(name: "弾幕発射音 (シュッ)", type: "SE", category: "演出", description: "高速で弾幕が放たれる連続発射効果音。", defaultDuration: 1.5, defaultVolume: 0.80, isLoopable: true),
        AudioPresetItem(name: "弾幕ヒット・爆発音 (ドカーン)", type: "SE", category: "演出", description: "重低音を効かせた迫力のある爆発インパクト音。", defaultDuration: 2.8, defaultVolume: 0.90, isLoopable: false),
        AudioPresetItem(name: "魔力チャージ (重低音ブオオオン)", type: "SE", category: "演出", description: "マスタースパークなどの溜め演出に最適な持続低音。", defaultDuration: 3.5, defaultVolume: 0.85, isLoopable: true),
        AudioPresetItem(name: "ピチュン (被弾・消失音)", type: "SE", category: "演出", description: "東方おなじみの被弾・消滅効果音。", defaultDuration: 1.2, defaultVolume: 0.85, isLoopable: false),
        AudioPresetItem(name: "風切り音 (ヒュッ)", type: "SE", category: "演出", description: "キャラクターの高速移動や瞬間移動演出。", defaultDuration: 1.0, defaultVolume: 0.75, isLoopable: false),
        AudioPresetItem(name: "決定音 (システム音)", type: "SE", category: "システム", description: "メニュー選択やシーン転換時の心地よいクリック音。", defaultDuration: 0.6, defaultVolume: 0.80, isLoopable: false),
        AudioPresetItem(name: "歓声・拍手", type: "SE", category: "演出", description: "シーン全体を包み込む賑やかな歓声と拍手の持続環境音。", defaultDuration: 10.0, defaultVolume: 0.70, isLoopable: true)
    ]

    private var activePresets: [AudioPresetItem] {
        audioType == "BGM" ? bgmPresets : sePresets
    }

    // Calculated Time Range
    private var spanTiming: (startTime: Double, duration: Double, endTime: Double) {
        let maxScene = scenes.count
        let sIdx = max(1, min(startSceneIndex, maxScene)) - 1
        let eIdx = max(sIdx + 1, min(endSceneIndex, maxScene)) - 1

        var startT: Double = 0.0
        for i in 0..<sIdx {
            startT += scenes[i].duration
        }

        var spanDur: Double = 0.0
        for i in sIdx...eIdx {
            spanDur += scenes[i].duration
        }

        return (startT, spanDur, startT + spanDur)
    }

    public init(initialStartScene: Int = 1) {
        _startSceneIndex = State(initialValue: initialStartScene)
        _endSceneIndex = State(initialValue: max(initialStartScene, 2))
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Main Settings Form
            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 18) {
                    // 1. Audio Type Selection (BGM or SE)
                    audioTypeSection

                    // 2. Scene Span Range Selector
                    sceneSpanRangeSection

                    // 3. Audio Source Selection (Preset or External File)
                    audioSourceSection

                    // 4. Audio Playback Parameters (Volume, Fades, Loop)
                    audioParametersSection
                }
                .frame(maxWidth: 640)
                .padding(20)
            }
            .frame(width: 680)
            .clipped()

            Divider()

            // Footer / Actions
            footerView
        }
        .frame(width: 680, height: 640)
        .background(Color(red: 0.14, green: 0.15, blue: 0.17))
        .onAppear {
            let maxCount = max(1, scenes.count)
            if endSceneIndex > maxCount {
                endSceneIndex = maxCount
            }
            if endSceneIndex < startSceneIndex {
                endSceneIndex = min(maxCount, startSceneIndex + 1)
            }
        }
        .onDisappear {
            stopPreview()
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.triangle.merge")
                .font(.system(size: 20))
                .foregroundColor(.cyan)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("複数シーンにまたがるBGM・SEを挿入")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("シーン跨ぎ配置")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Color.purple.opacity(0.3))
                        .foregroundColor(Color(hex: "#DDA0DD"))
                        .cornerRadius(3)
                }
                Text("指定した複数のシーン区間に途切れなく流れるBGMや持続効果音をタイムラインに一括配置します。")
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
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(red: 0.18, green: 0.19, blue: 0.22))
    }

    // MARK: - 1. Audio Type Selection
    private var audioTypeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("挿入するオーディオの種類", systemImage: "music.note.list")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)

            Picker("", selection: $audioType) {
                Text("🎵 BGM (背景音楽)").tag("BGM")
                Text("⚡️ SE (効果音・環境音)").tag("SE")
            }
            .pickerStyle(.segmented)
            .onChange(of: audioType) { newType in
                if newType == "BGM" {
                    selectedPresetName = "少女綺想曲 〜 Dream Battle風"
                    volume = 0.65
                    isLooping = true
                    fadeInDuration = 1.5
                    fadeOutDuration = 2.0
                } else {
                    selectedPresetName = "スペルカード展開 (キラーン)"
                    volume = 0.85
                    isLooping = false
                    fadeInDuration = 0.0
                    fadeOutDuration = 0.5
                }
            }
        }
        .padding(12)
        .background(Color(red: 0.16, green: 0.17, blue: 0.20))
        .cornerRadius(6)
    }

    // MARK: - 2. Scene Span Range Section
    private var sceneSpanRangeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("またがるシーンの範囲", systemImage: "film.stack")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text("全 \(scenes.count) シーン")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Pickers for Start and End Scene
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("開始シーン:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("", selection: $startSceneIndex) {
                        ForEach(1...max(1, scenes.count), id: \.self) { idx in
                            let title = (idx <= scenes.count) ? scenes[idx - 1].title : "シーン \(idx)"
                            Text("S\(idx): \(title)").tag(idx)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: startSceneIndex) { newStart in
                        if endSceneIndex < newStart {
                            endSceneIndex = newStart
                        }
                    }
                }
                .frame(maxWidth: .infinity)

                Image(systemName: "arrow.right")
                    .foregroundColor(.cyan)
                    .font(.system(size: 14, weight: .bold))
                    .padding(.top, 16)

                VStack(alignment: .leading, spacing: 4) {
                    Text("終了シーン:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Picker("", selection: $endSceneIndex) {
                        ForEach(startSceneIndex...max(1, scenes.count), id: \.self) { idx in
                            let title = (idx <= scenes.count) ? scenes[idx - 1].title : "シーン \(idx)"
                            Text("S\(idx): \(title)").tag(idx)
                        }
                    }
                    .pickerStyle(.menu)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity)
            }

            // Visual Graphic Bar of Scenes (Proportional Timeline Gauge + Scrollable Scene Cards)
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("シーン区間タイムライン:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("S\(startSceneIndex) 〜 S\(endSceneIndex) 選択中")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.cyan)
                }

                // 1. Proportional Timeline Gauge (絶対に横幅をオーバーフローさせないゲージ)
                let totalDuration = max(1.0, scenes.reduce(0.0) { $0 + $1.duration })
                let startFraction = min(1.0, max(0.0, spanTiming.startTime / totalDuration))
                let spanFraction = min(1.0 - startFraction, max(0.02, spanTiming.duration / totalDuration))

                GeometryReader { geo in
                    let barWidth = geo.size.width
                    ZStack(alignment: .leading) {
                        // Total timeline background
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.4))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )

                        // Highlighted span
                        RoundedRectangle(cornerRadius: 3)
                            .fill(
                                LinearGradient(
                                    colors: audioType == "BGM" ?
                                        [Color.purple.opacity(0.8), Color(hex: "#9B59B6")] :
                                        [Color.green.opacity(0.8), Color.teal],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(8, barWidth * CGFloat(spanFraction)), height: 18)
                            .offset(x: barWidth * CGFloat(startFraction))
                            .overlay(
                                HStack {
                                    Text("S\(startSceneIndex)")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.white)
                                        .padding(.leading, 4)
                                    Spacer()
                                    if startSceneIndex != endSceneIndex {
                                        Text("S\(endSceneIndex)")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.trailing, 4)
                                    }
                                }
                                .frame(width: max(8, barWidth * CGFloat(spanFraction)))
                                .offset(x: barWidth * CGFloat(startFraction))
                            )
                    }
                }
                .frame(height: 18)

                // 2. Horizontally Scrollable Scene Chips (選択区間周辺のシーンを快適に視認)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
                        let displayRange = scenes.indices
                        ForEach(displayRange, id: \.self) { i in
                            let idx = i + 1
                            let isIncluded = (idx >= startSceneIndex && idx <= endSceneIndex)
                            let scene = scenes[i]
                            Button(action: {
                                if idx < startSceneIndex {
                                    startSceneIndex = idx
                                } else {
                                    endSceneIndex = idx
                                }
                            }) {
                                VStack(spacing: 2) {
                                    Text("S\(idx)")
                                        .font(.system(size: 9, weight: .bold))
                                        .foregroundColor(isIncluded ? .white : .secondary)
                                    Text(String(format: "%.1fs", scene.duration))
                                        .font(.system(size: 8))
                                        .foregroundColor(isIncluded ? .white.opacity(0.8) : .secondary.opacity(0.6))
                                }
                                .frame(width: 48, height: 32)
                                .background(
                                    isIncluded ?
                                        (audioType == "BGM" ? Color.purple.opacity(0.6) : Color.green.opacity(0.6)) :
                                        Color.white.opacity(0.05)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(isIncluded ? (audioType == "BGM" ? Color(hex: "#DDA0DD") : Color.green) : Color.clear, lineWidth: 1.5)
                                )
                                .cornerRadius(3)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: 38)

                // Time Summary Banner
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 10))
                        Text(String(format: "開始位置: %.2fs", spanTiming.startTime))
                            .font(.system(size: 11, design: .monospaced))
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 10))
                        Text(String(format: "総継続時間: %.2f 秒", spanTiming.duration))
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.cyan)
                    }
                    HStack(spacing: 4) {
                        Image(systemName: "flag.checkered")
                            .font(.system(size: 10))
                        Text(String(format: "終了位置: %.2fs", spanTiming.endTime))
                            .font(.system(size: 11, design: .monospaced))
                    }
                }
                .foregroundColor(.white.opacity(0.85))
                .padding(.vertical, 2)
            }
        }
        .padding(12)
        .background(Color(red: 0.16, green: 0.17, blue: 0.20))
        .cornerRadius(6)
    }

    // MARK: - 3. Audio Source Selection
    private var audioSourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("音源の選択", systemImage: "waveform.circle")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)

            // Preset List
            VStack(alignment: .leading, spacing: 6) {
                Text("プリセットから選択:")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Picker("", selection: $selectedPresetName) {
                    ForEach(activePresets) { preset in
                        Text("\(preset.name) (\(preset.category))").tag(preset.name)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: selectedPresetName) { newName in
                    customAudioFilePath = nil
                    customAudioFileName = ""
                    if let matched = activePresets.first(where: { $0.name == newName }) {
                        volume = matched.defaultVolume
                        isLooping = matched.isLoopable
                    }
                }

                if let currentPreset = activePresets.first(where: { $0.name == selectedPresetName }) {
                    Text(currentPreset.description)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
            }

            Divider().background(Color.white.opacity(0.1))

            // External Local File Selection
            HStack(spacing: 10) {
                Button(action: selectLocalAudioFile) {
                    Label(customAudioFileName.isEmpty ? "ローカル音声ファイルを選択 (.wav, .mp3, .m4a)..." : "ファイル変更: \(customAudioFileName)", systemImage: "folder.badge.plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                if !customAudioFileName.isEmpty {
                    Button(action: {
                        customAudioFilePath = nil
                        customAudioFileName = ""
                    }) {
                        Image(systemName: "xmark.circle")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("外部ファイルの選択を解除")
                }

                Spacer()

                // Preview Button
                Button(action: togglePreview) {
                    HStack(spacing: 4) {
                        Image(systemName: isPreviewPlaying ? "stop.fill" : "play.fill")
                        Text(isPreviewPlaying ? "停止" : "試聴")
                    }
                    .font(.caption)
                    .foregroundColor(isPreviewPlaying ? .green : .cyan)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(Color(red: 0.16, green: 0.17, blue: 0.20))
        .cornerRadius(6)
    }

    // MARK: - 4. Audio Playback Parameters
    private var audioParametersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("オーディオ再生設定", systemImage: "slider.vertical.3")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)

            // Volume Slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("音量 (Volume):")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(volume * 100))%")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.cyan)
                }
                Slider(value: $volume, in: 0.0...1.0)
            }

            // Fades
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("フェードイン:")
                            .font(.caption)
                        Spacer()
                        Text(String(format: "%.1f 秒", fadeInDuration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $fadeInDuration, in: 0.0...5.0, step: 0.5)
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("フェードアウト:")
                            .font(.caption)
                        Spacer()
                        Text(String(format: "%.1f 秒", fadeOutDuration))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Slider(value: $fadeOutDuration, in: 0.0...5.0, step: 0.5)
                }
            }

            // Playback Speed (倍速再生)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("再生速度 (倍速):")
                        .font(.caption)
                        .foregroundColor(.white)
                    Spacer()
                    Text(String(format: "%.2fx", playbackRate))
                        .font(.caption.bold())
                        .foregroundColor(playbackRate != 1.0 ? .cyan : .white)
                }

                HStack(spacing: 6) {
                    ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 2.0], id: \.self) { rate in
                        Button(action: {
                            playbackRate = rate
                            if isPreviewPlaying { startPreview() }
                        }) {
                            Text(String(format: "%.2fx", rate))
                                .font(.system(size: 9, weight: .bold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                                .background(playbackRate == rate ? Color.cyan : Color.white.opacity(0.1))
                                .foregroundColor(playbackRate == rate ? .black : .white)
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Reverse Playback Toggle (逆再生)
            Toggle(isOn: Binding(
                get: { isReversed },
                set: { val in
                    isReversed = val
                    if isPreviewPlaying { startPreview() }
                }
            )) {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.uturn.backward")
                        .foregroundColor(.orange)
                    Text("逆再生 (リバース再生)")
                        .font(.caption)
                        .foregroundColor(.white)
                }
            }
            .toggleStyle(.checkbox)

            // Loop Toggle
            Toggle(isOn: $isLooping) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("区間全体にわたってループ再生する")
                        .font(.caption)
                        .foregroundColor(.white)
                    Text("選択したシーン区間の長さに合わせて、音が途切れないよう自動ループさせます。")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.checkbox)
        }
        .padding(12)
        .background(Color(red: 0.16, green: 0.17, blue: 0.20))
        .cornerRadius(6)
    }

    // MARK: - Footer
    private var footerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("配置先: S\(startSceneIndex) 〜 S\(endSceneIndex) (計 \(spanTiming.duration, specifier: "%.1f")秒)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
                Text(customAudioFileName.isEmpty ? "音源: \(selectedPresetName)" : "音源: \(customAudioFileName)")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Button("キャンセル") {
                stopPreview()
                presentationMode.wrappedValue.dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button(action: insertSpanAudio) {
                HStack(spacing: 6) {
                    Image(systemName: "plus.rectangle.on.rectangle")
                    Text("シーン区間に挿入 (S\(startSceneIndex)〜S\(endSceneIndex))")
                }
                .font(.system(size: 12, weight: .bold))
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(Color(red: 0.18, green: 0.19, blue: 0.22))
    }

    // MARK: - Actions
    private func selectLocalAudioFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = []
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.message = "タイムラインに挿入するオーディオファイル (.wav, .mp3, .m4a, .aiff) を選択してください"

        if panel.runModal() == .OK, let url = panel.url {
            customAudioFilePath = url.path
            customAudioFileName = url.lastPathComponent
            stopPreview()
        }
    }

    private func togglePreview() {
        if isPreviewPlaying {
            stopPreview()
        } else {
            startPreview()
        }
    }

    private func startPreview() {
        stopPreview()

        let dummyClip = SoundClip(
            name: customAudioFileName.isEmpty ? selectedPresetName : customAudioFileName,
            type: audioType,
            duration: spanTiming.duration,
            volume: volume,
            isLooping: isLooping,
            audioFilePath: customAudioFilePath,
            playbackRate: playbackRate,
            isReversed: isReversed
        )

        if let player = SoundMakerAudioManager.shared.createConfiguredPlayer(for: dummyClip) {
            previewPlayer = player
            player.play()
            isPreviewPlaying = true
        }
    }

    private func stopPreview() {
        previewPlayer?.stop()
        previewPlayer = nil
        isPreviewPlaying = false
    }

    private func insertSpanAudio() {
        stopPreview()

        let timing = spanTiming
        let targetTrackId = (audioType == "BGM") ? "track_bgm" : "track_se"
        let clipColor = (audioType == "BGM") ? "#9B59B6" : "#2ECC71"
        let soundTitle = customAudioFileName.isEmpty ? selectedPresetName : customAudioFileName

        // トラックの存在確認
        if !appState.audioTracks.contains(where: { $0.id == targetTrackId }) {
            let trackName = (audioType == "BGM") ? "BGM (背景音楽)" : "SE (効果音)"
            let iconName = (audioType == "BGM") ? "music.note" : "bolt.fill"
            let track = AudioTrack(
                id: targetTrackId,
                name: trackName,
                type: audioType.lowercased(),
                icon: iconName,
                colorHex: clipColor,
                volume: volume,
                pan: 0.0
            )
            appState.audioTracks.append(track)
        }

        let clipName = "[\(audioType)] \(soundTitle)"
        let wave: [Float] = (audioType == "BGM") ?
            [0.5, 0.65, 0.7, 0.55, 0.8, 0.65, 0.7, 0.6, 0.75, 0.6, 0.85, 0.7, 0.6] :
            [0.9, 0.8, 0.65, 0.5, 0.3, 0.2, 0.1, 0.05]

        let newClip = SoundClip(
            name: clipName,
            type: audioType,
            duration: timing.duration,
            volume: volume,
            startTime: timing.startTime,
            trackId: targetTrackId,
            pan: 0.0,
            colorHex: clipColor,
            waveformPoints: wave,
            sceneIndex: startSceneIndex,
            spanStartSceneIndex: startSceneIndex,
            spanEndSceneIndex: endSceneIndex,
            fadeInDuration: fadeInDuration,
            fadeOutDuration: fadeOutDuration,
            isLooping: isLooping,
            audioFilePath: customAudioFilePath,
            playbackRate: playbackRate,
            isReversed: isReversed
        )

        appState.soundClips.append(newClip)
        appState.log("複数シーン跨ぎ \(audioType)『\(soundTitle)』を S\(startSceneIndex)〜S\(endSceneIndex) (計 \(String(format: "%.1f", timing.duration))秒) に挿入しました")

        presentationMode.wrappedValue.dismiss()
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
