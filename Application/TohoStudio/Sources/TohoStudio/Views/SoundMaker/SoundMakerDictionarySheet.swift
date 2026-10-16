import SwiftUI
import AppKit

/// サウンドメーカー専用の読み仮名・発音辞書エディタシート
/// 東方Projectキャラクター名・用語プリセットの一覧・編集、ユーザーカスタム辞書の登録・試聴をサポート
public struct SoundMakerDictionarySheet: View {
    @ObservedObject var dictManager = SoundMakerDictionaryManager.shared
    @ObservedObject var aquesTalk = AquesTalkBridge.shared

    @Environment(\.presentationMode) var presentationMode

    // 検索・フィルタ
    @State private var searchText: String = ""
    @State private var selectedCategory: DictionaryCategory? = nil

    // 新規登録フォーム
    @State private var inputSurface: String = ""
    @State private var inputReading: String = ""
    @State private var inputPhonetic: String = ""
    @State private var inputCategory: DictionaryCategory = .userCustom
    @State private var formErrorMessage: String? = nil

    // テスト文検証バー
    @State private var testSentence: String = "博麗霊夢と霧雨魔理沙が、紅魔館で十六夜咲夜と会った。"
    @State private var isPlayingTestAudio: Bool = false

    // アラート
    @State private var showResetConfirmAlert: Bool = false
    @State private var showImportAlert: Bool = false
    @State private var importCsvString: String = ""

    public init() {}

    private var filteredWords: [DictionaryWord] {
        dictManager.words.filter { word in
            let matchesCategory = selectedCategory == nil || word.category == selectedCategory
            let matchesSearch = searchText.isEmpty
                || word.surface.localizedCaseInsensitiveContains(searchText)
                || word.reading.localizedCaseInsensitiveContains(searchText)
                || (word.phonetic?.localizedCaseInsensitiveContains(searchText) ?? false)
            return matchesCategory && matchesSearch
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider().background(Color(white: 0.2))

            // Main Content Area
            HStack(spacing: 0) {
                // Left: 新規登録 & テスト検証パネル
                leftSidebarView
                    .frame(width: 360)
                    .background(Color(red: 0.16, green: 0.17, blue: 0.19))

                Divider().background(Color(white: 0.2))

                // Right: 辞書単語テーブル
                rightTableView
                    .background(Color(red: 0.12, green: 0.13, blue: 0.15))
            }

            Divider().background(Color(white: 0.2))

            // Bottom Footer
            footerView
        }
        .frame(width: 980, height: 680)
        .background(Color(red: 0.14, green: 0.15, blue: 0.17))
        .alert(isPresented: $showResetConfirmAlert) {
            Alert(
                title: Text("辞書設定の初期化"),
                message: Text("東方Projectの標準辞書プリセットを初期状態に復元します。\n（ユーザー登録単語もリセットされます）"),
                primaryButton: .destructive(Text("初期化する")) {
                    dictManager.resetToDefaults()
                },
                secondaryButton: .cancel(Text("キャンセル"))
            )
        }
    }

    // MARK: - Header
    private var headerView: some View {
        HStack(spacing: 12) {
            Image(systemName: "character.book.closed.fill")
                .font(.system(size: 22))
                .foregroundColor(.cyan)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text("サウンドメーカー 発音・キャラクター辞書設定")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("東方Project専用 & ユーザー辞書")
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.cyan.opacity(0.2))
                        .foregroundColor(.cyan)
                        .cornerRadius(4)
                }
                Text("東方キャラクター名や固有名詞、文章の読み方を正確に指定し、自然で高品質なゆっくり音声を生成します。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // 単語件数バッジ
            HStack(spacing: 10) {
                HStack(spacing: 4) {
                    Text("登録数:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(dictManager.words.count)語")
                        .font(.caption.bold())
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06))
                .cornerRadius(4)

                Button(action: {
                    showResetConfirmAlert = true
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text("初期プリセットに復元")
                    }
                    .font(.caption2)
                    .foregroundColor(Color.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .help("東方Project標準キャラクター・用語辞書を初期状態にリセット")

                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Left Sidebar: Add Word Form & Test Sentence
    private var leftSidebarView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Section 1: 新規単語登録
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("新規単語・読みの登録", systemImage: "plus.circle.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.white)
                        Spacer()
                    }

                    // 表記 (Surface)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("表記 (漢字・カナ・単語)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        TextField("例: 霊夢, 咲夜, うｐ", text: $inputSurface)
                            .textFieldStyle(.roundedBorder)
                    }

                    // 読み (Reading)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("読み (ひらがな)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        TextField("例: れいむ, さくや, あっぷ", text: $inputReading)
                            .textFieldStyle(.roundedBorder)
                    }

                    // 音声記号 (Phonetic - 任意)
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("音声記号 (AquesTalk記号・任意)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("省略可")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                        TextField("例: レ'イム, サ'クヤ (未入力時は自動生成)", text: $inputPhonetic)
                            .textFieldStyle(.roundedBorder)
                    }

                    // カテゴリ
                    VStack(alignment: .leading, spacing: 4) {
                        Text("カテゴリ")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Picker("", selection: $inputCategory) {
                            ForEach(DictionaryCategory.allCases) { cat in
                                Text(cat.rawValue).tag(cat)
                            }
                        }
                        .pickerStyle(.menu)
                    }

                    if let err = formErrorMessage {
                        Text(err)
                            .font(.caption2)
                            .foregroundColor(.red)
                    }

                    // 登録・試聴ボタン
                    HStack(spacing: 8) {
                        Button(action: {
                            playTestVoice(text: inputReading.isEmpty ? inputSurface : inputReading)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "speaker.wave.2.fill")
                                Text("読みを試聴")
                            }
                            .font(.caption.bold())
                            .foregroundColor(.cyan)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.cyan.opacity(0.15))
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                        .disabled(inputReading.isEmpty && inputSurface.isEmpty)

                        Button(action: {
                            registerNewWord()
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "plus")
                                Text("辞書に追加")
                            }
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(Color.blue)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(Color(white: 0.12))
                .cornerRadius(6)

                // Section 2: 文章変換プレビュー＆検証
                VStack(alignment: .leading, spacing: 10) {
                    Label("文章での読み上げテスト", systemImage: "waveform.badge.magnifyingglass")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)

                    Text("東方キャラ名を含む文章を入力して、辞書による正しい読み替えと発音をチェックできます。")
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    TextEditor(text: $testSentence)
                        .font(.system(size: 11))
                        .frame(height: 70)
                        .padding(4)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(4)

                    // 辞書適用後のプレビュー
                    let converted = dictManager.applyDictionary(to: testSentence)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("辞書適用後のテキスト:")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text(converted)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.cyan)
                            .padding(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.cyan.opacity(0.1))
                            .cornerRadius(4)
                    }

                    // AquesTalk記号列プレビュー
                    let symbol = aquesTalk.convertToVoiceSymbol(text: testSentence)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("AquesTalk音声記号:")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text(symbol)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.orange)
                            .lineLimit(2)
                    }

                    Button(action: {
                        playTestVoice(text: testSentence)
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: isPlayingTestAudio ? "stop.fill" : "play.fill")
                            Text(isPlayingTestAudio ? "停止" : "この文章を発音テスト")
                        }
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 7)
                        .background(isPlayingTestAudio ? Color.red : Color.green)
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color(white: 0.12))
                .cornerRadius(6)

                // Section 3: CSV入出力
                VStack(alignment: .leading, spacing: 8) {
                    Label("辞書のバックアップ・共有", systemImage: "arrow.up.arrow.down.square")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)

                    HStack(spacing: 8) {
                        Button(action: {
                            exportCsvToClipboard()
                        }) {
                            Text("CSVをコピー")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            importCsvFromClipboard()
                        }) {
                            Text("クリップボードからCSV読込")
                                .font(.caption2)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(12)
                .background(Color(white: 0.12))
                .cornerRadius(6)
            }
            .padding(12)
        }
    }

    // MARK: - Right Table: Word List
    private var rightTableView: some View {
        VStack(spacing: 0) {
            // Search and Category Tabs
            VStack(spacing: 8) {
                // 検索バー
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("単語・表記・読みで辞書内を検索...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(Color(white: 0.08))
                .cornerRadius(4)

                // カテゴリフィルター
                HStack(spacing: 6) {
                    Button(action: { selectedCategory = nil }) {
                        Text("すべて (\(dictManager.words.count))")
                            .font(.system(size: 10, weight: selectedCategory == nil ? .bold : .regular))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(selectedCategory == nil ? Color.cyan.opacity(0.3) : Color.white.opacity(0.06))
                            .foregroundColor(selectedCategory == nil ? .cyan : .white)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    ForEach(DictionaryCategory.allCases, id: \.self) { cat in
                        let count = dictManager.words.filter { $0.category == cat }.count
                        Button(action: { selectedCategory = cat }) {
                            HStack(spacing: 3) {
                                Image(systemName: cat.iconName).font(.system(size: 8))
                                Text("\(cat.rawValue) (\(count))")
                            }
                            .font(.system(size: 10, weight: selectedCategory == cat ? .bold : .regular))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(selectedCategory == cat ? Color(hex: cat.badgeColorHex).opacity(0.35) : Color.white.opacity(0.06))
                            .foregroundColor(selectedCategory == cat ? Color(hex: cat.badgeColorHex) : .white)
                            .cornerRadius(4)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
            }
            .padding(10)
            .background(Color(white: 0.10))

            Divider().background(Color(white: 0.2))

            // Table Header
            HStack(spacing: 12) {
                Text("有効")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 32)

                Text("表記")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 160, alignment: .leading)

                Text("読み")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 170, alignment: .leading)

                Text("音声記号")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("カテゴリ")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 110, alignment: .leading)

                Text("操作")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.secondary)
                    .frame(width: 70)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(white: 0.08))

            Divider().background(Color(white: 0.2))

            // Table Content List
            if filteredWords.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "tray")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text(searchText.isEmpty ? "登録単語がありません" : "「\(searchText)」に一致する単語は見つかりませんでした")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(filteredWords) { word in
                        wordRowView(word: word)
                            .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Single Word Row View
    private func wordRowView(word: DictionaryWord) -> some View {
        HStack(spacing: 12) {
            // 有効・無効トグル
            Button(action: {
                dictManager.toggleWordEnabled(id: word.id)
            }) {
                Image(systemName: word.isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13))
                    .foregroundColor(word.isEnabled ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 32)

            // 表記
            Text(word.surface)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(word.isEnabled ? .white : .secondary)
                .frame(width: 160, alignment: .leading)
                .lineLimit(1)

            // 読み
            Text(word.reading)
                .font(.system(size: 11))
                .foregroundColor(word.isEnabled ? .cyan : .secondary)
                .frame(width: 170, alignment: .leading)
                .lineLimit(1)

            // 音声記号
            Text(word.phonetic ?? "-")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(word.phonetic != nil ? .orange : Color(white: 0.4))
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(1)

            // カテゴリバッジ
            HStack(spacing: 3) {
                Image(systemName: word.category.iconName)
                    .font(.system(size: 7))
                Text(word.category.rawValue)
                    .font(.system(size: 9))
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color(hex: word.category.badgeColorHex).opacity(0.2))
            .foregroundColor(Color(hex: word.category.badgeColorHex))
            .cornerRadius(3)
            .frame(width: 110, alignment: .leading)

            // 操作 (試聴 & 削除)
            HStack(spacing: 8) {
                Button(action: {
                    playTestVoice(text: word.reading)
                }) {
                    Image(systemName: "speaker.wave.2")
                        .font(.system(size: 11))
                        .foregroundColor(.cyan)
                }
                .buttonStyle(.plain)
                .help("この単語の読みを発音試聴")

                Button(action: {
                    dictManager.removeWord(id: word.id)
                }) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("辞書から削除")
            }
            .frame(width: 70)
        }
        .padding(.vertical, 2)
    }

    // MARK: - Footer
    private var footerView: some View {
        HStack {
            Text("💡 ヒント: サウンドメーカー内での音声生成や一括生成時、文章中の東方キャラ名・登録単語は最長一致で自動的に正しい読みに変換されます。")
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            Button(action: {
                presentationMode.wrappedValue.dismiss()
            }) {
                Text("閉じる")
                    .font(.caption.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(red: 0.12, green: 0.13, blue: 0.15))
    }

    // MARK: - Actions
    private func registerNewWord() {
        let s = inputSurface.trimmingCharacters(in: .whitespacesAndNewlines)
        let r = inputReading.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.isEmpty || r.isEmpty {
            formErrorMessage = "表記と読みを入力してください。"
            return
        }
        formErrorMessage = nil
        let p = inputPhonetic.isEmpty ? nil : inputPhonetic.trimmingCharacters(in: .whitespacesAndNewlines)
        dictManager.addWord(surface: s, reading: r, phonetic: p, category: inputCategory)

        // 入力クリア
        inputSurface = ""
        inputReading = ""
        inputPhonetic = ""
    }

    private func playTestVoice(text: String) {
        guard !text.isEmpty else { return }
        if isPlayingTestAudio {
            aquesTalk.stopPlayback()
            isPlayingTestAudio = false
            return
        }

        isPlayingTestAudio = true
        aquesTalk.synthesizeAndPlay(text: text) {
            DispatchQueue.main.async {
                self.isPlayingTestAudio = false
            }
        }
    }

    private func exportCsvToClipboard() {
        let csv = dictManager.exportCSV()
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(csv, forType: .string)
        AppState.shared.log("📋 辞書データ (CSV) をクリップボードにコピーしました (\(dictManager.words.count)語)")
    }

    private func importCsvFromClipboard() {
        if let string = NSPasteboard.general.string(forType: .string), !string.isEmpty {
            dictManager.importCSV(string)
            AppState.shared.log("📥 クリップボードから辞書データ (CSV) を読み込みました")
        }
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
