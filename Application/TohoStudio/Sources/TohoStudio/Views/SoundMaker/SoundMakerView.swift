import SwiftUI

public struct SoundMakerView: View {
    @ObservedObject var appState = AppState.shared
    @ObservedObject var aquesTalk = AquesTalkBridge.shared

    @State private var inputSpeechText: String = "ゆっくりしていってね！"
    @State private var convertedVoiceSymbol: String = "ユックリシテイッテネ"
    @State private var speechSpeed: Int = 100
    @State private var isSynthesizing: Bool = false
    @State private var showExportAudioSheet: Bool = false
    @State private var audioExportFormat: String = "WAV (非圧縮・最高音質)"

    public var body: some View {
        VStack(spacing: 0) {
            // Top Bar
            HStack(spacing: 14) {
                Label("サウンドメーカー", systemImage: "waveform")
                    .font(.headline)
                Text("(AquesTalk ゆっくりボイス & BGM/SE ミキサー)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // Extension Badges
                HStack(spacing: 6) {
                    extensionBadge(title: "Audition機能", isUnlocked: appState.unlockedExtensions.contains("Audition非搭載機能"))
                    extensionBadge(title: "Logic Pro機能", isUnlocked: appState.unlockedExtensions.contains("LogicPro非搭載機能"))
                }

                Divider().frame(height: 18)

                Button(action: { showExportAudioSheet = true }) {
                    Label("音声を書き出し", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Main Area
            HSplitView {
                // Left: AquesTalk Voice Generator
                aquesTalkSpeechGeneratorView
                    .frame(minWidth: 440, maxWidth: .infinity)
                    .padding()

                // Right: BGM / SE Mixer & Track Clips
                bgmAndSeMixerView
                    .frame(width: 340)
                    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            }
        }
        .sheet(isPresented: $showExportAudioSheet) {
            exportAudioDialog
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

    // MARK: - AquesTalk Speech Generator
    private var aquesTalkSpeechGeneratorView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("AquesTalk ゆっくりボイス合成エンジン")
                .font(.headline)

            GroupBox(label: Label("テキスト入力と記号変換 (AqKanji2Koe)", systemImage: "character.bubble")) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("日本語セリフを入力:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("セリフを入力", text: $inputSpeechText)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: inputSpeechText) { newVal in
                            convertedVoiceSymbol = aquesTalk.convertToVoiceSymbol(text: newVal)
                        }

                    Text("生成される音声記号列:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    TextField("音声記号列", text: $convertedVoiceSymbol)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                }
                .padding(8)
            }

            GroupBox(label: Label("声種設定と発声パラメータ (AquesTalk1)", systemImage: "slider.horizontal.3")) {
                VStack(spacing: 12) {
                    HStack {
                        Text("声種 (Voice Type):")
                        Spacer()
                        Picker("", selection: Binding(
                            get: { aquesTalk.currentVoice },
                            set: { aquesTalk.setVoiceType($0) }
                        )) {
                            ForEach(VoiceType.allCases) { v in
                                Text(v.rawValue).tag(v)
                            }
                        }
                        .frame(width: 180)
                    }

                    HStack {
                        Text("発話速度 (Speed):")
                        Spacer()
                        Text("\(speechSpeed)%").bold()
                    }
                    Slider(value: Binding(
                        get: { Double(speechSpeed) },
                        set: { speechSpeed = Int($0) }
                    ), in: 50...200)

                    HStack {
                        // Synthesize & Play Button
                        Button(action: {
                            isSynthesizing = true
                            aquesTalk.synthesizeAndPlay(text: inputSpeechText, speed: speechSpeed) {
                                isSynthesizing = false
                            }
                        }) {
                            HStack {
                                Image(systemName: isSynthesizing ? "waveform.badge.magnifyingglass" : "play.fill")
                                Text("ゆっくりボイスを合成・試聴")
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .keyboardShortcut(.return, modifiers: [.command])

                        // Add to SoundClips
                        Button("クリップに追加") {
                            let newClip = SoundClip(
                                name: "ボイス: \(inputSpeechText.prefix(8))...",
                                type: "Voice",
                                character: "博麗霊夢",
                                text: inputSpeechText,
                                voiceSymbol: convertedVoiceSymbol,
                                duration: Double(inputSpeechText.count) * 0.25,
                                volume: 1.0,
                                speed: speechSpeed
                            )
                            appState.soundClips.append(newClip)
                            appState.log("AquesTalkボイスをトラックに追加しました")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(8)
            }

            // Engine Log
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.secondary)
                Text(aquesTalk.lastLog)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
    }

    // MARK: - BGM / SE Mixer
    private var bgmAndSeMixerView: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("オーディオトラック & ミキサー")
                .font(.headline)

            List {
                ForEach(appState.soundClips) { clip in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: clip.type == "BGM" ? "music.note" : (clip.type == "SE" ? "speaker.wave.3.fill" : "person.wave.2.fill"))
                                .foregroundColor(.accentColor)
                            Text(clip.name)
                                .font(.subheadline)
                                .bold()
                            Spacer()
                            Text("\(String(format: "%.1f", clip.duration))s")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }

                        HStack {
                            Text("音量:")
                                .font(.caption2)
                            Slider(value: Binding(
                                get: { clip.volume },
                                set: { val in
                                    if let idx = appState.soundClips.firstIndex(where: { $0.id == clip.id }) {
                                        appState.soundClips[idx].volume = val
                                    }
                                }
                            ), in: 0...1.0)
                        }
                    }
                    .padding(4)
                }
            }
            .frame(height: 240)

            HStack {
                Button(action: {
                    let seClip = SoundClip(name: "スペルカード効果音", type: "SE", duration: 1.8, volume: 0.8)
                    appState.soundClips.append(seClip)
                }) {
                    Label("SE追加", systemImage: "plus")
                        .font(.caption)
                }

                Button(action: {
                    let bgmClip = SoundClip(name: "ネイティブフェイス (BGM)", type: "BGM", duration: 210.0, volume: 0.6)
                    appState.soundClips.append(bgmClip)
                }) {
                    Label("BGM追加", systemImage: "plus")
                        .font(.caption)
                }
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Export Dialog
    private var exportAudioDialog: some View {
        VStack(spacing: 18) {
            Text("音声データの書き出し")
                .font(.headline)
            Picker("音声フォーマット", selection: $audioExportFormat) {
                Text("WAV (非圧縮・最高音質)").tag("WAV (非圧縮・最高音質)")
                Text("MP3 (192kbps - 軽量)").tag("MP3 (192kbps - 軽量)")
                Text("M4A (AAC - Mac標準)").tag("M4A (AAC - Mac標準)")
                Text("AIFF (リニアPCM)").tag("AIFF (リニアPCM)")
                Text("LOGICX (Logic Proプロジェクト)").tag("LOGICX (Logic Proプロジェクト)")
                Text("SESX (Auditionセッション)").tag("SESX (Auditionセッション)")
            }
            .pickerStyle(.menu)

            HStack {
                Button("キャンセル") { showExportAudioSheet = false }
                Spacer()
                Button("書き出し実行") {
                    showExportAudioSheet = false
                    appState.log("音声を書き出しました: \(audioExportFormat)")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 420)
    }
}
