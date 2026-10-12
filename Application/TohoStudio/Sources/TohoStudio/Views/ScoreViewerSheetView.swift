import SwiftUI
import AppKit
import PDFKit
import UniformTypeIdentifiers

/// 音楽メディアからの自動採譜・PDF楽譜生成プレビュー＆保存シート
public struct ScoreViewerSheetView: View {
    @Environment(\.presentationMode) var presentationMode
    @ObservedObject var cloudLinuxService = CloudVirtualLinuxService.shared

    /// 外部から直接指定された音声ファイルURL（SoundMakerやAISoundGeneratorから直接渡された場合）
    public var initialAudioURL: URL?

    @State private var selectedAudioURL: URL? = nil
    @State private var pdfData: Data? = nil
    @State private var isProcessing: Bool = false
    @State private var progressPhase: String = "準備中..."
    @State private var errorMessage: String? = nil
    @State private var showErrorAlert: Bool = false
    @State private var showFilePicker: Bool = false
    @State private var showSuccessBanner: Bool = false
    @State private var successMessage: String = ""
    @State private var savedPDFURL: URL? = nil

    // サーバー情報
    @State private var hostIPInput: String = ""
    @State private var isCheckingConnection: Bool = false
    @State private var serverStatusText: String = "未確認"

    // 歌詞＆高精度採譜オプション
    @State private var customLyricsInput: String = ""
    @State private var separateStems: Bool = true
    @State private var withLyrics: Bool = true
    @State private var showLyricsInput: Bool = false
    @State private var showColabBrowser: Bool = false

    // PDF表示設定
    @State private var pdfViewScale: CGFloat = 1.0

    // バックグラウンド処理タスク
    @State private var currentTranscriptionTask: Task<Void, Never>? = nil

    public init(initialAudioURL: URL? = nil) {
        self.initialAudioURL = initialAudioURL
    }

    public var body: some View {
        VStack(spacing: 0) {
            // ヘッダーバー
            headerBar

            Divider()

            // メインコンテンツエリア
            ZStack {
                if let data = pdfData {
                    // PDF生成完了時のビュー
                    scoreResultView(data: data)
                } else if isProcessing {
                    // 処理中プログレス画面
                    processingView
                } else {
                    // 音声ファイル未選択・待機画面
                    emptyStateView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // フッターアクションバー
            footerBar
        }
        .frame(minWidth: 880, minHeight: 640)
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            hostIPInput = cloudLinuxService.machineStatus.hostIP
            if let initial = initialAudioURL {
                selectedAudioURL = initial
                startTranscription(fileURL: initial)
            } else {
                checkConnection()
            }
        }
        .onDisappear {
            currentTranscriptionTask?.cancel()
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [
                .audio,
                UTType(filenameExtension: "wav") ?? .audio,
                UTType(filenameExtension: "mp3") ?? .audio,
                UTType(filenameExtension: "m4a") ?? .audio,
                UTType(filenameExtension: "flac") ?? .audio,
                UTType(filenameExtension: "ogg") ?? .audio
            ],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    selectedAudioURL = url
                    startTranscription(fileURL: url)
                }
            case .failure(let error):
                errorMessage = "ファイル選択エラー: \(error.localizedDescription)"
                showErrorAlert = true
            }
        }
        .alert(isPresented: $showErrorAlert) {
            Alert(
                title: Text("自動採譜エラー"),
                message: Text(errorMessage ?? "不明なエラーが発生しました。"),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(isPresented: $showColabBrowser) {
            ColabGPUInAppBrowserView(isPresented: $showColabBrowser)
        }
    }

    // MARK: - Header Bar
    private var headerBar: some View {
        HStack(spacing: 14) {
            Image(systemName: "music.quarternote.3")
                .font(.title2)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Text("音楽メディア自動採譜・PDF楽譜生成システム")
                    .font(.headline)
                    .bold()
                Text("Spotify Basic Pitch（AIピッチ抽出）+ music21（拍クオンタイズ）+ LilyPond（五線譜組版）")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Colab GPU 起動 / 状態ボタン
            Button(action: {
                showColabBrowser = true
            }) {
                HStack(spacing: 5) {
                    Circle()
                        .fill(cloudLinuxService.colabBridge.isOnline ? Color.green : Color.blue)
                        .frame(width: 8, height: 8)
                    Text(cloudLinuxService.colabBridge.isOnline ? "⚡️ Colab GPU 接続中 (音源分離・歌詞抽出)" : "🌸 Colab GPU 起動...")
                        .font(.caption2)
                        .foregroundColor(cloudLinuxService.colabBridge.isOnline ? .green : .cyan)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(cloudLinuxService.colabBridge.isOnline ? Color.green.opacity(0.12) : Color.cyan.opacity(0.12))
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("アプリ内ブラウザでGoogle Colabを開き、GPUを使った音源分離・自動採譜を実行します")

            // サーバー接続情報バッジ
            HStack(spacing: 6) {
                Circle()
                    .fill(cloudLinuxService.connectionStatus == .connected ? Color.green : Color.orange)
                    .frame(width: 8, height: 8)
                Text("VM: \(hostIPInput):8080")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(6)

            Button(action: {
                currentTranscriptionTask?.cancel()
                presentationMode.wrappedValue.dismiss()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Empty / Standby View
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 90, height: 90)
                Image(systemName: "waveform.and.magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
            }

            VStack(spacing: 6) {
                Text("音楽メディアを選択して自動採譜を開始")
                    .font(.title3)
                    .bold()

                Text("音声からAIがメロディ・リズムを抽出し、高品位な五線譜（PDF）を自動で作成・組版します。\nColab GPU 接続時は、ドラムや伴奏を自動除去（音源分離）し歌詞付き楽譜を瞬時に生成します。")
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            // オプション設定パネル
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    Toggle(isOn: $separateStems) {
                        HStack(spacing: 4) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.purple)
                            Text("Colab GPU 音源分離 (ドラム・低音ノイズ遮断)")
                                .font(.caption)
                                .bold()
                        }
                    }
                    .toggleStyle(.checkbox)
                    .disabled(!cloudLinuxService.colabBridge.isOnline)

                    Toggle(isOn: $withLyrics) {
                        HStack(spacing: 4) {
                            Image(systemName: "text.bubble")
                                .foregroundColor(.blue)
                            Text("歌詞を楽譜に織り込む")
                                .font(.caption)
                                .bold()
                        }
                    }
                    .toggleStyle(.checkbox)

                    Spacer()

                    Button(action: {
                        withAnimation {
                            showLyricsInput.toggle()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: showLyricsInput ? "chevron.up" : "square.and.pencil")
                            Text(showLyricsInput ? "歌詞入力を閉じる" : "歌詞を直接入力 (任意)")
                                .font(.caption)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }

                if showLyricsInput {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("歌詞テキスト（ひらがな・漢字）：")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        TextEditor(text: $customLyricsInput)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 70)
                            .padding(4)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                        Text("※未入力の場合は、AI（Whisper）が歌声から自動で文字起こしして楽譜に配置します。")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .transition(.opacity)
                }
            }
            .padding(12)
            .frame(maxWidth: 580)
            .background(Color.secondary.opacity(0.06))
            .cornerRadius(10)

            if let selected = selectedAudioURL {
                HStack(spacing: 8) {
                    Image(systemName: "doc.badge.gearshape")
                        .foregroundColor(.blue)
                    Text(selected.lastPathComponent)
                        .font(.headline)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)

                Button(action: {
                    startTranscription(fileURL: selected)
                }) {
                    Label("この音声を採譜してPDFを生成", systemImage: "sparkles")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(action: {
                    showFilePicker = true
                }) {
                    Label("音声ファイルを選択...", systemImage: "folder.badge.plus")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    // MARK: - Processing View
    private var processingView: some View {
        VStack(spacing: 24) {
            Spacer()

            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.6)

            VStack(spacing: 10) {
                Text("自動採譜・組版処理を実行中")
                    .font(.title3)
                    .bold()

                Text(progressPhase)
                    .font(.body)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(6)

                if cloudLinuxService.colabBridge.isOnline {
                    HStack(spacing: 5) {
                        Circle().fill(Color.green).frame(width: 7, height: 7)
                        Text("⚡️ Colab L4 GPU: Meta Demucs音源分離 ＆ OpenAI Whisper歌詞抽出中")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(6)
                } else {
                    HStack(spacing: 5) {
                        Circle().fill(Color.orange).frame(width: 7, height: 7)
                        Text("ℹ️ ローカル Linux VM で解析中（Colab GPU 接続時はさらに高精度・ボーカル分離）")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                }

                Text("※ 音声の長さにより、処理に約10秒〜30秒ほどかかります。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button(action: {
                currentTranscriptionTask?.cancel()
                isProcessing = false
            }) {
                Label("キャンセル", systemImage: "stop.circle")
                    .font(.callout)
            }
            .buttonStyle(.bordered)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Score Result View (PDFKit プレビュー)
    private func scoreResultView(data: Data) -> some View {
        VStack(spacing: 0) {
            // 上部ツールバー（再採譜、保存、Finder表示など）
            HStack(spacing: 12) {
                if let url = selectedAudioURL {
                    HStack(spacing: 6) {
                        Image(systemName: "music.note")
                            .foregroundColor(.blue)
                        Text(url.lastPathComponent)
                            .font(.caption)
                            .bold()
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
                }

                if showSuccessBanner {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text(successMessage)
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                    .transition(.opacity)
                }

                Spacer()

                Button(action: {
                    showFilePicker = true
                }) {
                    Label("別の音声を選択", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Button(action: {
                    if let selected = selectedAudioURL {
                        startTranscription(fileURL: selected)
                    }
                }) {
                    Label("再生成", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Button(action: {
                    exportPDF(data: data)
                }) {
                    Label("PDF楽譜を書き出す...", systemImage: "square.and.arrow.down.fill")
                        .font(.caption)
                        .bold()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // PDF表示ビュー
            PDFKitRepresentedView(pdfData: data)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Footer Bar
    private var footerBar: some View {
        HStack {
            if let saved = savedPDFURL {
                Button(action: {
                    NSWorkspace.shared.activateFileViewerSelecting([saved])
                }) {
                    Label("保存先フォルダをFinderで表示", systemImage: "arrow.up.right.square")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
            } else {
                Text("五線譜PDFはベクター形式で出力されるため、印刷時も極めて鮮明です。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("閉じる") {
                currentTranscriptionTask?.cancel()
                presentationMode.wrappedValue.dismiss()
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.cancelAction)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - Actions
    private func checkConnection() {
        isCheckingConnection = true
        Task {
            let client = MusicTranscriptionClient.shared
            client.customHostIP = hostIPInput
            let (_, _, msg) = await client.checkServerCapability()
            await MainActor.run {
                self.serverStatusText = msg
                self.isCheckingConnection = false
            }
        }
    }

    private func startTranscription(fileURL: URL) {
        guard !isProcessing else { return }
        isProcessing = true
        errorMessage = nil
        let isColab = cloudLinuxService.colabBridge.isOnline
        progressPhase = isColab
            ? "1/3: 音声データを Colab L4 GPU へ転送中..."
            : "1/3: 音声データを準備して Linux VM へ転送中..."

        currentTranscriptionTask = Task {
            do {
                let client = MusicTranscriptionClient.shared
                client.customHostIP = hostIPInput

                try Task.checkCancellation()
                await MainActor.run {
                    progressPhase = isColab
                        ? "2/3: Colab GPU (Demucs音源分離 + Whisper歌詞抽出 + Basic Pitch) 実行中..."
                        : "2/3: Basic Pitch AI によるピッチ・発音時刻の抽出中..."
                }

                let receivedData = try await client.transcribe(
                    audioFileURL: fileURL,
                    customLyrics: customLyricsInput,
                    separateStems: separateStems,
                    withLyrics: withLyrics
                )

                try Task.checkCancellation()
                await MainActor.run {
                    progressPhase = "3/3: LilyPond による五線譜組版完了！"
                    self.pdfData = receivedData
                    self.isProcessing = false
                    AppState.shared.addSystemLog(level: "INFO", message: "【自動採譜完了】『\(fileURL.lastPathComponent)』から五線譜PDFを正常生成しました。")
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.isProcessing = false
                }
            } catch {
                await MainActor.run {
                    self.isProcessing = false
                    self.errorMessage = error.localizedDescription
                    self.showErrorAlert = true
                    AppState.shared.addSystemLog(level: "ERROR", message: "【自動採譜失敗】\(error.localizedDescription)")
                }
            }
        }
    }

    private func exportPDF(data: Data) {
        let savePanel = NSSavePanel()
        savePanel.title = "楽譜PDFの保存先を指定"
        savePanel.allowedContentTypes = [.pdf]

        let baseName = selectedAudioURL?.deletingPathExtension().lastPathComponent ?? "楽譜"
        savePanel.nameFieldStringValue = "\(baseName)_五線譜.pdf"

        savePanel.begin { response in
            if response == .OK, let targetURL = savePanel.url {
                do {
                    try data.write(to: targetURL)
                    self.savedPDFURL = targetURL
                    self.successMessage = "「\(targetURL.lastPathComponent)」に保存しました"
                    withAnimation {
                        self.showSuccessBanner = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
                        withAnimation {
                            self.showSuccessBanner = false
                        }
                    }
                    AppState.shared.addSystemLog(level: "INFO", message: "【楽譜エクスポート】\(targetURL.path) に保存完了")
                } catch {
                    self.errorMessage = "PDF保存エラー: \(error.localizedDescription)"
                    self.showErrorAlert = true
                }
            }
        }
    }
}

// MARK: - PDFKit NSViewRepresentable
public struct PDFKitRepresentedView: NSViewRepresentable {
    public let pdfData: Data?

    public init(pdfData: Data?) {
        self.pdfData = pdfData
    }

    public func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = NSColor.windowBackgroundColor
        return pdfView
    }

    public func updateNSView(_ nsView: PDFView, context: Context) {
        if let data = pdfData {
            if nsView.document == nil || nsView.document?.dataRepresentation() != data {
                if let doc = PDFDocument(data: data) {
                    nsView.document = doc
                }
            }
        } else {
            nsView.document = nil
        }
    }
}
