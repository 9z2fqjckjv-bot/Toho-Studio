import SwiftUI
import AppKit

/// 仕様書「AI BGM & SE 生成機能」プログラム
/// 東方風プロシージャル波形合成、リアルタイム試聴、およびSoundMaker/MovieMaker/素材スタジオ連携
public struct AISoundGeneratorProgramView: View {
    @ObservedObject var soundService = AISoundGeneratorService.shared
    @ObservedObject var tohoAIService = TohoAIService.shared
    @ObservedObject var cloudLinuxService = CloudVirtualLinuxService.shared
    @ObservedObject var appState = AppState.shared

    @State private var activeTab: SoundGeneratorMode = .bgm
    @State private var showSuccessAlert: Bool = false
    @State private var alertMessage: String = ""

    public enum SoundGeneratorMode: String, CaseIterable, Identifiable {
        case bgm = "東方風BGM生成 (ZUNペット/旋律)"
        case se = "東方風効果音 (SE) 生成 (弾幕/スペルカード)"

        public var id: String { rawValue }

        public var iconName: String {
            switch self {
            case .bgm: return "music.note"
            case .se: return "waveform"
            }
        }
    }

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // 上部モード切り替えタブバー
            modeSegmentBar

            Divider()

            // メインコンテンツ領域 (2カラム: 左 パラメータ設定 / 右 試聴・ビジュアライザ・履歴)
            HStack(spacing: 0) {
                // 左カラム: 設定パネル
                leftSettingsPanel
                    .frame(width: 380)

                Divider()

                // 右カラム: 試聴・波形・制作連携パネル
                rightPlaybackPanel
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(NSColor.windowBackgroundColor))
        .alert(isPresented: $showSuccessAlert) {
            Alert(
                title: Text("音響データ転送完了"),
                message: Text(alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    // MARK: - Mode Segment Bar
    private var modeSegmentBar: some View {
        HStack(spacing: 16) {
            Picker("", selection: $activeTab) {
                ForEach(SoundGeneratorMode.allCases) { mode in
                    Label(mode.rawValue, systemImage: mode.iconName).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 440)

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

    // MARK: - Left Settings Panel
    private var leftSettingsPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if activeTab == .bgm {
                    bgmSettingsSection
                } else {
                    seSettingsSection
                }

                Divider()

                // 生成実行ボタン
                generateButtonSection

                Spacer()
            }
            .padding(16)
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - BGM Settings
    private var bgmSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("東方風BGMパラメータ")
                    .font(.headline)
                Text("ZUNペット・和風短音階・疾走ベースによるリアルタイム楽曲合成")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // テーマプリセット
            VStack(alignment: .leading, spacing: 6) {
                Text("楽曲テーマ・原曲風プリセット:")
                    .font(.caption)
                    .bold()
                Picker("", selection: $soundService.bgmTheme) {
                    ForEach(AISoundGeneratorService.BGMThemePreset.allCases) { theme in
                        Text(theme.rawValue).tag(theme)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: soundService.bgmTheme) { newTheme in
                    soundService.bgmBPM = newTheme.defaultBPM
                }
            }

            // BPMスライダー
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("テンポ (BPM):")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(soundService.bgmBPM)) BPM")
                        .font(.caption)
                        .bold()
                }
                Slider(value: $soundService.bgmBPM, in: 80...200, step: 1.0)
            }

            // 尺（秒数）
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("ループ尺 (秒数):")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(soundService.bgmDurationSeconds)) 秒")
                        .font(.caption)
                        .bold()
                }
                Slider(value: $soundService.bgmDurationSeconds, in: 6...30, step: 2.0)
            }

            // 楽器編成スタイル
            VStack(alignment: .leading, spacing: 6) {
                Text("音色・楽器スタイル:")
                    .font(.caption)
                    .bold()
                Picker("", selection: $soundService.bgmInstrumentStyle) {
                    ForEach(AISoundGeneratorService.BGMInstrumentStyle.allCases) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(.menu)
            }
        }
    }

    // MARK: - SE Settings
    private var seSettingsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text("東方風効果音 (SE) パラメータ")
                    .font(.headline)
                Text("スペルカード・弾幕・被弾ピチューン等の波形シンセサイズ")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // SEプリセット
            VStack(alignment: .leading, spacing: 6) {
                Text("効果音プリセット:")
                    .font(.caption)
                    .bold()
                Picker("", selection: $soundService.sePreset) {
                    ForEach(AISoundGeneratorService.SEPresetType.allCases) { preset in
                        Text(preset.rawValue).tag(preset)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: soundService.sePreset) { newPreset in
                    soundService.seBaseFrequency = newPreset.defaultFrequency
                    soundService.seDurationSeconds = newPreset.defaultDuration
                }
            }

            // 周波数スライダー
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("基準周波数 (Hz):")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(soundService.seBaseFrequency)) Hz")
                        .font(.caption)
                        .bold()
                }
                Slider(value: $soundService.seBaseFrequency, in: 100...3500, step: 20.0)
            }

            // 持続時間スライダー
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("持続時間 (秒):")
                        .font(.caption)
                    Spacer()
                    Text(String(format: "%.2f 秒", soundService.seDurationSeconds))
                        .font(.caption)
                        .bold()
                }
                Slider(value: $soundService.seDurationSeconds, in: 0.1...3.0, step: 0.05)
            }

            // ノイズ混和率
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("ノイズ・歪み量:")
                        .font(.caption)
                    Spacer()
                    Text("\(Int(soundService.seNoiseMix * 100)) %")
                        .font(.caption)
                        .bold()
                }
                Slider(value: $soundService.seNoiseMix, in: 0.0...1.0, step: 0.05)
            }

            // 逆再生トグル
            Toggle("逆再生 (Reverse Sweep)", isOn: $soundService.seIsReversed)
                .font(.caption)
        }
    }

    // MARK: - Generate Button Section
    private var generateButtonSection: some View {
        VStack(spacing: 8) {
            Button(action: {
                if activeTab == .bgm {
                    soundService.generateBGM()
                } else {
                    soundService.generateSE()
                }
            }) {
                HStack(spacing: 8) {
                    if (activeTab == .bgm && soundService.isBGMGenerating) ||
                       (activeTab == .se && soundService.isSEGenerating) {
                        ProgressView().controlSize(.small)
                        Text("シンセ波形合成中...")
                    } else {
                        Image(systemName: "waveform.badge.plus")
                        Text(activeTab == .bgm ? "AI BGMを生成 (1プロンプト)" : "AI SEを生成 (1プロンプト)")
                            .bold()
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(soundService.isBGMGenerating || soundService.isSEGenerating)
        }
    }

    // MARK: - Right Playback & History Panel
    private var rightPlaybackPanel: some View {
        VStack(spacing: 0) {
            // 現在選択中のサウンド再生プレイヤー
            VStack(spacing: 16) {
                Spacer()

                // 波形ビジュアライザーアニメーション
                HStack(spacing: 6) {
                    ForEach(0..<24) { i in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(
                                colors: [Color.blue, Color.purple, Color.cyan],
                                startPoint: .bottom,
                                endPoint: .top
                            ))
                            .frame(
                                width: 8,
                                height: (soundService.isBGMPlaying || soundService.isSEPlaying) ?
                                    CGFloat.random(in: 15...90) :
                                    CGFloat(20 + (i % 6) * 8)
                            )
                            .animation(.easeInOut(duration: 0.15), value: soundService.isBGMPlaying || soundService.isSEPlaying)
                    }
                }
                .frame(height: 110)
                .padding(.horizontal)

                // 試聴コントロールバー
                HStack(spacing: 16) {
                    if activeTab == .bgm {
                        Button(action: {
                            soundService.togglePlayBGM()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: soundService.isBGMPlaying ? "stop.fill" : "play.fill")
                                Text(soundService.isBGMPlaying ? "停止" : "BGMをループ試聴")
                                    .bold()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(soundService.generatedBGMURL == nil)
                    } else {
                        Button(action: {
                            soundService.togglePlaySE()
                        }) {
                            HStack(spacing: 6) {
                                Image(systemName: soundService.isSEPlaying ? "speaker.wave.3.fill" : "play.fill")
                                Text(soundService.isSEPlaying ? "再生中..." : "SEを試聴再生")
                                    .bold()
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(soundService.generatedSEURL == nil)
                    }
                }

                // 制作スタジオ連携ボタン群
                if let latest = soundService.soundHistory.first {
                    HStack(spacing: 12) {
                        Button(action: {
                            soundService.applyToSoundMaker(item: latest)
                            alertMessage = "『\(latest.name)』をサウンドメーカーのタイムラインへ配置しました！"
                            showSuccessAlert = true
                        }) {
                            Label("サウンドメーカーへ配置", systemImage: "timeline.selection")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)

                        Button(action: {
                            soundService.applyToMovieMaker(item: latest)
                            alertMessage = "『\(latest.name)』をムービーメーカーのオーディオトラックに設定しました！"
                            showSuccessAlert = true
                        }) {
                            Label("ムービーメーカーへ適用", systemImage: "film")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)

                        Button(action: {
                            soundService.saveToMaterialStudio(item: latest)
                            alertMessage = "『\(latest.name)』を素材スタジオに登録しました！"
                            showSuccessAlert = true
                        }) {
                            Label("素材スタジオに保存", systemImage: "folder.badge.plus")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)

                        Button(action: {
                            NSWorkspace.shared.activateFileViewerSelecting([latest.fileURL])
                        }) {
                            Label("WAV表示", systemImage: "arrow.up.right.square")
                                .font(.caption)
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(.top, 4)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
            .background(Color.black.opacity(0.1))

            Divider()

            // 下部: サウンド生成履歴
            bottomSoundHistoryList
        }
    }

    // MARK: - Bottom Sound History List
    private var bottomSoundHistoryList: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("生成済みサウンド履歴 (\(soundService.soundHistory.count)件):")
                    .font(.caption2)
                    .bold()
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)

            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(soundService.soundHistory) { item in
                        HStack(spacing: 10) {
                            Image(systemName: item.type == "BGM" ? "music.note" : "waveform")
                                .foregroundColor(item.type == "BGM" ? .blue : .purple)
                                .frame(width: 24)

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(item.name)
                                        .font(.caption)
                                        .bold()
                                    Text("[\(item.type)]")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Text(item.detailDescription)
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Text(String(format: "%.1fs", item.duration))
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Button(action: {
                                if item.type == "BGM" {
                                    soundService.generatedBGMURL = item.fileURL
                                    soundService.togglePlayBGM()
                                } else {
                                    soundService.generatedSEURL = item.fileURL
                                    soundService.togglePlaySE()
                                }
                            }) {
                                Image(systemName: "play.circle.fill")
                                    .font(.title3)
                                    .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)

                            Button(action: {
                                soundService.applyToSoundMaker(item: item)
                                alertMessage = "『\(item.name)』をサウンドメーカーへ配置しました！"
                                showSuccessAlert = true
                            }) {
                                Image(systemName: "arrow.right.circle")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                            .help("サウンドメーカーのタイムラインへ配置")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .frame(height: 160)
        .background(Color(NSColor.windowBackgroundColor))
    }
}
